use std::{
    collections::{BTreeMap, BTreeSet},
    fs,
    path::{Path, PathBuf},
    sync::{Arc, OnceLock},
};

use anyhow::{Context, Result, bail};
use chrono::{DateTime, NaiveDate, Timelike, Utc};
use chrono_tz::America::New_York;
use databento::dbn::{
    OhlcvMsg,
    decode::{DbnDecoder, DbnMetadata, DecodeRecordRef},
    symbol_map::SymbolIndex,
};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

use crate::data::{
    manifest::{DataManifest, sha256_file},
    market_store::{StoredLiveMarketBar, latest_live_bars},
};

const PRICE_SCALE: f64 = 1_000_000_000.0;
const REQUIRED_SYMBOLS: [&str; 8] = ["SPY", "QQQ", "IWM", "SOXX", "HYG", "TLT", "UUP", "VXX"];
const SECTOR_ROTATION_SYMBOLS: [&str; 15] = [
    "MAGS", "SKYY", "IGV", "XLK", "XLC", "XLY", "XLF", "XLE", "XLI", "XLV", "XLP", "XLU", "XLRE",
    "XLB", "SOXX",
];
const SECTOR_ROTATION_GROUPS: [(&str, &str); 15] = [
    ("MAGNIFICENT_SEVEN", "MAGS"),
    ("CLOUD_COMPUTING", "SKYY"),
    ("SOFTWARE", "IGV"),
    ("TECHNOLOGY", "XLK"),
    ("COMMUNICATION_SERVICES", "XLC"),
    ("CONSUMER_DISCRETIONARY", "XLY"),
    ("FINANCIALS", "XLF"),
    ("ENERGY", "XLE"),
    ("INDUSTRIALS", "XLI"),
    ("HEALTH_CARE", "XLV"),
    ("CONSUMER_STAPLES", "XLP"),
    ("UTILITIES", "XLU"),
    ("REAL_ESTATE", "XLRE"),
    ("MATERIALS", "XLB"),
    ("SEMICONDUCTORS", "SOXX"),
];
const FEATURE_NAMES: [&str; 15] = [
    "spy_session_return",
    "spy_gap_return",
    "spy_5d_return",
    "spy_20d_return",
    "spy_20d_realized_volatility",
    "spy_session_range",
    "spy_close_location",
    "spy_log_volume_z20",
    "qqq_relative_return",
    "iwm_relative_return",
    "soxx_relative_return",
    "hyg_return",
    "tlt_return",
    "uup_return",
    "vxx_return",
];
const SECTOR_ROTATION_FEATURE_NAMES: [&str; 6] = [
    "mag7_relative_return",
    "cloud_relative_return",
    "software_relative_return",
    "sector_leadership_breadth",
    "sector_return_dispersion",
    "growth_defensive_rotation",
];
const MINIMUM_PRIMARY_ROWS: usize = 390;
// Databento's OHLCV-1m schema emits a bar only for minutes with trades. Less
// active context ETFs such as UUP therefore cannot honestly satisfy a
// 370-print threshold even when their full session is present. Require enough
// observations for a daily return and explicit coverage near both session
// edges instead.
const MINIMUM_CONTEXT_ROWS: usize = 20;
const CONTEXT_FIRST_MINUTE_LIMIT_ET: u32 = 10 * 60;
const CONTEXT_LAST_MINUTE_LIMIT_ET: u32 = 15 * 60 + 30;
const ANALOG_NEIGHBORS: usize = 15;
const MINIMUM_ANALOGS: usize = 10;
const DIRECTIONAL_AGREEMENT_THRESHOLD: f64 = 0.60;
const PREDICTION_INTERVAL_COVERAGE: f64 = 0.90;
const MINIMUM_INTERVAL_CALIBRATION_SESSIONS: usize = 40;
const RAW_LIKELIHOOD_CONFIDENCE_LEVEL: f64 = 0.95;
const NORMAL_95_TWO_SIDED_Z: f64 = 1.959_963_984_540_054;
const SECTOR_CHALLENGER_MINIMUM_QUERIES: usize = 80;
const SECTOR_CHALLENGER_MINIMUM_DIRECTIONAL_CALLS: usize = 20;
const SECTOR_CHALLENGER_MINIMUM_HIT_GAIN: f64 = 0.02;
const SECTOR_CHALLENGER_MAXIMUM_MAE_RATIO: f64 = 1.0;

static HISTORY_CACHE: OnceLock<Arc<HistoricalDailyData>> = OnceLock::new();

#[derive(Debug, Clone, Default)]
struct DailyBar {
    open: f64,
    high: f64,
    low: f64,
    close: f64,
    volume: f64,
    minute_rows: usize,
    first_at: Option<DateTime<Utc>>,
    last_at: Option<DateTime<Utc>>,
}

impl DailyBar {
    fn push(
        &mut self,
        timestamp: DateTime<Utc>,
        open: f64,
        high: f64,
        low: f64,
        close: f64,
        volume: f64,
    ) {
        if self.minute_rows == 0 {
            self.open = open;
            self.high = high;
            self.low = low;
            self.first_at = Some(timestamp);
        } else {
            self.high = self.high.max(high);
            self.low = self.low.min(low);
        }
        self.close = close;
        self.volume += volume;
        self.minute_rows += 1;
        self.last_at = Some(timestamp);
    }
}

type DailyTape = BTreeMap<NaiveDate, BTreeMap<String, DailyBar>>;

#[derive(Debug, Clone, Copy)]
struct RawMinute {
    timestamp: DateTime<Utc>,
    open: f64,
    high: f64,
    low: f64,
    close: f64,
    volume: f64,
}

#[derive(Debug, Clone)]
struct HistoricalDailyData {
    tape: DailyTape,
    lineage: Vec<SourceFile>,
    dataset_sha256: String,
    acquired_at: DateTime<Utc>,
}

#[derive(Debug, Clone)]
struct FeatureRow {
    date: NaiveDate,
    features: Vec<f64>,
    sector_rotation: Option<SectorRotationFeatures>,
    missing_sector_symbols: Vec<String>,
    regime: RegimeLabel,
    spy: DailyBar,
    coverage: BTreeMap<String, usize>,
}

#[derive(Debug, Clone)]
struct SectorRotationFeatures {
    values: Vec<f64>,
    group_returns: BTreeMap<String, f64>,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
enum RegimeLabel {
    HighVolSellOff,
    HighVolRecovery,
    LowVolBreakout,
    RiskOnTrend,
    RiskOffTrend,
    HighVolRange,
    LowVolRange,
    MixedTransition,
}

impl RegimeLabel {
    fn definition(self) -> &'static str {
        match self {
            Self::HighVolSellOff => {
                "Elevated trailing volatility with a materially negative SPY session."
            }
            Self::HighVolRecovery => {
                "Elevated trailing volatility with a materially positive SPY recovery session."
            }
            Self::LowVolBreakout => {
                "Low trailing volatility with a positive 20-session trend and broad risk-asset confirmation."
            }
            Self::RiskOnTrend => {
                "Positive 20-session SPY trend confirmed by cross-asset breadth and non-negative HYG."
            }
            Self::RiskOffTrend => {
                "Negative 20-session SPY trend with weak breadth and negative HYG."
            }
            Self::HighVolRange => {
                "Elevated trailing volatility without a directional trend confirmation."
            }
            Self::LowVolRange => {
                "Low trailing volatility and no material 20-session directional trend."
            }
            Self::MixedTransition => {
                "Trend, volatility, breadth, and defensive cross-asset evidence are mixed."
            }
        }
    }

    fn display_name(self) -> &'static str {
        match self {
            Self::HighVolSellOff => "High-volatility sell-off",
            Self::HighVolRecovery => "High-volatility recovery",
            Self::LowVolBreakout => "Low-volatility breakout",
            Self::RiskOnTrend => "Risk-on trend",
            Self::RiskOffTrend => "Risk-off trend",
            Self::HighVolRange => "High-volatility range",
            Self::LowVolRange => "Low-volatility range",
            Self::MixedTransition => "Mixed transition",
        }
    }

    fn selection_rule(self) -> &'static str {
        match self {
            Self::HighVolSellOff => {
                "Volatility percentile at or above 75% and SPY session return at or below -0.75%."
            }
            Self::HighVolRecovery => {
                "Volatility percentile at or above 75% and SPY session return at or above +0.75%."
            }
            Self::LowVolBreakout => {
                "Volatility percentile at or below 25%, SPY 20-session return at or above +2%, breadth at or above 50%, and HYG non-negative."
            }
            Self::RiskOnTrend => {
                "SPY 20-session return at or above +2%, breadth at or above 50%, and HYG non-negative."
            }
            Self::RiskOffTrend => {
                "SPY 20-session return at or below -2%, breadth at or below 50%, and HYG negative."
            }
            Self::HighVolRange => {
                "Volatility percentile at or above 75% without an earlier directional state."
            }
            Self::LowVolRange => {
                "Volatility percentile at or below 25% without an earlier directional state."
            }
            Self::MixedTransition => {
                "No earlier state in the ordered eight-regime decision tree is satisfied."
            }
        }
    }
}

const REGIME_TAXONOMY: [RegimeLabel; 8] = [
    RegimeLabel::HighVolSellOff,
    RegimeLabel::HighVolRecovery,
    RegimeLabel::LowVolBreakout,
    RegimeLabel::RiskOnTrend,
    RegimeLabel::RiskOffTrend,
    RegimeLabel::HighVolRange,
    RegimeLabel::LowVolRange,
    RegimeLabel::MixedTransition,
];

#[derive(Debug, Clone, Serialize)]
pub struct DailyRegimeReport {
    schema_version: &'static str,
    status: &'static str,
    result_kind: &'static str,
    generated_at: DateTime<Utc>,
    observation_cutoff: DateTime<Utc>,
    public_symbol: &'static str,
    data_symbol: &'static str,
    proxy_disclosure: &'static str,
    forecast_horizon: &'static str,
    current_regime: CurrentRegime,
    regime_taxonomy: Vec<RegimeTaxonomyEntry>,
    current_market: CurrentMarket,
    prediction: NextSessionLean,
    raw_likelihood: RawLikelihoodEstimate,
    prediction_interval: PredictionInterval,
    prediction_rationale: PredictionRationale,
    similar_historical_sessions: Vec<HistoricalAnalog>,
    same_regime_history: Vec<HistoricalAnalog>,
    walk_forward_validation: WalkForwardValidation,
    feature_snapshot: Vec<FeatureValue>,
    sector_rotation_challenger: SectorRotationChallenger,
    source: DailySource,
    model_contract: DailyModelContract,
    macro_news_policy: MacroNewsPolicy,
    probability_published: bool,
    automatic_execution_enabled: bool,
    caveats: Vec<&'static str>,
}

#[derive(Debug, Clone, Serialize)]
struct CurrentRegime {
    label: RegimeLabel,
    display_name: &'static str,
    definition: &'static str,
    market_summary: String,
    classification_reasons: Vec<String>,
    volatility_percentile_prior_252: f64,
    cross_asset_breadth: f64,
}

#[derive(Debug, Clone, Serialize)]
struct RegimeTaxonomyEntry {
    priority: usize,
    label: RegimeLabel,
    display_name: &'static str,
    definition: &'static str,
    selection_rule: &'static str,
    active: bool,
}

#[derive(Debug, Clone, Serialize)]
struct CurrentMarket {
    session_date_et: NaiveDate,
    open: f64,
    high: f64,
    low: f64,
    close: f64,
    session_return_pct: f64,
    twenty_session_return_pct: f64,
    twenty_session_annualized_volatility_pct: f64,
    close_location_pct: f64,
    minute_coverage: BTreeMap<String, usize>,
}

#[derive(Debug, Clone, Serialize)]
struct NextSessionLean {
    lean: &'static str,
    directional_call_status: &'static str,
    target_definition: &'static str,
    analog_sample_size: usize,
    raw_up_count: usize,
    raw_down_or_flat_count: usize,
    raw_up_frequency: f64,
    raw_directional_agreement: f64,
    minimum_directional_agreement: f64,
    reported_evidence_strength: Option<f64>,
    median_next_session_return_pct: f64,
    mean_next_session_return_pct: f64,
    calibrated_probability: bool,
    interpretation: &'static str,
}

#[derive(Debug, Clone, Serialize)]
struct RawLikelihoodEstimate {
    method: &'static str,
    sample_size: usize,
    up_count: usize,
    down_or_flat_count: usize,
    up_estimate: f64,
    down_or_flat_estimate: f64,
    confidence_method: &'static str,
    confidence_level: f64,
    up_lower_bound: f64,
    up_upper_bound: f64,
    calibrated_probability: bool,
    interpretation: &'static str,
}

#[derive(Debug, Clone, Serialize)]
struct PredictionInterval {
    method: &'static str,
    nominal_coverage: f64,
    point_estimate_pct: f64,
    lower_bound_pct: f64,
    upper_bound_pct: f64,
    calibration_sessions: usize,
    evaluated_sessions: usize,
    covered_sessions: usize,
    empirical_coverage: Option<f64>,
    directional_probability: bool,
    interpretation: &'static str,
}

#[derive(Debug, Clone, Serialize)]
struct PredictionRationale {
    conclusion: String,
    supporting_evidence: Vec<String>,
    opposing_evidence: Vec<String>,
    uncertainty_reasons: Vec<String>,
    model_steps: Vec<&'static str>,
}

#[derive(Debug, Clone, Serialize)]
struct HistoricalAnalog {
    rank: usize,
    session_date_et: NaiveDate,
    regime: RegimeLabel,
    standardized_euclidean_distance: f64,
    session_return_pct: f64,
    next_session_date_et: NaiveDate,
    next_session_return_pct: f64,
    next_session_direction: &'static str,
}

#[derive(Debug, Clone, Serialize)]
struct WalkForwardValidation {
    method: &'static str,
    evaluation_window_sessions: usize,
    eligible_queries: usize,
    directional_calls: usize,
    correct_directional_calls: usize,
    raw_directional_hit_frequency: Option<f64>,
    probability_interpretation_allowed: bool,
    notes: Vec<&'static str>,
}

#[derive(Debug, Clone, Serialize)]
struct FeatureValue {
    name: &'static str,
    value: f64,
    unit: &'static str,
}

#[derive(Debug, Clone, Serialize)]
struct SectorRotationChallenger {
    status: &'static str,
    feature_version: &'static str,
    applied_to_published_prediction: bool,
    required_symbols: Vec<&'static str>,
    missing_current_symbols: Vec<String>,
    feature_snapshot: Vec<FeatureValue>,
    current_leaders: Vec<SectorGroupReturn>,
    current_laggards: Vec<SectorGroupReturn>,
    validation: Option<SectorChallengerValidation>,
    promotion_gate: SectorPromotionGate,
    blockers: Vec<String>,
}

#[derive(Debug, Clone, Serialize)]
struct SectorGroupReturn {
    group: &'static str,
    symbol: &'static str,
    session_return_pct: f64,
    relative_to_spy_pct: f64,
}

#[derive(Debug, Clone, Serialize)]
struct SectorChallengerValidation {
    method: &'static str,
    matched_queries: usize,
    baseline_directional_calls: usize,
    baseline_correct_directional_calls: usize,
    baseline_raw_hit_frequency: Option<f64>,
    baseline_mean_absolute_return_error_pct: f64,
    challenger_directional_calls: usize,
    challenger_correct_directional_calls: usize,
    challenger_raw_hit_frequency: Option<f64>,
    challenger_mean_absolute_return_error_pct: f64,
    raw_hit_frequency_change: Option<f64>,
    mean_absolute_error_change_pct: f64,
    probability_interpretation_allowed: bool,
}

#[derive(Debug, Clone, Serialize)]
struct SectorPromotionGate {
    minimum_matched_queries: usize,
    minimum_directional_calls: usize,
    minimum_raw_hit_frequency_gain: f64,
    maximum_mean_absolute_error_ratio: f64,
    forward_shadow_required: bool,
    independently_promoted_artifact_required: bool,
}

#[derive(Debug, Clone, Serialize)]
struct SourceFile {
    request_name: String,
    file_name: String,
    bytes: u64,
    sha256: String,
    acquired_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize)]
struct DailySource {
    provider: &'static str,
    dataset: &'static str,
    schema: &'static str,
    session_clock: &'static str,
    history_start: NaiveDate,
    history_end: NaiveDate,
    complete_feature_sessions: usize,
    acquired_at: DateTime<Utc>,
    latest_available_at: DateTime<Utc>,
    dataset_sha256: String,
    files: Vec<SourceFile>,
}

#[derive(Debug, Clone, Serialize)]
struct DailyModelContract {
    model_id: &'static str,
    model_version: &'static str,
    owner: &'static str,
    regime_algorithm: &'static str,
    analog_algorithm: &'static str,
    feature_count: usize,
    neighbors: usize,
    minimum_analogs: usize,
    fit_semantics: &'static str,
    label_semantics: &'static str,
    status: &'static str,
    source_code: &'static str,
}

#[derive(Debug, Clone, Serialize)]
struct MacroNewsPolicy {
    status: &'static str,
    detail: &'static str,
}

#[derive(Debug, Clone)]
struct RankedAnalog {
    index: usize,
    distance: f64,
    next_return: f64,
}

#[derive(Debug)]
struct WalkForwardComputation {
    validation: WalkForwardValidation,
    residuals: Vec<f64>,
    interval_evaluated_sessions: usize,
    interval_covered_sessions: usize,
}

#[derive(Debug, Clone, Copy)]
struct AnalogPredictionSummary {
    lean: &'static str,
    up_count: usize,
    analog_count: usize,
    raw_up: f64,
    median: f64,
    average: f64,
}

#[derive(Debug, Default)]
struct ChallengerScore {
    directional_calls: usize,
    correct_directional_calls: usize,
    absolute_return_errors: Vec<f64>,
}

impl ChallengerScore {
    fn observe(&mut self, analogs: &[RankedAnalog], realized: f64) {
        let (lean, _, _, median, _) = lean_from_analogs(analogs);
        self.absolute_return_errors.push((realized - median).abs());
        if lean != "MIXED" {
            self.directional_calls += 1;
            if (lean == "UP" && realized > 0.0) || (lean == "DOWN" && realized < 0.0) {
                self.correct_directional_calls += 1;
            }
        }
    }

    fn raw_hit_frequency(&self) -> Option<f64> {
        (self.directional_calls > 0)
            .then_some(self.correct_directional_calls as f64 / self.directional_calls as f64)
    }

    fn mean_absolute_return_error(&self) -> f64 {
        if self.absolute_return_errors.is_empty() {
            0.0
        } else {
            mean(&self.absolute_return_errors)
        }
    }
}

fn utc_from_nanos(value: u64) -> Result<DateTime<Utc>> {
    let nanos: i64 = value
        .try_into()
        .context("timestamp exceeds signed nanosecond range")?;
    Ok(DateTime::<Utc>::from_timestamp_nanos(nanos))
}

fn is_regular_session(timestamp: DateTime<Utc>) -> bool {
    let local = timestamp.with_timezone(&New_York);
    let minute = local.hour() * 60 + local.minute();
    (570..960).contains(&minute)
}

fn push_daily(tape: &mut DailyTape, symbol: &str, minute: RawMinute) {
    if !is_regular_session(minute.timestamp) {
        return;
    }
    let canonical = symbol.trim().trim_start_matches("US.").to_ascii_uppercase();
    if !REQUIRED_SYMBOLS.contains(&canonical.as_str())
        && !SECTOR_ROTATION_SYMBOLS.contains(&canonical.as_str())
    {
        return;
    }
    let date = minute.timestamp.with_timezone(&New_York).date_naive();
    tape.entry(date)
        .or_default()
        .entry(canonical)
        .or_default()
        .push(
            minute.timestamp,
            minute.open,
            minute.high,
            minute.low,
            minute.close,
            minute.volume,
        );
}

fn read_dbn_into_tape(path: &Path, tape: &mut DailyTape) -> Result<()> {
    let mut decoder = DbnDecoder::from_zstd_file(path)
        .with_context(|| format!("failed opening daily-regime DBN {}", path.display()))?;
    let symbol_map = decoder.metadata().symbol_map()?;
    while let Some(record) = decoder.decode_record_ref()? {
        let Some(bar) = record.get::<OhlcvMsg>() else {
            continue;
        };
        let Some(symbol) = symbol_map.get_for_rec(bar) else {
            continue;
        };
        push_daily(
            tape,
            symbol,
            RawMinute {
                timestamp: utc_from_nanos(bar.hd.ts_event)?,
                open: bar.open as f64 / PRICE_SCALE,
                high: bar.high as f64 / PRICE_SCALE,
                low: bar.low as f64 / PRICE_SCALE,
                close: bar.close as f64 / PRICE_SCALE,
                volume: bar.volume as f64,
            },
        );
    }
    Ok(())
}

fn manifest_files(root: &Path) -> Result<Vec<PathBuf>> {
    if !root.exists() {
        bail!("DAILY_REGIME_MANIFEST_DIRECTORY_MISSING");
    }
    let mut paths = fs::read_dir(root)?
        .filter_map(|entry| entry.ok().map(|row| row.path()))
        .filter(|path| {
            path.file_name()
                .and_then(|value| value.to_str())
                .is_some_and(|name| {
                    (name.starts_with("spx_daily_regime_context_")
                        || name.starts_with("spx_daily_regime_sector_"))
                        && name.ends_with(".manifest.json")
                })
        })
        .collect::<Vec<_>>();
    paths.sort();
    Ok(paths)
}

fn raw_files(root: &Path) -> Result<Vec<PathBuf>> {
    if !root.exists() {
        bail!("DAILY_REGIME_RAW_DIRECTORY_MISSING");
    }
    let mut paths = fs::read_dir(root)?
        .filter_map(|entry| entry.ok().map(|row| row.path()))
        .filter(|path| {
            path.file_name()
                .and_then(|value| value.to_str())
                .is_some_and(|name| {
                    (name.starts_with("spx_daily_regime_context_")
                        || name.starts_with("spx_daily_regime_sector_"))
                        && name.ends_with(".dbn.zst")
                })
        })
        .collect::<Vec<_>>();
    paths.sort();
    Ok(paths)
}

fn load_historical(data_root: &Path) -> Result<HistoricalDailyData> {
    let regime_root = data_root.join("market/regime");
    let raw_root = regime_root.join("raw/EQUS.MINI/ohlcv-1m");
    let manifests = manifest_files(&regime_root.join("manifests"))?
        .into_iter()
        .map(|path| {
            let payload = fs::read(&path)?;
            serde_json::from_slice::<DataManifest>(&payload)
                .with_context(|| format!("invalid daily-regime manifest {}", path.display()))
        })
        .collect::<Result<Vec<_>>>()?;
    let raw = raw_files(&raw_root)?;
    if raw.len() < 4 || manifests.len() != raw.len() {
        bail!("DAILY_REGIME_HISTORY_COVERAGE_INCOMPLETE");
    }

    let mut tape = DailyTape::new();
    let mut lineage = Vec::new();
    let mut dataset_hasher = Sha256::new();
    let mut acquired_at = DateTime::<Utc>::MIN_UTC;
    let mut seen_requests = BTreeSet::new();
    for path in raw {
        let file_name = path
            .file_name()
            .and_then(|value| value.to_str())
            .context("daily-regime raw file has no UTF-8 name")?
            .to_string();
        let manifest = manifests
            .iter()
            .find(|row| file_name.starts_with(&row.request.name))
            .context("DAILY_REGIME_RAW_MANIFEST_MISSING")?;
        if manifest.provider != "Databento"
            || manifest.request.dataset != "EQUS.MINI"
            || manifest.request.schema != "ohlcv-1m"
            || manifest.synthetic
            || !seen_requests.insert(manifest.request.name.clone())
        {
            bail!("DAILY_REGIME_MANIFEST_REJECTED");
        }
        let metadata = fs::metadata(&path)?;
        if metadata.len() != manifest.bytes || sha256_file(&path)? != manifest.sha256 {
            bail!("DAILY_REGIME_IMMUTABLE_HASH_MISMATCH");
        }
        dataset_hasher.update(manifest.sha256.as_bytes());
        acquired_at = acquired_at.max(manifest.acquired_at);
        read_dbn_into_tape(&path, &mut tape)?;
        lineage.push(SourceFile {
            request_name: manifest.request.name.clone(),
            file_name,
            bytes: manifest.bytes,
            sha256: manifest.sha256.clone(),
            acquired_at: manifest.acquired_at,
        });
    }
    if lineage.len() < 4 {
        bail!("DAILY_REGIME_HISTORY_COVERAGE_INCOMPLETE");
    }
    Ok(HistoricalDailyData {
        tape,
        lineage,
        dataset_sha256: format!("{:x}", dataset_hasher.finalize()),
        acquired_at,
    })
}

fn historical(data_root: &Path) -> Result<Arc<HistoricalDailyData>> {
    if let Some(value) = HISTORY_CACHE.get() {
        return Ok(value.clone());
    }
    let loaded = Arc::new(load_historical(data_root)?);
    let _ = HISTORY_CACHE.set(loaded.clone());
    Ok(HISTORY_CACHE.get().cloned().unwrap_or(loaded))
}

fn append_live_rows(
    tape: &mut DailyTape,
    rows: Vec<StoredLiveMarketBar>,
    historical_cutoff: DateTime<Utc>,
) -> Option<DateTime<Utc>> {
    let mut latest_available_at = None;
    for row in rows {
        if row.provider != "databento"
            || row.dataset != "EQUS.MINI"
            || row.schema_name != "ohlcv-1m"
            || !row.symbol_mapping_verified
        {
            continue;
        }
        let Ok(timestamp) = row.event_at.parse::<DateTime<Utc>>() else {
            continue;
        };
        if timestamp <= historical_cutoff {
            continue;
        }
        let Ok(available_at) = row.available_at.parse::<DateTime<Utc>>() else {
            continue;
        };
        latest_available_at = Some(
            latest_available_at
                .map_or(available_at, |prior: DateTime<Utc>| prior.max(available_at)),
        );
        push_daily(
            tape,
            &row.symbol,
            RawMinute {
                timestamp,
                open: row.open,
                high: row.high,
                low: row.low,
                close: row.close,
                volume: row.volume,
            },
        );
    }
    latest_available_at
}

fn context_session_covered(bar: &DailyBar) -> bool {
    let (Some(first_at), Some(last_at)) = (bar.first_at, bar.last_at) else {
        return false;
    };
    let first = first_at.with_timezone(&New_York);
    let last = last_at.with_timezone(&New_York);
    bar.minute_rows >= MINIMUM_CONTEXT_ROWS
        && first.hour() * 60 + first.minute() <= CONTEXT_FIRST_MINUTE_LIMIT_ET
        && last.hour() * 60 + last.minute() >= CONTEXT_LAST_MINUTE_LIMIT_ET
}

fn complete_day(day: &BTreeMap<String, DailyBar>) -> bool {
    REQUIRED_SYMBOLS.iter().all(|symbol| {
        day.get(*symbol).is_some_and(|bar| {
            if *symbol == "SPY" {
                bar.minute_rows >= MINIMUM_PRIMARY_ROWS
            } else {
                context_session_covered(bar)
            }
        })
    })
}

fn missing_sector_symbols(day: &BTreeMap<String, DailyBar>) -> Vec<String> {
    SECTOR_ROTATION_SYMBOLS
        .iter()
        .filter(|symbol| !day.get(**symbol).is_some_and(context_session_covered))
        .map(|symbol| (*symbol).to_string())
        .collect()
}

fn mean(values: &[f64]) -> f64 {
    values.iter().sum::<f64>() / values.len() as f64
}

fn standard_deviation(values: &[f64]) -> f64 {
    if values.len() < 2 {
        return 0.0;
    }
    let center = mean(values);
    (values
        .iter()
        .map(|value| (value - center).powi(2))
        .sum::<f64>()
        / (values.len() - 1) as f64)
        .sqrt()
}

fn quantile(mut values: Vec<f64>, probability: f64) -> f64 {
    values.sort_by(f64::total_cmp);
    if values.is_empty() {
        return 0.0;
    }
    let index = probability.clamp(0.0, 1.0) * (values.len() - 1) as f64;
    let low = index.floor() as usize;
    let high = index.ceil() as usize;
    if low == high {
        values[low]
    } else {
        values[low] + (values[high] - values[low]) * (index - low as f64)
    }
}

fn session_return(bar: &DailyBar) -> f64 {
    bar.close / bar.open - 1.0
}

fn close_location(bar: &DailyBar) -> f64 {
    if bar.high > bar.low {
        (bar.close - bar.low) / (bar.high - bar.low)
    } else {
        0.5
    }
}

fn build_sector_rotation_features(
    day: &BTreeMap<String, DailyBar>,
    spy_return: f64,
) -> Option<SectorRotationFeatures> {
    if !missing_sector_symbols(day).is_empty() {
        return None;
    }
    let group_returns = SECTOR_ROTATION_SYMBOLS
        .iter()
        .map(|symbol| {
            day.get(*symbol)
                .map(session_return)
                .map(|value| ((*symbol).to_string(), value))
        })
        .collect::<Option<BTreeMap<_, _>>>()?;
    let sector_returns = [
        "XLK", "XLC", "XLY", "XLF", "XLE", "XLI", "XLV", "XLP", "XLU", "XLRE", "XLB",
    ]
    .iter()
    .map(|symbol| group_returns.get(*symbol).copied())
    .collect::<Option<Vec<_>>>()?;
    let growth_returns = ["MAGS", "SKYY", "IGV", "SOXX"]
        .iter()
        .map(|symbol| group_returns.get(*symbol).copied())
        .collect::<Option<Vec<_>>>()?;
    let defensive_returns = ["XLP", "XLV", "XLU"]
        .iter()
        .map(|symbol| group_returns.get(*symbol).copied())
        .collect::<Option<Vec<_>>>()?;
    let leadership_breadth = sector_returns
        .iter()
        .filter(|value| **value > spy_return)
        .count() as f64
        / sector_returns.len() as f64;
    let values = vec![
        group_returns["MAGS"] - spy_return,
        group_returns["SKYY"] - spy_return,
        group_returns["IGV"] - spy_return,
        leadership_breadth,
        standard_deviation(&sector_returns),
        mean(&growth_returns) - mean(&defensive_returns),
    ];
    values
        .iter()
        .all(|value| value.is_finite())
        .then_some(SectorRotationFeatures {
            values,
            group_returns,
        })
}

fn build_features(tape: &DailyTape) -> Result<Vec<FeatureRow>> {
    let complete = tape
        .iter()
        .filter(|(_, day)| complete_day(day))
        .collect::<Vec<_>>();
    if complete.len() < 100 {
        bail!("DAILY_REGIME_REQUIRES_AT_LEAST_100_COMPLETE_SESSIONS");
    }
    let mut provisional = Vec::<FeatureRow>::new();
    for index in 20..complete.len() {
        let (date, day) = complete[index];
        let spy = day.get("SPY").context("SPY_DAY_MISSING")?;
        let previous_spy = complete[index - 1]
            .1
            .get("SPY")
            .context("PREVIOUS_SPY_DAY_MISSING")?;
        let spy_5d = complete[index - 5]
            .1
            .get("SPY")
            .context("SPY_5D_DAY_MISSING")?;
        let spy_20d = complete[index - 20]
            .1
            .get("SPY")
            .context("SPY_20D_DAY_MISSING")?;
        let close_returns = (index - 19..=index)
            .map(|cursor| {
                let current = complete[cursor].1.get("SPY").expect("complete SPY");
                let previous = complete[cursor - 1].1.get("SPY").expect("complete SPY");
                current.close / previous.close - 1.0
            })
            .collect::<Vec<_>>();
        let log_volumes = (index - 19..=index)
            .map(|cursor| {
                complete[cursor]
                    .1
                    .get("SPY")
                    .expect("complete SPY")
                    .volume
                    .max(1.0)
                    .ln()
            })
            .collect::<Vec<_>>();
        let volume_sd = standard_deviation(&log_volumes);
        let spy_return = session_return(spy);
        let instrument_return = |symbol: &str| {
            day.get(symbol)
                .map(session_return)
                .context("required context symbol missing")
        };
        let qqq_return = instrument_return("QQQ")?;
        let iwm_return = instrument_return("IWM")?;
        let soxx_return = instrument_return("SOXX")?;
        let features = vec![
            spy_return,
            spy.open / previous_spy.close - 1.0,
            spy.close / spy_5d.close - 1.0,
            spy.close / spy_20d.close - 1.0,
            standard_deviation(&close_returns) * 252.0_f64.sqrt(),
            spy.high / spy.low - 1.0,
            close_location(spy),
            if volume_sd > 1.0e-12 {
                (spy.volume.max(1.0).ln() - mean(&log_volumes)) / volume_sd
            } else {
                0.0
            },
            qqq_return - spy_return,
            iwm_return - spy_return,
            soxx_return - spy_return,
            instrument_return("HYG")?,
            instrument_return("TLT")?,
            instrument_return("UUP")?,
            instrument_return("VXX")?,
        ];
        if features.iter().any(|value| !value.is_finite()) {
            continue;
        }
        let missing_sector_symbols = missing_sector_symbols(day);
        let sector_rotation = build_sector_rotation_features(day, spy_return);
        provisional.push(FeatureRow {
            date: *date,
            features,
            sector_rotation,
            missing_sector_symbols,
            regime: RegimeLabel::MixedTransition,
            spy: spy.clone(),
            coverage: day
                .iter()
                .map(|(symbol, bar)| (symbol.clone(), bar.minute_rows))
                .collect(),
        });
    }
    for index in 0..provisional.len() {
        let start = index.saturating_sub(252);
        let prior_volatility = provisional[start..index]
            .iter()
            .map(|row| row.features[4])
            .collect::<Vec<_>>();
        let current_vol = provisional[index].features[4];
        let vol_percentile = if prior_volatility.len() >= 40 {
            prior_volatility
                .iter()
                .filter(|value| **value <= current_vol)
                .count() as f64
                / prior_volatility.len() as f64
        } else {
            0.5
        };
        provisional[index].regime = classify_regime(&provisional[index].features, vol_percentile);
    }
    Ok(provisional)
}

fn cross_asset_breadth(features: &[f64]) -> f64 {
    [8, 9, 10, 11]
        .iter()
        .filter(|index| features[**index] + features[0] > 0.0)
        .count() as f64
        / 4.0
}

fn classify_regime(features: &[f64], volatility_percentile: f64) -> RegimeLabel {
    let one_day = features[0];
    let trend_20d = features[3];
    let hyg = features[11];
    let breadth = cross_asset_breadth(features);
    if volatility_percentile >= 0.75 && one_day <= -0.0075 {
        RegimeLabel::HighVolSellOff
    } else if volatility_percentile >= 0.75 && one_day >= 0.0075 {
        RegimeLabel::HighVolRecovery
    } else if volatility_percentile <= 0.25 && trend_20d >= 0.02 && breadth >= 0.5 && hyg >= 0.0 {
        RegimeLabel::LowVolBreakout
    } else if trend_20d >= 0.02 && breadth >= 0.5 && hyg >= 0.0 {
        RegimeLabel::RiskOnTrend
    } else if trend_20d <= -0.02 && breadth <= 0.5 && hyg < 0.0 {
        RegimeLabel::RiskOffTrend
    } else if volatility_percentile >= 0.75 {
        RegimeLabel::HighVolRange
    } else if volatility_percentile <= 0.25 && trend_20d.abs() < 0.02 {
        RegimeLabel::LowVolRange
    } else {
        RegimeLabel::MixedTransition
    }
}

fn volatility_percentile(rows: &[FeatureRow], index: usize) -> f64 {
    let start = index.saturating_sub(252);
    let prior = &rows[start..index];
    if prior.len() < 40 {
        return 0.5;
    }
    prior
        .iter()
        .filter(|row| row.features[4] <= rows[index].features[4])
        .count() as f64
        / prior.len() as f64
}

fn ranked_same_regime_history(
    rows: &[FeatureRow],
    query_index: usize,
    purge_sessions: usize,
) -> Vec<RankedAnalog> {
    if query_index <= purge_sessions + 2 {
        return Vec::new();
    }
    let query = &rows[query_index];
    let last_candidate = query_index.saturating_sub(purge_sessions + 2);
    let candidate_indices = (0..=last_candidate)
        .filter(|index| {
            *index + 1 < rows.len()
                && rows[*index].regime == query.regime
                && rows[*index + 1].date < query.date
        })
        .collect::<Vec<_>>();
    if candidate_indices.len() < MINIMUM_ANALOGS {
        return Vec::new();
    }
    let mut centers = vec![0.0; FEATURE_NAMES.len()];
    let mut scales = vec![1.0; FEATURE_NAMES.len()];
    for dimension in 0..FEATURE_NAMES.len() {
        let values = candidate_indices
            .iter()
            .map(|index| rows[*index].features[dimension])
            .collect::<Vec<_>>();
        centers[dimension] = mean(&values);
        scales[dimension] = standard_deviation(&values).max(1.0e-9);
    }
    let mut ranked = candidate_indices
        .into_iter()
        .map(|index| {
            let squared = (0..FEATURE_NAMES.len())
                .map(|dimension| {
                    let query_z =
                        (query.features[dimension] - centers[dimension]) / scales[dimension];
                    let analog_z =
                        (rows[index].features[dimension] - centers[dimension]) / scales[dimension];
                    (query_z - analog_z).powi(2)
                })
                .sum::<f64>();
            RankedAnalog {
                index,
                distance: (squared / FEATURE_NAMES.len() as f64).sqrt(),
                next_return: rows[index + 1].spy.close / rows[index].spy.close - 1.0,
            }
        })
        .collect::<Vec<_>>();
    ranked.sort_by(|left, right| {
        left.distance
            .total_cmp(&right.distance)
            .then_with(|| rows[right.index].date.cmp(&rows[left.index].date))
    });
    ranked
}

fn nearest_analogs(
    rows: &[FeatureRow],
    query_index: usize,
    purge_sessions: usize,
) -> Vec<RankedAnalog> {
    ranked_same_regime_history(rows, query_index, purge_sessions)
        .into_iter()
        .take(ANALOG_NEIGHBORS)
        .collect()
}

fn paired_sector_analogs(
    rows: &[FeatureRow],
    query_index: usize,
    purge_sessions: usize,
    include_sector_features: bool,
) -> Vec<RankedAnalog> {
    if query_index <= purge_sessions + 2 || rows[query_index].sector_rotation.is_none() {
        return Vec::new();
    }
    let query = &rows[query_index];
    let last_candidate = query_index.saturating_sub(purge_sessions + 2);
    let candidate_indices = (0..=last_candidate)
        .filter(|index| {
            *index + 1 < rows.len()
                && rows[*index].regime == query.regime
                && rows[*index + 1].date < query.date
                && rows[*index].sector_rotation.is_some()
        })
        .collect::<Vec<_>>();
    if candidate_indices.len() < MINIMUM_ANALOGS {
        return Vec::new();
    }
    let vector = |row: &FeatureRow| {
        let mut values = row.features.clone();
        if include_sector_features {
            values.extend(
                row.sector_rotation
                    .as_ref()
                    .expect("sector-filtered row")
                    .values
                    .iter()
                    .copied(),
            );
        }
        values
    };
    let query_features = vector(query);
    let dimensions = query_features.len();
    let mut centers = vec![0.0; dimensions];
    let mut scales = vec![1.0; dimensions];
    for dimension in 0..dimensions {
        let values = candidate_indices
            .iter()
            .map(|index| vector(&rows[*index])[dimension])
            .collect::<Vec<_>>();
        centers[dimension] = mean(&values);
        scales[dimension] = standard_deviation(&values).max(1.0e-9);
    }
    let mut ranked = candidate_indices
        .into_iter()
        .map(|index| {
            let candidate_features = vector(&rows[index]);
            let squared = (0..dimensions)
                .map(|dimension| {
                    let query_z =
                        (query_features[dimension] - centers[dimension]) / scales[dimension];
                    let analog_z =
                        (candidate_features[dimension] - centers[dimension]) / scales[dimension];
                    (query_z - analog_z).powi(2)
                })
                .sum::<f64>();
            RankedAnalog {
                index,
                distance: (squared / dimensions as f64).sqrt(),
                next_return: rows[index + 1].spy.close / rows[index].spy.close - 1.0,
            }
        })
        .collect::<Vec<_>>();
    ranked.sort_by(|left, right| {
        left.distance
            .total_cmp(&right.distance)
            .then_with(|| rows[right.index].date.cmp(&rows[left.index].date))
    });
    ranked.truncate(ANALOG_NEIGHBORS);
    ranked
}

fn evaluate_sector_challenger(rows: &[FeatureRow]) -> Option<SectorChallengerValidation> {
    let start = rows.len().saturating_sub(127).max(80);
    let mut matched_queries = 0;
    let mut baseline = ChallengerScore::default();
    let mut challenger = ChallengerScore::default();
    for query_index in start..rows.len().saturating_sub(1) {
        let baseline_analogs = paired_sector_analogs(rows, query_index, 1, false);
        let challenger_analogs = paired_sector_analogs(rows, query_index, 1, true);
        if baseline_analogs.len() < MINIMUM_ANALOGS || challenger_analogs.len() < MINIMUM_ANALOGS {
            continue;
        }
        matched_queries += 1;
        let realized = rows[query_index + 1].spy.close / rows[query_index].spy.close - 1.0;
        baseline.observe(&baseline_analogs, realized);
        challenger.observe(&challenger_analogs, realized);
    }
    if matched_queries == 0 {
        return None;
    }
    let baseline_hit = baseline.raw_hit_frequency();
    let challenger_hit = challenger.raw_hit_frequency();
    let baseline_mae = baseline.mean_absolute_return_error();
    let challenger_mae = challenger.mean_absolute_return_error();
    Some(SectorChallengerValidation {
        method: "PAIRED_PURGED_EXPANDING_WALK_FORWARD",
        matched_queries,
        baseline_directional_calls: baseline.directional_calls,
        baseline_correct_directional_calls: baseline.correct_directional_calls,
        baseline_raw_hit_frequency: baseline_hit,
        baseline_mean_absolute_return_error_pct: baseline_mae * 100.0,
        challenger_directional_calls: challenger.directional_calls,
        challenger_correct_directional_calls: challenger.correct_directional_calls,
        challenger_raw_hit_frequency: challenger_hit,
        challenger_mean_absolute_return_error_pct: challenger_mae * 100.0,
        raw_hit_frequency_change: baseline_hit
            .zip(challenger_hit)
            .map(|(baseline, challenger)| challenger - baseline),
        mean_absolute_error_change_pct: (challenger_mae - baseline_mae) * 100.0,
        probability_interpretation_allowed: false,
    })
}

fn lean_from_analogs(analogs: &[RankedAnalog]) -> (&'static str, usize, f64, f64, f64) {
    let up_count = analogs
        .iter()
        .filter(|analog| analog.next_return > 0.0)
        .count();
    let raw_up = up_count as f64 / analogs.len() as f64;
    let returns = analogs
        .iter()
        .map(|analog| analog.next_return)
        .collect::<Vec<_>>();
    let median = quantile(returns.clone(), 0.5);
    let average = mean(&returns);
    let lean = if raw_up >= DIRECTIONAL_AGREEMENT_THRESHOLD && median > 0.0 {
        "UP"
    } else if raw_up <= 1.0 - DIRECTIONAL_AGREEMENT_THRESHOLD && median < 0.0 {
        "DOWN"
    } else {
        "MIXED"
    };
    (lean, up_count, raw_up, median, average)
}

fn conformal_residual_quantile(residuals: &[f64], coverage: f64) -> Option<f64> {
    if residuals.is_empty() {
        return None;
    }
    let mut sorted = residuals.to_vec();
    sorted.sort_by(f64::total_cmp);
    let rank = (((sorted.len() + 1) as f64 * coverage).ceil() as usize).clamp(1, sorted.len());
    Some(sorted[rank - 1])
}

fn wilson_score_interval(successes: usize, trials: usize, z: f64) -> Option<(f64, f64)> {
    if trials == 0 || !z.is_finite() || z <= 0.0 || successes > trials {
        return None;
    }
    let n = trials as f64;
    let proportion = successes as f64 / n;
    let z_squared = z * z;
    let denominator = 1.0 + z_squared / n;
    let center = (proportion + z_squared / (2.0 * n)) / denominator;
    let radius = z * ((proportion * (1.0 - proportion) / n) + z_squared / (4.0 * n * n)).sqrt()
        / denominator;
    Some(((center - radius).max(0.0), (center + radius).min(1.0)))
}

fn walk_forward(rows: &[FeatureRow]) -> WalkForwardComputation {
    let start = rows.len().saturating_sub(127).max(80);
    let mut eligible_queries = 0;
    let mut directional_calls = 0;
    let mut correct = 0;
    let mut residuals = Vec::new();
    let mut interval_evaluated_sessions = 0;
    let mut interval_covered_sessions = 0;
    for query_index in start..rows.len().saturating_sub(1) {
        let analogs = nearest_analogs(rows, query_index, 1);
        if analogs.len() < MINIMUM_ANALOGS {
            continue;
        }
        eligible_queries += 1;
        let realized = rows[query_index + 1].spy.close / rows[query_index].spy.close - 1.0;
        let (lean, _, _, median, _) = lean_from_analogs(&analogs);
        if residuals.len() >= MINIMUM_INTERVAL_CALIBRATION_SESSIONS
            && let Some(radius) =
                conformal_residual_quantile(&residuals, PREDICTION_INTERVAL_COVERAGE)
        {
            interval_evaluated_sessions += 1;
            if (realized - median).abs() <= radius {
                interval_covered_sessions += 1;
            }
        }
        residuals.push((realized - median).abs());
        if lean != "MIXED" {
            directional_calls += 1;
            if (lean == "UP" && realized > 0.0) || (lean == "DOWN" && realized < 0.0) {
                correct += 1;
            }
        }
    }
    WalkForwardComputation {
        validation: WalkForwardValidation {
            method: "PURGED_EXPANDING_WALK_FORWARD",
            evaluation_window_sessions: rows.len().saturating_sub(start + 1),
            eligible_queries,
            directional_calls,
            correct_directional_calls: correct,
            raw_directional_hit_frequency: (directional_calls > 0)
                .then_some(correct as f64 / directional_calls as f64),
            probability_interpretation_allowed: false,
            notes: vec![
                "Each validation query uses only earlier sessions and next-session labels already available before that query.",
                "One full session is purged between an analog label and the validation query.",
                "Directional calls require at least 60% raw sign agreement plus a same-sign median return.",
                "The raw hit frequency is descriptive and is not a calibrated probability.",
            ],
        },
        residuals,
        interval_evaluated_sessions,
        interval_covered_sessions,
    }
}

fn observation_cutoff(row: &FeatureRow) -> Result<DateTime<Utc>> {
    row.spy.last_at.context("SPY_OBSERVATION_CUTOFF_MISSING")
}

fn feature_snapshot(row: &FeatureRow) -> Vec<FeatureValue> {
    row.features
        .iter()
        .enumerate()
        .map(|(index, value)| FeatureValue {
            name: FEATURE_NAMES[index],
            value: if matches!(index, 6 | 7) {
                *value
            } else {
                *value * 100.0
            },
            unit: if index == 6 {
                "fraction_of_session_range"
            } else if index == 7 {
                "z_score"
            } else {
                "percent"
            },
        })
        .collect()
}

fn sector_rotation_challenger(
    rows: &[FeatureRow],
    current: &FeatureRow,
) -> SectorRotationChallenger {
    let validation = evaluate_sector_challenger(rows);
    let mut group_returns = current
        .sector_rotation
        .as_ref()
        .map(|features| {
            SECTOR_ROTATION_GROUPS
                .iter()
                .filter_map(|(group, symbol)| {
                    features
                        .group_returns
                        .get(*symbol)
                        .map(|value| SectorGroupReturn {
                            group,
                            symbol,
                            session_return_pct: value * 100.0,
                            relative_to_spy_pct: (value - current.features[0]) * 100.0,
                        })
                })
                .collect::<Vec<_>>()
        })
        .unwrap_or_default();
    group_returns.sort_by(|left, right| {
        right
            .session_return_pct
            .total_cmp(&left.session_return_pct)
            .then_with(|| left.symbol.cmp(right.symbol))
    });
    let current_leaders = group_returns.iter().take(3).cloned().collect::<Vec<_>>();
    let current_laggards = group_returns
        .iter()
        .rev()
        .take(3)
        .cloned()
        .collect::<Vec<_>>();
    let feature_snapshot = current
        .sector_rotation
        .as_ref()
        .map(|features| {
            features
                .values
                .iter()
                .enumerate()
                .map(|(index, value)| FeatureValue {
                    name: SECTOR_ROTATION_FEATURE_NAMES[index],
                    value: if index == 3 { *value } else { *value * 100.0 },
                    unit: if index == 3 { "fraction" } else { "percent" },
                })
                .collect::<Vec<_>>()
        })
        .unwrap_or_default();
    let promotion_gate = SectorPromotionGate {
        minimum_matched_queries: SECTOR_CHALLENGER_MINIMUM_QUERIES,
        minimum_directional_calls: SECTOR_CHALLENGER_MINIMUM_DIRECTIONAL_CALLS,
        minimum_raw_hit_frequency_gain: SECTOR_CHALLENGER_MINIMUM_HIT_GAIN,
        maximum_mean_absolute_error_ratio: SECTOR_CHALLENGER_MAXIMUM_MAE_RATIO,
        forward_shadow_required: true,
        independently_promoted_artifact_required: true,
    };
    let mut blockers = Vec::new();
    if current.sector_rotation.is_none() {
        blockers.push(format!(
            "The current completed session lacks point-in-time edge coverage for: {}.",
            current.missing_sector_symbols.join(", ")
        ));
    }
    let status = match validation.as_ref() {
        None => {
            blockers.push(
                "No matched causal walk-forward queries have complete sector-rotation history."
                    .to_string(),
            );
            "BLOCKED_POINT_IN_TIME_SECTOR_HISTORY_INCOMPLETE"
        }
        Some(result) if result.matched_queries < SECTOR_CHALLENGER_MINIMUM_QUERIES => {
            blockers.push(format!(
                "Only {} matched walk-forward queries are available; at least {} are required.",
                result.matched_queries, SECTOR_CHALLENGER_MINIMUM_QUERIES
            ));
            "BLOCKED_SECTOR_WALK_FORWARD_COVERAGE_INSUFFICIENT"
        }
        Some(result) => {
            let minimum_calls = SECTOR_CHALLENGER_MINIMUM_DIRECTIONAL_CALLS
                .max(((result.baseline_directional_calls as f64) * 0.8).ceil() as usize);
            let hit_gate = result
                .raw_hit_frequency_change
                .is_some_and(|change| change >= SECTOR_CHALLENGER_MINIMUM_HIT_GAIN);
            let mae_gate = if result.baseline_mean_absolute_return_error_pct > 0.0 {
                result.challenger_mean_absolute_return_error_pct
                    / result.baseline_mean_absolute_return_error_pct
                    <= SECTOR_CHALLENGER_MAXIMUM_MAE_RATIO
            } else {
                result.challenger_mean_absolute_return_error_pct <= 0.0
            };
            let call_gate = result.challenger_directional_calls >= minimum_calls;
            if !hit_gate {
                blockers.push(
                    "The paired walk-forward raw hit-frequency gain is below the predeclared two-percentage-point research gate."
                        .to_string(),
                );
            }
            if !mae_gate {
                blockers.push(
                    "The sector challenger increases mean absolute next-session return error."
                        .to_string(),
                );
            }
            if !call_gate {
                blockers.push(format!(
                    "The challenger made {} directional calls; at least {minimum_calls} are required for matched coverage.",
                    result.challenger_directional_calls
                ));
            }
            if hit_gate && mae_gate && call_gate && current.sector_rotation.is_some() {
                "ELIGIBLE_FOR_FORWARD_SHADOW_NOT_PROMOTED"
            } else {
                "REJECTED_NO_PAIRED_WALK_FORWARD_IMPROVEMENT"
            }
        }
    };
    blockers.push(
        "An untouched holdout, forward-shadow receipt, immutable artifact, and manual promotion are required before these features may affect customer publication."
            .to_string(),
    );
    SectorRotationChallenger {
        status,
        feature_version: "sector-rotation-session-close.v1",
        applied_to_published_prediction: false,
        required_symbols: SECTOR_ROTATION_SYMBOLS.to_vec(),
        missing_current_symbols: current.missing_sector_symbols.clone(),
        feature_snapshot,
        current_leaders,
        current_laggards,
        validation,
        promotion_gate,
        blockers,
    }
}

fn historical_sessions(rows: &[FeatureRow], analogs: &[RankedAnalog]) -> Vec<HistoricalAnalog> {
    analogs
        .iter()
        .enumerate()
        .map(|(rank, analog)| HistoricalAnalog {
            rank: rank + 1,
            session_date_et: rows[analog.index].date,
            regime: rows[analog.index].regime,
            standardized_euclidean_distance: analog.distance,
            session_return_pct: session_return(&rows[analog.index].spy) * 100.0,
            next_session_date_et: rows[analog.index + 1].date,
            next_session_return_pct: analog.next_return * 100.0,
            next_session_direction: if analog.next_return > 0.0 {
                "UP"
            } else if analog.next_return < 0.0 {
                "DOWN"
            } else {
                "FLAT"
            },
        })
        .collect()
}

fn regime_taxonomy(active: RegimeLabel) -> Vec<RegimeTaxonomyEntry> {
    REGIME_TAXONOMY
        .iter()
        .enumerate()
        .map(|(index, label)| RegimeTaxonomyEntry {
            priority: index + 1,
            label: *label,
            display_name: label.display_name(),
            definition: label.definition(),
            selection_rule: label.selection_rule(),
            active: *label == active,
        })
        .collect()
}

fn regime_classification_reasons(current: &FeatureRow, volatility_percentile: f64) -> Vec<String> {
    let one_day = current.features[0] * 100.0;
    let trend_20d = current.features[3] * 100.0;
    let breadth = cross_asset_breadth(&current.features) * 100.0;
    let hyg = current.features[11] * 100.0;
    let volatility_tier = if volatility_percentile >= 0.75 {
        "high"
    } else if volatility_percentile <= 0.25 {
        "low"
    } else {
        "middle"
    };
    let trend_tier = if trend_20d >= 2.0 {
        "positive"
    } else if trend_20d <= -2.0 {
        "negative"
    } else {
        "flat-to-mixed"
    };
    vec![
        format!(
            "SPY completed-session return was {one_day:+.2}%; the high-volatility directional trigger is ±0.75% and also requires volatility at or above the 75th percentile."
        ),
        format!(
            "The 20-session SPY return was {trend_20d:+.2}%, classified as {trend_tier} relative to the ±2.00% trend thresholds."
        ),
        format!(
            "The 20-session annualized volatility ranked at the {:.2}th percentile of the prior 252 sessions, which is the {volatility_tier} volatility tier.",
            volatility_percentile * 100.0
        ),
        format!(
            "Cross-asset breadth was {breadth:.2}% and HYG returned {hyg:+.2}% in the completed session."
        ),
        format!(
            "The ordered eight-state decision tree selected {} because no higher-priority state matched all of its required conditions.",
            current.regime.display_name()
        ),
    ]
}

fn prediction_rationale(
    current: &FeatureRow,
    all_same_regime_count: usize,
    prediction: AnalogPredictionSummary,
    interval: &PredictionInterval,
    validation: &WalkForwardValidation,
) -> PredictionRationale {
    let AnalogPredictionSummary {
        lean,
        up_count,
        analog_count,
        raw_up,
        median,
        average,
    } = prediction;
    let down_or_flat_count = analog_count - up_count;
    let agreement = raw_up.max(1.0 - raw_up);
    let mut supporting_evidence = Vec::new();
    let mut opposing_evidence = Vec::new();
    if up_count > 0 {
        supporting_evidence.push(format!(
            "{up_count} of {analog_count} nearest same-regime analogs were followed by an up session ({:.2}% raw frequency).",
            raw_up * 100.0
        ));
    }
    if down_or_flat_count > 0 {
        opposing_evidence.push(format!(
            "{down_or_flat_count} of {analog_count} nearest same-regime analogs were followed by a down or flat session ({:.2}% raw frequency).",
            (1.0 - raw_up) * 100.0
        ));
    }
    let median_sentence = format!(
        "The nearest-analog median next-session return was {:+.3}% and the mean was {:+.3}%.",
        median * 100.0,
        average * 100.0
    );
    if median > 0.0 {
        supporting_evidence.push(median_sentence);
    } else {
        opposing_evidence.push(median_sentence);
    }
    if current.features[3] > 0.0 {
        supporting_evidence.push(format!(
            "SPY's completed 20-session return was {:+.2}%, while cross-asset breadth was {:.2}%.",
            current.features[3] * 100.0,
            cross_asset_breadth(&current.features) * 100.0
        ));
    } else {
        opposing_evidence.push(format!(
            "SPY's completed 20-session return was {:+.2}%, while cross-asset breadth was {:.2}%.",
            current.features[3] * 100.0,
            cross_asset_breadth(&current.features) * 100.0
        ));
    }

    let mut uncertainty_reasons = vec![
        format!(
            "The current state has {all_same_regime_count} mature historical matches; only the 15 nearest are used for the directional rule."
        ),
        format!(
            "The 90% prequential conformal return interval is {:+.3}% to {:+.3}%; it is a return interval, not a directional probability.",
            interval.lower_bound_pct, interval.upper_bound_pct
        ),
        "Macro releases and news are display-only context and are not numerical inputs to this version of the Rust model.".to_string(),
    ];
    if agreement < DIRECTIONAL_AGREEMENT_THRESHOLD {
        uncertainty_reasons.push(format!(
            "Raw directional agreement was {:.2}%, below the required {:.0}% threshold, so no directional confidence number is published.",
            agreement * 100.0,
            DIRECTIONAL_AGREEMENT_THRESHOLD * 100.0
        ));
    }
    if interval.lower_bound_pct <= 0.0 && interval.upper_bound_pct >= 0.0 {
        uncertainty_reasons.push(
            "The return prediction interval crosses zero, so both positive and negative next-session outcomes remain historically plausible."
                .to_string(),
        );
    }
    let conclusion = if lean == "UP" {
        format!(
            "UP research lean: raw directional agreement is {:.2}% and the analog median is positive. This agreement is not a calibrated probability.",
            agreement * 100.0
        )
    } else if lean == "DOWN" {
        format!(
            "DOWN research lean: raw directional agreement is {:.2}% and the analog median is negative. This agreement is not a calibrated probability.",
            agreement * 100.0
        )
    } else {
        format!(
            "NO DIRECTIONAL CALL: raw agreement is {:.2}%, below the {:.0}% publication threshold.",
            agreement * 100.0,
            DIRECTIONAL_AGREEMENT_THRESHOLD * 100.0
        )
    };
    let validation_sentence = validation
        .raw_directional_hit_frequency
        .map(|hit| {
            format!(
                "Purged walk-forward validation made {} threshold-qualified directional calls with {:.2}% raw historical accuracy; this is not a future probability.",
                validation.directional_calls,
                hit * 100.0
            )
        })
        .unwrap_or_else(|| {
            "Purged walk-forward validation produced no threshold-qualified directional calls."
                .to_string()
        });
    uncertainty_reasons.push(validation_sentence);

    PredictionRationale {
        conclusion,
        supporting_evidence,
        opposing_evidence,
        uncertainty_reasons,
        model_steps: vec![
            "Read only completed, manifest-verified Databento regular sessions and map SPX to SPY.",
            "Construct 15 causal SPY price-volume and cross-asset features.",
            "Apply the ordered eight-regime deterministic state classifier.",
            "Fit feature scaling only on mature, earlier sessions in the selected regime.",
            "Rank every mature same-regime session by standardized-Euclidean distance and use the nearest 15 for the directional rule.",
            "Publish UP or DOWN only when raw sign agreement is at least 60% and the median return has the same sign; otherwise publish no directional call.",
            "Build the 90% return interval from earlier prequential absolute forecast residuals with a one-session purge.",
        ],
    }
}

pub fn build_daily_regime_report(
    data_root: &Path,
    live_database: &Path,
) -> Result<DailyRegimeReport> {
    let history = historical(data_root)?;
    let mut tape = history.tape.clone();
    let historical_cutoff = tape
        .values()
        .flat_map(|day| day.values())
        .filter_map(|bar| bar.last_at)
        .max()
        .context("DAILY_REGIME_HISTORY_CUTOFF_MISSING")?;
    let mut latest_available_at = history.acquired_at;
    if live_database.exists() {
        let live_symbols = REQUIRED_SYMBOLS
            .iter()
            .chain(SECTOR_ROTATION_SYMBOLS.iter())
            .copied()
            .collect::<BTreeSet<_>>();
        for symbol in live_symbols {
            if let Some(available_at) = append_live_rows(
                &mut tape,
                // Preserve enough append-only SQLite history to bridge the
                // immutable Databento batch until the next scheduled batch
                // archive. Public live-bar APIs remain capped at 5,000 rows.
                latest_live_bars(live_database, symbol, 250_000)?,
                historical_cutoff,
            ) {
                latest_available_at = latest_available_at.max(available_at);
            }
        }
    }
    let rows = build_features(&tape)?;
    let current_index = rows.len() - 1;
    let current = &rows[current_index];
    let all_same_regime = ranked_same_regime_history(&rows, current_index, 0);
    let analogs = all_same_regime
        .iter()
        .take(ANALOG_NEIGHBORS)
        .cloned()
        .collect::<Vec<_>>();
    if analogs.len() < MINIMUM_ANALOGS {
        bail!("DAILY_REGIME_ANALOG_COVERAGE_INSUFFICIENT");
    }
    let (lean, up_count, raw_up, median, average) = lean_from_analogs(&analogs);
    let walk_forward = walk_forward(&rows);
    let interval_radius =
        conformal_residual_quantile(&walk_forward.residuals, PREDICTION_INTERVAL_COVERAGE)
            .context("DAILY_REGIME_INTERVAL_CALIBRATION_INSUFFICIENT")?;
    let prediction_interval = PredictionInterval {
        method: "PREQUENTIAL_ABSOLUTE_RESIDUAL_CONFORMAL",
        nominal_coverage: PREDICTION_INTERVAL_COVERAGE,
        point_estimate_pct: median * 100.0,
        lower_bound_pct: (median - interval_radius) * 100.0,
        upper_bound_pct: (median + interval_radius) * 100.0,
        calibration_sessions: walk_forward.residuals.len(),
        evaluated_sessions: walk_forward.interval_evaluated_sessions,
        covered_sessions: walk_forward.interval_covered_sessions,
        empirical_coverage: (walk_forward.interval_evaluated_sessions > 0).then_some(
            walk_forward.interval_covered_sessions as f64
                / walk_forward.interval_evaluated_sessions as f64,
        ),
        directional_probability: false,
        interpretation: "A 90% next-session return prediction interval centered on the nearest-analog median and calibrated from earlier prequential absolute residuals. It is not a directional probability or guarantee.",
    };
    let volatility_percentile = volatility_percentile(&rows, current_index);
    let history_start = rows.first().context("NO_FEATURE_ROWS")?.date;
    let history_end = current.date;
    let similar_historical_sessions = historical_sessions(&rows, &analogs);
    let same_regime_history = historical_sessions(&rows, &all_same_regime);
    let raw_directional_agreement = raw_up.max(1.0 - raw_up);
    let (raw_up_lower_bound, raw_up_upper_bound) =
        wilson_score_interval(up_count, analogs.len(), NORMAL_95_TWO_SIDED_Z)
            .context("DAILY_REGIME_RAW_LIKELIHOOD_INTERVAL_UNAVAILABLE")?;
    let prediction_rationale = prediction_rationale(
        current,
        same_regime_history.len(),
        AnalogPredictionSummary {
            lean,
            up_count,
            analog_count: analogs.len(),
            raw_up,
            median,
            average,
        },
        &prediction_interval,
        &walk_forward.validation,
    );
    let sector_rotation_challenger = sector_rotation_challenger(&rows, current);
    let classification_reasons = regime_classification_reasons(current, volatility_percentile);

    Ok(DailyRegimeReport {
        schema_version: "axio.daily-regime.v3",
        status: "AVAILABLE_UNCALIBRATED",
        result_kind: "NEXT_REGULAR_SESSION_ANALOG_LEAN",
        generated_at: Utc::now(),
        observation_cutoff: observation_cutoff(current)?,
        public_symbol: "SPX",
        data_symbol: "SPY",
        proxy_disclosure: "SPX uses SPY for price, volume, and next-session return research.",
        forecast_horizon: "NEXT_COMPLETE_US_REGULAR_SESSION",
        current_regime: CurrentRegime {
            label: current.regime,
            display_name: current.regime.display_name(),
            definition: current.regime.definition(),
            market_summary: format!(
                "SPY closed {:+.2}% for the session, its 20-session return was {:+.2}%, 20-session annualized volatility was {:.2}%, volatility ranked at the {:.2}th percentile, and cross-asset breadth was {:.2}%.",
                current.features[0] * 100.0,
                current.features[3] * 100.0,
                current.features[4] * 100.0,
                volatility_percentile * 100.0,
                cross_asset_breadth(&current.features) * 100.0,
            ),
            classification_reasons,
            volatility_percentile_prior_252: volatility_percentile,
            cross_asset_breadth: cross_asset_breadth(&current.features),
        },
        regime_taxonomy: regime_taxonomy(current.regime),
        current_market: CurrentMarket {
            session_date_et: current.date,
            open: current.spy.open,
            high: current.spy.high,
            low: current.spy.low,
            close: current.spy.close,
            session_return_pct: current.features[0] * 100.0,
            twenty_session_return_pct: current.features[3] * 100.0,
            twenty_session_annualized_volatility_pct: current.features[4] * 100.0,
            close_location_pct: current.features[6] * 100.0,
            minute_coverage: current.coverage.clone(),
        },
        prediction: NextSessionLean {
            lean,
            directional_call_status: if lean == "MIXED" {
                "WITHHELD_INSUFFICIENT_AGREEMENT"
            } else {
                "PUBLISHED_RAW_RESEARCH_LEAN"
            },
            target_definition: "SPY next regular-session close divided by the current regular-session close, minus one.",
            analog_sample_size: analogs.len(),
            raw_up_count: up_count,
            raw_down_or_flat_count: analogs.len() - up_count,
            raw_up_frequency: raw_up,
            raw_directional_agreement,
            minimum_directional_agreement: DIRECTIONAL_AGREEMENT_THRESHOLD,
            reported_evidence_strength: (lean != "MIXED").then_some(raw_directional_agreement),
            median_next_session_return_pct: median * 100.0,
            mean_next_session_return_pct: average * 100.0,
            calibrated_probability: false,
            interpretation: "A directional research lean is published only when nearest-analog sign agreement is at least 60% and the median return has the same sign. Otherwise the directional call and confidence number are withheld.",
        },
        raw_likelihood: RawLikelihoodEstimate {
            method: "NEAREST_SAME_REGIME_EMPIRICAL_SIGN_FREQUENCY",
            sample_size: analogs.len(),
            up_count,
            down_or_flat_count: analogs.len() - up_count,
            up_estimate: raw_up,
            down_or_flat_estimate: 1.0 - raw_up,
            confidence_method: "WILSON_SCORE_INTERVAL",
            confidence_level: RAW_LIKELIHOOD_CONFIDENCE_LEVEL,
            up_lower_bound: raw_up_lower_bound,
            up_upper_bound: raw_up_upper_bound,
            calibrated_probability: false,
            interpretation: "The displayed up and down-or-flat likelihoods are the honest raw outcome shares among the 15 nearest same-regime analogs. The 95% Wilson interval quantifies sampling uncertainty in the raw up share. These values are uncalibrated and are not a promoted forecast probability.",
        },
        prediction_interval,
        prediction_rationale,
        similar_historical_sessions,
        same_regime_history,
        walk_forward_validation: walk_forward.validation,
        feature_snapshot: feature_snapshot(current),
        sector_rotation_challenger,
        source: DailySource {
            provider: "Databento",
            dataset: "EQUS.MINI",
            schema: "ohlcv-1m",
            session_clock: "09:30-16:00 America/New_York",
            history_start,
            history_end,
            complete_feature_sessions: rows.len(),
            acquired_at: history.acquired_at,
            latest_available_at,
            dataset_sha256: history.dataset_sha256.clone(),
            files: history.lineage.clone(),
        },
        model_contract: DailyModelContract {
            model_id: "axio7.spx-next-session-regime-analog",
            model_version: "2026-07-30.v4",
            owner: "quant_engine_rs",
            regime_algorithm: "Ordered causal eight-state trend-volatility-breadth decision tree using only completed sessions.",
            analog_algorithm: "All mature same-regime sessions are ranked by standardized-Euclidean distance over 15 causal features; the nearest 15 drive the thresholded directional rule and prequential conformal return interval.",
            feature_count: FEATURE_NAMES.len(),
            neighbors: ANALOG_NEIGHBORS,
            minimum_analogs: MINIMUM_ANALOGS,
            fit_semantics: "Feature scaling is fit only on eligible historical analog candidates before each query cutoff.",
            label_semantics: "Raw next-session close-to-close return; labels must be available before reuse.",
            status: "UNCALIBRATED_RESEARCH_OUTPUT",
            source_code: "quant_engine_rs/src/daily_regime.rs",
        },
        macro_news_policy: MacroNewsPolicy {
            status: "DISPLAY_CONTEXT_ONLY_NOT_NUMERICAL_MODEL_INPUT",
            detail: "Current macro releases and news may be attached by the web orchestration layer with source and as-of times. They do not change this Rust analog lean until a point-in-time feature artifact is separately validated and promoted.",
        },
        probability_published: false,
        automatic_execution_enabled: false,
        caveats: vec![
            "Raw analog frequencies and walk-forward hit frequencies are descriptive statistics, not calibrated probabilities.",
            "The raw likelihood estimate and its Wilson interval are shown for transparency but are not a calibrated or promoted forecast probability.",
            "The 90% conformal interval is a next-session return prediction interval, not a 90% directional probability.",
            "No directional confidence number is published when raw nearest-analog agreement is below 60%.",
            "SPY is an explicit proxy for SPX price and volume research.",
            "The historical window begins in 2023 and does not represent every possible market cycle.",
            "Sector and theme rotation features remain a separately evaluated challenger and do not alter the published baseline result without an untouched holdout, forward shadow, immutable artifact, and manual promotion.",
            "Macro and news context shown by the website is not yet a numerical input to this daily analog model.",
            "No output is an order, personalized recommendation, or guarantee.",
        ],
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn feature_row(index: usize, regime: RegimeLabel, next_direction_seed: f64) -> FeatureRow {
        FeatureRow {
            date: NaiveDate::from_ymd_opt(2025, 1, 1).unwrap()
                + chrono::Duration::days(index as i64),
            features: vec![next_direction_seed + index as f64 * 0.0001; FEATURE_NAMES.len()],
            sector_rotation: None,
            missing_sector_symbols: SECTOR_ROTATION_SYMBOLS
                .iter()
                .map(|symbol| (*symbol).to_string())
                .collect(),
            regime,
            spy: DailyBar {
                open: 100.0 + index as f64,
                high: 101.0 + index as f64,
                low: 99.0 + index as f64,
                close: 100.5 + index as f64,
                volume: 1_000_000.0,
                minute_rows: 390,
                first_at: None,
                last_at: None,
            },
            coverage: BTreeMap::new(),
        }
    }

    fn covered_bar(open: f64, close: f64) -> DailyBar {
        DailyBar {
            open,
            high: open.max(close) + 1.0,
            low: open.min(close) - 1.0,
            close,
            volume: 1_000_000.0,
            minute_rows: MINIMUM_CONTEXT_ROWS,
            first_at: Some("2026-07-30T13:45:00Z".parse().unwrap()),
            last_at: Some("2026-07-30T19:45:00Z".parse().unwrap()),
        }
    }

    #[test]
    fn analog_retrieval_never_uses_query_or_future_label() {
        let rows = (0..40)
            .map(|index| feature_row(index, RegimeLabel::RiskOnTrend, 0.001))
            .collect::<Vec<_>>();
        let analogs = nearest_analogs(&rows, 39, 1);
        assert_eq!(analogs.len(), ANALOG_NEIGHBORS);
        assert!(analogs.iter().all(|analog| analog.index + 2 < 39));
    }

    #[test]
    fn sector_rotation_requires_complete_edge_covered_groups() {
        let mut day = BTreeMap::new();
        for (index, symbol) in SECTOR_ROTATION_SYMBOLS.iter().enumerate() {
            day.insert(
                (*symbol).to_string(),
                covered_bar(100.0, 100.0 + index as f64),
            );
        }
        let features = build_sector_rotation_features(&day, 0.01).expect("complete rotation");
        assert_eq!(features.values.len(), SECTOR_ROTATION_FEATURE_NAMES.len());
        assert_eq!(features.group_returns.len(), SECTOR_ROTATION_SYMBOLS.len());
        assert!((features.values[0] + 0.01).abs() < 1.0e-12);
        assert!(features.values[1].abs() < 1.0e-12);
        assert!((features.values[2] - 0.01).abs() < 1.0e-12);
        assert_eq!(features.values[3], 1.0);
        assert!(features.values[4] > 0.0);

        day.get_mut("SKYY").unwrap().last_at = Some("2026-07-30T19:29:00Z".parse().unwrap());
        assert!(build_sector_rotation_features(&day, 0.01).is_none());
        assert_eq!(missing_sector_symbols(&day), vec!["SKYY"]);
    }

    #[test]
    fn paired_sector_challenger_never_uses_query_or_future_label() {
        let mut rows = (0..120)
            .map(|index| feature_row(index, RegimeLabel::RiskOnTrend, 0.001))
            .collect::<Vec<_>>();
        for (index, row) in rows.iter_mut().enumerate() {
            row.sector_rotation = Some(SectorRotationFeatures {
                values: vec![index as f64 * 0.00001; SECTOR_ROTATION_FEATURE_NAMES.len()],
                group_returns: BTreeMap::new(),
            });
            row.missing_sector_symbols.clear();
        }
        let analogs = paired_sector_analogs(&rows, 119, 1, true);
        assert_eq!(analogs.len(), ANALOG_NEIGHBORS);
        assert!(analogs.iter().all(|analog| analog.index + 2 < 119));
    }

    #[test]
    fn missing_sector_history_keeps_challenger_out_of_publication() {
        let rows = (0..100)
            .map(|index| feature_row(index, RegimeLabel::RiskOnTrend, 0.001))
            .collect::<Vec<_>>();
        let challenger = sector_rotation_challenger(&rows, rows.last().unwrap());
        assert_eq!(
            challenger.status,
            "BLOCKED_POINT_IN_TIME_SECTOR_HISTORY_INCOMPLETE"
        );
        assert!(!challenger.applied_to_published_prediction);
        assert!(challenger.validation.is_none());
        assert_eq!(
            challenger.missing_current_symbols.len(),
            SECTOR_ROTATION_SYMBOLS.len()
        );
    }

    #[test]
    fn lean_requires_sign_and_frequency_agreement() {
        let analogs = (0..15)
            .map(|index| RankedAnalog {
                index,
                distance: index as f64,
                next_return: if index < 10 { 0.01 } else { -0.005 },
            })
            .collect::<Vec<_>>();
        let (lean, up_count, raw_up, median, _) = lean_from_analogs(&analogs);
        assert_eq!(lean, "UP");
        assert_eq!(up_count, 10);
        assert!(raw_up > 0.65);
        assert!(median > 0.0);
    }

    #[test]
    fn near_fifty_fifty_analogs_withhold_the_directional_call() {
        let analogs = (0..15)
            .map(|index| RankedAnalog {
                index,
                distance: index as f64,
                next_return: if index < 8 { 0.01 } else { -0.005 },
            })
            .collect::<Vec<_>>();
        let (lean, _, raw_up, _, _) = lean_from_analogs(&analogs);
        assert_eq!(lean, "MIXED");
        assert!(raw_up < DIRECTIONAL_AGREEMENT_THRESHOLD);
    }

    #[test]
    fn high_volatility_selloff_is_named_deterministically() {
        let mut features = vec![0.0; FEATURE_NAMES.len()];
        features[0] = -0.02;
        assert_eq!(
            classify_regime(&features, 0.90),
            RegimeLabel::HighVolSellOff
        );
    }

    #[test]
    fn taxonomy_has_eight_unique_states_and_low_volatility_breakout() {
        let unique = REGIME_TAXONOMY
            .iter()
            .map(|label| format!("{label:?}"))
            .collect::<BTreeSet<_>>();
        assert_eq!(REGIME_TAXONOMY.len(), 8);
        assert_eq!(unique.len(), 8);

        let mut features = vec![0.0; FEATURE_NAMES.len()];
        features[3] = 0.03;
        features[8] = 0.01;
        features[9] = 0.01;
        features[10] = 0.01;
        features[11] = 0.001;
        assert_eq!(
            classify_regime(&features, 0.10),
            RegimeLabel::LowVolBreakout
        );
    }

    #[test]
    fn conformal_quantile_uses_finite_sample_rank() {
        let residuals = (1..=99).map(|value| value as f64).collect::<Vec<_>>();
        assert_eq!(conformal_residual_quantile(&residuals, 0.90), Some(90.0));
        assert_eq!(conformal_residual_quantile(&[], 0.90), None);
    }

    #[test]
    fn wilson_interval_exposes_raw_likelihood_uncertainty() {
        let (lower, upper) =
            wilson_score_interval(7, 15, NORMAL_95_TWO_SIDED_Z).expect("valid interval");
        assert!((lower - 0.248_095_353_657_374).abs() < 1.0e-12);
        assert!((upper - 0.698_830_199_745_016).abs() < 1.0e-12);
        assert!(wilson_score_interval(0, 0, NORMAL_95_TWO_SIDED_Z).is_none());
        assert!(wilson_score_interval(16, 15, NORMAL_95_TWO_SIDED_Z).is_none());
    }

    #[test]
    fn sparse_context_coverage_requires_both_session_edges() {
        let mut bar = DailyBar {
            minute_rows: MINIMUM_CONTEXT_ROWS,
            first_at: Some("2026-07-30T13:45:00Z".parse().unwrap()),
            last_at: Some("2026-07-30T19:45:00Z".parse().unwrap()),
            ..DailyBar::default()
        };
        assert!(context_session_covered(&bar));

        bar.first_at = Some("2026-07-30T14:01:00Z".parse().unwrap());
        assert!(!context_session_covered(&bar));

        bar.first_at = Some("2026-07-30T13:45:00Z".parse().unwrap());
        bar.last_at = Some("2026-07-30T19:29:00Z".parse().unwrap());
        assert!(!context_session_covered(&bar));
    }
}
