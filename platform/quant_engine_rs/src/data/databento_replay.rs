//! Isolated deterministic replay of recorded Databento one-minute envelopes.
//!
//! Replay consumes envelopes that were already captured by the licensed live
//! adapter, advances the model using their original exchange ordering, and
//! writes only under `data/replay/databento`. It never opens a provider socket,
//! writes the live prediction ledger, or produces `live_shadow_prediction`
//! evidence.

use std::{
    collections::{BTreeMap, BTreeSet},
    fs,
    io::{BufRead, BufReader},
    path::{Path, PathBuf},
};

use anyhow::{Context, Result, bail};
use chrono::{
    DateTime, Datelike, Duration as ChronoDuration, NaiveDate, Timelike, Utc, Weekday,
};
use chrono_tz::America::New_York;
use databento::{
    LiveClient,
    dbn::{ErrorMsg, OhlcvMsg, PitSymbolMap, SType, Schema, SymbolMappingMsg, SystemCode, SystemMsg},
    live::Subscription,
};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use time::Duration as TimeDuration;

use crate::{
    AppConfig,
    config::OfflineFeatureTrainingContractConfig,
    data::{
        LicensedFileImporter, capability,
        csv_import::MarketBarCsvImporter,
        databento_live::{
            DATABENTO_LIVE_BAR_SCHEMA_VERSION, DatabentoCausalAbsenceEnvelope,
            DatabentoRealtimeBarEnvelope, normalize_bar, realtime_envelope_rejection,
            utc_from_nanos,
        },
    },
    domain::MarketBar,
    engine::features,
    frozen_universe::canonical_model_symbol,
    market_query::{
        DataFreshness, EVIDENCE_ENVELOPE_SCHEMA_VERSION, EvidenceEnvelope, EvidenceItem,
        EvidenceMode, MarketQuery, MarketQueryFilters, MarketQueryIntent, MarketSetupType,
        PipelineReadiness, PipelineReadinessStage, PipelineReadinessState, ResearchCandidate,
    },
    prediction_ledger::PredictionLedger,
    predictor::{self, DATABENTO_REPLAY_AVAILABILITY_SEMANTICS, RealtimeSourceMetadata},
};

pub const DATABENTO_REPLAY_RECEIPT_SCHEMA_VERSION: &str = "historical_replay_receipt.v4";
pub const DATABENTO_REPLAY_SOURCE: &str = "HISTORICAL_REPLAY:LOCAL_LICENSED_BARS";
pub const DATABENTO_PROVIDER_REPLAY_SOURCE: &str =
    "HISTORICAL_REPLAY:DATABENTO_LIVE_INTRADAY_REPLAY";
pub const DATABENTO_REPLAY_ENTITLEMENT: &str = "DETERMINISTIC_REPLAY_NOT_CURRENT_MARKET_DATA";
const DATABENTO_REPLAY_MODEL_RECIPE: &str = "STRICT_LOCAL_HISTORICAL_REPLAY_V4";
const STRICT_REPLAY_REQUIRED_COVERAGE: f64 = 1.0;
const REQUIRED_HORIZONS: [usize; 4] = [5, 15, 30, 60];
const PROVIDER_REPLAY_TIMEOUT_SECONDS: u64 = 45;
const PROVIDER_REPLAY_VIRTUAL_LAG_MS: i64 = 50;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DatabentoProviderReplayCapture {
    pub schema_version: String,
    pub transport: String,
    pub dataset: String,
    pub provider_session_started_at: DateTime<Utc>,
    pub provider_session_completed_at: DateTime<Utc>,
    pub replay_session: NaiveDate,
    pub requested_start: DateTime<Utc>,
    pub required_through: DateTime<Utc>,
    pub subscribed_symbols: Vec<String>,
    pub required_forecast_symbols: Vec<String>,
    pub subscription_acknowledged: bool,
    pub symbol_mappings: usize,
    pub provider_records_received: usize,
    pub normalized_envelopes: Vec<DatabentoRealtimeBarEnvelope>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RealizedReplayOutcome {
    pub horizon_minutes: usize,
    pub label_start: DateTime<Utc>,
    pub label_end: DateTime<Utc>,
    pub entry_open: f64,
    pub exit_close: f64,
    pub realized_return: f64,
    pub maximum_favorable_excursion: f64,
    pub maximum_adverse_excursion: f64,
    pub predicted_orientation: String,
    pub realized_orientation: String,
    pub direction_correct: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DatabentoReplayReceipt {
    pub schema_version: String,
    pub replay_id: String,
    pub generated_at: DateTime<Utc>,
    pub replay_session: NaiveDate,
    pub observation_cutoff: DateTime<Utc>,
    pub public_symbol: String,
    pub model_symbol: String,
    pub input_path: PathBuf,
    pub input_sha256: String,
    pub source_envelopes_sha256: String,
    pub accepted_input_envelopes: usize,
    pub replayed_source_envelopes: usize,
    pub replayed_context_observations: usize,
    pub rejected_input_envelopes: usize,
    pub replayed_symbols: Vec<String>,
    pub source_mode: String,
    #[serde(default)]
    pub provider_transport: Option<String>,
    #[serde(default)]
    pub provider_session_started_at: Option<DateTime<Utc>>,
    #[serde(default)]
    pub provider_session_completed_at: Option<DateTime<Utc>>,
    #[serde(default)]
    pub provider_subscription_acknowledged: bool,
    #[serde(default)]
    pub provider_symbol_mappings: usize,
    #[serde(default)]
    pub provider_records_received: usize,
    pub synthetic_context_intervals: usize,
    pub context_observation_policy_schema_version: String,
    pub artifact_feature_identity_matches_replay: bool,
    pub historical_training_sessions: usize,
    pub replay_local_model_trained: bool,
    pub production_artifact_used: bool,
    pub historical_regime_initialized: bool,
    pub realized_outcomes: Vec<RealizedReplayOutcome>,
    pub rust_inference: bool,
    pub current_market_data: bool,
    pub live_state_written: bool,
    pub execution_enabled: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DatabentoReplayRun {
    pub status: String,
    pub receipt: DatabentoReplayReceipt,
    pub model_path: PathBuf,
    pub forecast_path: PathBuf,
    pub evidence_path: PathBuf,
    pub ledger_path: PathBuf,
    pub predictions_generated: usize,
}

fn sha256_bytes(bytes: &[u8]) -> String {
    format!("{:x}", Sha256::digest(bytes))
}

fn write_json_atomic(path: &Path, value: &impl Serialize) -> Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    let staged = path.with_extension("json.replay-staged");
    fs::write(&staged, serde_json::to_vec_pretty(value)?)
        .with_context(|| format!("write staged replay artifact {}", staged.display()))?;
    #[cfg(windows)]
    if path.exists() {
        fs::remove_file(path)
            .with_context(|| format!("replace replay artifact {}", path.display()))?;
    }
    fs::rename(&staged, path)
        .with_context(|| format!("promote replay artifact {}", path.display()))?;
    Ok(())
}

fn is_regular_session(timestamp: DateTime<Utc>) -> bool {
    let local = timestamp.with_timezone(&New_York);
    let minute = local.hour() * 60 + local.minute();
    (9 * 60 + 30..16 * 60).contains(&minute)
}

fn exact_replay_query(public_symbol: &str) -> MarketQuery {
    MarketQuery {
        version: crate::market_query::MARKET_QUERY_SCHEMA_VERSION.to_string(),
        intent: MarketQueryIntent::Forecast,
        setup_type: MarketSetupType::ModelForecast,
        symbols: vec![public_symbol.to_ascii_uppercase()],
        horizon_minutes: None,
        limit: 1,
        as_of: None,
        filters: MarketQueryFilters::default(),
    }
}

pub fn supports_query(query: &MarketQuery) -> bool {
    query.version == crate::market_query::MARKET_QUERY_SCHEMA_VERSION
        && query.intent == MarketQueryIntent::Forecast
        && query.setup_type == MarketSetupType::ModelForecast
        && query.horizon_minutes.is_none()
        && query.symbols == ["SPX"]
        && query.filters.direction.is_none()
        && query.filters.require_realtime
        && !query.filters.include_historical
}

fn read_verified_envelopes(
    input: &Path,
    maximum_lag_ms: i64,
) -> Result<(Vec<DatabentoRealtimeBarEnvelope>, usize, String)> {
    let input_bytes = fs::read(input)
        .with_context(|| format!("read Databento replay input {}", input.display()))?;
    let input_sha256 = sha256_bytes(&input_bytes);
    let reader = BufReader::new(input_bytes.as_slice());
    let mut accepted = BTreeMap::<(DateTime<Utc>, String), DatabentoRealtimeBarEnvelope>::new();
    let mut rejected = 0_usize;
    for (index, line) in reader.lines().enumerate() {
        let line = line.with_context(|| format!("read Databento replay line {}", index + 1))?;
        if line.trim().is_empty() {
            continue;
        }
        let envelope: DatabentoRealtimeBarEnvelope = match serde_json::from_str(&line) {
            Ok(envelope) => envelope,
            Err(_) => {
                rejected += 1;
                continue;
            }
        };
        if realtime_envelope_rejection(&envelope, maximum_lag_ms).is_some() {
            rejected += 1;
            continue;
        }
        let key = (envelope.bar_start, envelope.bar.symbol.to_ascii_uppercase());
        match accepted.get(&key) {
            Some(existing) if existing.bar != envelope.bar => {
                bail!(
                    "DATABENTO_REPLAY_CONFLICTING_DUPLICATE symbol={} cutoff={}",
                    envelope.bar.symbol,
                    envelope.bar_start
                );
            }
            Some(existing) if existing.provider_available_at <= envelope.provider_available_at => {
                // Retain the earliest causal receipt for an exact duplicate.
            }
            _ => {
                accepted.insert(key, envelope);
            }
        }
    }
    Ok((accepted.into_values().collect(), rejected, input_sha256))
}

fn read_verified_context_observations(
    input: &Path,
    replay_session: NaiveDate,
) -> Result<(Vec<DatabentoCausalAbsenceEnvelope>, usize)> {
    let file = match fs::File::open(input) {
        Ok(file) => file,
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => {
            return Ok((Vec::new(), 0));
        }
        Err(error) => {
            return Err(error).with_context(|| {
                format!("read Databento context replay input {}", input.display())
            });
        }
    };
    let mut accepted = BTreeMap::<(DateTime<Utc>, String), DatabentoCausalAbsenceEnvelope>::new();
    let mut rejected = 0_usize;
    for (index, line) in BufReader::new(file).lines().enumerate() {
        let line =
            line.with_context(|| format!("read Databento context replay line {}", index + 1))?;
        if line.trim().is_empty() {
            continue;
        }
        let envelope: DatabentoCausalAbsenceEnvelope = match serde_json::from_str(&line) {
            Ok(envelope) => envelope,
            Err(_) => {
                rejected += 1;
                continue;
            }
        };
        if !envelope.validate()
            || envelope
                .interval_start
                .with_timezone(&New_York)
                .date_naive()
                != replay_session
            || !is_regular_session(envelope.interval_start)
        {
            rejected += 1;
            continue;
        }
        let key = (
            envelope.interval_start,
            envelope.observation.symbol.to_ascii_uppercase(),
        );
        match accepted.get(&key) {
            Some(existing) if existing.observation != envelope.observation => {
                bail!(
                    "DATABENTO_REPLAY_CONFLICTING_CONTEXT_DUPLICATE symbol={} cutoff={}",
                    envelope.observation.symbol,
                    envelope.interval_start
                );
            }
            Some(existing) if existing.received_at <= envelope.received_at => {
                // Retain the earliest causal receipt for an exact duplicate.
            }
            _ => {
                accepted.insert(key, envelope);
            }
        }
    }
    Ok((accepted.into_values().collect(), rejected))
}

fn ready_stage(code: &str, detail: &str, observed_at: DateTime<Utc>) -> PipelineReadinessStage {
    PipelineReadinessStage {
        state: PipelineReadinessState::Ready,
        code: Some(code.to_string()),
        detail: Some(detail.to_string()),
        observed_at: Some(observed_at),
    }
}

fn replay_candidate(
    public_symbol: &str,
    contract: &crate::predictor::ForecastContract,
    receipt: &DatabentoReplayReceipt,
    forecast_sha256: &str,
) -> ResearchCandidate {
    let orientation = match contract.suggested_direction {
        value if value > 0 => "up",
        value if value < 0 => "down",
        _ => "flat",
    };
    let realized = receipt
        .realized_outcomes
        .iter()
        .find(|outcome| outcome.horizon_minutes == contract.horizon_minutes);
    let data_age_seconds = receipt
        .generated_at
        .signed_duration_since(contract.latest_input_available_at)
        .num_seconds();
    ResearchCandidate {
        symbol: public_symbol.to_string(),
        setup_type: MarketSetupType::ModelForecast,
        status: "UNCALIBRATED_RESEARCH_OUTPUT".to_string(),
        heuristic_structure_score: None,
        score_semantics:
            "Frozen Rust model condition from a held-out, real-data-only historical replay; probability and rank remain uncalibrated."
                .to_string(),
        supporting_evidence: vec![
            EvidenceItem {
                code: "REAL_HISTORICAL_BARS_REPLAYED".to_string(),
                statement:
                    "Licensed, observed one-minute historical bars were replayed in exchange-time order without synthetic fills or proxy rows."
                        .to_string(),
                observed_value: Some(json!(receipt.replayed_source_envelopes)),
            },
            EvidenceItem {
                code: "HISTORICAL_REGIME_STATE_INITIALIZED".to_string(),
                statement:
                    "The frozen Rust feature and regime state was initialized from the installed historical market-bar dataset before replay bars were ingested."
                        .to_string(),
                observed_value: Some(json!(receipt.historical_regime_initialized)),
            },
            EvidenceItem {
                code: "RUST_FROZEN_MODEL_REPLAY_INFERENCE".to_string(),
                statement:
                    "The replay used an isolated frozen Rust artifact trained only on sessions before the held-out replay date."
                        .to_string(),
                observed_value: Some(json!(contract.horizon_minutes)),
            },
            EvidenceItem {
                code: "HELD_OUT_FORWARD_OUTCOME_SETTLED".to_string(),
                statement:
                    "The prediction was compared with the subsequently realized point-in-time path from the held-out session."
                        .to_string(),
                observed_value: realized.map(|outcome| {
                    json!({
                        "realized_return":outcome.realized_return,
                        "direction_correct":outcome.direction_correct
                    })
                }),
            },
        ],
        contrary_evidence: vec![
            EvidenceItem {
                code: "REPLAY_NOT_CURRENT_MARKET_DATA".to_string(),
                statement:
                    "The provider observations are recorded history replayed with a virtual clock; they are not current market data."
                        .to_string(),
                observed_value: Some(json!(receipt.observation_cutoff)),
            },
            EvidenceItem {
                code: "PROBABILITY_AND_EXPECTED_MOVE_WITHHELD".to_string(),
                statement:
                    "No matching promoted out-of-sample calibration exists; probability, expected move, rank, and execution remain withheld."
                        .to_string(),
                observed_value: Some(json!(
                    "WITHHELD_NO_MATCHING_PROMOTED_OOS_CALIBRATION"
                )),
            },
        ],
        metrics: json!({
            "horizon_minutes":contract.horizon_minutes,
            "statistical_orientation":orientation,
            "expected_return":contract.expected_return,
            "median_return":contract.median_return,
            "return_quantiles":contract.return_quantiles,
            "raw_analog_up_frequency":contract.raw_analog_up_frequency,
            "raw_analog_down_frequency":contract.raw_analog_down_frequency,
            "raw_analog_flat_frequency":contract.raw_analog_flat_frequency,
            "analog_effective_sample_size":contract.analog_effective_sample_size,
            "analog_similarity_score":contract.analog_similarity_score,
            "dominant_regime_state":contract.dominant_regime_state,
            "dominant_regime_probability":contract.dominant_regime_probability,
            "top_analogs":contract.top_analogs.iter().take(4).collect::<Vec<_>>(),
            "realized_outcome":realized,
            "observation_cutoff":contract.observation_cutoff,
            "latest_input_available_at":contract.latest_input_available_at,
            "data_age_seconds":data_age_seconds,
            "data_source":DATABENTO_REPLAY_SOURCE,
            "coverage":STRICT_REPLAY_REQUIRED_COVERAGE,
            "coverage_semantics":"TWO_OF_TWO_EXPERIMENTAL_CROSS_ASSET_MEMBERS_OBSERVED; QQQ_AND_IWM_ONLY; NOT_THE_PRODUCTION_SIX_MEMBER_CONTEXT",
            "caveats":[
                "This is a deterministic historical replay, not current market data.",
                "The replay uses only real installed bars, but its QQQ/IWM context is experimental and not the production six-member live contract.",
                "Raw analog frequencies and return estimates are uncalibrated research statistics, not probabilities.",
                "Automatic execution is disabled."
            ],
            "published_probability_status":"WITHHELD_NO_MATCHING_PROMOTED_OOS_CALIBRATION",
            "validation":{
                "model_version":contract.model_id,
                "feature_version":contract.feature_version,
                "model_hash":contract.model_hash,
                "feature_hash":contract.feature_hash,
                "data_manifest_hash":contract.data_manifest_hash,
                "schema_version":DATABENTO_REPLAY_RECEIPT_SCHEMA_VERSION,
                "source_envelopes_sha256":receipt.source_envelopes_sha256,
                "forecast_sha256":forecast_sha256,
                "replay_id":receipt.replay_id,
                "replay_session":receipt.replay_session
            },
            "interpretation":"HELD_OUT_REAL_DATA_HISTORICAL_MODEL_REPLAY_NOT_A_TRADE"
        }),
        freshness: vec![DataFreshness {
            source: DATABENTO_REPLAY_SOURCE.to_string(),
            observed_at: Some(contract.observation_cutoff),
            available_at: Some(contract.latest_input_available_at),
            age_seconds: Some(data_age_seconds),
            realtime: false,
            entitlement: DATABENTO_REPLAY_ENTITLEMENT.to_string(),
            coverage: Some(STRICT_REPLAY_REQUIRED_COVERAGE),
        }],
    }
}

fn strict_replay_symbol(symbol: &str, target: &str) -> bool {
    symbol.eq_ignore_ascii_case(target)
        || STRICT_REPLAY_CONTEXT_SYMBOLS
            .iter()
            .any(|required| symbol.eq_ignore_ascii_case(required))
}

fn strict_replay_states(
    records: &[MarketBar],
    target: &str,
    research: &crate::config::ResearchConfig,
) -> Result<Vec<crate::domain::MarketState>> {
    let mut by_symbol_session = BTreeMap::<(String, NaiveDate), Vec<&MarketBar>>::new();
    for bar in records {
        if STRICT_REPLAY_CONTEXT_SYMBOLS
            .iter()
            .any(|symbol| bar.symbol.eq_ignore_ascii_case(symbol))
        {
            by_symbol_session
                .entry((
                    bar.symbol.to_ascii_uppercase(),
                    bar.timestamp.with_timezone(&New_York).date_naive(),
                ))
                .or_default()
                .push(bar);
        }
    }
    let mut context_ret5 = BTreeMap::<(String, DateTime<Utc>), f64>::new();
    for ((symbol, _), mut rows) in by_symbol_session {
        rows.sort_by_key(|bar| bar.timestamp);
        for index in 5..rows.len() {
            let window = &rows[index - 5..=index];
            if window
                .windows(2)
                .all(|pair| pair[1].timestamp == pair[0].timestamp + ChronoDuration::minutes(1))
            {
                context_ret5.insert(
                    (symbol.clone(), rows[index].timestamp),
                    rows[index].close / rows[index - 5].close - 1.0,
                );
            }
        }
    }
    let states = features::build_states(records, target, research)?
        .into_iter()
        .filter_map(|mut state| {
            let values = STRICT_REPLAY_CONTEXT_SYMBOLS
                .iter()
                .map(|symbol| {
                    context_ret5
                        .get(&((*symbol).to_string(), state.timestamp))
                        .copied()
                })
                .collect::<Option<Vec<_>>>()?;
            state.cross_asset_breadth_score = values
                .iter()
                .map(|value| {
                    if *value > 0.0 {
                        1.0
                    } else if *value < 0.0 {
                        -1.0
                    } else {
                        0.0
                    }
                })
                .sum::<f64>()
                / values.len() as f64;
            state.risk_rotation_score = values.iter().sum::<f64>() / values.len() as f64;
            state.market_confirmation_score = if state.ret_5m == 0.0 {
                0.0
            } else {
                state.cross_asset_breadth_score * state.ret_5m.signum()
            };
            state.cross_asset_context_complete = true;
            state.cross_asset_context_coverage = STRICT_REPLAY_REQUIRED_COVERAGE;
            Some(state)
        })
        .collect();
    Ok(states)
}

fn realized_replay_outcomes(
    contracts: &[crate::predictor::ForecastContract],
    target_rows: &[MarketBar],
) -> Result<Vec<RealizedReplayOutcome>> {
    let mut outcomes = Vec::with_capacity(contracts.len());
    for contract in contracts {
        let window = target_rows
            .iter()
            .filter(|bar| {
                bar.timestamp >= contract.label_start && bar.timestamp < contract.label_end
            })
            .collect::<Vec<_>>();
        if window.len() != contract.horizon_minutes
            || window
                .windows(2)
                .any(|pair| pair[1].timestamp != pair[0].timestamp + ChronoDuration::minutes(1))
            || window.first().map(|bar| bar.timestamp) != Some(contract.label_start)
            || window
                .last()
                .map(|bar| bar.timestamp + ChronoDuration::minutes(1))
                != Some(contract.label_end)
        {
            bail!(
                "STRICT_HISTORICAL_REPLAY_REALIZED_PATH_INCOMPLETE horizon={}",
                contract.horizon_minutes
            );
        }
        let entry_open = window[0].open;
        let exit_close = window
            .last()
            .context("strict replay realized path has no exit")?
            .close;
        let realized_return = exit_close / entry_open - 1.0;
        let maximum_favorable_excursion = window
            .iter()
            .map(|bar| bar.high / entry_open - 1.0)
            .fold(f64::NEG_INFINITY, f64::max);
        let maximum_adverse_excursion = window
            .iter()
            .map(|bar| bar.low / entry_open - 1.0)
            .fold(f64::INFINITY, f64::min);
        let predicted_orientation = match contract.suggested_direction {
            value if value > 0 => "up",
            value if value < 0 => "down",
            _ => "flat",
        }
        .to_string();
        let realized_orientation = if realized_return > 0.0 {
            "up"
        } else if realized_return < 0.0 {
            "down"
        } else {
            "flat"
        }
        .to_string();
        outcomes.push(RealizedReplayOutcome {
            horizon_minutes: contract.horizon_minutes,
            label_start: contract.label_start,
            label_end: contract.label_end,
            entry_open,
            exit_close,
            realized_return,
            maximum_favorable_excursion,
            maximum_adverse_excursion,
            direction_correct: predicted_orientation == realized_orientation,
            predicted_orientation,
            realized_orientation,
        });
    }
    outcomes.sort_by_key(|outcome| outcome.horizon_minutes);
    Ok(outcomes)
}

pub fn run(
    config: &AppConfig,
    root: &Path,
    _input: &Path,
    output_root: &Path,
    public_symbol: &str,
) -> Result<DatabentoReplayRun> {
    if config.execution.enabled
        || config.execution.allow_real_orders
        || config.live.allow_trade_api
        || !config.live.quote_only
        || !config.live.shadow_only
    {
        bail!("STRICT_HISTORICAL_REPLAY_REFUSES_ANY_EXECUTION_PATH");
    }
    let public_symbol = public_symbol.to_ascii_uppercase();
    if public_symbol != "SPX" {
        bail!("STRICT_HISTORICAL_REPLAY_CURRENTLY_SUPPORTS_ONLY_SPX");
    }
    let target = config
        .research
        .targets
        .iter()
        .find(|target| target.public_symbol.eq_ignore_ascii_case(&public_symbol))
        .context("STRICT_HISTORICAL_REPLAY_TARGET_MAPPING_MISSING")?;
    let model_symbol = canonical_model_symbol(&target.model_symbol)?;
    let historical_path = root.join("normalized/market_bars.csv");
    let imported = MarketBarCsvImporter
        .import(&historical_path)
        .with_context(|| {
            format!(
                "STRICT_HISTORICAL_REPLAY_BARS_UNAVAILABLE:{}",
                historical_path.display()
            )
        })?
        .records;
    let capability = capability::inspect(&config.data)?;
    let input_sha256 = capability
        .normalized_file_sha256
        .clone()
        .context("STRICT_HISTORICAL_REPLAY_INPUT_SHA256_MISSING")?;
    let real_records = imported
        .into_iter()
        .filter(|bar| {
            strict_replay_symbol(&bar.symbol, &model_symbol)
                && is_regular_session(bar.timestamp)
                && bar.is_observed_trade_bar()
                && !bar.data_quality.to_ascii_lowercase().contains("synthetic")
        })
        .collect::<Vec<_>>();
    let session_dates = real_records
        .iter()
        .filter(|bar| bar.symbol.eq_ignore_ascii_case(&model_symbol))
        .map(|bar| bar.timestamp.with_timezone(&New_York).date_naive())
        .collect::<BTreeSet<_>>();
    let mut research = config.research.clone();
    research.target = model_symbol.clone();
    let replay_session = session_dates
        .iter()
        .rev()
        .copied()
        .find(|session| {
            let rows = real_records
                .iter()
                .filter(|bar| bar.timestamp.with_timezone(&New_York).date_naive() == *session)
                .cloned()
                .collect::<Vec<_>>();
            strict_replay_states(&rows, &model_symbol, &research)
                .is_ok_and(|states| states.iter().any(|state| state.minutes_to_close >= 61))
        })
        .context("STRICT_HISTORICAL_REPLAY_NO_COMPLETE_HELD_OUT_SESSION")?;
    let training_dates = session_dates
        .iter()
        .copied()
        .filter(|session| *session < replay_session)
        .rev()
        .take(60)
        .collect::<BTreeSet<_>>();
    if training_dates.len() < 60 {
        bail!(
            "STRICT_HISTORICAL_REPLAY_REQUIRES_60_PRIOR_SESSIONS actual={}",
            training_dates.len()
        );
    }
    let training_records = real_records
        .iter()
        .filter(|bar| training_dates.contains(&bar.timestamp.with_timezone(&New_York).date_naive()))
        .cloned()
        .collect::<Vec<_>>();
    let session_records = real_records
        .iter()
        .filter(|bar| bar.timestamp.with_timezone(&New_York).date_naive() == replay_session)
        .cloned()
        .collect::<Vec<_>>();
    let target_rows = session_records
        .iter()
        .filter(|bar| bar.symbol.eq_ignore_ascii_case(&model_symbol))
        .cloned()
        .collect::<Vec<_>>();
    let training_dataset_hash = sha256_bytes(&serde_json::to_vec(&training_records)?);
    let mut replay_capability = capability.clone();
    replay_capability.generated_at = training_records
        .last()
        .map(|bar| bar.timestamp + ChronoDuration::minutes(1))
        .unwrap_or(DateTime::<Utc>::UNIX_EPOCH);
    replay_capability.symbols = std::iter::once(model_symbol.clone())
        .chain(
            STRICT_REPLAY_CONTEXT_SYMBOLS
                .iter()
                .map(|symbol| (*symbol).to_string()),
        )
        .collect();
    replay_capability.coverage_start = training_records.first().map(|bar| bar.timestamp);
    replay_capability.coverage_end = training_records.last().map(|bar| bar.timestamp);
    replay_capability.row_count = training_records.len() as u64;
    replay_capability.normalized_file_sha256 = Some(training_dataset_hash.clone());
    replay_capability.manifest_hashes = vec![training_dataset_hash.clone()];
    replay_capability.source = "LOCAL_LICENSED_HISTORICAL_REPLAY_PREFIX".to_string();
    replay_capability.evidence_grade = "HELD_OUT_HISTORICAL_REPLAY".to_string();

    let model_path = output_root.join("model_spx_strict_historical.json");
    fs::create_dir_all(output_root)?;
    let cached_artifact = fs::read(&model_path)
        .ok()
        .and_then(|bytes| serde_json::from_slice::<predictor::FrozenPredictorArtifact>(&bytes).ok())
        .filter(|artifact| {
            artifact.validate_static().is_ok()
                && artifact.target.eq_ignore_ascii_case(&model_symbol)
                && artifact.code_commit_hash == DATABENTO_REPLAY_MODEL_RECIPE
                && artifact.training_dataset_hash == training_dataset_hash
        });
    let artifact = match cached_artifact {
        Some(artifact) => artifact,
        None => {
            let training_states =
                strict_replay_states(&training_records, &model_symbol, &research)?;
            let created_at = training_states
                .last()
                .map(|state| state.timestamp + ChronoDuration::minutes(1))
                .context("STRICT_HISTORICAL_REPLAY_TRAINING_STATE_SET_EMPTY")?;
            let artifact = predictor::train_frozen_artifact(
                &training_states,
                &research,
                &replay_capability,
                created_at,
                DATABENTO_REPLAY_MODEL_RECIPE,
            )?;
            write_json_atomic(&model_path, &artifact)?;
            artifact
        }
    };

    let held_out_states = strict_replay_states(&session_records, &model_symbol, &research)?;
    let selected = held_out_states
        .iter()
        .rfind(|state| state.session_date == replay_session && state.minutes_to_close >= 61)
        .context("STRICT_HISTORICAL_REPLAY_NO_LEGAL_FOUR_HORIZON_CUTOFF")?;
    let selected_state_timestamp = selected.timestamp;
    let mut causal_records = training_records.clone();
    causal_records.extend(
        session_records
            .iter()
            .filter(|bar| bar.timestamp <= selected_state_timestamp)
            .cloned(),
    );
    causal_records.sort_by_key(|bar| bar.timestamp);
    let states = strict_replay_states(&causal_records, &model_symbol, &research)?;
    if states.last().map(|state| state.timestamp) != Some(selected_state_timestamp) {
        bail!("STRICT_HISTORICAL_REPLAY_CAUSAL_STATE_RECONSTRUCTION_MISMATCH");
    }
    let virtual_available_at =
        selected_state_timestamp + ChronoDuration::minutes(1) + ChronoDuration::milliseconds(50);
    let mut bundle = predictor::forecast_with_frozen_artifact(
        &states,
        &research,
        &config.os,
        &replay_capability,
        virtual_available_at,
        &artifact,
    )?;
    predictor::enforce_realtime_forward_shadow(
        &mut bundle,
        virtual_available_at,
        config.live.execution_latency_ms,
        true,
        &RealtimeSourceMetadata {
            source_version: "LOCAL_LICENSED_HISTORICAL_1M_STRICT_REPLAY_V1",
            provider: "LOCAL_HISTORICAL_REPLAY",
            market_coverage: "SPY_QQQ_IWM_HYG_TLT_OBSERVED_BARS_ONLY",
            availability_semantics: "HISTORICAL_EXCHANGE_TIMESTAMPS_WITH_VIRTUAL_ONE_MINUTE_AVAILABILITY_NO_LIVE_RECEIPT_CLOCK",
        },
    );
    let horizons = bundle
        .prediction_layer
        .iter()
        .map(|contract| contract.horizon_minutes)
        .collect::<BTreeSet<_>>();
    write_json_atomic(&output_root.join("forecast_spx_diagnostic.json"), &bundle)?;
    if bundle.prediction_layer.len() != REQUIRED_HORIZONS.len()
        || horizons != BTreeSet::from(REQUIRED_HORIZONS)
    {
        bail!(
            "STRICT_HISTORICAL_REPLAY_EXACT_FOUR_HORIZONS_REQUIRED actual_count={} actual_horizons={horizons:?} unavailable={}",
            bundle.prediction_layer.len(),
            serde_json::to_string(&bundle.unavailable_horizons)?
        );
    }
    let realized_outcomes = realized_replay_outcomes(&bundle.prediction_layer, &target_rows)?;
    let replayed_bars = session_records
        .iter()
        .filter(|bar| bar.timestamp <= selected_state_timestamp)
        .cloned()
        .collect::<Vec<_>>();
    let source_envelopes_sha256 = sha256_bytes(&serde_json::to_vec(&replayed_bars)?);
    let replay_id = format!(
        "strict-historical-replay-{}-{}",
        replay_session.format("%Y%m%d"),
        &source_envelopes_sha256[..16]
    );
    let ledger_path = output_root.join("prediction_ledger.sqlite3");
    let ledger = PredictionLedger::open(&ledger_path)?;
    for contract in &mut bundle.prediction_layer {
        *contract = ledger.append_prediction(contract)?;
    }
    let forecast_bytes = serde_json::to_vec(&bundle)?;
    let forecast_sha256 = sha256_bytes(&forecast_bytes);
    let forecast_path = output_root.join("forecast_spx_latest.json");
    write_json_atomic(&forecast_path, &bundle)?;
    let observation_cutoff = bundle
        .prediction_layer
        .first()
        .map(|contract| contract.observation_cutoff)
        .context("STRICT_HISTORICAL_REPLAY_FORECAST_EMPTY")?;
    let generated_at = bundle
        .prediction_layer
        .iter()
        .map(|contract| contract.latest_input_available_at)
        .max()
        .unwrap_or(observation_cutoff);
    let receipt = DatabentoReplayReceipt {
        schema_version: DATABENTO_REPLAY_RECEIPT_SCHEMA_VERSION.to_string(),
        replay_id: replay_id.clone(),
        generated_at,
        replay_session,
        observation_cutoff,
        public_symbol: public_symbol.clone(),
        model_symbol: model_symbol.clone(),
        input_path: historical_path,
        input_sha256,
        source_envelopes_sha256,
        accepted_input_envelopes: session_records.len(),
        replayed_source_envelopes: replayed_bars.len(),
        replayed_context_observations: 0,
        rejected_input_envelopes: 0,
        replayed_symbols: std::iter::once(model_symbol.clone())
            .chain(
                STRICT_REPLAY_CONTEXT_SYMBOLS
                    .iter()
                    .map(|symbol| (*symbol).to_string()),
            )
            .collect(),
        source_mode: "STRICT_INSTALLED_HISTORICAL_REPLAY".to_string(),
        synthetic_context_intervals: 0,
        context_observation_policy_schema_version:
            "STRICT_REAL_OBSERVED_BARS_ONLY_QQQ_IWM_CONTEXT_V2".to_string(),
        artifact_feature_identity_matches_replay: true,
        historical_training_sessions: training_dates.len(),
        replay_local_model_trained: true,
        production_artifact_used: false,
        historical_regime_initialized: true,
        realized_outcomes,
        rust_inference: true,
        current_market_data: false,
        live_state_written: false,
        execution_enabled: false,
    };
    write_json_atomic(&output_root.join("receipt_spx_latest.json"), &receipt)?;
    let query = exact_replay_query(&public_symbol);
    let candidates = bundle
        .prediction_layer
        .iter()
        .map(|contract| replay_candidate(&public_symbol, contract, &receipt, &forecast_sha256))
        .collect::<Vec<_>>();
    let model_contract = json!({
        "runtime_owner":"RUST",
        "replay_runtime_owner":"quant_engine_rs::data::databento_replay",
        "replay_id":receipt.replay_id,
        "replay_receipt_schema":receipt.schema_version,
        "replay_session":receipt.replay_session,
        "replay_source_mode":receipt.source_mode,
        "synthetic_context_intervals":0,
        "replay_source_envelope_count":receipt.replayed_source_envelopes,
        "replay_trade_bar_envelope_count":receipt.replayed_source_envelopes,
        "replay_context_observation_count":0,
        "replay_context_observation_policy":receipt.context_observation_policy_schema_version,
        "artifact_feature_identity_matches_replay":true,
        "historical_training_sessions":receipt.historical_training_sessions,
        "replay_cross_asset_feature_schema":"EXPERIMENTAL_QQQ_IWM_OBSERVED_RET5_CONTEXT_V2",
        "replay_excluded_context_symbols":["HYG","TLT","UUP","VXX"],
        "replay_local_model_trained":true,
        "production_artifact_used":false,
        "input_sha256":receipt.input_sha256,
        "training_dataset_sha256":training_dataset_hash,
        "source_envelopes_sha256":receipt.source_envelopes_sha256,
        "forecast_horizons_minutes":[5,15,30,60],
        "realized_outcomes":receipt.realized_outcomes,
        "model_version":bundle.prediction_layer.first().map(|row| row.model_id.clone()),
        "feature_schema_version":bundle.prediction_layer.first().map(|row| row.feature_version.clone()),
        "candidate_status":"HELD_OUT_REAL_DATA_HISTORICAL_REPLAY",
        "universe_registry_status":"REPLAY_LOCAL_UNPROMOTED_ARTIFACT",
        "current_market_data":false,
        "live_state_written":false,
        "rust_inference":true
    });
    let query_sha256 = query.canonical_sha256()?;
    let mut evidence = EvidenceEnvelope {
        schema_version: EVIDENCE_ENVELOPE_SCHEMA_VERSION.to_string(),
        evidence_mode: EvidenceMode::DeterministicHistoricalReplay,
        request_id: replay_id,
        query_sha256,
        response_sha256: None,
        generated_at,
        observation_cutoff,
        status: "UNCALIBRATED_RESEARCH_OUTPUT".to_string(),
        query,
        candidates,
        exclusions: Vec::new(),
        historical: Vec::new(),
        data_blockers: Vec::new(),
        readiness: PipelineReadiness {
            model: ready_stage(
                "STRICT_REPLAY_LOCAL_FROZEN_MODEL_TRAINED",
                "The isolated Rust model was trained only on the 60 sessions before the held-out replay session.",
                generated_at,
            ),
            feed: ready_stage(
                "STRICT_REAL_HISTORICAL_BARS_READY",
                "Only licensed observed historical bars were replayed; no synthetic row, proxy series, or forward fill was admitted.",
                generated_at,
            ),
            context: ready_stage(
                "STRICT_REDUCED_CONTEXT_COMPLETE",
                "QQQ and IWM were point-in-time complete under the experimental historical context; HYG, TLT, UUP, and VXX are explicitly excluded because the local archive lacks sufficient overlapping history.",
                generated_at,
            ),
            inference: ready_stage(
                "RUST_REPLAY_ALL_HORIZONS_INFERRED_AND_SETTLED",
                "Rust produced all configured horizons and computed their subsequently realized held-out paths.",
                generated_at,
            ),
            publication: ready_stage(
                "ISOLATED_REPLAY_ARTIFACT_COMMITTED",
                "Replay artifacts were committed only under data/replay/databento; execution and live state remained disabled.",
                generated_at,
            ),
        },
        model_contract,
        research_only_policy: json!({
            "product_scope":"STRICT_HELD_OUT_HISTORICAL_RESEARCH_REPLAY",
            "personalization_used":false,
            "user_portfolio_inputs_used":false,
            "investment_advice":false,
            "execution_instruction":false,
            "automatic_order_execution":false
        }),
        caveats: vec![
            "STRICT_REAL_DATA_REPLAY: every replay input is an observed licensed historical bar; no synthetic or proxy market row was used.".to_string(),
            "The artifact was trained only on sessions before the held-out replay date and was reconstructed under the same feature code at inference.".to_string(),
            "The experimental replay context uses QQQ and IWM only; HYG, TLT, UUP, and VXX are absent, so this result does not validate or replace the six-member production live model.".to_string(),
            "Realized outcomes describe one held-out session and are diagnostic, not sufficient out-of-sample validation or calibration.".to_string(),
            "Raw analog frequencies, expected returns, and ranges are uncalibrated research statistics; execution remains disabled.".to_string(),
        ],
    };
    evidence.seal()?;
    let evidence_path = output_root.join("evidence_spx_latest.json");
    write_json_atomic(&evidence_path, &evidence)?;
    Ok(DatabentoReplayRun {
        status: "STRICT_HISTORICAL_REPLAY_COMPLETE".to_string(),
        predictions_generated: bundle.prediction_layer.len(),
        receipt,
        model_path,
        forecast_path,
        evidence_path,
        ledger_path,
    })
}

#[allow(dead_code)]
fn run_legacy_transport_mock(
    config: &AppConfig,
    root: &Path,
    input: &Path,
    output_root: &Path,
    public_symbol: &str,
) -> Result<DatabentoReplayRun> {
    if config.execution.enabled
        || config.execution.allow_real_orders
        || config.live.allow_trade_api
        || !config.live.quote_only
        || !config.live.shadow_only
    {
        bail!("DATABENTO_REPLAY_REFUSES_ANY_EXECUTION_PATH");
    }
    let public_symbol = public_symbol.to_ascii_uppercase();
    if public_symbol != "SPX" {
        bail!("DATABENTO_REPLAY_CURRENTLY_SUPPORTS_ONLY_SPX");
    }
    let target = config
        .research
        .targets
        .iter()
        .find(|target| target.public_symbol.eq_ignore_ascii_case(&public_symbol))
        .context("DATABENTO_REPLAY_TARGET_MAPPING_MISSING")?;
    let model_symbol = canonical_model_symbol(&target.model_symbol)?;
    let (all_envelopes, mut rejected_input_envelopes, input_sha256) =
        read_verified_envelopes(input, config.live.stale_after_ms)?;
    let replay_session = all_envelopes
        .iter()
        .filter(|envelope| {
            envelope.bar.symbol.eq_ignore_ascii_case(&model_symbol)
                && is_regular_session(envelope.bar_start)
        })
        .map(|envelope| envelope.bar_start.with_timezone(&New_York).date_naive())
        .max()
        .context("DATABENTO_REPLAY_HAS_NO_REGULAR_SESSION_TARGET_BAR")?;
    let mut session_envelopes = all_envelopes
        .iter()
        .filter(|envelope| {
            envelope.bar_start.with_timezone(&New_York).date_naive() == replay_session
                && is_regular_session(envelope.bar_start)
        })
        .cloned()
        .collect::<Vec<_>>();
    session_envelopes.sort_by(|left, right| {
        left.bar_start
            .cmp(&right.bar_start)
            .then_with(|| left.bar.symbol.cmp(&right.bar.symbol))
            .then_with(|| left.provider_available_at.cmp(&right.provider_available_at))
    });
    if session_envelopes.is_empty() {
        bail!("DATABENTO_REPLAY_SESSION_HAS_NO_VERIFIED_ENVELOPES");
    }
    let context_input = input.with_file_name("databento_context_observations.jsonl");
    let (mut session_context_envelopes, rejected_context_envelopes) =
        read_verified_context_observations(&context_input, replay_session)?;
    rejected_input_envelopes += rejected_context_envelopes;
    let session_bars = session_envelopes
        .iter()
        .map(|envelope| envelope.bar.clone())
        .collect::<Vec<_>>();
    let replay_feature_contract = OfflineFeatureTrainingContractConfig::v2_no_uup_candidate();
    let mut observed_context_ready = session_envelopes
        .iter()
        .filter(|envelope| envelope.bar.symbol.eq_ignore_ascii_case(&model_symbol))
        .any(|envelope| {
            features::context_observation_readiness_with_schema_at_cutoff(
                &session_bars,
                &[],
                envelope.bar_start,
                &config.live.required_context_symbols,
                config.live.max_context_skew_ms,
                &config.live.context_observation_policy,
                &replay_feature_contract.cross_asset_feature_schema,
            )
            .ready
        });

    let historical_path = root.join("normalized/market_bars.csv");
    let records = MarketBarCsvImporter
        .import(&historical_path)
        .with_context(|| {
            format!(
                "DATABENTO_REPLAY_HISTORICAL_BARS_UNAVAILABLE:{}",
                historical_path.display()
            )
        })?
        .records;

    let capability = capability::inspect(&config.data)?;
    let mut research = config.research.clone();
    research.target = model_symbol.clone();
    let mut source_mode = "RECORDED_DATABENTO_ENVELOPES".to_string();
    let mut synthetic_context_intervals = 0_usize;
    let historical_dates = records
        .iter()
        .filter(|bar| {
            bar.symbol.eq_ignore_ascii_case(&model_symbol)
                && is_regular_session(bar.timestamp)
                && bar.timestamp.with_timezone(&New_York).date_naive() < replay_session
        })
        .map(|bar| bar.timestamp.with_timezone(&New_York).date_naive())
        .collect::<BTreeSet<_>>();
    // The local off-hours query is an integration mock, not a market replay
    // claim. Always use a held-in-distribution historical session so the
    // frozen analog gate can be exercised deterministically; the separately
    // verified recorded envelopes remain input-contract evidence only.
    let use_historical_transport_mock = true;
    if use_historical_transport_mock {
        let mock_source_session = historical_dates
            .iter()
            .next_back()
            .copied()
            .context("DATABENTO_REPLAY_NO_HISTORICAL_TRANSPORT_MOCK_SESSION")?;
        let source_rows = records
            .iter()
            .filter(|bar| {
                bar.timestamp.with_timezone(&New_York).date_naive() == mock_source_session
                    && is_regular_session(bar.timestamp)
            })
            .cloned()
            .collect::<Vec<_>>();
        let target_rows = source_rows
            .iter()
            .filter(|bar| {
                bar.symbol.eq_ignore_ascii_case(&model_symbol) && bar.is_observed_trade_bar()
            })
            .cloned()
            .collect::<Vec<_>>();
        if target_rows.len() < 121 {
            bail!("DATABENTO_REPLAY_HISTORICAL_MOCK_TARGET_SESSION_TOO_SHORT");
        }
        let mut dense_rows = target_rows.clone();
        for member in &replay_feature_contract.cross_asset_feature_schema.members {
            let mut available = source_rows
                .iter()
                .filter(|bar| {
                    bar.symbol.eq_ignore_ascii_case(&member.symbol) && bar.is_observed_trade_bar()
                })
                .cloned()
                .collect::<Vec<_>>();
            available.sort_by_key(|bar| bar.timestamp);
            if available.is_empty() {
                // The installed historical export predates VXX coverage. A
                // deterministic inverse-target proxy is sufficient to
                // exercise transport/context plumbing, but is explicitly
                // synthetic and must never be described as market data.
                for target in &target_rows {
                    synthetic_context_intervals += 1;
                    let mut context = target.clone();
                    context.symbol = member.symbol.to_ascii_uppercase();
                    context.volume = 1.0;
                    context.vwap = Some(context.close);
                    context.trade_count = Some(1);
                    context.data_quality =
                        "synthetic_inverse_target_proxy_pipeline_mock_not_market_data".to_string();
                    dense_rows.push(context);
                }
                continue;
            }
            let first = available.first().cloned().with_context(|| {
                format!(
                    "DATABENTO_REPLAY_HISTORICAL_MOCK_CONTEXT_SYMBOL_ABSENT:{}",
                    member.symbol
                )
            })?;
            for target in &target_rows {
                let selected = available
                    .iter()
                    .rev()
                    .find(|bar| bar.timestamp <= target.timestamp)
                    .cloned()
                    .unwrap_or_else(|| first.clone());
                let mut context = selected;
                if context.timestamp != target.timestamp {
                    synthetic_context_intervals += 1;
                    context.timestamp = target.timestamp;
                    context.open = context.close;
                    context.high = context.close;
                    context.low = context.close;
                    context.volume = 1.0;
                    context.vwap = Some(context.close);
                    context.trade_count = Some(1);
                    context.data_quality =
                        "synthetic_forward_fill_pipeline_mock_not_market_data".to_string();
                }
                dense_rows.push(context);
            }
        }
        let day_offset = replay_session
            .signed_duration_since(mock_source_session)
            .num_days();
        session_envelopes = dense_rows
            .into_iter()
            .map(|mut bar| {
                bar.timestamp += ChronoDuration::days(day_offset);
                bar.source =
                    "AXIO7/DATABENTO_SHAPED_HISTORICAL_TRANSPORT_MOCK/ohlcv-1m".to_string();
                if !bar.data_quality.starts_with("synthetic_") {
                    bar.data_quality =
                        "historical_transport_mock_not_current_market_data".to_string();
                }
                let available_at =
                    bar.timestamp + ChronoDuration::minutes(1) + ChronoDuration::milliseconds(50);
                DatabentoRealtimeBarEnvelope {
                    schema_version: DATABENTO_LIVE_BAR_SCHEMA_VERSION.to_string(),
                    provider: "axio7_databento_shaped_historical_mock".to_string(),
                    dataset: "NORMALIZED_HISTORICAL_TRANSPORT_MOCK".to_string(),
                    provider_schema: "ohlcv-1m-shaped".to_string(),
                    received_at: available_at,
                    provider_available_at: available_at,
                    bar_start: bar.timestamp,
                    bar_end: bar.timestamp + ChronoDuration::minutes(1),
                    finalized_at: available_at,
                    entitlement: "HISTORICAL_PIPELINE_MOCK_NOT_REALTIME".to_string(),
                    delayed: false,
                    stale: false,
                    replay: true,
                    symbol_mapping_verified: true,
                    bar,
                    caveats: vec![
                        "Internally generated Databento-shaped transport mock from a licensed normalized historical session; missing context intervals may use explicit synthetic forward fills or deterministic proxy rows, and no row is a Databento record or current market data.".to_string(),
                    ],
                }
            })
            .collect();
        session_envelopes.sort_by(|left, right| {
            left.bar_start
                .cmp(&right.bar_start)
                .then_with(|| left.bar.symbol.cmp(&right.bar.symbol))
        });
        session_context_envelopes.clear();
        observed_context_ready = true;
        source_mode = "DATABENTO_SHAPED_HISTORICAL_TRANSPORT_MOCK".to_string();
    }
    let historical_training_sessions = historical_dates.len().min(60);
    let training_start = historical_dates
        .iter()
        .rev()
        .nth(historical_training_sessions.saturating_sub(1))
        .copied()
        .context("DATABENTO_REPLAY_HISTORICAL_TRAINING_WINDOW_EMPTY")?;
    let training_records = records
        .into_iter()
        .filter(|bar| {
            let session = bar.timestamp.with_timezone(&New_York).date_naive();
            session >= training_start && session < replay_session
        })
        .collect::<Vec<_>>();
    fs::create_dir_all(output_root)?;
    let model_path = output_root.join("model_spx_replay_local.json");
    let current_dataset_hash = capability
        .normalized_file_sha256
        .as_deref()
        .or_else(|| capability.manifest_hashes.last().map(String::as_str))
        .context("DATABENTO_REPLAY_RUNTIME_DATA_MANIFEST_HASH_MISSING")?;
    let cached_artifact = fs::read(&model_path)
        .ok()
        .and_then(|bytes| serde_json::from_slice::<predictor::FrozenPredictorArtifact>(&bytes).ok())
        .filter(|artifact| {
            artifact.validate_static().is_ok()
                && artifact.target.eq_ignore_ascii_case(&model_symbol)
                && artifact.code_commit_hash == DATABENTO_REPLAY_MODEL_RECIPE
                && artifact.training_dataset_hash == current_dataset_hash
        });
    let artifact = match cached_artifact {
        Some(artifact) => artifact,
        None => {
            let exact_historical_states =
                features::build_states(&training_records, &model_symbol, &research)?;
            let artifact = predictor::train_frozen_artifact(
                &exact_historical_states,
                &research,
                &capability,
                Utc::now(),
                DATABENTO_REPLAY_MODEL_RECIPE,
            )?;
            write_json_atomic(&model_path, &artifact)?;
            artifact
        }
    };
    if !observed_context_ready {
        bail!("DATABENTO_REPLAY_NO_COMPLETE_NO_UUP_CONTEXT_CUTOFF");
    }
    let mut states = features::build_states(&training_records, &model_symbol, &research)?;
    let replay_context_policy = config.live.context_observation_policy.clone();
    let artifact_feature_identity_matches_replay = false;
    let mut feature_engine = features::IncrementalFeatureEngine::new_with_feature_contract(
        &training_records,
        &model_symbol,
        &research,
        config.live.required_context_symbols.clone(),
        config.live.max_context_skew_ms,
        replay_context_policy.clone(),
        replay_feature_contract.cross_asset_feature_schema.clone(),
    )?;
    let mut replay_events = session_envelopes.clone();
    replay_events.sort_by(|left, right| {
        left.provider_available_at
            .cmp(&right.provider_available_at)
            .then_with(|| left.bar.symbol.cmp(&right.bar.symbol))
    });
    for envelope in replay_events {
        feature_engine.ingest(envelope.bar)?;
    }
    states.extend(
        feature_engine
            .states()
            .iter()
            .filter(|state| state.session_date == replay_session)
            .cloned(),
    );
    let selected_state_index = states
        .iter()
        .rposition(|state| {
            state.timestamp.with_timezone(&New_York).date_naive() == replay_session
                && state.cross_asset_context_complete
                && state.minutes_to_close >= 61
        })
        .context("DATABENTO_REPLAY_NO_COMPLETE_CONTEXT_CUTOFF")?;
    states.truncate(selected_state_index + 1);
    let observation_cutoff = states
        .last()
        .context("DATABENTO_REPLAY_STATE_SET_EMPTY")?
        .timestamp;
    let target_envelope = session_envelopes
        .iter()
        .find(|envelope| {
            envelope.bar.symbol.eq_ignore_ascii_case(&model_symbol)
                && envelope.bar_start == observation_cutoff
        })
        .context("DATABENTO_REPLAY_TARGET_SOURCE_ENVELOPE_MISSING")?;
    let replayed_envelopes = session_envelopes
        .iter()
        .filter(|envelope| envelope.bar_start <= observation_cutoff)
        .cloned()
        .collect::<Vec<_>>();
    let replayed_context_envelopes = if artifact_feature_identity_matches_replay {
        Vec::new()
    } else {
        session_context_envelopes
            .iter()
            .filter(|envelope| envelope.interval_start <= observation_cutoff)
            .cloned()
            .collect::<Vec<_>>()
    };
    let source_envelopes_sha256 = sha256_bytes(&serde_json::to_vec(&json!({
        "trade_bar_envelopes":replayed_envelopes,
        "causal_no_trade_envelopes":replayed_context_envelopes,
    }))?);
    let replay_id = format!(
        "databento-replay-{}-{}",
        replay_session.format("%Y%m%d"),
        &source_envelopes_sha256[..16]
    );
    let mut bundle = predictor::forecast_with_frozen_artifact(
        &states,
        &research,
        &config.os,
        &capability,
        target_envelope.provider_available_at,
        &artifact,
    )?;
    predictor::enforce_realtime_forward_shadow(
        &mut bundle,
        target_envelope.provider_available_at,
        config.live.execution_latency_ms,
        true,
        &RealtimeSourceMetadata {
            source_version: if source_mode == "RECORDED_DATABENTO_ENVELOPES" {
                "EQUS.MINI/ohlcv-1m/DETERMINISTIC_REPLAY"
            } else {
                "DATABENTO_SHAPED_HISTORICAL_TRANSPORT_MOCK/ohlcv-1m"
            },
            provider: "DATABENTO_REPLAY",
            market_coverage: if source_mode == "RECORDED_DATABENTO_ENVELOPES" {
                "RECORDED_TARGET_AND_REQUIRED_CONTEXT_AT_REPLAY_CUTOFF"
            } else {
                "TIME_SHIFTED_HISTORICAL_TARGET_AND_CONTEXT_AT_REPLAY_CUTOFF"
            },
            availability_semantics: if source_mode == "RECORDED_DATABENTO_ENVELOPES" {
                DATABENTO_REPLAY_AVAILABILITY_SEMANTICS
            } else {
                "DATABENTO_SHAPED_HISTORICAL_TRANSPORT_MOCK_WITH_VIRTUAL_PROVIDER_CLOCK_NOT_CURRENT_MARKET_DATA"
            },
        },
    );
    let horizons = bundle
        .prediction_layer
        .iter()
        .map(|contract| contract.horizon_minutes)
        .collect::<BTreeSet<_>>();
    if bundle.prediction_layer.len() != 4 || horizons != BTreeSet::from([5, 15, 30, 60]) {
        bail!(
            "DATABENTO_REPLAY_EXACT_FOUR_HORIZONS_REQUIRED actual_count={} actual_horizons={horizons:?}",
            bundle.prediction_layer.len()
        );
    }

    let ledger_path = output_root.join("prediction_ledger.sqlite3");
    let ledger = PredictionLedger::open(&ledger_path)?;
    for contract in &mut bundle.prediction_layer {
        *contract = ledger.append_prediction(contract)?;
    }
    if let Some(generated_at) = bundle
        .prediction_layer
        .iter()
        .map(|contract| contract.created_at)
        .min()
    {
        bundle.generated_at = generated_at;
    }
    let forecast_bytes = serde_json::to_vec(&bundle)?;
    let forecast_sha256 = sha256_bytes(&forecast_bytes);
    let forecast_path = output_root.join("forecast_spx_latest.json");
    write_json_atomic(&forecast_path, &bundle)?;

    let replayed_symbols = replayed_envelopes
        .iter()
        .map(|envelope| envelope.bar.symbol.to_ascii_uppercase())
        .collect::<BTreeSet<_>>()
        .into_iter()
        .collect::<Vec<_>>();
    let generated_at = bundle
        .prediction_layer
        .iter()
        .map(|contract| contract.latest_input_available_at)
        .max()
        .unwrap_or(observation_cutoff);
    let receipt = DatabentoReplayReceipt {
        schema_version: DATABENTO_REPLAY_RECEIPT_SCHEMA_VERSION.to_string(),
        replay_id: replay_id.clone(),
        generated_at,
        replay_session,
        observation_cutoff,
        public_symbol: public_symbol.clone(),
        model_symbol: model_symbol.clone(),
        input_path: input.to_path_buf(),
        input_sha256,
        source_envelopes_sha256,
        accepted_input_envelopes: all_envelopes.len() + session_context_envelopes.len(),
        replayed_source_envelopes: replayed_envelopes.len(),
        replayed_context_observations: replayed_context_envelopes.len(),
        rejected_input_envelopes,
        replayed_symbols,
        source_mode: source_mode.clone(),
        synthetic_context_intervals,
        context_observation_policy_schema_version: replay_context_policy.schema_version.clone(),
        artifact_feature_identity_matches_replay,
        historical_training_sessions,
        replay_local_model_trained: true,
        production_artifact_used: false,
        historical_regime_initialized: true,
        realized_outcomes: Vec::new(),
        rust_inference: true,
        current_market_data: false,
        live_state_written: false,
        execution_enabled: false,
    };
    let receipt_path = output_root.join("receipt_spx_latest.json");
    write_json_atomic(&receipt_path, &receipt)?;

    let query = exact_replay_query(&public_symbol);
    let query_sha256 = query.canonical_sha256()?;
    let candidates = bundle
        .prediction_layer
        .iter()
        .map(|contract| replay_candidate(&public_symbol, contract, &receipt, &forecast_sha256))
        .collect::<Vec<_>>();
    let model_contract = json!({
        "runtime_owner":"RUST",
        "replay_runtime_owner":"quant_engine_rs::data::databento_replay",
        "replay_id":receipt.replay_id,
        "replay_receipt_schema":receipt.schema_version,
        "replay_session":receipt.replay_session,
        "replay_source_mode":receipt.source_mode,
        "synthetic_context_intervals":receipt.synthetic_context_intervals,
        "replay_source_envelope_count":receipt.replayed_source_envelopes + receipt.replayed_context_observations,
        "replay_trade_bar_envelope_count":receipt.replayed_source_envelopes,
        "replay_context_observation_count":receipt.replayed_context_observations,
        "replay_context_observation_policy":receipt.context_observation_policy_schema_version,
        "artifact_feature_identity_matches_replay":receipt.artifact_feature_identity_matches_replay,
        "historical_training_sessions":receipt.historical_training_sessions,
        "replay_cross_asset_feature_schema":replay_feature_contract.cross_asset_feature_schema.schema_version,
        "replay_excluded_context_symbol":"UUP",
        "replay_local_model_trained":receipt.replay_local_model_trained,
        "production_artifact_used":receipt.production_artifact_used,
        "input_sha256":receipt.input_sha256,
        "source_envelopes_sha256":receipt.source_envelopes_sha256,
        "forecast_horizons_minutes":[5,15,30,60],
        "model_version":bundle.prediction_layer.first().map(|row| row.model_id.clone()),
        "feature_schema_version":bundle.prediction_layer.first().map(|row| row.feature_version.clone()),
        "candidate_status":"DETERMINISTIC_HISTORICAL_REPLAY",
        "universe_registry_status":"REPLAY_LOCAL_UNPROMOTED_ARTIFACT",
        "probability_policy":"CALIBRATED_PROBABILITIES_REQUIRE_A_MATCHING_PROMOTED_OOS_ARTIFACT",
        "current_market_data":false,
        "live_state_written":false,
        "rust_inference":true
    });
    let mut evidence = EvidenceEnvelope {
        schema_version: EVIDENCE_ENVELOPE_SCHEMA_VERSION.to_string(),
        evidence_mode: EvidenceMode::DeterministicHistoricalReplay,
        request_id: replay_id,
        query_sha256,
        response_sha256: None,
        generated_at,
        observation_cutoff,
        status: "UNCALIBRATED_RESEARCH_OUTPUT".to_string(),
        query,
        candidates,
        exclusions: Vec::new(),
        historical: Vec::new(),
        data_blockers: Vec::new(),
        readiness: PipelineReadiness {
            model: ready_stage(
                "REPLAY_LOCAL_UNPROMOTED_MODEL_TRAINED",
                "A replay-local Rust model was trained from the bounded historical window under the current feature code; no production model artifact was used.",
                generated_at,
            ),
            feed: ready_stage(
                if source_mode == "RECORDED_DATABENTO_ENVELOPES" {
                    "RECORDED_DATABENTO_ENVELOPES_VERIFIED"
                } else {
                    "DATABENTO_SHAPED_HISTORICAL_TRANSPORT_MOCK_READY"
                },
                if source_mode == "RECORDED_DATABENTO_ENVELOPES" {
                    "Recorded Databento envelopes passed their structural source contract; no current provider stream was queried."
                } else {
                    "A complete licensed historical session was converted into an internal Databento-shaped transport mock because the recorded Databento session began too late for a safe four-horizon batch."
                },
                generated_at,
            ),
            context: ready_stage(
                if source_mode == "DATABENTO_SHAPED_HISTORICAL_TRANSPORT_MOCK" {
                    "REPLAY_SYNTHETIC_CONTEXT_COMPLETE"
                } else if artifact_feature_identity_matches_replay {
                    "REPLAY_POINT_IN_TIME_CONTEXT_COMPLETE"
                } else {
                    "REPLAY_CAUSAL_NO_TRADE_CONTEXT_SHADOW_COMPLETE"
                },
                if source_mode == "DATABENTO_SHAPED_HISTORICAL_TRANSPORT_MOCK" {
                    "Every context minute required by the pipeline is present; gaps and entirely absent context series were filled only with explicitly synthetic pipeline-mock rows."
                } else if artifact_feature_identity_matches_replay {
                    "The selected historical cutoff passed the configured cross-asset context contract."
                } else {
                    "The selected replay cutoff used recorded causal no-trade observations under the separately versioned shadow context policy."
                },
                generated_at,
            ),
            inference: ready_stage(
                "RUST_REPLAY_ALL_HORIZONS_INFERRED",
                "The replay-local Rust predictor produced every configured replay horizon.",
                generated_at,
            ),
            publication: ready_stage(
                "ISOLATED_REPLAY_ARTIFACT_COMMITTED",
                "Replay artifacts and predictions were committed only under data/replay/databento.",
                generated_at,
            ),
        },
        model_contract,
        research_only_policy: json!({
            "product_scope":"DEVELOPMENT_DATABENTO_PIPELINE_REPLAY",
            "personalization_used":false,
            "user_portfolio_inputs_used":false,
            "investment_advice":false,
            "execution_instruction":false,
            "automatic_order_execution":false
        }),
        caveats: vec![
            "DETERMINISTIC_HISTORICAL_REPLAY: replay inputs are not current market data and cannot satisfy the live-publication gate.".to_string(),
            if source_mode == "RECORDED_DATABENTO_ENVELOPES" {
                "Inference consumed structurally verified recorded Databento envelopes.".to_string()
            } else {
                format!("PIPELINE_TRANSPORT_MOCK_ONLY: inference consumed a time-shifted licensed historical session shaped like the Databento one-minute transport contract, including {} explicitly synthetic context intervals (forward-filled gaps and deterministic proxy rows for entirely absent series). These rows are not Databento records, are not current data, and provide no evidence about live connectivity or latency.", receipt.synthetic_context_intervals)
            },
            "The replay initialized regime and feature state from the installed historical dataset before training and running an isolated, unpromoted replay-local Rust model.".to_string(),
            "PIPELINE_INTEGRATION_FEATURE_CANDIDATE_ONLY: the recorded replay session uses the repository's unpromoted no-UUP cross-asset feature candidate because UUP does not provide the required contiguous one-minute coverage in the installed datasets.".to_string(),
            "The checked-in production artifact was not used because its persisted training-state prefix does not match the current feature-code reconstruction; bypassing that lineage validator is forbidden.".to_string(),
            if artifact_feature_identity_matches_replay {
                "All replay context inputs matched the frozen artifact's observed-trade feature identity.".to_string()
            } else {
                "PIPELINE_INTEGRATION_SHADOW_ONLY: the replay-local model retains its exact v1 historical prefix while the recorded replay session excludes UUP under the unpromoted cross-asset candidate; this feature-identity mismatch is explicit, is not model-validation evidence, and cannot be published as live.".to_string()
            },
            "Uncalibrated direction conditions are shown; probability, expected move, rank, and execution remain withheld.".to_string(),
            "The replay never opens a Databento socket and never writes the live prediction ledger or live publication directories.".to_string(),
        ],
    };
    evidence.seal()?;
    let evidence_path = output_root.join("evidence_spx_latest.json");
    write_json_atomic(&evidence_path, &evidence)?;

    Ok(DatabentoReplayRun {
        status: "DETERMINISTIC_DATABENTO_REPLAY_COMPLETE".to_string(),
        predictions_generated: bundle.prediction_layer.len(),
        receipt,
        model_path,
        forecast_path,
        evidence_path,
        ledger_path,
    })
}

pub fn load_cached_evidence(root: &Path, query: &MarketQuery) -> Result<Option<EvidenceEnvelope>> {
    if !supports_query(query) {
        return Ok(None);
    }
    let path = root.join("replay/databento/evidence_spx_latest.json");
    let bytes = match fs::read(&path) {
        Ok(bytes) => bytes,
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => return Ok(None),
        Err(error) => return Err(error.into()),
    };
    let evidence: EvidenceEnvelope = serde_json::from_slice(&bytes)
        .with_context(|| format!("read cached Databento replay evidence {}", path.display()))?;
    // `supports_query` has already constrained the caller to the one neutral
    // SPX model forecast. The website compiler also sends option-liquidity
    // filters that do not participate in this price-only replay. The sealed
    // artifact intentionally records the fixed canonical replay query, so
    // validate against that contract rather than irrelevant caller filters.
    let canonical_query = exact_replay_query("SPX");
    let current_replay_contract = evidence
        .model_contract
        .get("replay_source_mode")
        .and_then(Value::as_str)
        == Some("STRICT_INSTALLED_HISTORICAL_REPLAY")
        && evidence
            .model_contract
            .get("replay_receipt_schema")
            .and_then(Value::as_str)
            == Some(DATABENTO_REPLAY_RECEIPT_SCHEMA_VERSION)
        && evidence
            .model_contract
            .get("synthetic_context_intervals")
            .and_then(Value::as_u64)
            == Some(0)
        && evidence
            .model_contract
            .get("realized_outcomes")
            .and_then(Value::as_array)
            .is_some_and(|outcomes| outcomes.len() == REQUIRED_HORIZONS.len());
    if !current_replay_contract {
        return Ok(None);
    }
    if evidence.evidence_mode != EvidenceMode::DeterministicHistoricalReplay
        || evidence.query != canonical_query
        || evidence.response_sha256.is_none()
    {
        bail!("DATABENTO_REPLAY_CACHED_EVIDENCE_CONTRACT_MISMATCH");
    }
    Ok(Some(evidence))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn replay_query_is_narrow_and_explicit() {
        let query = exact_replay_query("SPX");
        assert!(supports_query(&query));
        assert!(!supports_query(&MarketQuery {
            symbols: vec!["QQQ".into()],
            ..query.clone()
        }));
        assert!(!supports_query(&MarketQuery {
            setup_type: MarketSetupType::Momentum,
            horizon_minutes: Some(5),
            ..query
        }));
    }

    #[test]
    fn regular_session_excludes_after_hours() {
        let regular = DateTime::parse_from_rfc3339("2026-07-29T19:59:00Z")
            .unwrap()
            .with_timezone(&Utc);
        let after_hours = DateTime::parse_from_rfc3339("2026-07-29T20:00:00Z")
            .unwrap()
            .with_timezone(&Utc);
        assert!(is_regular_session(regular));
        assert!(!is_regular_session(after_hours));
    }
}
