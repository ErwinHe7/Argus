#include "axio/quant_os.hpp"

#include <algorithm>
#include <cmath>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <unordered_map>

namespace {

std::string arg_value(int argc, char** argv, std::string_view name,
                      std::string fallback = {}) {
  for (int i = 1; i + 1 < argc; ++i) {
    if (argv[i] == name) return argv[i + 1];
  }
  return fallback;
}

bool has_arg(int argc, char** argv, std::string_view name) {
  for (int i = 1; i < argc; ++i) if (argv[i] == name) return true;
  return false;
}

std::string json_escape(std::string_view value) {
  std::string out;
  for (const char ch : value) {
    if (ch == '"' || ch == '\\') out.push_back('\\');
    out.push_back(ch);
  }
  return out;
}

std::filesystem::path find_root(std::filesystem::path current) {
  current = std::filesystem::absolute(std::move(current));
  while (!current.empty()) {
    if (std::filesystem::exists(current / "quant_core_cpp" / "CMakeLists.txt")) return current;
    if (current == current.root_path()) break;
    current = current.parent_path();
  }
  throw std::runtime_error("cannot locate Axio7 workspace root");
}

struct Dataset {
  std::vector<axio::MarketEvent> events;
  std::vector<axio::Bar> target_bars;
  std::vector<axio::FeatureSnapshot> features;
  axio::DataManifest manifest;
  axio::ReplayResult replay;
};

Dataset load_dataset(const std::filesystem::path& csv) {
  axio::CsvBarAdapter adapter(csv, {"SPY", "QQQ", "IWM"});
  Dataset data;
  data.events = adapter.load();
  data.manifest = adapter.manifest();
  for (const auto& event : data.events) {
    if (event.bar && event.bar->symbol == "SPY" && axio::is_regular_session_bar(*event.bar)) {
      data.target_bars.push_back(*event.bar);
    }
  }
  axio::IncrementalFeatureStore store("SPY");
  data.replay = axio::ReplayEngine{}.replay(data.events, store);
  data.features = store.snapshots();
  return data;
}

std::pair<std::vector<axio::FeatureSnapshot>, std::vector<axio::Label>> align(
    const std::vector<axio::FeatureSnapshot>& features, const std::vector<axio::Label>& labels) {
  std::unordered_map<axio::Timestamp, axio::Label> by_time;
  for (const auto& label : labels) by_time.emplace(label.signal_time, label);
  std::vector<axio::FeatureSnapshot> x;
  std::vector<axio::Label> y;
  for (const auto& feature : features) {
    const auto found = by_time.find(feature.timestamp);
    if (feature.warm && found != by_time.end()) {
      x.push_back(feature);
      y.push_back(found->second);
    }
  }
  return {std::move(x), std::move(y)};
}

std::string metrics_json(const axio::EvaluationMetrics& value) {
  std::ostringstream out;
  out << "{\"samples\":" << value.samples << ",\"trades\":" << value.trades
      << ",\"brier\":" << value.brier
      << ",\"log_loss\":" << value.log_loss << ",\"ece\":" << value.expected_calibration_error
      << ",\"net_expectancy_per_candidate\":" << value.net_expectancy
      << ",\"trade_expectancy\":" << value.trade_expectancy << ",\"win_rate\":" << value.win_rate
      << ",\"bootstrap_95_low\":" << value.bootstrap_low
      << ",\"bootstrap_95_high\":" << value.bootstrap_high << '}';
  return out.str();
}

void write_file(const std::filesystem::path& path, const std::string& text) {
  if (!path.parent_path().empty()) std::filesystem::create_directories(path.parent_path());
  std::ofstream out(path, std::ios::binary | std::ios::trunc);
  if (!out) throw std::runtime_error("cannot write " + path.string());
  out << text;
}

int evaluate(const std::filesystem::path& csv, const std::filesystem::path& report_path) {
  Dataset data = load_dataset(csv);
  const auto labels = axio::make_labels(data.target_bars, 5);
  auto [x, y] = align(data.features, labels);
  if (x.size() < 1000U) throw std::runtime_error("insufficient aligned point-in-time samples");
  const std::size_t train_end = static_cast<std::size_t>(static_cast<double>(x.size()) * 0.60);
  const std::size_t validation_end = static_cast<std::size_t>(static_cast<double>(x.size()) * 0.80);
  std::vector<axio::FeatureSnapshot> train_x(x.begin(), x.begin() + static_cast<std::ptrdiff_t>(train_end));
  std::vector<axio::Label> train_y(y.begin(), y.begin() + static_cast<std::ptrdiff_t>(train_end));
  std::vector<axio::FeatureSnapshot> validation_x(x.begin() + static_cast<std::ptrdiff_t>(train_end),
                                                   x.begin() + static_cast<std::ptrdiff_t>(validation_end));
  std::vector<axio::Label> validation_y(y.begin() + static_cast<std::ptrdiff_t>(train_end),
                                        y.begin() + static_cast<std::ptrdiff_t>(validation_end));
  std::vector<axio::FeatureSnapshot> test_x(x.begin() + static_cast<std::ptrdiff_t>(validation_end), x.end());
  std::vector<axio::Label> test_y(y.begin() + static_cast<std::ptrdiff_t>(validation_end), y.end());

  axio::LogisticModel logistic(0.02, 7);
  logistic.fit(train_x, train_y);
  logistic.calibrate(validation_x, validation_y);
  axio::AnalogKernelModel analog(80, 20.0);
  std::vector<axio::FeatureSnapshot> pretest_x;
  std::vector<axio::Label> pretest_y;
  for (std::size_t i = 0; i < validation_end; ++i) {
    const int minute = static_cast<int>(x[i].x[10]);
    if (minute % 30 == 0 || std::abs(x[i].x[2]) >= 0.0035) {
      pretest_x.push_back(x[i]);
      pretest_y.push_back(y[i]);
    }
  }
  analog.fit(pretest_x, pretest_y);

  std::vector<axio::PredictionDistribution> logistic_predictions;
  std::vector<axio::PredictionDistribution> analog_predictions;
  std::vector<axio::FeatureSnapshot> candidate_test_x;
  std::vector<axio::Label> candidate_test_y;
  const double cost = 0.00015;
  for (std::size_t index = 0; index < test_x.size(); ++index) {
    const auto& feature = test_x[index];
    const int minute = static_cast<int>(feature.x[10]);
    if (minute % 30 != 0 && std::abs(feature.x[2]) < 0.0035) continue;
    candidate_test_x.push_back(feature);
    candidate_test_y.push_back(test_y[index]);
    auto lp = logistic.predict_distribution(feature, 5);
    lp.expected_net_value = std::abs(lp.expected_return) - cost;
    lp.lower_confidence_bound = lp.expected_net_value - 1.645 * lp.uncertainty;
    lp.decision = lp.lower_confidence_bound > 0.0 ?
        (lp.expected_return > 0.0 ? axio::Decision::Long : axio::Decision::Short) : axio::Decision::NoTrade;
    logistic_predictions.push_back(lp);
    auto ap = analog.predict_distribution(feature, 5);
    ap.expected_net_value = std::abs(ap.expected_return) - cost;
    ap.lower_confidence_bound = ap.expected_net_value - 1.645 * ap.uncertainty /
        std::sqrt(std::max(ap.effective_sample_size, 1.0));
    ap.decision = ap.lower_confidence_bound > 0.0 && ap.effective_sample_size >= 20.0 ?
        (ap.expected_return > 0.0 ? axio::Decision::Long : axio::Decision::Short) : axio::Decision::NoTrade;
    analog_predictions.push_back(ap);
  }
  const auto logistic_metrics = axio::evaluate_predictions(logistic_predictions, candidate_test_y, cost, 7);
  const auto analog_metrics = axio::evaluate_predictions(analog_predictions, candidate_test_y, cost, 7);
  std::ostringstream baselines;
  baselines << '{';
  const std::array baseline_kinds{
      axio::BaselineModel::Kind::AlwaysUp, axio::BaselineModel::Kind::AlwaysDown,
      axio::BaselineModel::Kind::FiftyFifty, axio::BaselineModel::Kind::RollingMean,
      axio::BaselineModel::Kind::Momentum, axio::BaselineModel::Kind::MeanReversion};
  for (std::size_t kind_index = 0; kind_index < baseline_kinds.size(); ++kind_index) {
    axio::BaselineModel baseline(baseline_kinds[kind_index]);
    baseline.fit(train_x, train_y);
    std::vector<axio::PredictionDistribution> predictions;
    for (const auto& feature : candidate_test_x) {
      auto prediction = baseline.predict_distribution(feature, 5);
      if (baseline_kinds[kind_index] == axio::BaselineModel::Kind::FiftyFifty) {
        prediction.decision = axio::Decision::NoTrade;
      } else {
        prediction.decision = prediction.expected_return >= 0.0 ? axio::Decision::Long : axio::Decision::Short;
      }
      predictions.push_back(prediction);
    }
    if (kind_index > 0U) baselines << ',';
    baselines << '"' << baseline.id() << "\":"
              << metrics_json(axio::evaluate_predictions(predictions, candidate_test_y, cost, 7));
  }
  baselines << '}';

  auto direct_horizon = [&](int horizon) {
    const auto horizon_labels = axio::make_labels(data.target_bars, horizon);
    auto [horizon_x, horizon_y] = align(data.features, horizon_labels);
    const std::size_t h_train_end = static_cast<std::size_t>(static_cast<double>(horizon_x.size()) * 0.60);
    const std::size_t h_validation_end = static_cast<std::size_t>(static_cast<double>(horizon_x.size()) * 0.80);
    std::vector<axio::FeatureSnapshot> h_train_x(horizon_x.begin(), horizon_x.begin() + static_cast<std::ptrdiff_t>(h_train_end));
    std::vector<axio::Label> h_train_y(horizon_y.begin(), horizon_y.begin() + static_cast<std::ptrdiff_t>(h_train_end));
    std::vector<axio::FeatureSnapshot> h_validation_x(horizon_x.begin() + static_cast<std::ptrdiff_t>(h_train_end),
                                                       horizon_x.begin() + static_cast<std::ptrdiff_t>(h_validation_end));
    std::vector<axio::Label> h_validation_y(horizon_y.begin() + static_cast<std::ptrdiff_t>(h_train_end),
                                            horizon_y.begin() + static_cast<std::ptrdiff_t>(h_validation_end));
    axio::LogisticModel model(0.02, 7);
    model.fit(h_train_x, h_train_y);
    model.calibrate(h_validation_x, h_validation_y);
    std::vector<axio::PredictionDistribution> predictions;
    std::vector<axio::Label> selected_labels;
    for (std::size_t i = h_validation_end; i < horizon_x.size(); ++i) {
      const auto& feature = horizon_x[i];
      const int minute = static_cast<int>(feature.x[10]);
      if (minute % 30 != 0 && std::abs(feature.x[2]) < 0.0035) continue;
      auto prediction = model.predict_distribution(feature, horizon);
      prediction.expected_net_value = std::abs(prediction.expected_return) - cost;
      prediction.lower_confidence_bound = prediction.expected_net_value - 1.645 * prediction.uncertainty;
      prediction.decision = prediction.lower_confidence_bound > 0.0 ?
          (prediction.expected_return > 0.0 ? axio::Decision::Long : axio::Decision::Short) : axio::Decision::NoTrade;
      predictions.push_back(prediction);
      selected_labels.push_back(horizon_y[i]);
    }
    return axio::evaluate_predictions(predictions, selected_labels, cost, 7);
  };
  std::ostringstream horizons;
  horizons << "{\"1\":" << metrics_json(direct_horizon(1))
           << ",\"5\":" << metrics_json(logistic_metrics)
           << ",\"15\":" << metrics_json(direct_horizon(15))
           << ",\"30\":" << metrics_json(direct_horizon(30)) << '}';
  std::vector<std::array<double, 4>> hmm_observations;
  hmm_observations.reserve(train_x.size());
  for (const auto& feature : train_x) {
    if (static_cast<int>(feature.x[10]) % 5 == 0)
      hmm_observations.push_back({feature.x[0], feature.x[3], feature.x[5], feature.x[7]});
  }
  std::string hmm_json = "[]";
  if (hmm_observations.size() >= 100U) {
    std::ostringstream hmm;
    hmm << '[';
    for (std::size_t states = 3U; states <= 8U; ++states) {
      axio::GaussianHmm model(states, 7);
      model.fit(hmm_observations, 12, 2);
      if (states > 3U) hmm << ',';
      hmm << model.diagnostics();
    }
    hmm << ']';
    hmm_json = hmm.str();
  }
  const bool promote = logistic_metrics.net_expectancy > 0.0 && logistic_metrics.bootstrap_low > 0.0 &&
                       logistic_metrics.expected_calibration_error < 0.05;
  std::ostringstream report;
  report << "{\n  \"evidence\": \"REAL_MASSIVE_AGGREGATES_UNDERLYING_ONLY\",\n"
         << "  \"nasdaq_scope\": \"QBBO_ADAPTER_IMPLEMENTED_BUT_NO_LICENSED_CAPTURE_PRESENT\",\n"
         << "  \"spxw_options\": \"NOT_EXECUTED_NO_OPRA_NBBO\",\n"
         << "  \"holdout_status\": \"CONTAMINATED_EXISTING_HISTORY_EXPLORATORY_OOS_ONLY\",\n"
         << "  \"data_sha256\": \"" << data.manifest.content_sha256 << "\",\n"
         << "  \"rows\": " << data.manifest.rows << ",\n  \"aligned_samples\": " << x.size() << ",\n"
         << "  \"replay\": " << axio::to_json(data.replay) << ",\n"
         << "  \"baselines_5m\": " << baselines.str() << ",\n"
         << "  \"direct_logistic_horizons\": " << horizons.str() << ",\n"
         << "  \"logistic\": " << metrics_json(logistic_metrics) << ",\n"
         << "  \"analog\": " << metrics_json(analog_metrics) << ",\n"
         << "  \"hmm_candidates\": " << hmm_json << ",\n"
         << "  \"promotion_decision\": \"" << (promote ? "CANDIDATE_REQUIRES_NEW_FROZEN_FUTURE" : "REJECTED_NO_DEPLOYABLE_EDGE") << "\"\n}\n";
  write_file(report_path, report.str());
  std::cout << report.str();
  return promote ? 0 : 2;
}

void usage() {
  std::cout << "Axio Quant OS native CLI\n\n"
            << "quantctl status\n"
            << "quantctl replay --data <market_bars.csv>\n"
            << "quantctl train|evaluate --data <market_bars.csv> --report <report.json>\n"
            << "quantctl predict --data <market_bars.csv>\n"
            << "quantctl data nasdaq-qbbo --capture <file> --date YYYY-MM-DD\n"
            << "quantctl paper start|stop\n"
            << "quantctl risk pause|resume\n"
            << "quantctl ledger init|check [--db <ledger.sqlite3>]\n";
}

} // namespace

int main(int argc, char** argv) {
  try {
    if (argc < 2) { usage(); return 1; }
    const auto root = find_root(std::filesystem::current_path());
    const std::string command = argv[1];
    const auto default_csv = root / "quant_engine_rs" / "data" / "normalized" / "market_bars.csv";
    const auto csv = std::filesystem::path(arg_value(argc, argv, "--data", default_csv.string()));
    if (command == "status") {
      const bool csv_present = std::filesystem::exists(default_csv);
      const bool nasdaq_configured = std::getenv("NASDAQ_TOTALVIEW_WS_URL") != nullptr;
      std::cout << "{\"service\":\"axio-quant-os\",\"core\":\"C++20\",\"mode\":\"RESEARCH_PAPER_ONLY\","
                << "\"kill_switch\":true,\"market_data_present\":" << (csv_present ? "true" : "false")
                << ",\"nasdaq_transport_configured\":" << (nasdaq_configured ? "true" : "false")
                << ",\"nasdaq_semantics\":\"EXCHANGE_BBO_NOT_NBBO\",\"spxw_backtest\":\"DISABLED_NO_OPRA\"}\n";
      return 0;
    }
    if (command == "replay") {
      auto data = load_dataset(csv);
      std::cout << axio::to_json(data.replay) << '\n';
      return 0;
    }
    if (command == "train" || command == "evaluate") {
      const auto report = std::filesystem::path(arg_value(argc, argv, "--report",
          (root / "research" / "reports" / "native_oos_latest.json").string()));
      return evaluate(csv, report);
    }
    if (command == "predict") {
      auto data = load_dataset(csv);
      const auto labels = axio::make_labels(data.target_bars, 5);
      auto [x, y] = align(data.features, labels);
      if (x.size() < 100U) throw std::runtime_error("insufficient history");
      axio::AnalogKernelModel model(80, 20.0);
      model.fit(x, y);
      auto prediction = model.predict_distribution(x.back(), 5);
      prediction.expected_net_value = std::abs(prediction.expected_return) - 0.00015;
      prediction.lower_confidence_bound = prediction.expected_net_value - 1.645 * prediction.uncertainty /
          std::sqrt(std::max(prediction.effective_sample_size, 1.0));
      prediction.decision = axio::Decision::NoTrade; // Historical terminal point is not a live executable quote.
      prediction.evidence.push_back("HISTORICAL_RESEARCH_ONLY");
      std::cout << axio::to_json(prediction) << '\n';
      return 0;
    }
    if (command == "data" && argc >= 3 && std::string(argv[2]) == "nasdaq-qbbo") {
      const auto capture = arg_value(argc, argv, "--capture");
      const auto date = arg_value(argc, argv, "--date");
      if (capture.empty() || date.empty()) throw std::runtime_error("--capture and --date are required");
      axio::NasdaqQbboAdapter adapter(capture, date);
      const auto events = adapter.load();
      std::cout << "{\"source\":\"nasdaq_qbbo\",\"scope\":\"NASDAQ_BBO_NOT_NBBO\",\"quotes\":"
                << events.size() << ",\"sha256\":\"" << adapter.manifest().content_sha256 << "\"}\n";
      return 0;
    }
    const auto runtime = root / "data" / "state";
    if (command == "paper" && argc >= 3) {
      std::filesystem::create_directories(runtime);
      write_file(runtime / "paper.state", std::string(argv[2]) == "start" ? "STARTED\n" : "STOPPED\n");
      std::cout << "{\"paper\":\"" << json_escape(argv[2]) << "\",\"kill_switch\":true}\n";
      return 0;
    }
    if (command == "risk" && argc >= 3) {
      std::filesystem::create_directories(runtime);
      write_file(runtime / "risk.state", std::string(argv[2]) == "resume" ? "ACTIVE\n" : "PAUSED\n");
      std::cout << "{\"risk\":\"" << json_escape(argv[2]) << "\"}\n";
      return 0;
    }
    if (command == "ledger" && argc >= 3) {
      const auto database = std::filesystem::path(arg_value(argc, argv, "--db",
          (root / "data" / "state" / "ledger.sqlite3").string()));
      axio::Ledger ledger(database);
      ledger.initialize(root / "ledger" / "schema.sql");
      if (std::string(argv[2]) == "init") std::cout << "{\"ledger\":\"initialized\"}\n";
      else if (std::string(argv[2]) == "check") {
        const bool balanced = ledger.balanced();
        std::cout << "{\"balanced\":" << (balanced ? "true" : "false")
                  << ",\"audit_hash\":\"" << ledger.audit_hash() << "\"}\n";
        return balanced ? 0 : 3;
      }
      return 0;
    }
    usage();
    return 1;
  } catch (const std::exception& error) {
    std::cerr << "quantctl: " << error.what() << '\n';
    return 1;
  }
}
