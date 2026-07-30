use std::{
    collections::{BTreeMap, BTreeSet, HashMap},
    ffi::OsStr,
    io::{BufRead, BufReader},
    path::{Path, PathBuf},
    process::{Command as ProcessCommand, Stdio},
    time::Instant,
};

use anyhow::{Context, Result, bail};
use axio_quant_engine::{
    AppConfig,
    broker::{BrokerMonitor, ExecutionStore, MoomooBrokerClient, plan_order, reconcile_once},
    config::OfflineFeatureTrainingContractConfig,
    data::{
        LicensedFileImporter, capability, context,
        csv_import::MarketBarCsvImporter,
        databento, dbn_decode,
        market_store::{AvailabilityPolicy, LicenseScope, MarketDataStore, MaterializeRequest},
        training_lineage::{self, AdjustmentStatus, SealTrainingLineageRequest},
    },
    domain::MarketState,
    engine::{
        features,
        regime::{
            GaussianHmm, HmmCandidateAssessment, select_hmm_candidates,
            validate_hmm_state_occupancy,
        },
        run_csv_research,
        tvtp_regime::{NonHomogeneousGaussianHmm, TvtpFitConfig},
        walk_forward,
    },
    frozen_universe::{LoadedFrozenUniverse, canonical_model_symbol, load_frozen_universe},
    ledger::Ledger,
    live,
    offline_model_validation::{
        NamedEvaluationInterval, OfflineValidationConfig, OfflineValidationLineage,
        evaluate_offline_frozen_model,
    },
    os::QuantRuntime,
    pattern_factory::{PatternFactoryConfig, run_autonomous_pattern_factory},
    prediction_ledger::{ForecastSettlement, PredictionLedger, settlement_content_hash},
    predictor,
};
use chrono::{DateTime, Duration, NaiveDate, Timelike, Utc};
use chrono_tz::America::New_York;
use clap::{Args, Parser, Subcommand, ValueEnum};
use sha2::Digest;

#[derive(Debug, Parser)]
#[command(
    name = "quantctl",
    about = "AXIO7 licensed-data and research control CLI"
)]
struct Cli {
    #[arg(long, global = true, default_value = "configs/production.yaml")]
    config: PathBuf,
    #[command(subcommand)]
    command: Command,
}

#[derive(Debug, Subcommand)]
enum Command {
    Data(DataArgs),
    Live(LiveArgs),
    Broker(BrokerArgs),
    Predictor(PredictorArgs),
    Research(ResearchArgs),
    Ledger(LedgerArgs),
    Bench,
}

#[derive(Debug, Args)]
struct BrokerArgs {
    #[command(subcommand)]
    command: BrokerCommand,
}

#[derive(Debug, Subcommand)]
enum BrokerCommand {
    /// Verify authenticated connectivity without creating an order.
    Doctor,
    /// Pull authoritative account/position/order/fill state into the OMS.
    Reconcile,
    /// Evaluate the current promoted allocation and optionally route one order.
    ExecuteOnce {
        #[arg(long, default_value = "http://127.0.0.1:8001")]
        control_url: String,
        #[arg(
            long,
            default_value = "data/reports/forecast_contract_live_latest.json"
        )]
        forecast: PathBuf,
        #[arg(long)]
        execute: bool,
        #[arg(long)]
        confirm_live_account: Option<u64>,
    },
    /// Continuously evaluate new forecasts. OMS identity makes retries idempotent.
    Run {
        #[arg(long, default_value = "http://127.0.0.1:8001")]
        control_url: String,
        #[arg(
            long,
            default_value = "data/reports/forecast_contract_live_latest.json"
        )]
        forecast: PathBuf,
        #[arg(long)]
        execute: bool,
        #[arg(long)]
        confirm_live_account: Option<u64>,
        #[arg(long, default_value_t = 2_000)]
        poll_ms: u64,
    },
}

#[derive(Debug, Args)]
struct LiveArgs {
    #[command(subcommand)]
    command: LiveCommand,
}

#[derive(Debug, Clone, Copy, ValueEnum)]
enum MassiveReadinessScope {
    All,
    Equity,
    Options,
}

#[derive(Debug, Subcommand)]
enum LiveCommand {
    /// Print the immutable feature-contract identity for retraining. The
    /// no-UUP candidate remains observed-bars-only; causal absence is a
    /// separate shadow identity pending Databento batch-parity evidence.
    #[command(name = "feature-contract")]
    FeatureContract {
        #[arg(long)]
        no_uup: bool,
        #[arg(long)]
        no_uup_no_tlt: bool,
        #[arg(long)]
        causal_absence_shadow: bool,
    },
    /// Verify paid SIP stock WebSocket and OPRA full-chain entitlements. The
    /// report contains no secret and fails closed on delayed/unauthorized data.
    #[command(name = "massive-check")]
    MassiveCheck {
        #[arg(long, default_value = "data/live/massive_readiness.json")]
        output: PathBuf,
        #[arg(long, value_enum, default_value_t = MassiveReadinessScope::All)]
        scope: MassiveReadinessScope,
    },
    /// Persist finalized real-time SIP one-minute bars from the licensed
    /// Massive WebSocket. No prediction or order routing occurs here.
    #[command(name = "massive-stream")]
    MassiveStream {
        #[arg(long, default_value = "data/live/massive_stock_bars.jsonl")]
        output: PathBuf,
        #[arg(long, default_value = "data/live/massive_stream_status.json")]
        status: PathBuf,
        /// Test/diagnostic bound. Omit for the reconnecting production stream.
        #[arg(long)]
        max_finalized: Option<u64>,
    },
    /// End-to-end shadow runtime: licensed SIP stream -> strict synchronized
    /// context -> bounded-session incremental features -> immutable artifact.
    #[command(name = "massive-model")]
    MassiveModel {
        #[arg(long, default_value = "data/normalized/market_bars.csv")]
        historical_bars: PathBuf,
        #[arg(long, default_value = "data/models/universe/registry.json")]
        universe_registry: PathBuf,
        #[arg(long, default_value = "data/live/massive_stock_bars.jsonl")]
        raw_output: PathBuf,
        #[arg(long, default_value = "data/live/massive_stream_status.json")]
        stream_status: PathBuf,
        #[arg(
            long,
            default_value = "data/reports/forecast_contract_live_latest.json"
        )]
        forecast_output: PathBuf,
        #[arg(long, default_value = "data/live/massive_inference_status.json")]
        inference_status: PathBuf,
        #[arg(long, default_value = "data/state/prediction_ledger.sqlite3")]
        ledger: PathBuf,
    },
    /// Download every page of one or more licensed OPRA chain snapshots and
    /// atomically publish strict coverage/readiness artifacts.
    #[command(name = "massive-options-snapshot")]
    MassiveOptionsSnapshot {
        #[arg(long, value_delimiter = ',')]
        underlyings: Vec<String>,
    },
    /// Refresh configured full option chains continuously. Incomplete/stale
    /// chains are persisted with model_ready=false, never silently consumed.
    #[command(name = "massive-options-watch")]
    MassiveOptionsWatch {
        #[arg(long, value_delimiter = ',')]
        underlyings: Vec<String>,
        #[arg(long)]
        refresh_seconds: Option<u64>,
    },
    #[command(name = "moomoo-check", hide = true)]
    Check {
        #[arg(long, default_value = "127.0.0.1")]
        host: String,
        #[arg(long, default_value_t = 11_111)]
        port: u16,
        #[arg(long, default_value = "data/live/status.json")]
        output: PathBuf,
    },
    #[command(name = "moomoo-capabilities", hide = true)]
    Capabilities,
    #[command(name = "moomoo-stream", hide = true)]
    Stream {
        #[arg(long, default_value_t = true)]
        shadow: bool,
        #[arg(long, default_value = "../scripts/moomoo_quote_bridge.py")]
        bridge: PathBuf,
        #[arg(long, default_value = "data/normalized/market_bars.csv")]
        historical_bars: PathBuf,
        #[arg(long, default_value = "data/live/raw_sdk_events.jsonl")]
        raw_output: PathBuf,
        #[arg(long, default_value = "data/live/finalized_bars.jsonl")]
        finalized_output: PathBuf,
        #[arg(long, default_value = "data/live/gaps.jsonl")]
        gaps_output: PathBuf,
        #[arg(
            long,
            default_value = "data/reports/forecast_contract_live_latest.json"
        )]
        forecast_output: PathBuf,
        #[arg(long, default_value = "data/state/prediction_ledger.sqlite3")]
        ledger: PathBuf,
        #[arg(long, default_value = "data/models/universe/registry.json")]
        universe_registry: PathBuf,
        /// Optional owner-only HTTPS relay. The bearer value is read from the
        /// named environment variable and is never accepted on the command line.
        #[arg(long, env = "AXIO7_MOOMOO_FORECAST_RELAY_URL")]
        publish_url: Option<String>,
        #[arg(long, default_value = "MOOMOO_FORECAST_RELAY_TOKEN")]
        publish_token_env: String,
    },
    #[command(name = "moomoo-status", hide = true)]
    Status {
        #[arg(long, default_value = "data/live/status.json")]
        status: PathBuf,
    },
    #[command(name = "moomoo-replay", hide = true)]
    Replay {
        #[arg(long)]
        input: PathBuf,
        #[arg(long, default_value = "SPY")]
        symbol: String,
        #[arg(long, default_value = "data/replay/moomoo_finalized_bars.jsonl")]
        output: PathBuf,
        #[arg(long, default_value = "data/normalized/market_bars.csv")]
        historical_bars: PathBuf,
        #[arg(
            long,
            default_value = "data/reports/forecast_contract_owner_replay_latest.json"
        )]
        forecast_output: PathBuf,
        #[arg(long, default_value = "data/state/replay_prediction_ledger.sqlite3")]
        ledger: PathBuf,
        #[arg(long, default_value = "data/models/universe/registry.json")]
        universe_registry: PathBuf,
        /// Optional owner-only HTTPS relay. Replay remains explicitly labelled
        /// historical and can never satisfy the live-publication gate.
        #[arg(long, env = "AXIO7_MOOMOO_FORECAST_RELAY_URL")]
        publish_url: Option<String>,
        #[arg(long, default_value = "MOOMOO_FORECAST_RELAY_TOKEN")]
        publish_token_env: String,
    },
}

#[derive(Debug, Args)]
struct LedgerArgs {
    #[arg(long, default_value = "../ledger/quant_ledger.sqlite3")]
    database: PathBuf,
}

#[derive(Debug, Args)]
struct DataArgs {
    #[command(subcommand)]
    command: DataCommand,
}

#[derive(Debug, Subcommand)]
enum DataCommand {
    Plan,
    Capability {
        #[arg(long, default_value = "data/quality/data_capability_latest.json")]
        output: PathBuf,
    },
    Doctor {
        #[arg(long, default_value = "data/quality/data_doctor_latest.json")]
        output: PathBuf,
    },
    Estimate(EstimateArgs),
    SamplePlan {
        #[arg(long, default_value = "data/normalized/market_bars.csv")]
        bars: PathBuf,
        #[arg(long)]
        event_date: Option<NaiveDate>,
        #[arg(long, default_value_t = 0.05)]
        strike_window_pct: f64,
        #[arg(long, default_value = "data/estimates/opra_five_day_sample_plan.json")]
        output: PathBuf,
    },
    OpraSample {
        #[arg(long, value_delimiter = ',', num_args = 1..)]
        dates: Vec<NaiveDate>,
        #[arg(long, default_value = "SPXW")]
        parent: String,
        #[arg(long, value_delimiter = ',', default_value = "definition,cbbo-1m")]
        schemas: Vec<String>,
        #[arg(long)]
        confirm_download: bool,
        #[arg(long, default_value_t = 0.0)]
        maximum_cost_usd: f64,
    },
    ValidateSpxw,
    Coverage,
    Lineage,
    Cost {
        #[arg(long)]
        request: String,
    },
    Download {
        #[arg(long)]
        request: String,
        #[arg(long)]
        confirm_cost: bool,
        #[arg(long)]
        maximum_cost_usd: f64,
    },
    ValidateBars {
        #[arg(long)]
        input: PathBuf,
    },
    /// Validate a pinned private market-data rights receipt using the same
    /// fail-closed parser as production readiness. No evidence content,
    /// identity, URL, path, or hash is printed.
    ValidateMarketDataRights {
        #[arg(long)]
        data_root: PathBuf,
        #[arg(long)]
        provider: String,
        #[arg(long)]
        product: String,
        #[arg(long)]
        receipt_sha256: String,
        /// Optional deterministic UTC validation clock for isolated tests.
        #[arg(long)]
        at: Option<String>,
    },
    /// Seal immutable normalized-bars lineage for offline training.
    ///
    /// This validates the pinned model-input rights receipt and hashes the
    /// normalized bars plus every raw source without copying market data. The
    /// receipt must be `data/rights/market_data_rights_receipt.json`, with its
    /// SHA-256 pinned in `AXIO7_MARKET_DATA_RIGHTS_RECEIPT_SHA256`.
    SealTrainingLineage {
        /// Normalized CSV under the configured normalized root. Defaults to
        /// `<normalized_root>/market_bars.csv`.
        #[arg(long)]
        bars: Option<PathBuf>,
        /// Raw file or directory under the configured raw root. Repeat this
        /// option to bind more than one source.
        #[arg(long = "source", required = true, action = clap::ArgAction::Append)]
        sources: Vec<PathBuf>,
        /// Canonical lowercase receipt provider. Supported normalized-source
        /// bindings are Databento datasets and Massive US equities.
        #[arg(long)]
        provider: String,
        /// Canonical uppercase receipt product.
        #[arg(long)]
        product: String,
        #[arg(
            long,
            value_parser = ["raw-unadjusted", "vendor-adjusted"]
        )]
        adjustment_status: String,
        /// New manifest path under the configured manifest root. Its basename
        /// must be `normalized_market_bars_<bars-sha256>.json`. Existing
        /// manifests are immutable and will not be overwritten.
        #[arg(long)]
        output: PathBuf,
    },
    /// Append a validated normalized CSV into the immutable point-in-time
    /// market-data store. License and availability semantics are mandatory.
    MaterializeBars {
        #[arg(long)]
        input: PathBuf,
        #[arg(long, default_value = "data/state/market_data.sqlite3")]
        database: PathBuf,
        #[arg(long)]
        provider: String,
        #[arg(long)]
        dataset: String,
        #[arg(long)]
        captured_at: Option<String>,
        #[arg(
            long,
            value_parser = ["observed-at-ingestion", "completed-minute-end-plus-delay"]
        )]
        availability_policy: String,
        #[arg(long, default_value_t = 0)]
        availability_delay_seconds: i64,
        #[arg(
            long,
            value_parser = ["research-only", "internal-display", "public-redistribution"]
        )]
        license_scope: String,
        #[arg(long)]
        license_reference: String,
    },
    MarketStoreCoverage {
        #[arg(long, default_value = "data/state/market_data.sqlite3")]
        database: PathBuf,
    },
    /// Audit a normalized contextual feed. This never promotes snapshots to
    /// executable prices and rejects observations unavailable at the cutoff.
    ContextAudit {
        #[arg(long)]
        input: Option<PathBuf>,
        #[arg(long)]
        cutoff: Option<String>,
        #[arg(long, default_value = "data/quality/context_audit_latest.json")]
        output: PathBuf,
    },
    DecodeOhlcv {
        #[arg(long)]
        input: PathBuf,
        #[arg(long)]
        output: PathBuf,
        #[arg(long)]
        symbol_alias: Option<String>,
    },
    DecodeCbbo {
        #[arg(long)]
        input: PathBuf,
        #[arg(long)]
        output: PathBuf,
    },
    MassiveStatus,
    MassiveSync {
        #[arg(long)]
        from: NaiveDate,
        #[arg(long)]
        to: NaiveDate,
        #[arg(long, value_delimiter = ',')]
        symbols: Vec<String>,
        /// Optional cache-compatible request chunk override. It does not
        /// change the configured request-rate limit.
        #[arg(long)]
        chunk_days: Option<i64>,
        #[arg(long, default_value = "data/normalized/market_bars.csv")]
        output: PathBuf,
    },
    /// One incremental poll. Invoke from Task Scheduler/cron; it never fabricates
    /// fresher bars than the account entitlement makes available.
    MassivePoll {
        #[arg(long, default_value_t = 3)]
        lookback_days: i64,
        #[arg(long, default_value = "data/normalized/market_bars.csv")]
        output: PathBuf,
    },
}

#[derive(Debug, Args)]
struct PredictorArgs {
    #[command(subcommand)]
    command: PredictorCommand,
}

#[derive(Debug, Subcommand)]
enum PredictorCommand {
    Train {
        #[arg(long, default_value = "data/normalized/market_bars.csv")]
        bars: PathBuf,
        #[arg(long, default_value = "data/models/predictor_candidate_latest.json")]
        output: PathBuf,
    },
    /// Train one immutable candidate artifact per configured public target.
    /// This never promotes an artifact or enables execution.
    TrainUniverse {
        #[arg(long, default_value = "data/normalized/market_bars.csv")]
        bars: PathBuf,
        /// Output directory. The v1 path defaults to the production candidate
        /// location; an explicit feature contract requires a separate path.
        #[arg(long)]
        output_dir: Option<PathBuf>,
        /// Registry path. An explicit feature contract requires this to be
        /// supplied under its separate output directory.
        #[arg(long)]
        registry: Option<PathBuf>,
        #[arg(long, value_delimiter = ',')]
        symbols: Vec<String>,
        /// Dedicated offline feature contract. It cannot modify AppConfig or
        /// promote a candidate, and it requires explicit isolated outputs.
        #[arg(long)]
        feature_contract_config: Option<PathBuf>,
    },
    WalkForward {
        #[arg(long, default_value = "data/normalized/market_bars.csv")]
        bars: PathBuf,
        #[arg(long, default_value = "data/reports/walk_forward_contract_latest.json")]
        output: PathBuf,
        /// Empty means every configured research horizon.
        #[arg(long, value_delimiter = ',')]
        horizons: Vec<usize>,
        /// Optional isolated feature contract, for example the no-UUP
        /// candidate. It changes only this offline validation run.
        #[arg(long)]
        feature_contract_config: Option<PathBuf>,
        /// Optional immutable candidate registry whose exact target artifact
        /// is audited against these states and evaluation intervals.
        #[arg(long)]
        reference_registry: Option<PathBuf>,
        /// Optional externally displayed replay interval for overlap auditing.
        /// Both endpoints are required together and use inclusive RFC3339
        /// timestamps.
        #[arg(long)]
        displayed_replay_start: Option<String>,
        #[arg(long)]
        displayed_replay_end: Option<String>,
    },
    /// Compare no-regime, Gaussian HMM, Student-t HMM, minimum-duration HSMM,
    /// and TVTP HMM on identical chronological embargoed OOF folds. K=8 is a
    /// challenger only; this report never mutates the live artifact.
    RegimeCompetition {
        #[arg(long, default_value = "data/normalized/market_bars.csv")]
        bars: PathBuf,
        #[arg(
            long,
            default_value = "data/reports/regime_oof_competition_latest.json"
        )]
        output: PathBuf,
    },
    /// Materialize horizon-specific Platt/isotonic artifacts from precomputed
    /// OOF rows. This command can reach oos_validated but never auto-promotes.
    Calibrate {
        #[arg(long)]
        input: PathBuf,
        #[arg(long)]
        fit_start: String,
        #[arg(long)]
        fit_end: String,
        #[arg(long)]
        oos_start: String,
        #[arg(long)]
        oos_end: String,
        #[arg(long)]
        valid_from: Option<String>,
        #[arg(long, default_value_t = 200)]
        minimum_oos_samples: usize,
        #[arg(long, default_value_t = 0.05)]
        maximum_ece: f64,
        #[arg(
            long,
            default_value = "data/models/probability_calibration_registry_candidate.json"
        )]
        output: PathBuf,
        #[arg(
            long,
            default_value = "data/reports/probability_calibration_build_latest.json"
        )]
        report: PathBuf,
    },
    Forecast {
        #[arg(long, default_value = "data/normalized/market_bars.csv")]
        bars: PathBuf,
        #[arg(long, default_value = "data/reports/forecast_contract_latest.json")]
        output: PathBuf,
        #[arg(long, default_value = "data/state/prediction_ledger.sqlite3")]
        ledger: PathBuf,
        #[arg(long, default_value_t = true)]
        record_shadow: bool,
    },
    Settle {
        #[arg(long)]
        prediction_id: String,
        #[arg(long)]
        realized_reference_price: f64,
        #[arg(long)]
        realized_log_return: f64,
        #[arg(long, default_value_t = 0.0)]
        realized_mfe: f64,
        #[arg(long, default_value_t = 0.0)]
        realized_mae: f64,
        #[arg(long, default_value_t = 0.0)]
        realized_volatility: f64,
        #[arg(long, default_value = "NEITHER_OR_UNKNOWN")]
        barrier_outcome: String,
        #[arg(long, default_value = "data/state/prediction_ledger.sqlite3")]
        ledger: PathBuf,
    },
    SettlePending {
        #[arg(long, default_value = "data/state/prediction_ledger.sqlite3")]
        ledger: PathBuf,
        #[arg(long, default_value = "data/live/finalized_bars.jsonl")]
        bars: PathBuf,
    },
    Report {
        #[arg(long, default_value = "data/state/prediction_ledger.sqlite3")]
        ledger: PathBuf,
    },
    ShadowStatus {
        #[arg(long, default_value = "data/state/prediction_ledger.sqlite3")]
        ledger: PathBuf,
    },
}

#[derive(Debug, Args)]
struct EstimateArgs {
    #[command(subcommand)]
    command: EstimateCommand,
}

#[derive(Debug, Subcommand)]
enum EstimateCommand {
    Opra {
        #[arg(long, default_value = "SPXW")]
        parent: String,
        #[arg(long)]
        start: NaiveDate,
        #[arg(long)]
        end: NaiveDate,
        #[arg(long)]
        schema: String,
        #[arg(long, value_delimiter = ',', default_value = "0,1")]
        dte: Vec<usize>,
        #[arg(long, default_value = "data/estimates/opra_latest.json")]
        output: PathBuf,
    },
}

fn opra_request(
    parent: &str,
    start: NaiveDate,
    end_inclusive: NaiveDate,
    schema: &str,
) -> Result<axio_quant_engine::config::DataRequest> {
    if end_inclusive < start {
        anyhow::bail!("OPRA estimate end must be on or after start");
    }
    if !matches!(
        schema,
        "definition" | "cbbo-1m" | "cmbp-1" | "tcbbo" | "trades"
    ) {
        anyhow::bail!("unsupported OPRA schema {schema}");
    }
    let end_exclusive = end_inclusive
        .succ_opt()
        .context("OPRA estimate end date overflow")?;
    Ok(axio_quant_engine::config::DataRequest {
        name: format!(
            "opra_{}_{}_{}_{}",
            parent.to_ascii_lowercase(),
            schema.replace('-', "_"),
            start.format("%Y%m%d"),
            end_inclusive.format("%Y%m%d")
        ),
        dataset: "OPRA.PILLAR".to_string(),
        schema: schema.to_string(),
        stype_in: "parent".to_string(),
        symbols: vec![parent.to_string()],
        start: format!("{start}T00:00:00Z"),
        end: format!("{end_exclusive}T00:00:00Z"),
    })
}

const DEFAULT_UNIVERSE_OUTPUT_DIR: &str = "data/models/universe";
const DEFAULT_UNIVERSE_REGISTRY: &str = "data/models/universe/registry.json";

fn resolved_destination(root: &Path, path: &Path, label: &str) -> Result<PathBuf> {
    if path
        .components()
        .any(|component| component == std::path::Component::ParentDir)
    {
        bail!("{label} must not contain parent-directory traversal");
    }
    let mut unresolved = if path.is_absolute() {
        path.to_path_buf()
    } else {
        root.join(path)
    };
    let mut tail = Vec::new();
    while !unresolved.exists() {
        let name = unresolved
            .file_name()
            .with_context(|| format!("{label} has no resolvable ancestor"))?
            .to_os_string();
        tail.push(name);
        unresolved = unresolved
            .parent()
            .with_context(|| format!("{label} has no resolvable ancestor"))?
            .to_path_buf();
    }
    let mut resolved = unresolved
        .canonicalize()
        .with_context(|| format!("resolve {label} {}", unresolved.display()))?;
    for component in tail.into_iter().rev() {
        resolved.push(component);
    }
    Ok(resolved)
}

fn destination_starts_with(path: &Path, base: &Path) -> bool {
    let path_components = path.components().collect::<Vec<_>>();
    let base_components = base.components().collect::<Vec<_>>();
    path_components.len() >= base_components.len()
        && path_components.iter().zip(base_components.iter()).all(
            |(path_component, base_component)| {
                if cfg!(windows) {
                    path_component
                        .as_os_str()
                        .to_string_lossy()
                        .eq_ignore_ascii_case(&base_component.as_os_str().to_string_lossy())
                } else {
                    path_component == base_component
                }
            },
        )
}

fn destinations_equal(left: &Path, right: &Path) -> bool {
    destination_starts_with(left, right) && destination_starts_with(right, left)
}

fn train_universe_destinations(
    root: &Path,
    output_dir: Option<PathBuf>,
    registry: Option<PathBuf>,
    explicit_feature_contract: bool,
) -> Result<(PathBuf, PathBuf)> {
    if !explicit_feature_contract {
        return Ok((
            output_dir.unwrap_or_else(|| PathBuf::from(DEFAULT_UNIVERSE_OUTPUT_DIR)),
            registry.unwrap_or_else(|| PathBuf::from(DEFAULT_UNIVERSE_REGISTRY)),
        ));
    }
    let output_dir = output_dir
        .context("--feature-contract-config requires an explicit separate --output-dir")?;
    let registry =
        registry.context("--feature-contract-config requires an explicit separate --registry")?;
    let output_resolved = resolved_destination(root, &output_dir, "candidate output directory")?;
    let registry_resolved = resolved_destination(root, &registry, "candidate registry")?;
    let production_resolved = resolved_destination(
        root,
        Path::new(DEFAULT_UNIVERSE_OUTPUT_DIR),
        "production universe directory",
    )?;
    if destination_starts_with(&output_resolved, &production_resolved)
        || destination_starts_with(&production_resolved, &output_resolved)
        || destination_starts_with(&registry_resolved, &production_resolved)
    {
        bail!(
            "offline feature candidate outputs must be disjoint from {}",
            DEFAULT_UNIVERSE_OUTPUT_DIR
        );
    }
    if destinations_equal(&registry_resolved, &output_resolved)
        || !destination_starts_with(&registry_resolved, &output_resolved)
    {
        bail!("offline feature candidate --registry must be inside its --output-dir");
    }
    Ok((output_dir, registry))
}

fn write_json(path: &Path, value: &impl serde::Serialize) -> Result<()> {
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }
    std::fs::write(path, serde_json::to_vec_pretty(value)?)?;
    Ok(())
}

fn owner_relay_url(raw: &str) -> Result<reqwest::Url> {
    let url = reqwest::Url::parse(raw).context("parse Moomoo owner forecast relay URL")?;
    let loopback_http = url.scheme() == "http"
        && url
            .host_str()
            .is_some_and(|host| matches!(host, "127.0.0.1" | "::1" | "[::1]" | "localhost"));
    if url.scheme() != "https" && !loopback_http {
        bail!("Moomoo owner forecast relay must use HTTPS (HTTP is allowed only on loopback)");
    }
    if !url.username().is_empty() || url.password().is_some() {
        bail!("Moomoo owner forecast relay URL must not contain credentials");
    }
    Ok(url)
}

async fn publish_owner_forecast(
    publish_url: Option<&str>,
    publish_token_env: &str,
    bundle: &predictor::ForecastBundle,
) -> Result<bool> {
    let Some(raw_url) = publish_url.map(str::trim).filter(|value| !value.is_empty()) else {
        return Ok(false);
    };
    if publish_token_env.is_empty()
        || publish_token_env.len() > 80
        || !publish_token_env
            .chars()
            .all(|value| value.is_ascii_uppercase() || value.is_ascii_digit() || value == '_')
    {
        bail!("publish token environment-variable name is invalid");
    }
    let token = std::env::var(publish_token_env).with_context(|| {
        format!("{publish_token_env} is required when forecast relay is enabled")
    })?;
    if token.len() < 32 {
        bail!("{publish_token_env} must contain at least 32 characters");
    }
    let url = owner_relay_url(raw_url)?;
    let response = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(8))
        .build()?
        .post(url)
        .bearer_auth(token)
        .header(reqwest::header::ACCEPT, "application/json")
        .json(bundle)
        .send()
        .await
        .context("publish owner-only Moomoo forecast")?;
    if !response.status().is_success() {
        let status = response.status();
        let detail = response.text().await.unwrap_or_default();
        bail!(
            "owner-only Moomoo forecast relay rejected HTTP {status}: {}",
            detail.chars().take(240).collect::<String>()
        );
    }
    Ok(true)
}

fn parse_utc_timestamp(value: &str, name: &str) -> Result<DateTime<Utc>> {
    DateTime::parse_from_rfc3339(value)
        .with_context(|| format!("{name} must be an RFC3339 timestamp"))
        .map(|timestamp| timestamp.with_timezone(&Utc))
}

fn massive_option_input_at_cutoff(
    config: &axio_quant_engine::config::MassiveConfig,
    target: &str,
    cutoff: DateTime<Utc>,
    max_age_seconds: i64,
) -> Result<Option<predictor::PointInTimeOptionChainInput>> {
    let canonical = target.trim_start_matches("US.").to_ascii_lowercase();
    let path = config
        .option_chain_output_root
        .join(format!("{canonical}_full_chain_latest.json"));
    if !path.exists() {
        return Ok(None);
    }
    let snapshot: axio_quant_engine::data::massive_live::MassiveFullOptionChain =
        serde_json::from_slice(
            &std::fs::read(&path).with_context(|| format!("read {}", path.display()))?,
        )
        .with_context(|| format!("deserialize {}", path.display()))?;
    if snapshot.schema_version != axio_quant_engine::data::massive_live::OPTION_CHAIN_SCHEMA_VERSION
        || !snapshot.chain_complete
        || !snapshot.model_ready
        || snapshot.captured_at > cutoff
        || cutoff
            .signed_duration_since(snapshot.captured_at)
            .num_seconds()
            > max_age_seconds
    {
        return Ok(None);
    }
    let contracts_bytes = serde_json::to_vec(&snapshot.contracts)?;
    let observed_hash = format!("{:x}", sha2::Sha256::digest(&contracts_bytes));
    if observed_hash != snapshot.contracts_sha256 {
        anyhow::bail!("option chain artifact hash mismatch at {}", path.display());
    }
    let quotes = snapshot
        .contracts
        .iter()
        .filter_map(|contract| contract.as_option_quote())
        .collect::<Vec<_>>();
    if quotes.len() != snapshot.coverage.model_eligible_contracts
        || quotes.len() < config.option_chain_min_eligible_contracts
    {
        anyhow::bail!(
            "option chain eligible subset mismatch at {}: converted={} reported={} required={}",
            path.display(),
            quotes.len(),
            snapshot.coverage.model_eligible_contracts,
            config.option_chain_min_eligible_contracts
        );
    }
    Ok(Some(predictor::PointInTimeOptionChainInput {
        quotes,
        full_chain_complete: true,
        oi_available_at: Some(snapshot.oi_available_at),
        greeks_available_at: Some(snapshot.greeks_available_at),
    }))
}

fn live_forecast_path(base: &Path, target: &str) -> PathBuf {
    let canonical = target.trim_start_matches("US.").to_ascii_lowercase();
    if canonical == "spy" {
        return base.to_path_buf();
    }
    base.parent()
        .unwrap_or_else(|| Path::new("."))
        .join(format!("forecast_contract_live_{canonical}_latest.json"))
}

fn live_inference_status_path(base: &Path, target: &str) -> PathBuf {
    let canonical = target.trim_start_matches("US.").to_ascii_lowercase();
    if canonical == "spy" {
        return base.to_path_buf();
    }
    let stem = base
        .file_stem()
        .and_then(OsStr::to_str)
        .unwrap_or("live_inference_status");
    base.parent()
        .unwrap_or_else(|| Path::new("."))
        .join(format!("{stem}_{canonical}.json"))
}

struct MassiveTargetRuntime {
    research: axio_quant_engine::config::ResearchConfig,
    artifact: predictor::FrozenPredictorArtifact,
    feature_engine: features::IncrementalFeatureEngine,
    target_events: HashMap<i64, axio_quant_engine::data::massive_live::RealtimeMarketBarEnvelope>,
}

fn quote_bridge_command(
    bridge: &Path,
    python_executable: &OsStr,
    host: &str,
    port: u16,
    symbols: &[String],
) -> Result<ProcessCommand> {
    let is_python = bridge
        .extension()
        .and_then(OsStr::to_str)
        .is_some_and(|extension| extension.eq_ignore_ascii_case("py"));
    if !is_python {
        let mut command = ProcessCommand::new(bridge);
        command.arg("QuotePush");
        return Ok(command);
    }
    if symbols.is_empty()
        || symbols.iter().any(|symbol| {
            !symbol.starts_with("US.")
                || symbol.len() <= 3
                || symbol.contains(',')
                || symbol.chars().any(char::is_whitespace)
        })
    {
        anyhow::bail!("Python Moomoo bridge requires a valid non-empty US symbol list");
    }
    let mut command = ProcessCommand::new(python_executable);
    command
        .arg(bridge)
        .arg("QuotePush")
        .arg("--host")
        .arg(host)
        .arg("--port")
        .arg(port.to_string())
        .arg("--symbols")
        .arg(symbols.join(","));
    Ok(command)
}

fn build_forecast_bundle(
    bars: &Path,
    config: &AppConfig,
) -> Result<axio_quant_engine::predictor::ForecastBundle> {
    let imported = MarketBarCsvImporter.import(bars)?;
    let states =
        features::build_states(&imported.records, &config.research.target, &config.research)?;
    let capability = capability::inspect(&config.data)?;
    predictor::forecast(
        &states,
        &config.research,
        &config.os,
        &capability,
        Utc::now(),
    )
}

fn persist_canonical_predictions(
    ledger: &PredictionLedger,
    bundle: &mut predictor::ForecastBundle,
) -> Result<()> {
    for contract in &mut bundle.prediction_layer {
        *contract = ledger.append_prediction(contract)?;
    }
    if let Some(created_at) = bundle
        .prediction_layer
        .iter()
        .map(|contract| contract.created_at)
        .min()
    {
        bundle.generated_at = created_at;
    }
    Ok(())
}

const TVTP_COVARIATE_SCHEMA: [&str; 5] = [
    "rolling_realized_vol",
    "volume_zscore",
    "cross_asset_breadth_score",
    "risk_rotation_score",
    "normalized_session_phase",
];
const TVTP_MINIMUM_VALIDATION_IMPROVEMENT_PER_OBSERVATION: f64 = 0.0;
const TVTP_FROZEN_ONE_STEP_ASSUMPTION: &str =
    "FROZEN_CURRENT_FINALIZED_COVARIATE_FOR_ONE_STEP; NO_FUTURE_COVARIATE_OBSERVED";

#[derive(Debug, Clone, PartialEq)]
struct TvtpAlignedSession {
    date: NaiveDate,
    observations: Vec<Vec<f64>>,
    covariates: Vec<Vec<f64>>,
    as_of: Vec<DateTime<Utc>>,
}

#[derive(Debug, Clone, PartialEq)]
struct TvtpAlignedSequences {
    dates: Vec<NaiveDate>,
    observations: Vec<Vec<Vec<f64>>>,
    covariates: Vec<Vec<Vec<f64>>>,
    as_of: Vec<Vec<DateTime<Utc>>>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
struct TvtpChallengerConfig {
    fit_end: usize,
    use_validation: bool,
    selected_states: usize,
    hmm_iterations: usize,
    hmm_restarts: usize,
}

#[derive(Debug)]
struct FoldHmmSelection {
    model: GaussianHmm,
    selected_states: usize,
    candidate_scores: Vec<HmmCandidateAssessment>,
    selection_method: &'static str,
    validation_used_for_selection: bool,
    validation_sessions: usize,
}

#[derive(Debug, Clone, Copy, PartialEq)]
struct HmmOccupancyPolicy {
    minimum_fraction: f64,
    minimum_expected_observations: f64,
}

/// Select K without ever accepting the chronological test partition as input.
///
/// Candidate parameters are fitted on `train` only. When there are enough
/// validation sessions, K is selected by fixed-parameter validation likelihood;
/// otherwise train BIC is the explicit fallback. The returned model is the
/// selected train-fitted candidate and is not refitted on validation data.
fn select_hmm_within_forward_fold(
    train: &[Vec<Vec<f64>>],
    validation: &[Vec<Vec<f64>>],
    candidates: &[usize],
    minimum_validation_sessions: usize,
    iterations: usize,
    restarts: usize,
    occupancy_policy: HmmOccupancyPolicy,
) -> Result<FoldHmmSelection> {
    if train.iter().all(Vec::is_empty) {
        bail!("forward-fold HMM selection requires non-empty train observations");
    }
    if candidates.is_empty() {
        bail!("forward-fold HMM selection requires at least one K candidate");
    }

    let validation_sessions = validation
        .iter()
        .filter(|sequence| !sequence.is_empty())
        .count();
    let validation_used_for_selection = validation_sessions >= minimum_validation_sessions.max(1);
    let selection = select_hmm_candidates(
        train,
        validation_used_for_selection.then_some(validation),
        candidates,
        iterations,
        restarts,
        occupancy_policy.minimum_fraction,
        occupancy_policy.minimum_expected_observations,
    )?;
    let selected_states = selection.selected_state_count;
    let selection_method = selection.selection_method;
    let candidate_scores = selection.candidate_assessments;
    let (model, _) = selection.model.canonicalized();
    Ok(FoldHmmSelection {
        model,
        selected_states,
        candidate_scores,
        selection_method,
        validation_used_for_selection,
        validation_sessions,
    })
}

fn finalized_tvtp_sequences(states: &[MarketState]) -> Result<TvtpAlignedSequences> {
    let mut sessions = BTreeMap::<NaiveDate, TvtpAlignedSession>::new();
    let mut previous_finalized: Option<(NaiveDate, DateTime<Utc>)> = None;

    for state in states
        .iter()
        .filter(|state| state.minute_in_5m_bucket == 4 && state.completed_5m_bucket_valid)
    {
        if state.timestamp.with_timezone(&New_York).date_naive() != state.session_date {
            bail!("TVTP finalized state session date does not match its exchange timestamp");
        }
        if !(0..=390).contains(&state.minutes_from_open) {
            bail!("TVTP session phase is outside the regular-session clock");
        }
        if let Some((previous_date, previous_timestamp)) = previous_finalized {
            if state.timestamp <= previous_timestamp {
                bail!("TVTP finalized observations must be strictly chronological");
            }
            if state.session_date == previous_date
                && state.timestamp - previous_timestamp != Duration::minutes(5)
            {
                bail!("TVTP refuses to infer a one-step transition across a missing 5m bucket");
            }
        }

        let observation = vec![
            state.active_5m_return,
            state.dist_vwap,
            state.rolling_realized_vol,
            state.volume_zscore,
        ];
        let covariate = vec![
            state.rolling_realized_vol,
            state.volume_zscore,
            state.cross_asset_breadth_score,
            state.risk_rotation_score,
            state.minutes_from_open as f64 / 390.0,
        ];
        if observation.iter().any(|value| !value.is_finite())
            || covariate.iter().any(|value| !value.is_finite())
        {
            bail!("TVTP finalized observations and covariates must be finite");
        }

        let as_of = state.timestamp + Duration::minutes(1);
        let session = sessions
            .entry(state.session_date)
            .or_insert_with(|| TvtpAlignedSession {
                date: state.session_date,
                observations: Vec::new(),
                covariates: Vec::new(),
                as_of: Vec::new(),
            });
        session.observations.push(observation);
        session.covariates.push(covariate);
        session.as_of.push(as_of);
        previous_finalized = Some((state.session_date, state.timestamp));
    }

    if sessions.is_empty() {
        bail!("TVTP requires finalized five-minute observations");
    }
    if sessions.values().any(|session| {
        session.observations.is_empty()
            || session.observations.len() != session.covariates.len()
            || session.observations.len() != session.as_of.len()
    }) {
        bail!("TVTP observation, covariate, and availability sequences are not index aligned");
    }

    let sessions = sessions.into_values().collect::<Vec<_>>();
    Ok(TvtpAlignedSequences {
        dates: sessions.iter().map(|session| session.date).collect(),
        observations: sessions
            .iter()
            .map(|session| session.observations.clone())
            .collect(),
        covariates: sessions
            .iter()
            .map(|session| session.covariates.clone())
            .collect(),
        as_of: sessions
            .iter()
            .map(|session| session.as_of.clone())
            .collect(),
    })
}

fn tvtp_unavailable_report(
    validation_flags: Vec<String>,
    error: Option<String>,
) -> serde_json::Value {
    serde_json::json!({
        "model": "non_homogeneous_diagonal_gaussian_hmm_tvtp",
        "status": "UNAVAILABLE",
        "availability": "UNAVAILABLE",
        "role": "SHADOW_CHALLENGER_ONLY",
        "decision_policy_impact": "NONE",
        "covariate_schema": TVTP_COVARIATE_SCHEMA,
        "covariate_alignment": "FINALIZED_5M_Z_T_INDEX_ALIGNED_WITH_X_T; Z_T_EXPLAINS_T_TO_T_PLUS_1",
        "validation": {
            "criterion": "CHRONOLOGICAL_HELD_OUT_PREQUENTIAL_AVERAGE_LOG_LIKELIHOOD",
            "homogeneous_average_log_likelihood": serde_json::Value::Null,
            "tvtp_average_log_likelihood": serde_json::Value::Null,
            "improvement_per_observation": serde_json::Value::Null,
            "minimum_required_improvement_per_observation": TVTP_MINIMUM_VALIDATION_IMPROVEMENT_PER_OBSERVATION,
            "selected_for_shadow": false,
            "flags": validation_flags,
        },
        "fit": {
            "row_effective_transition_weight": serde_json::Value::Null,
            "covariate_center": serde_json::Value::Null,
            "covariate_scale": serde_json::Value::Null,
        },
        "current_session": {
            "status": "UNAVAILABLE",
            "online_ood": serde_json::Value::Null,
            "maximum_absolute_covariate_zscore": serde_json::Value::Null,
            "online_validation_flags": ["TVTP_CURRENT_FILTER_NOT_RUN"],
            "current_filtered_probability": serde_json::Value::Null,
            "one_step_state_probability": serde_json::Value::Null,
            "one_step_transition_covariate_assumption": "NOT_EVALUATED",
        },
        "error": error,
    })
}

fn tvtp_challenger_report(
    market_states: &[MarketState],
    expected_dates: &[NaiveDate],
    prior_emission_model: &GaussianHmm,
    config: TvtpChallengerConfig,
) -> Result<serde_json::Value> {
    let aligned = finalized_tvtp_sequences(market_states)?;
    if aligned.dates != expected_dates {
        bail!("TVTP session alignment differs from the homogeneous HMM session sequence");
    }
    let prior_session_count = aligned.observations.len().saturating_sub(1);
    if !config.use_validation
        || config.fit_end == 0
        || config.fit_end >= prior_session_count
        || aligned.observations.len() < 2
    {
        return Ok(tvtp_unavailable_report(
            vec!["TVTP_CHRONOLOGICAL_VALIDATION_SPLIT_UNAVAILABLE".into()],
            None,
        ));
    }

    let fit_observations = &aligned.observations[..config.fit_end];
    let fit_covariates = &aligned.covariates[..config.fit_end];
    let validation_observations = &aligned.observations[config.fit_end..prior_session_count];
    let validation_covariates = &aligned.covariates[config.fit_end..prior_session_count];
    let fit_config = TvtpFitConfig {
        max_iterations: config.hmm_iterations.max(1),
        ..TvtpFitConfig::default()
    };
    let validation_emission_model = GaussianHmm::fit(
        fit_observations,
        config.selected_states,
        config.hmm_iterations,
        config.hmm_restarts,
    )?;
    let (validation_emission_model, _) = validation_emission_model.canonicalized();
    let validation_challenger = NonHomogeneousGaussianHmm::fit(
        validation_emission_model,
        fit_observations,
        fit_covariates,
        fit_config.clone(),
    )?;
    let comparison = validation_challenger.validation_comparison(
        validation_observations,
        validation_covariates,
        TVTP_MINIMUM_VALIDATION_IMPROVEMENT_PER_OBSERVATION,
    );

    let validation = serde_json::json!({
        "criterion": "CHRONOLOGICAL_HELD_OUT_PREQUENTIAL_AVERAGE_LOG_LIKELIHOOD",
        "fit_sessions": config.fit_end,
        "validation_sessions": validation_observations.len(),
        "homogeneous_average_log_likelihood": comparison.homogeneous_average_log_likelihood,
        "tvtp_average_log_likelihood": comparison.tvtp_average_log_likelihood,
        "improvement_per_observation": comparison.improvement_per_observation,
        "minimum_required_improvement_per_observation": TVTP_MINIMUM_VALIDATION_IMPROVEMENT_PER_OBSERVATION,
        "selected_for_shadow": comparison.selected_for_shadow,
        "flags": comparison.validation_flags,
        "selection_semantics": comparison.selection_semantics,
    });
    let validation_fit = serde_json::json!({
        "row_effective_transition_weight": validation_challenger.row_effective_transition_weight,
        "covariate_center": validation_challenger.covariate_center,
        "covariate_scale": validation_challenger.covariate_scale,
        "training_cross_entropy": validation_challenger.training_cross_entropy,
        "training_iterations": validation_challenger.training_iterations,
        "fit_config": validation_challenger.fit_config,
    });

    if !comparison.selected_for_shadow {
        return Ok(serde_json::json!({
            "model": "non_homogeneous_diagonal_gaussian_hmm_tvtp",
            "status": "VALIDATION_REJECTED",
            "availability": "AVAILABLE",
            "role": "SHADOW_CHALLENGER_ONLY",
            "decision_policy_impact": "NONE",
            "covariate_schema": TVTP_COVARIATE_SCHEMA,
            "covariate_alignment": "FINALIZED_5M_Z_T_INDEX_ALIGNED_WITH_X_T; Z_T_EXPLAINS_T_TO_T_PLUS_1",
            "validation": validation,
            "fit": validation_fit,
            "current_session": {
                "status": "NOT_RUN_VALIDATION_REJECTED",
                "online_ood": serde_json::Value::Null,
                "maximum_absolute_covariate_zscore": serde_json::Value::Null,
                "online_validation_flags": ["TVTP_CURRENT_FILTER_NOT_RUN_VALIDATION_REJECTED"],
                "current_filtered_probability": serde_json::Value::Null,
                "one_step_state_probability": serde_json::Value::Null,
                "one_step_transition_covariate_assumption": "NOT_EVALUATED",
            },
            "error": serde_json::Value::Null,
        }));
    }

    let prior_observations = &aligned.observations[..prior_session_count];
    let prior_covariates = &aligned.covariates[..prior_session_count];
    let current_observations = &aligned.observations[prior_session_count];
    let current_covariates = &aligned.covariates[prior_session_count];
    let current_as_of = aligned.as_of[prior_session_count]
        .last()
        .copied()
        .context("TVTP current session has no finalized availability timestamp")?;

    let current_evaluation = (|| -> Result<serde_json::Value> {
        let challenger = NonHomogeneousGaussianHmm::fit(
            prior_emission_model.clone(),
            prior_observations,
            prior_covariates,
            fit_config,
        )?;
        let filtered = challenger.filter(current_observations, current_covariates)?;
        let current_probability = filtered
            .filtered_probabilities
            .last()
            .context("TVTP current-session filter returned no probability")?;
        let frozen_current_covariate = current_covariates
            .last()
            .context("TVTP current session has no transition covariate")?;
        let one_step_probability = challenger.horizon_state_probabilities(
            current_probability,
            std::slice::from_ref(frozen_current_covariate),
        )?;
        let mut online_flags = challenger.online_validation_flags(frozen_current_covariate);
        if filtered.maximum_absolute_covariate_zscore
            > challenger.fit_config.maximum_online_covariate_zscore
            && !online_flags
                .iter()
                .any(|flag| flag == "NH_HMM_TRANSITION_COVARIATE_OOD")
        {
            online_flags.push("NH_HMM_TRANSITION_COVARIATE_OOD".into());
        }
        online_flags.sort();
        online_flags.dedup();
        let online_ood = online_flags
            .iter()
            .any(|flag| flag == "NH_HMM_TRANSITION_COVARIATE_OOD");
        Ok(serde_json::json!({
            "status": if online_flags.is_empty() { "SHADOW_FILTERED" } else { "SHADOW_FILTERED_WITH_FLAGS" },
            "availability": "AVAILABLE",
            "as_of": current_as_of,
            "online_ood": online_ood,
            "maximum_absolute_covariate_zscore": filtered.maximum_absolute_covariate_zscore,
            "maximum_allowed_covariate_zscore": challenger.fit_config.maximum_online_covariate_zscore,
            "online_validation_flags": online_flags,
            "current_filtered_probability": current_probability,
            "one_step_state_probability": one_step_probability,
            "one_step_transition_covariate_assumption": TVTP_FROZEN_ONE_STEP_ASSUMPTION,
            "probability_semantics": filtered.probability_semantics,
            "current_session_log_likelihood": filtered.log_likelihood,
            "row_effective_transition_weight_after_prior_refit": challenger.row_effective_transition_weight,
            "covariate_center_after_prior_refit": challenger.covariate_center,
            "covariate_scale_after_prior_refit": challenger.covariate_scale,
            "trained_through": aligned.dates.get(prior_session_count.saturating_sub(1)),
            "current_session": aligned.dates.last(),
        }))
    })();
    let (current_session, current_available) = match current_evaluation {
        Ok(report) => (report, true),
        Err(error) => (
            serde_json::json!({
                "status": "UNAVAILABLE",
                "availability": "UNAVAILABLE",
                "as_of": current_as_of,
                "online_ood": serde_json::Value::Null,
                "maximum_absolute_covariate_zscore": serde_json::Value::Null,
                "online_validation_flags": ["TVTP_PRIOR_REFIT_OR_CURRENT_FILTER_FAILED"],
                "current_filtered_probability": serde_json::Value::Null,
                "one_step_state_probability": serde_json::Value::Null,
                "one_step_transition_covariate_assumption": "NOT_EVALUATED",
                "error": error.to_string(),
            }),
            false,
        ),
    };

    Ok(serde_json::json!({
        "model": "non_homogeneous_diagonal_gaussian_hmm_tvtp",
        "status": if current_available { "SHADOW_SELECTED" } else { "SHADOW_SELECTED_CURRENT_FILTER_UNAVAILABLE" },
        "availability": if current_available { "AVAILABLE" } else { "PARTIAL" },
        "role": "SHADOW_CHALLENGER_ONLY",
        "decision_policy_impact": "NONE",
        "covariate_schema": TVTP_COVARIATE_SCHEMA,
        "covariate_alignment": "FINALIZED_5M_Z_T_INDEX_ALIGNED_WITH_X_T; Z_T_EXPLAINS_T_TO_T_PLUS_1",
        "validation": validation,
        "fit": validation_fit,
        "current_session": current_session,
        "error": serde_json::Value::Null,
    }))
}

#[derive(Debug, Args)]
struct ResearchArgs {
    #[command(subcommand)]
    command: ResearchCommand,
}

#[derive(Debug, Subcommand)]
enum ResearchCommand {
    Backtest {
        #[arg(long)]
        bars: PathBuf,
        #[arg(long, default_value = "data/reports/latest.json")]
        output: PathBuf,
    },
    /// End-to-end real-data path: sync Massive -> normalize/dedupe -> model/backtest.
    MassiveRun {
        #[arg(long)]
        from: NaiveDate,
        #[arg(long)]
        to: NaiveDate,
        #[arg(long, value_delimiter = ',')]
        symbols: Vec<String>,
        #[arg(long, default_value = "data/normalized/market_bars.csv")]
        bars: PathBuf,
        #[arg(long, default_value = "data/reports/massive_latest.json")]
        output: PathBuf,
    },
    /// Fit a causal diagonal-Gaussian HMM on finalized five-minute states.
    RegimeFit {
        #[arg(long)]
        bars: PathBuf,
        /// Optional fixed-K diagnostic retained for reproducibility. When
        /// omitted, chronological model selection evaluates all candidates.
        #[arg(long)]
        states: Option<usize>,
        #[arg(
            long,
            value_delimiter = ',',
            default_value = "2,3,4,5,6,7,8,9,10,11,12"
        )]
        state_candidates: Vec<usize>,
        #[arg(long, default_value_t = 40)]
        iterations: usize,
        #[arg(long, default_value_t = 3)]
        restarts: usize,
        #[arg(long, default_value = "data/reports/regime_latest.json")]
        output: PathBuf,
    },
    Ablation {
        #[arg(long, default_value = "data/normalized/market_bars.csv")]
        bars: PathBuf,
        #[arg(long, default_value_t = 30)]
        horizon: usize,
        #[arg(long, default_value = "data/reports/ablation_latest.json")]
        output: PathBuf,
    },
    NegativeControls {
        #[arg(long, default_value = "data/normalized/market_bars.csv")]
        bars: PathBuf,
        #[arg(long, default_value_t = 30)]
        horizon: usize,
        #[arg(long, default_value = "data/reports/negative_controls_latest.json")]
        output: PathBuf,
    },
    /// Mine repeated return-path motifs, control the full hypothesis family,
    /// and associate surviving research candidates with shadow-only strategies.
    PatternDiscover {
        #[arg(long, default_value = "data/normalized/market_bars.csv")]
        bars: PathBuf,
        #[arg(long, default_value_t = 15)]
        horizon: usize,
        #[arg(long, value_delimiter = ',', default_value = "3,5,10,15,30,60")]
        windows: Vec<usize>,
        #[arg(long, default_value_t = 3)]
        maximum_candidates_per_window: usize,
        #[arg(long, default_value = "data/reports/pattern_factory_latest.json")]
        output: PathBuf,
    },
}

fn find_request<'a>(
    config: &'a AppConfig,
    name: &str,
) -> Result<&'a axio_quant_engine::config::DataRequest> {
    config
        .data
        .databento
        .requests
        .iter()
        .find(|request| request.name == name)
        .with_context(|| format!("Databento request `{name}` is not configured"))
}

async fn control_get(base_url: &str, path: &str) -> Result<serde_json::Value> {
    let token = std::env::var("INTRADAY_QUANT_TOKEN")
        .context("INTRADAY_QUANT_TOKEN is required to read the local control plane")?;
    if token.len() < 32 {
        anyhow::bail!("INTRADAY_QUANT_TOKEN must contain at least 32 characters");
    }
    let base = reqwest::Url::parse(base_url).context("invalid quant control URL")?;
    let host = base.host_str().context("quant control URL has no host")?;
    let ip: std::net::IpAddr = host
        .parse()
        .context("quant control URL must use a numeric loopback host")?;
    if base.scheme() != "http" || !ip.is_loopback() {
        anyhow::bail!("quant control URL must use HTTP on a numeric loopback host");
    }
    let response = reqwest::Client::builder()
        .connect_timeout(std::time::Duration::from_secs(2))
        .timeout(std::time::Duration::from_secs(8))
        .build()?
        .get(format!("{}{}", base_url.trim_end_matches('/'), path))
        .header("x-research-token", token)
        .header("accept", "application/json")
        .send()
        .await?;
    let status = response.status();
    let bytes = response.bytes().await?;
    if !status.is_success() {
        anyhow::bail!(
            "quant control plane returned {}: {}",
            status,
            String::from_utf8_lossy(&bytes)
        );
    }
    serde_json::from_slice(&bytes).context("invalid quant control response")
}

async fn execute_broker_once(
    config: &AppConfig,
    control_url: &str,
    forecast_path: &Path,
    execute: bool,
    confirm_live_account: Option<u64>,
) -> Result<bool> {
    if !config.execution.enabled {
        anyhow::bail!("broker execution is disabled in configuration");
    }
    let (allocation_value, system_value, risk_value) = tokio::try_join!(
        control_get(control_url, "/api/v1/allocation/betting"),
        control_get(control_url, "/api/v1/system/status"),
        control_get(control_url, "/api/v1/risk"),
    )?;
    if allocation_value
        .get("status")
        .and_then(serde_json::Value::as_str)
        != Some("TARGET_PROPOSED")
    {
        println!(
            "{}",
            serde_json::to_string_pretty(&serde_json::json!({
                "status":"NO_TRADE",
                "stage":"ALLOCATION",
                "allocation":allocation_value
            }))?
        );
        return Ok(false);
    }
    let allocation: axio_quant_engine::allocation::BettingDecision =
        serde_json::from_value(allocation_value).context("invalid allocation decision")?;
    let runtime: axio_quant_engine::os::RuntimeStatus = serde_json::from_value(
        system_value
            .get("runtime")
            .cloned()
            .context("control response omitted runtime status")?,
    )?;
    let risk: axio_quant_engine::os::RiskStatus = serde_json::from_value(risk_value)?;
    let bytes = std::fs::read(forecast_path)
        .with_context(|| format!("cannot read forecast {}", forecast_path.display()))?;
    let bundle: axio_quant_engine::predictor::ForecastBundle =
        serde_json::from_slice(&bytes).context("invalid forecast bundle")?;
    let forecast = bundle
        .prediction_layer
        .iter()
        .find(|row| {
            row.horizon_minutes as u32 == allocation.horizon_minutes
                && row.decision_as_of == allocation.forecast_as_of
                && row
                    .symbol
                    .trim_start_matches("US.")
                    .eq_ignore_ascii_case(allocation.symbol.trim_start_matches("US."))
        })
        .context("allocation does not match exactly one current forecast")?;

    let client = MoomooBrokerClient::from_config(&config.execution)?;
    let health = client.health().await?;
    if health.mode != config.execution.mode {
        anyhow::bail!("broker gateway mode does not match execution config");
    }
    let snapshot = client.snapshot().await?;
    snapshot.validate(&config.execution, Utc::now())?;
    let store = ExecutionStore::open(&config.execution.oms_path)?;
    store.reconcile(&snapshot)?;
    let plan = plan_order(
        &allocation,
        forecast,
        &snapshot,
        &runtime,
        &risk,
        &config.execution,
        Utc::now(),
    );
    if !plan.approved {
        println!(
            "{}",
            serde_json::to_string_pretty(&serde_json::json!({
                "status":"NO_TRADE",
                "stage":"EXECUTION_RISK",
                "plan":plan
            }))?
        );
        return Ok(false);
    }
    let intent = plan
        .intent
        .context("approved execution plan omitted intent")?;
    store.record_intent(
        &intent,
        if execute {
            "SUBMISSION_PENDING"
        } else {
            "DRY_RUN_APPROVED"
        },
    )?;
    if !execute {
        println!(
            "{}",
            serde_json::to_string_pretty(&serde_json::json!({
                "status":"DRY_RUN_APPROVED",
                "broker":health,
                "intent":intent,
                "truth":"No broker order was sent; rerun with --execute only after reviewing the intent"
            }))?
        );
        return Ok(false);
    }
    if config.execution.mode == "real"
        && (confirm_live_account.is_none()
            || confirm_live_account != config.execution.account_id
            || confirm_live_account != Some(health.account_id))
    {
        store.record_rejection(&intent, "LIVE_ACCOUNT_CONFIRMATION_MISMATCH")?;
        anyhow::bail!(
            "real order requires --confirm-live-account matching the pinned gateway account"
        );
    }
    let response = match client.place_order(&intent.order).await {
        Ok(response) => response,
        Err(error) => {
            store.record_submission_unknown(&intent.client_order_id, &error.to_string())?;
            return Err(error)
                .context("broker submission outcome is unknown; reconcile before any retry");
        }
    };
    store.record_submission(&intent.client_order_id, &response)?;
    let settled_snapshot = client.snapshot().await?;
    settled_snapshot.validate(&config.execution, Utc::now())?;
    store.reconcile(&settled_snapshot)?;
    println!(
        "{}",
        serde_json::to_string_pretty(&serde_json::json!({
            "status":"BROKER_ORDER_ACCEPTED",
            "mode":config.execution.mode,
            "intent":intent,
            "response":response,
            "snapshot_id":settled_snapshot.snapshot_id
        }))?
    );
    Ok(true)
}

fn main() -> Result<()> {
    // The generated Clap command graph is intentionally large. Windows gives
    // the process main thread a comparatively small stack, which caused even
    // `quantctl --help` to overflow before parsing. Run the unchanged async
    // entrypoint on an explicitly bounded, larger stack.
    std::thread::Builder::new()
        .name("quantctl-runtime".to_string())
        .stack_size(8 * 1024 * 1024)
        .spawn(run)?
        .join()
        .map_err(|_| anyhow::anyhow!("quantctl runtime thread panicked"))?
}

#[tokio::main]
async fn run() -> Result<()> {
    axio_quant_engine::install_tls_crypto_provider();
    let _ = dotenvy::from_filename("../.env.local");
    let _ = dotenvy::dotenv();
    let cli = Cli::parse();
    let config = AppConfig::load(&cli.config)?;
    match cli.command {
        Command::Data(args) => match args.command {
            DataCommand::Plan => {
                println!(
                    "{}",
                    serde_json::to_string_pretty(&serde_json::json!({
                        "databento": config.data.databento.requests,
                        "cboe": config.data.cboe,
                        "broker": config.data.broker,
                        "guard": "cost must be estimated and explicitly capped before download"
                    }))?
                );
            }
            DataCommand::Capability { output } => {
                let report = capability::inspect(&config.data)?;
                let audit = capability::capability_audit(&config.data)?;
                let payload = serde_json::json!({"data":report,"capability_audit":audit,"report_hash":capability::report_hash(&report)?});
                write_json(&output, &payload)?;
                println!("{}", serde_json::to_string_pretty(&payload)?);
            }
            DataCommand::Doctor { output } => {
                let report = axio_quant_engine::data::readiness::doctor(&config.data)?;
                write_json(&output, &report)?;
                println!("{}", serde_json::to_string_pretty(&report)?);
                eprintln!("doctor_report={}", output.display());
            }
            DataCommand::Estimate(args) => match args.command {
                EstimateCommand::Opra {
                    parent,
                    start,
                    end,
                    schema,
                    dte,
                    output,
                } => {
                    let request = opra_request(&parent, start, end, &schema)?;
                    if std::env::var_os("DATABENTO_API_KEY").is_none() {
                        let blocked = serde_json::json!({
                            "status": "DATA_SOURCE_NOT_CONFIGURED",
                            "missing_credential": "DATABENTO_API_KEY",
                            "provider": "Databento",
                            "dataset": "OPRA.PILLAR",
                            "parent": parent,
                            "requested_schema": schema,
                            "requested_dte": dte,
                            "selected_dates": {"start": start, "end_inclusive": end},
                            "estimated_records": null,
                            "estimated_bytes": null,
                            "estimated_vendor_charge_usd": null,
                            "download_started": false,
                            "warning": "Parent-wide estimate is an upper bound. Resolve point-in-time definitions before producing a 0/1DTE raw-symbol estimate. No data was downloaded."
                        });
                        write_json(&output, &blocked)?;
                        println!("{}", serde_json::to_string_pretty(&blocked)?);
                    } else {
                        let estimate = databento::estimate_cost(&request).await?;
                        let report = serde_json::json!({
                            "status": "ESTIMATE_COMPLETE_AWAITING_CONFIRMATION",
                            "provider": "Databento",
                            "dataset": "OPRA.PILLAR",
                            "parent": parent,
                            "requested_dte": dte,
                            "estimate": estimate,
                            "download_started": false,
                            "warning": "Parent-wide estimate may include expirations outside 0/1DTE. Download definitions first, resolve raw symbols point-in-time, then recalculate the quote estimate."
                        });
                        write_json(&output, &report)?;
                        println!("{}", serde_json::to_string_pretty(&report)?);
                    }
                    eprintln!("estimate_report={}", output.display());
                }
            },
            DataCommand::SamplePlan {
                bars,
                event_date,
                strike_window_pct,
                output,
            } => {
                let plan = axio_quant_engine::data::sample_plan::build_five_day_plan(
                    &bars,
                    event_date,
                    strike_window_pct,
                )?;
                write_json(&output, &plan)?;
                println!("{}", serde_json::to_string_pretty(&plan)?);
                eprintln!("sample_plan={}", output.display());
            }
            DataCommand::OpraSample {
                dates,
                parent,
                schemas,
                confirm_download,
                maximum_cost_usd,
            } => {
                if dates.len() != 5 {
                    anyhow::bail!("OPRA sample requires exactly five explicit trading dates");
                }
                if !confirm_download {
                    anyhow::bail!(
                        "download refused: estimate first, then pass --confirm-download and --maximum-cost-usd"
                    );
                }
                if maximum_cost_usd <= 0.0 {
                    anyhow::bail!("--maximum-cost-usd must be positive");
                }
                if std::env::var_os("DATABENTO_API_KEY").is_none() {
                    anyhow::bail!("DATA_SOURCE_NOT_CONFIGURED: missing DATABENTO_API_KEY");
                }
                let mut requests = Vec::new();
                for date in &dates {
                    for schema in &schemas {
                        requests.push(opra_request(&parent, *date, *date, schema)?);
                    }
                }
                let mut estimates = Vec::new();
                for request in &requests {
                    estimates.push(databento::estimate_cost(request).await?);
                }
                let total = estimates
                    .iter()
                    .map(|row| row.estimated_cost_usd)
                    .sum::<f64>();
                if total > maximum_cost_usd {
                    anyhow::bail!(
                        "estimated sample cost ${total:.2} exceeds --maximum-cost-usd ${maximum_cost_usd:.2}; nothing downloaded"
                    );
                }
                let mut receipts = Vec::new();
                for request in &requests {
                    receipts.push(
                        databento::download(&config.data, request, true, maximum_cost_usd).await?,
                    );
                }
                println!(
                    "{}",
                    serde_json::to_string_pretty(&serde_json::json!({
                        "status": "SAMPLE_DOWNLOADED_REQUIRES_NORMALIZATION_AND_VALIDATION",
                        "dates": dates,
                        "schemas": schemas,
                        "estimated_total_cost_usd": total,
                        "receipts": receipts
                    }))?
                );
            }
            DataCommand::ValidateSpxw => {
                let report = axio_quant_engine::data::readiness::doctor(&config.data)?;
                println!("{}", serde_json::to_string_pretty(&report.readiness)?);
                if report.readiness.status != "SPXW_BACKTEST_READY" {
                    anyhow::bail!(
                        "SPXW_BACKTEST_BLOCKED: {}",
                        report.readiness.missing_requirements.join(",")
                    );
                }
            }
            DataCommand::Coverage | DataCommand::Lineage => {
                let report = axio_quant_engine::data::readiness::doctor(&config.data)?;
                println!("{}", serde_json::to_string_pretty(&report)?);
            }
            DataCommand::Cost { request } => {
                let estimate = databento::estimate_cost(find_request(&config, &request)?).await?;
                println!("{}", serde_json::to_string_pretty(&estimate)?);
            }
            DataCommand::Download {
                request,
                confirm_cost,
                maximum_cost_usd,
            } => {
                let receipt = databento::download(
                    &config.data,
                    find_request(&config, &request)?,
                    confirm_cost,
                    maximum_cost_usd,
                )
                .await?;
                println!("{}", serde_json::to_string_pretty(&receipt)?);
            }
            DataCommand::ValidateBars { input } => {
                let report = MarketBarCsvImporter.import(&input)?;
                println!(
                    "{}",
                    serde_json::to_string_pretty(&serde_json::json!({
                        "input_rows": report.input_rows, "accepted_rows": report.accepted_rows,
                        "duplicate_rows": report.duplicate_rows, "rejected_rows": report.rejected_rows,
                        "first": report.records.first().map(|r| r.timestamp),
                        "last": report.records.last().map(|r| r.timestamp),
                    }))?
                );
            }
            DataCommand::ValidateMarketDataRights {
                data_root,
                provider,
                product,
                receipt_sha256,
                at,
            } => {
                let now = at
                    .as_deref()
                    .map(DateTime::parse_from_rfc3339)
                    .transpose()
                    .context("--at must be RFC3339")?
                    .map(|value| value.with_timezone(&Utc))
                    .unwrap_or_else(Utc::now);
                let receipt =
                    axio_quant_engine::production_readiness::validate_pinned_market_data_rights_receipt(
                        &data_root,
                        &provider,
                        &product,
                        now,
                        &receipt_sha256,
                    );
                println!("{}", serde_json::to_string_pretty(&receipt)?);
                if receipt.status
                    != axio_quant_engine::production_readiness::MarketDataRightsStatus::Ready
                {
                    bail!("MARKET_DATA_RIGHTS_VALIDATION_{}", receipt.reason.code());
                }
            }
            DataCommand::SealTrainingLineage {
                bars,
                sources,
                provider,
                product,
                adjustment_status,
                output,
            } => {
                let request = SealTrainingLineageRequest {
                    bars: bars
                        .unwrap_or_else(|| config.data.normalized_root.join("market_bars.csv")),
                    raw_sources: sources,
                    provider,
                    product,
                    adjustment_status: AdjustmentStatus::from_cli(&adjustment_status)?,
                    output_manifest: output,
                };
                let receipt = training_lineage::seal_training_lineage(&config.data, &request)?;
                println!("{}", serde_json::to_string_pretty(&receipt)?);
            }
            DataCommand::MaterializeBars {
                input,
                database,
                provider,
                dataset,
                captured_at,
                availability_policy,
                availability_delay_seconds,
                license_scope,
                license_reference,
            } => {
                let report = MarketBarCsvImporter.import(&input)?;
                let captured_at = captured_at
                    .as_deref()
                    .map(DateTime::parse_from_rfc3339)
                    .transpose()
                    .context("--captured-at must be RFC3339")?
                    .map(|value| value.with_timezone(&Utc))
                    .unwrap_or_else(Utc::now);
                let availability_policy = match availability_policy.as_str() {
                    "observed-at-ingestion" => AvailabilityPolicy::ObservedAtIngestion,
                    "completed-minute-end-plus-delay" => {
                        AvailabilityPolicy::CompletedMinuteEndPlusDelay
                    }
                    _ => unreachable!("clap constrains availability policy"),
                };
                let license_scope = match license_scope.as_str() {
                    "research-only" => LicenseScope::ResearchOnly,
                    "internal-display" => LicenseScope::InternalDisplay,
                    "public-redistribution" => LicenseScope::PublicRedistribution,
                    _ => unreachable!("clap constrains license scope"),
                };
                let request = MaterializeRequest {
                    database: database.clone(),
                    source_path: input,
                    provider,
                    dataset,
                    captured_at,
                    availability_policy,
                    availability_delay_seconds,
                    license_scope,
                    license_reference,
                    input_rows: report.input_rows,
                    accepted_rows: report.accepted_rows,
                    duplicate_rows: report.duplicate_rows,
                    rejected_rows: report.rejected_rows,
                };
                let mut store = MarketDataStore::open(&database)?;
                let receipt = store.materialize(&request, &report.records)?;
                println!("{}", serde_json::to_string_pretty(&receipt)?);
            }
            DataCommand::MarketStoreCoverage { database } => {
                let store = MarketDataStore::open(&database)?;
                println!("{}", serde_json::to_string_pretty(&store.coverage()?)?);
            }
            DataCommand::ContextAudit {
                input,
                cutoff,
                output,
            } => {
                let input = input.unwrap_or_else(|| config.data.context.input_path.clone());
                let cutoff = cutoff
                    .as_deref()
                    .map(DateTime::parse_from_rfc3339)
                    .transpose()
                    .context("--cutoff must be RFC3339, for example 2026-07-21T13:30:00Z")?
                    .map(|value| value.with_timezone(&Utc))
                    .unwrap_or_else(Utc::now);
                let report = context::audit(&input, &config.data.context, cutoff)?;
                write_json(&output, &report)?;
                println!("{}", serde_json::to_string_pretty(&report)?);
                eprintln!("context_audit={}", output.display());
            }
            DataCommand::DecodeOhlcv {
                input,
                output,
                symbol_alias,
            } => {
                let rows = dbn_decode::write_ohlcv_csv(&input, &output, symbol_alias.as_deref())?;
                println!(
                    "decoded_schema=ohlcv rows={rows} output={}",
                    output.display()
                );
            }
            DataCommand::DecodeCbbo { input, output } => {
                let rows = dbn_decode::write_cbbo_csv(&input, &output)?;
                println!(
                    "decoded_schema=cbbo rows={rows} output={}",
                    output.display()
                );
            }
            DataCommand::MassiveStatus => {
                println!(
                    "{}",
                    serde_json::to_string_pretty(&axio_quant_engine::data::massive::status(
                        &config.data.massive
                    ))?
                );
            }
            DataCommand::MassiveSync {
                from,
                to,
                symbols,
                chunk_days,
                output,
            } => {
                let override_symbols = (!symbols.is_empty()).then_some(symbols);
                let mut data_config = config.data.clone();
                if let Some(chunk_days) = chunk_days {
                    if chunk_days <= 0 {
                        anyhow::bail!("--chunk-days must be positive");
                    }
                    data_config.massive.chunk_days = chunk_days;
                }
                let receipt = axio_quant_engine::data::massive::sync(
                    &data_config,
                    from,
                    to,
                    override_symbols,
                    &output,
                )
                .await?;
                println!("{}", serde_json::to_string_pretty(&receipt)?);
            }
            DataCommand::MassivePoll {
                lookback_days,
                output,
            } => {
                let today = Utc::now().date_naive();
                let from = today - Duration::days(lookback_days.max(1));
                let receipt = axio_quant_engine::data::massive::sync(
                    &config.data,
                    from,
                    today,
                    None,
                    &output,
                )
                .await?;
                println!("{}", serde_json::to_string_pretty(&receipt)?);
            }
        },
        Command::Broker(args) => match args.command {
            BrokerCommand::Doctor => {
                let client = MoomooBrokerClient::from_config(&config.execution)?;
                let health = client.health().await?;
                println!("{}", serde_json::to_string_pretty(&health)?);
            }
            BrokerCommand::Reconcile => {
                let runtime = QuantRuntime::new(config.os.clone());
                let monitor = BrokerMonitor::new(&config.execution);
                let snapshot = reconcile_once(&config.execution, &runtime, &monitor).await?;
                println!(
                    "{}",
                    serde_json::to_string_pretty(&serde_json::json!({
                        "status":"RECONCILED",
                        "snapshot_id":snapshot.snapshot_id,
                        "as_of":snapshot.as_of,
                        "account_id":snapshot.account.account_id,
                        "positions":snapshot.positions.len(),
                        "orders":snapshot.orders.len(),
                        "fills":snapshot.fills.len(),
                        "oms":config.execution.oms_path
                    }))?
                );
            }
            BrokerCommand::ExecuteOnce {
                control_url,
                forecast,
                execute,
                confirm_live_account,
            } => {
                execute_broker_once(
                    &config,
                    &control_url,
                    &forecast,
                    execute,
                    confirm_live_account,
                )
                .await?;
            }
            BrokerCommand::Run {
                control_url,
                forecast,
                execute,
                confirm_live_account,
                poll_ms,
            } => {
                if poll_ms < 500 {
                    anyhow::bail!("broker run poll interval must be at least 500ms");
                }
                loop {
                    if let Err(error) = execute_broker_once(
                        &config,
                        &control_url,
                        &forecast,
                        execute,
                        confirm_live_account,
                    )
                    .await
                    {
                        eprintln!("BROKER_RUN_FAIL_CLOSED error={error:#}");
                    }
                    tokio::time::sleep(std::time::Duration::from_millis(poll_ms)).await;
                }
            }
        },
        Command::Live(args) => match args.command {
            LiveCommand::FeatureContract {
                no_uup,
                no_uup_no_tlt,
                causal_absence_shadow,
            } => {
                if no_uup && no_uup_no_tlt {
                    anyhow::bail!("choose only one sparse cross-asset feature candidate");
                }
                let policy = if causal_absence_shadow {
                    axio_quant_engine::config::ContextObservationPolicyConfig::v2_candidate()
                } else {
                    axio_quant_engine::config::ContextObservationPolicyConfig::default()
                };
                let cross_asset_schema = if no_uup_no_tlt {
                    axio_quant_engine::config::CrossAssetFeatureSchemaConfig::v3_candidate_without_uup_or_tlt()
                } else if no_uup {
                    axio_quant_engine::config::CrossAssetFeatureSchemaConfig::v2_candidate_without_uup()
                } else {
                    axio_quant_engine::config::CrossAssetFeatureSchemaConfig::default()
                };
                let (feature_schema_version, feature_schema_sha256) =
                    predictor::live_feature_contract_identity(&policy, &cross_asset_schema)?;
                println!(
                    "{}",
                    serde_json::to_string_pretty(&serde_json::json!({
                        "schema_version": "axio.live-feature-contract-inspection.v1",
                        "feature_schema_version": feature_schema_version,
                        "feature_schema_sha256": feature_schema_sha256,
                        "context_observation_policy_schema_version": policy.schema_version,
                        "cross_asset_feature_schema_version": cross_asset_schema.schema_version,
                        "cross_asset_feature_schema_sha256": cross_asset_schema.schema_sha256,
                        "promotion_status": if causal_absence_shadow {
                            "LIVE_SHADOW_ONLY_PENDING_DATABENTO_BATCH_PARITY"
                        } else if no_uup || no_uup_no_tlt {
                            "RETRAIN_AND_VALIDATE_REQUIRED"
                        } else {
                            "CURRENT_V1_IDENTITY"
                        },
                    }))?
                );
            }
            LiveCommand::MassiveCheck { output, scope } => {
                let report = axio_quant_engine::data::massive_live::check_realtime_entitlements(
                    &config.data.massive,
                    &config.live,
                )
                .await?;
                write_json(&output, &report)?;
                println!("{}", serde_json::to_string_pretty(&report)?);
                match scope {
                    MassiveReadinessScope::All if !report.production_ready => {
                        anyhow::bail!("MASSIVE_REALTIME_NOT_READY: {}", report.blockers.join("; "));
                    }
                    MassiveReadinessScope::Equity if !report.equity_realtime_ready => {
                        anyhow::bail!(
                            "MASSIVE_EQUITY_REALTIME_NOT_READY: stock websocket: {}; stock snapshot: {}",
                            report.stock_websocket.detail,
                            report.stock_snapshot.detail
                        );
                    }
                    MassiveReadinessScope::Options if !report.options_realtime_ready => {
                        let unavailable = report
                            .options_ready_by_underlying
                            .iter()
                            .filter_map(|(underlying, ready)| {
                                (!ready).then_some(underlying.as_str())
                            })
                            .collect::<Vec<_>>();
                        anyhow::bail!(
                            "MASSIVE_OPTIONS_REALTIME_NOT_READY: {}",
                            if unavailable.is_empty() {
                                "no option underlyings configured".to_string()
                            } else {
                                format!("unavailable underlyings: {}", unavailable.join(","))
                            }
                        );
                    }
                    _ => {}
                }
            }
            LiveCommand::MassiveStream {
                output,
                status,
                max_finalized,
            } => {
                let readiness = axio_quant_engine::data::massive_live::check_realtime_entitlements(
                    &config.data.massive,
                    &config.live,
                )
                .await?;
                write_json(Path::new("data/live/massive_readiness.json"), &readiness)?;
                if !readiness.equity_realtime_ready {
                    anyhow::bail!(
                        "MASSIVE_EQUITY_REALTIME_NOT_READY: stock websocket: {}; stock snapshot: {}",
                        readiness.stock_websocket.detail,
                        readiness.stock_snapshot.detail
                    );
                }
                axio_quant_engine::data::massive_live::run_stock_stream(
                    &config.data.massive,
                    &config.live,
                    &output,
                    &status,
                    max_finalized,
                    None,
                )
                .await?;
            }
            LiveCommand::MassiveModel {
                historical_bars,
                universe_registry,
                raw_output,
                stream_status,
                forecast_output,
                inference_status,
                ledger,
            } => {
                let readiness = axio_quant_engine::data::massive_live::check_realtime_entitlements(
                    &config.data.massive,
                    &config.live,
                )
                .await?;
                write_json(Path::new("data/live/massive_readiness.json"), &readiness)?;
                if !readiness.equity_realtime_ready {
                    anyhow::bail!(
                        "MASSIVE_EQUITY_REALTIME_NOT_READY: stock websocket: {}; stock snapshot: {}",
                        readiness.stock_websocket.detail,
                        readiness.stock_snapshot.detail
                    );
                }
                let (historical_import, data_capability) =
                    capability::import_verified_training_bars(&config.data, &historical_bars)?;
                let historical = historical_import.records;
                let configured_model_symbols = config
                    .live
                    .forecast_symbols
                    .iter()
                    .map(|symbol| canonical_model_symbol(symbol))
                    .collect::<Result<BTreeSet<_>>>()?;
                if configured_model_symbols.is_empty() {
                    anyhow::bail!("live.forecast_symbols is empty");
                }
                let frozen_universe =
                    match load_frozen_universe(&universe_registry, &configured_model_symbols) {
                        Ok(universe) => universe,
                        Err(error) => {
                            // Market-data capture must remain useful while a new,
                            // independently promoted artifact is being trained.
                            // A global registry error disables each configured
                            // symbol explicitly; it never selects the primary
                            // target as a fallback.
                            LoadedFrozenUniverse::unavailable_for_symbols(
                                &configured_model_symbols,
                                &format!("UNIVERSE_REGISTRY_UNAVAILABLE:{error}"),
                            )
                        }
                    };
                let (artifacts, mut artifact_failures) = frozen_universe.into_parts();
                let mut target_runtimes = BTreeMap::<String, MassiveTargetRuntime>::new();
                for (target, artifact) in artifacts {
                    if let Err(error) = predictor::validate_live_feature_contract(
                        &artifact,
                        &config.live.context_observation_policy,
                        &config.live.cross_asset_feature_schema,
                    ) {
                        artifact_failures.insert(
                            target,
                            format!("LIVE_FEATURE_SCHEMA_ARTIFACT_MISMATCH:{error}"),
                        );
                        continue;
                    }
                    if !config
                        .research
                        .targets
                        .iter()
                        .any(|configured| configured.model_symbol.eq_ignore_ascii_case(&target))
                    {
                        artifact_failures
                            .insert(target, "RESEARCH_TARGET_MAPPING_MISSING".to_string());
                        continue;
                    }
                    let mut research = config.research.clone();
                    research.target = target.clone();
                    match features::IncrementalFeatureEngine::new_with_feature_contract(
                        &historical,
                        &target,
                        &research,
                        config.live.required_context_symbols.clone(),
                        config.live.max_context_skew_ms,
                        config.live.context_observation_policy.clone(),
                        config.live.cross_asset_feature_schema.clone(),
                    ) {
                        Ok(feature_engine) => {
                            target_runtimes.insert(
                                target,
                                MassiveTargetRuntime {
                                    research,
                                    artifact,
                                    feature_engine,
                                    target_events: HashMap::new(),
                                },
                            );
                        }
                        Err(error) => {
                            artifact_failures.insert(
                                target,
                                format!("FEATURE_ENGINE_INITIALIZATION_FAILED:{error}"),
                            );
                        }
                    }
                }
                write_json(
                    &inference_status,
                    &serde_json::json!({
                        "schema_version":"massive_inference_status.v1",
                        "as_of":Utc::now(),
                        "status":if target_runtimes.is_empty() {
                            "NO_FORECAST"
                        } else if artifact_failures.is_empty() {
                            "UNIVERSE_READY"
                        } else {
                            "PARTIAL_UNIVERSE_READY"
                        },
                        "stage":"FROZEN_UNIVERSE_GATE",
                        "configured_symbols":configured_model_symbols,
                        "ready_symbols":target_runtimes.keys().collect::<Vec<_>>(),
                        "symbol_failures":artifact_failures,
                        "market_data_capture_continues":true,
                        "intraday_fit_allowed":false
                    }),
                )?;
                let prediction_ledger = PredictionLedger::open(&ledger)?;
                let (sender, mut receiver) = tokio::sync::mpsc::channel(4096);
                let massive_config = config.data.massive.clone();
                let live_config = config.live.clone();
                let stream_output = raw_output.clone();
                let stream_status_path = stream_status.clone();
                let stream_task = tokio::spawn(async move {
                    axio_quant_engine::data::massive_live::run_stock_stream(
                        &massive_config,
                        &live_config,
                        &stream_output,
                        &stream_status_path,
                        None,
                        Some(sender),
                    )
                    .await
                });
                while let Some(envelope) = receiver.recv().await {
                    for (target, runtime) in &mut target_runtimes {
                        let target_status_path =
                            live_inference_status_path(&inference_status, target);
                        if envelope.bar.symbol.eq_ignore_ascii_case(target) {
                            runtime
                                .target_events
                                .insert(envelope.bar_start.timestamp_millis(), envelope.clone());
                        }
                        let update = match runtime.feature_engine.ingest(envelope.bar.clone()) {
                            Ok(update) => update,
                            Err(error) => {
                                write_json(
                                    &target_status_path,
                                    &serde_json::json!({
                                        "schema_version":"massive_inference_status.v1",
                                        "as_of":Utc::now(),
                                        "model_symbol":target,
                                        "status":"NO_FORECAST",
                                        "stage":"FEATURE_ENGINE",
                                        "reason":error.to_string()
                                    }),
                                )?;
                                continue;
                            }
                        };
                        write_json(&target_status_path, &update)?;
                        if !update.state_ready {
                            continue;
                        }
                        let Some(cutoff) = update.cutoff else {
                            continue;
                        };
                        let Some(target_event) =
                            runtime.target_events.get(&cutoff.timestamp_millis())
                        else {
                            write_json(
                                &target_status_path,
                                &serde_json::json!({
                                    "schema_version":"massive_inference_status.v1",
                                    "as_of":cutoff,
                                    "model_symbol":target,
                                    "status":"NO_FORECAST",
                                    "reason":"TARGET_PROVIDER_EVENT_METADATA_MISSING"
                                }),
                            )?;
                            continue;
                        };
                        let target_received_at = target_event.received_at;
                        let inference_started = Instant::now();
                        let option_input = match massive_option_input_at_cutoff(
                            &config.data.massive,
                            target,
                            cutoff + Duration::minutes(1),
                            runtime.research.option_max_staleness_seconds,
                        ) {
                            Ok(option_input) => option_input,
                            Err(error) => {
                                write_json(
                                    &target_status_path,
                                    &serde_json::json!({
                                        "schema_version":"massive_inference_status.v1",
                                        "as_of":cutoff,
                                        "model_symbol":target,
                                        "status":"NO_FORECAST",
                                        "stage":"OPTION_ARTIFACT_GATE",
                                        "reason":error.to_string()
                                    }),
                                )?;
                                continue;
                            }
                        };
                        let forecast_result = if let Some(option_input) = option_input.as_ref() {
                            predictor::forecast_with_frozen_artifact_and_options(
                                runtime.feature_engine.states(),
                                &runtime.research,
                                &config.os,
                                &data_capability,
                                Utc::now(),
                                &runtime.artifact,
                                option_input,
                            )
                        } else {
                            predictor::forecast_with_frozen_artifact(
                                runtime.feature_engine.states(),
                                &runtime.research,
                                &config.os,
                                &data_capability,
                                Utc::now(),
                                &runtime.artifact,
                            )
                        };
                        let mut bundle = match forecast_result {
                            Ok(bundle) => bundle,
                            Err(error) => {
                                write_json(
                                    &target_status_path,
                                    &serde_json::json!({
                                        "schema_version":"massive_inference_status.v1",
                                        "as_of":cutoff,
                                        "model_symbol":target,
                                        "status":"NO_FORECAST",
                                        "stage":"FROZEN_INFERENCE",
                                        "reason":error.to_string()
                                    }),
                                )?;
                                continue;
                            }
                        };
                        let compute_ms = inference_started.elapsed().as_millis();
                        let end_to_end_ms = Utc::now()
                            .signed_duration_since(target_received_at)
                            .num_milliseconds();
                        if end_to_end_ms > config.live.prediction_sla_ms {
                            write_json(
                                &target_status_path,
                                &serde_json::json!({
                                    "schema_version":"massive_inference_status.v1",
                                    "as_of":cutoff,
                                    "model_symbol":target,
                                    "status":"NO_FORECAST",
                                    "stage":"SLA_GATE",
                                    "reason":"PREDICTION_SLA_EXCEEDED",
                                    "compute_ms":compute_ms,
                                    "end_to_end_ms":end_to_end_ms,
                                    "budget_ms":config.live.prediction_sla_ms
                                }),
                            )?;
                            continue;
                        }
                        predictor::enforce_realtime_forward_shadow(
                            &mut bundle,
                            target_received_at,
                            config.live.execution_latency_ms,
                            false,
                            &predictor::RealtimeSourceMetadata {
                                source_version: "stocks-ws-am-v1",
                                provider: "MASSIVE_SIP",
                                market_coverage: "US_CONSOLIDATED_SIP",
                                availability_semantics: "MASSIVE_PROVIDER_EVENT_RECEIVE_AND_FINALIZED_TIMESTAMPS",
                            },
                        );
                        persist_canonical_predictions(&prediction_ledger, &mut bundle)?;
                        let target_output = live_forecast_path(&forecast_output, target);
                        write_json(&target_output, &bundle)?;
                        write_json(
                            &target_status_path,
                            &serde_json::json!({
                                "schema_version":"massive_inference_status.v1",
                                "as_of":cutoff,
                                "model_symbol":target,
                                "status":"FORWARD_SHADOW_PERSISTED",
                                "compute_ms":compute_ms,
                                "end_to_end_ms":end_to_end_ms,
                                "budget_ms":config.live.prediction_sla_ms,
                                "model_hash":runtime.artifact.model_hash,
                                "contracts":bundle.prediction_layer.len()
                            }),
                        )?;
                    }
                }
                stream_task
                    .await
                    .context("Massive stream task panicked")??;
            }
            LiveCommand::MassiveOptionsSnapshot { underlyings } => {
                let requested = if underlyings.is_empty() {
                    config.data.massive.option_underlyings.clone()
                } else {
                    underlyings
                };
                if requested.is_empty() {
                    anyhow::bail!("no option underlyings configured or requested");
                }
                let mut receipts = Vec::new();
                for underlying in requested {
                    let snapshot = axio_quant_engine::data::massive_live::fetch_full_option_chain(
                        &config.data.massive,
                        &config.live,
                        &underlying,
                    )
                    .await?;
                    let path = axio_quant_engine::data::massive_live::persist_full_option_chain(
                        &config.data.massive,
                        &snapshot,
                    )?;
                    receipts.push(serde_json::json!({
                        "underlying": snapshot.underlying,
                        "path": path,
                        "captured_at": snapshot.captured_at,
                        "chain_complete": snapshot.chain_complete,
                        "model_ready": snapshot.model_ready,
                        "coverage": snapshot.coverage,
                        "blockers": snapshot.blockers,
                        "contracts_sha256": snapshot.contracts_sha256
                    }));
                }
                println!("{}", serde_json::to_string_pretty(&receipts)?);
            }
            LiveCommand::MassiveOptionsWatch {
                underlyings,
                refresh_seconds,
            } => {
                let requested = if underlyings.is_empty() {
                    config.data.massive.option_underlyings.clone()
                } else {
                    underlyings
                };
                if requested.is_empty() {
                    anyhow::bail!("no option underlyings configured or requested");
                }
                let interval = refresh_seconds
                    .unwrap_or(config.data.massive.option_chain_refresh_seconds)
                    .max(30);
                loop {
                    for underlying in &requested {
                        match axio_quant_engine::data::massive_live::fetch_full_option_chain(
                            &config.data.massive,
                            &config.live,
                            underlying,
                        )
                        .await
                        {
                            Ok(snapshot) => {
                                let path = axio_quant_engine::data::massive_live::persist_full_option_chain(
                                    &config.data.massive,
                                    &snapshot,
                                )?;
                                println!(
                                    "MASSIVE_OPTION_CHAIN underlying={} complete={} model_ready={} contracts={} output={}",
                                    snapshot.underlying,
                                    snapshot.chain_complete,
                                    snapshot.model_ready,
                                    snapshot.contracts.len(),
                                    path.display()
                                );
                            }
                            Err(error) => {
                                eprintln!(
                                    "MASSIVE_OPTION_CHAIN_NO_MODEL_INPUT underlying={} reason={error:#}",
                                    underlying
                                );
                            }
                        }
                    }
                    tokio::time::sleep(std::time::Duration::from_secs(interval)).await;
                }
            }
            LiveCommand::Check { host, port, output } => {
                if host != "127.0.0.1" && host != "::1" && host != "localhost" {
                    anyhow::bail!("Moomoo OpenD host must be loopback-only");
                }
                let report = live::check(&config.live, &host, port);
                write_json(&output, &report)?;
                println!("{}", serde_json::to_string_pretty(&report)?);
            }
            LiveCommand::Capabilities => {
                println!(
                    "{}",
                    serde_json::to_string_pretty(&live::capability(&config.live))?
                );
            }
            LiveCommand::Status { status } => {
                if status.exists() {
                    println!("{}", std::fs::read_to_string(status)?);
                } else {
                    println!(
                        "{}",
                        serde_json::to_string_pretty(&live::check(
                            &config.live,
                            &config.live.host,
                            config.live.port
                        ))?
                    );
                }
            }
            LiveCommand::Replay {
                input,
                symbol,
                output,
                historical_bars,
                forecast_output,
                ledger,
                universe_registry,
                publish_url,
                publish_token_env,
            } => {
                let bars = live::replay(
                    &input,
                    config.live.finalize_grace_ms,
                    config.live.stale_after_ms,
                )?;
                for bar in &bars {
                    live::append_jsonl(&output, bar)?;
                }
                let mut prediction_count = 0;
                let target = canonical_model_symbol(&symbol)?;
                let complete_bars = bars
                    .iter()
                    .filter(|bar| {
                        bar.gap_status == "COMPLETE"
                            && canonical_model_symbol(&bar.update.symbol)
                                .is_ok_and(|value| value == target)
                    })
                    .collect::<Vec<_>>();
                if !complete_bars.is_empty() && historical_bars.exists() {
                    if config
                        .live
                        .context_observation_policy
                        .causal_no_trade_materialization_enabled()
                    {
                        anyhow::bail!(
                            "Moomoo replay cannot satisfy causal no-trade feature semantics"
                        );
                    }
                    let (historical_import, capability) =
                        capability::import_verified_training_bars(&config.data, &historical_bars)?;
                    let mut imported = historical_import.records;
                    imported.extend(
                        complete_bars
                            .iter()
                            .map(|bar| live::FinalizedLiveBar::as_market_bar(bar)),
                    );
                    imported.sort_by_key(|row| row.timestamp);
                    let mut target_research = config.research.clone();
                    target_research.target = target.clone();
                    let frozen_universe = load_frozen_universe(&universe_registry, [&target])?;
                    let frozen_artifact = frozen_universe.artifact(&target).with_context(|| {
                        let reason = frozen_universe
                            .failures()
                            .get(&target)
                            .cloned()
                            .unwrap_or_else(|| "EXACT_SYMBOL_ARTIFACT_MISSING".to_string());
                        format!("frozen replay artifact unavailable for {target}: {reason}")
                    })?;
                    predictor::validate_live_feature_contract(
                        frozen_artifact,
                        &config.live.context_observation_policy,
                        &config.live.cross_asset_feature_schema,
                    )?;
                    let states = features::build_states_for_observed_feature_contract(
                        &imported,
                        &target,
                        &target_research,
                        &config.live.context_observation_policy,
                        &config.live.cross_asset_feature_schema,
                    )?;
                    let latest = complete_bars
                        .iter()
                        .max_by_key(|row| row.finalized_timestamp)
                        .context("replay produced no complete latest bar")?;
                    let latest_state = states.last().context(
                        "replay produced no state under the configured feature contract",
                    )?;
                    if latest_state.timestamp != latest.update.bar_start
                        || !latest_state.cross_asset_context_complete
                    {
                        anyhow::bail!("MOOMOO_REPLAY_CONTEXT_INCOMPLETE_AT_LATEST_TARGET_CUTOFF");
                    }
                    let mut bundle = predictor::forecast_with_frozen_artifact(
                        &states,
                        &target_research,
                        &config.os,
                        &capability,
                        Utc::now(),
                        frozen_artifact,
                    )?;
                    predictor::enforce_moomoo_forward_shadow(
                        &mut bundle,
                        latest.update.available_timestamp,
                        &latest.update.source_version,
                        config.live.execution_latency_ms,
                        latest.update.is_replay,
                    );
                    prediction_count = bundle.prediction_layer.len();
                    let prediction_ledger = PredictionLedger::open(&ledger)?;
                    persist_canonical_predictions(&prediction_ledger, &mut bundle)?;
                    write_json(&forecast_output, &bundle)?;
                    match publish_owner_forecast(
                        publish_url.as_deref(),
                        &publish_token_env,
                        &bundle,
                    )
                    .await
                    {
                        Ok(true) => eprintln!(
                            "OWNER_FORECAST_RELAYED symbol={target} mode=DETERMINISTIC_REPLAY"
                        ),
                        Ok(false) => {}
                        Err(error) => eprintln!(
                            "OWNER_FORECAST_RELAY_FAILED symbol={target} mode=DETERMINISTIC_REPLAY error={error:#}"
                        ),
                    }
                }
                println!(
                    "{}",
                    serde_json::to_string_pretty(&serde_json::json!({
                        "status":"DETERMINISTIC_REPLAY_COMPLETE",
                        "input":input,
                        "output":output,
                        "symbol":target,
                        "finalized_bars":bars.len(),
                        "predictions_generated":prediction_count,
                        "truth":"Replay validates finalization; it is not live market evidence"
                    }))?
                );
            }
            LiveCommand::Stream {
                shadow,
                bridge,
                historical_bars,
                raw_output,
                finalized_output,
                gaps_output,
                forecast_output,
                ledger,
                universe_registry,
                publish_url,
                publish_token_env,
            } => {
                if !shadow || !config.live.shadow_only || config.live.allow_trade_api {
                    anyhow::bail!(
                        "Moomoo runtime is quote-only forward-shadow; trading is prohibited"
                    );
                }
                if config
                    .live
                    .context_observation_policy
                    .causal_no_trade_materialization_enabled()
                {
                    anyhow::bail!(
                        "Moomoo quote runtime cannot satisfy causal no-trade feature semantics"
                    );
                }
                let report = live::check(&config.live, &config.live.host, config.live.port);
                write_json(Path::new("data/live/status.json"), &report)?;
                if !report.tcp_connected {
                    anyhow::bail!(
                        report
                            .blocker
                            .unwrap_or_else(|| "OpenD disconnected".into())
                    );
                }
                if !bridge.exists() {
                    anyhow::bail!(
                        "official Moomoo quote bridge not found: {}",
                        bridge.display()
                    );
                }
                let python_executable = std::env::var_os("PYTHON")
                    .filter(|value| !value.is_empty())
                    .unwrap_or_else(|| "python".into());

                let (historical_import, data_capability) =
                    capability::import_verified_training_bars(&config.data, &historical_bars)?;
                let historical = historical_import.records;
                let configured_model_symbols = config
                    .live
                    .forecast_symbols
                    .iter()
                    .map(|symbol| canonical_model_symbol(symbol))
                    .collect::<Result<BTreeSet<_>>>()?;
                let frozen_universe =
                    match load_frozen_universe(&universe_registry, &configured_model_symbols) {
                        Ok(universe) => universe,
                        Err(error) => LoadedFrozenUniverse::unavailable_for_symbols(
                            &configured_model_symbols,
                            &format!("UNIVERSE_REGISTRY_UNAVAILABLE:{error}"),
                        ),
                    };
                let (loaded_artifacts, mut artifact_failures) = frozen_universe.into_parts();
                let mut frozen_artifacts = BTreeMap::new();
                for (symbol, artifact) in loaded_artifacts {
                    if let Err(error) = predictor::validate_live_feature_contract(
                        &artifact,
                        &config.live.context_observation_policy,
                        &config.live.cross_asset_feature_schema,
                    ) {
                        artifact_failures.insert(
                            symbol,
                            format!("LIVE_FEATURE_SCHEMA_ARTIFACT_MISMATCH:{error}"),
                        );
                        continue;
                    }
                    eprintln!(
                        "FROZEN_PREDICTOR_LOADED target={symbol} cutoff={} model_hash={}",
                        artifact.training_cutoff, artifact.model_hash
                    );
                    frozen_artifacts.insert(symbol, artifact);
                }
                for (symbol, reason) in &artifact_failures {
                    eprintln!(
                        "LIVE_NO_FORECAST symbol={symbol} status=FROZEN_ARTIFACT_UNAVAILABLE reason={reason}"
                    );
                }
                let prediction_ledger = PredictionLedger::open(&ledger)?;
                let mut finalizer = live::MinuteBarFinalizer::new(config.live.stale_after_ms)?;
                let mut gap_writer = live::GapJsonlWriter::open(&gaps_output)?;
                let mut session_bars = Vec::<live::FinalizedLiveBar>::new();
                let mut protocol_verified = false;
                let forecast_symbols: BTreeSet<String> = config
                    .live
                    .forecast_symbols
                    .iter()
                    .map(|symbol| symbol.to_ascii_uppercase())
                    .collect();
                let mut spy_verified = false;
                let mut kline_verified = false;
                let mut reconnect_ms = config.live.reconnect_min_ms;
                loop {
                    let mut bridge_command = quote_bridge_command(
                        &bridge,
                        &python_executable,
                        &config.live.host,
                        config.live.port,
                        &config.live.symbols,
                    )?;
                    let mut child = bridge_command
                        .stdout(Stdio::piped())
                        .stderr(Stdio::inherit())
                        .spawn()
                        .with_context(|| {
                            format!("start official Moomoo bridge {}", bridge.display())
                        })?;
                    let stdout = child
                        .stdout
                        .take()
                        .context("Moomoo bridge stdout unavailable")?;
                    println!("MOOMOO_STREAM_STARTED pid={} quote_only=true", child.id());

                    let (line_sender, line_receiver) =
                        std::sync::mpsc::sync_channel::<std::io::Result<String>>(1024);
                    let reader_handle = std::thread::spawn(move || {
                        for line in BufReader::new(stdout).lines() {
                            if line_sender.send(line).is_err() {
                                break;
                            }
                        }
                    });
                    loop {
                        let line = match line_receiver
                            .recv_timeout(std::time::Duration::from_millis(250))
                        {
                            Ok(line) => Some(line?),
                            Err(std::sync::mpsc::RecvTimeoutError::Timeout) => None,
                            Err(std::sync::mpsc::RecvTimeoutError::Disconnected) => break,
                        };
                        let received_at = Utc::now();
                        // This independent clock fires even when OpenD emits
                        // no K_1M line. Every bridge event also passes through
                        // this point before event-specific parsing.
                        let mut completed =
                            finalizer.finalize_due(received_at, config.live.finalize_grace_ms);
                        if let Some(line) = line {
                            let parsed_value =
                                serde_json::from_str::<serde_json::Value>(&line).ok();
                            if let Some(value) = &parsed_value {
                                live::append_jsonl_rotating(
                                    &raw_output,
                                    value,
                                    config.live.raw_log_max_bytes,
                                    config.live.raw_log_archive_count,
                                )?;
                                let event = value
                                    .get("event")
                                    .and_then(|v| v.as_str())
                                    .unwrap_or("quote");
                                let symbol = value
                                    .get("symbol")
                                    .and_then(|v| v.as_str())
                                    .unwrap_or("US.UNKNOWN");
                                let should_update = !protocol_verified
                                    || (!spy_verified && symbol == "US.SPY")
                                    || (!kline_verified && event == "k_1m");
                                if should_update {
                                    let verified =
                                        live::verified_check(&config.live, symbol, event);
                                    write_json(Path::new("data/live/status.json"), &verified)?;
                                    protocol_verified = true;
                                    spy_verified |= symbol == "US.SPY";
                                    kline_verified |= event == "k_1m";
                                    println!(
                                        "MOOMOO_PROTOCOL_VERIFIED symbol={symbol} event={event}"
                                    );
                                }
                                reconnect_ms = config.live.reconnect_min_ms;
                            }
                            if let Some(update) = live::parse_sdk_kline(&line, received_at)? {
                                completed.extend(finalizer.ingest(update)?);
                            }
                        }
                        let persisted_gaps = gap_writer.append_new(&finalizer.gaps)?;
                        if persisted_gaps > 0 {
                            println!(
                                "MOOMOO_GAPS_APPENDED count={persisted_gaps} output={}",
                                gaps_output.display()
                            );
                        }
                        for bar in completed {
                            live::append_jsonl(&finalized_output, &bar)?;
                            session_bars.push(bar.clone());
                            let local = bar.update.bar_start.with_timezone(&New_York);
                            let regular = (local.hour(), local.minute()) >= (9, 30)
                                && (local.hour(), local.minute()) < (16, 0);
                            let live_symbol = bar.update.symbol.to_ascii_uppercase();
                            if !forecast_symbols.contains(&live_symbol)
                                || bar.update.is_cached_push
                                || bar.gap_status != "COMPLETE"
                                || !regular
                            {
                                continue;
                            }
                            let mut records = historical.clone();
                            let target = live_symbol.trim_start_matches("US.").to_string();
                            records.extend(
                                session_bars
                                    .iter()
                                    .filter(|candidate| {
                                        candidate.gap_status == "COMPLETE"
                                            && candidate.update.available_timestamp
                                                <= bar.update.available_timestamp
                                            && candidate.update.bar_start <= bar.update.bar_start
                                    })
                                    .map(live::FinalizedLiveBar::as_market_bar),
                            );
                            records.sort_by_key(|row| row.timestamp);
                            let mut target_research = config.research.clone();
                            target_research.target = target.clone();
                            let states = match features::build_states_for_observed_feature_contract(
                                &records,
                                &target,
                                &target_research,
                                &config.live.context_observation_policy,
                                &config.live.cross_asset_feature_schema,
                            ) {
                                Ok(states) => states,
                                Err(error) => {
                                    eprintln!(
                                        "LIVE_FORECAST_SKIPPED symbol={target} as_of={} status=WARMING_UP_NO_FORECAST stage=feature_state reason={error}",
                                        bar.update.bar_end
                                    );
                                    continue;
                                }
                            };
                            let latest_state_is_exact_and_complete =
                                states.last().is_some_and(|state| {
                                    state.timestamp == bar.update.bar_start
                                        && state.cross_asset_context_complete
                                });
                            if !latest_state_is_exact_and_complete {
                                eprintln!(
                                    "LIVE_FORECAST_SKIPPED symbol={target} as_of={} status=NO_FORECAST stage=context_readiness reason=LATEST_TARGET_CONTEXT_INCOMPLETE",
                                    bar.update.bar_end
                                );
                                continue;
                            }
                            let Some(frozen_artifact) = frozen_artifacts.get(&target) else {
                                eprintln!(
                                    "LIVE_FORECAST_SKIPPED symbol={target} as_of={} status=NO_FORECAST stage=frozen_artifact reason=EXACT_SYMBOL_ARTIFACT_MISSING",
                                    bar.update.bar_end
                                );
                                continue;
                            };
                            let mut bundle = match predictor::forecast_with_frozen_artifact(
                                &states,
                                &target_research,
                                &config.os,
                                &data_capability,
                                received_at,
                                frozen_artifact,
                            ) {
                                Ok(bundle) => bundle,
                                Err(error) => {
                                    // A new live process has no completed current-session
                                    // five-minute HMM context until enough one-minute bars
                                    // have finalized. That is a normal fail-closed warm-up
                                    // state, not a reason to terminate the quote supervisor.
                                    eprintln!(
                                        "LIVE_FORECAST_SKIPPED symbol={target} as_of={} status=WARMING_UP_NO_FORECAST stage=frozen_inference_context reason={error}",
                                        bar.update.bar_end
                                    );
                                    continue;
                                }
                            };
                            predictor::enforce_moomoo_forward_shadow(
                                &mut bundle,
                                bar.update.available_timestamp,
                                &bar.update.source_version,
                                config.live.execution_latency_ms,
                                false,
                            );
                            persist_canonical_predictions(&prediction_ledger, &mut bundle)?;
                            let target_output = live_forecast_path(&forecast_output, &target);
                            write_json(&target_output, &bundle)?;
                            match publish_owner_forecast(
                                publish_url.as_deref(),
                                &publish_token_env,
                                &bundle,
                            )
                            .await
                            {
                                Ok(true) => eprintln!(
                                    "OWNER_FORECAST_RELAYED symbol={target} mode=LIVE_FORWARD_SHADOW"
                                ),
                                Ok(false) => {}
                                Err(error) => eprintln!(
                                    "OWNER_FORECAST_RELAY_FAILED symbol={target} mode=LIVE_FORWARD_SHADOW error={error:#}"
                                ),
                            }
                            let settlements =
                                live::settle_pending(&prediction_ledger, &finalized_output)?;
                            println!(
                                "LIVE_FORECAST as_of={} predictions={} settlements={} status={}",
                                bar.update.bar_end,
                                bundle.prediction_layer.len(),
                                settlements.len(),
                                bundle.status
                            );
                        }
                    }
                    reader_handle.join().map_err(|_| {
                        anyhow::anyhow!("Moomoo bridge stdout reader thread panicked")
                    })?;
                    let status = child.wait()?;
                    eprintln!(
                        "Moomoo quote bridge exited ({status}); reconnecting in {reconnect_ms}ms"
                    );
                    std::thread::sleep(std::time::Duration::from_millis(reconnect_ms));
                    reconnect_ms = reconnect_ms
                        .saturating_mul(2)
                        .min(config.live.reconnect_max_ms);
                }
            }
        },
        Command::Predictor(args) => match args.command {
            PredictorCommand::Train { bars, output } => {
                let (imported, capability) =
                    capability::import_verified_training_bars(&config.data, &bars)?;
                let states = features::build_states(
                    &imported.records,
                    &config.research.target,
                    &config.research,
                )?;
                let artifact = predictor::train_frozen_artifact(
                    &states,
                    &config.research,
                    &capability,
                    Utc::now(),
                    option_env!("GIT_COMMIT").unwrap_or("WORKTREE_UNCOMMITTED"),
                )?;
                write_json(&output, &artifact)?;
                println!(
                    "artifact={} status=FROZEN_IMMUTABLE target={} cutoff={} model_hash={}",
                    output.display(),
                    artifact.target,
                    artifact.training_cutoff,
                    artifact.model_hash
                );
            }
            PredictorCommand::TrainUniverse {
                bars,
                output_dir,
                registry,
                symbols,
                feature_contract_config,
            } => {
                if config.research.targets.is_empty() {
                    anyhow::bail!("research.targets is empty");
                }
                let feature_contract_source = feature_contract_config
                    .as_ref()
                    .map(|path| path.to_string_lossy().replace('\\', "/"));
                let feature_contract = feature_contract_config
                    .as_ref()
                    .map(OfflineFeatureTrainingContractConfig::load)
                    .transpose()?;
                let (output_dir, registry) = train_universe_destinations(
                    &std::env::current_dir()?,
                    output_dir,
                    registry,
                    feature_contract.is_some(),
                )?;
                let context_observation_policy = feature_contract
                    .as_ref()
                    .map(|contract| contract.context_observation_policy.clone())
                    .unwrap_or_default();
                let cross_asset_feature_schema = feature_contract
                    .as_ref()
                    .map(|contract| contract.cross_asset_feature_schema.clone())
                    .unwrap_or_default();
                let (feature_schema_version, feature_schema_sha256) =
                    predictor::live_feature_contract_identity(
                        &context_observation_policy,
                        &cross_asset_feature_schema,
                    )?;
                let selected = symbols
                    .iter()
                    .map(|symbol| symbol.trim().to_ascii_uppercase())
                    .collect::<BTreeSet<_>>();
                let targets = config
                    .research
                    .targets
                    .iter()
                    .filter(|target| {
                        selected.is_empty() || selected.contains(&target.public_symbol)
                    })
                    .collect::<Vec<_>>();
                if targets.is_empty() {
                    anyhow::bail!("no configured public targets matched --symbols");
                }
                let (imported, capability) =
                    capability::import_verified_training_bars(&config.data, &bars)?;
                let trained_at = Utc::now();
                let mut entries = Vec::new();
                for (index, target) in targets.iter().enumerate() {
                    eprintln!(
                        "TRAIN_UNIVERSE_START target={} model_symbol={} item={}/{}",
                        target.public_symbol,
                        target.model_symbol,
                        index + 1,
                        targets.len()
                    );
                    let started = Instant::now();
                    let mut research = config.research.clone();
                    research.target = target.model_symbol.clone();
                    let artifact = if let Some(contract) = feature_contract.as_ref() {
                        let state_set = features::build_states_for_offline_feature_contract(
                            &imported.records,
                            &target.model_symbol,
                            &research,
                            contract,
                        )
                        .with_context(|| {
                            format!(
                                "build states for public target {} using {}",
                                target.public_symbol, target.model_symbol
                            )
                        })?;
                        predictor::train_frozen_artifact_for_offline_feature_contract(
                            &state_set,
                            &research,
                            &capability,
                            trained_at,
                            option_env!("GIT_COMMIT").unwrap_or("WORKTREE_UNCOMMITTED"),
                        )
                    } else {
                        let states = features::build_states(
                            &imported.records,
                            &target.model_symbol,
                            &research,
                        )
                        .with_context(|| {
                            format!(
                                "build states for public target {} using {}",
                                target.public_symbol, target.model_symbol
                            )
                        })?;
                        predictor::train_frozen_artifact(
                            &states,
                            &research,
                            &capability,
                            trained_at,
                            option_env!("GIT_COMMIT").unwrap_or("WORKTREE_UNCOMMITTED"),
                        )
                    }
                    .with_context(|| {
                        format!("train frozen candidate for {}", target.public_symbol)
                    })?;
                    let artifact_path =
                        output_dir.join(format!("{}.frozen.json", target.public_symbol));
                    write_json(&artifact_path, &artifact)?;
                    eprintln!(
                        "TRAIN_UNIVERSE_COMPLETE target={} elapsed_seconds={} artifact={}",
                        target.public_symbol,
                        started.elapsed().as_secs(),
                        artifact_path.display()
                    );
                    let portable_artifact_path = artifact_path.to_string_lossy().replace('\\', "/");
                    entries.push(serde_json::json!({
                        "public_symbol": target.public_symbol,
                        "model_symbol": target.model_symbol,
                        "price_symbol": target.price_symbol,
                        "options_underlying": target.options_underlying,
                        "vwap_volume_source": target.vwap_volume_source,
                        "target_status": target.target_status,
                        "artifact_path": portable_artifact_path,
                        "artifact_version": artifact.artifact_version,
                        "model_version": artifact.model_version,
                        "model_hash": artifact.model_hash,
                        "feature_schema_version": artifact.feature_schema_version,
                        "feature_schema_sha256": artifact.feature_schema_sha256,
                        "research_model_config_sha256": artifact.research_model_config_sha256,
                        "training_cutoff": artifact.training_cutoff,
                        "training_excluded_incomplete_context_states":
                            artifact.training_excluded_incomplete_context_states,
                        "short_horizon_sde_present": artifact.short_horizon_model.is_some(),
                        "promotion_status": "CANDIDATE_NOT_PROMOTED"
                    }));
                }
                let payload = serde_json::json!({
                    "schema_version": "axio.frozen-universe-registry.v1",
                    "generated_at": trained_at,
                    "status": "CANDIDATE_ARTIFACTS_NOT_PROMOTED",
                    "requested_public_symbols": targets
                        .iter()
                        .map(|target| target.public_symbol.clone())
                        .collect::<Vec<_>>(),
                    "horizons_minutes": config.research.horizons,
                    "training_mode": if feature_contract.is_some() {
                        "EXPLICIT_OFFLINE_FEATURE_CANDIDATE"
                    } else {
                        "CURRENT_V1_DEFAULT"
                    },
                    "feature_contract_config": feature_contract_source,
                    "feature_schema_version": feature_schema_version,
                    "feature_schema_sha256": feature_schema_sha256,
                    "context_observation_policy_schema_version":
                        context_observation_policy.schema_version,
                    "cross_asset_feature_schema_version":
                        cross_asset_feature_schema.schema_version,
                    "cross_asset_feature_schema_sha256":
                        cross_asset_feature_schema.schema_sha256,
                    "entries": entries,
                    "execution_enabled": false
                });
                write_json(&registry, &payload)?;
                println!("{}", serde_json::to_string_pretty(&payload)?);
            }
            PredictorCommand::WalkForward {
                bars,
                output,
                horizons,
                feature_contract_config,
                reference_registry,
                displayed_replay_start,
                displayed_replay_end,
            } => {
                let (imported, capability) =
                    capability::import_verified_training_bars(&config.data, &bars)?;
                let feature_contract_source = feature_contract_config
                    .as_ref()
                    .map(|path| path.to_string_lossy().replace('\\', "/"));
                let feature_contract = feature_contract_config
                    .as_ref()
                    .map(OfflineFeatureTrainingContractConfig::load)
                    .transpose()?;
                let candidate_state_set = feature_contract
                    .as_ref()
                    .map(|contract| {
                        features::build_states_for_offline_feature_contract(
                            &imported.records,
                            &config.research.target,
                            &config.research,
                            contract,
                        )
                    })
                    .transpose()?;
                let legacy_states = if candidate_state_set.is_none() {
                    Some(features::build_states(
                        &imported.records,
                        &config.research.target,
                        &config.research,
                    )?)
                } else {
                    None
                };
                let states = candidate_state_set
                    .as_ref()
                    .map(|state_set| state_set.states())
                    .or(legacy_states.as_deref())
                    .context("walk-forward state construction produced no states")?;

                let session_count = states
                    .iter()
                    .map(|state| state.session_date)
                    .collect::<BTreeSet<_>>()
                    .len();
                let requested_horizons = if horizons.is_empty() {
                    config.research.horizons.clone()
                } else {
                    horizons
                };
                let requested_horizons = requested_horizons
                    .into_iter()
                    .collect::<BTreeSet<_>>()
                    .into_iter()
                    .collect::<Vec<_>>();
                if requested_horizons.is_empty()
                    || requested_horizons
                        .iter()
                        .any(|horizon| !config.research.horizons.contains(horizon))
                {
                    bail!(
                        "walk-forward horizons must be a non-empty subset of configured horizons {:?}",
                        config.research.horizons
                    );
                }

                let displayed_intervals = match (displayed_replay_start, displayed_replay_end) {
                    (Some(start), Some(end)) => vec![NamedEvaluationInterval {
                        name: "displayed_replay_or_external_test".into(),
                        role: "DISPLAYED_HISTORICAL_REPLAY_OR_EXTERNAL_TEST".into(),
                        start: parse_utc_timestamp(&start, "displayed_replay_start")?,
                        end: parse_utc_timestamp(&end, "displayed_replay_end")?,
                    }],
                    (None, None) => Vec::new(),
                    _ => bail!(
                        "--displayed-replay-start and --displayed-replay-end must be supplied together"
                    ),
                };

                let reference_universe = reference_registry
                    .as_ref()
                    .map(|registry| {
                        load_frozen_universe(registry, [&config.research.target]).with_context(
                            || {
                                format!(
                                    "load walk-forward reference registry {}",
                                    registry.display()
                                )
                            },
                        )
                    })
                    .transpose()?;
                if let Some(universe) = reference_universe.as_ref()
                    && !universe.failures().is_empty()
                {
                    bail!(
                        "walk-forward reference artifact failed closed: {:?}",
                        universe.failures()
                    );
                }
                let reference_artifact = reference_universe
                    .as_ref()
                    .and_then(|universe| universe.artifact(&config.research.target));
                if reference_registry.is_some() && reference_artifact.is_none() {
                    bail!(
                        "walk-forward reference registry has no exact artifact for {}",
                        config.research.target
                    );
                }

                let generated_at = Utc::now();
                let source_sha256 = capability
                    .normalized_file_sha256
                    .clone()
                    .context("verified training bars are missing their exact SHA-256")?;
                let lineage = OfflineValidationLineage {
                    generated_at,
                    source_path: imported.source_path.replace('\\', "/"),
                    source_sha256: source_sha256.clone(),
                    code_commit_hash: option_env!("GIT_COMMIT")
                        .unwrap_or("WORKTREE_UNCOMMITTED")
                        .into(),
                    displayed_replay_or_external_test_intervals: displayed_intervals,
                };
                let mut reports = Vec::with_capacity(requested_horizons.len());
                for horizon in &requested_horizons {
                    let validation =
                        OfflineValidationConfig::for_session_count(session_count, *horizon);
                    reports.push(evaluate_offline_frozen_model(
                        states,
                        &config.research,
                        &validation,
                        &lineage,
                        reference_artifact,
                    )?);
                }
                let successful_horizons = reports
                    .iter()
                    .filter(|report| {
                        report.status == "OFFLINE_VALIDATION_COMPLETE_RESEARCH_ONLY"
                            || report.status == "OFFLINE_VALIDATION_COMPLETE_HMM_OPTIMUM_UNRESOLVED"
                    })
                    .count();
                let suite_status = if successful_horizons == reports.len() {
                    "OFFLINE_VALIDATION_SUITE_COMPLETE_RESEARCH_ONLY"
                } else {
                    "OFFLINE_VALIDATION_SUITE_INSUFFICIENT_FAIL_CLOSED"
                };
                let mut payload = serde_json::json!({
                    "schema_version": "axio.offline-frozen-model-validation-suite.v1",
                    "generated_at": generated_at,
                    "status": suite_status,
                    "evidence_grade":
                        "PURGED_CHRONOLOGICAL_FOLD_TEST_RESEARCH_EVIDENCE_NOT_PROMOTION_EVIDENCE",
                    "promotion_status": "CANDIDATE_NOT_PROMOTED",
                    "automatic_promotion_permitted": false,
                    "production_artifact_or_config_mutated": false,
                    "execution_enabled": false,
                    "target": config.research.target,
                    "horizons_minutes": requested_horizons,
                    "successful_horizon_count": successful_horizons,
                    "source_path": imported.source_path.replace('\\', "/"),
                    "source_sha256": source_sha256,
                    "import_accounting": {
                        "input_rows": imported.input_rows,
                        "accepted_rows": imported.accepted_rows,
                        "rejected_rows": imported.rejected_rows,
                        "duplicate_rows": imported.duplicate_rows,
                    },
                    "feature_contract_config": feature_contract_source,
                    "reference_registry": reference_registry
                        .as_ref()
                        .map(|path| path.to_string_lossy().replace('\\', "/")),
                    "reports": reports,
                    "suite_sha256": "",
                });
                let suite_sha256 =
                    format!("{:x}", sha2::Sha256::digest(serde_json::to_vec(&payload)?));
                payload["suite_sha256"] = serde_json::Value::String(suite_sha256);
                write_json(&output, &payload)?;
                println!(
                    "walk_forward={} target={} horizons={} successful={} status={}",
                    output.display(),
                    config.research.target,
                    reports.len(),
                    successful_horizons,
                    suite_status
                );
            }
            PredictorCommand::RegimeCompetition { bars, output } => {
                let imported = MarketBarCsvImporter.import(&bars)?;
                let states = features::build_states(
                    &imported.records,
                    &config.research.target,
                    &config.research,
                )?;
                let report = axio_quant_engine::engine::regime_competition::evaluate(
                    &states,
                    &config.research.target,
                    &config.research.regime,
                )?;
                write_json(&output, &report)?;
                println!(
                    "regime_competition={} folds={} selected={} promotion_status={}",
                    output.display(),
                    report.fold_count,
                    report.selected_family.as_deref().unwrap_or("NONE"),
                    report.promotion_status
                );
            }
            PredictorCommand::Calibrate {
                input,
                fit_start,
                fit_end,
                oos_start,
                oos_end,
                valid_from,
                minimum_oos_samples,
                maximum_ece,
                output,
                report,
            } => {
                let mut reader = csv::Reader::from_path(&input)
                    .with_context(|| format!("open calibration OOF rows {}", input.display()))?;
                let observations = reader
                    .deserialize::<
                        axio_quant_engine::probability_calibration::CalibrationObservation,
                    >()
                    .collect::<std::result::Result<Vec<_>, _>>()
                    .with_context(|| format!("parse calibration OOF rows {}", input.display()))?;
                let fit_window = axio_quant_engine::probability_calibration::TimePartition {
                    start: parse_utc_timestamp(&fit_start, "fit_start")?,
                    end_exclusive: parse_utc_timestamp(&fit_end, "fit_end")?,
                };
                let oos_window = axio_quant_engine::probability_calibration::TimePartition {
                    start: parse_utc_timestamp(&oos_start, "oos_start")?,
                    end_exclusive: parse_utc_timestamp(&oos_end, "oos_end")?,
                };
                let valid_from = valid_from
                    .as_deref()
                    .map(|value| parse_utc_timestamp(value, "valid_from"))
                    .transpose()?
                    .unwrap_or_else(|| Utc::now() + Duration::minutes(1));
                let build =
                    axio_quant_engine::probability_calibration::materialize_oos_calibration_registry(
                        &observations,
                        fit_window,
                        oos_window,
                        valid_from,
                        minimum_oos_samples,
                        maximum_ece,
                    )?;
                write_json(&output, &build.registry)?;
                write_json(&report, &build)?;
                println!(
                    "calibration_registry={} report={} artifacts={} status=OOS_VALIDATED_AT_MOST_NOT_PROMOTED",
                    output.display(),
                    report.display(),
                    build.registry.artifacts.len()
                );
            }
            PredictorCommand::Forecast {
                bars,
                output,
                ledger,
                record_shadow,
            } => {
                let mut bundle = build_forecast_bundle(&bars, &config)?;
                if record_shadow {
                    let ledger = PredictionLedger::open(&ledger)?;
                    persist_canonical_predictions(&ledger, &mut bundle)?;
                }
                write_json(&output, &bundle)?;
                println!(
                    "forecast={} status={} horizons={} recorded={}",
                    output.display(),
                    bundle.status,
                    bundle.prediction_layer.len(),
                    record_shadow
                );
            }
            PredictorCommand::Settle {
                prediction_id,
                realized_reference_price,
                realized_log_return,
                realized_mfe,
                realized_mae,
                realized_volatility,
                barrier_outcome,
                ledger,
            } => {
                let ledger = PredictionLedger::open(&ledger)?;
                let settled_at = Utc::now();
                let mut settlement = ForecastSettlement {
                    settlement_id: uuid::Uuid::new_v4().to_string(),
                    prediction_id: prediction_id.clone(),
                    settled_at,
                    realized_reference_price,
                    realized_log_return,
                    realized_direction: if realized_log_return > 0.0 {
                        1
                    } else if realized_log_return < 0.0 {
                        -1
                    } else {
                        0
                    },
                    realized_mfe,
                    realized_mae,
                    realized_volatility,
                    barrier_outcome,
                    data_status: "MANUAL_SETTLEMENT".into(),
                    source_bar_ids: Vec::new(),
                    settlement_available_timestamp: settled_at,
                    settlement_hash: String::new(),
                    executable_entry: None,
                    executable_exit: None,
                    spread_cost: None,
                    slippage: None,
                    fees: None,
                    hypothetical_pnl: None,
                    evidence_kind: "manual_settlement_observation".into(),
                };
                settlement.settlement_hash = settlement_content_hash(&settlement)?;
                let settlement = ledger.append_settlement(&settlement)?;
                println!("{}", serde_json::to_string_pretty(&settlement)?);
            }
            PredictorCommand::SettlePending { ledger, bars } => {
                let ledger = PredictionLedger::open(&ledger)?;
                let settlements = live::settle_pending(&ledger, &bars)?;
                println!(
                    "{}",
                    serde_json::to_string_pretty(&serde_json::json!({
                        "status":"SETTLEMENT_SCAN_COMPLETE",
                        "settled":settlements.len(),
                        "settlements":settlements
                    }))?
                );
            }
            PredictorCommand::Report { ledger } | PredictorCommand::ShadowStatus { ledger } => {
                println!(
                    "{}",
                    serde_json::to_string_pretty(
                        &PredictionLedger::open(&ledger)?.shadow_status()?
                    )?
                );
            }
        },
        Command::Research(args) => match args.command {
            ResearchCommand::Backtest { bars, output } => {
                let started = Instant::now();
                let report = run_csv_research(&bars, &config.research)?;
                if let Some(parent) = output.parent() {
                    std::fs::create_dir_all(parent)?;
                }
                std::fs::write(&output, serde_json::to_vec_pretty(&report)?)?;
                println!(
                    "report={} elapsed_ms={} trades={} evidence={}",
                    output.display(),
                    started.elapsed().as_millis(),
                    report.trades.len(),
                    report.evidence_tier
                );
            }
            ResearchCommand::MassiveRun {
                from,
                to,
                symbols,
                bars,
                output,
            } => {
                let started = Instant::now();
                let override_symbols = (!symbols.is_empty()).then_some(symbols);
                let receipt = axio_quant_engine::data::massive::sync(
                    &config.data,
                    from,
                    to,
                    override_symbols,
                    &bars,
                )
                .await?;
                let report = run_csv_research(&bars, &config.research)?;
                if let Some(parent) = output.parent() {
                    std::fs::create_dir_all(parent)?;
                }
                std::fs::write(&output, serde_json::to_vec_pretty(&report)?)?;
                println!(
                    "sync_rows={} report={} elapsed_ms={} trades={} effects_tested={} evidence={}",
                    receipt.rows,
                    output.display(),
                    started.elapsed().as_millis(),
                    report.trades.len(),
                    report.time_bucket_effects.len(),
                    report.evidence_tier
                );
            }
            ResearchCommand::PatternDiscover {
                bars,
                horizon,
                windows,
                maximum_candidates_per_window,
                output,
            } => {
                let started = Instant::now();
                let imported = MarketBarCsvImporter.import(&bars)?;
                let states = features::build_states(
                    &imported.records,
                    &config.research.target,
                    &config.research,
                )?;
                drop(imported);
                let factory_config = PatternFactoryConfig {
                    window_observations: windows,
                    outcome_horizon_minutes: horizon,
                    maximum_candidates_per_window,
                    round_trip_cost_bps: 2.0 * config.os.spread_bps + 2.0 * config.os.slippage_bps,
                    random_seed: config.os.random_seed,
                    ..PatternFactoryConfig::default()
                };
                let report = run_autonomous_pattern_factory(&states, &factory_config)?;
                write_json(&output, &report)?;
                println!(
                    "pattern_report={} elapsed_ms={} hypotheses={} fdr_survivors={} current_matches={} promotion_ceiling={}",
                    output.display(),
                    started.elapsed().as_millis(),
                    report.hypothesis_family_size,
                    report.fdr_survivors,
                    report.current_matches,
                    report.promotion_ceiling
                );
            }
            ResearchCommand::Ablation {
                bars,
                horizon,
                output,
            }
            | ResearchCommand::NegativeControls {
                bars,
                horizon,
                output,
            } => {
                let imported = MarketBarCsvImporter.import(&bars)?;
                let states = features::build_states(
                    &imported.records,
                    &config.research.target,
                    &config.research,
                )?;
                let outcomes =
                    axio_quant_engine::engine::labels::forward_outcomes(&states, horizon);
                let report =
                    axio_quant_engine::engine::validation::evaluate(&states, &outcomes, horizon);
                write_json(&output, &report)?;
                println!(
                    "validation_report={} folds={} status={}",
                    output.display(),
                    report.fold_count,
                    report.status
                );
            }
            ResearchCommand::RegimeFit {
                bars,
                states,
                state_candidates,
                iterations,
                restarts,
                output,
            } => {
                let imported = MarketBarCsvImporter.import(&bars)?;
                let market_states = features::build_states(
                    &imported.records,
                    &config.research.target,
                    &config.research,
                )?;
                let mut sessions = BTreeMap::<NaiveDate, Vec<Vec<f64>>>::new();
                for state in market_states.iter().filter(|state| {
                    state.minute_in_5m_bucket == 4 && state.completed_5m_bucket_valid
                }) {
                    sessions.entry(state.session_date).or_default().push(vec![
                        state.active_5m_return,
                        state.dist_vwap,
                        state.rolling_realized_vol,
                        state.volume_zscore,
                    ]);
                }
                let dates = sessions.keys().copied().collect::<Vec<_>>();
                let sequences = sessions.values().cloned().collect::<Vec<_>>();
                let latest = sequences
                    .last()
                    .context("no finalized five-minute observations")?;
                let prior = sequences
                    .get(..sequences.len().saturating_sub(1))
                    .context("regime selection requires prior sessions")?;
                let candidates = states
                    .map(|states| vec![states])
                    .unwrap_or(state_candidates);
                let requested_validation = ((prior.len() as f64)
                    * config.research.regime.validation_fraction)
                    .ceil() as usize;
                let validation_session_count = requested_validation
                    .max(config.research.regime.minimum_validation_sessions)
                    .min(prior.len().saturating_sub(1));
                let use_validation = validation_session_count
                    >= config.research.regime.minimum_validation_sessions
                    && prior.len() > validation_session_count;
                let fit_end = if use_validation {
                    prior.len() - validation_session_count
                } else {
                    prior.len()
                };
                let fit_sequences = &prior[..fit_end];
                let validation_sequences = if use_validation {
                    &prior[fit_end..]
                } else {
                    &[][..]
                };
                let selection = select_hmm_candidates(
                    fit_sequences,
                    use_validation.then_some(validation_sequences),
                    &candidates,
                    iterations,
                    restarts,
                    config.research.regime.minimum_state_occupancy_fraction,
                    config.research.regime.minimum_state_expected_observations,
                )?;
                let selected_states = selection.selected_state_count;
                let selection_method = selection.selection_method;
                let selected_at_candidate_boundary = selection.selected_at_candidate_boundary;
                let eight_state_assessment = selection
                    .candidate_assessments
                    .iter()
                    .find(|assessment| assessment.state_count == 8);
                let eight_state_status = if selected_states == 8 {
                    "SELECTED_BY_CHRONOLOGICAL_MODEL_SELECTION"
                } else if eight_state_assessment.is_some_and(|assessment| assessment.eligible) {
                    "EVALUATED_NOT_SELECTED"
                } else if eight_state_assessment.is_some() {
                    "EVALUATED_REJECTED_BY_OCCUPANCY_OR_SCORE"
                } else {
                    "FIT_FAILED_OR_INSUFFICIENT_OBSERVATIONS"
                };
                let candidate_scores = selection
                    .candidate_assessments
                    .iter()
                    .map(|assessment| serde_json::json!({
                        "states": assessment.state_count,
                        "training_bic": assessment.training_bic,
                        "validation_average_log_likelihood": assessment.validation_average_log_likelihood,
                        "fit_minimum_state_occupancy_fraction": assessment.fit_minimum_state_occupancy_fraction,
                        "validation_minimum_state_occupancy_fraction": assessment.validation_minimum_state_occupancy_fraction,
                        "fit_minimum_state_expected_observations": assessment.fit_minimum_state_expected_observations,
                        "validation_minimum_state_expected_observations": assessment.validation_minimum_state_expected_observations,
                        "occupancy_eligible": assessment.eligible,
                        "status": assessment.status,
                    }))
                    .collect::<Vec<_>>();
                // Refit only on completed sessions strictly before the current
                // session. The current session is inference-only.
                let model = GaussianHmm::fit(prior, selected_states, iterations, restarts)?;
                validate_hmm_state_occupancy(
                    &model,
                    prior,
                    config.research.regime.minimum_state_occupancy_fraction,
                    config.research.regime.minimum_state_expected_observations,
                )
                .context("refitted regime HMM failed the state-occupancy contract")?;
                let (model, _) = model.canonicalized();
                let filtered = model.filtered_probabilities(latest)?;
                let current = filtered.last().context("empty latest session")?;
                let next = model.next_state_probabilities(current)?;
                let state_output = axio_quant_engine::market_state::infer_filtered(&model, latest)?;
                let latest_completed_state = market_states
                    .iter()
                    .rfind(|state| {
                        state.session_date == *dates.last().unwrap()
                            && state.minute_in_5m_bucket == 4
                            && state.completed_5m_bucket_valid
                    })
                    .context("latest finalized HMM observation has no market timestamp")?;
                let state_as_of = latest_completed_state.timestamp + Duration::minutes(1);
                let maximum_same_session_transitions =
                    (latest_completed_state.minutes_to_close.max(0) as usize) / 5;
                let horizon_state_forecasts =
                    axio_quant_engine::market_state::forecast_same_session_horizons(
                        &model,
                        current,
                        &[1, 3, 6, 12],
                        maximum_same_session_transitions,
                    )?;
                let horizon_state_forecast_rows = horizon_state_forecasts
                    .iter()
                    .map(|forecast| {
                        serde_json::json!({
                            "horizon_steps": forecast.transitions_ahead,
                            "horizon_minutes": forecast.transitions_ahead * 5,
                            "status": forecast.status,
                            "endpoint_state_probabilities": forecast.endpoint_state_probabilities,
                            "dominant_raw_state_id": forecast.dominant_raw_state_id,
                            "dominant_probability": forecast.dominant_probability,
                            "endpoint_entropy": forecast.endpoint_entropy,
                            "normalized_endpoint_entropy": forecast.normalized_endpoint_entropy,
                            "posterior_weighted_no_state_change_probability": forecast.posterior_weighted_no_state_change_probability,
                            "probability_semantics": forecast.probability_semantics,
                        })
                    })
                    .collect::<Vec<_>>();
                let transition_audit =
                    axio_quant_engine::market_state::transition_audit(&model, prior)?;
                let tvtp_challenger = tvtp_challenger_report(
                    &market_states,
                    &dates,
                    &model,
                    TvtpChallengerConfig {
                        fit_end,
                        use_validation,
                        selected_states,
                        hmm_iterations: iterations,
                        hmm_restarts: restarts,
                    },
                )
                .unwrap_or_else(|error| {
                    tvtp_unavailable_report(
                        vec![
                            "TVTP_CHALLENGER_UNAVAILABLE".into(),
                            "TVTP_ALIGNMENT_FIT_OR_SCORING_FAILED".into(),
                        ],
                        Some(error.to_string()),
                    )
                });
                // The live/current session is inference-only and is excluded from
                // every historical train/validation/test partition.
                let historical_dates = &dates[..dates.len().saturating_sub(1)];
                let initial_train_days = historical_dates.len() / 2;
                let validation_days = historical_dates.len() / 5;
                let test_days = historical_dates.len() / 5;
                let forward_fold = if initial_train_days == 0
                    || validation_days == 0
                    || test_days == 0
                {
                    serde_json::json!({
                        "status": "UNAVAILABLE_INSUFFICIENT_PURGED_CHRONOLOGICAL_SESSIONS",
                        "evidence_grade": "UNAVAILABLE",
                        "selection_scope": "NONE",
                        "test_untouched": true,
                        "test_excluded_from_fit_and_selection": true,
                        "validation_average_log_likelihood": serde_json::Value::Null,
                        "test_average_log_likelihood": serde_json::Value::Null,
                        "reason": "NOT_ENOUGH_COMPLETED_PRIOR_SESSIONS_FOR_NON_OVERLAPPING_TRAIN_VALIDATION_TEST"
                    })
                } else {
                    walk_forward::expanding_day_folds(
                        historical_dates,
                        initial_train_days,
                        validation_days,
                        test_days,
                        1,
                        1,
                    )
                    .into_iter()
                    .last()
                    .map(|fold| -> Result<serde_json::Value> {
                        let train_days =
                            fold.train_days.iter().copied().collect::<BTreeSet<_>>();
                        let validation_days = fold
                            .validation_days
                            .iter()
                            .copied()
                            .collect::<BTreeSet<_>>();
                        let test_days =
                            fold.test_days.iter().copied().collect::<BTreeSet<_>>();
                        if !train_days.is_disjoint(&validation_days)
                            || !train_days.is_disjoint(&test_days)
                            || !validation_days.is_disjoint(&test_days)
                        {
                            bail!("purged forward fold partitions overlap");
                        }
                        let select = |wanted: &BTreeSet<NaiveDate>| {
                            sessions
                                .iter()
                                .filter(|(date, _)| wanted.contains(date))
                                .map(|(_, sequence)| sequence.clone())
                                .collect::<Vec<_>>()
                        };
                        let train = select(&train_days);
                        let validation = select(&validation_days);
                        let test = select(&test_days);
                        if test.iter().all(Vec::is_empty) {
                            bail!("purged forward fold requires untouched test observations");
                        }
                        let selected = select_hmm_within_forward_fold(
                            &train,
                            &validation,
                            &candidates,
                            config.research.regime.minimum_validation_sessions,
                            iterations,
                            restarts,
                            HmmOccupancyPolicy {
                                minimum_fraction: config
                                    .research
                                    .regime
                                    .minimum_state_occupancy_fraction,
                                minimum_expected_observations: config
                                    .research
                                    .regime
                                    .minimum_state_expected_observations,
                            },
                        )?;
                        let validation_average_log_likelihood = selected
                            .model
                            .average_log_likelihood(&validation)
                            .context("selected train-fitted HMM could not score fold validation")?;
                        let test_average_log_likelihood = selected
                            .model
                            .average_log_likelihood(&test)
                            .context("selected train-fitted HMM could not score untouched fold test")?;
                        let fold_candidate_scores = selected
                            .candidate_scores
                            .iter()
                            .map(|score| {
                                serde_json::json!({
                                    "states": score.state_count,
                                    "training_bic": score.training_bic,
                                    "validation_average_log_likelihood": score.validation_average_log_likelihood,
                                    "fit_minimum_state_occupancy_fraction": score.fit_minimum_state_occupancy_fraction,
                                    "validation_minimum_state_occupancy_fraction": score.validation_minimum_state_occupancy_fraction,
                                    "fit_minimum_state_expected_observations": score.fit_minimum_state_expected_observations,
                                    "validation_minimum_state_expected_observations": score.validation_minimum_state_expected_observations,
                                    "occupancy_eligible": score.eligible,
                                    "status": score.status,
                                })
                            })
                            .collect::<Vec<_>>();
                        Ok(serde_json::json!({
                            "status": "AVAILABLE_UNTOUCHED_CHRONOLOGICAL_TEST",
                            "evidence_grade": "EXPLORATORY_SINGLE_FOLD_NOT_PROMOTION_EVIDENCE",
                            "train_start": fold.train_days.first(),
                            "train_end": fold.train_days.last(),
                            "purged_days": fold.purged_days,
                            "validation_start": fold.validation_days.first(),
                            "validation_end": fold.validation_days.last(),
                            "embargoed_days": fold.embargoed_days,
                            "test_start": fold.test_days.first(),
                            "test_end": fold.test_days.last(),
                            "selected_states": selected.selected_states,
                            "candidate_scores": fold_candidate_scores,
                            "selection_method": selected.selection_method,
                            "selection_scope": "FOLD_TRAIN_FIT_WITH_FOLD_VALIDATION_FOR_K_ONLY; TEST_EXCLUDED",
                            "model_training_scope": "FOLD_TRAIN_ONLY",
                            "validation_sessions": selected.validation_sessions,
                            "validation_used_for_selection": selected.validation_used_for_selection,
                            "validation_average_log_likelihood": validation_average_log_likelihood,
                            "validation_score_role": if selected.validation_used_for_selection { "K_SELECTION_SCORE_NOT_AN_INDEPENDENT_TEST" } else { "DIAGNOSTIC_ONLY_NOT_USED_FOR_SELECTION" },
                            "test_average_log_likelihood": test_average_log_likelihood,
                            "test_score_role": "UNTOUCHED_AFTER_K_SELECTION",
                            "test_untouched": true,
                            "test_untouched_semantics": "TEST_FIRST_ACCESSED_AFTER_K_SELECTION_AND_TRAIN_PARAMETER_FREEZE",
                            "test_excluded_from_fit_and_selection": true,
                            "parameters_frozen_after_train": true,
                            "refit_on_train_plus_validation": false,
                        }))
                    })
                    .transpose()?
                    .unwrap_or_else(|| {
                        serde_json::json!({
                            "status": "UNAVAILABLE_NO_PURGED_FORWARD_FOLD",
                            "evidence_grade": "UNAVAILABLE",
                            "selection_scope": "NONE",
                            "test_untouched": true,
                            "test_excluded_from_fit_and_selection": true,
                            "validation_average_log_likelihood": serde_json::Value::Null,
                            "test_average_log_likelihood": serde_json::Value::Null,
                            "reason": "PURGE_EMBARGO_AND_PARTITION_LENGTHS_LEFT_NO_VALID_FOLD"
                        })
                    })
                };
                let next_state_probability =
                    (maximum_same_session_transitions >= 1).then(|| next.clone());
                let next_state_probability_status = if next_state_probability.is_some() {
                    "AVAILABLE_SAME_SESSION"
                } else {
                    "UNAVAILABLE_CROSSES_SESSION_BOUNDARY"
                };
                let state_contract = serde_json::json!({
                    "state_definition": {
                        "cadence_minutes": 5,
                        "session_reset": true,
                        "cross_session_model_available": false,
                        "state_identity": "LATENT_HMM_STATE_WITH_TRAIN_ONLY_SEMANTIC_MAPPING",
                    },
                    "current_filtered_probability": current,
                    "next_state_probability": next_state_probability,
                    "next_state_probability_status": next_state_probability_status,
                    "one_step_model_implied_state_probability": next,
                    "horizon_state_forecasts": horizon_state_forecast_rows,
                    "cross_session_state_forecast": {
                        "status": "UNAVAILABLE_REQUIRES_SEPARATELY_VALIDATED_OVERNIGHT_MODEL",
                        "today_to_tomorrow_claim_supported": false,
                    },
                    "transition_audit": transition_audit,
                    "raw_state_certainty": state_output.raw_state_certainty,
                    "one_step_change_probability": state_output.probability_of_regime_change,
                    "transition_row_normalized_entropy": state_output.transition_row_normalized_entropy,
                    "duration_diagnostics": {
                        "duration_model": state_output.duration_model,
                        "untruncated_geometric_diagnostic": state_output.untruncated_geometric_diagnostic,
                        "expected_spell_observations_including_current": state_output.expected_regime_duration_observations,
                        "expected_future_self_transitions": state_output.expected_future_self_transitions,
                        "observation_minutes": 5,
                        "session_close_truncation_applied": false,
                        "must_not_extrapolate_past_session_close": true,
                        "semantics": state_output.duration_semantics,
                    },
                    "decision_boundary": {
                        "forecast_conditioning_role": "DESCRIPTIVE_MODEL_CONTEXT",
                        "direct_allocation_impact": true,
                        "continuous_sizing_impact": false,
                        "hard_no_trade_veto_impact": true,
                        "allocation_impact_semantics": "NORMALIZED_REGIME_ENTROPY_CAN_ONLY_TRIGGER_A_HARD_NO_TRADE_VETO; IT_DOES_NOT_SCALE_POSITION_SIZE",
                        "execution_eligible": false,
                        "confidence_semantics": "RAW_STATE_CERTAINTY_IS_NOT_RETURN_CONFIDENCE",
                    },
                    "latest_input_available_at": serde_json::Value::Null,
                    "input_availability_status": "UNAVAILABLE_IN_NORMALIZED_REGIME_FIT_INPUT",
                });
                let model_selection_report = serde_json::json!({
                    "candidate_states": candidates,
                    "selected_states": selected_states,
                    "criterion": selection_method,
                    "fit_sessions": fit_end,
                    "validation_sessions": if use_validation { validation_session_count } else { 0 },
                    "minimum_state_occupancy_fraction": config.research.regime.minimum_state_occupancy_fraction,
                    "minimum_state_expected_observations": config.research.regime.minimum_state_expected_observations,
                    "occupancy_semantics": "CAUSAL_FILTERED_POSTERIOR_EXPECTED_MASS_NOT_HARD_STATE_COUNT",
                    "candidate_scores": candidate_scores,
                    "eight_state_challenger_status": eight_state_status,
                    "selected_at_candidate_boundary": selected_at_candidate_boundary,
                    "selection_warning": if selected_at_candidate_boundary { Some("BEST_VALIDATION_SCORE_IS_AT_MAXIMUM_TESTED_K; STATE_COUNT_OPTIMUM_IS_NOT_ESTABLISHED") } else { None }
                });
                let model_artifact = serde_json::to_value(&model)?;
                let model_artifact_bytes = serde_json::to_vec(&model_artifact)?;
                let model_artifact_sha256 =
                    format!("{:x}", sha2::Sha256::digest(&model_artifact_bytes));
                let mut report = serde_json::json!({
                    "schema_version": "axio.regime-artifact.v2",
                    "model": "diagonal_gaussian_hmm",
                    "hmm_numerics_version": "LOG_SPACE_FORWARD_BACKWARD_V1",
                    "evidence": "exploratory_regime_diagnostic_not_a_trading_result",
                    "source": bars,
                    "as_of": state_as_of,
                    "states": model.states,
                    "dimensions": ["ret_5m", "dist_session_vwap", "realized_vol", "volume_zscore"],
                    "sessions": sequences.len(),
                    "observations": sequences.iter().map(Vec::len).sum::<usize>(),
                    "trained_through": dates.get(dates.len().saturating_sub(2)),
                    "current_session": dates.last(),
                    "model_selection": model_selection_report,
                    "log_likelihood": model.log_likelihood,
                    "bic": model.bic,
                    "transition": model.transition,
                    "standardized_means": model.means,
                    "standardized_variances": model.variances,
                    "regime_entropy": state_output.regime_entropy,
                    "normalized_regime_entropy": state_output.normalized_regime_entropy,
                    "dominant_raw_state_id": state_output.dominant_raw_state_id,
                    "dominant_state_name": state_output.dominant_state_name,
                    "state_profiles": state_output.profiles,
                    "state_feature_schema": state_output.state_feature_schema,
                    "state_feature_schema_sha256": state_output.state_feature_schema_sha256,
                    "model_artifact": model_artifact,
                    "model_artifact_sha256": model_artifact_sha256,
                    "model_validation_status": state_output.model_validation_status,
                    "probability_semantics": state_output.probability_semantics,
                    "tvtp_challenger": tvtp_challenger,
                    "purged_forward_validation": forward_fold,
                    "causality": "filter uses observations available through the latest finalized 5m bar; no smoothed future state"
                });
                report
                    .as_object_mut()
                    .context("regime report root must be a JSON object")?
                    .extend(
                        state_contract
                            .as_object()
                            .context("state contract must be a JSON object")?
                            .clone(),
                    );
                if let Some(parent) = output.parent() {
                    std::fs::create_dir_all(parent)?;
                }
                std::fs::write(&output, serde_json::to_vec_pretty(&report)?)?;
                println!("regime_report={} bic={:.6}", output.display(), model.bic);
            }
        },
        Command::Ledger(args) => {
            let ledger = Ledger::open(&args.database)?;
            println!(
                "{}",
                serde_json::to_string_pretty(&serde_json::json!({
                    "database": args.database,
                    "unbalanced_transactions": ledger.unbalanced_transaction_count()?,
                    "status": "append_only_double_entry"
                }))?
            );
        }
        Command::Bench => {
            let started = Instant::now();
            let mut checksum = 0.0;
            for idx in 1..=5_000_000_u64 {
                checksum += ((idx as f64).ln_1p() * 1e-9).sin();
            }
            println!(
                "rust_hot_loop iterations=5000000 elapsed_ms={} checksum={checksum:.8}",
                started.elapsed().as_millis()
            );
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use std::{
        ffi::{OsStr, OsString},
        path::{Path, PathBuf},
    };

    use axio_quant_engine::domain::MarketState;
    use chrono::{Duration, NaiveDate, TimeZone, Utc};
    use clap::Parser;

    use super::{
        Cli, Command, DEFAULT_UNIVERSE_OUTPUT_DIR, DEFAULT_UNIVERSE_REGISTRY, DataArgs,
        DataCommand, HmmOccupancyPolicy, LiveArgs, LiveCommand, PredictorArgs, PredictorCommand,
        TVTP_COVARIATE_SCHEMA, finalized_tvtp_sequences, owner_relay_url, quote_bridge_command,
        select_hmm_within_forward_fold, train_universe_destinations, tvtp_unavailable_report,
    };

    fn arguments(command: &std::process::Command) -> Vec<OsString> {
        command.get_args().map(OsStr::to_os_string).collect()
    }

    #[test]
    fn seal_training_lineage_cli_contract() {
        let cli = Cli::try_parse_from([
            "quantctl",
            "data",
            "seal-training-lineage",
            "--bars",
            "data/normalized/market_bars.csv",
            "--source",
            "data/raw/part-000.dbn.zst",
            "--source",
            "data/raw/part-001.dbn.zst",
            "--provider",
            "databento",
            "--product",
            "EQUS.MINI",
            "--adjustment-status",
            "vendor-adjusted",
            "--output",
            "data/manifests/normalized_market_bars_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.json",
        ])
        .unwrap();
        match cli.command {
            Command::Data(DataArgs {
                command:
                    DataCommand::SealTrainingLineage {
                        bars,
                        sources,
                        provider,
                        product,
                        adjustment_status,
                        output,
                    },
            }) => {
                assert_eq!(
                    bars.as_deref(),
                    Some(Path::new("data/normalized/market_bars.csv"))
                );
                assert_eq!(sources.len(), 2);
                assert_eq!(provider, "databento");
                assert_eq!(product, "EQUS.MINI");
                assert_eq!(adjustment_status, "vendor-adjusted");
                assert_eq!(
                    output,
                    Path::new(
                        "data/manifests/normalized_market_bars_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.json"
                    )
                );
            }
            _ => panic!("expected seal-training-lineage command"),
        }

        let help = Cli::try_parse_from(["quantctl", "data", "seal-training-lineage", "--help"])
            .unwrap_err()
            .to_string();
        for required in [
            "--bars",
            "--source",
            "--provider",
            "--product",
            "--adjustment-status",
            "--output",
            "AXIO7_MARKET_DATA_RIGHTS_RECEIPT_SHA256",
            "data/rights/market_data_rights_receipt.json",
            "normalized_market_bars_<bars-sha256>.json",
        ] {
            assert!(help.contains(required), "help omitted {required}: {help}");
        }
    }

    #[test]
    fn owner_relay_url_accepts_https() {
        let url = owner_relay_url("https://axio7.com/api/market/moomoo/relay")
            .expect("HTTPS is required");

        assert_eq!(url.scheme(), "https");
        assert_eq!(url.host_str(), Some("axio7.com"));
    }

    #[test]
    fn owner_relay_url_accepts_loopback_http() {
        for raw in [
            "http://127.0.0.1:3000/api/market/moomoo/relay",
            "http://localhost:3000/api/market/moomoo/relay",
            "http://[::1]:3000/api/market/moomoo/relay",
        ] {
            assert!(owner_relay_url(raw).is_ok(), "{raw} should be accepted");
        }
    }

    #[test]
    fn owner_relay_url_rejects_remote_http() {
        let error = owner_relay_url("http://axio7.com/api/market/moomoo/relay")
            .expect_err("remote HTTP must fail closed");

        assert!(error.to_string().contains("must use HTTPS"));
    }

    #[test]
    fn owner_relay_url_rejects_embedded_credentials() {
        let error =
            owner_relay_url("https://relay-user:relay-password@axio7.com/api/market/moomoo/relay")
                .expect_err("URL credentials must not be accepted");

        assert!(error.to_string().contains("must not contain credentials"));
    }

    #[test]
    fn replay_defaults_never_write_live_artifacts() {
        let cli = Cli::try_parse_from([
            "quantctl",
            "live",
            "moomoo-replay",
            "--input",
            "fixture.jsonl",
        ])
        .unwrap();
        match cli.command {
            Command::Live(LiveArgs {
                command:
                    LiveCommand::Replay {
                        output,
                        forecast_output,
                        ..
                    },
            }) => {
                assert_eq!(output, Path::new("data/replay/moomoo_finalized_bars.jsonl"));
                assert_eq!(
                    forecast_output,
                    Path::new("data/reports/forecast_contract_owner_replay_latest.json")
                );
            }
            _ => panic!("expected Moomoo replay command"),
        }
    }

    #[test]
    fn train_universe_v1_keeps_legacy_defaults() {
        let cli = Cli::try_parse_from(["quantctl", "predictor", "train-universe"]).unwrap();
        match cli.command {
            Command::Predictor(PredictorArgs {
                command:
                    PredictorCommand::TrainUniverse {
                        output_dir,
                        registry,
                        feature_contract_config,
                        ..
                    },
            }) => {
                assert!(output_dir.is_none());
                assert!(registry.is_none());
                assert!(feature_contract_config.is_none());
                let root = tempfile::tempdir().unwrap();
                let (output_dir, registry) =
                    train_universe_destinations(root.path(), None, None, false).unwrap();
                assert_eq!(output_dir, Path::new(DEFAULT_UNIVERSE_OUTPUT_DIR));
                assert_eq!(registry, Path::new(DEFAULT_UNIVERSE_REGISTRY));
            }
            _ => panic!("expected predictor train-universe command"),
        }
    }

    #[test]
    fn explicit_feature_candidate_requires_disjoint_bundle_paths() {
        let root = tempfile::tempdir().unwrap();
        assert!(
            train_universe_destinations(root.path(), None, None, true)
                .unwrap_err()
                .to_string()
                .contains("explicit separate --output-dir")
        );
        assert!(
            train_universe_destinations(
                root.path(),
                Some(PathBuf::from(DEFAULT_UNIVERSE_OUTPUT_DIR)),
                Some(PathBuf::from(DEFAULT_UNIVERSE_REGISTRY)),
                true,
            )
            .unwrap_err()
            .to_string()
            .contains("must be disjoint")
        );
        if cfg!(windows) {
            assert!(
                train_universe_destinations(
                    root.path(),
                    Some(PathBuf::from("data/models/UNIVERSE")),
                    Some(PathBuf::from("data/models/UNIVERSE/candidate.json")),
                    true,
                )
                .unwrap_err()
                .to_string()
                .contains("must be disjoint")
            );
        }
        assert!(
            train_universe_destinations(
                root.path(),
                Some(PathBuf::from("data/models")),
                Some(PathBuf::from("data/models/candidate-registry.json")),
                true,
            )
            .unwrap_err()
            .to_string()
            .contains("must be disjoint")
        );
        assert!(
            train_universe_destinations(
                root.path(),
                Some(PathBuf::from("data/models/no-uup-v2")),
                Some(PathBuf::from("data/reports/no-uup-v2-registry.json")),
                true,
            )
            .unwrap_err()
            .to_string()
            .contains("must be inside")
        );

        let expected_output = PathBuf::from("data/models/no-uup-v2");
        let expected_registry = expected_output.join("registry.json");
        let (output, registry) = train_universe_destinations(
            root.path(),
            Some(expected_output.clone()),
            Some(expected_registry.clone()),
            true,
        )
        .unwrap();
        assert_eq!(output, expected_output);
        assert_eq!(registry, expected_registry);
    }

    fn finalized_regime_state(
        timestamp: chrono::DateTime<Utc>,
        session_date: NaiveDate,
        bucket: i32,
        seed: f64,
    ) -> MarketState {
        let minutes_from_open = 4 + bucket * 5;
        MarketState {
            timestamp,
            session_date,
            symbol: "SPY".into(),
            open: 100.0,
            high: 101.0,
            low: 99.0,
            close: 100.0 + seed,
            atr: 1.0,
            ret_1m: seed * 0.001,
            ret_3m: seed * 0.002,
            ret_5m: seed * 0.003,
            ret_15m: seed * 0.004,
            ret_30m: seed * 0.005,
            ret_60m: seed * 0.006,
            active_5m_return: seed * 0.007,
            last_completed_5m_return: seed * 0.006,
            last_completed_15m_return: seed * 0.005,
            slope_15m: seed * 0.001,
            dist_vwap: seed * 0.002,
            dist_session_open: seed * 0.002,
            rolling_realized_vol: 0.01 + seed.abs() * 0.001,
            normalized_range: 0.01,
            upper_wick_ratio: 0.2,
            lower_wick_ratio: 0.2,
            close_location_value: 0.5,
            distance_session_high: -0.01,
            distance_session_low: 0.01,
            failed_opening_breakout: 0.0,
            consecutive_up_bars: 1,
            consecutive_down_bars: 0,
            return_acceleration: seed * 0.001,
            volume_zscore: seed * 0.1,
            volume_acceleration: seed * 0.01,
            session_range_position: 0.5,
            cross_asset_breadth_score: seed.signum() * 0.5,
            risk_rotation_score: seed * 0.0005,
            market_confirmation_score: 0.5,
            cross_asset_context_complete: true,
            cross_asset_context_coverage: 1.0,
            closing_short_cover_score: 0.0,
            rvol_same_minute: 1.0,
            minutes_from_open,
            minutes_to_close: 390 - minutes_from_open,
            bucket_5m: bucket,
            bucket_15m: bucket / 3,
            minute_in_5m_bucket: 4,
            completed_5m_bucket_valid: true,
            continuous_minute_count: (minutes_from_open + 1) as usize,
        }
    }

    fn synthetic_hmm_sequence(offset: f64) -> Vec<Vec<f64>> {
        (0..24)
            .map(|index| {
                let phase = if index % 2 == 0 { -1.0 } else { 1.0 };
                vec![offset + 0.2 * phase, 0.5 * phase]
            })
            .collect()
    }

    #[test]
    fn forward_fold_k_selection_keeps_parameters_train_only() {
        let train = vec![
            synthetic_hmm_sequence(-0.6),
            synthetic_hmm_sequence(-0.2),
            synthetic_hmm_sequence(0.2),
            synthetic_hmm_sequence(0.6),
        ];
        let validation = vec![synthetic_hmm_sequence(-50.0), synthetic_hmm_sequence(51.0)];

        let selection = select_hmm_within_forward_fold(
            &train,
            &validation,
            &[2],
            2,
            5,
            1,
            HmmOccupancyPolicy {
                minimum_fraction: 0.001,
                minimum_expected_observations: 1.0,
            },
        )
        .unwrap();
        let train_sum = train.iter().flatten().map(|row| row[0]).sum::<f64>();
        let train_observations = train.iter().map(Vec::len).sum::<usize>();
        let validation_sum = validation.iter().flatten().map(|row| row[0]).sum::<f64>();
        let validation_observations = validation.iter().map(Vec::len).sum::<usize>();
        let train_mean = train_sum / train_observations as f64;
        let train_plus_validation_mean =
            (train_sum + validation_sum) / (train_observations + validation_observations) as f64;

        assert!(selection.validation_used_for_selection);
        assert_eq!(
            selection.selection_method,
            "MAX_VALIDATION_AVERAGE_LOG_LIKELIHOOD_AMONG_OCCUPANCY_ELIGIBLE_CANDIDATES"
        );
        assert_eq!(selection.selected_states, 2);
        assert!((selection.model.center[0] - train_mean).abs() < 1.0e-12);
        assert!((selection.model.center[0] - train_plus_validation_mean).abs() > 0.1);
        assert!(
            selection.candidate_scores[0]
                .validation_average_log_likelihood
                .is_some()
        );
    }

    #[test]
    fn forward_fold_k_selection_uses_train_bic_when_validation_is_insufficient() {
        let train = vec![
            synthetic_hmm_sequence(-0.6),
            synthetic_hmm_sequence(-0.2),
            synthetic_hmm_sequence(0.2),
            synthetic_hmm_sequence(0.6),
        ];
        let validation = vec![synthetic_hmm_sequence(1.0)];

        let selection = select_hmm_within_forward_fold(
            &train,
            &validation,
            &[2, 3],
            2,
            5,
            1,
            HmmOccupancyPolicy {
                minimum_fraction: 0.001,
                minimum_expected_observations: 1.0,
            },
        )
        .unwrap();

        assert!(!selection.validation_used_for_selection);
        assert_eq!(
            selection.selection_method,
            "MIN_TRAIN_BIC_AMONG_OCCUPANCY_ELIGIBLE_CANDIDATES"
        );
        assert!(
            selection
                .candidate_scores
                .iter()
                .all(|score| score.validation_average_log_likelihood.is_none())
        );
    }

    #[test]
    fn forward_fold_k_selection_fails_closed_when_train_cannot_fit_any_candidate() {
        let train = vec![vec![vec![0.0]; 8]];
        let validation = vec![synthetic_hmm_sequence(0.0)];

        let error = select_hmm_within_forward_fold(
            &train,
            &validation,
            &[2, 3],
            2,
            5,
            1,
            HmmOccupancyPolicy {
                minimum_fraction: 0.001,
                minimum_expected_observations: 1.0,
            },
        )
        .unwrap_err();

        assert!(
            error
                .to_string()
                .contains("occupancy-eligible HMM candidate")
        );
    }

    #[test]
    fn tvtp_alignment_is_finalized_causal_and_index_matched() {
        let first_date = NaiveDate::from_ymd_opt(2026, 7, 23).unwrap();
        let second_date = NaiveDate::from_ymd_opt(2026, 7, 24).unwrap();
        let first = Utc
            .with_ymd_and_hms(2026, 7, 23, 13, 34, 0)
            .single()
            .unwrap();
        let second = first + Duration::minutes(5);
        let next_session = Utc
            .with_ymd_and_hms(2026, 7, 24, 13, 34, 0)
            .single()
            .unwrap();
        let states = vec![
            finalized_regime_state(first, first_date, 0, 1.0),
            finalized_regime_state(second, first_date, 1, 2.0),
            finalized_regime_state(next_session, second_date, 0, -1.0),
        ];

        let aligned = finalized_tvtp_sequences(&states).unwrap();
        assert_eq!(aligned.dates, vec![first_date, second_date]);
        assert_eq!(aligned.observations.len(), aligned.covariates.len());
        assert_eq!(aligned.observations[0].len(), aligned.covariates[0].len());
        assert_eq!(aligned.observations[0][0].len(), 4);
        assert_eq!(aligned.covariates[0][0].len(), TVTP_COVARIATE_SCHEMA.len());
        assert_eq!(aligned.observations[0][0][0], 0.007);
        assert_eq!(aligned.covariates[0][0][0], 0.011);
        assert!((aligned.covariates[0][1][4] - 9.0 / 390.0).abs() < 1.0e-12);
        assert_eq!(aligned.as_of[0][0], first + Duration::minutes(1));

        let out_of_order = vec![
            finalized_regime_state(second, first_date, 1, 2.0),
            finalized_regime_state(first, first_date, 0, 1.0),
        ];
        assert!(finalized_tvtp_sequences(&out_of_order).is_err());
    }

    #[test]
    fn tvtp_unavailable_report_is_structured_and_decision_neutral() {
        let report = tvtp_unavailable_report(
            vec!["TVTP_TEST_UNAVAILABLE".into()],
            Some("synthetic failure".into()),
        );

        assert_eq!(report["status"], "UNAVAILABLE");
        assert_eq!(report["availability"], "UNAVAILABLE");
        assert_eq!(report["role"], "SHADOW_CHALLENGER_ONLY");
        assert_eq!(report["decision_policy_impact"], "NONE");
        assert_eq!(report["validation"]["flags"][0], "TVTP_TEST_UNAVAILABLE");
        assert_eq!(report["validation"]["selected_for_shadow"], false);
        assert!(report["fit"]["row_effective_transition_weight"].is_null());
        assert!(report["current_session"]["online_ood"].is_null());
        assert_eq!(
            report["current_session"]["one_step_transition_covariate_assumption"],
            "NOT_EVALUATED"
        );
    }

    #[test]
    fn python_quote_bridge_receives_configured_connection_and_symbols() {
        let bridge = Path::new("scripts/moomoo_quote_bridge.py");
        let symbols = vec![
            "US.SPY".to_string(),
            "US.SOXX".to_string(),
            "US.MU".to_string(),
        ];
        let command = quote_bridge_command(
            bridge,
            OsStr::new("python-test"),
            "127.0.0.1",
            11_111,
            &symbols,
        )
        .unwrap();

        assert_eq!(command.get_program(), OsStr::new("python-test"));
        assert_eq!(
            arguments(&command),
            vec![
                bridge.as_os_str().to_os_string(),
                "QuotePush".into(),
                "--host".into(),
                "127.0.0.1".into(),
                "--port".into(),
                "11111".into(),
                "--symbols".into(),
                "US.SPY,US.SOXX,US.MU".into(),
            ]
        );
    }

    #[test]
    fn native_quote_bridge_command_is_unchanged() {
        let bridge = Path::new("runtime/moomoo/moomoo_quote_bridge.exe");
        let symbols = vec!["US.SPY".to_string()];
        let command = quote_bridge_command(
            bridge,
            OsStr::new("ignored-python"),
            "127.0.0.1",
            11_111,
            &symbols,
        )
        .unwrap();

        assert_eq!(command.get_program(), bridge.as_os_str());
        assert_eq!(arguments(&command), vec![OsString::from("QuotePush")]);
    }

    #[test]
    fn python_quote_bridge_rejects_ambiguous_symbol_arguments() {
        let bridge = Path::new("scripts/moomoo_quote_bridge.PY");
        let symbols = vec!["US.SPY,US.MU".to_string()];
        let result =
            quote_bridge_command(bridge, OsStr::new("python"), "127.0.0.1", 11_111, &symbols);
        assert!(result.is_err());
    }
}
