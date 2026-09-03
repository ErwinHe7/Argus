#include "axio/quant_os.hpp"

#include <array>
#include <cmath>
#include <cstddef>
#include <filesystem>
#include <iostream>
#include <numeric>
#include <stdexcept>
#include <string>
#include <vector>

namespace {

int failures = 0;

#define CHECK(condition) do { if (!(condition)) { \
  std::cerr << "FAIL " << __FILE__ << ':' << __LINE__ << " " #condition "\n"; ++failures; } } while (false)

axio::Bar bar(axio::Timestamp open_time, double price, bool finalized = true,
              std::uint64_t sequence = 1U) {
  axio::Bar value;
  value.meta.source = "test";
  value.meta.sequence = sequence;
  value.meta.event_time = open_time;
  value.meta.available_time = open_time + 60LL * 1'000'000'000LL;
  value.symbol = "SPY";
  value.open_time = open_time;
  value.close_time = value.meta.available_time;
  value.open = price;
  value.high = price + 0.2;
  value.low = price - 0.2;
  value.close = price + 0.1;
  value.volume = 1000.0;
  value.finalized = finalized;
  axio::MarketEvent event{.kind = axio::EventKind::Bar, .bar = value};
  value.meta.lineage_hash = axio::stable_event_hash(event);
  return value;
}

void put_be(std::array<std::byte, 34>& bytes, std::size_t offset, std::size_t size,
            std::uint64_t value) {
  for (std::size_t i = 0; i < size; ++i) {
    bytes[offset + size - 1U - i] = static_cast<std::byte>(value & 0xffU);
    value >>= 8U;
  }
}

void test_qbbo_is_exchange_bbo() {
  std::array<std::byte, 34> message{};
  message[0] = static_cast<std::byte>('Q');
  const std::string symbol = "SPY     ";
  for (std::size_t i = 0; i < symbol.size(); ++i) message[9U + i] = static_cast<std::byte>(symbol[i]);
  message[17] = static_cast<std::byte>('P');
  put_be(message, 3U, 6U, 10ULL * 60ULL * 60ULL * 1'000'000'000ULL);
  put_be(message, 18U, 4U, 500'1200U);
  put_be(message, 22U, 4U, 100U);
  put_be(message, 26U, 4U, 500'1400U);
  put_be(message, 30U, 4U, 80U);
  const auto quote = axio::NasdaqQbboAdapter::decode_quote(message, 0, 9U);
  CHECK(quote.meta.scope == axio::DataScope::NasdaqBbo);
  CHECK(quote.symbol == "SPY");
  CHECK(std::abs(quote.bid - 500.12) < 1e-9);
  CHECK(std::abs(quote.ask - 500.14) < 1e-9);
}

void test_unfinalized_bar_is_not_visible() {
  const axio::Timestamp t = 1'720'450'600LL * 1'000'000'000LL;
  axio::IncrementalFeatureStore store;
  auto value = bar(t, 500.0, false);
  const auto output = store.on_event({.kind = axio::EventKind::Bar, .bar = value});
  CHECK(!output.has_value());
  CHECK(store.snapshots().empty());
}

void test_labels_enter_next_bar() {
  const axio::Timestamp t = 1'720'450'600LL * 1'000'000'000LL;
  std::vector<axio::Bar> bars;
  for (std::uint64_t i = 0; i < 10U; ++i) bars.push_back(bar(t + static_cast<axio::Timestamp>(i) * 60LL * 1'000'000'000LL,
                                                               500.0 + static_cast<double>(i), true, i));
  const auto labels = axio::make_labels(bars, 5);
  CHECK(!labels.empty());
  CHECK(labels.front().signal_time == bars[0].close_time);
  CHECK(labels.front().entry_time == bars[1].open_time);
  CHECK(labels.front().entry_time >= labels.front().signal_time);
}

void test_purge_removes_overlapping_response() {
  std::vector<axio::Label> labels;
  const axio::Timestamp day = 1'704'110'400LL * 1'000'000'000LL;
  for (int d = 0; d < 12; ++d) {
    const auto signal = day + static_cast<axio::Timestamp>(d) * 86'400LL * 1'000'000'000LL + 15LL * 60LL * 60LL * 1'000'000'000LL;
    labels.push_back({.signal_time = signal, .entry_time = signal + 60LL * 1'000'000'000LL,
                      .end_time = signal + 90LL * 60LL * 1'000'000'000LL, .horizon_minutes = 90});
  }
  const auto folds = axio::purged_walk_forward(labels, 6, 2, 2, 60);
  CHECK(!folds.empty());
  for (const auto index : folds.front().train) {
    for (const auto validation : folds.front().validation) {
      CHECK(labels[index].end_time < labels[validation].signal_time);
    }
  }
}

void test_analog_excludes_current_and_future_days() {
  std::vector<axio::FeatureSnapshot> x(80);
  std::vector<axio::Label> y(80);
  const axio::Timestamp start = 1'704'110'400LL * 1'000'000'000LL;
  for (std::size_t i = 0; i < x.size(); ++i) {
    x[i].timestamp = start + static_cast<axio::Timestamp>(i) * 86'400LL * 1'000'000'000LL +
                     15LL * 60LL * 60LL * 1'000'000'000LL;
    x[i].symbol = "SPY";
    x[i].x.fill(static_cast<double>(i) / 100.0);
    y[i] = {.signal_time = x[i].timestamp,
            .entry_time = x[i].timestamp + 60LL * 1'000'000'000LL,
            .end_time = x[i].timestamp + 6LL * 60LL * 1'000'000'000LL,
            .horizon_minutes = 5,
            .log_return = i % 2U == 0U ? 0.001 : -0.001};
  }
  axio::AnalogKernelModel model(30, 5.0);
  model.fit(x, y);
  auto query = x.back();
  query.timestamp += 86'400LL * 1'000'000'000LL;
  const auto analogs = model.analogs(query);
  CHECK(!analogs.empty());
  for (const auto& value : analogs) CHECK(value.timestamp < query.timestamp);
}

void test_stale_quote_is_rejected() {
  axio::PredictionDistribution prediction;
  prediction.decision = axio::Decision::Long;
  prediction.lower_confidence_bound = 0.001;
  prediction.effective_sample_size = 50.0;
  prediction.uncertainty = 0.001;
  axio::Quote quote;
  quote.bid = 500.0;
  quote.ask = 500.01;
  quote.meta.event_time = 1'000'000'000LL;
  const auto risk = axio::RiskEngine{}.evaluate(prediction, quote, 10'000'000'000LL, 0, 0.0, 10.0, false, false);
  CHECK(!risk.approved);
  CHECK(std::find(risk.reasons.begin(), risk.reasons.end(), "STALE_QUOTE") != risk.reasons.end());
}

void test_order_cannot_fill_before_submission() {
  axio::PaperOms oms;
  axio::RiskDecision risk{.approved = true, .audit_hash = "ok"};
  axio::Order order{.order_id = "o1", .idempotency_key = "k1", .symbol = "SPY",
                    .side = axio::Side::Long, .quantity = 1.0, .signal_time = 100,
                    .submitted_time = 200};
  oms.submit(order, risk);
  axio::Quote quote;
  quote.symbol = "SPY";
  quote.bid = 499.99;
  quote.ask = 500.01;
  quote.meta.event_time = 150;
  CHECK(!oms.on_quote(quote, 150).has_value());
  quote.meta.event_time = 201;
  CHECK(oms.on_quote(quote, 201).has_value());
}

void test_ledger_is_balanced_and_append_only() {
  const auto root = std::filesystem::path(__FILE__).parent_path().parent_path().parent_path();
  const auto temporary = std::filesystem::temp_directory_path() / "axio-ledger-test.sqlite3";
  std::error_code ignored;
  std::filesystem::remove(temporary, ignored);
  {
    axio::Ledger ledger(temporary);
    ledger.initialize(root / "ledger" / "schema.sql");
    ledger.record_fill({.fill_id = "f1", .order_id = "o1", .symbol = "SPY", .side = axio::Side::Long,
                        .quantity = 2.0, .price = 500.0, .fee = 1.0, .slippage = 0.5, .fill_time = 10});
    CHECK(ledger.balanced());
    CHECK(ledger.audit_hash().size() == 64U);
  }
  std::filesystem::remove(temporary, ignored);
}

void test_replay_hash_is_deterministic_and_lineage_changes() {
  const axio::Timestamp t = 1'720'450'600LL * 1'000'000'000LL;
  auto first_bar = bar(t, 500.0);
  std::vector<axio::MarketEvent> events{{.kind = axio::EventKind::Bar, .bar = first_bar}};
  axio::IncrementalFeatureStore first;
  axio::IncrementalFeatureStore second;
  const auto a = axio::ReplayEngine{}.replay(events, first);
  const auto b = axio::ReplayEngine{}.replay(events, second);
  CHECK(a.event_hash == b.event_hash);
  events.front().bar->close += 1.0;
  axio::IncrementalFeatureStore third;
  const auto c = axio::ReplayEngine{}.replay(events, third);
  CHECK(a.event_hash != c.event_hash);
}

void test_calibration_outputs_probability() {
  std::vector<axio::FeatureSnapshot> train_x(80), validation_x(30);
  std::vector<axio::Label> train_y(80), validation_y(30);
  for (std::size_t i = 0; i < train_x.size(); ++i) {
    train_x[i].x.fill(0.0);
    train_x[i].x[0] = static_cast<double>(i) / 80.0 - 0.5;
    train_y[i].log_return = train_x[i].x[0] > 0.0 ? 0.001 : -0.001;
  }
  for (std::size_t i = 0; i < validation_x.size(); ++i) {
    validation_x[i].x.fill(0.0);
    validation_x[i].x[0] = static_cast<double>(i) / 30.0 - 0.5;
    validation_y[i].log_return = validation_x[i].x[0] > 0.0 ? 0.001 : -0.001;
  }
  axio::LogisticModel model;
  model.fit(train_x, train_y);
  model.calibrate(validation_x, validation_y);
  const auto prediction = model.predict_distribution(validation_x.back(), 5);
  CHECK(prediction.p_up >= 0.0 && prediction.p_up <= 1.0);
  CHECK(prediction.p_up > 0.5);
}

void test_hmm_forward_backward_is_finite() {
  std::vector<std::array<double, 4>> observations;
  for (std::size_t i = 0; i < 360U; ++i) {
    const double regime = static_cast<double>((i / 60U) % 3U);
    observations.push_back({regime + std::sin(static_cast<double>(i) * 0.1) * 0.05,
                            0.2 + regime * 0.3,
                            -regime + std::cos(static_cast<double>(i) * 0.07) * 0.05,
                            1.0 + regime});
  }
  axio::GaussianHmm model(3, 7);
  model.fit(observations, 10, 2);
  CHECK(std::isfinite(model.bic()));
  const auto probabilities = model.filter(observations.back());
  CHECK(probabilities.size() == 3U);
  CHECK(std::abs(std::accumulate(probabilities.begin(), probabilities.end(), 0.0) - 1.0) < 1e-8);
}

} // namespace

int main() {
  test_qbbo_is_exchange_bbo();
  test_unfinalized_bar_is_not_visible();
  test_labels_enter_next_bar();
  test_purge_removes_overlapping_response();
  test_analog_excludes_current_and_future_days();
  test_stale_quote_is_rejected();
  test_order_cannot_fill_before_submission();
  test_ledger_is_balanced_and_append_only();
  test_replay_hash_is_deterministic_and_lineage_changes();
  test_calibration_outputs_probability();
  test_hmm_forward_backward_is_finite();
  if (failures == 0) std::cout << "11 native Quant OS tests passed\n";
  return failures == 0 ? 0 : 1;
}
