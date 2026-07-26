#pragma once

#include <array>
#include <chrono>
#include <cstdint>
#include <filesystem>
#include <functional>
#include <map>
#include <memory>
#include <optional>
#include <span>
#include <string>
#include <string_view>
#include <unordered_map>
#include <vector>

struct sqlite3;

namespace axio {

using Timestamp = std::int64_t; // UTC nanoseconds since Unix epoch.

enum class EventKind { Bar, Quote, Trade, ScheduledEvent };
enum class DataScope { Consolidated, NasdaqBbo, NasdaqDepth, Indicative, Synthetic };
enum class Side { Flat = 0, Long = 1, Short = -1 };
enum class Decision { NoTrade, Long, Short };
enum class OrderState { Created, RiskRejected, Submitted, PartiallyFilled, Filled, Cancelled };

struct EventMeta {
  std::string event_id;
  std::string source;
  std::string source_version;
  std::string lineage_hash;
  std::uint64_t sequence{};
  Timestamp event_time{};
  Timestamp available_time{};
  DataScope scope{DataScope::Consolidated};
};

struct Bar {
  EventMeta meta;
  std::string symbol;
  Timestamp open_time{};
  Timestamp close_time{};
  double open{};
  double high{};
  double low{};
  double close{};
  double volume{};
  std::optional<double> vendor_vwap;
  std::uint32_t trade_count{};
  bool finalized{};
  bool adjusted{};
};

struct Quote {
  EventMeta meta;
  std::string symbol;
  double bid{};
  double ask{};
  std::uint32_t bid_size{};
  std::uint32_t ask_size{};
};

struct TradePrint {
  EventMeta meta;
  std::string symbol;
  double price{};
  std::uint32_t size{};
  std::int8_t aggressor{};
};

struct MarketEvent {
  EventKind kind{EventKind::Bar};
  std::optional<Bar> bar;
  std::optional<Quote> quote;
  std::optional<TradePrint> trade;
};

struct DataManifest {
  std::string source;
  DataScope scope{DataScope::Consolidated};
  std::string schema_version;
  std::string content_sha256;
  std::vector<std::string> symbols;
  Timestamp first_timestamp{};
  Timestamp last_timestamp{};
  std::uint64_t rows{};
  std::uint64_t rejected_rows{};
  std::uint64_t duplicate_rows{};
};

class MarketDataAdapter {
public:
  virtual ~MarketDataAdapter() = default;
  virtual std::string name() const = 0;
  virtual DataScope scope() const = 0;
  virtual std::vector<MarketEvent> load() = 0;
  virtual const DataManifest& manifest() const = 0;
};

class CsvBarAdapter final : public MarketDataAdapter {
public:
  CsvBarAdapter(std::filesystem::path path, std::vector<std::string> symbols);
  std::string name() const override;
  DataScope scope() const override;
  std::vector<MarketEvent> load() override;
  const DataManifest& manifest() const override;
private:
  std::filesystem::path path_;
  std::vector<std::string> symbols_;
  DataManifest manifest_;
};

// Decoder for the exchange-specific Nasdaq QBBO quotation message.  This is
// explicitly Nasdaq BBO, never represented as consolidated NBBO.
class NasdaqQbboAdapter final : public MarketDataAdapter {
public:
  explicit NasdaqQbboAdapter(std::filesystem::path capture_path, std::string session_date);
  std::string name() const override;
  DataScope scope() const override;
  std::vector<MarketEvent> load() override;
  const DataManifest& manifest() const override;
  static Quote decode_quote(std::span<const std::byte> message, Timestamp midnight_utc_ns,
                            std::uint64_t sequence);
private:
  std::filesystem::path path_;
  std::string session_date_;
  DataManifest manifest_;
};

std::string sha256(std::string_view value);
std::string sha256_file(const std::filesystem::path& path);
std::string stable_event_hash(const MarketEvent& event);

struct FeatureSnapshot {
  static constexpr std::size_t kDimension = 15;
  Timestamp timestamp{};
  std::string symbol;
  std::array<double, kDimension> x{};
  std::array<std::string_view, kDimension> names{
      "ret_1m", "ret_5m", "ret_15m", "rv_15m", "range", "session_vwap_distance",
      "session_range_position", "rvol_same_minute", "volume_acceleration",
      "close_location", "minutes_from_open", "minutes_to_close", "qqq_relative_5m",
      "iwm_relative_5m", "spread_bps"};
  std::string lineage_hash;
  bool warm{};
};

class IncrementalFeatureStore {
public:
  explicit IncrementalFeatureStore(std::string target = "SPY");
  ~IncrementalFeatureStore();
  IncrementalFeatureStore(IncrementalFeatureStore&&) noexcept;
  IncrementalFeatureStore& operator=(IncrementalFeatureStore&&) noexcept;
  IncrementalFeatureStore(const IncrementalFeatureStore&) = delete;
  IncrementalFeatureStore& operator=(const IncrementalFeatureStore&) = delete;
  std::optional<FeatureSnapshot> on_event(const MarketEvent& event);
  const std::vector<FeatureSnapshot>& snapshots() const;
private:
  struct Impl;
  std::unique_ptr<Impl> impl_;
};

struct Label {
  Timestamp signal_time{};
  Timestamp entry_time{};
  Timestamp end_time{};
  int horizon_minutes{};
  double log_return{};
  double mfe{};
  double mae{};
};

std::vector<Label> make_labels(const std::vector<Bar>& bars, int horizon_minutes);
bool is_regular_session_bar(const Bar& bar);

struct PredictionDistribution {
  Timestamp timestamp{};
  int horizon_minutes{};
  double p_up{};
  double p_down{};
  double expected_return{};
  double median_return{};
  std::array<double, 6> quantiles{}; // q10, q25, q50, q75, q90, q99.
  double expected_volatility{};
  double volatility_expansion_probability{};
  double expected_mfe{};
  double expected_mae{};
  double uncertainty{};
  double effective_sample_size{};
  std::vector<double> regime_probabilities;
  double calibrated_confidence{};
  double expected_net_value{};
  double lower_confidence_bound{};
  Decision decision{Decision::NoTrade};
  std::string model_id;
  std::string prediction_hash;
  std::vector<std::string> evidence;
};

class DistributionModel {
public:
  virtual ~DistributionModel() = default;
  virtual std::string id() const = 0;
  virtual void fit(const std::vector<FeatureSnapshot>& x, const std::vector<Label>& y) = 0;
  virtual PredictionDistribution predict_distribution(const FeatureSnapshot& x,
                                                        int horizon_minutes) const = 0;
  virtual std::string diagnostics() const = 0;
  virtual void serialize(const std::filesystem::path& path) const = 0;
};

class BaselineModel final : public DistributionModel {
public:
  enum class Kind { AlwaysUp, AlwaysDown, FiftyFifty, RollingMean, Momentum, MeanReversion };
  explicit BaselineModel(Kind kind);
  std::string id() const override;
  void fit(const std::vector<FeatureSnapshot>& x, const std::vector<Label>& y) override;
  PredictionDistribution predict_distribution(const FeatureSnapshot& x,
                                                int horizon_minutes) const override;
  std::string diagnostics() const override;
  void serialize(const std::filesystem::path& path) const override;
private:
  Kind kind_;
  double mean_{};
  double volatility_{};
  std::vector<double> empirical_;
};

class LogisticModel final : public DistributionModel {
public:
  LogisticModel(double l2 = 0.01, std::uint64_t seed = 7);
  std::string id() const override;
  void fit(const std::vector<FeatureSnapshot>& x, const std::vector<Label>& y) override;
  void calibrate(const std::vector<FeatureSnapshot>& x, const std::vector<Label>& y);
  PredictionDistribution predict_distribution(const FeatureSnapshot& x,
                                                int horizon_minutes) const override;
  std::string diagnostics() const override;
  void serialize(const std::filesystem::path& path) const override;
private:
  double l2_;
  std::uint64_t seed_;
  std::array<double, FeatureSnapshot::kDimension> mean_{};
  std::array<double, FeatureSnapshot::kDimension> scale_{};
  std::array<double, FeatureSnapshot::kDimension> weights_{};
  double intercept_{};
  double platt_a_{1.0};
  double platt_b_{};
  double return_mean_{};
  double return_std_{};
  std::vector<double> empirical_;
};

class GaussianHmm {
public:
  explicit GaussianHmm(std::size_t states, std::uint64_t seed = 7);
  void fit(const std::vector<std::array<double, 4>>& observations,
           std::size_t iterations = 30, std::size_t restarts = 3);
  std::vector<double> filter(const std::array<double, 4>& observation);
  std::vector<double> next_state_probabilities() const;
  double bic() const;
  std::string diagnostics() const;
private:
  struct Impl;
  std::shared_ptr<Impl> impl_;
};

struct AnalogCase {
  Timestamp timestamp{};
  double distance{};
  double weight{};
  double outcome{};
  std::string day_key;
};

class AnalogKernelModel final : public DistributionModel {
public:
  explicit AnalogKernelModel(std::size_t neighbors = 80, double min_effective_sample = 20.0);
  std::string id() const override;
  void fit(const std::vector<FeatureSnapshot>& x, const std::vector<Label>& y) override;
  PredictionDistribution predict_distribution(const FeatureSnapshot& x,
                                                int horizon_minutes) const override;
  std::vector<AnalogCase> analogs(const FeatureSnapshot& x) const;
  std::string diagnostics() const override;
  void serialize(const std::filesystem::path& path) const override;
private:
  std::size_t neighbors_;
  double min_effective_sample_;
  std::vector<FeatureSnapshot> x_;
  std::vector<Label> y_;
  std::array<double, FeatureSnapshot::kDimension> median_{};
  std::array<double, FeatureSnapshot::kDimension> scale_{};
};

struct PurgedFold {
  std::vector<std::size_t> train;
  std::vector<std::size_t> validation;
  std::vector<std::size_t> test;
};

std::vector<PurgedFold> purged_walk_forward(const std::vector<Label>& labels,
                                            int train_days, int validation_days,
                                            int test_days, int embargo_minutes);

struct EvaluationMetrics {
  std::size_t samples{};
  std::size_t trades{};
  double brier{};
  double log_loss{};
  double expected_calibration_error{};
  double net_expectancy{};
  double trade_expectancy{};
  double win_rate{};
  double bootstrap_low{};
  double bootstrap_high{};
};

EvaluationMetrics evaluate_predictions(const std::vector<PredictionDistribution>& predictions,
                                       const std::vector<Label>& labels,
                                       double round_trip_cost, std::uint64_t seed = 7);

struct RiskConfig {
  double max_daily_loss{0.01};
  double max_position{1000.0};
  int max_trades_per_day{2};
  int cooldown_minutes{30};
  double max_uncertainty{0.004};
  double min_effective_sample{20.0};
  double max_spread_bps{5.0};
  int stale_quote_seconds{5};
};

struct RiskDecision {
  bool approved{};
  std::vector<std::string> reasons;
  std::string audit_hash;
};

class RiskEngine {
public:
  explicit RiskEngine(RiskConfig config = {});
  RiskDecision evaluate(const PredictionDistribution& prediction,
                        const std::optional<Quote>& quote, Timestamp now,
                        int trades_today, double daily_pnl, double proposed_quantity,
                        bool duplicate_order, bool kill_switch) const;
private:
  RiskConfig config_;
};

struct Order {
  std::string order_id;
  std::string idempotency_key;
  std::string symbol;
  Side side{Side::Flat};
  double quantity{};
  Timestamp signal_time{};
  Timestamp submitted_time{};
  OrderState state{OrderState::Created};
  std::string audit_hash;
};

struct Fill {
  std::string fill_id;
  std::string order_id;
  std::string symbol;
  Side side{Side::Flat};
  double quantity{};
  double price{};
  double fee{};
  double slippage{};
  Timestamp fill_time{};
};

class PaperOms {
public:
  Order submit(Order order, const RiskDecision& risk);
  std::optional<Fill> on_quote(const Quote& quote, Timestamp now);
  const std::vector<Order>& orders() const;
  const std::vector<Fill>& fills() const;
private:
  std::vector<Order> orders_;
  std::vector<Fill> fills_;
  std::unordered_map<std::string, std::size_t> idempotency_;
};

class Ledger {
public:
  explicit Ledger(const std::filesystem::path& database_path);
  ~Ledger();
  Ledger(const Ledger&) = delete;
  Ledger& operator=(const Ledger&) = delete;
  void initialize(const std::filesystem::path& schema_path);
  void record_fill(const Fill& fill);
  bool balanced() const;
  std::string audit_hash() const;
private:
  sqlite3* db_{};
};

struct ReplayResult {
  std::uint64_t events{};
  std::uint64_t feature_snapshots{};
  std::uint64_t rejected_unfinalized{};
  std::string event_hash;
  std::string feature_hash;
};

class ReplayEngine {
public:
  ReplayResult replay(std::vector<MarketEvent> events, IncrementalFeatureStore& store) const;
};

std::string to_json(const PredictionDistribution& value);
std::string to_json(const ReplayResult& value);
std::string decision_name(Decision value);

} // namespace axio
