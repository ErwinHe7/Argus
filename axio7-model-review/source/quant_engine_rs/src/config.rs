use std::{
    fs,
    net::IpAddr,
    path::{Path, PathBuf},
    str::FromStr,
};

use anyhow::{Context, Result, bail};
use serde::{Deserialize, Serialize};

use crate::risk_policy::{DEFAULT_RISK_POLICY_PATH, UnifiedRiskPolicy};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppConfig {
    #[serde(default = "default_risk_policy_path")]
    pub risk_policy_path: PathBuf,
    #[serde(skip)]
    pub risk_policy: UnifiedRiskPolicy,
    pub server: ServerConfig,
    pub research: ResearchConfig,
    pub data: DataConfig,
    #[serde(default)]
    pub os: QuantOsConfig,
    #[serde(default)]
    pub live: LiveConfig,
    #[serde(default)]
    pub execution: ExecutionConfig,
}

fn default_risk_policy_path() -> PathBuf {
    PathBuf::from(DEFAULT_RISK_POLICY_PATH)
}

/// Broker execution is deliberately separated from the market-data adapter.
/// Production defaults to no broker. The retained legacy Moomoo boundary needs
/// an explicit configuration change plus runtime credentials/arming.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExecutionConfig {
    pub enabled: bool,
    pub provider: String,
    pub mode: String,
    pub gateway_url: String,
    pub gateway_token_env: String,
    pub live_arm_token_env: String,
    pub account_id: Option<u64>,
    pub allow_real_orders: bool,
    pub long_only: bool,
    pub allowed_symbols: Vec<String>,
    pub max_order_notional: f64,
    pub max_position_notional: f64,
    pub max_gross_exposure: f64,
    pub max_daily_loss: f64,
    pub max_snapshot_age_seconds: i64,
    pub max_signal_age_seconds: i64,
    pub limit_price_collar_bps: f64,
    pub reconcile_interval_ms: u64,
    pub oms_path: PathBuf,
}

impl Default for ExecutionConfig {
    fn default() -> Self {
        Self {
            enabled: false,
            provider: "none".into(),
            mode: "simulate".into(),
            gateway_url: "http://127.0.0.1:8765".into(),
            gateway_token_env: "AXIO_BROKER_GATEWAY_TOKEN".into(),
            live_arm_token_env: "AXIO_LIVE_ARMING_TOKEN".into(),
            account_id: None,
            allow_real_orders: false,
            long_only: true,
            allowed_symbols: vec!["US.SPY".into()],
            max_order_notional: 500.0,
            max_position_notional: 1_000.0,
            max_gross_exposure: 0.01,
            max_daily_loss: 0.0025,
            max_snapshot_age_seconds: 10,
            max_signal_age_seconds: 30,
            limit_price_collar_bps: 5.0,
            reconcile_interval_ms: 2_000,
            oms_path: PathBuf::from("data/state/execution_oms.sqlite3"),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LiveConfig {
    pub enabled: bool,
    pub provider: String,
    /// Production market data must be exchange-real-time. A provider response
    /// marked delayed, cached, replayed, or with unknown entitlement fails
    /// closed before it reaches a model.
    #[serde(default = "default_true")]
    pub require_realtime: bool,
    pub quote_only: bool,
    pub host: String,
    pub port: u16,
    pub symbols: Vec<String>,
    #[serde(default = "default_live_forecast_symbols")]
    pub forecast_symbols: Vec<String>,
    pub session: String,
    pub subscribe_quote: bool,
    pub subscribe_k_1m: bool,
    pub subscribe_ticker: bool,
    pub subscribe_order_book: bool,
    pub finalize_grace_ms: i64,
    pub stale_after_ms: i64,
    pub execution_latency_ms: i64,
    /// End-to-end budget from provider availability timestamp to a persisted
    /// model result. The runtime emits NO_FORECAST when this budget is missed.
    #[serde(default = "default_prediction_sla_ms")]
    pub prediction_sla_ms: i64,
    /// Maximum allowed timestamp skew between the target bar and every
    /// required context symbol.
    #[serde(default = "default_context_skew_ms")]
    pub max_context_skew_ms: i64,
    /// Context instruments that must be present and fresh at the same cutoff.
    /// Symbols use provider-neutral US tickers (for example QQQ, VXX, USO).
    #[serde(default)]
    pub required_context_symbols: Vec<String>,
    pub reconnect_min_ms: u64,
    pub reconnect_max_ms: u64,
    #[serde(default = "default_live_raw_log_max_bytes")]
    pub raw_log_max_bytes: u64,
    #[serde(default = "default_live_raw_log_archive_count")]
    pub raw_log_archive_count: usize,
    pub shadow_only: bool,
    pub allow_trade_api: bool,
    pub enable_spxw_recorder: bool,
}

fn default_live_forecast_symbols() -> Vec<String> {
    vec!["US.SPY".into()]
}

fn default_true() -> bool {
    true
}

fn default_prediction_sla_ms() -> i64 {
    5_000
}

fn default_context_skew_ms() -> i64 {
    5_000
}

fn default_live_raw_log_max_bytes() -> u64 {
    128 * 1024 * 1024
}

fn default_live_raw_log_archive_count() -> usize {
    4
}

impl Default for LiveConfig {
    fn default() -> Self {
        Self {
            enabled: false,
            provider: "massive".into(),
            require_realtime: true,
            quote_only: true,
            host: "127.0.0.1".into(),
            port: 11_111,
            symbols: vec!["US.SPY".into()],
            session: "regular".into(),
            forecast_symbols: default_live_forecast_symbols(),
            subscribe_quote: true,
            subscribe_k_1m: true,
            subscribe_ticker: true,
            subscribe_order_book: false,
            finalize_grace_ms: 2_000,
            stale_after_ms: 10_000,
            execution_latency_ms: 250,
            prediction_sla_ms: default_prediction_sla_ms(),
            max_context_skew_ms: default_context_skew_ms(),
            required_context_symbols: vec![
                "QQQ".into(),
                "IWM".into(),
                "HYG".into(),
                "TLT".into(),
                "UUP".into(),
                "VXX".into(),
                "USO".into(),
            ],
            reconnect_min_ms: 1_000,
            reconnect_max_ms: 30_000,
            raw_log_max_bytes: default_live_raw_log_max_bytes(),
            raw_log_archive_count: default_live_raw_log_archive_count(),
            shadow_only: true,
            allow_trade_api: false,
            enable_spxw_recorder: false,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QuantOsConfig {
    pub freshness_limit_seconds: i64,
    pub minimum_samples: usize,
    pub confidence_threshold: f64,
    pub minimum_expected_return_bps: f64,
    pub starting_capital: f64,
    pub max_position_pct: f64,
    pub max_gross_exposure: f64,
    pub max_correlated_exposure: f64,
    pub max_daily_loss: f64,
    pub max_drawdown: f64,
    pub max_daily_trades: usize,
    pub cooldown_minutes: i64,
    pub force_flat_time: String,
    pub execution_mode: String,
    pub latency_ms: u64,
    pub spread_bps: f64,
    pub slippage_bps: f64,
    pub fee_per_order: f64,
    pub train_months: usize,
    pub validation_months: usize,
    pub test_months: usize,
    pub purge_minutes: usize,
    pub embargo_minutes: usize,
    pub random_seed: u64,
}

impl Default for QuantOsConfig {
    fn default() -> Self {
        Self {
            freshness_limit_seconds: 120,
            minimum_samples: 200,
            confidence_threshold: 0.60,
            minimum_expected_return_bps: 2.0,
            starting_capital: 100_000.0,
            max_position_pct: 0.10,
            max_gross_exposure: 0.25,
            max_correlated_exposure: 0.15,
            max_daily_loss: 0.01,
            max_drawdown: 0.05,
            max_daily_trades: 3,
            cooldown_minutes: 30,
            force_flat_time: "15:55".to_string(),
            execution_mode: "paper".to_string(),
            latency_ms: 250,
            spread_bps: 1.0,
            slippage_bps: 0.5,
            fee_per_order: 0.0,
            train_months: 12,
            validation_months: 2,
            test_months: 1,
            purge_minutes: 60,
            embargo_minutes: 60,
            random_seed: 7,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServerConfig {
    pub host: String,
    pub port: u16,
    pub registry_path: PathBuf,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ResearchConfig {
    pub target: String,
    /// Explicit public research universe. `target` remains the primary
    /// compatibility target used by single-artifact commands; live universe
    /// orchestration must use this list and may never infer aliases silently.
    #[serde(default)]
    pub targets: Vec<ResearchTargetConfig>,
    pub timezone: String,
    pub session_open: String,
    pub session_close: String,
    pub horizons: Vec<usize>,
    pub max_trades_per_day: usize,
    pub cooldown_minutes: i64,
    pub analog_neighbors: usize,
    pub analog_bandwidth: f64,
    pub validation_score_threshold: f64,
    pub stop_bps: f64,
    pub take_profit_bps: f64,
    pub max_holding_minutes: usize,
    pub underlying_slippage_bps: f64,
    pub commission_per_trade: f64,
    pub option_slippage: f64,
    pub option_max_spread_pct: f64,
    pub option_max_staleness_seconds: i64,
    /// Hidden-state selection and same-regime retrieval policy. This is
    /// defaulted so older research profiles remain readable, while the live
    /// predictor no longer has a hidden hard-coded state count.
    #[serde(default)]
    pub regime: RegimeResearchConfig,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct ResearchTargetConfig {
    /// Symbol shown in the product and accepted by the query contract.
    pub public_symbol: String,
    /// Canonical symbol whose bars are consumed by the current predictor.
    pub model_symbol: String,
    /// Vendor-neutral price instrument. Index tickers retain their asset
    /// prefix so an ETF proxy cannot be mislabeled as the cash index.
    pub price_symbol: String,
    /// Option-chain root. This is intentionally separate from `model_symbol`.
    pub options_underlying: String,
    /// Source used for volume/VWAP. Cash indices do not have consolidated
    /// executable volume, so SPX explicitly uses SPY as a research proxy.
    pub vwap_volume_source: String,
    pub target_status: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct RegimeResearchConfig {
    /// Candidate hidden-state counts evaluated with chronological held-out
    /// likelihood. Eight is a public-history-inspired challenger, not a claim
    /// that Renaissance's private production model is known or reproduced.
    pub state_candidates: Vec<usize>,
    pub validation_fraction: f64,
    pub minimum_validation_sessions: usize,
    pub max_iterations: usize,
    pub restarts: usize,
    pub require_same_dominant_state: bool,
    pub minimum_dominant_probability: f64,
    pub minimum_posterior_cosine_similarity: f64,
    pub maximum_normalized_entropy: f64,
    pub minimum_effective_sample_size: f64,
}

impl Default for RegimeResearchConfig {
    fn default() -> Self {
        Self {
            // Widened from 2..=10 to 2..=12 -- the full range `GaussianHmm::fit`
            // already permits and config validation already requires staying
            // within. Every shipped candidate previously saturated at the top
            // of whatever grid it was given
            // (BEST_VALIDATION_SCORE_IS_AT_MAXIMUM_TESTED_K); stopping two
            // states short of the model's own hard cap made that impossible to
            // tell apart from "the grid just wasn't wide enough yet". Selection
            // now also requires MINIMUM_STATE_OCCUPANCY per state
            // (engine::model_selection), which is what actually creates an
            // interior optimum -- widening the grid alone would just move the
            // saturation point.
            state_candidates: (2..=12).collect(),
            validation_fraction: 0.20,
            minimum_validation_sessions: 5,
            max_iterations: 40,
            restarts: 3,
            require_same_dominant_state: true,
            minimum_dominant_probability: 0.50,
            minimum_posterior_cosine_similarity: 0.90,
            maximum_normalized_entropy: 0.85,
            minimum_effective_sample_size: 20.0,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DataConfig {
    pub raw_root: PathBuf,
    pub normalized_root: PathBuf,
    pub manifest_root: PathBuf,
    pub required_symbols: Vec<String>,
    #[serde(default)]
    pub massive: MassiveConfig,
    #[serde(default)]
    pub context: ContextFeedConfig,
    pub databento: DatabentoConfig,
    pub cboe: CboeConfig,
    pub broker: BrokerConfig,
}

/// Slow/contextual data is deliberately isolated from the executable minute
/// tape. A vendor snapshot is not promoted to a model feature until a
/// point-in-time history with explicit availability timestamps exists.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ContextFeedConfig {
    pub enabled: bool,
    pub provider: String,
    pub input_path: PathBuf,
    pub minimum_history_days: usize,
    pub require_upstream_vendor: bool,
    pub max_snapshot_staleness_seconds: i64,
}

impl Default for ContextFeedConfig {
    fn default() -> Self {
        Self {
            enabled: false,
            provider: "sec_edgar+fred_alfred".to_string(),
            input_path: PathBuf::from("data/context/official_observations.jsonl"),
            minimum_history_days: 120,
            require_upstream_vendor: true,
            max_snapshot_staleness_seconds: 300,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MassiveConfig {
    pub enabled: bool,
    pub base_url: String,
    #[serde(default = "default_massive_stock_websocket_url")]
    pub stock_websocket_url: String,
    #[serde(default = "default_massive_options_websocket_url")]
    pub options_websocket_url: String,
    /// Lossless normalized archive of authenticated stock T/Q/A/AM events.
    /// The inference path consumes only finalized AM bars; the richer tape is
    /// retained for microstructure features, replay, and data-quality audit.
    #[serde(default = "default_massive_stock_tape_output")]
    pub stock_tape_output: PathBuf,
    pub api_key_env: String,
    pub symbols: Vec<String>,
    /// Index instruments use Massive's `I:` symbology and historical index
    /// endpoint. They are kept separate from stocks because they do not have
    /// consolidated trade volume or a stock SIP NBBO.
    #[serde(default)]
    pub index_symbols: Vec<String>,
    /// Underlyings for which a paginated full-chain OPRA snapshot is required.
    #[serde(default)]
    pub option_underlyings: Vec<String>,
    #[serde(default = "default_option_chain_output_root")]
    pub option_chain_output_root: PathBuf,
    #[serde(default = "default_option_chain_refresh_seconds")]
    pub option_chain_refresh_seconds: u64,
    #[serde(default = "default_option_chain_max_pages")]
    pub option_chain_max_pages: usize,
    #[serde(default = "default_option_chain_max_contracts")]
    pub option_chain_max_contracts: usize,
    #[serde(default = "default_option_chain_min_eligible_contracts")]
    pub option_chain_min_eligible_contracts: usize,
    #[serde(default = "default_option_chain_min_coverage")]
    pub option_chain_min_quote_coverage: f64,
    #[serde(default = "default_option_chain_min_coverage")]
    pub option_chain_min_open_interest_coverage: f64,
    #[serde(default = "default_option_chain_min_coverage")]
    pub option_chain_min_greeks_coverage: f64,
    pub request_interval_ms: u64,
    pub chunk_days: i64,
}

fn default_massive_stock_websocket_url() -> String {
    "wss://socket.massive.com/stocks".to_string()
}

fn default_massive_options_websocket_url() -> String {
    "wss://socket.massive.com/options".to_string()
}

fn default_massive_stock_tape_output() -> PathBuf {
    PathBuf::from("data/live/massive_stock_tape.jsonl")
}

fn default_option_chain_output_root() -> PathBuf {
    PathBuf::from("data/live/options")
}

fn default_option_chain_refresh_seconds() -> u64 {
    60
}

fn default_option_chain_max_pages() -> usize {
    200
}

fn default_option_chain_max_contracts() -> usize {
    250_000
}

fn default_option_chain_min_eligible_contracts() -> usize {
    20
}

fn default_option_chain_min_coverage() -> f64 {
    0.80
}

impl Default for MassiveConfig {
    fn default() -> Self {
        Self {
            enabled: false,
            base_url: "https://api.massive.com".to_string(),
            stock_websocket_url: default_massive_stock_websocket_url(),
            options_websocket_url: default_massive_options_websocket_url(),
            stock_tape_output: default_massive_stock_tape_output(),
            api_key_env: "MASSIVE_API_KEY".to_string(),
            symbols: Vec::new(),
            index_symbols: Vec::new(),
            option_underlyings: Vec::new(),
            option_chain_output_root: default_option_chain_output_root(),
            option_chain_refresh_seconds: default_option_chain_refresh_seconds(),
            option_chain_max_pages: default_option_chain_max_pages(),
            option_chain_max_contracts: default_option_chain_max_contracts(),
            option_chain_min_eligible_contracts: default_option_chain_min_eligible_contracts(),
            option_chain_min_quote_coverage: default_option_chain_min_coverage(),
            option_chain_min_open_interest_coverage: default_option_chain_min_coverage(),
            option_chain_min_greeks_coverage: default_option_chain_min_coverage(),
            request_interval_ms: 12_100,
            chunk_days: 28,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DatabentoConfig {
    pub enabled: bool,
    pub requests: Vec<DataRequest>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DataRequest {
    pub name: String,
    pub dataset: String,
    pub schema: String,
    pub stype_in: String,
    pub symbols: Vec<String>,
    pub start: String,
    pub end: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CboeConfig {
    pub licensed_csv_root: PathBuf,
    pub spx_index_history_from: String,
    pub option_quote_history_from: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BrokerConfig {
    pub provider: String,
    pub execution_only: bool,
    pub mode: String,
}

impl AppConfig {
    pub fn load(path: impl AsRef<Path>) -> Result<Self> {
        let path = path.as_ref();
        let text = fs::read_to_string(path)
            .with_context(|| format!("failed reading configuration {}", path.display()))?;
        let mut config: Self = serde_yaml::from_str(&text)
            .with_context(|| format!("invalid YAML in {}", path.display()))?;
        let risk_path = UnifiedRiskPolicy::resolve(path, &config.risk_policy_path);
        config.risk_policy = UnifiedRiskPolicy::load(&risk_path)?;
        config.apply_unified_risk_policy();
        config.validate()?;
        Ok(config)
    }

    fn apply_unified_risk_policy(&mut self) {
        self.os.max_position_pct = self.risk_policy.max_single_name_pct;
        self.os.max_gross_exposure = self.risk_policy.max_total_gross_pct;
        self.os.max_correlated_exposure = self.risk_policy.max_correlated_cluster_pct;
        self.os.max_daily_loss = self.risk_policy.max_daily_loss_pct;
        self.os.max_drawdown = self.risk_policy.max_drawdown_pct;
        self.os.max_daily_trades = self.risk_policy.max_trades_per_day;
        self.execution.max_gross_exposure = self.risk_policy.max_total_gross_pct;
        self.execution.max_daily_loss = self.risk_policy.max_daily_loss_pct;
    }

    pub fn betting_policy(&self) -> crate::allocation::BettingPolicy {
        self.risk_policy.betting_policy()
    }

    pub fn portfolio_risk_policy(&self) -> crate::portfolio_risk::PortfolioRiskPolicy {
        self.risk_policy.portfolio_risk_policy()
    }

    pub fn validate(&self) -> Result<()> {
        self.risk_policy.validate()?;
        if self.os.max_position_pct != self.risk_policy.max_single_name_pct
            || self.os.max_gross_exposure != self.risk_policy.max_total_gross_pct
            || self.os.max_correlated_exposure != self.risk_policy.max_correlated_cluster_pct
            || self.os.max_daily_loss != self.risk_policy.max_daily_loss_pct
            || self.os.max_drawdown != self.risk_policy.max_drawdown_pct
            || self.os.max_daily_trades != self.risk_policy.max_trades_per_day
            || self.execution.max_gross_exposure != self.risk_policy.max_total_gross_pct
            || self.execution.max_daily_loss != self.risk_policy.max_daily_loss_pct
        {
            bail!("runtime risk limits must be derived from the unified risk policy");
        }
        if self.research.max_trades_per_day > 3 {
            bail!("max_trades_per_day must be <= 3");
        }
        if self.os.execution_mode != "paper" {
            bail!("execution mode must remain paper");
        }
        if self.os.max_daily_trades > 3 || self.os.max_position_pct <= 0.0 {
            bail!("Quant OS risk limits are invalid");
        }
        if self.research.horizons.is_empty() || self.research.horizons.contains(&0) {
            bail!("forecast horizons must be positive");
        }
        if self
            .research
            .horizons
            .iter()
            .any(|horizon| !matches!(horizon, 5 | 15 | 30 | 60))
        {
            bail!("intraday forecast horizons must be one of 5, 15, 30, or 60 minutes");
        }
        if self.research.targets.is_empty() || self.research.targets.len() > 15 {
            bail!("research.targets must contain between 1 and 15 explicit targets");
        }
        let mut public_symbols = std::collections::BTreeSet::new();
        for target in &self.research.targets {
            let fields = [
                target.public_symbol.as_str(),
                target.model_symbol.as_str(),
                target.price_symbol.as_str(),
                target.options_underlying.as_str(),
                target.vwap_volume_source.as_str(),
                target.target_status.as_str(),
            ];
            if fields.iter().any(|value| value.trim().is_empty())
                || target
                    .public_symbol
                    .bytes()
                    .any(|byte| !(byte.is_ascii_uppercase() || byte.is_ascii_digit()))
                || !public_symbols.insert(target.public_symbol.clone())
            {
                bail!("research target identities must be non-empty, uppercase, and unique");
            }
        }
        if !self.research.targets.iter().any(|target| {
            target
                .model_symbol
                .eq_ignore_ascii_case(&self.research.target)
        }) {
            bail!("research.target must be represented by research.targets");
        }
        if self.research.analog_neighbors == 0 || self.research.analog_bandwidth <= 0.0 {
            bail!("analog_neighbors and analog_bandwidth must be positive");
        }
        if self.research.option_max_spread_pct <= 0.0 {
            bail!("option_max_spread_pct must be positive");
        }
        let regime = &self.research.regime;
        if regime.state_candidates.is_empty()
            || regime
                .state_candidates
                .iter()
                .any(|states| !(2..=12).contains(states))
            || !regime.state_candidates.contains(&8)
        {
            bail!(
                "regime state candidates must be within 2..=12 and include the 8-state challenger"
            );
        }
        let unique_regime_candidates = regime
            .state_candidates
            .iter()
            .copied()
            .collect::<std::collections::BTreeSet<_>>();
        if unique_regime_candidates.len() != regime.state_candidates.len()
            || !regime.validation_fraction.is_finite()
            || !(0.05..=0.50).contains(&regime.validation_fraction)
            || regime.minimum_validation_sessions == 0
            || regime.max_iterations == 0
            || regime.restarts == 0
            || !regime.minimum_dominant_probability.is_finite()
            || !(0.0..=1.0).contains(&regime.minimum_dominant_probability)
            || !regime.minimum_posterior_cosine_similarity.is_finite()
            || !(-1.0..=1.0).contains(&regime.minimum_posterior_cosine_similarity)
            || !regime.maximum_normalized_entropy.is_finite()
            || !(0.0..=1.0).contains(&regime.maximum_normalized_entropy)
            || !regime.minimum_effective_sample_size.is_finite()
            || regime.minimum_effective_sample_size < 10.0
        {
            bail!("regime research configuration is invalid");
        }
        let server_ip = IpAddr::from_str(&self.server.host)
            .with_context(|| format!("server.host must be an IP address: {}", self.server.host))?;
        if !server_ip.is_loopback() {
            bail!("quant control plane must remain loopback-only until TLS/mTLS is implemented");
        }
        for request in &self.data.databento.requests {
            if request.symbols.is_empty() || request.start >= request.end {
                bail!("invalid Databento request {}", request.name);
            }
        }
        if self.data.massive.enabled
            && (self.data.massive.symbols.is_empty()
                || self
                    .data
                    .massive
                    .index_symbols
                    .iter()
                    .any(|symbol| !symbol.starts_with("I:") || symbol.len() <= 2)
                || self.data.massive.chunk_days <= 0
                || self.data.massive.request_interval_ms < 12_000
                || self.data.massive.option_chain_min_eligible_contracts == 0
                || [
                    self.data.massive.option_chain_min_quote_coverage,
                    self.data.massive.option_chain_min_open_interest_coverage,
                    self.data.massive.option_chain_min_greeks_coverage,
                ]
                .into_iter()
                .any(|value| !value.is_finite() || !(0.0..=1.0).contains(&value)))
        {
            bail!(
                "Massive requires symbols, positive chunk_days, <=5 requests/minute, and valid option coverage gates"
            );
        }
        if self.data.context.enabled
            && (self.data.context.provider.trim().is_empty()
                || self.data.context.minimum_history_days == 0
                || self.data.context.max_snapshot_staleness_seconds <= 0)
        {
            bail!("context feed configuration is invalid");
        }
        if self.live.enabled {
            if !matches!(
                self.live.provider.as_str(),
                "massive" | "moomoo" | "databento"
            ) {
                bail!("live.provider must be massive, moomoo, or databento");
            }
            if !self.live.quote_only || self.live.allow_trade_api {
                bail!("live market-data adapter must remain quote-only with trade API disabled");
            }
            match self.live.provider.as_str() {
                "moomoo" => {
                    let ip = IpAddr::from_str(&self.live.host)
                        .with_context(|| "live.host must be a numeric loopback address")?;
                    if !ip.is_loopback() {
                        bail!("Moomoo live adapter must be loopback-only");
                    }
                    if self.live.symbols.iter().any(|symbol| symbol == "US..SPX") {
                        bail!("Moomoo does not support US index quote symbol US..SPX");
                    }
                }
                "massive" => {
                    if !self.data.massive.enabled {
                        bail!("live.provider=massive requires data.massive.enabled=true");
                    }
                    for (name, raw) in [
                        (
                            "data.massive.stock_websocket_url",
                            self.data.massive.stock_websocket_url.as_str(),
                        ),
                        (
                            "data.massive.options_websocket_url",
                            self.data.massive.options_websocket_url.as_str(),
                        ),
                    ] {
                        let url = reqwest::Url::parse(raw)
                            .with_context(|| format!("{name} must be an absolute WSS URL"))?;
                        if url.scheme() != "wss" {
                            bail!("{name} must use wss");
                        }
                        if self.live.require_realtime
                            && url.host_str().is_some_and(|host| host.contains("delayed"))
                        {
                            bail!("{name} points at a delayed endpoint while realtime is required");
                        }
                    }
                }
                "databento" => {
                    if !self.data.databento.enabled {
                        bail!("live.provider=databento requires data.databento.enabled=true");
                    }
                    let request = self
                        .data
                        .databento
                        .requests
                        .iter()
                        .find(|request| {
                            request.dataset.eq_ignore_ascii_case("EQUS.MINI")
                                && request.schema.eq_ignore_ascii_case("ohlcv-1m")
                                && request.stype_in.eq_ignore_ascii_case("raw_symbol")
                        })
                        .context(
                            "live.provider=databento requires an EQUS.MINI/ohlcv-1m/raw_symbol request",
                        )?;
                    if self.live.symbols.is_empty() {
                        bail!("Databento live adapter requires at least one symbol");
                    }
                    let missing_symbols = self
                        .live
                        .symbols
                        .iter()
                        .filter_map(|symbol| {
                            let normalized = symbol.strip_prefix("US.").unwrap_or(symbol);
                            (!request
                                .symbols
                                .iter()
                                .any(|configured| configured.eq_ignore_ascii_case(normalized)))
                            .then_some(normalized)
                        })
                        .collect::<Vec<_>>();
                    if !missing_symbols.is_empty() {
                        bail!(
                            "Databento live symbols are absent from the configured EQUS.MINI request: {}",
                            missing_symbols.join(", ")
                        );
                    }
                }
                _ => unreachable!("live provider was validated above"),
            }
            if self.live.finalize_grace_ms < 0
                || self.live.stale_after_ms <= 0
                || self.live.prediction_sla_ms <= 0
                || self.live.max_context_skew_ms <= 0
                || self.live.raw_log_max_bytes < 1024 * 1024
                || self.live.raw_log_archive_count == 0
            {
                bail!("live finalization/staleness settings are invalid");
            }
        }
        self.execution.validate()?;
        Ok(())
    }
}

impl ExecutionConfig {
    pub fn validate(&self) -> Result<()> {
        if !self.enabled && self.provider == "none" {
            if self.allow_real_orders || self.mode != "simulate" {
                bail!("disabled execution must remain simulate with real orders prohibited");
            }
            return Ok(());
        }
        if !matches!(self.provider.as_str(), "moomoo") {
            bail!("enabled execution.provider must be moomoo in this build");
        }
        if !matches!(self.mode.as_str(), "simulate" | "real") {
            bail!("execution.mode must be simulate or real");
        }
        let url = reqwest::Url::parse(&self.gateway_url)
            .with_context(|| "execution.gateway_url must be an absolute HTTP URL")?;
        let host = url
            .host_str()
            .context("execution.gateway_url must contain a host")?;
        let ip = IpAddr::from_str(host)
            .with_context(|| "execution gateway host must be a numeric loopback address")?;
        if url.scheme() != "http" || !ip.is_loopback() {
            bail!("execution gateway must use HTTP on a numeric loopback address");
        }
        if self.gateway_token_env.trim().is_empty()
            || self.live_arm_token_env.trim().is_empty()
            || self.allowed_symbols.is_empty()
            || self
                .allowed_symbols
                .iter()
                .any(|symbol| !symbol.starts_with("US.") || symbol.len() <= 3)
        {
            bail!("execution credentials and US symbol allowlist are invalid");
        }
        for (name, value) in [
            ("max_order_notional", self.max_order_notional),
            ("max_position_notional", self.max_position_notional),
            ("max_gross_exposure", self.max_gross_exposure),
            ("max_daily_loss", self.max_daily_loss),
            ("limit_price_collar_bps", self.limit_price_collar_bps),
        ] {
            if !value.is_finite() || value <= 0.0 {
                bail!("execution.{name} must be finite and positive");
            }
        }
        if self.max_order_notional > self.max_position_notional
            || self.max_gross_exposure > 1.0
            || self.max_daily_loss >= 1.0
            || self.max_snapshot_age_seconds <= 0
            || self.max_signal_age_seconds <= 0
            || self.reconcile_interval_ms < 250
        {
            bail!("execution risk limits are inconsistent");
        }
        if self.mode == "real" && (!self.allow_real_orders || self.account_id.is_none()) {
            bail!("real execution requires allow_real_orders=true and a pinned account_id");
        }
        Ok(())
    }
}
