#include "axio/quant_os.hpp"

#include <openssl/evp.h>
#include <sqlite3.h>

#include <algorithm>
#include <atomic>
#include <bit>
#include <cmath>
#include <cstring>
#include <deque>
#include <fstream>
#include <iomanip>
#include <limits>
#include <numeric>
#include <random>
#include <set>
#include <sstream>
#include <stdexcept>
#include <unordered_set>

namespace axio {
namespace {

constexpr double kEpsilon = 1e-12;
constexpr std::int64_t kNsPerSecond = 1'000'000'000LL;
constexpr std::int64_t kNsPerMinute = 60LL * kNsPerSecond;
constexpr std::int64_t kNsPerDay = 86'400LL * kNsPerSecond;

std::int64_t days_from_civil(int year, unsigned month, unsigned day) {
  year -= month <= 2U ? 1 : 0;
  const int era = (year >= 0 ? year : year - 399) / 400;
  const unsigned yoe = static_cast<unsigned>(year - era * 400);
  const int adjusted_month = static_cast<int>(month) + (month > 2U ? -3 : 9);
  const unsigned doy = (153U * static_cast<unsigned>(adjusted_month) + 2U) / 5U + day - 1U;
  const unsigned doe = yoe * 365U + yoe / 4U - yoe / 100U + doy;
  return static_cast<std::int64_t>(era) * 146097LL + static_cast<std::int64_t>(doe) - 719468LL;
}

Timestamp parse_rfc3339(std::string_view value) {
  if (value.size() < 19U) {
    throw std::runtime_error("timestamp is not RFC3339: " + std::string(value));
  }
  auto number = [&](std::size_t pos, std::size_t count) {
    return std::stoi(std::string(value.substr(pos, count)));
  };
  const int year = number(0, 4);
  const unsigned month = static_cast<unsigned>(number(5, 2));
  const unsigned day = static_cast<unsigned>(number(8, 2));
  const int hour = number(11, 2);
  const int minute = number(14, 2);
  const int second = number(17, 2);
  std::int64_t nanos = 0;
  std::size_t tz_pos = 19;
  if (tz_pos < value.size() && value[tz_pos] == '.') {
    ++tz_pos;
    std::int64_t factor = 100'000'000LL;
    while (tz_pos < value.size() && std::isdigit(static_cast<unsigned char>(value[tz_pos])) != 0) {
      if (factor > 0) {
        nanos += static_cast<std::int64_t>(value[tz_pos] - '0') * factor;
        factor /= 10;
      }
      ++tz_pos;
    }
  }
  int offset_seconds = 0;
  if (tz_pos < value.size() && value[tz_pos] != 'Z') {
    const int sign = value[tz_pos] == '-' ? -1 : 1;
    if (tz_pos + 5U >= value.size()) {
      throw std::runtime_error("invalid RFC3339 offset");
    }
    offset_seconds = sign * (number(tz_pos + 1U, 2U) * 3600 + number(tz_pos + 4U, 2U) * 60);
  }
  const std::int64_t seconds = days_from_civil(year, month, day) * 86400LL +
                               static_cast<std::int64_t>(hour * 3600 + minute * 60 + second - offset_seconds);
  return seconds * kNsPerSecond + nanos;
}

int weekday_from_days(std::int64_t days) {
  int value = static_cast<int>((days + 4LL) % 7LL);
  return value < 0 ? value + 7 : value; // 0 Sunday.
}

unsigned nth_sunday(int year, unsigned month, unsigned nth) {
  const auto first = days_from_civil(year, month, 1U);
  const unsigned first_sunday = 1U + static_cast<unsigned>((7 - weekday_from_days(first)) % 7);
  return first_sunday + 7U * (nth - 1U);
}

int utc_year(Timestamp timestamp) {
  const std::time_t seconds = static_cast<std::time_t>(timestamp / kNsPerSecond);
  std::tm tm{};
#ifdef _WIN32
  gmtime_s(&tm, &seconds);
#else
  gmtime_r(&seconds, &tm);
#endif
  return tm.tm_year + 1900;
}

int eastern_offset_seconds(Timestamp timestamp) {
  const int year = utc_year(timestamp);
  const unsigned march_day = nth_sunday(year, 3U, 2U);
  const unsigned november_day = nth_sunday(year, 11U, 1U);
  const Timestamp dst_start = (days_from_civil(year, 3U, march_day) * 86400LL + 7LL * 3600LL) * kNsPerSecond;
  const Timestamp dst_end = (days_from_civil(year, 11U, november_day) * 86400LL + 6LL * 3600LL) * kNsPerSecond;
  return timestamp >= dst_start && timestamp < dst_end ? -4 * 3600 : -5 * 3600;
}

struct SessionClock {
  std::int64_t day{};
  int minute{};
  int minute_from_open{};
};

SessionClock eastern_clock(Timestamp timestamp) {
  const std::int64_t seconds = timestamp / kNsPerSecond + eastern_offset_seconds(timestamp);
  std::int64_t day = seconds / 86400LL;
  std::int64_t remainder = seconds % 86400LL;
  if (remainder < 0) {
    remainder += 86400LL;
    --day;
  }
  const int minute = static_cast<int>(remainder / 60LL);
  return {day, minute, minute - 570};
}

std::vector<std::string> split_csv(std::string_view line) {
  std::vector<std::string> out;
  std::string current;
  bool quoted = false;
  for (std::size_t i = 0; i < line.size(); ++i) {
    const char ch = line[i];
    if (ch == '"') {
      if (quoted && i + 1U < line.size() && line[i + 1U] == '"') {
        current.push_back('"');
        ++i;
      } else {
        quoted = !quoted;
      }
    } else if (ch == ',' && !quoted) {
      out.push_back(current);
      current.clear();
    } else {
      current.push_back(ch);
    }
  }
  out.push_back(current);
  return out;
}

double parse_double(const std::string& value) {
  if (value.empty()) {
    return 0.0;
  }
  return std::stod(value);
}

std::uint32_t parse_u32(const std::string& value) {
  if (value.empty()) {
    return 0U;
  }
  return static_cast<std::uint32_t>(std::stoul(value));
}

double mean(std::span<const double> values) {
  return values.empty() ? 0.0 : std::accumulate(values.begin(), values.end(), 0.0) /
                                    static_cast<double>(values.size());
}

double sample_std(std::span<const double> values) {
  if (values.size() < 2U) {
    return 0.0;
  }
  const double m = mean(values);
  const double total = std::accumulate(values.begin(), values.end(), 0.0,
                                       [m](double acc, double value) {
                                         return acc + (value - m) * (value - m);
                                       });
  return std::sqrt(total / static_cast<double>(values.size() - 1U));
}

double sigmoid(double value) {
  if (value >= 0.0) {
    return 1.0 / (1.0 + std::exp(-value));
  }
  const double exp_value = std::exp(value);
  return exp_value / (1.0 + exp_value);
}

double quantile(std::vector<double> values, double probability) {
  if (values.empty()) {
    return 0.0;
  }
  std::sort(values.begin(), values.end());
  const double location = probability * static_cast<double>(values.size() - 1U);
  const auto left = static_cast<std::size_t>(std::floor(location));
  const auto right = static_cast<std::size_t>(std::ceil(location));
  const double fraction = location - static_cast<double>(left);
  return values[left] * (1.0 - fraction) + values[right] * fraction;
}

std::string hex_digest(const unsigned char* bytes, std::size_t size) {
  std::ostringstream out;
  out << std::hex << std::setfill('0');
  for (std::size_t i = 0; i < size; ++i) {
    out << std::setw(2) << static_cast<unsigned int>(bytes[i]);
  }
  return out.str();
}

std::string escape_json(std::string_view value) {
  std::ostringstream out;
  for (const char ch : value) {
    if (ch == '"' || ch == '\\') {
      out << '\\' << ch;
    } else if (ch == '\n') {
      out << "\\n";
    } else {
      out << ch;
    }
  }
  return out.str();
}

std::string day_key(Timestamp timestamp) {
  return std::to_string(eastern_clock(timestamp).day);
}

std::uint64_t big_endian(std::span<const std::byte> bytes) {
  std::uint64_t output = 0;
  for (const auto byte : bytes) {
    output = (output << 8U) | static_cast<std::uint64_t>(std::to_integer<unsigned int>(byte));
  }
  return output;
}

void write_text(const std::filesystem::path& path, const std::string& value) {
  if (!path.parent_path().empty()) {
    std::filesystem::create_directories(path.parent_path());
  }
  std::ofstream stream(path, std::ios::binary | std::ios::trunc);
  if (!stream) {
    throw std::runtime_error("cannot write " + path.string());
  }
  stream << value;
}

} // namespace

std::string sha256(std::string_view value) {
  EVP_MD_CTX* context = EVP_MD_CTX_new();
  if (context == nullptr) {
    throw std::runtime_error("EVP_MD_CTX_new failed");
  }
  std::array<unsigned char, EVP_MAX_MD_SIZE> digest{};
  unsigned int length = 0U;
  const bool ok = EVP_DigestInit_ex(context, EVP_sha256(), nullptr) == 1 &&
                  EVP_DigestUpdate(context, value.data(), value.size()) == 1 &&
                  EVP_DigestFinal_ex(context, digest.data(), &length) == 1;
  EVP_MD_CTX_free(context);
  if (!ok) {
    throw std::runtime_error("SHA-256 failed");
  }
  return hex_digest(digest.data(), length);
}

std::string sha256_file(const std::filesystem::path& path) {
  std::ifstream stream(path, std::ios::binary);
  if (!stream) {
    throw std::runtime_error("cannot hash " + path.string());
  }
  EVP_MD_CTX* context = EVP_MD_CTX_new();
  if (context == nullptr || EVP_DigestInit_ex(context, EVP_sha256(), nullptr) != 1) {
    EVP_MD_CTX_free(context);
    throw std::runtime_error("SHA-256 initialization failed");
  }
  std::array<char, 64 * 1024> buffer{};
  while (stream) {
    stream.read(buffer.data(), static_cast<std::streamsize>(buffer.size()));
    if (stream.gcount() > 0 &&
        EVP_DigestUpdate(context, buffer.data(), static_cast<std::size_t>(stream.gcount())) != 1) {
      EVP_MD_CTX_free(context);
      throw std::runtime_error("SHA-256 update failed");
    }
  }
  std::array<unsigned char, EVP_MAX_MD_SIZE> digest{};
  unsigned int length = 0U;
  if (EVP_DigestFinal_ex(context, digest.data(), &length) != 1) {
    EVP_MD_CTX_free(context);
    throw std::runtime_error("SHA-256 finalization failed");
  }
  EVP_MD_CTX_free(context);
  return hex_digest(digest.data(), length);
}

std::string stable_event_hash(const MarketEvent& event) {
  std::ostringstream out;
  out << static_cast<int>(event.kind) << '|';
  if (event.bar) {
    const auto& value = *event.bar;
    out << value.meta.source << '|' << value.meta.sequence << '|' << value.meta.event_time << '|'
        << value.meta.available_time << '|' << value.symbol << '|' << std::setprecision(17)
        << value.open << '|' << value.high << '|' << value.low << '|' << value.close << '|'
        << value.volume << '|' << value.finalized;
  } else if (event.quote) {
    const auto& value = *event.quote;
    out << value.meta.source << '|' << value.meta.sequence << '|' << value.meta.event_time << '|'
        << value.symbol << '|' << std::setprecision(17) << value.bid << '|' << value.ask << '|'
        << value.bid_size << '|' << value.ask_size;
  } else if (event.trade) {
    const auto& value = *event.trade;
    out << value.meta.source << '|' << value.meta.sequence << '|' << value.meta.event_time << '|'
        << value.symbol << '|' << std::setprecision(17) << value.price << '|' << value.size;
  }
  return sha256(out.str());
}

CsvBarAdapter::CsvBarAdapter(std::filesystem::path path, std::vector<std::string> symbols)
    : path_(std::move(path)), symbols_(std::move(symbols)) {}

std::string CsvBarAdapter::name() const { return "normalized_csv"; }
DataScope CsvBarAdapter::scope() const { return DataScope::Consolidated; }
const DataManifest& CsvBarAdapter::manifest() const { return manifest_; }

std::vector<MarketEvent> CsvBarAdapter::load() {
  std::ifstream stream(path_);
  if (!stream) {
    throw std::runtime_error("cannot open market bars: " + path_.string());
  }
  std::unordered_set<std::string> filter(symbols_.begin(), symbols_.end());
  std::string header_line;
  std::getline(stream, header_line);
  const auto header = split_csv(header_line);
  std::unordered_map<std::string, std::size_t> column;
  for (std::size_t i = 0; i < header.size(); ++i) {
    column.emplace(header[i], i);
  }
  const std::array<std::string_view, 8> required{
      "timestamp", "symbol", "open", "high", "low", "close", "volume", "source"};
  for (const auto key : required) {
    if (!column.contains(std::string(key))) {
      throw std::runtime_error("missing CSV column: " + std::string(key));
    }
  }
  std::vector<MarketEvent> events;
  std::unordered_set<std::string> seen;
  std::set<std::string> loaded_symbols;
  std::string line;
  std::uint64_t sequence = 0U;
  manifest_ = {};
  manifest_.source = name();
  manifest_.scope = scope();
  manifest_.schema_version = "market-bar-v2";
  while (std::getline(stream, line)) {
    ++sequence;
    const auto values = split_csv(line);
    try {
      const auto get = [&](std::string_view key) -> const std::string& {
        const auto index = column.at(std::string(key));
        if (index >= values.size()) {
          throw std::runtime_error("short CSV row");
        }
        return values[index];
      };
      const std::string symbol = get("symbol");
      if (!filter.empty() && !filter.contains(symbol)) {
        continue;
      }
      const Timestamp timestamp = parse_rfc3339(get("timestamp"));
      const std::string identity = symbol + '|' + std::to_string(timestamp);
      if (!seen.insert(identity).second) {
        ++manifest_.duplicate_rows;
        continue;
      }
      Bar bar;
      bar.meta.source = get("source");
      bar.meta.source_version = "normalized-v2";
      bar.meta.sequence = sequence;
      bar.meta.event_time = timestamp;
      bar.meta.available_time = timestamp + kNsPerMinute;
      bar.meta.scope = DataScope::Consolidated;
      bar.symbol = symbol;
      bar.open_time = timestamp;
      bar.close_time = timestamp + kNsPerMinute;
      bar.open = parse_double(get("open"));
      bar.high = parse_double(get("high"));
      bar.low = parse_double(get("low"));
      bar.close = parse_double(get("close"));
      bar.volume = parse_double(get("volume"));
      if (column.contains("vwap") && !get("vwap").empty()) {
        bar.vendor_vwap = parse_double(get("vwap"));
      }
      if (column.contains("trade_count")) {
        bar.trade_count = parse_u32(get("trade_count"));
      }
      bar.finalized = true;
      bar.adjusted = false;
      const bool valid = bar.open > 0.0 && bar.high >= std::max({bar.open, bar.close, bar.low}) &&
                         bar.low <= std::min({bar.open, bar.close, bar.high}) && bar.volume >= 0.0;
      if (!valid) {
        ++manifest_.rejected_rows;
        continue;
      }
      MarketEvent event;
      event.kind = EventKind::Bar;
      event.bar = bar;
      event.bar->meta.lineage_hash = stable_event_hash(event);
      event.bar->meta.event_id = event.bar->meta.lineage_hash.substr(0, 24);
      events.push_back(std::move(event));
      loaded_symbols.insert(symbol);
      manifest_.first_timestamp = manifest_.rows == 0U ? timestamp : std::min(manifest_.first_timestamp, timestamp);
      manifest_.last_timestamp = manifest_.rows == 0U ? timestamp : std::max(manifest_.last_timestamp, timestamp);
      ++manifest_.rows;
    } catch (const std::exception&) {
      ++manifest_.rejected_rows;
    }
  }
  manifest_.symbols.assign(loaded_symbols.begin(), loaded_symbols.end());
  manifest_.content_sha256 = sha256_file(path_);
  return events;
}

NasdaqQbboAdapter::NasdaqQbboAdapter(std::filesystem::path capture_path, std::string session_date)
    : path_(std::move(capture_path)), session_date_(std::move(session_date)) {}

std::string NasdaqQbboAdapter::name() const { return "nasdaq_qbbo"; }
DataScope NasdaqQbboAdapter::scope() const { return DataScope::NasdaqBbo; }
const DataManifest& NasdaqQbboAdapter::manifest() const { return manifest_; }

Quote NasdaqQbboAdapter::decode_quote(std::span<const std::byte> message,
                                      Timestamp midnight_utc_ns, std::uint64_t sequence) {
  if (message.size() < 34U || std::to_integer<char>(message[0]) != 'Q') {
    throw std::runtime_error("not a 34-byte Nasdaq QBBO quotation message");
  }
  const auto nanos_after_midnight = static_cast<Timestamp>(big_endian(message.subspan(3U, 6U)));
  std::string symbol;
  for (const auto byte : message.subspan(9U, 8U)) {
    const char ch = std::to_integer<char>(byte);
    if (ch != ' ') {
      symbol.push_back(ch);
    }
  }
  Quote quote;
  quote.meta.source = "nasdaq_qbbo";
  quote.meta.source_version = "QBBO-2.1";
  quote.meta.scope = DataScope::NasdaqBbo;
  quote.meta.sequence = sequence;
  quote.meta.event_time = midnight_utc_ns + nanos_after_midnight;
  quote.meta.available_time = quote.meta.event_time;
  quote.symbol = symbol;
  quote.bid = static_cast<double>(big_endian(message.subspan(18U, 4U))) / 10'000.0;
  quote.bid_size = static_cast<std::uint32_t>(big_endian(message.subspan(22U, 4U)));
  quote.ask = static_cast<double>(big_endian(message.subspan(26U, 4U))) / 10'000.0;
  quote.ask_size = static_cast<std::uint32_t>(big_endian(message.subspan(30U, 4U)));
  MarketEvent event;
  event.kind = EventKind::Quote;
  event.quote = quote;
  quote.meta.lineage_hash = stable_event_hash(event);
  quote.meta.event_id = quote.meta.lineage_hash.substr(0, 24);
  return quote;
}

std::vector<MarketEvent> NasdaqQbboAdapter::load() {
  std::ifstream stream(path_, std::ios::binary);
  if (!stream) {
    throw std::runtime_error("cannot open Nasdaq QBBO capture: " + path_.string());
  }
  if (session_date_.size() != 10U) {
    throw std::runtime_error("Nasdaq capture session_date must be YYYY-MM-DD");
  }
  const int year = std::stoi(session_date_.substr(0, 4));
  const unsigned month = static_cast<unsigned>(std::stoul(session_date_.substr(5, 2)));
  const unsigned day = static_cast<unsigned>(std::stoul(session_date_.substr(8, 2)));
  // The feed timestamp is Eastern time since midnight.  The capture date offset is
  // evaluated at noon, which is safe across the U.S. DST transition boundary.
  const Timestamp utc_noon = (days_from_civil(year, month, day) * 86400LL + 12LL * 3600LL) * kNsPerSecond;
  const Timestamp midnight = days_from_civil(year, month, day) * kNsPerDay -
                             static_cast<Timestamp>(eastern_offset_seconds(utc_noon)) * kNsPerSecond;
  std::vector<MarketEvent> events;
  std::set<std::string> symbols;
  std::uint64_t sequence = 0U;
  manifest_ = {};
  manifest_.source = name();
  manifest_.scope = scope();
  manifest_.schema_version = "QBBO-2.1";
  while (stream) {
    std::array<std::byte, 34> message{};
    stream.read(reinterpret_cast<char*>(message.data()), static_cast<std::streamsize>(message.size()));
    if (stream.gcount() == 0) {
      break;
    }
    if (stream.gcount() != static_cast<std::streamsize>(message.size())) {
      ++manifest_.rejected_rows;
      break;
    }
    ++sequence;
    try {
      Quote quote = decode_quote(message, midnight, sequence);
      if (quote.bid <= 0.0 || quote.ask <= quote.bid) {
        ++manifest_.rejected_rows;
        continue;
      }
      symbols.insert(quote.symbol);
      manifest_.first_timestamp = manifest_.rows == 0U ? quote.meta.event_time :
                                  std::min(manifest_.first_timestamp, quote.meta.event_time);
      manifest_.last_timestamp = manifest_.rows == 0U ? quote.meta.event_time :
                                 std::max(manifest_.last_timestamp, quote.meta.event_time);
      MarketEvent event;
      event.kind = EventKind::Quote;
      event.quote = std::move(quote);
      events.push_back(std::move(event));
      ++manifest_.rows;
    } catch (const std::exception&) {
      ++manifest_.rejected_rows;
    }
  }
  manifest_.symbols.assign(symbols.begin(), symbols.end());
  manifest_.content_sha256 = sha256_file(path_);
  return events;
}

struct IncrementalFeatureStore::Impl {
  explicit Impl(std::string requested_target) : target(std::move(requested_target)) {}

  std::string target;
  std::unordered_map<std::string, std::deque<Bar>> history;
  std::unordered_map<std::string, Quote> quotes;
  std::vector<FeatureSnapshot> output;
  std::int64_t active_day{std::numeric_limits<std::int64_t>::min()};
  double cumulative_volume{};
  double cumulative_price_volume{};
  double session_high{};
  double session_low{};
  double session_open{};
  std::unordered_map<int, std::vector<double>> historical_cumulative_volume;
  std::vector<std::pair<int, double>> current_day_cumulative;

  void finish_day() {
    for (const auto& [minute, volume] : current_day_cumulative) {
      historical_cumulative_volume[minute].push_back(volume);
    }
    current_day_cumulative.clear();
  }

  double context_return(const std::string& symbol, Timestamp timestamp, std::size_t lookback) const {
    const auto found = history.find(symbol);
    if (found == history.end() || found->second.size() <= lookback) {
      return 0.0;
    }
    const auto& rows = found->second;
    const auto current = std::find_if(rows.rbegin(), rows.rend(), [timestamp](const Bar& bar) {
      return bar.close_time <= timestamp;
    });
    if (current == rows.rend()) {
      return 0.0;
    }
    const auto current_index = static_cast<std::size_t>(std::distance(rows.begin(), current.base()) - 1);
    if (current_index < lookback || rows[current_index - lookback].close <= 0.0) {
      return 0.0;
    }
    return std::log(rows[current_index].close / rows[current_index - lookback].close);
  }
};

IncrementalFeatureStore::IncrementalFeatureStore(std::string target)
    : impl_(std::make_unique<Impl>(std::move(target))) {}

IncrementalFeatureStore::~IncrementalFeatureStore() = default;
IncrementalFeatureStore::IncrementalFeatureStore(IncrementalFeatureStore&&) noexcept = default;
IncrementalFeatureStore& IncrementalFeatureStore::operator=(IncrementalFeatureStore&&) noexcept = default;

const std::vector<FeatureSnapshot>& IncrementalFeatureStore::snapshots() const {
  return impl_->output;
}

std::optional<FeatureSnapshot> IncrementalFeatureStore::on_event(const MarketEvent& event) {
  if (event.quote) {
    impl_->quotes[event.quote->symbol] = *event.quote;
    return std::nullopt;
  }
  if (!event.bar || !event.bar->finalized) {
    return std::nullopt;
  }
  const Bar bar = *event.bar;
  auto& rows = impl_->history[bar.symbol];
  rows.push_back(bar);
  while (rows.size() > 256U) {
    rows.pop_front();
  }
  if (bar.symbol != impl_->target) {
    return std::nullopt;
  }
  const SessionClock clock = eastern_clock(bar.close_time);
  if (clock.minute < 570 || clock.minute >= 960) {
    return std::nullopt;
  }
  if (clock.day != impl_->active_day) {
    if (impl_->active_day != std::numeric_limits<std::int64_t>::min()) {
      impl_->finish_day();
    }
    impl_->active_day = clock.day;
    impl_->cumulative_volume = 0.0;
    impl_->cumulative_price_volume = 0.0;
    impl_->session_high = bar.high;
    impl_->session_low = bar.low;
    impl_->session_open = bar.open;
  }
  impl_->cumulative_volume += bar.volume;
  // Session VWAP is derived point-in-time from finalized bars.  The vendor `vw`
  // field is a per-bar average and must not replace cumulative session VWAP.
  const double typical = (bar.high + bar.low + bar.close) / 3.0;
  impl_->cumulative_price_volume += typical * bar.volume;
  impl_->session_high = std::max(impl_->session_high, bar.high);
  impl_->session_low = std::min(impl_->session_low, bar.low);
  impl_->current_day_cumulative.emplace_back(clock.minute, impl_->cumulative_volume);

  auto log_return = [&](std::size_t lookback) {
    if (rows.size() <= lookback) {
      return 0.0;
    }
    const double previous = rows[rows.size() - 1U - lookback].close;
    return previous > 0.0 ? std::log(bar.close / previous) : 0.0;
  };
  std::vector<double> one_minute_returns;
  const std::size_t start = rows.size() > 16U ? rows.size() - 16U : 1U;
  for (std::size_t i = start; i < rows.size(); ++i) {
    if (rows[i - 1U].close > 0.0) {
      one_minute_returns.push_back(std::log(rows[i].close / rows[i - 1U].close));
    }
  }
  const double session_vwap = impl_->cumulative_volume > 0.0 ?
      impl_->cumulative_price_volume / impl_->cumulative_volume : bar.close;
  const double session_range = impl_->session_high - impl_->session_low;
  const auto prior = impl_->historical_cumulative_volume.find(clock.minute);
  const double historical_mean = prior == impl_->historical_cumulative_volume.end() ? 0.0 :
                                 mean(prior->second);
  const double rvol = historical_mean > 0.0 ? impl_->cumulative_volume / historical_mean : 1.0;
  const double previous_volume = rows.size() > 1U ? rows[rows.size() - 2U].volume : bar.volume;
  const double volume_acceleration = previous_volume > 0.0 ? bar.volume / previous_volume - 1.0 : 0.0;
  const double bar_range = std::max(bar.high - bar.low, kEpsilon);
  double spread_bps = 0.0;
  if (const auto quote = impl_->quotes.find(bar.symbol); quote != impl_->quotes.end() &&
      quote->second.ask > quote->second.bid && quote->second.bid > 0.0) {
    spread_bps = (quote->second.ask - quote->second.bid) /
                 ((quote->second.ask + quote->second.bid) * 0.5) * 10'000.0;
  }
  FeatureSnapshot snapshot;
  snapshot.timestamp = bar.close_time;
  snapshot.symbol = bar.symbol;
  snapshot.x = {
      log_return(1U), log_return(5U), log_return(15U), sample_std(one_minute_returns),
      (bar.high - bar.low) / bar.close, std::log(bar.close / session_vwap),
      session_range > 0.0 ? (bar.close - impl_->session_low) / session_range : 0.5,
      rvol, volume_acceleration, ((bar.close - bar.low) - (bar.high - bar.close)) / bar_range,
      static_cast<double>(clock.minute_from_open), static_cast<double>(960 - clock.minute),
      impl_->context_return("QQQ", bar.close_time, 5U) - log_return(5U),
      impl_->context_return("IWM", bar.close_time, 5U) - log_return(5U), spread_bps};
  snapshot.warm = rows.size() >= 61U && prior != impl_->historical_cumulative_volume.end() &&
                  prior->second.size() >= 5U;
  std::ostringstream lineage;
  lineage << bar.meta.lineage_hash;
  for (const double value : snapshot.x) {
    lineage << '|' << std::setprecision(17) << value;
  }
  snapshot.lineage_hash = sha256(lineage.str());
  impl_->output.push_back(snapshot);
  return snapshot;
}

std::vector<Label> make_labels(const std::vector<Bar>& input, int horizon_minutes) {
  std::vector<Bar> bars = input;
  std::sort(bars.begin(), bars.end(), [](const Bar& left, const Bar& right) {
    return left.close_time < right.close_time;
  });
  std::vector<Label> labels;
  for (std::size_t i = 0; i + 1U < bars.size(); ++i) {
    const std::size_t entry = i + 1U;
    const auto signal_clock = eastern_clock(bars[i].close_time);
    if (eastern_clock(bars[entry].open_time).day != signal_clock.day) {
      continue;
    }
    std::size_t end = entry;
    const Timestamp target = bars[entry].open_time + static_cast<Timestamp>(horizon_minutes) * kNsPerMinute;
    while (end + 1U < bars.size() && bars[end + 1U].close_time <= target &&
           eastern_clock(bars[end + 1U].close_time).day == signal_clock.day) {
      ++end;
    }
    if (bars[entry].open <= 0.0) {
      continue;
    }
    const double entry_price = bars[entry].open;
    double high = bars[entry].high;
    double low = bars[entry].low;
    for (std::size_t j = entry; j <= end; ++j) {
      high = std::max(high, bars[j].high);
      low = std::min(low, bars[j].low);
    }
    labels.push_back({.signal_time = bars[i].close_time,
                      .entry_time = bars[entry].open_time,
                      .end_time = bars[end].close_time,
                      .horizon_minutes = horizon_minutes,
                      .log_return = std::log(bars[end].close / entry_price),
                      .mfe = high / entry_price - 1.0,
                      .mae = entry_price / low - 1.0});
  }
  return labels;
}

bool is_regular_session_bar(const Bar& bar) {
  const SessionClock clock = eastern_clock(bar.open_time);
  return clock.minute >= 570 && clock.minute < 960;
}

BaselineModel::BaselineModel(Kind kind) : kind_(kind) {}

std::string BaselineModel::id() const {
  switch (kind_) {
    case Kind::AlwaysUp: return "baseline_always_up";
    case Kind::AlwaysDown: return "baseline_always_down";
    case Kind::FiftyFifty: return "baseline_fifty_fifty";
    case Kind::RollingMean: return "baseline_rolling_mean";
    case Kind::Momentum: return "baseline_momentum";
    case Kind::MeanReversion: return "baseline_mean_reversion";
  }
  return "baseline_unknown";
}

void BaselineModel::fit(const std::vector<FeatureSnapshot>&, const std::vector<Label>& y) {
  empirical_.clear();
  empirical_.reserve(y.size());
  for (const auto& label : y) {
    empirical_.push_back(label.log_return);
  }
  mean_ = mean(empirical_);
  volatility_ = sample_std(empirical_);
}

PredictionDistribution BaselineModel::predict_distribution(const FeatureSnapshot& x,
                                                             int horizon_minutes) const {
  PredictionDistribution output;
  output.timestamp = x.timestamp;
  output.horizon_minutes = horizon_minutes;
  double signal = mean_;
  if (kind_ == Kind::AlwaysUp) signal = std::abs(mean_) + 1e-6;
  if (kind_ == Kind::AlwaysDown) signal = -std::abs(mean_) - 1e-6;
  if (kind_ == Kind::FiftyFifty) signal = 0.0;
  if (kind_ == Kind::Momentum) signal = x.x[2];
  if (kind_ == Kind::MeanReversion) signal = -x.x[5];
  output.expected_return = signal;
  output.median_return = empirical_.empty() ? signal : quantile(empirical_, 0.5);
  output.p_up = kind_ == Kind::AlwaysUp ? 1.0 : kind_ == Kind::AlwaysDown ? 0.0 :
                kind_ == Kind::FiftyFifty ? 0.5 : sigmoid(signal / std::max(volatility_, 1e-6));
  output.p_down = 1.0 - output.p_up;
  const std::array<double, 6> probabilities{0.10, 0.25, 0.50, 0.75, 0.90, 0.99};
  for (std::size_t i = 0; i < probabilities.size(); ++i) {
    output.quantiles[i] = empirical_.empty() ? signal : quantile(empirical_, probabilities[i]);
  }
  output.expected_volatility = volatility_;
  output.uncertainty = volatility_;
  output.effective_sample_size = static_cast<double>(empirical_.size());
  output.calibrated_confidence = std::max(output.p_up, output.p_down);
  output.model_id = id();
  output.prediction_hash = sha256(to_json(output));
  return output;
}

std::string BaselineModel::diagnostics() const {
  return "{\"model\":\"" + id() + "\",\"samples\":" + std::to_string(empirical_.size()) +
         ",\"mean\":" + std::to_string(mean_) + "}";
}

void BaselineModel::serialize(const std::filesystem::path& path) const {
  write_text(path, diagnostics());
}

LogisticModel::LogisticModel(double l2, std::uint64_t seed) : l2_(l2), seed_(seed) {}
std::string LogisticModel::id() const { return "regularized_logistic_platt"; }

void LogisticModel::fit(const std::vector<FeatureSnapshot>& x, const std::vector<Label>& y) {
  const std::size_t count = std::min(x.size(), y.size());
  if (count < 20U) {
    throw std::runtime_error("logistic regression requires at least 20 samples");
  }
  empirical_.clear();
  empirical_.reserve(count);
  for (std::size_t j = 0; j < FeatureSnapshot::kDimension; ++j) {
    std::vector<double> values;
    values.reserve(count);
    for (std::size_t i = 0; i < count; ++i) values.push_back(x[i].x[j]);
    mean_[j] = mean(values);
    scale_[j] = std::max(sample_std(values), 1e-9);
  }
  const double positive_rate = std::clamp(
      std::accumulate(y.begin(), y.begin() + static_cast<std::ptrdiff_t>(count), 0.0,
                      [](double sum, const Label& label) { return sum + (label.log_return > 0.0 ? 1.0 : 0.0); }) /
          static_cast<double>(count),
      1e-5, 1.0 - 1e-5);
  intercept_ = std::log(positive_rate / (1.0 - positive_rate));
  weights_.fill(0.0);
  for (std::size_t epoch = 0; epoch < 250U; ++epoch) {
    const double learning_rate = 0.08 / (1.0 + static_cast<double>(epoch) * 0.015);
    std::array<double, FeatureSnapshot::kDimension> gradient{};
    double intercept_gradient = 0.0;
    for (std::size_t i = 0; i < count; ++i) {
      double score = intercept_;
      for (std::size_t j = 0; j < FeatureSnapshot::kDimension; ++j) {
        score += weights_[j] * (x[i].x[j] - mean_[j]) / scale_[j];
      }
      const double target = y[i].log_return > 0.0 ? 1.0 : 0.0;
      const double error = sigmoid(score) - target;
      intercept_gradient += error;
      for (std::size_t j = 0; j < FeatureSnapshot::kDimension; ++j) {
        gradient[j] += error * (x[i].x[j] - mean_[j]) / scale_[j];
      }
    }
    intercept_ -= learning_rate * intercept_gradient / static_cast<double>(count);
    for (std::size_t j = 0; j < FeatureSnapshot::kDimension; ++j) {
      weights_[j] -= learning_rate * (gradient[j] / static_cast<double>(count) + l2_ * weights_[j]);
    }
  }
  for (std::size_t i = 0; i < count; ++i) empirical_.push_back(y[i].log_return);
  return_mean_ = mean(empirical_);
  return_std_ = sample_std(empirical_);
}

void LogisticModel::calibrate(const std::vector<FeatureSnapshot>& x, const std::vector<Label>& y) {
  const std::size_t count = std::min(x.size(), y.size());
  if (count < 20U) {
    throw std::runtime_error("Platt calibration requires an independent validation set of 20 samples");
  }
  platt_a_ = 1.0;
  platt_b_ = 0.0;
  for (std::size_t epoch = 0; epoch < 300U; ++epoch) {
    double grad_a = 0.0;
    double grad_b = 0.0;
    for (std::size_t i = 0; i < count; ++i) {
      double raw = intercept_;
      for (std::size_t j = 0; j < FeatureSnapshot::kDimension; ++j) {
        raw += weights_[j] * (x[i].x[j] - mean_[j]) / scale_[j];
      }
      const double target = y[i].log_return > 0.0 ? 1.0 : 0.0;
      const double error = sigmoid(platt_a_ * raw + platt_b_) - target;
      grad_a += error * raw;
      grad_b += error;
    }
    const double rate = 0.05 / (1.0 + static_cast<double>(epoch) * 0.01);
    platt_a_ -= rate * grad_a / static_cast<double>(count);
    platt_b_ -= rate * grad_b / static_cast<double>(count);
  }
}

PredictionDistribution LogisticModel::predict_distribution(const FeatureSnapshot& x,
                                                             int horizon_minutes) const {
  double raw = intercept_;
  for (std::size_t j = 0; j < FeatureSnapshot::kDimension; ++j) {
    raw += weights_[j] * (x.x[j] - mean_[j]) / std::max(scale_[j], 1e-9);
  }
  PredictionDistribution output;
  output.timestamp = x.timestamp;
  output.horizon_minutes = horizon_minutes;
  output.p_up = sigmoid(platt_a_ * raw + platt_b_);
  output.p_down = 1.0 - output.p_up;
  output.expected_return = return_mean_ + (output.p_up - 0.5) * return_std_;
  output.median_return = empirical_.empty() ? output.expected_return : quantile(empirical_, 0.5);
  const std::array<double, 6> probabilities{0.10, 0.25, 0.50, 0.75, 0.90, 0.99};
  for (std::size_t i = 0; i < probabilities.size(); ++i) {
    output.quantiles[i] = empirical_.empty() ? output.expected_return : quantile(empirical_, probabilities[i]);
  }
  output.expected_volatility = return_std_;
  output.volatility_expansion_probability = std::clamp(x.x[3] / std::max(return_std_, 1e-9), 0.0, 1.0);
  output.expected_mfe = std::max(output.quantiles[4], 0.0);
  output.expected_mae = std::max(-output.quantiles[0], 0.0);
  output.uncertainty = return_std_;
  output.effective_sample_size = static_cast<double>(empirical_.size());
  output.calibrated_confidence = std::max(output.p_up, output.p_down);
  output.model_id = id();
  output.prediction_hash = sha256(to_json(output));
  return output;
}

std::string LogisticModel::diagnostics() const {
  std::ostringstream out;
  out << "{\"model\":\"" << id() << "\",\"l2\":" << l2_ << ",\"seed\":" << seed_
      << ",\"samples\":" << empirical_.size() << ",\"platt_a\":" << platt_a_
      << ",\"platt_b\":" << platt_b_ << '}';
  return out.str();
}

void LogisticModel::serialize(const std::filesystem::path& path) const { write_text(path, diagnostics()); }

struct GaussianHmm::Impl {
  explicit Impl(std::size_t count, std::uint64_t random_seed)
      : states(count), seed(random_seed), pi(count, 1.0 / static_cast<double>(count)),
        transition(count, std::vector<double>(count, 1.0 / static_cast<double>(count))),
        means(count), variances(count), filtered(pi) {
    for (auto& variance : variances) variance.fill(1.0);
  }
  std::size_t states;
  std::uint64_t seed;
  std::vector<double> pi;
  std::vector<std::vector<double>> transition;
  std::vector<std::array<double, 4>> means;
  std::vector<std::array<double, 4>> variances;
  std::vector<double> filtered;
  std::array<double, 4> observation_mean{};
  std::array<double, 4> observation_scale{1.0, 1.0, 1.0, 1.0};
  double log_likelihood{-std::numeric_limits<double>::infinity()};
  std::size_t observations{};

  double emission(std::size_t state, const std::array<double, 4>& value) const {
    double log_density = 0.0;
    constexpr double two_pi = 6.28318530717958647692;
    for (std::size_t j = 0; j < 4U; ++j) {
      const double variance = std::max(variances[state][j], 1e-6);
      const double delta = value[j] - means[state][j];
      log_density += -0.5 * (std::log(two_pi * variance) + delta * delta / variance);
    }
    return std::exp(std::clamp(log_density, -700.0, 50.0));
  }
};

GaussianHmm::GaussianHmm(std::size_t states, std::uint64_t seed)
    : impl_(std::make_shared<Impl>(states, seed)) {
  if (states < 2U || states > 12U) throw std::runtime_error("HMM state count must be 2..12");
}

void GaussianHmm::fit(const std::vector<std::array<double, 4>>& observations,
                      std::size_t iterations, std::size_t restarts) {
  if (observations.size() < impl_->states * 10U) {
    throw std::runtime_error("HMM sample is too small");
  }
  std::array<double, 4> observation_mean{};
  std::array<double, 4> observation_scale{};
  for (std::size_t j = 0; j < 4U; ++j) {
    std::vector<double> values;
    values.reserve(observations.size());
    for (const auto& row : observations) values.push_back(row[j]);
    observation_mean[j] = mean(values);
    observation_scale[j] = std::max(sample_std(values), 1e-9);
  }
  std::vector<std::array<double, 4>> normalized = observations;
  for (auto& row : normalized) {
    for (std::size_t j = 0; j < 4U; ++j) row[j] = (row[j] - observation_mean[j]) / observation_scale[j];
  }
  std::shared_ptr<Impl> best;
  for (std::size_t restart = 0; restart < restarts; ++restart) {
    auto candidate = std::make_shared<Impl>(impl_->states, impl_->seed + restart);
    candidate->observation_mean = observation_mean;
    candidate->observation_scale = observation_scale;
    candidate->observations = observations.size();
    std::mt19937_64 rng(candidate->seed);
    std::uniform_int_distribution<std::size_t> picker(0U, observations.size() - 1U);
    for (std::size_t state = 0; state < candidate->states; ++state) {
      candidate->means[state] = normalized[picker(rng)];
    }
    for (std::size_t iteration = 0; iteration < iterations; ++iteration) {
      const std::size_t n = observations.size();
      const std::size_t k = candidate->states;
      std::vector<std::vector<double>> alpha(n, std::vector<double>(k));
      std::vector<std::vector<double>> beta(n, std::vector<double>(k, 1.0));
      std::vector<double> scales(n, 1.0);
      for (std::size_t state = 0; state < k; ++state) {
        alpha[0][state] = candidate->pi[state] * candidate->emission(state, normalized[0]);
      }
      scales[0] = std::accumulate(alpha[0].begin(), alpha[0].end(), 0.0);
      if (!std::isfinite(scales[0]) || scales[0] <= std::numeric_limits<double>::min()) {
        scales[0] = std::numeric_limits<double>::min();
        for (double& value : alpha[0]) value = 1.0 / static_cast<double>(k);
      } else {
        for (double& value : alpha[0]) value /= scales[0];
      }
      for (std::size_t t = 1; t < n; ++t) {
        for (std::size_t state = 0; state < k; ++state) {
          double incoming = 0.0;
          for (std::size_t previous = 0; previous < k; ++previous) {
            incoming += alpha[t - 1U][previous] * candidate->transition[previous][state];
          }
          alpha[t][state] = incoming * candidate->emission(state, normalized[t]);
        }
        scales[t] = std::accumulate(alpha[t].begin(), alpha[t].end(), 0.0);
        if (!std::isfinite(scales[t]) || scales[t] <= std::numeric_limits<double>::min()) {
          scales[t] = std::numeric_limits<double>::min();
          for (double& value : alpha[t]) value = 1.0 / static_cast<double>(k);
        } else {
          for (double& value : alpha[t]) value /= scales[t];
        }
      }
      for (std::size_t t = n - 1U; t-- > 0U;) {
        for (std::size_t state = 0; state < k; ++state) {
          beta[t][state] = 0.0;
          for (std::size_t next = 0; next < k; ++next) {
            beta[t][state] += candidate->transition[state][next] *
                                  candidate->emission(next, normalized[t + 1U]) * beta[t + 1U][next];
          }
        }
        const double beta_sum = std::accumulate(beta[t].begin(), beta[t].end(), 0.0);
        if (!std::isfinite(beta_sum) || beta_sum <= std::numeric_limits<double>::min()) {
          for (double& value : beta[t]) value = 1.0 / static_cast<double>(k);
        } else {
          for (double& value : beta[t]) value /= beta_sum;
        }
      }
      std::vector<std::vector<double>> gamma(n, std::vector<double>(k));
      for (std::size_t t = 0; t < n; ++t) {
        double total = 0.0;
        for (std::size_t state = 0; state < k; ++state) {
          gamma[t][state] = alpha[t][state] * beta[t][state];
          total += gamma[t][state];
        }
        if (!std::isfinite(total) || total <= std::numeric_limits<double>::min()) {
          gamma[t] = alpha[t];
        } else {
          for (double& value : gamma[t]) value /= total;
        }
      }
      candidate->pi = gamma[0];
      for (std::size_t from = 0; from < k; ++from) {
        std::vector<double> numerators(k, 0.0);
        double denominator = 0.0;
        for (std::size_t t = 0; t + 1U < n; ++t) {
          denominator += gamma[t][from];
          double xi_scale = 0.0;
          std::vector<double> xi(k);
          for (std::size_t to = 0; to < k; ++to) {
            xi[to] = alpha[t][from] * candidate->transition[from][to] *
                     candidate->emission(to, normalized[t + 1U]) * beta[t + 1U][to];
            xi_scale += xi[to];
          }
          if (std::isfinite(xi_scale) && xi_scale > std::numeric_limits<double>::min()) {
            for (std::size_t to = 0; to < k; ++to)
              numerators[to] += xi[to] / xi_scale * gamma[t][from];
          }
        }
        for (std::size_t to = 0; to < k; ++to) {
          candidate->transition[from][to] = (numerators[to] + 1e-3) /
              (denominator + 1e-3 * static_cast<double>(k));
        }
      }
      for (std::size_t state = 0; state < k; ++state) {
        const double responsibility = std::accumulate(gamma.begin(), gamma.end(), 0.0,
            [state](double sum, const auto& row) { return sum + row[state]; });
        if (!std::isfinite(responsibility) || responsibility < 1e-8) continue;
        for (std::size_t j = 0; j < 4U; ++j) {
          double weighted_mean = 0.0;
          for (std::size_t t = 0; t < n; ++t) weighted_mean += gamma[t][state] * normalized[t][j];
          candidate->means[state][j] = weighted_mean / std::max(responsibility, kEpsilon);
          double weighted_variance = 0.0;
          for (std::size_t t = 0; t < n; ++t) {
            const double delta = normalized[t][j] - candidate->means[state][j];
            weighted_variance += gamma[t][state] * delta * delta;
          }
          candidate->variances[state][j] = std::max(weighted_variance / std::max(responsibility, kEpsilon), 1e-6);
        }
      }
      candidate->log_likelihood = std::accumulate(scales.begin(), scales.end(), 0.0,
          [](double sum, double scale) {
            return sum + std::log(std::max(scale, std::numeric_limits<double>::min()));
          });
      candidate->filtered = alpha.back();
    }
    if (std::isfinite(candidate->log_likelihood) &&
        (!best || candidate->log_likelihood > best->log_likelihood)) best = candidate;
  }
  if (!best) throw std::runtime_error("all HMM restarts failed numerical stability gate");
  impl_ = std::move(best);
}

std::vector<double> GaussianHmm::filter(const std::array<double, 4>& observation) {
  std::array<double, 4> normalized = observation;
  for (std::size_t j = 0; j < 4U; ++j) {
    normalized[j] = (normalized[j] - impl_->observation_mean[j]) / impl_->observation_scale[j];
  }
  std::vector<double> next(impl_->states, 0.0);
  for (std::size_t state = 0; state < impl_->states; ++state) {
    double incoming = 0.0;
    for (std::size_t previous = 0; previous < impl_->states; ++previous) {
      incoming += impl_->filtered[previous] * impl_->transition[previous][state];
    }
    next[state] = incoming * impl_->emission(state, normalized);
  }
  const double total = std::max(std::accumulate(next.begin(), next.end(), 0.0), kEpsilon);
  for (double& value : next) value /= total;
  impl_->filtered = next;
  return next;
}

std::vector<double> GaussianHmm::next_state_probabilities() const {
  std::vector<double> next(impl_->states, 0.0);
  for (std::size_t from = 0; from < impl_->states; ++from) {
    for (std::size_t to = 0; to < impl_->states; ++to) {
      next[to] += impl_->filtered[from] * impl_->transition[from][to];
    }
  }
  return next;
}

double GaussianHmm::bic() const {
  const double states = static_cast<double>(impl_->states);
  const double parameters = states * (states - 1.0) + (states - 1.0) + states * 8.0;
  return -2.0 * impl_->log_likelihood + parameters *
      std::log(static_cast<double>(std::max(impl_->observations, std::size_t{1})));
}

std::string GaussianHmm::diagnostics() const {
  std::ostringstream out;
  out << "{\"states\":" << impl_->states << ",\"log_likelihood\":" << impl_->log_likelihood
      << ",\"bic\":" << bic() << ",\"seed\":" << impl_->seed << '}';
  return out.str();
}

AnalogKernelModel::AnalogKernelModel(std::size_t neighbors, double min_effective_sample)
    : neighbors_(neighbors), min_effective_sample_(min_effective_sample) {}
std::string AnalogKernelModel::id() const { return "robust_day_block_analog_kernel"; }

void AnalogKernelModel::fit(const std::vector<FeatureSnapshot>& x, const std::vector<Label>& y) {
  const std::size_t count = std::min(x.size(), y.size());
  if (count < 30U) throw std::runtime_error("analog kernel requires at least 30 samples");
  x_.assign(x.begin(), x.begin() + static_cast<std::ptrdiff_t>(count));
  y_.assign(y.begin(), y.begin() + static_cast<std::ptrdiff_t>(count));
  for (std::size_t j = 0; j < FeatureSnapshot::kDimension; ++j) {
    std::vector<double> values;
    values.reserve(count);
    for (std::size_t i = 0; i < count; ++i) values.push_back(x_[i].x[j]);
    median_[j] = quantile(values, 0.5);
    std::vector<double> deviations;
    deviations.reserve(count);
    for (const double value : values) deviations.push_back(std::abs(value - median_[j]));
    scale_[j] = std::max(1.4826 * quantile(deviations, 0.5), 1e-9);
  }
}

std::vector<AnalogCase> AnalogKernelModel::analogs(const FeatureSnapshot& query) const {
  struct Candidate { std::size_t index; double distance; };
  std::unordered_map<std::string, Candidate> best_by_day;
  const SessionClock query_clock = eastern_clock(query.timestamp);
  for (std::size_t i = 0; i < x_.size(); ++i) {
    if (x_[i].timestamp >= query.timestamp || y_[i].end_time >= query.timestamp) continue;
    const SessionClock candidate_clock = eastern_clock(x_[i].timestamp);
    if (candidate_clock.day == query_clock.day ||
        std::abs(candidate_clock.minute_from_open - query_clock.minute_from_open) > 15) continue;
    double squared = 0.0;
    // The kernel is intentionally capped at fifteen pre-declared dimensions.
    // Robust marginal scales approximate a shrinkage diagonal Mahalanobis metric.
    for (std::size_t j = 0; j < FeatureSnapshot::kDimension; ++j) {
      const double delta = (query.x[j] - x_[i].x[j]) / scale_[j];
      squared += delta * delta;
    }
    const double distance = std::sqrt(squared / static_cast<double>(FeatureSnapshot::kDimension));
    const std::string key = day_key(x_[i].timestamp);
    const auto found = best_by_day.find(key);
    if (found == best_by_day.end() || distance < found->second.distance) {
      best_by_day[key] = {i, distance};
    }
  }
  std::vector<Candidate> candidates;
  candidates.reserve(best_by_day.size());
  for (const auto& [_, candidate] : best_by_day) candidates.push_back(candidate);
  std::sort(candidates.begin(), candidates.end(), [](const auto& left, const auto& right) {
    return left.distance < right.distance;
  });
  if (candidates.size() > neighbors_) candidates.resize(neighbors_);
  if (candidates.empty()) return {};
  // Adaptive kNN bandwidth: the furthest retained neighbor defines support.
  const double bandwidth = std::max(candidates.back().distance, 1e-6);
  std::vector<AnalogCase> output;
  output.reserve(candidates.size());
  double weight_sum = 0.0;
  for (const auto& candidate : candidates) {
    const double ratio = candidate.distance / bandwidth;
    const double weight = std::exp(-0.5 * ratio * ratio);
    weight_sum += weight;
    output.push_back({.timestamp = x_[candidate.index].timestamp,
                      .distance = candidate.distance,
                      .weight = weight,
                      .outcome = y_[candidate.index].log_return,
                      .day_key = day_key(x_[candidate.index].timestamp)});
  }
  for (auto& value : output) value.weight /= std::max(weight_sum, kEpsilon);
  return output;
}

PredictionDistribution AnalogKernelModel::predict_distribution(const FeatureSnapshot& x,
                                                                 int horizon_minutes) const {
  const auto cases = analogs(x);
  PredictionDistribution output;
  output.timestamp = x.timestamp;
  output.horizon_minutes = horizon_minutes;
  output.model_id = id();
  if (cases.empty()) {
    output.evidence.push_back("NO_ANALOG_HISTORY");
    output.prediction_hash = sha256(to_json(output));
    return output;
  }
  double weight_squared = 0.0;
  double variance = 0.0;
  std::vector<std::pair<double, double>> weighted;
  for (const auto& item : cases) {
    output.expected_return += item.weight * item.outcome;
    output.p_up += item.outcome > 0.0 ? item.weight : 0.0;
    weight_squared += item.weight * item.weight;
    weighted.emplace_back(item.outcome, item.weight);
  }
  output.p_down = 1.0 - output.p_up;
  output.effective_sample_size = 1.0 / std::max(weight_squared, kEpsilon);
  for (const auto& item : cases) variance += item.weight * std::pow(item.outcome - output.expected_return, 2.0);
  output.uncertainty = std::sqrt(variance);
  output.expected_volatility = output.uncertainty;
  auto weighted_quantile = [&](double probability) {
    auto values = weighted;
    std::sort(values.begin(), values.end());
    double cumulative = 0.0;
    for (const auto& [value, weight] : values) {
      cumulative += weight;
      if (cumulative >= probability) return value;
    }
    return values.back().first;
  };
  const std::array<double, 6> probabilities{0.10, 0.25, 0.50, 0.75, 0.90, 0.99};
  for (std::size_t i = 0; i < probabilities.size(); ++i) output.quantiles[i] = weighted_quantile(probabilities[i]);
  output.median_return = output.quantiles[2];
  output.expected_mfe = std::max(output.quantiles[4], 0.0);
  output.expected_mae = std::max(-output.quantiles[0], 0.0);
  output.calibrated_confidence = std::max(output.p_up, output.p_down);
  if (output.effective_sample_size < min_effective_sample_) output.evidence.push_back("LOW_EFFECTIVE_SAMPLE");
  if (!cases.empty() && cases.front().weight > 0.30) output.evidence.push_back("EPISODE_CONCENTRATION");
  output.prediction_hash = sha256(to_json(output));
  return output;
}

std::string AnalogKernelModel::diagnostics() const {
  return "{\"model\":\"" + id() + "\",\"samples\":" + std::to_string(x_.size()) +
         ",\"neighbors\":" + std::to_string(neighbors_) +
         ",\"day_block\":true,\"adaptive_bandwidth\":true}";
}

void AnalogKernelModel::serialize(const std::filesystem::path& path) const { write_text(path, diagnostics()); }

std::vector<PurgedFold> purged_walk_forward(const std::vector<Label>& labels, int train_days,
                                            int validation_days, int test_days,
                                            int embargo_minutes) {
  if (labels.empty() || train_days <= 0 || validation_days <= 0 || test_days <= 0) return {};
  std::vector<std::int64_t> days;
  for (const auto& label : labels) days.push_back(eastern_clock(label.signal_time).day);
  std::sort(days.begin(), days.end());
  days.erase(std::unique(days.begin(), days.end()), days.end());
  std::vector<PurgedFold> folds;
  for (std::size_t train_end = static_cast<std::size_t>(train_days);
       train_end + static_cast<std::size_t>(validation_days + test_days) <= days.size();
       train_end += static_cast<std::size_t>(test_days)) {
    const std::int64_t validation_start_day = days[train_end];
    const std::int64_t validation_end_day = days[train_end + static_cast<std::size_t>(validation_days) - 1U];
    const std::int64_t test_start_day = days[train_end + static_cast<std::size_t>(validation_days)];
    const std::int64_t test_end_day = days[train_end + static_cast<std::size_t>(validation_days + test_days) - 1U];
    const Timestamp validation_start = validation_start_day * kNsPerDay -
        static_cast<Timestamp>(embargo_minutes) * kNsPerMinute;
    const Timestamp test_start = test_start_day * kNsPerDay -
        static_cast<Timestamp>(embargo_minutes) * kNsPerMinute;
    PurgedFold fold;
    for (std::size_t i = 0; i < labels.size(); ++i) {
      const auto day = eastern_clock(labels[i].signal_time).day;
      if (day < validation_start_day && labels[i].end_time < validation_start) {
        fold.train.push_back(i);
      } else if (day >= validation_start_day && day <= validation_end_day &&
                 labels[i].end_time < test_start) {
        fold.validation.push_back(i);
      } else if (day >= test_start_day && day <= test_end_day) {
        fold.test.push_back(i);
      }
    }
    folds.push_back(std::move(fold));
  }
  return folds;
}

EvaluationMetrics evaluate_predictions(const std::vector<PredictionDistribution>& predictions,
                                       const std::vector<Label>& labels,
                                       double round_trip_cost, std::uint64_t seed) {
  const std::size_t count = std::min(predictions.size(), labels.size());
  EvaluationMetrics metrics;
  metrics.samples = count;
  if (count == 0U) return metrics;
  std::array<double, 10> bucket_probability{};
  std::array<double, 10> bucket_realized{};
  std::array<std::size_t, 10> bucket_count{};
  std::vector<double> net;
  std::vector<double> executed;
  net.reserve(count);
  std::size_t wins = 0U;
  for (std::size_t i = 0; i < count; ++i) {
    const double probability = std::clamp(predictions[i].p_up, 1e-9, 1.0 - 1e-9);
    const double target = labels[i].log_return > 0.0 ? 1.0 : 0.0;
    metrics.brier += std::pow(probability - target, 2.0);
    metrics.log_loss += -(target * std::log(probability) + (1.0 - target) * std::log(1.0 - probability));
    const std::size_t bucket = std::min(static_cast<std::size_t>(probability * 10.0), std::size_t{9});
    bucket_probability[bucket] += probability;
    bucket_realized[bucket] += target;
    ++bucket_count[bucket];
    const int direction = predictions[i].decision == Decision::Long ? 1 :
                          predictions[i].decision == Decision::Short ? -1 : 0;
    const double value = direction == 0 ? 0.0 : static_cast<double>(direction) * labels[i].log_return - round_trip_cost;
    net.push_back(value);
    if (direction != 0) {
      executed.push_back(value);
      if (value > 0.0) ++wins;
    }
  }
  metrics.brier /= static_cast<double>(count);
  metrics.log_loss /= static_cast<double>(count);
  for (std::size_t bucket = 0; bucket < bucket_count.size(); ++bucket) {
    if (bucket_count[bucket] == 0U) continue;
    const double bucket_size = static_cast<double>(bucket_count[bucket]);
    metrics.expected_calibration_error += bucket_size / static_cast<double>(count) *
        std::abs(bucket_probability[bucket] / bucket_size - bucket_realized[bucket] / bucket_size);
  }
  metrics.net_expectancy = mean(net);
  metrics.trades = executed.size();
  metrics.trade_expectancy = mean(executed);
  metrics.win_rate = executed.empty() ? 0.0 : static_cast<double>(wins) / static_cast<double>(executed.size());
  std::unordered_map<std::string, std::vector<double>> by_day;
  for (std::size_t i = 0; i < count; ++i) by_day[day_key(labels[i].signal_time)].push_back(net[i]);
  std::vector<std::string> keys;
  for (const auto& [key, _] : by_day) keys.push_back(key);
  std::mt19937_64 rng(seed);
  std::uniform_int_distribution<std::size_t> pick(0U, keys.size() - 1U);
  std::vector<double> bootstraps;
  for (std::size_t repetition = 0; repetition < 500U; ++repetition) {
    double sum = 0.0;
    std::size_t samples = 0U;
    for (std::size_t day = 0; day < keys.size(); ++day) {
      const auto& values = by_day[keys[pick(rng)]];
      sum += std::accumulate(values.begin(), values.end(), 0.0);
      samples += values.size();
    }
    bootstraps.push_back(sum / static_cast<double>(std::max(samples, std::size_t{1})));
  }
  metrics.bootstrap_low = quantile(bootstraps, 0.025);
  metrics.bootstrap_high = quantile(bootstraps, 0.975);
  return metrics;
}

RiskEngine::RiskEngine(RiskConfig config) : config_(config) {}

RiskDecision RiskEngine::evaluate(const PredictionDistribution& prediction,
                                  const std::optional<Quote>& quote, Timestamp now,
                                  int trades_today, double daily_pnl, double proposed_quantity,
                                  bool duplicate_order, bool kill_switch) const {
  RiskDecision output;
  output.approved = true;
  auto reject = [&](std::string reason) {
    output.approved = false;
    output.reasons.push_back(std::move(reason));
  };
  if (kill_switch) reject("KILL_SWITCH");
  if (prediction.decision == Decision::NoTrade || prediction.lower_confidence_bound <= 0.0) reject("NO_POSITIVE_LCB");
  if (daily_pnl <= -config_.max_daily_loss) reject("MAX_DAILY_LOSS");
  if (std::abs(proposed_quantity) > config_.max_position) reject("MAX_POSITION");
  if (trades_today >= config_.max_trades_per_day) reject("MAX_TRADES_PER_DAY");
  if (prediction.uncertainty > config_.max_uncertainty) reject("UNCERTAINTY_HIGH");
  if (prediction.effective_sample_size < config_.min_effective_sample) reject("EFFECTIVE_SAMPLE_LOW");
  if (duplicate_order) reject("DUPLICATE_ORDER");
  if (!quote) {
    reject("MISSING_QUOTE");
  } else {
    const double midpoint = (quote->bid + quote->ask) * 0.5;
    if (quote->bid <= 0.0 || quote->ask <= quote->bid || midpoint <= 0.0) {
      reject("INVALID_QUOTE");
    } else if ((quote->ask - quote->bid) / midpoint * 10'000.0 > config_.max_spread_bps) {
      reject("SPREAD_EXCEEDS_EDGE");
    }
    if (now - quote->meta.event_time > static_cast<Timestamp>(config_.stale_quote_seconds) * kNsPerSecond) {
      reject("STALE_QUOTE");
    }
  }
  std::ostringstream evidence;
  evidence << output.approved << '|' << prediction.prediction_hash << '|' << now;
  for (const auto& reason : output.reasons) evidence << '|' << reason;
  output.audit_hash = sha256(evidence.str());
  return output;
}

Order PaperOms::submit(Order order, const RiskDecision& risk) {
  if (const auto found = idempotency_.find(order.idempotency_key); found != idempotency_.end()) {
    return orders_[found->second];
  }
  order.state = risk.approved ? OrderState::Submitted : OrderState::RiskRejected;
  order.audit_hash = sha256(order.order_id + '|' + order.idempotency_key + '|' + risk.audit_hash);
  idempotency_[order.idempotency_key] = orders_.size();
  orders_.push_back(order);
  return order;
}

std::optional<Fill> PaperOms::on_quote(const Quote& quote, Timestamp now) {
  for (auto& order : orders_) {
    if (order.state != OrderState::Submitted || order.symbol != quote.symbol ||
        now < order.submitted_time || quote.meta.event_time < order.submitted_time ||
        quote.bid <= 0.0 || quote.ask <= quote.bid) continue;
    const double price = order.side == Side::Long ? quote.ask : quote.bid;
    Fill fill{.fill_id = sha256(order.order_id + '|' + std::to_string(now)).substr(0, 24),
              .order_id = order.order_id,
              .symbol = order.symbol,
              .side = order.side,
              .quantity = order.quantity,
              .price = price,
              .fee = 0.0,
              .slippage = (quote.ask - quote.bid) * 0.5 * order.quantity,
              .fill_time = now};
    order.state = OrderState::Filled;
    fills_.push_back(fill);
    return fill;
  }
  return std::nullopt;
}

const std::vector<Order>& PaperOms::orders() const { return orders_; }
const std::vector<Fill>& PaperOms::fills() const { return fills_; }

namespace {
void sql_exec(sqlite3* database, const std::string& sql) {
  char* error = nullptr;
  if (sqlite3_exec(database, sql.c_str(), nullptr, nullptr, &error) != SQLITE_OK) {
    const std::string message = error == nullptr ? "SQLite error" : error;
    sqlite3_free(error);
    throw std::runtime_error(message);
  }
}
}

Ledger::Ledger(const std::filesystem::path& database_path) {
  if (!database_path.parent_path().empty()) std::filesystem::create_directories(database_path.parent_path());
  if (sqlite3_open(database_path.string().c_str(), &db_) != SQLITE_OK) {
    const std::string message = db_ == nullptr ? "cannot open SQLite" : sqlite3_errmsg(db_);
    sqlite3_close(db_);
    db_ = nullptr;
    throw std::runtime_error(message);
  }
  sql_exec(db_, "PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL; PRAGMA foreign_keys=ON;");
}

Ledger::~Ledger() { if (db_ != nullptr) sqlite3_close(db_); }

void Ledger::initialize(const std::filesystem::path& schema_path) {
  std::ifstream stream(schema_path);
  if (!stream) throw std::runtime_error("cannot open ledger schema: " + schema_path.string());
  std::ostringstream sql;
  sql << stream.rdbuf();
  sql_exec(db_, sql.str());
}

void Ledger::record_fill(const Fill& fill) {
  const double notional = fill.price * fill.quantity;
  const double costs = fill.fee + fill.slippage;
  const std::string transaction_id = sha256(fill.fill_id + "|ledger").substr(0, 24);
  sqlite3_stmt* statement = nullptr;
  const char* sql = "INSERT INTO ledger_transactions(transaction_id,event_time,event_type,source_id,correction_of,content_hash) "
                    "VALUES(?1,?2,'FILL',?3,NULL,?4);";
  sql_exec(db_, "BEGIN IMMEDIATE;");
  try {
    if (sqlite3_prepare_v2(db_, sql, -1, &statement, nullptr) != SQLITE_OK) throw std::runtime_error(sqlite3_errmsg(db_));
    sqlite3_bind_text(statement, 1, transaction_id.c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_int64(statement, 2, fill.fill_time);
    sqlite3_bind_text(statement, 3, fill.fill_id.c_str(), -1, SQLITE_TRANSIENT);
    const std::string hash = sha256(fill.fill_id + '|' + std::to_string(fill.price) + '|' + std::to_string(fill.quantity));
    sqlite3_bind_text(statement, 4, hash.c_str(), -1, SQLITE_TRANSIENT);
    if (sqlite3_step(statement) != SQLITE_DONE) throw std::runtime_error(sqlite3_errmsg(db_));
    sqlite3_finalize(statement);
    statement = nullptr;
    std::size_t entry_sequence = 0U;
    auto entry = [&](std::string_view account, double debit, double credit, std::string_view memo) {
      sqlite3_stmt* row = nullptr;
      const char* insert = "INSERT INTO ledger_entries(entry_id,transaction_id,account,debit,credit,currency,memo) "
                           "VALUES(?1,?2,?3,?4,?5,'USD',?6);";
      if (sqlite3_prepare_v2(db_, insert, -1, &row, nullptr) != SQLITE_OK) throw std::runtime_error(sqlite3_errmsg(db_));
      const std::string id = sha256(transaction_id + '|' + std::string(account) + '|' +
                                    std::to_string(entry_sequence++)).substr(0, 24);
      sqlite3_bind_text(row, 1, id.c_str(), -1, SQLITE_TRANSIENT);
      sqlite3_bind_text(row, 2, transaction_id.c_str(), -1, SQLITE_TRANSIENT);
      sqlite3_bind_text(row, 3, account.data(), static_cast<int>(account.size()), SQLITE_TRANSIENT);
      sqlite3_bind_double(row, 4, debit);
      sqlite3_bind_double(row, 5, credit);
      sqlite3_bind_text(row, 6, memo.data(), static_cast<int>(memo.size()), SQLITE_TRANSIENT);
      if (sqlite3_step(row) != SQLITE_DONE) { sqlite3_finalize(row); throw std::runtime_error(sqlite3_errmsg(db_)); }
      sqlite3_finalize(row);
    };
    if (fill.side == Side::Long) {
      entry("Position", notional, 0.0, fill.symbol);
      entry("Cash", 0.0, notional, fill.symbol);
    } else {
      entry("Cash", notional, 0.0, fill.symbol);
      entry("Position", 0.0, notional, fill.symbol);
    }
    if (costs > 0.0) {
      entry("Fees", costs, 0.0, "fee+slippage");
      entry("Cash", 0.0, costs, "fee+slippage");
    }
    sql_exec(db_, "COMMIT;");
  } catch (...) {
    if (statement != nullptr) sqlite3_finalize(statement);
    sql_exec(db_, "ROLLBACK;");
    throw;
  }
}

bool Ledger::balanced() const {
  sqlite3_stmt* statement = nullptr;
  const char* sql = "SELECT COUNT(*) FROM (SELECT transaction_id FROM ledger_entries GROUP BY transaction_id "
                    "HAVING ABS(SUM(debit)-SUM(credit)) > 0.000001);";
  if (sqlite3_prepare_v2(db_, sql, -1, &statement, nullptr) != SQLITE_OK) throw std::runtime_error(sqlite3_errmsg(db_));
  const bool ok = sqlite3_step(statement) == SQLITE_ROW && sqlite3_column_int64(statement, 0) == 0;
  sqlite3_finalize(statement);
  return ok;
}

std::string Ledger::audit_hash() const {
  sqlite3_stmt* statement = nullptr;
  const char* sql = "SELECT transaction_id,content_hash FROM ledger_transactions ORDER BY rowid;";
  if (sqlite3_prepare_v2(db_, sql, -1, &statement, nullptr) != SQLITE_OK) throw std::runtime_error(sqlite3_errmsg(db_));
  std::ostringstream values;
  while (sqlite3_step(statement) == SQLITE_ROW) {
    values << reinterpret_cast<const char*>(sqlite3_column_text(statement, 0)) << '|'
           << reinterpret_cast<const char*>(sqlite3_column_text(statement, 1)) << '\n';
  }
  sqlite3_finalize(statement);
  return sha256(values.str());
}

ReplayResult ReplayEngine::replay(std::vector<MarketEvent> events, IncrementalFeatureStore& store) const {
  auto time = [](const MarketEvent& event) {
    if (event.bar) return event.bar->meta.available_time;
    if (event.quote) return event.quote->meta.available_time;
    if (event.trade) return event.trade->meta.available_time;
    return Timestamp{};
  };
  auto sequence = [](const MarketEvent& event) {
    if (event.bar) return event.bar->meta.sequence;
    if (event.quote) return event.quote->meta.sequence;
    if (event.trade) return event.trade->meta.sequence;
    return std::uint64_t{};
  };
  std::stable_sort(events.begin(), events.end(), [&](const auto& left, const auto& right) {
    return std::make_pair(time(left), sequence(left)) < std::make_pair(time(right), sequence(right));
  });
  ReplayResult output;
  std::ostringstream event_lineage;
  std::ostringstream feature_lineage;
  for (const auto& event : events) {
    if (event.bar && !event.bar->finalized) {
      ++output.rejected_unfinalized;
      continue;
    }
    ++output.events;
    event_lineage << stable_event_hash(event);
    if (const auto feature = store.on_event(event)) {
      ++output.feature_snapshots;
      feature_lineage << feature->lineage_hash;
    }
  }
  output.event_hash = sha256(event_lineage.str());
  output.feature_hash = sha256(feature_lineage.str());
  return output;
}

std::string decision_name(Decision value) {
  if (value == Decision::Long) return "LONG";
  if (value == Decision::Short) return "SHORT";
  return "NO_TRADE";
}

std::string to_json(const PredictionDistribution& value) {
  std::ostringstream out;
  out << std::setprecision(12)
      << "{\"timestamp\":" << value.timestamp << ",\"horizon_minutes\":" << value.horizon_minutes
      << ",\"p_up\":" << value.p_up << ",\"p_down\":" << value.p_down
      << ",\"expected_return\":" << value.expected_return << ",\"median_return\":" << value.median_return
      << ",\"q10\":" << value.quantiles[0] << ",\"q25\":" << value.quantiles[1]
      << ",\"q50\":" << value.quantiles[2] << ",\"q75\":" << value.quantiles[3]
      << ",\"q90\":" << value.quantiles[4] << ",\"q99\":" << value.quantiles[5]
      << ",\"expected_volatility\":" << value.expected_volatility
      << ",\"volatility_expansion_probability\":" << value.volatility_expansion_probability
      << ",\"expected_mfe\":" << value.expected_mfe << ",\"expected_mae\":" << value.expected_mae
      << ",\"uncertainty\":" << value.uncertainty
      << ",\"effective_sample_size\":" << value.effective_sample_size
      << ",\"calibrated_confidence\":" << value.calibrated_confidence
      << ",\"expected_net_value\":" << value.expected_net_value
      << ",\"lower_confidence_bound\":" << value.lower_confidence_bound
      << ",\"decision\":\"" << decision_name(value.decision) << "\",\"model_id\":\""
      << escape_json(value.model_id) << "\"}";
  return out.str();
}

std::string to_json(const ReplayResult& value) {
  std::ostringstream out;
  out << "{\"events\":" << value.events << ",\"feature_snapshots\":" << value.feature_snapshots
      << ",\"rejected_unfinalized\":" << value.rejected_unfinalized
      << ",\"event_hash\":\"" << value.event_hash << "\",\"feature_hash\":\""
      << value.feature_hash << "\"}";
  return out.str();
}

} // namespace axio
