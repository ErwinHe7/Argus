use std::{
    collections::{BTreeMap, BTreeSet},
    fs,
    net::SocketAddr,
    sync::Arc,
};

use anyhow::{Context, Result};
use axum::{
    Json, Router,
    extract::{Path, Query, Request, State},
    http::{HeaderMap, Method, StatusCode},
    middleware::{self, Next},
    response::{IntoResponse, Response},
    routing::{get, post},
};
use chrono::{DateTime, Timelike, Utc};
use chrono_tz::America::New_York;
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use tower_http::trace::TraceLayer;
use uuid::Uuid;

use crate::{
    AppConfig,
    broker::BrokerMonitor,
    data::{
        databento_inference::{TargetInferenceStage, TargetInferenceState},
        massive_live::readiness_scopes_from_receipt,
    },
    domain::CallPut,
    engine::{
        gamma_convexity::{GammaConvexityRequest, gamma_convexity_feedback_risk},
        run_csv_research,
    },
    frozen_universe::{FrozenUniverseRegistry, load_frozen_universe},
    market_query::{
        EVIDENCE_ENVELOPE_SCHEMA_VERSION, EvidenceEnvelope, EvidenceItem, MarketQuery,
        MarketQueryIntent, MarketSetupType, PipelineReadiness, PipelineReadinessStage,
        PipelineReadinessState, ResearchCandidate, gamma_structure_candidate,
        historical_setup_stats, live_vwap_candidate,
    },
    os::QuantRuntime,
    prediction_ledger::PredictionLedger,
    predictor::{
        CURRENT_CLOSE_SCENARIO_BASIS, CURRENT_CLOSE_SCENARIO_SEMANTICS,
        CURRENT_CLOSE_SCENARIO_STATUS, ForecastBundle, KERNEL_RETURN_DEFINITION,
    },
    production_readiness::{
        CalibrationRegistryStatus, EvidenceStatus, FreshnessStatus, MarketDataRightsStatus,
        OverallReadiness, ProductionReadinessReceipt, PromotionRegistryStatus,
    },
    promotion_registry::inspect_from_environment as inspect_promotion_registry,
    registry::{Registry, RunRecord},
};

#[derive(Clone)]
pub struct AppState {
    pub config: Arc<AppConfig>,
    pub registry: Arc<Registry>,
    pub runtime: Arc<QuantRuntime>,
    pub broker_monitor: Arc<BrokerMonitor>,
}

fn constant_time_token_match(expected: &str, provided: &str) -> bool {
    let expected = expected.as_bytes();
    let provided = provided.as_bytes();
    let mut difference = expected.len() ^ provided.len();
    for index in 0..expected.len().max(provided.len()) {
        difference |= usize::from(
            expected.get(index).copied().unwrap_or(0) ^ provided.get(index).copied().unwrap_or(0),
        );
    }
    difference == 0
}

fn valid_nonzero_sha256(value: &str) -> bool {
    value.len() == 64
        && value.bytes().all(|byte| byte.is_ascii_hexdigit())
        && value.bytes().any(|byte| byte != b'0')
}

fn sha256_hex(bytes: &[u8]) -> String {
    format!("{:x}", Sha256::digest(bytes))
}

fn is_public_health_request(method: &Method, path: &str) -> bool {
    (method == Method::GET || method == Method::HEAD) && matches!(path, "/health" | "/ready")
}

async fn require_research_token(request: Request, next: Next) -> Response {
    if is_public_health_request(request.method(), request.uri().path()) {
        return next.run(request).await;
    }
    let Some(expected) = std::env::var("INTRADAY_QUANT_TOKEN")
        .ok()
        .filter(|value| value.len() >= 32)
    else {
        return (
            StatusCode::SERVICE_UNAVAILABLE,
            Json(json!({
                "detail":"quant control-plane access is disabled: configure an INTRADAY_QUANT_TOKEN of at least 32 characters"
            })),
        )
            .into_response();
    };
    let provided = request
        .headers()
        .get("x-research-token")
        .and_then(|value| value.to_str().ok())
        .unwrap_or_default();
    if !constant_time_token_match(&expected, provided) {
        return (
            StatusCode::UNAUTHORIZED,
            Json(json!({"detail":"invalid research control token"})),
        )
            .into_response();
    }
    next.run(request).await
}

#[derive(Debug)]
pub struct ApiError {
    status: StatusCode,
    message: String,
}

impl ApiError {
    fn internal(error: impl std::fmt::Display) -> Self {
        Self {
            status: StatusCode::INTERNAL_SERVER_ERROR,
            message: error.to_string(),
        }
    }
    fn unprocessable(message: impl Into<String>) -> Self {
        Self {
            status: StatusCode::UNPROCESSABLE_ENTITY,
            message: message.into(),
        }
    }
    fn conflict(message: impl Into<String>) -> Self {
        Self {
            status: StatusCode::CONFLICT,
            message: message.into(),
        }
    }
    fn unauthorized(message: impl Into<String>) -> Self {
        Self {
            status: StatusCode::UNAUTHORIZED,
            message: message.into(),
        }
    }
    fn service_unavailable(message: impl Into<String>) -> Self {
        Self {
            status: StatusCode::SERVICE_UNAVAILABLE,
            message: message.into(),
        }
    }
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        (self.status, Json(json!({ "detail": self.message }))).into_response()
    }
}

pub fn router(state: AppState) -> Router {
    Router::new()
        .route("/health", get(health))
        .route("/ready", get(readiness))
        .route("/api/v1/system", get(system))
        .route("/api/v1/system/status", get(system_status))
        .route("/api/v1/system/readiness", get(production_readiness_status))
        .route("/api/v1/data/plan", get(data_plan))
        .route("/api/v1/data/sources", get(data_sources))
        .route("/api/v1/data/readiness", get(data_readiness))
        .route("/api/v1/data/capabilities", get(data_capabilities))
        .route("/api/v1/research/universe", get(research_universe))
        .route(
            "/api/v1/research/session-summary",
            get(research_session_summary),
        )
        .route("/api/v1/research/ticker-rag", get(research_ticker_rag))
        .route("/api/v1/research/daily-regime", get(research_daily_regime))
        .route("/api/v1/research/factor-shadow", get(factor_shadow_status))
        .route("/api/v1/live/status", get(live_status))
        .route("/api/v1/live/events", get(live_events))
        .route("/api/v1/live/bars", get(live_bars))
        .route(
            "/api/v1/live/ibkr/quotes",
            get(ibkr_relay_quotes).post(ibkr_relay_ingest),
        )
        .route(
            "/api/v1/live/moomoo/forecasts",
            get(moomoo_owner_forecast_relay_status).post(moomoo_owner_forecast_relay_ingest),
        )
        .route("/api/v1/live/gaps", get(live_gaps))
        .route("/api/v1/live/capabilities", get(live_capabilities))
        .route("/api/v1/options/intel/{underlying}", get(options_intel))
        .route("/api/v1/broker/status", get(broker_status))
        .route("/api/v1/data/coverage", get(data_coverage))
        .route("/api/v1/data/status", get(data_coverage))
        .route("/api/v1/data/estimate", post(data_estimate))
        .route("/api/v1/data/validate", post(data_validate))
        .route("/api/v1/data/lineage/{artifact_id}", get(data_lineage))
        .route("/api/v1/predictor/forecast", get(predictor_forecast))
        .route(
            "/api/v1/predictor/owner-preview",
            get(predictor_owner_preview),
        )
        .route("/api/v1/predictor/model", get(predictor_model))
        .route(
            "/api/v1/predictor/walk-forward",
            get(predictor_walk_forward),
        )
        .route("/api/v1/predictor/calibration", get(predictor_calibration))
        .route("/api/v1/predictor/shadow", get(predictor_shadow))
        .route("/api/v1/predictor/settlements", get(predictor_settlements))
        .route("/api/v1/predictor/regime", get(predictor_regime))
        .route(
            "/api/v1/research/opportunities",
            get(research_opportunities),
        )
        .route("/api/v1/research/query", post(research_query))
        .route("/v1/scan", post(research_scan))
        .route("/v1/backtest/query", post(research_backtest_query))
        .route(
            "/api/v1/memory/summary",
            get(crate::research_api::memory_summary),
        )
        .route(
            "/api/v1/events/atlas",
            get(crate::research_api::event_atlas),
        )
        .route(
            "/api/v1/analogs/current",
            get(crate::research_api::analogs_current),
        )
        .route(
            "/api/v1/state/current",
            get(crate::research_api::state_current),
        )
        .route(
            "/api/v1/research/factory",
            get(crate::research_api::research_factory),
        )
        .route(
            "/api/v1/audit/predictions",
            get(crate::research_api::audit_predictions),
        )
        .route("/api/v1/context/fusion", get(context_fusion))
        .route("/api/v1/allocation/betting", get(betting_allocation))
        .route("/api/v1/risk/portfolio-analytics", get(portfolio_analytics))
        .route("/api/v1/features/current", get(current_features))
        .route("/api/v1/models", get(models))
        .route("/api/v1/models/{model_id}", get(model))
        .route("/api/v1/predictions/current", get(current_predictions))
        .route("/api/v1/signals/current", get(current_signal))
        .route("/api/v1/portfolio", get(portfolio))
        .route("/api/v1/risk", get(risk))
        .route("/api/v1/orders", get(orders))
        .route("/api/v1/fills", get(fills))
        .route("/api/v1/experiments", get(list_runs))
        .route("/api/v1/experiments/{run_id}", get(get_run))
        .route("/api/v1/research/backtest", post(start_run))
        .route("/api/v1/paper/start", post(paper_start))
        .route("/api/v1/paper/stop", post(paper_stop))
        .route("/api/v1/risk/kill", post(risk_kill))
        .route("/api/v1/risk/resume", post(risk_resume))
        .route("/api/v1/replay/last-session", post(replay_last_session))
        .route("/api/v1/audit", get(audit))
        .route("/api/v1/stream", get(stream_snapshot))
        .route("/api/v1/overview", get(overview))
        .route("/api/v1/runs", get(list_runs).post(start_run))
        .route("/api/v1/runs/{run_id}", get(get_run))
        .layer(middleware::from_fn(require_research_token))
        .layer(TraceLayer::new_for_http())
        .with_state(state)
}

pub async fn serve(config: AppConfig) -> Result<()> {
    let registry = Registry::open(&config.server.registry_path)?;
    let runtime = QuantRuntime::new(config.os.clone());
    let broker_monitor = BrokerMonitor::new(&config.execution);
    if config.execution.enabled {
        tokio::spawn(crate::broker::run_reconciliation_loop(
            config.execution.clone(),
            runtime.clone(),
            broker_monitor.clone(),
        ));
    }
    let address = SocketAddr::new(config.server.host.parse()?, config.server.port);
    let app = router(AppState {
        config: Arc::new(config),
        registry,
        runtime,
        broker_monitor,
    });
    let listener = tokio::net::TcpListener::bind(address).await?;
    tracing::info!(%address, "AXIO7 Rust quant control plane listening");
    axum::serve(listener, app).await?;
    Ok(())
}

async fn broker_status(State(state): State<AppState>) -> Json<Value> {
    Json(json!({
        "reconciliation": state.broker_monitor.status(),
        "portfolio_authoritative": state.runtime.portfolio_is_authoritative(),
        "portfolio_source": state.runtime.authoritative_portfolio_source(),
        "execution_provider": state.config.execution.provider,
        "execution_mode": state.config.execution.mode,
        "real_orders_configured": state.config.execution.mode == "real"
            && state.config.execution.allow_real_orders,
        "truth": "A connected broker snapshot is required before allocation or order routing; connection alone never authorizes an order"
    }))
}

async fn system_status(State(state): State<AppState>) -> Json<Value> {
    Json(json!({
        "service": "quantd",
        "architecture": "event_driven_in_process",
        "control_plane": "Axum HTTP",
        "runtime": state.runtime.status(),
        "hot_path": ["market_event", "feature_snapshot", "model_inference", "ensemble", "risk", "paper_oms"],
        "frontend_role": "display_and_control_only",
        "production_readiness": production_readiness_receipt(&state)
    }))
}

fn production_readiness_receipt(
    state: &AppState,
) -> crate::production_readiness::ProductionReadinessReceipt {
    let now = chrono::Utc::now();
    let root = state
        .config
        .data
        .raw_root
        .parent()
        .unwrap_or(std::path::Path::new("data"));
    let promotion_registry = inspect_promotion_registry(root).registry;
    crate::production_readiness::build(
        &state.config,
        now,
        |payload, canonical, evaluation_as_of, maximum_age_seconds| {
            validate_live_forecast_bundle(
                payload,
                &state.config.live.provider,
                canonical,
                &state.config.research.horizons,
                evaluation_as_of,
                maximum_age_seconds,
            )
            .is_ok()
        },
        |row| {
            promotion_registry.as_ref().is_some_and(|registry| {
                parse_utc(row.get("decision_as_of").or_else(|| row.get("as_of"))).is_some_and(
                    |forecast_as_of| registry.matches_forecast_row(row, forecast_as_of, now),
                )
            })
        },
        |row| live_prediction_is_ledger_backed(root, &state.config.live.provider, row),
    )
}

fn target_inference_projection(receipt: &ProductionReadinessReceipt, symbol: &str) -> Value {
    receipt
        .forecasts
        .iter()
        .find(|forecast| forecast.symbol.eq_ignore_ascii_case(symbol))
        .map(|forecast| json!(&forecast.live_inference))
        .unwrap_or_else(|| {
            json!({
                "required":true,
                "status_available":false,
                "status":null,
                "stage":null,
                "reason_code":"TARGET_READINESS_NOT_CONFIGURED",
                "status_freshness":"UNAVAILABLE",
                "cutoff":null,
                "latest_input_available_at":null,
                "compute_ms":null,
                "end_to_end_ms":null,
                "budget_ms":null,
                "context_blockers":[],
                "forecast_committed":false,
                "receipt_committed":false,
                "ledger_persisted":false,
                "ready":false
            })
        })
}

fn pipeline_stage(
    state: PipelineReadinessState,
    code: impl Into<String>,
    detail: impl Into<String>,
    observed_at: Option<chrono::DateTime<chrono::Utc>>,
) -> PipelineReadinessStage {
    PipelineReadinessStage {
        state,
        code: Some(code.into()),
        detail: Some(detail.into()),
        observed_at,
    }
}

fn research_pipeline_readiness(
    state: &AppState,
    query: &MarketQuery,
    receipt: &ProductionReadinessReceipt,
    candidates: &[ResearchCandidate],
) -> PipelineReadiness {
    if query.intent == MarketQueryIntent::Backtest {
        return PipelineReadiness::default();
    }

    let requested_model_symbols = query
        .symbols
        .iter()
        .filter_map(|symbol| {
            state
                .config
                .research
                .targets
                .iter()
                .find(|target| target.public_symbol.eq_ignore_ascii_case(symbol))
                .map(|target| target.model_symbol.to_ascii_uppercase())
        })
        .collect::<BTreeSet<_>>();
    let runtime = frozen_model_runtime_projection(state);
    let loaded_symbols = runtime
        .get("symbols")
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .filter(|row| row.get("status").and_then(Value::as_str) == Some("LOADED"))
        .filter_map(|row| row.get("model_symbol").and_then(Value::as_str))
        .map(str::to_ascii_uppercase)
        .collect::<BTreeSet<_>>();
    let all_models_loaded =
        !requested_model_symbols.is_empty() && requested_model_symbols.is_subset(&loaded_symbols);
    let model = if all_models_loaded {
        pipeline_stage(
            PipelineReadinessState::Ready,
            "REQUESTED_FROZEN_MODELS_LOADED",
            "Every requested frozen model artifact passed runtime loading and compatibility checks.",
            None,
        )
    } else {
        pipeline_stage(
            PipelineReadinessState::Blocked,
            "REQUESTED_FROZEN_MODELS_NOT_LOADED",
            "One or more requested frozen model artifacts failed or were absent at runtime.",
            None,
        )
    };

    let feed_ready = receipt.market_data.public_use_rights.status == MarketDataRightsStatus::Ready
        && receipt.market_data.provider_entitlement == EvidenceStatus::Ready
        && receipt.market_data.stream_freshness == FreshnessStatus::Fresh
        && receipt.market_data.feed_freshness == FreshnessStatus::Fresh;
    let feed = if feed_ready {
        pipeline_stage(
            PipelineReadinessState::Ready,
            "LICENSED_REALTIME_FEED_FRESH",
            "The selected licensed realtime feed and completed-bar archive passed freshness checks.",
            None,
        )
    } else {
        pipeline_stage(
            PipelineReadinessState::Blocked,
            "LICENSED_REALTIME_FEED_NOT_READY",
            "The licensed realtime feed, public-display authorization, or completed-bar freshness gate did not pass.",
            None,
        )
    };

    if !matches!(
        query.setup_type,
        MarketSetupType::ModelForecast | MarketSetupType::StatisticalDislocation
    ) {
        return PipelineReadiness {
            model,
            feed,
            ..PipelineReadiness::default()
        };
    }

    let target_rows = receipt
        .forecasts
        .iter()
        .filter(|forecast| {
            requested_model_symbols
                .iter()
                .any(|symbol| forecast.symbol.eq_ignore_ascii_case(symbol))
        })
        .collect::<Vec<_>>();
    let latest_observed = target_rows
        .iter()
        .filter_map(|forecast| forecast.live_inference.cutoff)
        .max();
    if !candidates.is_empty() {
        let ready = |code: &str, detail: &str| {
            pipeline_stage(PipelineReadinessState::Ready, code, detail, latest_observed)
        };
        return PipelineReadiness {
            model,
            feed,
            context: ready(
                "POINT_IN_TIME_CONTEXT_COMPLETE",
                "Every required target and context input passed the common-cutoff gate.",
            ),
            inference: ready(
                "FROZEN_INFERENCE_COMPLETED",
                "The frozen model completed inference for the visible forecast.",
            ),
            publication: ready(
                "FORECAST_PUBLICATION_COMMITTED",
                "The forecast, source receipt, and append-only publication ledger commit were verified.",
            ),
        };
    }

    if target_rows.is_empty() {
        return PipelineReadiness {
            model,
            feed,
            context: pipeline_stage(
                PipelineReadinessState::NotChecked,
                "TARGET_CONTEXT_STATUS_UNAVAILABLE",
                "No target-specific context receipt is available yet.",
                None,
            ),
            inference: pipeline_stage(
                PipelineReadinessState::NotChecked,
                "TARGET_INFERENCE_STATUS_UNAVAILABLE",
                "No target-specific inference receipt is available yet.",
                None,
            ),
            publication: pipeline_stage(
                PipelineReadinessState::NotChecked,
                "TARGET_PUBLICATION_STATUS_UNAVAILABLE",
                "No target-specific publication receipt is available yet.",
                None,
            ),
        };
    }

    let any_context_blocked = target_rows
        .iter()
        .any(|row| !row.live_inference.context_blockers.is_empty());
    let any_waiting_context = target_rows
        .iter()
        .any(|row| row.live_inference.status == Some(TargetInferenceState::WaitingForContext));
    let all_context_passed = target_rows.iter().all(|row| {
        row.live_inference.context_blockers.is_empty()
            && matches!(
                row.live_inference.stage,
                Some(
                    TargetInferenceStage::FrozenInference
                        | TargetInferenceStage::SlaGate
                        | TargetInferenceStage::PredictionLedger
                        | TargetInferenceStage::PublishStaging
                        | TargetInferenceStage::PublishCommit
                        | TargetInferenceStage::Published
                )
            )
    });
    let context = if all_context_passed {
        pipeline_stage(
            PipelineReadinessState::Ready,
            "POINT_IN_TIME_CONTEXT_COMPLETE",
            "Target-specific receipts show that the common-cutoff context gate passed.",
            latest_observed,
        )
    } else if any_context_blocked || any_waiting_context {
        pipeline_stage(
            PipelineReadinessState::Waiting,
            "POINT_IN_TIME_CONTEXT_INCOMPLETE",
            "One or more required target or context intervals are missing, stale, duplicated, or not causally observable.",
            latest_observed,
        )
    } else {
        pipeline_stage(
            PipelineReadinessState::NotChecked,
            "POINT_IN_TIME_CONTEXT_NOT_REACHED",
            "The target has not reached the context-validation stage.",
            latest_observed,
        )
    };

    let any_inference_rejected = target_rows.iter().any(|row| {
        matches!(
            row.live_inference.status,
            Some(
                TargetInferenceState::CompatibilityRejected
                    | TargetInferenceState::SlaRejected
                    | TargetInferenceState::PublishRejected
            )
        )
    });
    let any_running = target_rows
        .iter()
        .any(|row| row.live_inference.status == Some(TargetInferenceState::Running));
    let all_inferred = target_rows.iter().all(|row| {
        row.live_inference.status == Some(TargetInferenceState::Published)
            || matches!(
                row.live_inference.stage,
                Some(
                    TargetInferenceStage::SlaGate
                        | TargetInferenceStage::PredictionLedger
                        | TargetInferenceStage::PublishStaging
                        | TargetInferenceStage::PublishCommit
                        | TargetInferenceStage::Published
                )
            )
    });
    let inference = if any_inference_rejected {
        pipeline_stage(
            PipelineReadinessState::Blocked,
            "FROZEN_INFERENCE_REJECTED",
            "A compatibility, latency, or inference gate rejected the target.",
            latest_observed,
        )
    } else if all_inferred {
        pipeline_stage(
            PipelineReadinessState::Ready,
            "FROZEN_INFERENCE_COMPLETED",
            "Target-specific receipts show that frozen inference completed.",
            latest_observed,
        )
    } else if any_running {
        pipeline_stage(
            PipelineReadinessState::Waiting,
            "FROZEN_INFERENCE_RUNNING",
            "Frozen inference is currently running.",
            latest_observed,
        )
    } else {
        pipeline_stage(
            PipelineReadinessState::Waiting,
            "FROZEN_INFERENCE_WAITING_FOR_INPUTS",
            "Frozen inference is waiting for an eligible target and complete context.",
            latest_observed,
        )
    };

    let any_publish_rejected = target_rows.iter().any(|row| {
        matches!(
            row.live_inference.status,
            Some(TargetInferenceState::PublishRejected | TargetInferenceState::SlaRejected)
        )
    });
    let publication = if any_publish_rejected {
        pipeline_stage(
            PipelineReadinessState::Blocked,
            "FORECAST_PUBLICATION_REJECTED",
            "The forecast failed its latency, staging, receipt, or append-only publication gate.",
            latest_observed,
        )
    } else {
        pipeline_stage(
            PipelineReadinessState::Waiting,
            "FORECAST_NOT_VISIBLE",
            "No forecast passed every customer-visible publication gate for this request.",
            latest_observed,
        )
    };
    PipelineReadiness {
        model,
        feed,
        context,
        inference,
        publication,
    }
}

const FACTOR_SHADOW_SCHEMA_VERSION: &str = "axio.factor-shadow-status.v1";
const FACTOR_SHADOW_CANDIDATE_ID: &str = "axio.pv-multifactor-40-20-40";
const FACTOR_SHADOW_CANDIDATE_VERSION: &str = "v1";
const FACTOR_SHADOW_STATUS: &str = "CANDIDATE_NOT_PROMOTED";

#[derive(Debug, Serialize)]
struct FactorShadowCandidateMetadata {
    candidate_id: &'static str,
    candidate_version: &'static str,
    owner: &'static str,
    scope: &'static str,
    status: &'static str,
}

#[derive(Debug, Serialize)]
struct FactorShadowFixedWeights {
    momentum: u8,
    liquidity_proxy: u8,
    regime_and_other_price_volume: u8,
}

#[derive(Debug, Serialize)]
struct FactorShadowStatus {
    schema_version: &'static str,
    candidate: FactorShadowCandidateMetadata,
    fixed_weights_percent: FactorShadowFixedWeights,
    blockers: [&'static str; 3],
    execution: &'static str,
}

fn factor_shadow_status_contract() -> FactorShadowStatus {
    FactorShadowStatus {
        schema_version: FACTOR_SHADOW_SCHEMA_VERSION,
        candidate: FactorShadowCandidateMetadata {
            candidate_id: FACTOR_SHADOW_CANDIDATE_ID,
            candidate_version: FACTOR_SHADOW_CANDIDATE_VERSION,
            owner: "quant_engine_rs",
            scope: "IMPERSONAL_CROSS_SECTIONAL_MARKET_RESEARCH_SHADOW",
            status: FACTOR_SHADOW_STATUS,
        },
        fixed_weights_percent: FactorShadowFixedWeights {
            momentum: 40,
            liquidity_proxy: 20,
            regime_and_other_price_volume: 40,
        },
        blockers: [
            "POINT_IN_TIME_UNIVERSE_NOT_VALIDATED",
            "LIQUIDITY_PROXY_NOT_VALIDATED",
            "PURGED_WALK_FORWARD_AND_FORWARD_SHADOW_INCOMPLETE",
        ],
        execution: "DISABLED",
    }
}

async fn factor_shadow_status() -> Json<FactorShadowStatus> {
    Json(factor_shadow_status_contract())
}

async fn production_readiness_status(
    State(state): State<AppState>,
) -> Json<crate::production_readiness::ProductionReadinessReceipt> {
    Json(production_readiness_receipt(&state))
}

fn live_supervisor_blocker_present(status: &Value) -> bool {
    status.get("blocker").is_some_and(|blocker| match blocker {
        Value::Null => false,
        Value::String(message) => !message.trim().is_empty(),
        _ => true,
    })
}

fn evaluate_live_supervisor_status(
    provider: &str,
    status: &Value,
    now: chrono::DateTime<Utc>,
    maximum_age_ms: i64,
) -> (bool, Vec<String>) {
    let mut reasons = Vec::new();
    let updated_at = parse_utc(
        status
            .get("updated_at")
            .or_else(|| status.get("checked_at")),
    );
    match updated_at {
        Some(updated_at) => {
            let age_ms = now.signed_duration_since(updated_at).num_milliseconds();
            if age_ms < 0 || age_ms > maximum_age_ms {
                reasons.push("LIVE_SUPERVISOR_STATUS_STALE".to_string());
            }
        }
        None => reasons.push("LIVE_SUPERVISOR_STATUS_TIMESTAMP_MISSING".to_string()),
    }

    if live_supervisor_blocker_present(status) {
        reasons.push("LIVE_SUPERVISOR_BLOCKED".to_string());
    }

    match provider {
        "databento" => {
            if status.get("state").and_then(Value::as_str) != Some("STREAMING_REALTIME") {
                reasons.push("DATABENTO_STREAM_NOT_RUNNING".to_string());
            }
            if status.get("authenticated").and_then(Value::as_bool) != Some(true) {
                reasons.push("DATABENTO_NOT_AUTHENTICATED".to_string());
            }
            if status.get("entitlement_verified").and_then(Value::as_bool) != Some(true) {
                reasons.push("DATABENTO_ENTITLEMENT_NOT_VERIFIED".to_string());
            }
        }
        "massive" => {
            if status.get("state").and_then(Value::as_str) != Some("STREAMING_REALTIME") {
                reasons.push("MASSIVE_EQUITY_STREAM_NOT_RUNNING".to_string());
            }
            if status.get("authenticated").and_then(Value::as_bool) != Some(true) {
                reasons.push("MASSIVE_EQUITY_STREAM_NOT_AUTHENTICATED".to_string());
            }
        }
        _ => {
            if status.get("status").and_then(Value::as_str)
                != Some("CONNECTED_QUOTE_PROTOCOL_VERIFIED")
            {
                reasons.push("LEGACY_LIVE_ADAPTER_NOT_VERIFIED".to_string());
            }
        }
    }
    (reasons.is_empty(), reasons)
}

async fn readiness(State(state): State<AppState>) -> Response {
    if !state.config.live.enabled {
        return (
            StatusCode::OK,
            Json(json!({
                "status":"ready",
                "live_enabled":false,
                "readiness_scope":"control_plane_only",
                "bar_freshness_evaluated":false,
                "truth":"The control plane is ready; live market inference is explicitly disabled."
            })),
        )
            .into_response();
    }
    let provider = state.config.live.provider.as_str();
    let status_file = match provider {
        "databento" => "databento_stream_status.json",
        "massive" => "massive_stream_status.json",
        _ => "status.json",
    };
    let status = match read_json_if_present(&live_root(&state).join(status_file)) {
        Ok(status) => status,
        Err(error) => return error.into_response(),
    };
    let maximum_age_ms = i64::try_from(
        state
            .config
            .live
            .reconnect_max_ms
            .saturating_mul(2)
            .max(30_000),
    )
    .unwrap_or(i64::MAX);
    let (ready, reasons) =
        evaluate_live_supervisor_status(provider, &status, Utc::now(), maximum_age_ms);
    let response_status = if ready {
        StatusCode::OK
    } else {
        StatusCode::SERVICE_UNAVAILABLE
    };
    (
        response_status,
        Json(json!({
            "status":if ready { "ready" } else { "not_ready" },
            "live_enabled":true,
            "provider":provider,
            "readiness_scope":"supervisor_connection",
            "bar_freshness_evaluated":false,
            "production_readiness_endpoint":"/api/v1/system/readiness",
            "maximum_status_age_ms":maximum_age_ms,
            "reasons":reasons,
            "supervisor":status,
            "truth":"Readiness covers only a fresh authenticated, unblocked provider supervisor connection. It does not evaluate finalized-bar freshness; use the production-readiness receipt for publication readiness."
        })),
    )
        .into_response()
}

async fn health() -> Json<Value> {
    Json(json!({
        "status": "ok", "runtime": "rust", "backend": "axum",
        "hot_path_transport": "in_process", "python_backend": false,
        "scope":"liveness_only", "readiness_endpoint":"/ready"
    }))
}

async fn system(State(state): State<AppState>) -> Json<Value> {
    Json(json!({
        "engine": "axio-quant-engine", "language": "Rust", "api": "Axum",
        "registry": "SQLite WAL (metadata only)",
        "raw_market_store": "immutable vendor DBN/DBN.ZST/JSON chunks",
        "production_analytics_store": "ClickHouse or QuestDB adapter boundary",
        "broker": state.config.data.broker,
        "rules": {
            "http_inside_event_path": false,
            "python_backend": false,
            "signal_to_entry": "t close -> earliest t+1",
            "option_fills": "buy ask+slippage; sell bid-slippage"
        }
    }))
}

async fn data_plan(State(state): State<AppState>) -> Json<Value> {
    let requests: Vec<Value> = state.config.data.databento.requests.iter().map(|request| json!({
        "name": request.name, "provider": "Databento", "dataset": request.dataset,
        "schema": request.schema, "symbols": request.symbols, "start": request.start,
        "end": request.end, "requires_api_key": true,
        "status": if std::env::var_os("DATABENTO_API_KEY").is_some() { "ready_for_cost_estimate" } else { "blocked_missing_api_key" }
    })).collect();
    Json(json!({
        "requests": requests,
        "massive": crate::data::massive::status(&state.config.data.massive),
        "cboe": state.config.data.cboe,
        "required_symbols": state.config.data.required_symbols,
        "purchase_guard": "cost estimate + --confirm-cost + --maximum-cost-usd are mandatory",
        "broker_history_allowed": false,
        "free_data_path": "Massive 1m stock aggregates -> normalized market_bars.csv -> point-in-time SPY model"
    }))
}

async fn research_universe(State(state): State<AppState>) -> Json<Value> {
    let model_runtime = frozen_model_runtime_projection(&state);
    let targets = state
        .config
        .research
        .targets
        .iter()
        .map(|target| {
            json!({
                "public_symbol": target.public_symbol,
                "model_symbol": target.model_symbol,
                "price_symbol": target.price_symbol,
                "options_underlying": target.options_underlying,
                "vwap_volume_source": target.vwap_volume_source,
                "status": target.target_status,
            })
        })
        .collect::<Vec<_>>();
    Json(json!({
        "status": "CONFIGURED_RESEARCH_UNIVERSE",
        "targets": targets,
        "forecast_horizons_minutes": state.config.research.horizons,
        "production_inference_owner": "quant_engine_rs",
        "model_runtime": model_runtime,
        "model_layers": {
            "regime": "chronologically selected frozen Gaussian HMM",
            "analog": "same-regime horizon-matched causal kernel",
            "stochastic": {
                "family": "Markov-switching log-return diffusion + VWAP-residual Ornstein-Uhlenbeck + regime-conditioned momentum",
                "mode": "FROZEN_RESEARCH_SHADOW",
                "affects_published_probability": false,
                "reason": "requires separate out-of-sample validation, calibration, immutable promotion, and live shadow evidence"
            },
            "gamma": {
                "mode": "CONDITIONAL_STRUCTURE_RESEARCH",
                "dealer_sign_observed": false,
                "truth": "open interest and public OPRA fields do not reveal dealer inventory sign"
            }
        },
        "public_data_activation": {
            "status": "BLOCKED_UNTIL_REDISTRIBUTION_ENTITLEMENTS_PASS",
            "equities_requirement": "commercial US equity feed with external redistribution/model-use rights",
            "options_requirement": "OPRA vendor agreement and applicable external redistribution rights",
            "personal_free_feeds": "RESEARCH_ONLY"
        },
        "execution": "DISABLED",
        "product_boundary": "impersonal reproducible market research; no order placement or risk-free-arbitrage claims"
    }))
}

fn model_runtime_status(
    requested_artifact_count: usize,
    loaded_artifact_count: usize,
    failed_artifact_count: usize,
) -> &'static str {
    if requested_artifact_count > 0
        && loaded_artifact_count == requested_artifact_count
        && failed_artifact_count == 0
    {
        "LOADED"
    } else if loaded_artifact_count > 0 {
        "PARTIAL"
    } else {
        "UNAVAILABLE"
    }
}

fn sanitized_model_runtime_failure(reason: &str) -> &'static str {
    if reason.contains("REGISTRY_ARTIFACT_TARGET_MISMATCH") {
        "ARTIFACT_TARGET_MISMATCH"
    } else if reason.contains("REGISTRY_ARTIFACT_VERSION_MISMATCH") {
        "ARTIFACT_VERSION_MISMATCH"
    } else if reason.contains("REGISTRY_MODEL_HASH_MISMATCH") {
        "MODEL_HASH_MISMATCH"
    } else if reason.contains("unsupported frozen predictor artifact version") {
        "UNSUPPORTED_ARTIFACT_VERSION"
    } else if reason.contains("identity or lineage is incomplete") {
        "ARTIFACT_LINEAGE_INCOMPLETE"
    } else if reason.contains("feature schema mismatch") {
        "FEATURE_SCHEMA_MISMATCH"
    } else if reason.contains("persisted regime selection") {
        "REGIME_SELECTION_MISMATCH"
    } else if reason.contains("analog index count") {
        "ANALOG_INDEX_COUNT_MISMATCH"
    } else if reason.contains("stochastic distribution head") {
        "STOCHASTIC_HEAD_INVALID"
    } else if reason.contains("artifact hash mismatch") {
        "ARTIFACT_CONTENT_HASH_MISMATCH"
    } else if reason.contains("deserialize") {
        "ARTIFACT_DESERIALIZATION_FAILED"
    } else if reason.contains("validate") {
        "ARTIFACT_STATIC_VALIDATION_FAILED"
    } else if reason.contains("read") {
        "ARTIFACT_NOT_READABLE"
    } else {
        "ARTIFACT_REJECTED"
    }
}

fn frozen_model_runtime_projection(state: &AppState) -> Value {
    let root = state
        .config
        .data
        .raw_root
        .parent()
        .unwrap_or(std::path::Path::new("data"));
    let registry_path = root.join("models/universe/registry.json");
    let requested_symbols = state
        .config
        .research
        .targets
        .iter()
        .filter_map(|target| {
            let symbol = target.model_symbol.trim().trim_start_matches("US.");
            (!symbol.is_empty()).then(|| symbol.to_ascii_uppercase())
        })
        .collect::<BTreeSet<_>>();
    let requested_artifact_count = requested_symbols.len();

    match load_frozen_universe(&registry_path, requested_symbols.iter()) {
        Ok(universe) => {
            let loaded_symbols = universe
                .artifacts()
                .keys()
                .cloned()
                .collect::<BTreeSet<_>>();
            let failed_symbols = universe.failures().keys().cloned().collect::<BTreeSet<_>>();
            let loaded_artifact_count = loaded_symbols.len();
            let failed_artifact_count = failed_symbols.len();
            let symbols = requested_symbols
                .iter()
                .map(|symbol| {
                    let failure_code = universe
                        .failures()
                        .get(symbol)
                        .map(|reason| sanitized_model_runtime_failure(reason));
                    json!({
                        "model_symbol": symbol,
                        "status": if loaded_symbols.contains(symbol) {
                            "LOADED"
                        } else if failed_symbols.contains(symbol) {
                            "REJECTED"
                        } else {
                            "UNAVAILABLE"
                        },
                        "reason_code": failure_code
                    })
                })
                .collect::<Vec<_>>();
            json!({
                "schema_version": "axio.model-runtime-receipt.v1",
                "status": model_runtime_status(
                    requested_artifact_count,
                    loaded_artifact_count,
                    failed_artifact_count,
                ),
                "requested_artifact_count": requested_artifact_count,
                "loaded_artifact_count": loaded_artifact_count,
                "failed_artifact_count": failed_artifact_count,
                "symbols": symbols,
                "quality_and_promotion_checked_separately": true,
                "automatic_execution_enabled": false
            })
        }
        Err(_) => json!({
            "schema_version": "axio.model-runtime-receipt.v1",
            "status": "UNAVAILABLE",
            "requested_artifact_count": requested_artifact_count,
            "loaded_artifact_count": 0,
            "failed_artifact_count": requested_artifact_count,
            "symbols": requested_symbols
                .iter()
                .map(|symbol| json!({
                    "model_symbol":symbol,
                    "status":"UNAVAILABLE",
                    "reason_code":"REGISTRY_UNAVAILABLE"
                }))
                .collect::<Vec<_>>(),
            "quality_and_promotion_checked_separately": true,
            "automatic_execution_enabled": false
        }),
    }
}

async fn data_sources(State(state): State<AppState>) -> Result<Json<Value>, ApiError> {
    let report = crate::data::readiness::doctor(&state.config.data).map_err(ApiError::internal)?;
    Ok(Json(json!({
        "credentials": report.credentials,
        "sources": report.source_matrix,
        "underlying_proxy": report.underlying_proxy
    })))
}

async fn data_readiness(State(state): State<AppState>) -> Result<Json<Value>, ApiError> {
    let report = crate::data::readiness::doctor(&state.config.data).map_err(ApiError::internal)?;
    Ok(Json(json!(report.readiness)))
}

async fn data_capabilities(State(state): State<AppState>) -> Result<Json<Value>, ApiError> {
    let artifact = state
        .config
        .data
        .raw_root
        .parent()
        .unwrap_or(std::path::Path::new("data"))
        .join("quality/data_capability_latest.json");
    if artifact.exists() {
        return Ok(Json(read_json_if_present(&artifact)?));
    }
    let report =
        crate::data::capability::inspect(&state.config.data).map_err(ApiError::internal)?;
    let audit = crate::data::capability::capability_audit(&state.config.data)
        .map_err(ApiError::internal)?;
    Ok(Json(json!({"data":report,"capability_audit":audit})))
}

fn credential_configured(name: &str) -> bool {
    std::env::var(name)
        .ok()
        .is_some_and(|value| !value.trim().is_empty())
}

fn public_observation_readiness_blockers(
    selected_provider: &str,
    receipt: &ProductionReadinessReceipt,
) -> Vec<String> {
    let mut blockers = Vec::new();
    if receipt.market_data.selected_provider != selected_provider {
        blockers.push("PUBLIC_MARKET_DATA_PROVIDER_MISMATCH".to_string());
    }
    if !receipt.market_data.live_enabled {
        blockers.push("PUBLIC_MARKET_DATA_LIVE_FEED_DISABLED".to_string());
    }
    if receipt.market_data.public_use_rights.status != MarketDataRightsStatus::Ready {
        blockers.push(format!(
            "PUBLIC_MARKET_DATA_RIGHTS_{}",
            receipt.market_data.public_use_rights.reason.code()
        ));
    }
    if receipt.market_data.provider_entitlement != EvidenceStatus::Ready {
        blockers.push("PUBLIC_MARKET_DATA_PROVIDER_ENTITLEMENT_NOT_READY".to_string());
    }
    if receipt.market_data.stream_freshness != FreshnessStatus::Fresh {
        blockers.push("PUBLIC_MARKET_DATA_STREAM_NOT_FRESH".to_string());
    }
    if receipt.market_data.feed_freshness != FreshnessStatus::Fresh {
        blockers.push("PUBLIC_MARKET_DATA_FINALIZED_FEED_NOT_FRESH".to_string());
    }
    if !receipt.artifacts.prediction_ledger_present {
        blockers.push("PREDICTION_LEDGER_NOT_READY".to_string());
    }
    blockers.sort();
    blockers.dedup();
    blockers
}

fn probability_publication_readiness_blockers(receipt: &ProductionReadinessReceipt) -> Vec<String> {
    let mut blockers = Vec::new();
    if receipt.artifacts.promotion_registry_status != PromotionRegistryStatus::ActivePinned {
        blockers.push("MODEL_PROMOTION_REGISTRY_NOT_ACTIVE_PINNED".to_string());
    }
    if receipt.artifacts.calibration_registry_status != CalibrationRegistryStatus::Promoted {
        blockers.push("MODEL_CALIBRATION_REGISTRY_NOT_PROMOTED".to_string());
    }
    if receipt.forecasts.is_empty() {
        blockers.push("PRODUCTION_FORECASTS_NOT_AVAILABLE".to_string());
    } else if receipt.forecasts.iter().any(|forecast| !forecast.ready) {
        blockers.push("PRODUCTION_FORECASTS_NOT_READY".to_string());
    }
    if receipt.status != OverallReadiness::Ready || !receipt.public_realtime_research_ready {
        blockers.push("PUBLIC_REALTIME_RESEARCH_READINESS_BLOCKED".to_string());
    }
    blockers.sort();
    blockers.dedup();
    blockers
}

fn context_source_requirements(domain_counts: &Value) -> Vec<Value> {
    let count = |domain: &str| {
        domain_counts
            .get(domain)
            .and_then(Value::as_u64)
            .unwrap_or(0)
    };
    let sec_rows = count("FUNDAMENTAL") + count("EARNINGSACTUAL") + count("FILING");
    let macro_rows = count("MACRO");
    let consensus_rows = count("EARNINGSCONSENSUS");
    let news_rows = count("NEWS");
    vec![
        json!({
            "domain":"SEC_ACTUALS_AND_FILINGS",
            "status":if sec_rows > 0 {"ARCHIVED"} else {"BLOCKED"},
            "normalized_rows":sec_rows,
            "credential_configured":credential_configured("SEC_USER_AGENT"),
            "required_credential":"SEC_USER_AGENT",
            "truth":"SEC actuals do not contain analyst consensus or management guidance estimates"
        }),
        json!({
            "domain":"ALFRED_MACRO_VINTAGES",
            "status":if macro_rows > 0 {"ARCHIVED"} else {"BLOCKED"},
            "normalized_rows":macro_rows,
            "credential_configured":credential_configured("FRED_API_KEY"),
            "required_credential":"FRED_API_KEY",
            "truth":"Training accepts initial-release/vintage observations, never today's revised FRED history projected backwards"
        }),
        json!({
            "domain":"EARNINGS_CONSENSUS_HISTORY",
            "status":if consensus_rows > 0 {"ARCHIVED"} else {"BLOCKED"},
            "normalized_rows":consensus_rows,
            "credential_configured":credential_configured("LSEG_CLIENT_ID") || credential_configured("BENZINGA_API_KEY") || credential_configured("INTRINIO_API_KEY"),
            "required_credential":"licensed point-in-time consensus vendor",
            "truth":"No consensus means no earnings-surprise feature"
        }),
        json!({
            "domain":"POINT_IN_TIME_NEWS",
            "status":if news_rows > 0 {"ARCHIVED"} else {"BLOCKED"},
            "normalized_rows":news_rows,
            "credential_configured":credential_configured("LSEG_CLIENT_ID") || credential_configured("BENZINGA_API_KEY"),
            "required_credential":"licensed news history with first-public timestamps and model-use rights",
            "truth":"A current news search is not a historical point-in-time news archive"
        }),
        json!({
            "domain":"MARKET_TAPE",
            "status":"SEPARATE_TAPE_PIPELINE",
            "credential_configured":credential_configured("MASSIVE_API_KEY") || credential_configured("DATABENTO_API_KEY"),
            "required_credential":"Massive/Databento plus the relevant exchange entitlement",
            "truth":"Tape readiness is audited by /api/v1/data/capabilities"
        }),
    ]
}

async fn context_fusion(State(state): State<AppState>) -> Result<Json<Value>, ApiError> {
    let config = &state.config.data.context;
    let as_of = chrono::Utc::now();
    if !config.enabled {
        return Ok(Json(json!({
            "status":"BLOCKED",
            "as_of":as_of,
            "provider":config.provider,
            "input_path":config.input_path,
            "point_in_time_ready":false,
            "model_feature_ready":false,
            "production_context_ready":false,
            "observation_count":0,
            "model_eligible_fields":[],
            "latest_features":[],
            "official_archive_verification":{"verified":false,"reason_codes":["CONTEXT_FEED_DISABLED"]},
            "required_sources":context_source_requirements(&json!({})),
            "prohibited_uses":[
                "current-only macro snapshots in historical backtests",
                "filing-date placeholders instead of SEC acceptanceDateTime",
                "earnings surprise without point-in-time consensus",
                "model promotion without an isolated ablation"
            ],
            "reason_codes":["CONTEXT_FEED_DISABLED","RUN_OFFICIAL_CONTEXT_SYNC_AND_AUDIT_BEFORE_ENABLING"]
        })));
    }
    if !config.input_path.exists() {
        return Ok(Json(json!({
            "status":"BLOCKED",
            "as_of":as_of,
            "provider":config.provider,
            "input_path":config.input_path,
            "point_in_time_ready":false,
            "model_feature_ready":false,
            "production_context_ready":false,
            "observation_count":0,
            "model_eligible_fields":[],
            "latest_features":[],
            "official_archive_verification":{"verified":false,"reason_codes":["CONTEXT_ARCHIVE_ABSENT"]},
            "required_sources":context_source_requirements(&json!({})),
            "prohibited_uses":["training or forecasting from an absent context archive"],
            "reason_codes":["CONTEXT_ARCHIVE_ABSENT"]
        })));
    }
    let snapshot = crate::data::context::fusion_snapshot(&config.input_path, config, as_of)
        .map_err(ApiError::internal)?;
    let mut value = serde_json::to_value(snapshot).map_err(ApiError::internal)?;
    let official_archive_verification = crate::data::context::verify_official_archive(
        &config.input_path,
        &state.config.data.manifest_root,
    );
    let official_archive_verified = official_archive_verification.verified;
    value["official_archive_verification"] =
        serde_json::to_value(official_archive_verification).map_err(ApiError::internal)?;
    let model_eligible_domain_counts = value
        .get("model_eligible_domain_counts")
        .cloned()
        .unwrap_or_else(|| json!({}));
    let required_sources = context_source_requirements(&model_eligible_domain_counts);
    let missing_required_context_domains = required_sources
        .iter()
        .take(4)
        .filter(|source| source.get("status").and_then(Value::as_str) != Some("ARCHIVED"))
        .filter_map(|source| source.get("domain").and_then(Value::as_str))
        .map(str::to_string)
        .collect::<Vec<_>>();
    let model_feature_ready = value
        .get("point_in_time_ready")
        .and_then(Value::as_bool)
        .unwrap_or(false)
        && official_archive_verified;
    let production_context_ready =
        model_feature_ready && missing_required_context_domains.is_empty();
    value["model_feature_ready"] = json!(model_feature_ready);
    value["production_context_ready"] = json!(production_context_ready);
    value["missing_required_context_domains"] = json!(missing_required_context_domains);
    value["required_sources"] = json!(required_sources);
    if !production_context_ready {
        value["status"] = json!(if model_feature_ready {
            "RESEARCH_ONLY"
        } else {
            "BLOCKED"
        });
        if let Some(reasons) = value.get_mut("reason_codes").and_then(Value::as_array_mut) {
            if !official_archive_verified {
                reasons.push(json!("OFFICIAL_CONTEXT_ARCHIVE_CHAIN_UNVERIFIED"));
            }
            reasons.push(json!("FULL_CONTEXT_SOURCE_MESH_INCOMPLETE"));
        }
    }
    Ok(Json(value))
}

fn scenarios_from_allocation_distribution(
    row: &Value,
) -> Result<Vec<crate::allocation::ScenarioOutcome>, ApiError> {
    if row
        .get("allocation_distribution_status")
        .and_then(Value::as_str)
        != Some("OOS_CALIBRATED_FULL_DISTRIBUTION")
        || row.get("tail_model_status").and_then(Value::as_str) != Some("OOS_VALIDATED")
    {
        return Err(ApiError::unprocessable(
            "allocation requires an OOS-calibrated full distribution with validated tail buckets",
        ));
    }
    let values = row
        .get("allocation_scenarios")
        .and_then(Value::as_array)
        .ok_or_else(|| ApiError::unprocessable("allocation scenarios are absent"))?;
    if values.len() < 5 {
        return Err(ApiError::unprocessable(
            "at least five scenarios including both explicit tail buckets are required",
        ));
    }
    let mut scenarios = values
        .iter()
        .map(|value| {
            let probability = value
                .get("probability")
                .and_then(Value::as_f64)
                .ok_or_else(|| ApiError::unprocessable("scenario probability is invalid"))?;
            let return_fraction = value
                .get("return_fraction")
                .and_then(Value::as_f64)
                .ok_or_else(|| ApiError::unprocessable("scenario return is invalid"))?;
            let kind = value
                .get("kind")
                .and_then(Value::as_str)
                .ok_or_else(|| ApiError::unprocessable("scenario kind is absent"))?;
            if !probability.is_finite()
                || probability <= 0.0
                || !return_fraction.is_finite()
                || return_fraction <= -1.0
            {
                return Err(ApiError::unprocessable(
                    "allocation scenario is outside its numeric domain",
                ));
            }
            if !matches!(kind, "LOWER_TAIL" | "BODY" | "UPPER_TAIL") {
                return Err(ApiError::unprocessable(
                    "scenario kind must be LOWER_TAIL, BODY, or UPPER_TAIL",
                ));
            }
            Ok((probability, return_fraction, kind))
        })
        .collect::<Result<Vec<_>, ApiError>>()?;
    scenarios.sort_by(|left, right| left.1.total_cmp(&right.1));
    if scenarios
        .windows(2)
        .any(|window| window[0].1 >= window[1].1)
    {
        return Err(ApiError::unprocessable(
            "allocation scenario returns must be strictly increasing",
        ));
    }
    let probability_sum = scenarios.iter().map(|row| row.0).sum::<f64>();
    if (probability_sum - 1.0).abs() > 1.0e-9 {
        return Err(ApiError::unprocessable(
            "allocation scenario probabilities must sum to one",
        ));
    }
    let valid_lower_tail = scenarios
        .first()
        .is_some_and(|(_, return_fraction, kind)| *kind == "LOWER_TAIL" && *return_fraction < 0.0);
    let valid_upper_tail = scenarios
        .last()
        .is_some_and(|(_, return_fraction, kind)| *kind == "UPPER_TAIL" && *return_fraction > 0.0);
    if !valid_lower_tail || !valid_upper_tail {
        return Err(ApiError::unprocessable(
            "allocation distribution requires explicit negative and positive tail expectations",
        ));
    }
    Ok(scenarios
        .into_iter()
        .map(
            |(probability, return_fraction, _)| crate::allocation::ScenarioOutcome {
                probability,
                return_fraction,
            },
        )
        .collect())
}

fn parse_utc(value: Option<&Value>) -> Option<chrono::DateTime<chrono::Utc>> {
    value
        .and_then(Value::as_str)
        .and_then(|value| chrono::DateTime::parse_from_rfc3339(value).ok())
        .map(|value| value.with_timezone(&chrono::Utc))
}

fn forecast_distribution_mean_matches(
    row: &Value,
    scenarios: &[crate::allocation::ScenarioOutcome],
) -> bool {
    let Some(expected_return) = row.get("expected_return").and_then(Value::as_f64) else {
        return false;
    };
    let scenario_mean = scenarios
        .iter()
        .map(|scenario| scenario.probability * scenario.return_fraction)
        .sum::<f64>();
    expected_return.is_finite() && (expected_return - scenario_mean).abs() <= 1.0e-8
}

fn validated_round_trip_cost_bps(row: &Value) -> Option<f64> {
    let status = row
        .pointer("/decision/cost_model_status")
        .and_then(Value::as_str)?;
    if !matches!(status, "OOS_VALIDATED" | "CONSERVATIVE_BOUND") {
        return None;
    }
    row.pointer("/decision/estimated_round_trip_cost_bps")
        .and_then(Value::as_f64)
        .filter(|cost| cost.is_finite() && *cost >= 0.0)
}

fn forecast_timestamps_are_fresh_and_causal(
    forecast_as_of: chrono::DateTime<chrono::Utc>,
    latest_input: Option<chrono::DateTime<chrono::Utc>>,
    evaluation_as_of: chrono::DateTime<chrono::Utc>,
    maximum_age_seconds: i64,
) -> (bool, bool) {
    let forecast_age = evaluation_as_of
        .signed_duration_since(forecast_as_of)
        .num_seconds();
    let forecast_fresh =
        maximum_age_seconds > 0 && forecast_age >= 0 && forecast_age <= maximum_age_seconds;
    let input_fresh_and_causal = latest_input.is_some_and(|timestamp| {
        let age = evaluation_as_of
            .signed_duration_since(timestamp)
            .num_seconds();
        age >= 0
            && age <= maximum_age_seconds
            && timestamp <= forecast_as_of
            && maximum_age_seconds > 0
    });
    (forecast_fresh, input_fresh_and_causal)
}

fn approximately_equal_notional(left: f64, right: f64) -> bool {
    left.is_finite()
        && right.is_finite()
        && (left - right).abs() <= 0.01_f64.max(1.0e-6 * left.abs().max(right.abs()))
}

fn risk_input_matches_runtime_portfolio(
    input: &crate::portfolio_risk::PortfolioRiskInput,
    runtime: &crate::os_domain::PortfolioSnapshot,
) -> bool {
    if !approximately_equal_notional(input.equity, runtime.equity) {
        return false;
    }
    let mut risk_positions = BTreeMap::new();
    for position in &input.positions {
        let symbol = position.symbol.trim().to_ascii_uppercase();
        if symbol.is_empty() || !position.market_value.is_finite() {
            return false;
        }
        if position.market_value.abs() <= f64::EPSILON {
            continue;
        }
        // The independent report and runtime portfolio must use the same
        // canonical one-row-per-symbol snapshot. Silent map overwrites would
        // otherwise let duplicate symbols evade the binding check.
        if risk_positions
            .insert(symbol, position.market_value)
            .is_some()
        {
            return false;
        }
    }
    let mut runtime_positions = BTreeMap::new();
    for position in &runtime.positions {
        let symbol = position.symbol.trim().to_ascii_uppercase();
        let market_value = position.quantity * position.mark_price;
        if symbol.is_empty() || !market_value.is_finite() {
            return false;
        }
        if market_value.abs() <= f64::EPSILON {
            continue;
        }
        if runtime_positions.insert(symbol, market_value).is_some() {
            return false;
        }
    }
    risk_positions.len() == runtime_positions.len()
        && risk_positions.iter().all(|(symbol, market_value)| {
            runtime_positions.get(symbol).is_some_and(|runtime_value| {
                approximately_equal_notional(*market_value, *runtime_value)
            })
        })
}

fn live_source_matches_expected_provider(expected_provider: &str, source: &str) -> bool {
    let canonical = source.to_ascii_uppercase();
    if canonical.contains("FIXTURE") || canonical.contains("REPLAY") {
        return false;
    }
    match expected_provider.trim().to_ascii_lowercase().as_str() {
        "databento" => source == "DATABENTO:EQUS.MINI",
        "moomoo" => source.starts_with("MOOMOO_OPEND:"),
        _ => false,
    }
}

fn live_prediction_is_ledger_backed(
    root: &std::path::Path,
    expected_provider: &str,
    row: &Value,
) -> bool {
    let evidence_kind_is_live =
        row.get("evidence_kind").and_then(Value::as_str) == Some("live_shadow_prediction");
    let source_is_live = row
        .get("data_source")
        .and_then(Value::as_str)
        .is_some_and(|source| live_source_matches_expected_provider(expected_provider, source));
    if !evidence_kind_is_live || !source_is_live {
        return false;
    }
    if expected_provider.eq_ignore_ascii_case("databento")
        && !crate::data::databento_inference::receipt_matches_forecast_row(root, row)
    {
        return false;
    }
    let Some(prediction_id) = row.get("prediction_id").and_then(Value::as_str) else {
        return false;
    };
    let ledger_path = root.join("state/prediction_ledger.sqlite3");
    if !ledger_path.exists() {
        return false;
    }
    crate::prediction_ledger::PredictionLedger::open(&ledger_path)
        .and_then(|ledger| {
            if expected_provider.eq_ignore_ascii_case("databento") {
                ledger.published_prediction_payload(prediction_id)
            } else {
                ledger.prediction_payload(prediction_id)
            }
        })
        .ok()
        .flatten()
        .is_some_and(|recorded| recorded == *row)
}

fn current_data_manifest_matches(config: &crate::config::DataConfig, row: &Value) -> bool {
    let Some(declared) = row.get("data_manifest_hash").and_then(Value::as_str) else {
        return false;
    };
    if !valid_nonzero_sha256(declared) {
        return false;
    }
    crate::data::capability::inspect(config)
        .ok()
        .is_some_and(|capability| {
            capability
                .manifest_hashes
                .iter()
                .any(|hash| hash.eq_ignore_ascii_case(declared))
                || capability
                    .normalized_file_sha256
                    .as_deref()
                    .is_some_and(|hash| hash.eq_ignore_ascii_case(declared))
        })
}

fn pinned_promotion_registry_matches(
    root: &std::path::Path,
    row: &Value,
    forecast_as_of: chrono::DateTime<chrono::Utc>,
    evaluation_as_of: chrono::DateTime<chrono::Utc>,
) -> bool {
    inspect_promotion_registry(root)
        .registry
        .is_some_and(|registry| {
            registry.matches_forecast_row(row, forecast_as_of, evaluation_as_of)
        })
}

fn blocked_betting_payload(
    row: Option<&Value>,
    reason: &str,
    detail: &str,
    policy: &crate::allocation::BettingPolicy,
) -> Value {
    json!({
        "status":"NO_TRADE",
        "policy_version":policy.policy_version,
        "symbol":row.and_then(|value| value.get("symbol")).and_then(Value::as_str),
        "horizon_minutes":15,
        "forecast_as_of":row.and_then(|value| value.get("decision_as_of").or_else(|| value.get("as_of"))),
        "evidence_status":"BLOCKED",
        "action":"NO_TRADE",
        "executable":false,
        "target_weight":null,
        "raw_kelly_fraction":null,
        "fractional_kelly":policy.fractional_kelly,
        "net_edge_bps":null,
        "shrinkage_factor":null,
        "pretrade_checks":{"EVIDENCE_CONTRACT_COMPLETE":false},
        "reason_codes":[reason],
        "detail":detail,
        "truth":"Kelly remains disabled until the complete predictive distribution, tail model, cost model, lineage, and independent risk evidence are valid"
    })
}

async fn betting_allocation(State(state): State<AppState>) -> Result<Json<Value>, ApiError> {
    let betting_policy = state.config.betting_policy();
    let portfolio_policy = state.config.portfolio_risk_policy();
    let root = state
        .config
        .data
        .raw_root
        .parent()
        .unwrap_or(std::path::Path::new("data"));
    let expected_symbols = configured_live_forecast_symbols(&state.config);
    let payload = CustomerLiveForecastSnapshot::load(
        root,
        &state.config.live.provider,
        &expected_symbols,
        state.config.live.forecast_symbols.len(),
    )
    .and_then(|snapshot| snapshot.payload(root, "SPY"));
    let unavailable = |reason: &'static str| {
        Json(json!({
            "status":"UNAVAILABLE",
            "policy_version":betting_policy.policy_version,
            "symbol":null,
            "horizon_minutes":15,
            "forecast_as_of":null,
            "evidence_status":"BLOCKED",
            "action":"NO_TRADE",
            "executable":false,
            "target_weight":null,
            "raw_kelly_fraction":null,
            "fractional_kelly":betting_policy.fractional_kelly,
            "net_edge_bps":null,
            "shrinkage_factor":null,
            "pretrade_checks":{},
            "reason_codes":[reason],
            "truth":"Kelly is disabled until a calibrated, promoted, fresh forecast distribution exists"
        }))
    };
    let payload = match payload {
        Ok(Some(payload)) => payload,
        Ok(None) => return Ok(unavailable("LIVE_FORECAST_ARTIFACT_ABSENT")),
        Err(reason) => return Ok(unavailable(reason)),
    };
    let rows = payload
        .get("prediction_layer")
        .and_then(Value::as_array)
        .ok_or_else(|| ApiError::unprocessable("forecast prediction layer is absent"))?;
    let registered = rows
        .iter()
        .filter(|row| row.get("horizon_minutes").and_then(Value::as_u64) == Some(15))
        .collect::<Vec<_>>();
    if registered.len() != 1 {
        return Ok(Json(blocked_betting_payload(
            registered.first().copied(),
            "FORECAST_HORIZON_NOT_UNIQUE",
            "allocation requires exactly one registered 15-minute live forecast",
            &betting_policy,
        )));
    }
    let row = registered[0];
    let scenarios = match scenarios_from_allocation_distribution(row) {
        Ok(scenarios) => scenarios,
        Err(error) => {
            return Ok(Json(blocked_betting_payload(
                Some(row),
                "FULL_DISTRIBUTION_OR_TAIL_MODEL_UNAVAILABLE",
                &error.message,
                &betting_policy,
            )));
        }
    };
    let forecast_as_of = parse_utc(row.get("decision_as_of").or_else(|| row.get("as_of")))
        .ok_or_else(|| ApiError::unprocessable("forecast decision timestamp is invalid"))?;
    let latest_input = parse_utc(row.get("latest_input_available_at"));
    let mut upstream_no_trade_reasons = row
        .pointer("/decision/no_trade_reasons")
        .and_then(Value::as_array)
        .map(|values| {
            values
                .iter()
                .filter_map(Value::as_str)
                .map(str::to_string)
                .collect::<Vec<_>>()
        })
        .unwrap_or_default();
    let stale_upstream = upstream_no_trade_reasons
        .iter()
        .any(|reason| reason.contains("STALE"));
    let evaluation_as_of = chrono::Utc::now();
    let maximum_age = state.config.data.context.max_snapshot_staleness_seconds;
    let (forecast_fresh, input_fresh_and_causal) = forecast_timestamps_are_fresh_and_causal(
        forecast_as_of,
        latest_input,
        evaluation_as_of,
        maximum_age,
    );
    if !forecast_fresh {
        upstream_no_trade_reasons.push("FORECAST_SNAPSHOT_STALE_OR_FUTURE".to_string());
    }
    if !input_fresh_and_causal {
        upstream_no_trade_reasons.push("LATEST_INPUT_STALE_FUTURE_OR_POSTDECISION".to_string());
    }
    let data_fresh = forecast_fresh && input_fresh_and_causal && !stale_upstream;
    let state_count = row
        .get("filtered_state_probabilities")
        .and_then(Value::as_array)
        .map_or(0, Vec::len);
    let normalized_regime_entropy_candidate = row
        .get("normalized_regime_entropy")
        .and_then(Value::as_f64)
        .or_else(|| {
            let entropy = row.get("state_entropy").and_then(Value::as_f64)?;
            (state_count > 1).then(|| entropy / (state_count as f64).ln())
        });
    let normalized_regime_entropy = match normalized_regime_entropy_candidate {
        Some(value) if value.is_finite() && (0.0..=1.0).contains(&value) => value,
        Some(_) => {
            upstream_no_trade_reasons.push("REGIME_ENTROPY_INVALID".to_string());
            1.0
        }
        None => {
            upstream_no_trade_reasons.push("REGIME_ENTROPY_UNAVAILABLE".to_string());
            1.0
        }
    };
    let calibration_status = row
        .get("calibration_status")
        .and_then(Value::as_str)
        .unwrap_or("UNAVAILABLE");
    let model_status = row
        .get("model_status")
        .and_then(Value::as_str)
        .unwrap_or("UNAVAILABLE");
    let promotion_registry_matches =
        pinned_promotion_registry_matches(root, row, forecast_as_of, evaluation_as_of);
    let model_promoted = model_status == "PROMOTED"
        && matches!(calibration_status, "PROMOTED_OOS" | "OOS_CALIBRATED")
        && promotion_registry_matches;
    if !promotion_registry_matches {
        upstream_no_trade_reasons.push("PINNED_MODEL_PROMOTION_NOT_APPROVED".to_string());
    }
    let declared_hashes_valid = ["model_hash", "feature_hash", "data_manifest_hash"]
        .iter()
        .all(|field| {
            row.get(field)
                .and_then(Value::as_str)
                .is_some_and(valid_nonzero_sha256)
        });
    let ledger_backed = live_prediction_is_ledger_backed(root, &state.config.live.provider, row);
    if !ledger_backed {
        upstream_no_trade_reasons.push("LIVE_PREDICTION_NOT_LEDGER_BACKED".to_string());
    }
    let data_manifest_matches = current_data_manifest_matches(&state.config.data, row);
    if !data_manifest_matches {
        upstream_no_trade_reasons.push("DATA_MANIFEST_NOT_BOUND_TO_CURRENT_ARCHIVE".to_string());
    }
    let lineage_complete = declared_hashes_valid && ledger_backed && data_manifest_matches;
    let runtime_risk = state.runtime.risk_status();
    let portfolio = state.runtime.portfolio();
    let runtime_portfolio_authoritative = state.runtime.portfolio_is_authoritative();
    let runtime_portfolio_age = evaluation_as_of
        .signed_duration_since(portfolio.as_of)
        .num_seconds();
    let runtime_portfolio_fresh = runtime_portfolio_authoritative
        && runtime_portfolio_age >= 0
        && runtime_portfolio_age <= portfolio_policy.maximum_snapshot_age_seconds;
    if !runtime_portfolio_authoritative {
        upstream_no_trade_reasons.push("RUNTIME_PORTFOLIO_SOURCE_UNAVAILABLE".to_string());
    }
    if !runtime_portfolio_fresh {
        upstream_no_trade_reasons.push("RUNTIME_PORTFOLIO_SNAPSHOT_STALE".to_string());
    }
    let risk_input_path = root.join("state/portfolio_risk_input_latest.json");
    let independent_risk_approved = fs::read(&risk_input_path)
        .ok()
        .and_then(|bytes| {
            serde_json::from_slice::<crate::portfolio_risk::PortfolioRiskInput>(&bytes).ok()
        })
        .and_then(|input| {
            let report = crate::portfolio_risk::analyze_portfolio_at(
                &input,
                &portfolio_policy,
                evaluation_as_of,
            )
            .ok()?;
            Some((input, report))
        })
        .is_some_and(|(input, report)| {
            report.new_risk_allowed
                && !report.kill_switch_recommended
                && runtime_portfolio_authoritative
                && risk_input_matches_runtime_portfolio(&input, &portfolio)
        });
    if !independent_risk_approved {
        upstream_no_trade_reasons.push("INDEPENDENT_PORTFOLIO_RISK_NOT_APPROVED".to_string());
    }
    if !forecast_distribution_mean_matches(row, &scenarios) {
        return Ok(Json(blocked_betting_payload(
            Some(row),
            "FORECAST_DISTRIBUTION_MEAN_MISMATCH",
            "expected_return does not equal the probability-weighted full-distribution mean",
            &betting_policy,
        )));
    }
    let Some(estimated_round_trip_cost_bps) = validated_round_trip_cost_bps(row) else {
        return Ok(Json(blocked_betting_payload(
            Some(row),
            "COST_MODEL_UNAVAILABLE",
            "allocation requires a nonnegative round-trip cost estimate from an OOS-validated or conservative cost model",
            &betting_policy,
        )));
    };
    if runtime_risk.kill_switch_active {
        upstream_no_trade_reasons.push("RUNTIME_KILL_SWITCH_ACTIVE".to_string());
    }
    let evidence = crate::allocation::ForecastEvidence {
        symbol: row
            .get("symbol")
            .and_then(Value::as_str)
            .unwrap_or("UNKNOWN")
            .to_string(),
        forecast_as_of,
        horizon_minutes: 15,
        scenarios,
        effective_sample_size: row
            .get("effective_sample_size")
            .and_then(Value::as_f64)
            .unwrap_or(0.0),
        ood_score: row.get("ood_score").and_then(Value::as_f64).unwrap_or(1.0),
        normalized_regime_entropy,
        calibration_error: row
            .get("calibration_error")
            .and_then(Value::as_f64)
            .unwrap_or(1.0),
        model_promoted,
        data_fresh,
        lineage_complete,
        upstream_no_trade_reasons,
    };
    let current_weight = portfolio
        .positions
        .iter()
        .find(|position| position.symbol.eq_ignore_ascii_case(&evidence.symbol))
        .map(|position| position.quantity * position.mark_price / portfolio.equity)
        .unwrap_or(0.0);
    let allocation_state = crate::allocation::AllocationState {
        equity: portfolio.equity,
        current_weight,
        gross_exposure: portfolio.gross_exposure.max(current_weight.abs()),
        correlated_exposure: portfolio.gross_exposure.max(current_weight.abs()),
        daily_loss_fraction: runtime_risk.daily_loss_used,
        drawdown_fraction: runtime_risk.drawdown,
        estimated_round_trip_cost_bps,
    };
    let decision = crate::allocation::decide_bet(&evidence, &allocation_state, &betting_policy)
        .map_err(ApiError::internal)?;
    Ok(Json(
        serde_json::to_value(decision).map_err(ApiError::internal)?,
    ))
}

async fn portfolio_analytics(State(state): State<AppState>) -> Result<Json<Value>, ApiError> {
    let portfolio_policy = state.config.portfolio_risk_policy();
    let root = state
        .config
        .data
        .raw_root
        .parent()
        .unwrap_or(std::path::Path::new("data"));
    let path = root.join("state/portfolio_risk_input_latest.json");
    if !path.exists() {
        let runtime = state.runtime.risk_status();
        return Ok(Json(json!({
            "status":"BLOCK_NEW_RISK",
            "policy_version":portfolio_policy.policy_version,
            "as_of":chrono::Utc::now(),
            "new_risk_allowed":false,
            "kill_switch_recommended":runtime.kill_switch_active,
            "gross_exposure":null,
            "net_exposure":null,
            "max_position_weight":null,
            "historical_var_fraction":null,
            "expected_shortfall_fraction":null,
            "worst_stress_loss_fraction":null,
            "drawdown_fraction":null,
            "daily_loss_fraction":null,
            "liquidity":[],
            "factor_exposures":{},
            "checks":{
                "PORTFOLIO_SNAPSHOT_AVAILABLE":false,
                "RUNTIME_PORTFOLIO_SOURCE_AUTHORITATIVE":false,
                "TAIL_HISTORY_AVAILABLE":false,
                "STRESS_SCENARIOS_AVAILABLE":false,
                "LIQUIDITY_AVAILABLE":false
            },
            "reason_codes":[
                "PORTFOLIO_RISK_INPUT_ABSENT",
                "RUNTIME_PORTFOLIO_SOURCE_UNAVAILABLE",
                "TAIL_HISTORY_UNAVAILABLE",
                "STRESS_SCENARIOS_UNAVAILABLE",
                "LIQUIDITY_INPUT_UNAVAILABLE"
            ],
            "required_input_path":path,
            "truth":"Missing portfolio history, stress scenarios, or ADV is unknown risk and blocks new exposure; missing values are never reported as zero"
        })));
    }
    let bytes = fs::read(&path).map_err(ApiError::internal)?;
    let input = serde_json::from_slice::<crate::portfolio_risk::PortfolioRiskInput>(&bytes)
        .map_err(ApiError::internal)?;
    let evaluation_as_of = chrono::Utc::now();
    let report =
        crate::portfolio_risk::analyze_portfolio_at(&input, &portfolio_policy, evaluation_as_of)
            .map_err(ApiError::internal)?;
    let runtime_portfolio = state.runtime.portfolio();
    let runtime_risk = state.runtime.risk_status();
    let runtime_portfolio_authoritative = state.runtime.portfolio_is_authoritative();
    let runtime_age = evaluation_as_of
        .signed_duration_since(runtime_portfolio.as_of)
        .num_seconds();
    let runtime_portfolio_fresh = runtime_portfolio_authoritative
        && runtime_age >= 0
        && runtime_age <= portfolio_policy.maximum_snapshot_age_seconds;
    let runtime_portfolio_matches =
        risk_input_matches_runtime_portfolio(&input, &runtime_portfolio);
    let mut value = serde_json::to_value(report).map_err(ApiError::internal)?;
    value["checks"]["RUNTIME_PORTFOLIO_SOURCE_AUTHORITATIVE"] =
        json!(runtime_portfolio_authoritative);
    value["checks"]["RUNTIME_PORTFOLIO_FRESH"] = json!(runtime_portfolio_fresh);
    value["checks"]["RUNTIME_PORTFOLIO_MATCHES_RISK_INPUT"] = json!(runtime_portfolio_matches);
    if !runtime_portfolio_authoritative
        || !runtime_portfolio_fresh
        || !runtime_portfolio_matches
        || runtime_risk.kill_switch_active
    {
        value["new_risk_allowed"] = json!(false);
        let report_kill_switch = value
            .get("kill_switch_recommended")
            .and_then(Value::as_bool)
            .unwrap_or(false);
        if runtime_risk.kill_switch_active || report_kill_switch {
            value["status"] = json!("KILL_SWITCH_RECOMMENDED");
            value["kill_switch_recommended"] = json!(true);
        } else {
            value["status"] = json!("BLOCK_NEW_RISK");
        }
        if let Some(reasons) = value.get_mut("reason_codes").and_then(Value::as_array_mut) {
            if !runtime_portfolio_authoritative {
                reasons.push(json!("RUNTIME_PORTFOLIO_SOURCE_UNAVAILABLE"));
            }
            if !runtime_portfolio_fresh {
                reasons.push(json!("RUNTIME_PORTFOLIO_STALE"));
            }
            if !runtime_portfolio_matches {
                reasons.push(json!("RUNTIME_PORTFOLIO_RISK_INPUT_MISMATCH"));
            }
            if runtime_risk.kill_switch_active {
                reasons.push(json!("RUNTIME_KILL_SWITCH_ACTIVE"));
            }
        }
    }
    Ok(Json(value))
}

fn live_root(state: &AppState) -> std::path::PathBuf {
    state
        .config
        .data
        .raw_root
        .parent()
        .unwrap_or(std::path::Path::new("data"))
        .join("live")
}

async fn live_status(State(state): State<AppState>) -> Result<Json<Value>, ApiError> {
    if state.config.live.provider == "massive" {
        let root = live_root(&state);
        return Ok(Json(json!({
            "provider":"massive",
            "stream":read_json_if_present(&root.join("massive_stream_status.json"))?,
            "readiness":read_json_if_present(&root.join("massive_readiness.json"))?,
            "inference":read_json_if_present(&root.join("massive_inference_status.json"))?
        })));
    }
    if state.config.live.provider == "databento" {
        let root = live_root(&state);
        return Ok(Json(json!({
            "provider":"databento",
            "stream":read_json_if_present(&root.join("databento_stream_status.json"))?,
            "bar_artifact":"databento_stock_bars.jsonl",
            "execution_enabled":false
        })));
    }
    let path = live_root(&state).join("status.json");
    if path.exists() {
        return Ok(Json(read_json_if_present(&path)?));
    }
    Ok(Json(json!(crate::live::check(
        &state.config.live,
        &state.config.live.host,
        state.config.live.port
    ))))
}

async fn live_capabilities(State(state): State<AppState>) -> Result<Json<Value>, ApiError> {
    if state.config.live.provider == "massive" {
        return Ok(Json(
            serde_json::to_value(crate::data::massive::status(&state.config.data.massive))
                .map_err(ApiError::internal)?,
        ));
    }
    if state.config.live.provider == "databento" {
        let request = state.config.data.databento.requests.iter().find(|request| {
            request.dataset.eq_ignore_ascii_case("EQUS.MINI")
                && request.schema.eq_ignore_ascii_case("ohlcv-1m")
                && request.stype_in.eq_ignore_ascii_case("raw_symbol")
        });
        return Ok(Json(json!({
            "provider":"databento",
            "dataset":request.map(|row| row.dataset.as_str()),
            "schema":request.map(|row| row.schema.as_str()),
            "credential_configured":credential_configured("DATABENTO_API_KEY"),
            "realtime_required":state.config.live.require_realtime,
            "quote_only":state.config.live.quote_only,
            "subscribed_symbols":state.config.live.symbols,
            "public_redistribution_authorized":false,
            "execution_enabled":false
        })));
    }
    Ok(Json(crate::live::capability(&state.config.live)))
}

#[derive(Debug, Deserialize)]
struct OptionsIntelQuery {
    expiration: Option<String>,
    #[serde(default)]
    levels: Option<String>,
}

fn options_top_oi(
    contracts: &[crate::data::massive_live::MassiveOptionContract],
    side: Option<CallPut>,
    limit: usize,
) -> Vec<Value> {
    let mut rows = contracts
        .iter()
        .filter(|contract| side.is_none_or(|wanted| contract.call_put == wanted))
        .filter_map(|contract| {
            Some((
                contract,
                contract.open_interest?,
                contract.volume.unwrap_or(0),
            ))
        })
        .collect::<Vec<_>>();
    rows.sort_by(|left, right| {
        right
            .1
            .cmp(&left.1)
            .then_with(|| right.2.cmp(&left.2))
            .then_with(|| left.0.strike.total_cmp(&right.0.strike))
    });
    rows.into_iter()
        .take(limit)
        .enumerate()
        .map(|(index, (contract, open_interest, volume))| {
            json!({
                "rank":index + 1,
                "symbol":contract.option_symbol,
                "expiration":contract.expiry,
                "strike":contract.strike,
                "side":if contract.call_put == CallPut::Call {"C"} else {"P"},
                "openInterest":open_interest,
                "volume":volume
            })
        })
        .collect()
}

fn mechanical_max_pain(
    contracts: &[crate::data::massive_live::MassiveOptionContract],
    spot: f64,
) -> Option<Value> {
    if contracts.is_empty()
        || contracts
            .iter()
            .any(|contract| contract.open_interest.is_none())
    {
        return None;
    }
    let mut strikes = contracts
        .iter()
        .map(|contract| contract.strike)
        .filter(|strike| strike.is_finite() && *strike > 0.0)
        .collect::<Vec<_>>();
    strikes.sort_by(f64::total_cmp);
    strikes.dedup_by(|left, right| left.to_bits() == right.to_bits());
    let curve = strikes
        .iter()
        .map(|settlement| {
            let total = contracts
                .iter()
                .map(|contract| {
                    let intrinsic = match contract.call_put {
                        CallPut::Call => (settlement - contract.strike).max(0.0),
                        CallPut::Put => (contract.strike - settlement).max(0.0),
                    };
                    intrinsic * contract.open_interest.unwrap_or(0) as f64 * 100.0
                })
                .sum::<f64>();
            (*settlement, total)
        })
        .collect::<Vec<_>>();
    let (max_pain_strike, total_pain) = curve
        .iter()
        .min_by(|left, right| left.1.total_cmp(&right.1))
        .copied()?;
    Some(json!({
        "maxPainStrike":max_pain_strike,
        "totalPainAtMax":total_pain,
        "spot":spot,
        "distanceFromSpotPct":if spot > 0.0 {(max_pain_strike / spot - 1.0) * 100.0} else {0.0},
        "curve":curve.into_iter().map(|(strike,total)|json!({"strike":strike,"totalPain":total})).collect::<Vec<_>>()
    }))
}

async fn options_intel(
    State(state): State<AppState>,
    Path(underlying): Path<String>,
    Query(query): Query<OptionsIntelQuery>,
) -> Result<Json<Value>, ApiError> {
    let underlying = underlying
        .trim()
        .trim_start_matches("US.")
        .to_ascii_uppercase();
    if underlying.is_empty()
        || underlying.len() > 10
        || !underlying
            .chars()
            .all(|character| character.is_ascii_alphanumeric() || character == '.')
    {
        return Err(ApiError::unprocessable("invalid option underlying"));
    }
    let path = state
        .config
        .data
        .massive
        .option_chain_output_root
        .join(format!(
            "{}_full_chain_latest.json",
            underlying.to_ascii_lowercase()
        ));
    if !path.exists() {
        return Err(ApiError::service_unavailable(format!(
            "full option-chain artifact is absent for {underlying}"
        )));
    }
    let bytes = fs::read(&path).map_err(ApiError::internal)?;
    let snapshot =
        serde_json::from_slice::<crate::data::massive_live::MassiveFullOptionChain>(&bytes)
            .map_err(ApiError::internal)?;
    if snapshot.schema_version != crate::data::massive_live::OPTION_CHAIN_SCHEMA_VERSION {
        return Err(ApiError::conflict(
            "unsupported option-chain artifact schema",
        ));
    }
    let observed_hash =
        sha256_hex(&serde_json::to_vec(&snapshot.contracts).map_err(ApiError::internal)?);
    if observed_hash != snapshot.contracts_sha256 {
        return Err(ApiError::conflict("option-chain artifact hash mismatch"));
    }
    let requested_expiry = query
        .expiration
        .as_deref()
        .map(|value| {
            chrono::NaiveDate::parse_from_str(value, "%Y-%m-%d")
                .map_err(|_| ApiError::unprocessable("expiration must be YYYY-MM-DD"))
        })
        .transpose()?;
    let selected_expiry = requested_expiry.or_else(|| {
        snapshot
            .contracts
            .iter()
            .filter(|contract| contract.expiry >= Utc::now().date_naive())
            .map(|contract| contract.expiry)
            .min()
    });
    let contracts = snapshot
        .contracts
        .iter()
        .filter(|contract| selected_expiry.is_none_or(|expiry| contract.expiry == expiry))
        .cloned()
        .collect::<Vec<_>>();
    let spot = contracts
        .iter()
        .filter_map(|contract| contract.underlying_price)
        .find(|price| price.is_finite() && *price > 0.0)
        .unwrap_or(0.0);
    let top_oi = options_top_oi(&contracts, None, 10);
    let top_calls = options_top_oi(&contracts, Some(CallPut::Call), 10);
    let top_puts = options_top_oi(&contracts, Some(CallPut::Put), 10);
    let call_oi = contracts
        .iter()
        .filter(|contract| contract.call_put == CallPut::Call)
        .filter_map(|contract| contract.open_interest)
        .sum::<u64>();
    let put_oi = contracts
        .iter()
        .filter(|contract| contract.call_put == CallPut::Put)
        .filter_map(|contract| contract.open_interest)
        .sum::<u64>();
    let call_volume = contracts
        .iter()
        .filter(|contract| contract.call_put == CallPut::Call)
        .filter_map(|contract| contract.volume)
        .sum::<u64>();
    let put_volume = contracts
        .iter()
        .filter(|contract| contract.call_put == CallPut::Put)
        .filter_map(|contract| contract.volume)
        .sum::<u64>();
    let total_oi = call_oi + put_oi;
    let total_volume = call_volume + put_volume;
    let quoted = contracts
        .iter()
        .filter_map(|contract| {
            let bid = contract.bid?;
            let ask = contract.ask?;
            let mid = (bid + ask) * 0.5;
            (mid > 0.0 && ask >= bid).then(|| {
                json!({
                    "strike":contract.strike,
                    "side":if contract.call_put == CallPut::Call {"C"} else {"P"},
                    "mid":mid,
                    "spreadPct":(ask-bid)/mid
                })
            })
        })
        .take(500)
        .collect::<Vec<_>>();
    let quotes = if snapshot.model_ready {
        contracts
            .iter()
            .filter_map(|contract| contract.as_option_quote())
            .collect::<Vec<_>>()
    } else {
        Vec::new()
    };
    let now = Utc::now();
    let gamma = gamma_convexity_feedback_risk(
        &quotes,
        &GammaConvexityRequest {
            as_of: now,
            underlying: underlying.clone(),
            spot,
            contract_multiplier: 100.0,
            oi_as_of: snapshot.model_ready.then_some(snapshot.oi_available_at),
            greeks_as_of: snapshot.model_ready.then_some(snapshot.greeks_available_at),
            max_quote_age_seconds: state.config.research.option_max_staleness_seconds,
            max_oi_age_seconds: state.config.research.option_max_staleness_seconds,
            max_greeks_age_seconds: state.config.research.option_max_staleness_seconds,
        },
    );
    let expiration = selected_expiry
        .map(|date| date.to_string())
        .unwrap_or_default();
    let _requested_levels = query.levels;
    Ok(Json(json!({
        "underlying":underlying,
        "expiration":expiration,
        "spot":spot,
        "provider":if snapshot.chain_complete {"massive"} else {"unavailable"},
        "topOi":top_oi,
        "topCalls":top_calls,
        "topPuts":top_puts,
        "maxPain":if snapshot.chain_complete {mechanical_max_pain(&contracts,spot)} else {None},
        // Signed dealer GEX is intentionally absent: public OI does not reveal
        // dealer ownership. The typed unsigned convexity report is separate.
        "gex":null,
        "probability":null,
        "squeezeAssessment":{
            "scenario":"mixed",
            "callOiTotal":call_oi,
            "putOiTotal":put_oi,
            "callPutRatio":call_oi as f64 / put_oi.max(1) as f64,
            "rationale":["Public OI/volume are descriptive; dealer sign and a squeeze direction are not inferred."],
            "caveats":["No personalized advice.","No dealer-book assumption.","No probability is emitted without a promoted OOS calibration artifact."]
        },
        "flowPressure":{
            "callOi":call_oi,
            "putOi":put_oi,
            "callVolume":call_volume,
            "putVolume":put_volume,
            "callPutOiRatio":call_oi as f64 / put_oi.max(1) as f64,
            "callPutVolumeRatio":call_volume as f64 / put_volume.max(1) as f64,
            "oiPctCall":call_oi as f64 / total_oi.max(1) as f64,
            "volPctCall":call_volume as f64 / total_volume.max(1) as f64,
            "bidAskQuality":if quoted.len()==contracts.len() {"ok"} else if quoted.is_empty() {"unavailable"} else {"partial"},
            "bidAskWeightedMidByStrike":quoted,
            "interpretation":"Descriptive call/put counts only; trade direction is not inferred."
        },
        "generatedAt":now,
        "dataReadiness":{
            "chainComplete":snapshot.chain_complete,
            "modelReady":snapshot.model_ready,
            "capturedAt":snapshot.captured_at,
            "blockers":snapshot.blockers,
            "contractsSha256":snapshot.contracts_sha256
        },
        "gammaConvexityRisk":gamma,
        "disclaimer":"Impersonal whole-market mathematical research only. The endpoint displays a licensed point-in-time chain and strict risk diagnostics; it is not an investment recommendation."
    })))
}

fn read_jsonl_tail(path: &std::path::Path, limit: usize) -> Result<Vec<Value>, ApiError> {
    if !path.exists() {
        return Ok(Vec::new());
    }
    let text = fs::read_to_string(path).map_err(ApiError::internal)?;
    let mut rows = text
        .lines()
        .rev()
        .take(limit)
        .filter_map(|line| serde_json::from_str(line).ok())
        .collect::<Vec<_>>();
    rows.reverse();
    Ok(rows)
}

#[derive(Debug, Clone, Serialize)]
struct SessionFiveMinuteBar {
    bar_number: usize,
    window_start: String,
    window_end: String,
    open: f64,
    high: f64,
    low: f64,
    close: f64,
    volume: f64,
    return_pct: f64,
    minute_rows: usize,
}

fn build_session_summary(
    rows: Vec<crate::data::market_store::StoredLiveMarketBar>,
    public_symbol: &str,
    data_symbol: &str,
) -> Result<Value> {
    let mut parsed = rows
        .into_iter()
        .filter_map(|row| {
            row.event_at
                .parse::<DateTime<Utc>>()
                .ok()
                .map(|event_at| (event_at, row))
        })
        .collect::<Vec<_>>();
    parsed.sort_by_key(|(event_at, _)| *event_at);
    let regular_rows = parsed
        .into_iter()
        .filter(|(event_at, _)| {
            let local = event_at.with_timezone(&New_York);
            let minute = local.hour() * 60 + local.minute();
            (570..960).contains(&minute)
        })
        .collect::<Vec<_>>();
    let session_date = regular_rows
        .last()
        .map(|(event_at, _)| event_at.with_timezone(&New_York).date_naive())
        .context("NO_REGULAR_SESSION_ROWS")?;
    let regular = regular_rows
        .into_iter()
        .filter(|(event_at, _)| event_at.with_timezone(&New_York).date_naive() == session_date)
        .collect::<Vec<_>>();
    if regular.is_empty() {
        anyhow::bail!("NO_REGULAR_SESSION_ROWS");
    }

    let mut buckets = Vec::<SessionFiveMinuteBar>::new();
    for (event_at, row) in &regular {
        let local = event_at.with_timezone(&New_York);
        let minute = local.hour() * 60 + local.minute();
        let bar_number = ((minute - 570) / 5 + 1) as usize;
        if let Some(bucket) = buckets.last_mut()
            && bucket.bar_number == bar_number
        {
            bucket.high = bucket.high.max(row.high);
            bucket.low = bucket.low.min(row.low);
            bucket.close = row.close;
            bucket.volume += row.volume;
            bucket.window_end = (*event_at + chrono::Duration::minutes(1)).to_rfc3339();
            bucket.return_pct = (bucket.close / bucket.open - 1.0) * 100.0;
            bucket.minute_rows += 1;
            continue;
        }
        buckets.push(SessionFiveMinuteBar {
            bar_number,
            window_start: event_at.to_rfc3339(),
            window_end: (*event_at + chrono::Duration::minutes(1)).to_rfc3339(),
            open: row.open,
            high: row.high,
            low: row.low,
            close: row.close,
            volume: row.volume,
            return_pct: (row.close / row.open - 1.0) * 100.0,
            minute_rows: 1,
        });
    }
    let first = regular.first().context("NO_REGULAR_SESSION_ROWS")?;
    let last = regular.last().context("NO_REGULAR_SESSION_ROWS")?;
    let session_open = first.1.open;
    let session_close = last.1.close;
    let session_high = regular
        .iter()
        .map(|(_, row)| row.high)
        .fold(f64::NEG_INFINITY, f64::max);
    let session_low = regular
        .iter()
        .map(|(_, row)| row.low)
        .fold(f64::INFINITY, f64::min);
    let total_volume = regular.iter().map(|(_, row)| row.volume).sum::<f64>();
    let close_volume_proxy = (total_volume > 0.0).then(|| {
        regular
            .iter()
            .map(|(_, row)| row.close * row.volume)
            .sum::<f64>()
            / total_volume
    });
    let session_return_pct = (session_close / session_open - 1.0) * 100.0;
    let session_range_pct = (session_high / session_low - 1.0) * 100.0;
    let close_location_pct = if session_high > session_low {
        (session_close - session_low) / (session_high - session_low) * 100.0
    } else {
        50.0
    };
    let trend_state = if session_return_pct > 0.0 {
        "UP_SESSION"
    } else if session_return_pct < 0.0 {
        "DOWN_SESSION"
    } else {
        "FLAT_SESSION"
    };
    let mut peak_windows = buckets
        .iter()
        .filter(|bucket| bucket.minute_rows == 5)
        .cloned()
        .collect::<Vec<_>>();
    peak_windows.sort_by(|left, right| {
        right
            .return_pct
            .abs()
            .total_cmp(&left.return_pct.abs())
            .then_with(|| left.bar_number.cmp(&right.bar_number))
    });
    peak_windows.truncate(3);
    let entitlements = regular
        .iter()
        .map(|(_, row)| row.entitlement.clone())
        .collect::<BTreeSet<_>>();
    let completed = regular.len() == 390
        && buckets.len() == 78
        && buckets.iter().all(|bucket| bucket.minute_rows == 5);
    let latest_completed_bar = buckets
        .iter()
        .rev()
        .find(|bucket| bucket.minute_rows == 5)
        .cloned();

    Ok(json!({
        "schema_version":"axio.session-summary.v1",
        "status":if completed {"COMPLETE_78_BAR_SESSION"} else {"SESSION_TO_DATE"},
        "result_kind":"OBSERVED_SESSION_TREND",
        "scope":if completed {
            "LAST_COMPLETED_REGULAR_SESSION"
        } else {
            "CURRENT_REGULAR_SESSION_TO_DATE"
        },
        "public_symbol":public_symbol,
        "data_symbol":data_symbol,
        "proxy_disclosure":if public_symbol == "SPX" {
            "SPX uses SPY for price, volume, and close-volume session research."
        } else {
            "Direct listed instrument observations."
        },
        "session_date_et":session_date.to_string(),
        "trend_state":trend_state,
        "session_return_pct":session_return_pct,
        "session_open":session_open,
        "session_high":session_high,
        "session_low":session_low,
        "session_close":session_close,
        "session_range_pct":session_range_pct,
        "close_location_pct":close_location_pct,
        "total_volume":total_volume,
        "close_volume_proxy":close_volume_proxy,
        "close_vs_close_volume_proxy_bps":close_volume_proxy
            .map(|value| (session_close / value - 1.0) * 10_000.0),
        "minute_rows":regular.len(),
        "five_minute_bar_count":buckets.len(),
        "latest_completed_bar":latest_completed_bar,
        "peak_windows":peak_windows,
        "five_minute_bars":buckets,
        "source":{
            "provider":"databento",
            "dataset":"EQUS.MINI",
            "schema":"ohlcv-1m",
            "storage":"APPEND_ONLY_SQLITE",
            "first_observed_at":first.0,
            "last_observed_at":last.0,
            "last_available_at":last.1.available_at,
            "entitlements":entitlements,
        },
        "freshness":{
            "status":"NOT_EVALUATED_FOR_LIVE_USE",
            "observation_cutoff":last.0,
            "available_at":last.1.available_at,
        },
        "coverage":{
            "expected_regular_session_minutes":390,
            "observed_regular_session_minutes":regular.len(),
            "ratio":regular.len() as f64 / 390.0,
        },
        "model_status":"LIVE_FROZEN_MODEL_RESULT_NOT_AVAILABLE_FOR_THIS_CUTOFF",
        "model_version":Value::Null,
        "feature_version":Value::Null,
        "probability_published":false,
        "automatic_execution_enabled":false,
        "caveats":[
            "This is a deterministic observed-session result, not a live forecast or personalized recommendation.",
            "The close-volume proxy is calculated from finalized one-minute close and volume; it is not labeled as vendor VWAP.",
            "No probability is published."
        ]
    }))
}

#[derive(Debug, Deserialize)]
struct SessionSummaryRequest {
    symbol: Option<String>,
}

#[derive(Debug, Deserialize)]
struct TickerRagRequest {
    symbols: String,
}

fn normalize_ticker(value: &str) -> Result<String> {
    let upper = value.trim().to_ascii_uppercase();
    let symbol = upper.trim_start_matches("US.").to_string();
    let valid = !symbol.is_empty()
        && symbol.len() <= 12
        && symbol
            .bytes()
            .next()
            .is_some_and(|byte| byte.is_ascii_alphabetic())
        && symbol
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'.' | b'-'));
    if !valid {
        anyhow::bail!("INVALID_TICKER_SYMBOL");
    }
    Ok(symbol)
}

fn normalize_ticker_list(value: &str) -> Result<Vec<String>> {
    let mut seen = BTreeSet::new();
    let mut symbols = Vec::new();
    for raw in value.split(',') {
        let symbol = normalize_ticker(raw)?;
        if seen.insert(symbol.clone()) {
            symbols.push(symbol);
        }
    }
    if symbols.is_empty() || symbols.len() > 20 {
        anyhow::bail!("TICKER_RAG_REQUIRES_ONE_TO_TWENTY_SYMBOLS");
    }
    Ok(symbols)
}

fn build_ticker_rag_bundle<F>(requested_symbols: &[String], mut retrieve: F) -> Value
where
    F: FnMut(&str) -> Result<Vec<crate::data::market_store::StoredLiveMarketBar>>,
{
    let results = requested_symbols
        .iter()
        .map(|requested_symbol| {
            let data_symbol = if requested_symbol == "SPX" {
                "SPY".to_string()
            } else {
                requested_symbol.clone()
            };
            match retrieve(&data_symbol) {
                Ok(rows) if rows.is_empty() => json!({
                    "requested_symbol":requested_symbol,
                    "canonical_symbol":requested_symbol,
                    "data_symbol":data_symbol,
                    "status":"NO_STORED_OBSERVATIONS",
                    "reason_code":"NO_STORED_OBSERVATIONS",
                    "reason":"No eligible finalized database observations are stored for this ticker.",
                    "summary":Value::Null,
                }),
                Ok(rows) => match build_session_summary(rows, requested_symbol, &data_symbol) {
                    Ok(summary) => json!({
                        "requested_symbol":requested_symbol,
                        "canonical_symbol":requested_symbol,
                        "data_symbol":data_symbol,
                        "status":"RETRIEVED",
                        "reason_code":Value::Null,
                        "reason":Value::Null,
                        "summary":summary,
                    }),
                    Err(_) => json!({
                        "requested_symbol":requested_symbol,
                        "canonical_symbol":requested_symbol,
                        "data_symbol":data_symbol,
                        "status":"INSUFFICIENT_DATA",
                        "reason_code":"NO_ELIGIBLE_REGULAR_SESSION",
                        "reason":"Stored rows do not form an eligible regular-session observation at the requested retrieval policy.",
                        "summary":Value::Null,
                    }),
                },
                Err(_) => json!({
                    "requested_symbol":requested_symbol,
                    "canonical_symbol":requested_symbol,
                    "data_symbol":data_symbol,
                    "status":"RETRIEVAL_FAILED",
                    "reason_code":"DATABASE_READ_FAILED",
                    "reason":"The authoritative market database could not be read for this ticker.",
                    "summary":Value::Null,
                }),
            }
        })
        .collect::<Vec<_>>();
    json!({
        "schema_version":"axio.ticker-rag.v1",
        "generated_at":Utc::now(),
        "requested_count":requested_symbols.len(),
        "result_count":results.len(),
        "retrieval_policy":"EXACT_SYMBOL_POINT_IN_TIME_DATABASE_LOOKUP",
        "storage":"APPEND_ONLY_SQLITE_WITH_POSTGRES_ARCHIVE",
        "results":results,
        "probability_published":false,
        "automatic_execution_enabled":false,
        "caveats":[
            "Each requested ticker is retrieved independently; one ticker's observations are never reused for another ticker.",
            "Missing or incomplete stored observations return a reason-coded status rather than a fabricated result.",
            "Retrieved session summaries are observed market facts, not calibrated forecasts or personalized recommendations."
        ]
    })
}

async fn research_session_summary(
    State(state): State<AppState>,
    Query(request): Query<SessionSummaryRequest>,
) -> Result<Json<Value>, ApiError> {
    let public_symbol = normalize_ticker(request.symbol.as_deref().unwrap_or("SPX"))
        .map_err(|_| ApiError::unprocessable("The requested ticker symbol is invalid."))?;
    let data_symbol = if public_symbol == "SPX" {
        "SPY".to_string()
    } else {
        public_symbol.clone()
    };
    let database = data_root(&state).join("market/databento_market_data.sqlite3");
    let summary = tokio::task::spawn_blocking(move || {
        let rows = crate::data::market_store::latest_live_bars(&database, &data_symbol, 5_000)?;
        build_session_summary(rows, &public_symbol, &data_symbol)
    })
    .await
    .map_err(ApiError::internal)?
    .map_err(|error| ApiError::service_unavailable(error.to_string()))?;
    Ok(Json(summary))
}

async fn research_ticker_rag(
    State(state): State<AppState>,
    Query(request): Query<TickerRagRequest>,
) -> Result<Json<Value>, ApiError> {
    let symbols = normalize_ticker_list(&request.symbols).map_err(|_| {
        ApiError::unprocessable("Ticker RAG requires one to twenty comma-separated ticker symbols.")
    })?;
    let database = data_root(&state).join("market/databento_market_data.sqlite3");
    let bundle = tokio::task::spawn_blocking(move || {
        build_ticker_rag_bundle(&symbols, |data_symbol| {
            crate::data::market_store::latest_live_bars(&database, data_symbol, 5_000)
        })
    })
    .await
    .map_err(ApiError::internal)?;
    Ok(Json(bundle))
}

async fn research_daily_regime(
    State(state): State<AppState>,
    Query(request): Query<SessionSummaryRequest>,
) -> Result<Json<Value>, ApiError> {
    let public_symbol = request
        .symbol
        .as_deref()
        .unwrap_or("SPX")
        .trim()
        .trim_start_matches("US.")
        .to_ascii_uppercase();
    if public_symbol != "SPX" {
        return Err(ApiError::unprocessable(
            "The daily-regime v1 contract currently supports SPX through the explicit SPY proxy.",
        ));
    }
    let root = data_root(&state);
    let database = root.join("market/databento_market_data.sqlite3");
    let report = tokio::task::spawn_blocking(move || {
        crate::daily_regime::build_daily_regime_report(&root, &database)
    })
    .await
    .map_err(ApiError::internal)?
    .map_err(|error| ApiError::service_unavailable(error.to_string()))?;
    Ok(Json(
        serde_json::to_value(report).map_err(ApiError::internal)?,
    ))
}

#[derive(Debug, Deserialize)]
struct LiveBarsRequest {
    symbol: Option<String>,
    limit: Option<usize>,
}

async fn live_bars(
    State(state): State<AppState>,
    Query(request): Query<LiveBarsRequest>,
) -> Result<Json<Value>, ApiError> {
    if state.config.live.provider == "databento"
        && let Some(symbol) = request.symbol.as_deref()
    {
        let limit = request.limit.unwrap_or(500).clamp(1, 5_000);
        let rows = crate::data::market_store::latest_live_bars(
            &data_root(&state).join("market/databento_market_data.sqlite3"),
            symbol,
            limit,
        )
        .map_err(ApiError::internal)?;
        return Ok(Json(json!({
            "provider":"databento",
            "dataset":"EQUS.MINI",
            "schema":"ohlcv-1m",
            "storage":"APPEND_ONLY_SQLITE",
            "symbol":symbol.trim().trim_start_matches("US.").to_ascii_uppercase(),
            "bars":rows,
            "count":rows.len()
        })));
    }
    let file = if state.config.live.provider == "massive" {
        "massive_stock_bars.jsonl"
    } else if state.config.live.provider == "databento" {
        "databento_stock_bars.jsonl"
    } else {
        "finalized_bars.jsonl"
    };
    let rows = read_jsonl_tail(&live_root(&state).join(file), 500)?;
    Ok(Json(json!({"bars":rows,"count":rows.len()})))
}

async fn live_events(State(state): State<AppState>) -> Result<Json<Value>, ApiError> {
    let file = if state.config.live.provider == "massive" {
        "massive_stock_bars.jsonl"
    } else if state.config.live.provider == "databento" {
        "databento_stock_bars.jsonl"
    } else {
        "raw_sdk_events.jsonl"
    };
    let rows = read_jsonl_tail(&live_root(&state).join(file), 200)?;
    Ok(Json(json!({"events": rows})))
}

fn ibkr_relay_enabled() -> bool {
    std::env::var("IBKR_QUOTE_RELAY_ENABLED").is_ok_and(|value| value == "true")
}

async fn ibkr_relay_ingest(
    State(state): State<AppState>,
    Json(batch): Json<crate::data::ibkr_relay::IbkrQuoteBatch>,
) -> Result<Json<crate::data::ibkr_relay::IbkrRelayStatus>, ApiError> {
    if !ibkr_relay_enabled() {
        return Err(ApiError::service_unavailable(
            "IBKR quote relay is disabled",
        ));
    }
    let received_at = Utc::now();
    let policy = crate::data::ibkr_relay::policy_from_symbols(
        &state.config.live.symbols,
        state.config.live.stale_after_ms,
        state.config.live.max_context_skew_ms,
    );
    let receipt = crate::data::ibkr_relay::validate_quote_batch(&batch, received_at, &policy)
        .map_err(|error| ApiError::unprocessable(error.to_string()))?;
    let status = crate::data::ibkr_relay::persist_quote_batch(&live_root(&state), batch, receipt)
        .map_err(ApiError::internal)?;
    Ok(Json(status))
}

async fn ibkr_relay_quotes(State(state): State<AppState>) -> Result<Json<Value>, ApiError> {
    if !ibkr_relay_enabled() {
        return Ok(Json(json!({
            "status":"DISABLED",
            "provider":"IBKR_CLIENT_PORTAL",
            "quote_only":true,
            "execution_enabled":false
        })));
    }
    let root = live_root(&state);
    let status = crate::data::ibkr_relay::read_status(&root.join("ibkr_relay_status.json"))
        .map_err(ApiError::internal)?;
    let batches = read_jsonl_tail(&root.join("ibkr_quote_batches.jsonl"), 10)?;
    Ok(Json(json!({
        "status":status,
        "batches":batches,
        "quote_only":true,
        "execution_enabled":false
    })))
}

fn moomoo_owner_forecast_relay_enabled() -> bool {
    std::env::var("MOOMOO_FORECAST_RELAY_ENABLED").is_ok_and(|value| value == "true")
}

fn data_root(state: &AppState) -> std::path::PathBuf {
    state
        .config
        .data
        .raw_root
        .parent()
        .unwrap_or(std::path::Path::new("data"))
        .to_path_buf()
}

fn moomoo_owner_forecast_policy(
    state: &AppState,
) -> Result<crate::data::moomoo_forecast_relay::OwnerForecastPolicy, ApiError> {
    let registry_path = data_root(state).join("models/universe/registry.json");
    let registry = FrozenUniverseRegistry::from_path(&registry_path).map_err(ApiError::internal)?;
    let configured_symbols = state
        .config
        .live
        .forecast_symbols
        .iter()
        .map(|symbol| symbol.trim_start_matches("US.").to_ascii_uppercase())
        .collect::<BTreeSet<_>>();
    let mut allowed_model_hashes = BTreeMap::new();
    for (symbol, entry) in registry.exact_coverage(&configured_symbols) {
        let entry = entry.map_err(|reason| {
            ApiError::service_unavailable(format!(
                "frozen model registry is unavailable for {symbol}: {reason}"
            ))
        })?;
        allowed_model_hashes.insert(symbol, entry.model_hash.clone());
    }
    Ok(crate::data::moomoo_forecast_relay::OwnerForecastPolicy {
        allowed_model_hashes,
        allowed_horizons: state.config.research.horizons.iter().copied().collect(),
        maximum_live_age_seconds: state.config.os.freshness_limit_seconds,
    })
}

fn append_owner_forecast_to_ledger(
    root: &std::path::Path,
    bundle: &mut ForecastBundle,
    mode: crate::data::moomoo_forecast_relay::OwnerForecastMode,
) -> Result<(), ApiError> {
    let filename = match mode {
        crate::data::moomoo_forecast_relay::OwnerForecastMode::LiveForwardShadow => {
            "prediction_ledger.sqlite3"
        }
        crate::data::moomoo_forecast_relay::OwnerForecastMode::DeterministicReplay => {
            "owner_preview_ledger.sqlite3"
        }
    };
    let ledger =
        PredictionLedger::open(&root.join("state").join(filename)).map_err(ApiError::internal)?;
    for contract in &mut bundle.prediction_layer {
        *contract = ledger
            .append_prediction(contract)
            .map_err(ApiError::internal)?;
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

async fn moomoo_owner_forecast_relay_ingest(
    State(state): State<AppState>,
    Json(mut bundle): Json<ForecastBundle>,
) -> Result<Json<crate::data::moomoo_forecast_relay::OwnerForecastReceipt>, ApiError> {
    if !moomoo_owner_forecast_relay_enabled() {
        return Err(ApiError::service_unavailable(
            "Moomoo owner forecast relay is disabled",
        ));
    }
    if state.config.execution.enabled
        || state.config.execution.allow_real_orders
        || state.config.live.allow_trade_api
    {
        return Err(ApiError::conflict(
            "Moomoo owner forecast relay refuses to run while an execution path is enabled",
        ));
    }
    let received_at = Utc::now();
    let root = data_root(&state);
    let policy = moomoo_owner_forecast_policy(&state)?;
    let initial =
        crate::data::moomoo_forecast_relay::validate_owner_forecast(&bundle, received_at, &policy)
            .map_err(|error| ApiError::unprocessable(error.to_string()))?;
    if initial.mode == crate::data::moomoo_forecast_relay::OwnerForecastMode::LiveForwardShadow {
        let payload = serde_json::to_value(&bundle).map_err(ApiError::internal)?;
        validate_live_forecast_bundle(
            &payload,
            "moomoo",
            &initial.symbol,
            &state.config.research.horizons,
            received_at,
            state.config.os.freshness_limit_seconds,
        )
        .map_err(|reasons| ApiError::unprocessable(reasons.join(" | ")))?;
    }
    append_owner_forecast_to_ledger(&root, &mut bundle, initial.mode)?;
    let receipt =
        crate::data::moomoo_forecast_relay::validate_owner_forecast(&bundle, received_at, &policy)
            .map_err(|error| ApiError::unprocessable(error.to_string()))?;
    let receipt =
        crate::data::moomoo_forecast_relay::persist_owner_forecast(&root, bundle, receipt)
            .map_err(ApiError::internal)?;
    Ok(Json(receipt))
}

async fn moomoo_owner_forecast_relay_status(
    State(state): State<AppState>,
) -> Result<Json<Value>, ApiError> {
    if !moomoo_owner_forecast_relay_enabled() {
        return Ok(Json(json!({
            "status":"DISABLED",
            "provider":"MOOMOO_OPEND",
            "owner_only":true,
            "public_redistribution_authorized":false,
            "execution_enabled":false
        })));
    }
    let status = crate::data::moomoo_forecast_relay::read_status(&data_root(&state))
        .map_err(ApiError::internal)?;
    Ok(Json(json!({
        "status":status,
        "provider":"MOOMOO_OPEND",
        "owner_only":true,
        "public_redistribution_authorized":false,
        "execution_enabled":false,
        "truth":"This relay is an administrator-only research preview and does not grant customer-facing market-data rights."
    })))
}

async fn live_gaps(State(state): State<AppState>) -> Result<Json<Value>, ApiError> {
    if state.config.live.provider == "massive" {
        return Ok(Json(json!({
            "gaps":[],
            "count":0,
            "status":"PROVIDER_STREAM_FAILS_CLOSED_ON_STALE_OR_DISCONNECTED_INPUT",
            "stream":read_json_if_present(&live_root(&state).join("massive_stream_status.json"))?
        })));
    }
    if state.config.live.provider == "databento" {
        return Ok(Json(json!({
            "gaps":[],
            "count":0,
            "status":"PROVIDER_STREAM_FAILS_CLOSED_ON_STALE_DISCONNECTED_OR_UNMAPPED_INPUT",
            "stream":read_json_if_present(&live_root(&state).join("databento_stream_status.json"))?
        })));
    }
    let rows = read_jsonl_tail(&live_root(&state).join("gaps.jsonl"), 500)?;
    Ok(Json(json!({"gaps":rows,"count":rows.len()})))
}

fn read_json_if_present(path: &std::path::Path) -> Result<Value, ApiError> {
    if !path.exists() {
        return Ok(
            json!({"status":"UNAVAILABLE","reason":format!("artifact absent: {}",path.display())}),
        );
    }
    let bytes = fs::read(path).map_err(ApiError::internal)?;
    serde_json::from_slice(&bytes).map_err(ApiError::internal)
}

#[derive(Debug, Deserialize)]
struct ForecastQuery {
    symbol: Option<String>,
}

#[derive(Debug, Deserialize)]
struct OpportunityQuery {
    #[serde(alias = "horizon")]
    horizon_minutes: Option<usize>,
    limit: Option<usize>,
    include_unvalidated: Option<bool>,
    #[serde(skip)]
    maximum_age_seconds: Option<i64>,
}

#[derive(Debug)]
struct RankedResearchCandidate {
    rank_score: f64,
    symbol: String,
    validated: bool,
    value: Value,
}

fn public_realtime_source(provider: &str) -> &'static str {
    match provider {
        "databento" => "DATABENTO:EQUS.MINI",
        "massive" => "MASSIVE:SIP",
        "moomoo" => "MOOMOO_OPEND",
        _ => "RUST_LIVE_FORECAST_CONTRACT",
    }
}

fn public_realtime_caveats(provider: &str) -> Vec<&'static str> {
    let mut caveats = vec![
        "Direction is an uncalibrated model condition; no probability, expected move, target price, rank, or trade instruction is published.",
        "Fresh licensed market data and immutable model lineage were verified for this observation.",
    ];
    if provider.eq_ignore_ascii_case("databento") {
        caveats.extend([
            "Provider send time is unavailable; the availability timestamp is the AXIO7 server receipt clock.",
            "Databento EQUS.MINI OHLCV-1m contains completed bars and does not expose order-book depth.",
            "Licensed access does not imply permission to redistribute raw vendor data.",
        ]);
    }
    caveats
}

fn uncalibrated_scan_candidate_projection(
    candidate: &RankedResearchCandidate,
    provider: &str,
) -> Value {
    let row = &candidate.value;
    json!({
        "symbol":row.get("symbol").cloned().unwrap_or_else(|| json!(candidate.symbol)),
        "horizon_minutes":row.get("horizon_minutes").cloned().unwrap_or(Value::Null),
        "candidate_status":"UNCALIBRATED_RESEARCH_OUTPUT",
        "statistical_orientation":row.get("statistical_orientation").cloned().unwrap_or(Value::Null),
        "observation_cutoff":row.get("observation_cutoff").cloned().unwrap_or(Value::Null),
        "latest_input_available_at":row.get("latest_input_available_at").cloned().unwrap_or(Value::Null),
        "data_age_seconds":row.get("data_age_seconds").cloned().unwrap_or(Value::Null),
        "data_source":public_realtime_source(provider),
        "coverage":1.0,
        "coverage_semantics":"ALL_REQUIRED_TARGET_AND_CONTEXT_SYMBOLS_PRESENT_AT_THE_DECISION_CUTOFF",
        "realtime":true,
        "entitlement":"LICENSED_REALTIME_SHADOW_EVIDENCE_VERIFIED",
        "published_probability_status":row.get("published_probability_status").cloned().unwrap_or_else(|| json!("WITHHELD_NO_MATCHING_PROMOTED_OOS_CALIBRATION")),
        "validation":row.get("validation").cloned().unwrap_or_else(|| json!({})),
        "caveats":public_realtime_caveats(provider)
    })
}

fn project_public_scan_candidates(
    mut candidates: Vec<RankedResearchCandidate>,
    limit: usize,
    provider: &str,
    live_feed_verified: bool,
) -> Vec<Value> {
    if !live_feed_verified {
        return Vec::new();
    }
    candidates.sort_by(|left, right| match (left.validated, right.validated) {
        (true, false) => std::cmp::Ordering::Less,
        (false, true) => std::cmp::Ordering::Greater,
        (true, true) => right
            .rank_score
            .total_cmp(&left.rank_score)
            .then_with(|| left.symbol.cmp(&right.symbol)),
        (false, false) => left.symbol.cmp(&right.symbol),
    });
    let mut validated_rank = 0_usize;
    candidates
        .into_iter()
        .take(limit)
        .map(|mut candidate| {
            if !candidate.validated {
                return uncalibrated_scan_candidate_projection(&candidate, provider);
            }
            validated_rank += 1;
            if let Some(object) = candidate.value.as_object_mut() {
                object.insert("research_rank".into(), json!(validated_rank));
            }
            candidate.value
        })
        .collect()
}

fn live_forecast_filename(canonical: &str) -> String {
    if canonical.eq_ignore_ascii_case("SPY") {
        "forecast_contract_live_latest.json".to_string()
    } else {
        format!(
            "forecast_contract_live_{}_latest.json",
            canonical.to_ascii_lowercase()
        )
    }
}

const DATABENTO_ATOMIC_FORECAST_SYMBOL_COUNT: usize = 9;

fn configured_live_forecast_symbols(config: &AppConfig) -> BTreeSet<String> {
    config
        .live
        .forecast_symbols
        .iter()
        .filter_map(|symbol| crate::frozen_universe::canonical_model_symbol(symbol).ok())
        .collect()
}

/// Request-scoped source of customer-visible forecasts.
///
/// A Databento request resolves one all-nine committed batch once and keeps
/// that immutable snapshot for every symbol lookup in the request. It cannot
/// fall back to the independently projected `*_latest.json` files.
#[derive(Debug)]
enum CustomerLiveForecastSnapshot {
    Databento(Option<crate::data::databento_inference::CommittedForecastBatch>),
    PerSymbolFiles,
}

impl CustomerLiveForecastSnapshot {
    fn load(
        root: &std::path::Path,
        provider: &str,
        expected_symbols: &BTreeSet<String>,
        configured_symbol_count: usize,
    ) -> Result<Self, &'static str> {
        if !provider.eq_ignore_ascii_case("databento") {
            return Ok(Self::PerSymbolFiles);
        }
        if configured_symbol_count != DATABENTO_ATOMIC_FORECAST_SYMBOL_COUNT
            || expected_symbols.len() != DATABENTO_ATOMIC_FORECAST_SYMBOL_COUNT
        {
            return Err("DATABENTO_ATOMIC_BATCH_EXACT_NINE_CONFIG_REQUIRED");
        }
        let batch = crate::data::databento_inference::read_latest_committed_forecast_batch(
            root,
            expected_symbols,
        );
        if batch.as_ref().is_some_and(|batch| {
            batch.forecasts.len() != DATABENTO_ATOMIC_FORECAST_SYMBOL_COUNT
                || batch.forecasts.keys().cloned().collect::<BTreeSet<_>>() != *expected_symbols
        }) {
            return Err("DATABENTO_ATOMIC_BATCH_MEMBER_SET_MISMATCH");
        }
        Ok(Self::Databento(batch))
    }

    fn payload(
        &self,
        root: &std::path::Path,
        canonical: &str,
    ) -> Result<Option<Value>, &'static str> {
        match self {
            Self::Databento(batch) => Ok(batch
                .as_ref()
                .and_then(|batch| batch.forecasts.get(canonical))
                .cloned()),
            Self::PerSymbolFiles => {
                let path = root.join("reports").join(live_forecast_filename(canonical));
                let bytes = match fs::read(path) {
                    Ok(bytes) => bytes,
                    Err(error) if error.kind() == std::io::ErrorKind::NotFound => return Ok(None),
                    Err(_) => return Err("FORECAST_ARTIFACT_READ_FAILED"),
                };
                serde_json::from_slice(&bytes)
                    .map(Some)
                    .map_err(|_| "FORECAST_ARTIFACT_INVALID")
            }
        }
    }
}

fn percent(value: f64) -> f64 {
    value * 100.0
}

const PROMOTED_PROBABILITY_CALIBRATION_STATUS: &str = "PROMOTED_OOS_CALIBRATION_APPLIED";

fn promoted_probability_up_for_publication(row: &Value) -> Option<f64> {
    let eligible = row
        .pointer("/probability_calibration/eligible_for_probability_use")
        .and_then(Value::as_bool)
        == Some(true);
    let runtime_status = row
        .pointer("/probability_calibration/status")
        .and_then(Value::as_str);
    let contract_status = row.get("calibration_status").and_then(Value::as_str);
    let reasons_empty = row
        .pointer("/probability_calibration/reasons")
        .and_then(Value::as_array)
        .is_some_and(|reasons| reasons.is_empty());
    if !eligible
        || runtime_status != Some(PROMOTED_PROBABILITY_CALIBRATION_STATUS)
        || contract_status != runtime_status
        || !reasons_empty
    {
        return None;
    }

    let runtime_probability = row
        .pointer("/probability_calibration/calibrated_probability_up")
        .and_then(Value::as_f64)
        .filter(|value| value.is_finite() && (0.0..=1.0).contains(value));
    let contract_probability = row
        .get("calibrated_probability_up")
        .and_then(Value::as_f64)
        .filter(|value| value.is_finite() && (0.0..=1.0).contains(value));
    runtime_probability
        .zip(contract_probability)
        .filter(|(runtime, contract)| (runtime - contract).abs() <= 1.0e-9)
        .map(|(runtime, _)| runtime)
}

#[derive(Debug)]
struct LiveBundleValidation {
    maximum_forecast_age_seconds: i64,
}

const SUPPORTED_LIVE_FORECAST_CONTRACT_VERSIONS: [&str; 4] = ["4.1", "4.2", "4.3", "4.4"];

fn validate_probability_estimate_interval(
    value: Option<&Value>,
    prefix: &str,
    expected_estimate: f64,
    reasons: &mut Vec<String>,
) {
    let Some(interval) = value.filter(|value| value.is_object()) else {
        reasons.push(format!("{prefix}_ABSENT"));
        return;
    };
    let estimate = interval.get("estimate").and_then(Value::as_f64);
    let lower = interval.get("lower").and_then(Value::as_f64);
    let upper = interval.get("upper").and_then(Value::as_f64);
    let confidence_level = interval.get("confidence_level").and_then(Value::as_f64);
    let effective_sample_size = interval
        .get("effective_sample_size")
        .and_then(Value::as_f64);
    let ordered = estimate
        .zip(lower)
        .zip(upper)
        .is_some_and(|((estimate, lower), upper)| {
            estimate.is_finite()
                && lower.is_finite()
                && upper.is_finite()
                && (0.0..=1.0).contains(&estimate)
                && (0.0..=1.0).contains(&lower)
                && (0.0..=1.0).contains(&upper)
                && lower <= estimate
                && estimate <= upper
                && (estimate - expected_estimate).abs() <= 1.0e-6
        });
    if !ordered
        || confidence_level != Some(0.95)
        || effective_sample_size.is_none_or(|value| !value.is_finite() || value < 1.0)
        || !interval
            .get("method")
            .and_then(Value::as_str)
            .is_some_and(|value| !value.trim().is_empty())
        || !interval
            .get("status")
            .and_then(Value::as_str)
            .is_some_and(|value| !value.trim().is_empty())
        || !interval
            .get("semantics")
            .and_then(Value::as_str)
            .is_some_and(|value| !value.trim().is_empty())
    {
        reasons.push(format!("{prefix}_INVALID"));
    }
}

fn validate_distribution_contract(
    row: &Value,
    prefix: &str,
    reasons: &mut Vec<String>,
    version: &str,
) {
    let is_v44 = version == "4.4";
    let reference_price = row
        .get("reference_price")
        .and_then(Value::as_f64)
        .filter(|value| value.is_finite() && *value > 0.0);
    let expected_return = row
        .get("expected_return")
        .and_then(Value::as_f64)
        .filter(|value| value.is_finite());
    let legacy_price_semantics_valid = || {
        let expected_price = row
            .get("expected_price")
            .and_then(Value::as_f64)
            .filter(|value| value.is_finite() && *value > 0.0);
        row.get("return_definition").and_then(Value::as_str) == Some("SIMPLE_RETURN")
            && reference_price
                .zip(expected_return)
                .zip(expected_price)
                .is_some_and(|((reference, expected_return), expected_price)| {
                    let engine_price = reference * (1.0 + expected_return);
                    (engine_price - expected_price).abs() <= 1.0e-8 * reference.max(1.0)
                })
    };
    let v44_price_semantics_valid = || {
        let scenario_expected_price = row
            .get("current_close_reference_scenario_expected_price")
            .and_then(Value::as_f64)
            .filter(|value| value.is_finite() && *value > 0.0);
        row.get("expected_price").is_some_and(Value::is_null)
            && row.get("return_definition").and_then(Value::as_str)
                == Some(KERNEL_RETURN_DEFINITION)
            && row
                .get("price_quantiles")
                .and_then(Value::as_array)
                .is_some_and(Vec::is_empty)
            && row
                .get("current_close_reference_scenario_basis")
                .and_then(Value::as_str)
                == Some(CURRENT_CLOSE_SCENARIO_BASIS)
            && row
                .get("current_close_reference_scenario_status")
                .and_then(Value::as_str)
                == Some(CURRENT_CLOSE_SCENARIO_STATUS)
            && row
                .get("current_close_reference_scenario_semantics")
                .and_then(Value::as_str)
                == Some(CURRENT_CLOSE_SCENARIO_SEMANTICS)
            && reference_price
                .zip(expected_return)
                .zip(scenario_expected_price)
                .is_some_and(|((reference, expected_return), scenario_price)| {
                    let reference_scenario_price = reference * (1.0 + expected_return);
                    reference_scenario_price.is_finite()
                        && reference_scenario_price > 0.0
                        && (reference_scenario_price - scenario_price).abs()
                            <= 1.0e-8 * reference.max(1.0)
                })
    };
    if (is_v44 && !v44_price_semantics_valid()) || (!is_v44 && !legacy_price_semantics_valid()) {
        reasons.push(format!(
            "{prefix}_EXPECTED_PRICE_OR_RETURN_DEFINITION_INVALID"
        ));
    }
    if is_v44 {
        let return_quantiles = row.get("return_quantiles").and_then(Value::as_array);
        let scenario_price_quantiles = row
            .get("current_close_reference_scenario_price_quantiles")
            .and_then(Value::as_array);
        let quantiles_valid = return_quantiles
            .zip(scenario_price_quantiles)
            .zip(reference_price)
            .is_some_and(|((returns, scenario_prices), reference)| {
                !returns.is_empty()
                    && returns.len() == scenario_prices.len()
                    && returns.iter().zip(scenario_prices).all(
                        |(return_quantile, price_quantile)| {
                            let return_probability =
                                return_quantile.get("probability").and_then(Value::as_f64);
                            let return_value = return_quantile.get("value").and_then(Value::as_f64);
                            let price_probability =
                                price_quantile.get("probability").and_then(Value::as_f64);
                            let price_value = price_quantile.get("value").and_then(Value::as_f64);
                            return_probability
                                .zip(return_value)
                                .zip(price_probability)
                                .zip(price_value)
                                .is_some_and(
                                    |(
                                        ((return_probability, return_value), price_probability),
                                        price_value,
                                    )| {
                                        return_probability.is_finite()
                                            && (0.0..=1.0).contains(&return_probability)
                                            && return_value.is_finite()
                                            && price_probability.is_finite()
                                            && (return_probability - price_probability).abs()
                                                <= 1.0e-12
                                            && price_value.is_finite()
                                            && price_value > 0.0
                                            && (price_value - reference * (1.0 + return_value))
                                                .abs()
                                                <= 1.0e-8 * reference.max(1.0)
                                    },
                                )
                        },
                    )
            });
        if !quantiles_valid {
            reasons.push(format!(
                "{prefix}_CURRENT_CLOSE_REFERENCE_SCENARIO_QUANTILES_INVALID"
            ));
        }
    }

    let raw_up = row.get("raw_analog_up_frequency").and_then(Value::as_f64);
    let raw_flat = row.get("raw_analog_flat_frequency").and_then(Value::as_f64);
    let raw_down = row.get("raw_analog_down_frequency").and_then(Value::as_f64);
    if raw_up
        .zip(raw_flat)
        .zip(raw_down)
        .is_none_or(|((up, flat), down)| {
            [up, flat, down]
                .iter()
                .any(|value| !value.is_finite() || !(0.0..=1.0).contains(value))
                || (up + flat + down - 1.0).abs() > 1.0e-6
        })
    {
        reasons.push(format!("{prefix}_RAW_DIRECTION_FREQUENCIES_INVALID"));
    }
    let calibration_eligible = row
        .pointer("/probability_calibration/eligible_for_probability_use")
        .and_then(Value::as_bool)
        == Some(true);
    let runtime_calibrated_up = row
        .pointer("/probability_calibration/calibrated_probability_up")
        .and_then(Value::as_f64);
    let contract_calibrated_up = row.get("calibrated_probability_up").and_then(Value::as_f64);
    let published_up = row.get("p_up").and_then(Value::as_f64);
    let down_withheld = row.get("p_down").is_none_or(Value::is_null);
    let flat_withheld = row.get("p_flat").is_none_or(Value::is_null);
    let published_probability_valid = if calibration_eligible {
        runtime_calibrated_up
            .zip(contract_calibrated_up)
            .zip(published_up)
            .is_some_and(|((runtime, contract), published)| {
                runtime.is_finite()
                    && (0.0..=1.0).contains(&runtime)
                    && (runtime - contract).abs() <= 1.0e-9
                    && (runtime - published).abs() <= 1.0e-9
            })
            && down_withheld
            && flat_withheld
    } else {
        row.get("p_up").is_none_or(Value::is_null)
            && down_withheld
            && flat_withheld
            && runtime_calibrated_up.is_none()
            && contract_calibrated_up.is_none()
    };
    if !published_probability_valid {
        reasons.push(format!(
            "{prefix}_PUBLISHED_PROBABILITY_NOT_PROMOTED_BINARY_UP_ONLY"
        ));
    }

    let kernel = row.get("kernel_regression");
    let feature_count = kernel
        .and_then(|value| value.get("feature_dimension_count"))
        .and_then(Value::as_u64)
        .and_then(|value| usize::try_from(value).ok());
    let selected_dimensions = kernel
        .and_then(|value| value.get("selected_dimensions"))
        .and_then(Value::as_array);
    let kernel_evidence_valid = kernel.is_some_and(Value::is_object)
        && kernel
            .and_then(|value| value.get("status"))
            .and_then(Value::as_str)
            .is_some_and(|value| !value.trim().is_empty())
        && feature_count.is_some_and(|value| value > 0 && value <= 12)
        && selected_dimensions.is_some_and(|values| {
            Some(values.len()) == feature_count
                && values
                    .iter()
                    .all(|value| value.as_str().is_some_and(|value| !value.is_empty()))
                && values
                    .iter()
                    .enumerate()
                    .all(|(index, value)| values[..index].iter().all(|earlier| earlier != value))
        })
        && ["metric", "kernel"].into_iter().all(|field| {
            kernel
                .and_then(|value| value.get(field))
                .and_then(Value::as_str)
                .is_some_and(|value| !value.trim().is_empty())
        })
        && kernel
            .and_then(|value| value.get("bandwidth"))
            .and_then(Value::as_f64)
            .is_some_and(|value| value.is_finite() && value > 0.0)
        && kernel
            .and_then(|value| value.get("neighbor_count"))
            .and_then(Value::as_u64)
            .is_some_and(|value| value > 0)
        && kernel
            .and_then(|value| value.get("effective_sample_size"))
            .and_then(Value::as_f64)
            .is_some_and(|value| value.is_finite() && value >= 1.0)
        && kernel
            .and_then(|value| value.get("direction_event_threshold_return"))
            .and_then(Value::as_f64)
            .is_some_and(|value| value.is_finite() && value >= 0.0)
        && kernel
            .and_then(|value| value.get("nadaraya_watson_expected_return"))
            .and_then(Value::as_f64)
            .zip(expected_return)
            .is_some_and(|(kernel_return, contract_return)| {
                kernel_return.is_finite() && (kernel_return - contract_return).abs() <= 1.0e-12
            })
        && kernel
            .and_then(|value| value.get("local_linear_intercept"))
            .and_then(Value::as_f64)
            .is_some_and(f64::is_finite);
    if !kernel_evidence_valid {
        reasons.push(format!("{prefix}_KERNEL_REGRESSION_EVIDENCE_INVALID"));
    }
    if let (Some(up), Some(flat), Some(down)) = (raw_up, raw_flat, raw_down) {
        validate_probability_estimate_interval(
            row.pointer("/kernel_regression/direction_probability_intervals/up"),
            &format!("{prefix}_RAW_UP_INTERVAL"),
            up,
            reasons,
        );
        validate_probability_estimate_interval(
            row.pointer("/kernel_regression/direction_probability_intervals/flat"),
            &format!("{prefix}_RAW_FLAT_INTERVAL"),
            flat,
            reasons,
        );
        validate_probability_estimate_interval(
            row.pointer("/kernel_regression/direction_probability_intervals/down"),
            &format!("{prefix}_RAW_DOWN_INTERVAL"),
            down,
            reasons,
        );
    }

    let intervals = row
        .get("outcome_prediction_intervals")
        .and_then(Value::as_array);
    let interval_for_mass = |mass: f64| {
        intervals.and_then(|values| {
            values.iter().find(|value| {
                value
                    .get("probability_mass")
                    .and_then(Value::as_f64)
                    .is_some_and(|value| (value - mass).abs() <= 1.0e-9)
            })
        })
    };
    let validate_outcome = |value: &Value| {
        let lower_return = value.get("lower_return").and_then(Value::as_f64);
        let upper_return = value.get("upper_return").and_then(Value::as_f64);
        let lower_price = value
            .get(if is_v44 {
                "current_close_reference_scenario_lower_price"
            } else {
                "lower_price"
            })
            .and_then(Value::as_f64);
        let upper_price = value
            .get(if is_v44 {
                "current_close_reference_scenario_upper_price"
            } else {
                "upper_price"
            })
            .and_then(Value::as_f64);
        let scenario_metadata_valid = !is_v44
            || (value.get("lower_price").is_some_and(Value::is_null)
                && value.get("upper_price").is_some_and(Value::is_null)
                && value
                    .get("current_close_reference_scenario_basis")
                    .and_then(Value::as_str)
                    == Some(CURRENT_CLOSE_SCENARIO_BASIS)
                && value
                    .get("current_close_reference_scenario_status")
                    .and_then(Value::as_str)
                    == Some(CURRENT_CLOSE_SCENARIO_STATUS)
                && value
                    .get("current_close_reference_scenario_semantics")
                    .and_then(Value::as_str)
                    == Some(CURRENT_CLOSE_SCENARIO_SEMANTICS));
        lower_return
            .zip(upper_return)
            .zip(lower_price)
            .zip(upper_price)
            .zip(reference_price)
            .is_some_and(
                |((((lower_return, upper_return), lower_price), upper_price), reference)| {
                    lower_return.is_finite()
                        && upper_return.is_finite()
                        && lower_return <= upper_return
                        && lower_price.is_finite()
                        && upper_price.is_finite()
                        && lower_price > 0.0
                        && lower_price <= upper_price
                        && (lower_price - reference * (1.0 + lower_return)).abs()
                            <= 1.0e-8 * reference.max(1.0)
                        && (upper_price - reference * (1.0 + upper_return)).abs()
                            <= 1.0e-8 * reference.max(1.0)
                        && scenario_metadata_valid
                        && value
                            .get("method")
                            .and_then(Value::as_str)
                            .is_some_and(|value| !value.is_empty())
                        && value
                            .get("status")
                            .and_then(Value::as_str)
                            .is_some_and(|value| !value.is_empty())
                        && value
                            .get("semantics")
                            .and_then(Value::as_str)
                            .is_some_and(|value| !value.is_empty())
                },
            )
    };
    let middle_80 = interval_for_mass(0.80);
    let middle_90 = interval_for_mass(0.90);
    if middle_80.is_none_or(|value| !validate_outcome(value))
        || middle_90.is_none_or(|value| !validate_outcome(value))
        || middle_80.zip(middle_90).is_some_and(|(inner, outer)| {
            inner.get("lower_return").and_then(Value::as_f64)
                < outer.get("lower_return").and_then(Value::as_f64)
                || inner.get("upper_return").and_then(Value::as_f64)
                    > outer.get("upper_return").and_then(Value::as_f64)
        })
    {
        reasons.push(format!("{prefix}_OUTCOME_PREDICTION_INTERVALS_INVALID"));
    }

    if row
        .pointer("/stochastic_research_layer/affects_decision")
        .and_then(Value::as_bool)
        != Some(false)
    {
        reasons.push(format!("{prefix}_SDE_MUST_BE_DECISION_NEUTRAL"));
    }
    let Some(horizon) = row
        .pointer("/stochastic_research_layer/horizon_forecast")
        .filter(|value| value.is_object())
    else {
        reasons.push(format!("{prefix}_SDE_DISTRIBUTION_ABSENT"));
        return;
    };
    {
        let direction = horizon.get("direction_probabilities");
        let p_up = direction
            .and_then(|value| value.get("p_up"))
            .and_then(Value::as_f64);
        let p_flat = direction
            .and_then(|value| value.get("p_flat"))
            .and_then(Value::as_f64);
        let p_down = direction
            .and_then(|value| value.get("p_down"))
            .and_then(Value::as_f64);
        let sde_intervals = horizon
            .get("central_prediction_intervals")
            .and_then(Value::as_array);
        let probabilities_valid = p_up
            .zip(p_flat)
            .zip(p_down)
            .is_some_and(|((up, flat), down)| {
                [up, flat, down]
                    .iter()
                    .all(|value| value.is_finite() && (0.0..=1.0).contains(value))
                    && (up + flat + down - 1.0).abs() <= 1.0e-6
            });
        let direction_metadata_valid = direction.is_some_and(|value| {
            value.get("status").and_then(Value::as_str)
                == Some("UNCALIBRATED_RESEARCH_ONLY_GAUSSIAN_MOMENT_MATCHED")
                && value
                    .get("method")
                    .and_then(Value::as_str)
                    .is_some_and(|value| !value.is_empty())
                && value
                    .get("semantics")
                    .and_then(Value::as_str)
                    .is_some_and(|value| {
                        value.contains("NOT_A_CONFIDENCE_GUARANTEE")
                            && value.contains("JUMP_COMPONENT_EXCLUDED")
                    })
                && if is_v44 {
                    value
                        .get("material_move_lower_threshold_log_return")
                        .and_then(Value::as_f64)
                        .zip(
                            value
                                .get("material_move_upper_threshold_log_return")
                                .and_then(Value::as_f64),
                        )
                        .zip(
                            row.pointer("/kernel_regression/direction_event_threshold_return")
                                .and_then(Value::as_f64),
                        )
                        .is_some_and(|((lower, upper), simple_threshold)| {
                            simple_threshold.is_finite()
                                && (0.0..1.0).contains(&simple_threshold)
                                && lower.is_finite()
                                && upper.is_finite()
                                && lower <= 0.0
                                && upper >= 0.0
                                && lower <= upper
                                && (lower - (-simple_threshold).ln_1p()).abs() <= 1.0e-9
                                && (upper - simple_threshold.ln_1p()).abs() <= 1.0e-9
                                && value
                                    .get("material_move_threshold_log_return")
                                    .is_none_or(Value::is_null)
                        })
                } else {
                    value
                        .get("material_move_threshold_log_return")
                        .and_then(Value::as_f64)
                        .zip(
                            row.pointer("/kernel_regression/direction_event_threshold_return")
                                .and_then(Value::as_f64),
                        )
                        .is_some_and(|(log_threshold, simple_threshold)| {
                            log_threshold.is_finite()
                                && log_threshold >= 0.0
                                && (log_threshold - simple_threshold.ln_1p()).abs() <= 1.0e-6
                        })
                }
        });
        let interval_for_mass = |mass: f64| {
            sde_intervals.and_then(|values| {
                values.iter().find(|value| {
                    value
                        .get("probability_mass")
                        .and_then(Value::as_f64)
                        .is_some_and(|value| (value - mass).abs() <= 1.0e-9)
                })
            })
        };
        let ordered_intervals = [
            interval_for_mass(0.80),
            interval_for_mass(0.90),
            interval_for_mass(0.95),
        ];
        let sde_masses_valid = ordered_intervals.iter().all(|interval| {
            interval.is_some_and(|value| {
                value
                    .get("lower_log_return")
                    .and_then(Value::as_f64)
                    .zip(value.get("upper_log_return").and_then(Value::as_f64))
                    .is_some_and(|(lower, upper)| {
                        lower.is_finite() && upper.is_finite() && lower <= upper
                    })
                    && value.get("status").and_then(Value::as_str)
                        == Some("UNCALIBRATED_RESEARCH_ONLY_GAUSSIAN_MOMENT_MATCHED")
                    && value
                        .get("method")
                        .and_then(Value::as_str)
                        .is_some_and(|value| !value.is_empty())
                    && value
                        .get("semantics")
                        .and_then(Value::as_str)
                        .is_some_and(|value| {
                            value.contains("NOT_A_CONFIDENCE_GUARANTEE")
                                && value.contains("JUMP_COMPONENT_EXCLUDED")
                        })
            })
        });
        let sde_intervals_nested = ordered_intervals.windows(2).all(|pair| {
            pair[0].zip(pair[1]).is_some_and(|(inner, outer)| {
                inner
                    .get("lower_log_return")
                    .and_then(Value::as_f64)
                    .zip(inner.get("upper_log_return").and_then(Value::as_f64))
                    .zip(outer.get("lower_log_return").and_then(Value::as_f64))
                    .zip(outer.get("upper_log_return").and_then(Value::as_f64))
                    .is_some_and(|(((inner_lower, inner_upper), outer_lower), outer_upper)| {
                        outer_lower <= inner_lower && outer_upper >= inner_upper
                    })
            })
        });
        if !probabilities_valid
            || !direction_metadata_valid
            || !sde_masses_valid
            || !sde_intervals_nested
        {
            reasons.push(format!("{prefix}_SDE_DISTRIBUTION_INVALID"));
        }
    }
}

fn validate_market_emotion_proxy(
    payload: &Value,
    expected_provider: &str,
    reasons: &mut Vec<String>,
) {
    let Some(layer) = payload.get("behavioral_state_layer") else {
        return;
    };
    if !layer.is_object() {
        reasons.push("MARKET_EMOTION_PROXY_LAYER_INVALID".to_string());
        return;
    }
    if layer.get("schema_version").and_then(Value::as_str) != Some("axio.behavioral-state.v3") {
        reasons.push("MARKET_EMOTION_PROXY_LAYER_VERSION_INVALID".to_string());
    }
    if layer.get("affects_decision").and_then(Value::as_bool) != Some(false) {
        reasons.push("MARKET_EMOTION_PROXY_MUST_BE_DECISION_NEUTRAL".to_string());
    }
    let Some(publication) = layer.get("market_emotion_proxy") else {
        reasons.push("MARKET_EMOTION_PROXY_PUBLICATION_ABSENT".to_string());
        return;
    };
    if !publication.is_object() {
        reasons.push("MARKET_EMOTION_PROXY_PUBLICATION_INVALID".to_string());
        return;
    }
    if publication.get("schema_version").and_then(Value::as_str)
        != Some("axio.market-emotion-proxy.v1")
        || publication
            .get("measurement_target")
            .and_then(Value::as_str)
            != Some("AGGREGATE_MARKET_RESPONSE_PATTERNS")
        || publication
            .get("measurement_semantics")
            .and_then(Value::as_str)
            != Some("MARKET_DERIVED_PROXY_NOT_DIRECT_HUMAN_PSYCHOLOGY")
        || publication.get("not_probability").and_then(Value::as_bool) != Some(true)
        || publication.get("affects_decision").and_then(Value::as_bool) != Some(false)
        || !publication
            .get("calibrated_probability")
            .is_some_and(Value::is_null)
    {
        reasons.push("MARKET_EMOTION_PROXY_SEMANTICS_INVALID".to_string());
    }
    let unpromoted_probability_present = layer
        .pointer("/behavioral_regime/raw_scores")
        .and_then(Value::as_array)
        .is_some_and(|scores| {
            scores.iter().any(|score| {
                score
                    .get("calibrated_probability")
                    .is_some_and(|value| !value.is_null())
            })
        });
    if unpromoted_probability_present {
        reasons.push("MARKET_EMOTION_PROXY_UNPROMOTED_PROBABILITY_PRESENT".to_string());
    }

    let status = publication
        .get("publication_status")
        .and_then(Value::as_str)
        .unwrap_or_default();
    if status == "AVAILABLE_PARTIAL_PRICE_FLOW_PROXY" {
        let published_raw_index = publication
            .get("raw_compatibility_index")
            .and_then(Value::as_f64);
        let raw_index_valid = published_raw_index
            .is_some_and(|value| value.is_finite() && (0.0..=100.0).contains(&value));
        let published_margin = publication.get("score_margin").and_then(Value::as_f64);
        let margin_valid = published_margin.is_some_and(|value| value.is_finite() && value >= 5.0);
        let layer_price_flow_coverage = layer
            .get("price_flow_feature_coverage_ratio")
            .and_then(Value::as_f64);
        let publication_price_flow_coverage = publication
            .get("price_flow_feature_coverage_ratio")
            .and_then(Value::as_f64);
        let layer_domain_coverage = layer
            .get("required_domain_coverage_ratio")
            .and_then(Value::as_f64);
        let publication_domain_coverage = publication
            .get("required_domain_coverage_ratio")
            .and_then(Value::as_f64);
        let coverage_binding_valid = layer_price_flow_coverage
            .zip(publication_price_flow_coverage)
            .is_some_and(|(layer_value, publication_value)| {
                layer_value.is_finite()
                    && publication_value.is_finite()
                    && (layer_value - 1.0).abs() <= 1.0e-12
                    && (publication_value - layer_value).abs() <= 1.0e-12
            })
            && layer_domain_coverage
                .zip(publication_domain_coverage)
                .is_some_and(|(layer_value, publication_value)| {
                    layer_value.is_finite()
                        && (0.0..=1.0).contains(&layer_value)
                        && publication_value.is_finite()
                        && (publication_value - layer_value).abs() <= 1.0e-12
                });
        let published_pattern = publication
            .get("dominant_market_response_pattern")
            .and_then(Value::as_str);
        let pattern_valid = published_pattern.is_some_and(|value| {
            matches!(
                value,
                "MIXED_OR_CONFLICTED"
                    | "STRESS_LIKE"
                    | "CHASE_LIKE"
                    | "CROWDING_LIKE"
                    | "ATTENTION_SHOCK_LIKE"
                    | "REBOUND_SQUEEZE_LIKE"
            )
        });
        let mut regime_scores = layer
            .pointer("/behavioral_regime/raw_scores")
            .and_then(Value::as_array)
            .map(|scores| {
                scores
                    .iter()
                    .filter_map(|score| {
                        Some((
                            score.get("regime")?.as_str()?,
                            score.get("raw_score")?.as_f64()?,
                        ))
                    })
                    .collect::<Vec<_>>()
            })
            .unwrap_or_default();
        regime_scores.sort_by(|left, right| right.1.total_cmp(&left.1));
        let score_binding_valid =
            published_pattern
                .zip(published_raw_index)
                .is_some_and(|(pattern, raw_index)| {
                    regime_scores
                        .first()
                        .is_some_and(|(top_pattern, top_score)| {
                            *top_pattern == pattern && (top_score - raw_index).abs() <= 1.0e-9
                        })
                })
                && published_margin.is_some_and(|margin| {
                    regime_scores.first().zip(regime_scores.get(1)).is_some_and(
                        |(first, second)| (first.1 - second.1 - margin).abs() <= 1.0e-9,
                    )
                });
        let source_binding_valid = layer
            .get("source_scope")
            .and_then(Value::as_str)
            .zip(publication.get("source_scope").and_then(Value::as_str))
            .is_some_and(|(layer_source, publication_source)| {
                !layer_source.trim().is_empty()
                    && layer_source == publication_source
                    && live_source_matches_expected_provider(expected_provider, layer_source)
            });
        let cutoff = parse_utc(layer.get("observation_cutoff"));
        let available_at = parse_utc(layer.get("latest_input_available_at"));
        let decision_as_of = parse_utc(layer.get("decision_as_of"));
        let publication_as_of = parse_utc(publication.get("as_of"));
        let clock_valid = cutoff
            .zip(available_at)
            .is_some_and(|(cutoff, available_at)| {
                available_at >= cutoff
                    && available_at < cutoff + chrono::Duration::minutes(1)
                    && decision_as_of == Some(available_at)
                    && publication_as_of == Some(available_at)
            });
        if layer.get("availability").and_then(Value::as_str) != Some("PARTIAL_PRICE_FLOW_ONLY")
            || layer
                .get("input_availability_status")
                .and_then(Value::as_str)
                != Some("VERIFIED_PROVIDER_AVAILABILITY")
            || !raw_index_valid
            || !margin_valid
            || !coverage_binding_valid
            || !pattern_valid
            || !score_binding_valid
            || !source_binding_valid
            || !clock_valid
            || !publication
                .get("reason_codes")
                .and_then(Value::as_array)
                .is_some_and(Vec::is_empty)
        {
            reasons.push("MARKET_EMOTION_PROXY_AVAILABLE_VALUE_INVALID".to_string());
        }
    } else if status == "WITHHELD" {
        let unavailable_values_null = publication
            .get("dominant_market_response_pattern")
            .is_some_and(Value::is_null)
            && publication
                .get("raw_compatibility_index")
                .is_some_and(Value::is_null)
            && publication.get("as_of").is_some_and(Value::is_null);
        if !unavailable_values_null
            || !publication
                .get("reason_codes")
                .and_then(Value::as_array)
                .is_some_and(|values| !values.is_empty())
        {
            reasons.push("MARKET_EMOTION_PROXY_WITHHELD_VALUE_INVALID".to_string());
        }
    } else {
        reasons.push("MARKET_EMOTION_PROXY_PUBLICATION_STATUS_INVALID".to_string());
    }
}

fn validate_live_forecast_bundle(
    payload: &Value,
    expected_provider: &str,
    canonical: &str,
    configured_horizons: &[usize],
    now: chrono::DateTime<chrono::Utc>,
    maximum_age_seconds: i64,
) -> Result<LiveBundleValidation, Vec<String>> {
    let mut reasons = Vec::new();
    let contract_version = payload
        .get("forecast_contract_version")
        .and_then(Value::as_str);
    if !contract_version
        .is_some_and(|version| SUPPORTED_LIVE_FORECAST_CONTRACT_VERSIONS.contains(&version))
    {
        reasons.push("INCOMPATIBLE_FORECAST_CONTRACT_VERSION".to_string());
    }
    if !payload
        .get("gamma_convexity_layer")
        .is_some_and(Value::is_object)
    {
        reasons.push("GAMMA_CONVEXITY_LAYER_ABSENT".to_string());
    }
    if payload
        .pointer("/research_only_policy/product_scope")
        .and_then(Value::as_str)
        != Some("IMPERSONAL_WHOLE_MARKET_STATISTICAL_RESEARCH")
    {
        reasons.push("RESEARCH_ONLY_POLICY_ABSENT_OR_INVALID".to_string());
    }
    validate_market_emotion_proxy(payload, expected_provider, &mut reasons);
    let generated_at = parse_utc(payload.get("generated_at"));
    match generated_at {
        Some(timestamp) => {
            let age = now.signed_duration_since(timestamp).num_seconds();
            if maximum_age_seconds <= 0 || age < 0 || age > maximum_age_seconds {
                reasons.push(format!(
                    "BUNDLE_STALE_OR_FUTURE:age_seconds={age}:maximum={maximum_age_seconds}"
                ));
            }
        }
        None => reasons.push("BUNDLE_GENERATED_AT_INVALID".to_string()),
    }

    let rows = payload
        .get("prediction_layer")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();
    if rows.is_empty() {
        let valid_no_edge = payload.get("status").and_then(Value::as_str)
            == Some("NO_VALIDATED_EDGE")
            && payload
                .get("unavailable_horizons")
                .and_then(Value::as_array)
                .is_some_and(|values| !values.is_empty());
        if !valid_no_edge {
            reasons.push("EMPTY_PREDICTION_LAYER_WITHOUT_EXPLICIT_NO_EDGE".to_string());
        }
    }

    let mut seen_horizons = BTreeMap::new();
    let mut maximum_forecast_age = 0_i64;
    let mut live_row_count = 0_usize;
    for (index, row) in rows.iter().enumerate() {
        let prefix = format!("ROW_{index}");
        let horizon = row
            .get("horizon_minutes")
            .and_then(Value::as_u64)
            .and_then(|value| usize::try_from(value).ok());
        match horizon {
            Some(value) if configured_horizons.contains(&value) => {
                if seen_horizons.insert(value, index).is_some() {
                    reasons.push(format!("{prefix}_DUPLICATE_HORIZON"));
                }
            }
            _ => reasons.push(format!("{prefix}_UNSUPPORTED_HORIZON")),
        }
        if row.get("symbol").and_then(Value::as_str) != Some(canonical) {
            reasons.push(format!("{prefix}_SYMBOL_MISMATCH"));
        }
        if row.get("timeframe").and_then(Value::as_str) != Some("1m") {
            reasons.push(format!("{prefix}_TIMEFRAME_NOT_1M"));
        }
        let evidence_kind = row
            .get("evidence_kind")
            .and_then(Value::as_str)
            .unwrap_or_default();
        let is_live_row = evidence_kind == "live_shadow_prediction";
        if is_live_row {
            live_row_count += 1;
            if !row
                .get("data_source")
                .and_then(Value::as_str)
                .is_some_and(|source| {
                    live_source_matches_expected_provider(expected_provider, source)
                })
            {
                reasons.push(format!("{prefix}_OFFICIAL_SDK_SOURCE_NOT_VERIFIED"));
            }
        } else if evidence_kind != "batch_research_prediction" {
            reasons.push(format!("{prefix}_UNSUPPORTED_EVIDENCE_KIND"));
        }
        if row
            .get("data_source")
            .and_then(Value::as_str)
            .unwrap_or_default()
            .contains("fixture")
        {
            reasons.push(format!("{prefix}_FIXTURE_SOURCE_PROHIBITED"));
        }
        if !row
            .get("stochastic_research_layer")
            .is_some_and(Value::is_object)
        {
            reasons.push(format!("{prefix}_STOCHASTIC_RESEARCH_LAYER_ABSENT"));
        }
        if let Some(version @ ("4.3" | "4.4")) = contract_version {
            validate_distribution_contract(row, &prefix, &mut reasons, version);
        }
        for field in ["model_hash", "feature_hash", "data_manifest_hash"] {
            if !row
                .get(field)
                .and_then(Value::as_str)
                .is_some_and(valid_nonzero_sha256)
            {
                reasons.push(format!("{prefix}_{}_INVALID", field.to_ascii_uppercase()));
            }
        }

        let observation_cutoff = parse_utc(row.get("observation_cutoff"));
        let as_of = parse_utc(row.get("as_of"));
        let decision_as_of = parse_utc(row.get("decision_as_of"));
        let latest_input_available_at = parse_utc(row.get("latest_input_available_at"));
        let label_start = parse_utc(row.get("label_start"));
        let label_end = parse_utc(row.get("label_end"));
        let Some(cutoff) = observation_cutoff else {
            reasons.push(format!("{prefix}_OBSERVATION_CUTOFF_INVALID"));
            continue;
        };
        if as_of != Some(cutoff) {
            reasons.push(format!("{prefix}_AS_OF_CLOCK_MISMATCH"));
        }
        if is_live_row {
            if decision_as_of.is_none()
                || decision_as_of != latest_input_available_at
                || latest_input_available_at.is_none_or(|timestamp| {
                    timestamp < cutoff || timestamp >= cutoff + chrono::Duration::minutes(1)
                })
            {
                reasons.push(format!("{prefix}_DECISION_OR_AVAILABILITY_CLOCK_INVALID"));
            }
        } else if decision_as_of != Some(cutoff) || latest_input_available_at != Some(cutoff) {
            reasons.push(format!("{prefix}_BATCH_CLOCK_NOT_AT_FEATURE_CUTOFF"));
        }
        if label_start != Some(cutoff)
            || horizon.is_none_or(|minutes| {
                label_end != Some(cutoff + chrono::Duration::minutes(minutes as i64))
            })
        {
            reasons.push(format!("{prefix}_LABEL_WINDOW_MISALIGNED"));
        }
        if is_live_row {
            let age = decision_as_of
                .map(|timestamp| now.signed_duration_since(timestamp).num_seconds())
                .unwrap_or(i64::MAX);
            maximum_forecast_age = maximum_forecast_age.max(age);
            if maximum_age_seconds <= 0 || age < 0 || age > maximum_age_seconds {
                reasons.push(format!(
                    "{prefix}_STALE_OR_FUTURE:age_seconds={age}:maximum={maximum_age_seconds}"
                ));
            }
        }
    }
    if !rows.is_empty() && live_row_count == 0 {
        reasons.push("NO_ALIGNED_LIVE_SHADOW_ROWS".to_string());
    }

    reasons.sort();
    reasons.dedup();
    if reasons.is_empty() {
        Ok(LiveBundleValidation {
            maximum_forecast_age_seconds: maximum_forecast_age,
        })
    } else {
        Err(reasons)
    }
}

#[allow(clippy::too_many_arguments)]
fn evaluate_research_candidate(
    expected_provider: &str,
    canonical: &str,
    bundle: &Value,
    row: &Value,
    horizon_minutes: usize,
    now: chrono::DateTime<chrono::Utc>,
    maximum_age_seconds: i64,
    minimum_probability: f64,
    minimum_expected_return_bps: f64,
    probability_publication_ready: bool,
    include_unvalidated: bool,
) -> Result<RankedResearchCandidate, String> {
    if row.get("horizon_minutes").and_then(Value::as_u64) != Some(horizon_minutes as u64) {
        return Err("HORIZON_MISMATCH".into());
    }
    if row.get("symbol").and_then(Value::as_str) != Some(canonical) {
        return Err("SYMBOL_MISMATCH".into());
    }
    if row.get("evidence_kind").and_then(Value::as_str) != Some("live_shadow_prediction")
        || !row
            .get("data_source")
            .and_then(Value::as_str)
            .is_some_and(|source| live_source_matches_expected_provider(expected_provider, source))
    {
        return Err("NOT_VERIFIED_LIVE_SHADOW_EVIDENCE".into());
    }

    let observation_cutoff = parse_utc(row.get("observation_cutoff"))
        .ok_or_else(|| "INVALID_OBSERVATION_CUTOFF".to_string())?;
    let feature_as_of =
        parse_utc(row.get("as_of")).ok_or_else(|| "INVALID_FEATURE_AS_OF".to_string())?;
    let forecast_as_of =
        parse_utc(row.get("decision_as_of")).ok_or_else(|| "INVALID_FORECAST_AS_OF".to_string())?;
    let latest_input_available_at = parse_utc(row.get("latest_input_available_at"))
        .ok_or_else(|| "INVALID_INPUT_AVAILABILITY_TIME".to_string())?;
    let label_start =
        parse_utc(row.get("label_start")).ok_or_else(|| "INVALID_LABEL_START".to_string())?;
    let label_end =
        parse_utc(row.get("label_end")).ok_or_else(|| "INVALID_LABEL_END".to_string())?;
    if feature_as_of != observation_cutoff
        || latest_input_available_at != forecast_as_of
        || latest_input_available_at < observation_cutoff
        || latest_input_available_at >= observation_cutoff + chrono::Duration::minutes(1)
        || label_start != observation_cutoff
        || label_end != observation_cutoff + chrono::Duration::minutes(horizon_minutes as i64)
    {
        return Err("NON_CAUSAL_OR_MISALIGNED_FORECAST_CLOCK".into());
    }
    let age_seconds = now.signed_duration_since(forecast_as_of).num_seconds();
    if maximum_age_seconds <= 0 || age_seconds < 0 || age_seconds > maximum_age_seconds {
        return Err(format!(
            "STALE_OR_FUTURE_FORECAST:age_seconds={age_seconds}:maximum={maximum_age_seconds}"
        ));
    }

    let expected_return = row
        .get("expected_return")
        .and_then(Value::as_f64)
        .filter(|value| value.is_finite())
        .ok_or_else(|| "INVALID_EXPECTED_RETURN".to_string())?;
    let raw_up = row
        .get("raw_analog_up_frequency")
        .and_then(Value::as_f64)
        .filter(|value| value.is_finite() && (0.0..=1.0).contains(value))
        .ok_or_else(|| "INVALID_RAW_UP_FREQUENCY".to_string())?;
    let raw_down = row
        .get("raw_analog_down_frequency")
        .and_then(Value::as_f64)
        .filter(|value| value.is_finite() && (0.0..=1.0).contains(value))
        .ok_or_else(|| "INVALID_RAW_DOWN_FREQUENCY".to_string())?;
    let raw_flat = row
        .get("raw_analog_flat_frequency")
        .and_then(Value::as_f64)
        .filter(|value| value.is_finite() && (0.0..=1.0).contains(value))
        .ok_or_else(|| "INVALID_RAW_FLAT_FREQUENCY".to_string())?;
    if (raw_up + raw_down + raw_flat - 1.0).abs() > 1.0e-6 {
        return Err("RAW_DIRECTION_FREQUENCIES_DO_NOT_SUM_TO_ONE".into());
    }
    let calibrated_probability_up = if probability_publication_ready {
        promoted_probability_up_for_publication(row)
    } else {
        None
    };
    if calibrated_probability_up.is_some()
        && expected_return.abs() * 10_000.0 < minimum_expected_return_bps
    {
        return Err("CONDITIONAL_MEAN_BELOW_RESEARCH_THRESHOLD".into());
    }

    let (orientation, conditional_probability, probability_kind, probability_interval, validated) =
        if expected_return > 0.0
            && let Some(probability) = calibrated_probability_up
        {
            (
                "POSITIVE_CONDITIONAL_MEAN",
                probability,
                "PROMOTED_OOS_CALIBRATED_BINARY_UP_PROBABILITY",
                row.pointer("/probability_calibration/calibrated_probability_up_interval")
                    .cloned()
                    .unwrap_or(Value::Null),
                true,
            )
        } else if expected_return > 0.0 {
            (
                "POSITIVE_CONDITIONAL_MEAN",
                raw_up,
                "UNCALIBRATED_KERNEL_WEIGHTED_HISTORICAL_FREQUENCY",
                row.pointer("/kernel_regression/direction_probability_intervals/up")
                    .cloned()
                    .unwrap_or(Value::Null),
                false,
            )
        } else if expected_return < 0.0 {
            (
                "NEGATIVE_CONDITIONAL_MEAN",
                raw_down,
                "UNCALIBRATED_KERNEL_WEIGHTED_HISTORICAL_FREQUENCY",
                row.pointer("/kernel_regression/direction_probability_intervals/down")
                    .cloned()
                    .unwrap_or(Value::Null),
                false,
            )
        } else {
            return Err("NO_DIRECTIONAL_ASYMMETRY".into());
        };
    if validated && conditional_probability < minimum_probability {
        return Err("DIRECTIONAL_PROBABILITY_BELOW_RESEARCH_THRESHOLD".into());
    }

    let calibration_status = row
        .get("calibration_status")
        .and_then(Value::as_str)
        .unwrap_or("UNKNOWN");
    if !include_unvalidated && !validated {
        return Err("UNVALIDATED_SHADOW_CANDIDATE_EXCLUDED_BY_QUERY".into());
    }

    let expected_volatility = row
        .get("expected_volatility")
        .and_then(Value::as_f64)
        .filter(|value| value.is_finite() && *value >= 0.0)
        .ok_or_else(|| "INVALID_EXPECTED_VOLATILITY".to_string())?;
    let epistemic_uncertainty = row
        .get("epistemic_uncertainty")
        .and_then(Value::as_f64)
        .filter(|value| value.is_finite() && *value >= 0.0)
        .ok_or_else(|| "INVALID_EPISTEMIC_UNCERTAINTY".to_string())?;
    let ood_score = row
        .get("ood_score")
        .and_then(Value::as_f64)
        .filter(|value| value.is_finite() && *value >= 0.0)
        .ok_or_else(|| "INVALID_OOD_SCORE".to_string())?;
    let signal_to_noise = expected_return.abs() / expected_volatility.max(1.0e-12);
    let rank_score =
        signal_to_noise * conditional_probability * (1.0 / (1.0 + epistemic_uncertainty));
    if !rank_score.is_finite() {
        return Err("NON_FINITE_RESEARCH_RANK_SCORE".into());
    }

    let momentum = row
        .pointer("/stochastic_research_layer/momentum_head")
        .map(|head| {
            let input_orientation = match head.get("momentum_direction").and_then(Value::as_i64) {
                Some(1) => "POSITIVE",
                Some(-1) => "NEGATIVE",
                _ => "UNAVAILABLE",
            };
            json!({
                "status": head.get("status").cloned().unwrap_or(json!("UNAVAILABLE")),
                "input_momentum_orientation": input_orientation,
                "continuation_probability_percent": head
                    .get("continuation_probability")
                    .and_then(Value::as_f64)
                    .map(percent),
                "reversal_probability_percent": head
                    .get("reversal_probability")
                    .and_then(Value::as_f64)
                    .map(percent),
                "posterior_standard_deviation_percent": head
                    .get("posterior_standard_deviation")
                    .and_then(Value::as_f64)
                    .map(percent),
                "effective_samples": head.get("effective_samples").cloned().unwrap_or(json!(0.0)),
                "shadow_comparison_only": true
            })
        })
        .unwrap_or_else(|| {
            json!({
                "status":"UNAVAILABLE",
                "shadow_comparison_only":true
            })
        });
    let gamma_availability = bundle
        .pointer("/gamma_convexity_layer/availability")
        .cloned()
        .unwrap_or(json!("unavailable"));
    let gamma_unavailable_reasons = bundle
        .pointer("/gamma_convexity_layer/unavailable_reasons")
        .cloned()
        .unwrap_or_else(|| json!(["OPTION_CHAIN_LINEAGE_NOT_AVAILABLE"]));
    let stochastic_model = row
        .pointer("/stochastic_research_layer/model_family")
        .cloned()
        .unwrap_or(json!("UNAVAILABLE"));
    let validation = json!({
        "calibration_status": calibration_status,
        "evidence_grade": row.get("evidence_grade").cloned().unwrap_or(json!("UNKNOWN")),
        "evidence_kind": "live_shadow_prediction",
        "prediction_id": row.get("prediction_id").cloned().unwrap_or(Value::Null),
        "model_version": row.get("model_id").cloned().unwrap_or(Value::Null),
        "feature_version": row.get("feature_version").cloned().unwrap_or(Value::Null),
        "feature_hash": row.get("feature_hash").cloned().unwrap_or(Value::Null),
        "model_hash": row.get("model_hash").cloned().unwrap_or(Value::Null),
        "data_manifest_hash": row.get("data_manifest_hash").cloned().unwrap_or(Value::Null)
    });

    Ok(RankedResearchCandidate {
        rank_score,
        symbol: canonical.to_string(),
        validated,
        value: json!({
            "symbol": canonical,
            "horizon_minutes": horizon_minutes,
            "as_of": forecast_as_of,
            "observation_cutoff": observation_cutoff,
            "latest_input_available_at": latest_input_available_at,
            "data_age_seconds": age_seconds,
            "candidate_status": if validated {
                "VALIDATED_STATISTICAL_CANDIDATE"
            } else {
                "UNVALIDATED_SHADOW_CANDIDATE"
            },
            "statistical_orientation": orientation,
            "conditional_probability_percent": if validated {
                Some(percent(conditional_probability))
            } else {
                None
            },
            "conditional_frequency_estimate_percent": if validated {
                None
            } else {
                Some(percent(conditional_probability))
            },
            "conditional_probability_kind": probability_kind,
            "conditional_probability_interval": probability_interval,
            "probability_up_percent": if validated {
                calibrated_probability_up.map(percent)
            } else {
                None
            },
            "probability_down_percent": Value::Null,
            "probability_flat_percent": Value::Null,
            "published_probability_status": if validated {
                "PROMOTED_BINARY_UP_ONLY_NO_JOINT_MULTICLASS_CALIBRATION"
            } else {
                "WITHHELD_NO_MATCHING_PROMOTED_OOS_CALIBRATION"
            },
            "raw_analog_up_frequency_percent": percent(raw_up),
            "raw_analog_down_frequency_percent": percent(raw_down),
            "raw_analog_flat_frequency_percent": percent(raw_flat),
            "raw_direction_probability_intervals": row
                .pointer("/kernel_regression/direction_probability_intervals"),
            "calibrated_probability_up_percent": calibrated_probability_up.map(percent),
            "probability_calibration": row.get("probability_calibration"),
            "expected_move_percent": percent(expected_return),
            "expected_price": row.get("expected_price"),
            "return_definition": row.get("return_definition"),
            "kernel_empirical_middle_80_percent": row
                .get("outcome_prediction_intervals")
                .and_then(Value::as_array)
                .and_then(|values| values.iter().find(|value| {
                    value.get("probability_mass").and_then(Value::as_f64) == Some(0.80)
                }))
                .map(|interval| json!({
                    "lower": interval.get("lower_return").and_then(Value::as_f64).map(percent),
                    "upper": interval.get("upper_return").and_then(Value::as_f64).map(percent),
                    "status": interval.get("status"),
                    "semantics": interval.get("semantics")
                })),
            "expected_volatility_percent": percent(expected_volatility),
            "epistemic_uncertainty_percent": percent(epistemic_uncertainty),
            "ood_score": ood_score,
            "research_rank_score": rank_score,
            "regime": {
                "dominant_state": row.get("dominant_regime_state").cloned().unwrap_or(Value::Null),
                "dominant_probability_percent": row
                    .get("dominant_regime_probability")
                    .and_then(Value::as_f64)
                    .map(percent),
                "normalized_entropy": row.get("state_entropy").cloned().unwrap_or(Value::Null),
                "selected_state_count": row
                    .pointer("/regime_model_selection/selected_state_count")
                    .cloned()
                    .unwrap_or(Value::Null),
                "eight_state_challenger_status": row
                    .pointer("/regime_model_selection/eight_state_challenger_status")
                    .cloned()
                    .unwrap_or(json!("UNAVAILABLE"))
            },
            "model_committee": {
                "primary_model_id": row.get("model_id").cloned().unwrap_or(json!("UNAVAILABLE")),
                "stochastic_model_family": stochastic_model,
                "same_regime_high_dimensional_kernel": row
                    .get("analog_engine_status")
                    .cloned()
                    .unwrap_or(json!("UNAVAILABLE")),
                "martingale_audit": row
                    .pointer("/stochastic_research_layer/martingale_audit_status")
                    .cloned()
                    .unwrap_or(json!("UNAVAILABLE")),
                "momentum": momentum
            },
            "gamma_feedback_risk": {
                "availability": gamma_availability,
                "unavailable_reasons": gamma_unavailable_reasons,
                "claim_policy": "NO_GAMMA_SQUEEZE_CLAIM_WITHOUT_FRESH_POINT_IN_TIME_OPTION_CHAIN_OI_AND_GREEKS"
            },
            "validation": validation,
            "interpretation": "A conditional statistical observation, not a guaranteed profit, risk-free arbitrage, personalized recommendation, or order."
        }),
    })
}

fn current_tvtp_challenger_projection(
    root: &std::path::Path,
    now: chrono::DateTime<chrono::Utc>,
) -> Value {
    let path = root.join("reports/regime_latest.json");
    let Ok(bytes) = fs::read(path) else {
        return json!({"status":"UNAVAILABLE","reason":"REGIME_ARTIFACT_ABSENT"});
    };
    let Ok(report) = serde_json::from_slice::<Value>(&bytes) else {
        return json!({"status":"UNAVAILABLE","reason":"REGIME_ARTIFACT_INVALID"});
    };
    let Some(artifact_as_of) = parse_utc(report.get("as_of")) else {
        return json!({"status":"UNAVAILABLE","reason":"REGIME_ARTIFACT_AS_OF_INVALID"});
    };
    let age_seconds = now.signed_duration_since(artifact_as_of).num_seconds();
    if !(0..=86_400).contains(&age_seconds) {
        return json!({
            "status":"STALE_UNAVAILABLE",
            "reason":"REGIME_ARTIFACT_OLDER_THAN_24_HOURS_OR_FROM_FUTURE",
            "artifact_as_of":artifact_as_of,
            "age_seconds":age_seconds
        });
    }
    let Some(challenger) = report.get("tvtp_challenger") else {
        return json!({"status":"UNAVAILABLE","reason":"TVTP_CHALLENGER_NOT_EVALUATED"});
    };
    json!({
        "status": challenger.get("status").cloned().unwrap_or(json!("UNAVAILABLE")),
        "artifact_as_of":artifact_as_of,
        "age_seconds":age_seconds,
        "role": challenger.get("role").cloned().unwrap_or(json!("SHADOW_CHALLENGER_ONLY")),
        "decision_policy_impact": "NONE",
        "validation": challenger.get("validation").cloned().unwrap_or(Value::Null),
        "current_session": challenger.get("current_session").cloned().unwrap_or(Value::Null)
    })
}

fn effective_maximum_age_seconds(requested: Option<i64>, server_policy: i64) -> i64 {
    requested
        .map(|requested| requested.min(server_policy))
        .unwrap_or(server_policy)
}

fn build_research_opportunity_scan(
    state: &AppState,
    query: OpportunityQuery,
    now: chrono::DateTime<chrono::Utc>,
) -> Result<Value, ApiError> {
    let horizon_minutes = query.horizon_minutes.unwrap_or(15);
    if !state.config.research.horizons.contains(&horizon_minutes) {
        return Err(ApiError::unprocessable(format!(
            "unsupported horizon {horizon_minutes}; configured horizons are {:?}",
            state.config.research.horizons
        )));
    }
    let limit = query.limit.unwrap_or(2);
    if !(1..=20).contains(&limit) {
        return Err(ApiError::unprocessable(
            "limit must be an integer from 1 through 20",
        ));
    }
    let include_unvalidated = query.include_unvalidated.unwrap_or(true);
    let readiness = production_readiness_receipt(state);
    let probability_publication_ready =
        probability_publication_readiness_blockers(&readiness).is_empty();
    let root = state
        .config
        .data
        .raw_root
        .parent()
        .unwrap_or(std::path::Path::new("data"));
    let maximum_age_seconds = effective_maximum_age_seconds(
        query.maximum_age_seconds,
        state.config.os.freshness_limit_seconds,
    );
    let minimum_probability = state.config.os.confidence_threshold;
    let minimum_expected_return_bps = state.config.os.minimum_expected_return_bps;
    let expected_symbols = configured_live_forecast_symbols(&state.config);
    let configured_symbols = expected_symbols
        .iter()
        .map(|canonical| (canonical.clone(), canonical.clone()))
        .collect::<BTreeMap<_, _>>();
    let forecast_snapshot = CustomerLiveForecastSnapshot::load(
        root,
        &state.config.live.provider,
        &expected_symbols,
        state.config.live.forecast_symbols.len(),
    );

    let mut candidates = Vec::new();
    let mut exclusions = Vec::new();
    let mut fresh_model_rows = 0_usize;
    for canonical in configured_symbols.values() {
        let bundle = match forecast_snapshot
            .as_ref()
            .map_err(|reason| *reason)
            .and_then(|snapshot| snapshot.payload(root, canonical))
        {
            Ok(Some(bundle)) => bundle,
            Ok(None) => {
                exclusions.push(json!({
                    "symbol":canonical,
                    "reason":"LIVE_FORECAST_NOT_PUBLISHED",
                    "live_inference":target_inference_projection(&readiness, canonical)
                }));
                continue;
            }
            Err(reason) => {
                exclusions.push(json!({
                    "symbol":canonical,
                    "reason":reason
                }));
                continue;
            }
        };
        if let Err(reasons) = validate_live_forecast_bundle(
            &bundle,
            &state.config.live.provider,
            canonical,
            &state.config.research.horizons,
            now,
            maximum_age_seconds,
        ) {
            exclusions.push(json!({
                "symbol":canonical,
                "reason":"STALE_OR_INCOMPATIBLE_LIVE_ARTIFACT",
                "validation_flags":reasons
            }));
            continue;
        }
        let matching_rows = bundle
            .get("prediction_layer")
            .and_then(Value::as_array)
            .map(|rows| {
                rows.iter()
                    .filter(|row| {
                        row.get("horizon_minutes").and_then(Value::as_u64)
                            == Some(horizon_minutes as u64)
                    })
                    .collect::<Vec<_>>()
            })
            .unwrap_or_default();
        if matching_rows.len() != 1 {
            exclusions.push(json!({
                "symbol":canonical,
                "reason":if matching_rows.is_empty() {
                    "HORIZON_FORECAST_UNAVAILABLE"
                } else {
                    "DUPLICATE_HORIZON_FORECAST"
                }
            }));
            continue;
        }
        let matching_row = matching_rows[0];
        if !live_prediction_is_ledger_backed(root, &state.config.live.provider, matching_row) {
            exclusions.push(json!({
                "symbol":canonical,
                "reason":"LIVE_PREDICTION_NOT_LEDGER_AND_RECEIPT_BACKED"
            }));
            continue;
        }
        let verified_source_lineage =
            if state.config.live.provider.eq_ignore_ascii_case("databento") {
                let Some(lineage) =
                    crate::data::databento_inference::verified_receipt_lineage(root, matching_row)
                else {
                    exclusions.push(json!({
                        "symbol":canonical,
                        "reason":"DATABENTO_VERIFIED_SOURCE_LINEAGE_UNAVAILABLE"
                    }));
                    continue;
                };
                Some(lineage)
            } else {
                None
            };
        match evaluate_research_candidate(
            &state.config.live.provider,
            canonical,
            &bundle,
            matching_row,
            horizon_minutes,
            now,
            maximum_age_seconds,
            minimum_probability,
            minimum_expected_return_bps,
            probability_publication_ready,
            include_unvalidated,
        ) {
            Ok(mut candidate) => {
                if let Some(lineage) = verified_source_lineage {
                    let Some(validation) = candidate
                        .value
                        .get_mut("validation")
                        .and_then(Value::as_object_mut)
                    else {
                        exclusions.push(json!({
                            "symbol":canonical,
                            "reason":"DATABENTO_SOURCE_LINEAGE_PROJECTION_FAILED"
                        }));
                        continue;
                    };
                    if let Some(lineage) = lineage.as_object() {
                        validation.extend(lineage.clone());
                    }
                }
                fresh_model_rows += 1;
                candidates.push(candidate);
            }
            Err(reason) => exclusions.push(json!({"symbol":canonical,"reason":reason})),
        }
    }
    let candidate_count_before_limit = candidates.len();
    let validated_candidate_count = candidates.iter().filter(|row| row.validated).count();
    let coverage_status = if configured_symbols.is_empty() {
        "NO_CONFIGURED_UNIVERSE"
    } else if fresh_model_rows == configured_symbols.len() {
        "FULL_CONFIGURED_UNIVERSE"
    } else if fresh_model_rows > 0 {
        "PARTIAL_CONFIGURED_UNIVERSE"
    } else {
        "NO_FRESH_QUALIFYING_CANDIDATES"
    };
    let maximum_stream_status_age_ms = maximum_age_seconds.saturating_mul(1_000);
    let (live_feed, live_feed_verified) = if state.config.live.provider == "massive" {
        let live_root = root.join("live");
        let readiness = fs::read(live_root.join("massive_readiness.json"))
            .ok()
            .and_then(|bytes| serde_json::from_slice::<Value>(&bytes).ok())
            .unwrap_or_else(|| json!({"production_ready":false,"blockers":["READINESS_ABSENT"]}));
        let readiness_scopes = readiness_scopes_from_receipt(&readiness);
        let stream = fs::read(live_root.join("massive_stream_status.json"))
            .ok()
            .and_then(|bytes| serde_json::from_slice::<Value>(&bytes).ok())
            .unwrap_or_else(|| json!({"state":"UNAVAILABLE","blocker":"STREAM_STATUS_ABSENT"}));
        let stream_updated_at = stream
            .get("updated_at")
            .and_then(Value::as_str)
            .and_then(|raw| chrono::DateTime::parse_from_rfc3339(raw).ok())
            .map(|value| value.with_timezone(&chrono::Utc));
        let stream_age_ms =
            stream_updated_at.map(|updated| now.signed_duration_since(updated).num_milliseconds());
        let stream_fresh =
            stream_age_ms.is_some_and(|age| age >= 0 && age <= maximum_stream_status_age_ms);
        let verified = readiness_scopes.equity_realtime_ready
            && stream.get("state").and_then(Value::as_str) == Some("STREAMING_REALTIME")
            && stream
                .get("authenticated")
                .and_then(Value::as_bool)
                .unwrap_or(false)
            && !live_supervisor_blocker_present(&stream)
            && stream_fresh;
        (
            json!({
                "provider":"massive",
                "status":stream.get("state").cloned().unwrap_or(json!("UNAVAILABLE")),
                "checked_at":readiness.get("checked_at").cloned().unwrap_or(Value::Null),
                "updated_at":stream.get("updated_at").cloned().unwrap_or(Value::Null),
                "stream_age_ms":stream_age_ms,
                "equity_realtime_ready":readiness_scopes.equity_realtime_ready,
                "options_realtime_ready":readiness_scopes.options_realtime_ready,
                "production_ready":readiness_scopes.production_ready,
                "options_ready_by_underlying":readiness.get("options_ready_by_underlying").cloned().unwrap_or(Value::Null),
                "login_status":if stream.get("authenticated").and_then(Value::as_bool).unwrap_or(false) {
                    "REALTIME_WEBSOCKET_AUTHENTICATED"
                } else {
                    "UNVERIFIED"
                },
                "blocker":stream.get("blocker").cloned().unwrap_or_else(|| {
                    readiness.get("blockers").cloned().unwrap_or(Value::Null)
                })
            }),
            verified,
        )
    } else if state.config.live.provider == "databento" {
        let stream = fs::read(root.join("live/databento_stream_status.json"))
            .ok()
            .and_then(|bytes| serde_json::from_slice::<Value>(&bytes).ok())
            .unwrap_or_else(|| {
                json!({
                    "state":"UNAVAILABLE",
                    "blocker":"DATABENTO_STREAM_STATUS_ABSENT"
                })
            });
        let stream_updated_at = stream
            .get("updated_at")
            .and_then(Value::as_str)
            .and_then(|raw| chrono::DateTime::parse_from_rfc3339(raw).ok())
            .map(|value| value.with_timezone(&chrono::Utc));
        let stream_age_ms =
            stream_updated_at.map(|updated| now.signed_duration_since(updated).num_milliseconds());
        let stream_fresh =
            stream_age_ms.is_some_and(|age| age >= 0 && age <= maximum_stream_status_age_ms);
        let verified = stream.get("state").and_then(Value::as_str) == Some("STREAMING_REALTIME")
            && stream.get("authenticated").and_then(Value::as_bool) == Some(true)
            && stream.get("entitlement_verified").and_then(Value::as_bool) == Some(true)
            && stream.get("replay_requested").and_then(Value::as_bool) == Some(false)
            && stream.get("execution_enabled").and_then(Value::as_bool) == Some(false)
            && stream.get("blocker").is_none_or(Value::is_null)
            && stream_fresh;
        (
            json!({
                "provider":"databento",
                "status":stream.get("state").cloned().unwrap_or(json!("UNAVAILABLE")),
                "dataset":stream.get("dataset").cloned().unwrap_or(Value::Null),
                "schema":stream.get("schema").cloned().unwrap_or(Value::Null),
                "updated_at":stream.get("updated_at").cloned().unwrap_or(Value::Null),
                "stream_age_ms":stream_age_ms,
                "login_status":if verified {
                    "REALTIME_SUBSCRIPTION_ACKNOWLEDGED"
                } else {
                    "UNVERIFIED"
                },
                "blocker":stream.get("blocker").cloned().unwrap_or(Value::Null),
                "execution_enabled":false
            }),
            verified,
        )
    } else {
        let live_status_path = root.join("live/status.json");
        let feed = fs::read(&live_status_path)
            .ok()
            .and_then(|bytes| serde_json::from_slice::<Value>(&bytes).ok())
            .unwrap_or_else(|| {
                json!({
                    "status":"UNAVAILABLE",
                    "blocker":"LIVE_STATUS_ARTIFACT_ABSENT"
                })
            });
        let verified = feed.get("status").and_then(Value::as_str)
            == Some("CONNECTED_QUOTE_PROTOCOL_VERIFIED")
            && feed.get("login_status").and_then(Value::as_str)
                == Some("VERIFIED_BY_OFFICIAL_SDK_CALLBACK");
        (feed, verified)
    };

    if !live_feed_verified {
        exclusions.extend(candidates.iter().map(|candidate| {
            json!({
                "symbol":candidate.symbol,
                "reason":"LIVE_FEED_STATUS_NOT_FRESH_OR_VERIFIED"
            })
        }));
    }
    let ranked_candidates = project_public_scan_candidates(
        candidates,
        limit,
        &state.config.live.provider,
        live_feed_verified,
    );

    Ok(json!({
        "status":if live_feed_verified {
            "IMPERSONAL_REALTIME_RESEARCH_SCAN"
        } else {
            "LIVE_FEED_NOT_READY"
        },
        "generated_at":now,
        "horizon_minutes":horizon_minutes,
        "configured_universe":configured_symbols.values().collect::<Vec<_>>(),
        "configured_symbol_count":configured_symbols.len(),
        "fresh_qualifying_symbol_count":fresh_model_rows,
        "candidate_count_before_limit":candidate_count_before_limit,
        "validated_candidate_count":validated_candidate_count,
        "returned_candidate_count":ranked_candidates.len(),
        "coverage_status":coverage_status,
        "live_feed":{
            "verified":live_feed_verified,
            "status":live_feed.get("status").cloned().unwrap_or(json!("UNAVAILABLE")),
            "provider":live_feed.get("provider").cloned().unwrap_or_else(|| json!(state.config.live.provider)),
            "checked_at":live_feed.get("checked_at").cloned().unwrap_or(Value::Null),
            "login_status":live_feed.get("login_status").cloned().unwrap_or(json!("UNVERIFIED")),
            "blocker":live_feed.get("blocker").cloned().unwrap_or(Value::Null),
            "equity_realtime_ready":live_feed.get("equity_realtime_ready").cloned().unwrap_or(Value::Null),
            "options_realtime_ready":live_feed.get("options_realtime_ready").cloned().unwrap_or(Value::Null),
            "production_ready":live_feed.get("production_ready").cloned().unwrap_or(Value::Null),
            "options_ready_by_underlying":live_feed.get("options_ready_by_underlying").cloned().unwrap_or(Value::Null)
        },
        "freshness_policy":{
            "maximum_age_seconds":maximum_age_seconds,
            "future_timestamp_allowed":false,
            "stale_candidates_returned":false,
            "source_requirement":"AUTHENTICATED_REALTIME_PROVIDER_FINALIZED_1M_BAR"
        },
        "screening_thresholds":{
            "minimum_directional_probability_percent":percent(minimum_probability),
            "minimum_absolute_conditional_mean_bps":minimum_expected_return_bps,
            "include_unvalidated":include_unvalidated
        },
        "ranked_statistical_candidates":ranked_candidates,
        "exclusions":exclusions,
        "regime_model_committee":{
            "homogeneous_hmm":"CHRONOLOGICAL_STATE_COUNT_SELECTION_WITH_K8_CHALLENGER",
            "non_homogeneous_hmm_tvtp":current_tvtp_challenger_projection(root, now),
            "high_dimensional_kernel":"SAME_REGIME_CAUSAL_ANALOG_RETRIEVAL",
            "stochastic_process":"MARKOV_SWITCHING_LOG_RETURN_DIFFUSION_WITH_VWAP_RESIDUAL_OU",
            "martingale_optional_stopping":"MODEL_AUDIT_VETO_ONLY_NOT_ALPHA"
        },
        "arbitrage_semantics":"NOT_RISK_FREE_ARBITRAGE; DIRECTIONAL_OR_RELATIVE_STATISTICAL_CANDIDATES_REQUIRE_SEPARATE_EXECUTABLE_HEDGE_AND_COST_VALIDATION",
        "research_only_policy":{
            "product_scope":"IMPERSONAL_WHOLE_MARKET_STATISTICAL_RESEARCH",
            "personalization_used":false,
            "user_portfolio_inputs_used":false,
            "investment_advice":false,
            "execution_instruction":false,
            "guaranteed_profit_claim":false,
            "forced_opportunity_quota":false
        }
    }))
}

async fn research_opportunities(
    State(state): State<AppState>,
    Query(query): Query<OpportunityQuery>,
) -> Result<Json<Value>, ApiError> {
    Ok(Json(build_research_opportunity_scan(
        &state,
        query,
        chrono::Utc::now(),
    )?))
}

async fn research_scan(
    State(state): State<AppState>,
    Json(query): Json<MarketQuery>,
) -> Result<Json<EvidenceEnvelope>, ApiError> {
    if query.intent == MarketQueryIntent::Backtest {
        return Err(ApiError::unprocessable(
            "POST /v1/scan does not accept intent=backtest",
        ));
    }
    execute_research_query(state, query).await
}

async fn research_backtest_query(
    State(state): State<AppState>,
    Json(query): Json<MarketQuery>,
) -> Result<Json<EvidenceEnvelope>, ApiError> {
    if query.intent != MarketQueryIntent::Backtest {
        return Err(ApiError::unprocessable(
            "POST /v1/backtest/query requires intent=backtest",
        ));
    }
    execute_research_query(state, query).await
}

async fn research_query(
    State(state): State<AppState>,
    Json(query): Json<MarketQuery>,
) -> Result<Json<EvidenceEnvelope>, ApiError> {
    execute_research_query(state, query).await
}

fn model_contract_projection(root: &std::path::Path) -> Value {
    let frozen = fs::read(root.join("models/frozen_predictor_latest.json"))
        .ok()
        .and_then(|bytes| serde_json::from_slice::<Value>(&bytes).ok())
        .unwrap_or_else(|| json!({"status":"UNAVAILABLE"}));
    let candidate = fs::read(root.join("models/predictor_candidate_latest.json"))
        .ok()
        .and_then(|bytes| serde_json::from_slice::<Value>(&bytes).ok())
        .unwrap_or_else(|| json!({"status":"UNAVAILABLE"}));
    let universe = fs::read(root.join("models/universe/registry.json"))
        .ok()
        .and_then(|bytes| serde_json::from_slice::<Value>(&bytes).ok())
        .unwrap_or_else(|| {
            json!({
                "status":"UNAVAILABLE",
                "reason":"PER_TARGET_FROZEN_ARTIFACTS_NOT_MATERIALIZED"
            })
        });
    json!({
        "runtime_owner":"RUST",
        "artifact_version":frozen.get("artifact_version").cloned().unwrap_or(Value::Null),
        "artifact_sha256":frozen.get("artifact_sha256").cloned().unwrap_or(Value::Null),
        "model_version":frozen.get("model_version").cloned().unwrap_or(Value::Null),
        "model_hash":frozen.get("model_hash").cloned().unwrap_or(Value::Null),
        "feature_schema_version":frozen.get("feature_schema_version").cloned().unwrap_or(Value::Null),
        "feature_schema_sha256":frozen.get("feature_schema_sha256").cloned().unwrap_or(Value::Null),
        "training_cutoff":frozen.get("training_cutoff").cloned().unwrap_or(Value::Null),
        "candidate_status":candidate.get("status").cloned().unwrap_or(json!("UNAVAILABLE")),
        "evidence_grade":candidate.get("evidence_grade").cloned().unwrap_or(json!("UNAVAILABLE")),
        "promotion":candidate.get("promotion").cloned().unwrap_or(json!("UNAVAILABLE")),
        "universe_registry_schema":universe.get("schema_version").cloned().unwrap_or(Value::Null),
        "universe_registry_status":universe.get("status").cloned().unwrap_or(json!("UNAVAILABLE")),
        "target_artifacts":universe.get("entries").cloned().unwrap_or_else(|| json!([])),
        "probability_policy":"CALIBRATED_PROBABILITIES_REQUIRE_A_MATCHING_PROMOTED_OOS_ARTIFACT"
    })
}

fn generic_statistical_candidates(
    setup_type: MarketSetupType,
    scan: &Value,
    requested_symbols: &[String],
) -> Vec<ResearchCandidate> {
    scan.get("ranked_statistical_candidates")
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .filter(|row| {
            row.get("symbol")
                .and_then(Value::as_str)
                .is_some_and(|symbol| requested_symbols.iter().any(|wanted| wanted == symbol))
        })
        .map(|row| {
            let symbol = row
                .get("symbol")
                .and_then(Value::as_str)
                .unwrap_or("UNKNOWN")
                .to_string();
            let observed_at = parse_utc(row.get("observation_cutoff"));
            let available_at = parse_utc(row.get("latest_input_available_at"));
            let age_seconds = row.get("data_age_seconds").and_then(Value::as_i64);
            let validated = row
                .get("candidate_status")
                .and_then(Value::as_str)
                == Some("VALIDATED_STATISTICAL_CANDIDATE");
            let status = if validated {
                "VALIDATED_STATISTICAL_CANDIDATE"
            } else {
                "UNCALIBRATED_RESEARCH_OUTPUT"
            }
            .to_string();
            let provider = scan
                .pointer("/live_feed/provider")
                .and_then(Value::as_str)
                .unwrap_or("unknown");
            let source = row
                .get("data_source")
                .and_then(Value::as_str)
                .unwrap_or_else(|| public_realtime_source(provider))
                .to_string();
            let coverage = row
                .get("coverage")
                .and_then(Value::as_f64)
                .filter(|value| value.is_finite() && (0.0..=1.0).contains(value));
            let entitlement = row
                .get("entitlement")
                .and_then(Value::as_str)
                .unwrap_or("LICENSED_REALTIME_SHADOW_EVIDENCE_VERIFIED")
                .to_string();
            let orientation = row
                .get("statistical_orientation")
                .cloned()
                .unwrap_or(Value::Null);
            let publication_status = row
                .get("published_probability_status")
                .cloned()
                .unwrap_or_else(|| {
                    json!("WITHHELD_NO_MATCHING_PROMOTED_OOS_CALIBRATION")
                });
            let mut contrary_evidence = vec![EvidenceItem {
                code: if validated {
                    "NO_VALIDATED_ARBITRAGE_CLAIM"
                } else {
                    "PROBABILITY_AND_EXPECTED_MOVE_WITHHELD"
                }
                .to_string(),
                statement: if validated {
                    "This is a conditional statistical candidate; hedgeability and positive after-cost arbitrage were not established."
                } else {
                    "The frozen model ran, but no matching promoted OOS calibration exists; probability, expected move, ranking score, and execution remain withheld."
                }
                .to_string(),
                observed_value: Some(publication_status.clone()),
            }];
            if let Some(caveats) = row.get("caveats").and_then(Value::as_array) {
                contrary_evidence.extend(caveats.iter().filter_map(Value::as_str).map(|caveat| {
                    EvidenceItem {
                        code: "MATERIAL_DATA_CAVEAT".to_string(),
                        statement: caveat.to_string(),
                        observed_value: None,
                    }
                }));
            }
            let mut candidate = ResearchCandidate {
                symbol,
                setup_type,
                status,
                heuristic_structure_score: if validated {
                    row.get("research_rank_score").and_then(Value::as_f64)
                } else {
                    None
                },
                score_semantics: if validated {
                    "Validated native research rank; not a probability or trade instruction."
                        .to_string()
                } else {
                    "Uncalibrated native model condition; probability, expected move, rank, and trade fields are withheld."
                        .to_string()
                },
                supporting_evidence: vec![EvidenceItem {
                    code: "FRESH_NATIVE_FORECAST_CONTRACT".to_string(),
                    statement:
                        "Candidate passed the Rust forecast-contract causality and freshness gates."
                            .to_string(),
                    observed_value: Some(orientation.clone()),
                }],
                contrary_evidence,
                metrics: json!({
                    "horizon_minutes":row.get("horizon_minutes").cloned().unwrap_or(Value::Null),
                    "statistical_orientation":orientation,
                    "observation_cutoff":row.get("observation_cutoff").cloned().unwrap_or(Value::Null),
                    "latest_input_available_at":row.get("latest_input_available_at").cloned().unwrap_or(Value::Null),
                    "data_age_seconds":age_seconds,
                    "data_source":source,
                    "coverage":coverage,
                    "coverage_semantics":row.get("coverage_semantics").cloned().unwrap_or(Value::Null),
                    "caveats":row.get("caveats").cloned().unwrap_or_else(|| json!([])),
                    "published_probability_status":publication_status,
                    "probability_up_percent":if validated {
                        row.get("probability_up_percent").cloned().unwrap_or(Value::Null)
                    } else {
                        Value::Null
                    },
                    "validation":row.get("validation").cloned().unwrap_or_else(|| json!({})),
                    "interpretation":"Model-derived directional research condition only; not a calibrated probability, expected return, personalized recommendation, order, or guaranteed outcome."
                }),
                freshness: vec![crate::market_query::DataFreshness {
                    source,
                    observed_at,
                    available_at,
                    age_seconds,
                    realtime: true,
                    entitlement,
                    coverage,
                }],
            };
            if !validated
                && let Some(metrics) = candidate.metrics.as_object_mut()
            {
                metrics.remove("probability_up_percent");
            }
            candidate
        })
        .collect()
}

fn enforce_model_forecast_horizon_contract(
    query: &MarketQuery,
    configured_horizons: &[usize],
    candidates: &mut [ResearchCandidate],
    blockers: &mut Vec<String>,
) {
    if query.setup_type != MarketSetupType::ModelForecast {
        return;
    }
    let expected_horizons = query
        .horizon_minutes
        .map(|horizon| vec![horizon])
        .unwrap_or_else(|| configured_horizons.to_vec());
    for symbol in &query.symbols {
        for horizon in &expected_horizons {
            let count = candidates
                .iter()
                .filter(|candidate| {
                    candidate.symbol.eq_ignore_ascii_case(symbol)
                        && candidate
                            .metrics
                            .get("horizon_minutes")
                            .and_then(Value::as_u64)
                            == u64::try_from(*horizon).ok()
                })
                .count();
            if count == 0 {
                blockers.push(format!(
                    "{symbol}:MODEL_FORECAST_HORIZON_MISSING:horizon_minutes={horizon}"
                ));
            } else if count > 1 {
                blockers.push(format!(
                    "{symbol}:MODEL_FORECAST_HORIZON_DUPLICATE:horizon_minutes={horizon}"
                ));
            }
        }
    }
    for candidate in candidates.iter() {
        let horizon = candidate
            .metrics
            .get("horizon_minutes")
            .and_then(Value::as_u64)
            .and_then(|value| usize::try_from(value).ok());
        if !query
            .symbols
            .iter()
            .any(|symbol| candidate.symbol.eq_ignore_ascii_case(symbol))
            || horizon.is_none_or(|value| !expected_horizons.contains(&value))
        {
            blockers.push(format!(
                "{}:MODEL_FORECAST_UNEXPECTED_SYMBOL_OR_HORIZON:horizon_minutes={}",
                candidate.symbol,
                horizon
                    .map(|value| value.to_string())
                    .unwrap_or_else(|| "INVALID".to_string())
            ));
        }
    }
    candidates.sort_by(|left, right| {
        left.symbol.cmp(&right.symbol).then_with(|| {
            left.metrics
                .get("horizon_minutes")
                .and_then(Value::as_u64)
                .cmp(&right.metrics.get("horizon_minutes").and_then(Value::as_u64))
        })
    });
}

fn apply_research_candidate_shape(query: &MarketQuery, candidates: &mut Vec<ResearchCandidate>) {
    // A model-forecast request is atomic across every explicitly requested
    // symbol and horizon. `limit` ranks scans; it must not silently discard a
    // validated symbol/horizon pair after the completeness check.
    if query.setup_type != MarketSetupType::ModelForecast {
        candidates.truncate(query.limit);
    }
}

fn requested_statistical_exclusion_blockers(
    scan: &Value,
    requested_model_symbols: &[String],
    model_to_public: &BTreeMap<String, String>,
) -> Vec<String> {
    let requested = requested_model_symbols
        .iter()
        .map(|symbol| symbol.trim().trim_start_matches("US.").to_ascii_uppercase())
        .collect::<BTreeSet<_>>();
    let mut blockers = scan
        .get("exclusions")
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .filter_map(|row| {
            let model_symbol = row
                .get("symbol")
                .and_then(Value::as_str)?
                .trim()
                .trim_start_matches("US.")
                .to_ascii_uppercase();
            if !requested.contains(&model_symbol) {
                return None;
            }
            let reason = row.get("reason").and_then(Value::as_str)?.trim();
            if reason.is_empty() {
                return None;
            }
            let public_symbol = model_to_public
                .get(&model_symbol)
                .cloned()
                .unwrap_or_else(|| model_symbol.clone());
            Some(format!("{public_symbol}:{reason}"))
        })
        .collect::<Vec<_>>();
    blockers.sort();
    blockers.dedup();
    blockers
}

fn persist_research_query_audit(
    root: &std::path::Path,
    envelope: &EvidenceEnvelope,
) -> Result<(), ApiError> {
    let path = root.join("state/research_query_audit.jsonl");
    crate::live::append_jsonl(
        &path,
        &json!({
            "schema_version":"axio.market-query-audit.v1",
            "request_id":envelope.request_id,
            "generated_at":envelope.generated_at,
            "observation_cutoff":envelope.observation_cutoff,
            "query_sha256":envelope.query_sha256,
            "response_sha256":envelope.response_sha256,
            "status":envelope.status,
            "setup_type":envelope.query.setup_type,
            "symbols":envelope.query.symbols,
            "candidate_count":envelope.candidates.len(),
            "historical_result_count":envelope.historical.len(),
            "data_blockers":envelope.data_blockers,
            "execution_instruction":false
        }),
    )
    .map_err(ApiError::internal)
}

async fn execute_research_query(
    state: AppState,
    query: MarketQuery,
) -> Result<Json<EvidenceEnvelope>, ApiError> {
    let query = query
        .normalize_and_validate()
        .map_err(ApiError::unprocessable)?;
    let unsupported = query
        .symbols
        .iter()
        .filter(|symbol| {
            !state
                .config
                .research
                .targets
                .iter()
                .any(|target| target.public_symbol.eq_ignore_ascii_case(symbol))
        })
        .cloned()
        .collect::<Vec<_>>();
    if !unsupported.is_empty() {
        return Err(ApiError::unprocessable(format!(
            "symbols outside the configured research universe: {}",
            unsupported.join(",")
        )));
    }
    if state.config.execution.enabled
        || state.config.execution.allow_real_orders
        || state.config.live.allow_trade_api
    {
        return Err(ApiError::conflict(
            "research query service refuses to run while any execution path is enabled",
        ));
    }
    let generated_at = Utc::now();
    let observation_cutoff = query.as_of.unwrap_or(generated_at);
    let query_sha256 = query.canonical_sha256().map_err(ApiError::internal)?;
    let root = state
        .config
        .data
        .raw_root
        .parent()
        .unwrap_or(std::path::Path::new("data"))
        .to_path_buf();
    let mut candidates = Vec::new();
    let mut exclusions = Vec::new();
    let mut historical = Vec::new();
    let readiness = production_readiness_receipt(&state);
    let live_result_requested = query.intent != MarketQueryIntent::Backtest;
    let mut data_blockers = if live_result_requested {
        public_observation_readiness_blockers(&state.config.live.provider, &readiness)
    } else {
        Vec::new()
    };
    let probability_publication_blockers = probability_publication_readiness_blockers(&readiness);
    let probability_publication_ready = probability_publication_blockers.is_empty();
    let public_observation_ready = live_result_requested && data_blockers.is_empty();
    if live_result_requested && !public_observation_ready {
        exclusions.extend(query.symbols.iter().map(|symbol| {
            json!({
                "symbol":symbol,
                "reason":"PUBLIC_REALTIME_OBSERVATION_READINESS_BLOCKED"
            })
        }));
    }

    if query.intent != MarketQueryIntent::Backtest && public_observation_ready {
        match query.setup_type {
            MarketSetupType::GammaSqueeze => {
                let readiness = fs::read(root.join("live/massive_readiness.json"))
                    .ok()
                    .and_then(|bytes| serde_json::from_slice::<Value>(&bytes).ok());
                if readiness
                    .as_ref()
                    .and_then(|value| value.get("production_ready"))
                    .and_then(Value::as_bool)
                    != Some(true)
                {
                    let blockers = readiness
                        .as_ref()
                        .and_then(|value| value.get("blockers"))
                        .and_then(Value::as_array)
                        .map(|values| {
                            values
                                .iter()
                                .filter_map(Value::as_str)
                                .take(8)
                                .collect::<Vec<_>>()
                                .join(" | ")
                        })
                        .filter(|value| !value.is_empty())
                        .unwrap_or_else(|| "MASSIVE_REALTIME_READINESS_RECEIPT_ABSENT".to_string());
                    data_blockers.push(format!("REALTIME_SIP_OPRA_READINESS_FAILED:{blockers}"));
                }
                for symbol in query.symbols.iter().take(query.limit) {
                    let target = state
                        .config
                        .research
                        .targets
                        .iter()
                        .find(|target| target.public_symbol.eq_ignore_ascii_case(symbol))
                        .expect("validated configured target");
                    let options_underlying = &target.options_underlying;
                    let path = state
                        .config
                        .data
                        .massive
                        .option_chain_output_root
                        .join(format!(
                            "{}_full_chain_latest.json",
                            options_underlying.to_ascii_lowercase()
                        ));
                    match gamma_structure_candidate(
                        &path,
                        &query,
                        options_underlying,
                        observation_cutoff,
                        state.config.data.massive.option_chain_min_quote_coverage,
                    ) {
                        Ok(mut candidate) => {
                            candidate.symbol = symbol.clone();
                            candidate.supporting_evidence.push(EvidenceItem {
                                code: "EXPLICIT_TARGET_MAPPING".to_string(),
                                statement: format!(
                                    "Public target {symbol} uses option-chain root {options_underlying}; no alias was inferred at request time."
                                ),
                                observed_value: Some(json!({
                                    "public_symbol":symbol,
                                    "options_underlying":options_underlying,
                                    "price_symbol":target.price_symbol
                                })),
                            });
                            candidates.push(candidate);
                        }
                        Err(reason) => {
                            data_blockers.push(format!("{symbol}:{reason}"));
                            exclusions.push(json!({"symbol":symbol,"reason":reason}));
                        }
                    }
                }
                candidates.sort_by(|left, right| {
                    right
                        .heuristic_structure_score
                        .unwrap_or_default()
                        .total_cmp(&left.heuristic_structure_score.unwrap_or_default())
                        .then_with(|| left.symbol.cmp(&right.symbol))
                });
            }
            MarketSetupType::Momentum
            | MarketSetupType::OpeningTurn
            | MarketSetupType::VwapReversal => {
                let bars_path = if state.config.live.provider == "massive" {
                    root.join("live/massive_stock_bars.jsonl")
                } else if state.config.live.provider == "databento" {
                    root.join("live/databento_stock_bars.jsonl")
                } else {
                    root.join("live/finalized_bars.jsonl")
                };
                for symbol in query.symbols.iter().take(query.limit) {
                    let target = state
                        .config
                        .research
                        .targets
                        .iter()
                        .find(|target| target.public_symbol.eq_ignore_ascii_case(symbol))
                        .expect("validated configured target");
                    match live_vwap_candidate(
                        &bars_path,
                        &query,
                        &target.vwap_volume_source,
                        observation_cutoff,
                        state.config.live.stale_after_ms,
                    ) {
                        Ok(mut candidate) => {
                            candidate.symbol = symbol.clone();
                            candidate.supporting_evidence.push(EvidenceItem {
                                code: "EXPLICIT_VWAP_SOURCE_MAPPING".to_string(),
                                statement: format!(
                                    "Public target {symbol} uses {} for causal volume and VWAP.",
                                    target.vwap_volume_source
                                ),
                                observed_value: Some(json!({
                                    "public_symbol":symbol,
                                    "vwap_volume_source":target.vwap_volume_source,
                                    "target_status":target.target_status
                                })),
                            });
                            candidates.push(candidate);
                        }
                        Err(reason) => {
                            data_blockers.push(format!("{symbol}:{reason}"));
                            exclusions.push(json!({"symbol":symbol,"reason":reason}));
                        }
                    }
                }
            }
            MarketSetupType::ModelForecast | MarketSetupType::StatisticalDislocation => {
                let requested_model_symbols = query
                    .symbols
                    .iter()
                    .filter_map(|symbol| {
                        state
                            .config
                            .research
                            .targets
                            .iter()
                            .find(|target| target.public_symbol.eq_ignore_ascii_case(symbol))
                            .map(|target| target.model_symbol.clone())
                    })
                    .collect::<Vec<_>>();
                let model_to_public = state
                    .config
                    .research
                    .targets
                    .iter()
                    .map(|target| {
                        (
                            target.model_symbol.to_ascii_uppercase(),
                            target.public_symbol.clone(),
                        )
                    })
                    .collect::<BTreeMap<_, _>>();
                let requested_horizons = query
                    .horizon_minutes
                    .map(|horizon| vec![horizon])
                    .unwrap_or_else(|| state.config.research.horizons.clone());
                for horizon_minutes in requested_horizons {
                    let scan = build_research_opportunity_scan(
                        &state,
                        OpportunityQuery {
                            horizon_minutes: Some(horizon_minutes),
                            // The opportunity endpoint ranks the whole configured
                            // universe before applying its limit. A direct-symbol
                            // research request must therefore retain the full
                            // universe here and filter to the requested symbols
                            // below; otherwise NVDA can disappear merely because
                            // another symbol ranked above it.
                            limit: Some(state.config.live.forecast_symbols.len().clamp(1, 20)),
                            include_unvalidated: Some(true),
                            maximum_age_seconds: Some(query.filters.max_data_age_seconds),
                        },
                        observation_cutoff,
                    )?;
                    let mut horizon_candidates = generic_statistical_candidates(
                        query.setup_type,
                        &scan,
                        &requested_model_symbols,
                    );
                    for candidate in &mut horizon_candidates {
                        if let Some(target) = state.config.research.targets.iter().find(|target| {
                            target.model_symbol.eq_ignore_ascii_case(&candidate.symbol)
                        }) {
                            candidate.symbol = target.public_symbol.clone();
                            candidate.supporting_evidence.push(EvidenceItem {
                                code: "EXPLICIT_MODEL_SYMBOL_MAPPING".to_string(),
                                statement: format!(
                                    "Public target {} is backed by frozen model symbol {}.",
                                    target.public_symbol, target.model_symbol
                                ),
                                observed_value: Some(json!({
                                    "public_symbol":target.public_symbol,
                                    "model_symbol":target.model_symbol,
                                    "target_status":target.target_status
                                })),
                            });
                        }
                    }
                    if let Some(rows) = scan.get("exclusions").and_then(Value::as_array) {
                        exclusions.extend(rows.iter().cloned());
                    }
                    let requested_blockers = requested_statistical_exclusion_blockers(
                        &scan,
                        &requested_model_symbols,
                        &model_to_public,
                    );
                    if horizon_candidates.is_empty() {
                        if requested_blockers.is_empty() {
                            data_blockers.push(format!(
                                "REALTIME_FORECAST_NOT_READY:horizon_minutes={horizon_minutes}"
                            ));
                        }
                    } else if scan.get("status").and_then(Value::as_str)
                        != Some("IMPERSONAL_REALTIME_RESEARCH_SCAN")
                    {
                        data_blockers.push(
                            "REALTIME_FORECAST_UNIVERSE_NOT_READY_OR_NO_FRESH_CANDIDATES"
                                .to_string(),
                        );
                    }
                    data_blockers.extend(requested_blockers);
                    candidates.extend(horizon_candidates);
                }
            }
            MarketSetupType::ClosingShortCover => {
                data_blockers.push(
                    "CLOSING_SHORT_COVER_SCANNER_IS_SHADOW_ONLY_AND_NOT_PROMOTED_FOR_PUBLIC_RANKING"
                        .to_string(),
                );
                exclusions.extend(query.symbols.iter().map(|symbol| {
                    json!({
                        "symbol":symbol,
                        "reason":"SETUP_SCANNER_NOT_PROMOTED; native hazard remains available only inside validated forecast contracts"
                    })
                }));
            }
        }
    }

    if query.filters.include_historical
        && matches!(
            query.setup_type,
            MarketSetupType::OpeningTurn
                | MarketSetupType::VwapReversal
                | MarketSetupType::Momentum
                | MarketSetupType::StatisticalDislocation
        )
    {
        let bars_path = state.config.data.normalized_root.join("market_bars.csv");
        let symbols = query
            .symbols
            .iter()
            .map(|symbol| {
                let target = state
                    .config
                    .research
                    .targets
                    .iter()
                    .find(|target| target.public_symbol.eq_ignore_ascii_case(symbol))
                    .expect("validated configured target");
                (symbol.clone(), target.vwap_volume_source.clone())
            })
            .collect::<Vec<_>>();
        let setup_type = query.setup_type;
        let direction = query.filters.direction.ok_or_else(|| {
            ApiError::unprocessable(
                "direction is required when an explicit historical rule replay is requested",
            )
        })?;
        let horizon_minutes = query.horizon_minutes.ok_or_else(|| {
            ApiError::unprocessable(
                "horizon_minutes is required when an explicit historical rule replay is requested",
            )
        })?;
        let cutoff = query.as_of;
        let assumed_round_trip_cost_bps =
            2.0 * state.config.os.spread_bps + 2.0 * state.config.os.slippage_bps;
        let rows = tokio::task::spawn_blocking(move || {
            symbols
                .into_iter()
                .map(|(public_symbol, data_symbol)| {
                    let result = historical_setup_stats(
                        &bars_path,
                        &data_symbol,
                        setup_type,
                        direction,
                        horizon_minutes,
                        cutoff,
                        assumed_round_trip_cost_bps,
                    );
                    (public_symbol, data_symbol, result)
                })
                .collect::<Vec<_>>()
        })
        .await
        .map_err(ApiError::internal)?;
        for (symbol, data_symbol, result) in rows {
            match result {
                Ok(mut stats) => {
                    stats.symbol = symbol.clone();
                    if symbol != data_symbol {
                        stats.caveats.push(format!(
                            "{symbol} historical VWAP/volume research uses the explicit {data_symbol} proxy."
                        ));
                    }
                    historical.push(stats);
                }
                Err(error) => {
                    let reason = format!("HISTORICAL_QUERY_FAILED:{error}");
                    data_blockers.push(format!("{symbol}:{reason}"));
                    exclusions.push(json!({"symbol":symbol,"reason":reason}));
                }
            }
        }
    }

    apply_research_candidate_shape(&query, &mut candidates);
    enforce_model_forecast_horizon_contract(
        &query,
        &state.config.research.horizons,
        &mut candidates,
        &mut data_blockers,
    );
    data_blockers.sort();
    data_blockers.dedup();
    if !data_blockers.is_empty() {
        candidates.clear();
    }
    let uncalibrated_candidate_present = candidates
        .iter()
        .any(|candidate| candidate.status == "UNCALIBRATED_RESEARCH_OUTPUT");
    let status = if !data_blockers.is_empty() && historical.is_empty() {
        "DATA_UNAVAILABLE"
    } else if !data_blockers.is_empty() {
        "PARTIAL"
    } else if uncalibrated_candidate_present {
        "UNCALIBRATED_RESEARCH_OUTPUT"
    } else if !candidates.is_empty() || !historical.is_empty() {
        "AVAILABLE"
    } else {
        "DATA_UNAVAILABLE"
    };
    let mut model_contract = model_contract_projection(&root);
    if let Some(contract) = model_contract.as_object_mut() {
        contract.insert(
            "probability_publication_ready".into(),
            json!(probability_publication_ready),
        );
        contract.insert(
            "probability_publication_blockers".into(),
            json!(probability_publication_blockers),
        );
    }
    let mut caveats = vec![
        "No candidate is an order, personalized recommendation, or guaranteed outcome.".to_string(),
    ];
    match query.setup_type {
        MarketSetupType::GammaSqueeze => {
            caveats.push(
                "A gamma structure score is a deterministic research heuristic, not a squeeze probability."
                    .to_string(),
            );
            caveats.push(
                "Dealer position sign, opening/closing trade intent, OTC inventory, and complex-order net direction are not directly observed."
                    .to_string(),
            );
        }
        MarketSetupType::ModelForecast | MarketSetupType::StatisticalDislocation => {
            caveats.push(
                "UNCALIBRATED_RESEARCH_OUTPUT exposes only a fresh model-derived condition; probability, expected move, ranking score, and execution fields remain withheld."
                    .to_string(),
            );
            if query.setup_type == MarketSetupType::ModelForecast && query.horizon_minutes.is_none()
            {
                caveats.push(
                    "A neutral model forecast is atomic across every configured horizon; if any requested horizon is absent, duplicated, stale, or incompatible, the complete result is withheld."
                        .to_string(),
                );
            }
        }
        MarketSetupType::Momentum
        | MarketSetupType::OpeningTurn
        | MarketSetupType::VwapReversal
        | MarketSetupType::ClosingShortCover => {
            caveats.push(
                "A deterministic completed-bar condition is research context, not a calibrated forecast probability."
                    .to_string(),
            );
        }
    }
    let pipeline_readiness = research_pipeline_readiness(&state, &query, &readiness, &candidates);
    let mut envelope = EvidenceEnvelope {
        schema_version: EVIDENCE_ENVELOPE_SCHEMA_VERSION.to_string(),
        request_id: Uuid::new_v4().to_string(),
        query_sha256,
        response_sha256: None,
        generated_at,
        observation_cutoff,
        status: status.to_string(),
        query,
        candidates,
        exclusions,
        historical,
        data_blockers,
        readiness: pipeline_readiness,
        model_contract,
        research_only_policy: json!({
            "product_scope":"IMPERSONAL_WHOLE_MARKET_STATISTICAL_RESEARCH",
            "personalization_used":false,
            "user_portfolio_inputs_used":false,
            "investment_advice":false,
            "execution_instruction":false,
            "automatic_order_execution":false,
            "arbitrage_claim_policy":"ONLY_SIMULTANEOUSLY_HEDGEABLE_POSITIVE_AFTER_COST_DISCREPANCIES_MAY_BE_CALLED_ARBITRAGE",
            "public_market_data_rights":{
                "status":readiness.market_data.public_use_rights.status,
                "reason":readiness.market_data.public_use_rights.reason
            }
        }),
        caveats,
    };
    envelope.seal().map_err(ApiError::internal)?;
    persist_research_query_audit(&root, &envelope)?;
    Ok(Json(envelope))
}

const PUBLIC_RESEARCH_FORBIDDEN_KEYS: [&str; 16] = [
    "action",
    "eligible",
    "suggested_direction",
    "strategy_win_probability",
    "expected_edge_after_cost",
    "side",
    "qty",
    "quantity",
    "order",
    "order_type",
    "position_size",
    "target_weight",
    "target_notional",
    "stop_loss",
    "target_price",
    "legs",
];

fn strip_advice_and_execution_fields(value: &mut Value) {
    match value {
        Value::Object(object) => {
            object.retain(|key, _| !PUBLIC_RESEARCH_FORBIDDEN_KEYS.contains(&key.as_str()));
            for child in object.values_mut() {
                strip_advice_and_execution_fields(child);
            }
        }
        Value::Array(values) => {
            for child in values {
                strip_advice_and_execution_fields(child);
            }
        }
        _ => {}
    }
}

/// Public/consumer projection of an internal shadow forecast. It exposes
/// distributions and validation state, never a side, order, position size, or
/// account-specific conclusion.
fn public_research_forecast_projection(mut payload: Value) -> Value {
    let is_v44 = payload
        .get("forecast_contract_version")
        .and_then(Value::as_str)
        == Some("4.4");
    if let Some(rows) = payload
        .get_mut("prediction_layer")
        .and_then(Value::as_array_mut)
    {
        for row in rows {
            let validation_flags = row
                .pointer("/decision/no_trade_reasons")
                .cloned()
                .unwrap_or_else(|| json!([]));
            let expected_return = row
                .get("expected_return")
                .and_then(Value::as_f64)
                .unwrap_or_default();
            let statistical_condition = if expected_return > 0.0 {
                "POSITIVE_CONDITIONAL_MEAN"
            } else if expected_return < 0.0 {
                "NEGATIVE_CONDITIONAL_MEAN"
            } else {
                "NO_DIRECTIONAL_ASYMMETRY"
            };
            let calibrated_up = promoted_probability_up_for_publication(row);
            let validated = calibrated_up.is_some()
                && validation_flags
                    .as_array()
                    .is_some_and(|flags| flags.is_empty());
            if let Some(object) = row.as_object_mut() {
                if is_v44 {
                    object.insert("expected_price".into(), Value::Null);
                }
                object.insert(
                    "p_up".into(),
                    calibrated_up.map_or(Value::Null, Value::from),
                );
                object.insert("p_down".into(), Value::Null);
                object.insert("p_flat".into(), Value::Null);
                object.insert(
                    "published_probability_status".into(),
                    json!(if calibrated_up.is_some() {
                        "PROMOTED_BINARY_UP_ONLY_NO_JOINT_MULTICLASS_CALIBRATION"
                    } else {
                        "WITHHELD_NO_MATCHING_PROMOTED_OOS_CALIBRATION"
                    }),
                );
                object.insert("validation_flags".into(), validation_flags);
                object.insert(
                    "research_status".into(),
                    json!(if validated {
                        "VALIDATED_STATISTICAL_CONDITION"
                    } else {
                        "NO_VALIDATED_EDGE"
                    }),
                );
                object.insert("statistical_condition".into(), json!(statistical_condition));
                object.insert("personalization_used".into(), json!(false));
                object.insert("execution_eligible".into(), json!(false));
            }
        }
    }
    if let Some(object) = payload.as_object_mut() {
        object.remove("option_execution_layer");
        object.insert("status".into(), json!("IMPERSONAL_MARKET_RESEARCH"));
        object.insert(
            "research_only_policy".into(),
            json!({
                "product_scope": "IMPERSONAL_WHOLE_MARKET_STATISTICAL_RESEARCH",
                "personalization_used": false,
                "user_portfolio_inputs_used": false,
                "investment_advice": false,
                "execution_instruction": false,
                "disclaimer": "Mathematical market research only; not personalized investment advice, an order, or an execution instruction."
            }),
        );
    }
    strip_advice_and_execution_fields(&mut payload);
    payload
}

fn withhold_owner_probability_fields(payload: &mut Value) {
    let Some(rows) = payload
        .get_mut("prediction_layer")
        .and_then(Value::as_array_mut)
    else {
        return;
    };
    for row in rows {
        if let Some(object) = row.as_object_mut() {
            for key in ["p_up", "p_down", "p_flat", "calibrated_probability_up"] {
                object.insert(key.into(), Value::Null);
            }
        }
        if let Some(runtime) = row
            .get_mut("probability_calibration")
            .and_then(Value::as_object_mut)
        {
            for key in [
                "artifact_id",
                "method",
                "calibrated_probability_up",
                "calibrated_probability_up_interval",
                "oos_metrics",
            ] {
                runtime.insert(key.into(), Value::Null);
            }
            runtime.insert("eligible_for_probability_use".into(), json!(false));
        }
    }
}

async fn predictor_forecast(
    State(state): State<AppState>,
    Query(query): Query<ForecastQuery>,
) -> Result<Json<Value>, ApiError> {
    let root = state
        .config
        .data
        .raw_root
        .parent()
        .unwrap_or(std::path::Path::new("data"));
    let canonical = query
        .symbol
        .as_deref()
        .unwrap_or("SPY")
        .trim()
        .trim_start_matches("US.")
        .to_ascii_uppercase();
    let expected_symbols = configured_live_forecast_symbols(&state.config);
    if !expected_symbols.contains(&canonical) {
        return Err(ApiError::unprocessable(format!(
            "unsupported live forecast symbol: {canonical}"
        )));
    }
    let forecast_snapshot = CustomerLiveForecastSnapshot::load(
        root,
        &state.config.live.provider,
        &expected_symbols,
        state.config.live.forecast_symbols.len(),
    );
    match forecast_snapshot
        .as_ref()
        .map_err(|reason| *reason)
        .and_then(|snapshot| snapshot.payload(root, &canonical))
    {
        Ok(Some(payload)) => {
            match validate_live_forecast_bundle(
                &payload,
                &state.config.live.provider,
                &canonical,
                &state.config.research.horizons,
                chrono::Utc::now(),
                state.config.os.freshness_limit_seconds,
            ) {
                Ok(validation) => {
                    let mut live_payload = payload;
                    let mut excluded_non_live_horizons = Vec::new();
                    if let Some(rows) = live_payload
                        .get_mut("prediction_layer")
                        .and_then(Value::as_array_mut)
                    {
                        for row in rows.iter() {
                            if row.get("evidence_kind").and_then(Value::as_str)
                                != Some("live_shadow_prediction")
                                && let Some(horizon) =
                                    row.get("horizon_minutes").and_then(Value::as_u64)
                            {
                                excluded_non_live_horizons.push(horizon);
                            }
                        }
                        rows.retain(|row| {
                            row.get("evidence_kind").and_then(Value::as_str)
                                == Some("live_shadow_prediction")
                        });
                    }
                    let mut projected = public_research_forecast_projection(live_payload);
                    if let Some(object) = projected.as_object_mut() {
                        object.insert("served_at".into(), json!(chrono::Utc::now()));
                        object.insert("freshness_status".into(), json!("FRESH"));
                        object.insert(
                            "maximum_forecast_age_seconds".into(),
                            json!(validation.maximum_forecast_age_seconds),
                        );
                        object.insert(
                            "excluded_non_live_horizons".into(),
                            json!(excluded_non_live_horizons),
                        );
                    }
                    return Ok(Json(projected));
                }
                Err(validation_flags) => {
                    let readiness = production_readiness_receipt(&state);
                    return Ok(Json(json!({
                        "status":"STALE_OR_INCOMPATIBLE_LIVE_ARTIFACT",
                        "symbol":canonical,
                        "served_at":chrono::Utc::now(),
                        "freshness_status":"REJECTED",
                        "prediction_layer":[],
                        "validation_flags":validation_flags,
                        "live_inference":target_inference_projection(&readiness, &canonical),
                        "research_only_policy":{
                            "product_scope":"IMPERSONAL_WHOLE_MARKET_STATISTICAL_RESEARCH",
                            "personalization_used":false,
                            "user_portfolio_inputs_used":false,
                            "investment_advice":false,
                            "execution_instruction":false
                        },
                        "truth":"A legacy, stale, non-causal, incomplete, or untraceable artifact is never served as a live forecast."
                    })));
                }
            }
        }
        Err(reason) => {
            let readiness = production_readiness_receipt(&state);
            return Ok(Json(json!({
                "status":"LIVE_FORECAST_ARTIFACT_REJECTED",
                "symbol":canonical,
                "served_at":chrono::Utc::now(),
                "freshness_status":"REJECTED",
                "prediction_layer":[],
                "validation_flags":[reason],
                "live_inference":target_inference_projection(&readiness, &canonical),
                "research_only_policy":{
                    "product_scope":"IMPERSONAL_WHOLE_MARKET_STATISTICAL_RESEARCH",
                    "personalization_used":false,
                    "user_portfolio_inputs_used":false,
                    "investment_advice":false,
                    "execution_instruction":false
                }
            })));
        }
        Ok(None) => {}
    }
    let readiness = production_readiness_receipt(&state);
    Ok(Json(json!({
        "status":"LIVE_FORECAST_NOT_PUBLISHED",
        "symbol":canonical,
        "prediction_layer":[],
        "live_inference":target_inference_projection(&readiness, &canonical),
        "research_only_policy":{
            "product_scope":"IMPERSONAL_WHOLE_MARKET_STATISTICAL_RESEARCH",
            "personalization_used":false,
            "user_portfolio_inputs_used":false,
            "investment_advice":false,
            "execution_instruction":false
        },
        "truth":"No authoritative forecast-and-receipt pair is available. Replay and fixture forecasts are excluded from the live endpoint."
    })))
}

async fn predictor_owner_preview(
    State(state): State<AppState>,
    Query(query): Query<ForecastQuery>,
) -> Result<Json<Value>, ApiError> {
    let canonical = query
        .symbol
        .as_deref()
        .unwrap_or("SPY")
        .trim()
        .trim_start_matches("US.")
        .to_ascii_uppercase();
    let configured = state.config.live.forecast_symbols.iter().any(|symbol| {
        symbol
            .trim_start_matches("US.")
            .eq_ignore_ascii_case(&canonical)
    });
    if !configured || !canonical.chars().all(|value| value.is_ascii_alphanumeric()) {
        return Err(ApiError::unprocessable(format!(
            "unsupported owner forecast symbol: {canonical}"
        )));
    }
    let root = data_root(&state);
    let Some(stored) = crate::data::moomoo_forecast_relay::read_owner_forecast(&root, &canonical)
        .map_err(ApiError::internal)?
    else {
        return Ok(Json(json!({
            "status":"AWAITING_OWNER_MOOMOO_FORECAST",
            "symbol":canonical,
            "prediction_layer":[],
            "owner_only":true,
            "customer_publication_authorized":false,
            "execution_enabled":false,
            "truth":"Start the loopback Moomoo OpenD quote bridge and owner relay, or publish a deterministic historical replay."
        })));
    };
    let now = Utc::now();
    let policy = moomoo_owner_forecast_policy(&state)?;
    let validation =
        crate::data::moomoo_forecast_relay::validate_owner_forecast(&stored.forecast, now, &policy);
    let receipt = match validation {
        Ok(receipt)
            if receipt.payload_sha256 == stored.receipt.payload_sha256
                && receipt.symbol == stored.receipt.symbol
                && receipt.model_hash == stored.receipt.model_hash
                && receipt.mode == stored.receipt.mode =>
        {
            receipt
        }
        _ => {
            return Ok(Json(json!({
                "status":"OWNER_PREVIEW_STALE_OR_REJECTED",
                "symbol":canonical,
                "prediction_layer":[],
                "owner_only":true,
                "customer_publication_authorized":false,
                "execution_enabled":false,
                "truth":"The stored owner preview failed its freshness, causality, lineage, or exact-model validation and was withheld."
            })));
        }
    };
    if receipt.mode == crate::data::moomoo_forecast_relay::OwnerForecastMode::LiveForwardShadow {
        let payload = serde_json::to_value(&stored.forecast).map_err(ApiError::internal)?;
        if let Err(reasons) = validate_live_forecast_bundle(
            &payload,
            "moomoo",
            &canonical,
            &state.config.research.horizons,
            now,
            state.config.os.freshness_limit_seconds,
        ) {
            return Ok(Json(json!({
                "status":"OWNER_PREVIEW_STALE_OR_REJECTED",
                "symbol":canonical,
                "prediction_layer":[],
                "validation_flags":reasons,
                "owner_only":true,
                "customer_publication_authorized":false,
                "execution_enabled":false
            })));
        }
    }
    let mut projected = public_research_forecast_projection(
        serde_json::to_value(&stored.forecast).map_err(ApiError::internal)?,
    );
    withhold_owner_probability_fields(&mut projected);
    if let Some(object) = projected.as_object_mut() {
        object.insert("status".into(), json!(receipt.status));
        object.insert("symbol".into(), json!(canonical));
        object.insert("preview_mode".into(), json!(receipt.mode));
        object.insert("owner_only".into(), json!(true));
        object.insert("customer_publication_authorized".into(), json!(false));
        object.insert("public_redistribution_authorized".into(), json!(false));
        object.insert("execution_enabled".into(), json!(false));
        object.insert(
            "probability_publication_status".into(),
            json!(receipt.probability_publication_status),
        );
        object.insert("received_at".into(), json!(stored.receipt.received_at));
        object.insert(
            "observation_cutoff".into(),
            json!(receipt.observation_cutoff),
        );
        object.insert(
            "observation_age_seconds".into(),
            json!(
                now.signed_duration_since(receipt.observation_cutoff)
                    .num_seconds()
                    .max(0)
            ),
        );
        object.insert(
            "freshness_status".into(),
            json!(match receipt.mode {
                crate::data::moomoo_forecast_relay::OwnerForecastMode::LiveForwardShadow =>
                    "FRESH_LIVE_FORWARD_SHADOW",
                crate::data::moomoo_forecast_relay::OwnerForecastMode::DeterministicReplay =>
                    "HISTORICAL_REPLAY_NOT_LIVE",
            }),
        );
        object.insert(
            "truth".into(),
            json!("Owner-only unpromoted shadow research. Directional probabilities and execution remain withheld; a historical replay is not live evidence."),
        );
    }
    Ok(Json(projected))
}

async fn predictor_model(State(state): State<AppState>) -> Result<Json<Value>, ApiError> {
    Ok(Json(read_json_if_present(
        &state
            .config
            .data
            .raw_root
            .parent()
            .unwrap_or(std::path::Path::new("data"))
            .join("models/predictor_candidate_latest.json"),
    )?))
}

async fn predictor_walk_forward(State(state): State<AppState>) -> Result<Json<Value>, ApiError> {
    let root = state
        .config
        .data
        .raw_root
        .parent()
        .unwrap_or(std::path::Path::new("data"));
    let split_contract =
        read_json_if_present(&root.join("reports/walk_forward_contract_latest.json"))?;
    let evaluation = read_json_if_present(&root.join("reports/negative_controls_latest.json"))?;
    Ok(Json(json!({
        "status": evaluation.get("status").cloned().unwrap_or(json!("UNAVAILABLE")),
        "split_contract": split_contract,
        "evaluation": evaluation
    })))
}

async fn predictor_calibration(State(state): State<AppState>) -> Result<Json<Value>, ApiError> {
    let root = state
        .config
        .data
        .raw_root
        .parent()
        .unwrap_or(std::path::Path::new("data"));
    let value = read_json_if_present(&root.join("reports/forecast_contract_latest.json"))?;
    let validation = read_json_if_present(&root.join("reports/negative_controls_latest.json"))?;
    let rows = value
        .get("prediction_layer")
        .and_then(Value::as_array)
        .map(|rows| {
            rows.iter()
                .map(|row| {
                    json!({
                        "horizon":row.get("horizon_minutes"),
                        "status":row.get("calibration_status"),
                        "raw_analog_up_frequency":row.get("raw_analog_up_frequency"),
                        "raw_analog_down_frequency":row.get("raw_analog_down_frequency"),
                        "raw_analog_flat_frequency":row.get("raw_analog_flat_frequency"),
                        "raw_direction_probability_intervals":row.pointer("/kernel_regression/direction_probability_intervals"),
                        "calibrated_probability_up":row.get("calibrated_probability_up"),
                        "calibrated_probability_up_interval":row.pointer("/probability_calibration/calibrated_probability_up_interval"),
                        "runtime":row.get("probability_calibration"),
                        "trade_eligible":row.pointer("/decision/eligible")
                    })
                })
                .collect::<Vec<_>>()
        })
        .unwrap_or_default();
    Ok(Json(json!({
        "calibration": rows,
        "oos_fold_metrics": validation.get("folds").cloned().unwrap_or(json!([])),
        "promotion": validation.get("promotion").cloned().unwrap_or(json!("UNAVAILABLE")),
        "truth":"A calibrator is never fit inside forecast serving. Only a separately materialized promoted OOS Platt-logit or isotonic artifact may populate calibrated_probability_up; absence or mismatch fails closed."
    })))
}

async fn predictor_shadow(State(state): State<AppState>) -> Result<Json<Value>, ApiError> {
    let path = state
        .config
        .data
        .raw_root
        .parent()
        .unwrap_or(std::path::Path::new("data"))
        .join("state/prediction_ledger.sqlite3");
    Ok(Json(
        PredictionLedger::open(&path)
            .map_err(ApiError::internal)?
            .shadow_status()
            .map_err(ApiError::internal)?,
    ))
}

async fn predictor_settlements(State(state): State<AppState>) -> Result<Json<Value>, ApiError> {
    let path = state
        .config
        .data
        .raw_root
        .parent()
        .unwrap_or(std::path::Path::new("data"))
        .join("state/prediction_ledger.sqlite3");
    let ledger = PredictionLedger::open(&path).map_err(ApiError::internal)?;
    let status = ledger.shadow_status().map_err(ApiError::internal)?;
    let pending = ledger.pending_forecasts().map_err(ApiError::internal)?;
    Ok(Json(json!({
        "status":status,
        "pending":pending.len(),
        "truth":"Settlements are append-only; gaps settle as INVALID_DATA_GAP"
    })))
}

async fn predictor_regime(State(state): State<AppState>) -> Result<Json<Value>, ApiError> {
    Ok(Json(read_json_if_present(
        &state
            .config
            .data
            .raw_root
            .parent()
            .unwrap_or(std::path::Path::new("data"))
            .join("reports/regime_latest.json"),
    )?))
}

#[derive(Debug, Deserialize)]
struct DataEstimateRequest {
    parent: String,
    start: chrono::NaiveDate,
    end: chrono::NaiveDate,
    schema: String,
    #[serde(default = "default_dte")]
    dte: Vec<usize>,
}

fn default_dte() -> Vec<usize> {
    vec![0, 1]
}

fn api_opra_request(request: &DataEstimateRequest) -> Result<crate::config::DataRequest, ApiError> {
    if request.end < request.start
        || !matches!(
            request.schema.as_str(),
            "definition" | "cbbo-1m" | "cmbp-1" | "tcbbo" | "trades"
        )
    {
        return Err(ApiError::unprocessable("invalid OPRA estimate request"));
    }
    let end_exclusive = request
        .end
        .succ_opt()
        .ok_or_else(|| ApiError::unprocessable("end date overflow"))?;
    Ok(crate::config::DataRequest {
        name: format!(
            "opra_{}_{}_{}_{}",
            request.parent.to_ascii_lowercase(),
            request.schema.replace('-', "_"),
            request.start.format("%Y%m%d"),
            request.end.format("%Y%m%d")
        ),
        dataset: "OPRA.PILLAR".to_string(),
        schema: request.schema.clone(),
        stype_in: "parent".to_string(),
        symbols: vec![request.parent.clone()],
        start: format!("{}T00:00:00Z", request.start),
        end: format!("{end_exclusive}T00:00:00Z"),
    })
}

async fn data_estimate(Json(request): Json<DataEstimateRequest>) -> Result<Json<Value>, ApiError> {
    let query = api_opra_request(&request)?;
    if std::env::var_os("DATABENTO_API_KEY").is_none() {
        return Ok(Json(json!({
            "status": "DATA_SOURCE_NOT_CONFIGURED",
            "missing_credential": "DATABENTO_API_KEY",
            "dataset": "OPRA.PILLAR",
            "parent": request.parent,
            "schema": request.schema,
            "dte": request.dte,
            "estimated_records": null,
            "estimated_bytes": null,
            "estimated_vendor_charge_usd": null,
            "download_started": false
        })));
    }
    let estimate = crate::data::databento::estimate_cost(&query)
        .await
        .map_err(ApiError::internal)?;
    Ok(Json(json!({
        "status": "ESTIMATE_COMPLETE_AWAITING_CONFIRMATION",
        "estimate": estimate,
        "requested_dte": request.dte,
        "download_started": false,
        "warning": "Parent-wide estimate is an upper bound until point-in-time definitions resolve 0/1DTE raw symbols."
    })))
}

async fn data_validate(State(state): State<AppState>) -> Result<Json<Value>, ApiError> {
    let report = crate::data::readiness::doctor(&state.config.data).map_err(ApiError::internal)?;
    if report.readiness.status != "SPXW_BACKTEST_READY" {
        return Err(ApiError::conflict(format!(
            "SPXW_BACKTEST_BLOCKED: {}",
            report.readiness.missing_requirements.join(",")
        )));
    }
    Ok(Json(json!({
        "status": report.readiness.status,
        "readiness": report.readiness,
        "truth": "No SPXW execution backtest is enabled unless every hard readiness gate passes."
    })))
}

async fn data_lineage(
    State(state): State<AppState>,
    Path(artifact_id): Path<String>,
) -> Result<Json<Value>, ApiError> {
    let report = crate::data::readiness::doctor(&state.config.data).map_err(ApiError::internal)?;
    let matches = report
        .artifacts
        .into_iter()
        .filter(|artifact| {
            artifact.path.contains(&artifact_id)
                || artifact
                    .manifest_hash
                    .as_ref()
                    .is_some_and(|hash| hash.contains(&artifact_id))
        })
        .collect::<Vec<_>>();
    if matches.is_empty() {
        return Err(ApiError {
            status: StatusCode::NOT_FOUND,
            message: "lineage artifact not found".to_string(),
        });
    }
    Ok(Json(
        json!({"artifact_id": artifact_id, "matches": matches}),
    ))
}

async fn data_coverage(State(state): State<AppState>) -> Result<Json<Value>, ApiError> {
    let root = &state.config.data.manifest_root;
    let mut manifests = Vec::new();
    if root.exists() {
        let entries = fs::read_dir(root).map_err(ApiError::internal)?;
        for entry in entries {
            let path = entry.map_err(ApiError::internal)?.path();
            if path.extension().and_then(|x| x.to_str()) != Some("json") {
                continue;
            }
            let bytes = fs::read(&path).map_err(ApiError::internal)?;
            if let Ok(value) = serde_json::from_slice::<Value>(&bytes) {
                manifests.push(value);
            }
        }
    }
    Ok(Json(json!({
        "manifest_count": manifests.len(), "manifests": manifests,
        "real_vendor_bars_ready": state.config.data.normalized_root.join("market_bars.csv").exists(),
        "option_backtest_ready": false,
        "truth": if manifests.is_empty() { "no real vendor historical data has been acquired" } else { "verify per-manifest coverage" }
    })))
}

async fn current_features(State(state): State<AppState>) -> Result<Json<Value>, ApiError> {
    let latest = state
        .registry
        .latest_completed()
        .map_err(ApiError::internal)?;
    let Some((_, report)) = latest else {
        return Ok(Json(
            json!({"status":"unavailable","reason":"no_completed_real_data_experiment"}),
        ));
    };
    let hint = report.current_hint;
    Ok(Json(match hint {
        Some(hint) => json!({
            "schema_version": "point-in-time-v2",
            "symbol": hint.target,
            "snapshot_time": hint.as_of,
            "last_completed_1m_bar": hint.as_of,
            "active_5m_partial_state": {"bucket_5m": hint.bucket_5m},
            "data_freshness_status": if QuantRuntime::market_status() == "MARKET_CLOSED" { "MARKET_CLOSED_LAST_KNOWN" } else { "UNKNOWN_UNTIL_POLL" },
            "missing_features": ["SPX_INDEX", "ES", "VIX", "SPXW_NBBO"],
            "source": report.source_mode
        }),
        None => json!({"status":"unavailable","reason":"latest_report_has_no_current_hint"}),
    }))
}

async fn models() -> Json<Value> {
    Json(json!({"models": QuantRuntime::models()}))
}

async fn model(Path(model_id): Path<String>) -> Result<Json<Value>, ApiError> {
    QuantRuntime::models()
        .into_iter()
        .find(|model| model.model_id == model_id)
        .map(|model| Json(json!(model)))
        .ok_or_else(|| ApiError {
            status: StatusCode::NOT_FOUND,
            message: "model not found".into(),
        })
}

async fn current_predictions(State(state): State<AppState>) -> Result<Json<Value>, ApiError> {
    let latest = state
        .registry
        .latest_completed()
        .map_err(ApiError::internal)?;
    let Some((run, report)) = latest else {
        return Ok(Json(
            json!({"predictions":[],"reason":"no_completed_experiment"}),
        ));
    };
    let predictions: Vec<Value> = report
        .current_hint
        .map(|hint| {
            hint.horizons
                .into_iter()
                .map(|row| {
                    json!({
                    "model_version": "candidate-0.1.0",
                                    "model_status": "REJECTED",
                                    "feature_timestamp": row.as_of,
                                    "prediction_timestamp": run.completed_at,
                                    "horizon": row.horizon_minutes,
                                    "probability": row.prediction.win_probability,
                                    "expected_return": row.prediction.expected_return,
                                    "sample_count": row.prediction.neighbor_count,
                    "calibration_status": "FAILED_EDGE_GATE",
                                    "action": "NO_TRADE",
                    "reason": "no_model_passed_oos_promotion_gate"
                                })
                })
                .collect()
        })
        .unwrap_or_default();
    Ok(Json(
        json!({"predictions":predictions,"paper_eligible":false}),
    ))
}

async fn current_signal(State(state): State<AppState>) -> Json<Value> {
    Json(json!({
        "symbol": "SPY",
        "action": "NO_TRADE",
        "mode": "PAPER",
        "regime": "UNCERTAIN",
        "position_size": 0.0,
        "reason_codes": ["NO_PROMOTED_MODEL", "BASELINE_OOS_FAILED", "MARKET_CLOSED", "SPXW_NBBO_UNAVAILABLE"],
        "risk": state.runtime.risk_status(),
        "explanation": "The failed baseline is not allowed to create a position intent."
    }))
}

async fn portfolio(State(state): State<AppState>) -> Json<Value> {
    Json(json!(state.runtime.portfolio()))
}

async fn risk(State(state): State<AppState>) -> Json<Value> {
    Json(json!(state.runtime.risk_status()))
}

async fn orders(State(state): State<AppState>) -> Json<Value> {
    Json(json!({"orders": state.runtime.orders()}))
}

async fn fills(State(state): State<AppState>) -> Json<Value> {
    Json(json!({"fills": state.runtime.fills()}))
}

async fn paper_start(State(state): State<AppState>) -> Result<Json<Value>, ApiError> {
    state
        .runtime
        .start_paper()
        .map(|status| Json(json!(status)))
        .map_err(ApiError::unprocessable)
}

async fn paper_stop(State(state): State<AppState>) -> Json<Value> {
    Json(json!(state.runtime.stop_paper()))
}

#[derive(Debug, Deserialize)]
struct KillRequest {
    cancel_open: Option<bool>,
}

async fn risk_kill(State(state): State<AppState>, Json(request): Json<KillRequest>) -> Json<Value> {
    Json(json!(
        state
            .runtime
            .activate_kill_switch(request.cancel_open.unwrap_or(true))
    ))
}

async fn risk_resume(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<Value>, ApiError> {
    let Some(expected) = std::env::var("RISK_APPROVAL_TOKEN").ok().filter(|value| {
        value.len() >= 32
            && std::env::var("INTRADAY_QUANT_TOKEN")
                .ok()
                .is_none_or(|control| control.as_str() != value.as_str())
    }) else {
        return Err(ApiError::service_unavailable(
            "risk resume is disabled until a separate 32+ character RISK_APPROVAL_TOKEN is configured",
        ));
    };
    let provided = headers
        .get("x-risk-approval-token")
        .and_then(|value| value.to_str().ok())
        .unwrap_or_default();
    if !constant_time_token_match(&expected, provided) {
        return Err(ApiError::unauthorized(
            "separate risk approval token is invalid",
        ));
    }
    Ok(Json(json!(state.runtime.resume_risk())))
}

async fn replay_last_session(State(state): State<AppState>) -> Json<Value> {
    Json(
        json!({"order": state.runtime.replay_rejection("SPY"), "truth": "risk rejection replay; no synthetic fill generated"}),
    )
}

async fn audit(State(state): State<AppState>) -> Json<Value> {
    Json(json!({"events": state.runtime.audit_events()}))
}

async fn stream_snapshot(State(state): State<AppState>) -> Json<Value> {
    Json(
        json!({"transport":"snapshot","upgrade":"SSE pending","runtime":state.runtime.status(),"risk":state.runtime.risk_status()}),
    )
}

#[derive(Debug, Deserialize)]
struct OverviewQuery {
    #[serde(rename = "profile")]
    _profile: Option<String>,
}

async fn overview(
    State(state): State<AppState>,
    Query(_query): Query<OverviewQuery>,
) -> Result<Json<Value>, ApiError> {
    let latest = state
        .registry
        .latest_completed()
        .map_err(ApiError::internal)?;
    let Some((run, report)) = latest else {
        return Ok(Json(json!({
            "status": "empty",
            "message": "No real-vendor historical run exists. Run Massive sync or import licensed bars, then POST /api/v1/runs. Synthetic results are intentionally excluded from this Rust backend."
        })));
    };
    let candidates: Vec<Value> = report
        .candidates
        .iter()
        .map(|decision| {
            json!({
                "candidate_id": decision.candidate.candidate_id,
                "timestamp": decision.candidate.timestamp,
                "session_date": decision.candidate.session_date,
                "setup_type": decision.candidate.setup_type,
                "direction": decision.candidate.direction,
                "decision": if decision.selected { "selected" } else { "rejected" },
                "score": decision.score,
                "expected_return": decision.prediction.as_ref().map(|p| p.expected_return),
                "expected_net_return": decision.expected_net_return,
                "win_probability": decision.prediction.as_ref().map(|p| p.win_probability),
                "predicted_mfe": decision.prediction.as_ref().map(|p| p.predicted_mfe),
                "predicted_mae": decision.prediction.as_ref().map(|p| p.predicted_mae),
                "uncertainty": decision.prediction.as_ref().map(|p| p.uncertainty),
                "rejection_reason": decision.rejection_reason,
                "reason_codes": decision.candidate.reason_codes.join("|")
            })
        })
        .collect();
    let analogs: Vec<Value> = report
        .analogs
        .iter()
        .map(|row| {
            json!({
                "rank": row.rank,
                "analog_date": row.analog_timestamp,
                "distance": row.distance,
                "similarity": row.similarity,
                "forward_return": row.forward_return,
                "mfe": row.mfe,
                "mae": row.mae
            })
        })
        .collect();
    Ok(Json(json!({
        "run": run, "metrics": report.metrics, "equity": report.equity,
        "trades": report.trades, "candidates": candidates,
        "analogs": analogs, "diagnostics": [], "audits": {
            "time_bucket_reversals": report.time_bucket_effects
        },
        "current_hint": report.current_hint,
        "model_specification": { "analog": "past-only Gaussian kernel", "execution": "event ordered" }
    })))
}

#[derive(Debug, Deserialize)]
struct StartRunRequest {
    profile: Option<String>,
}

#[derive(Debug, Serialize)]
struct StartRunResponse {
    run_id: String,
    status: String,
}

async fn start_run(
    State(state): State<AppState>,
    Json(request): Json<StartRunRequest>,
) -> Result<(StatusCode, Json<StartRunResponse>), ApiError> {
    let profile = request.profile.unwrap_or_else(|| "real_data".to_string());
    if !matches!(profile.as_str(), "licensed" | "real_data" | "massive") {
        return Err(ApiError::unprocessable(
            "Rust production backend accepts only licensed/real_data/massive profiles",
        ));
    }
    let bars_path = state.config.data.normalized_root.join("market_bars.csv");
    if !bars_path.exists() {
        return Err(ApiError::unprocessable(format!(
            "real vendor bars file is absent: {}. Run quantctl data massive-sync or validate imported vendor bars first.",
            bars_path.display()
        )));
    }
    let run_id = Uuid::new_v4().to_string();
    state
        .registry
        .create(&run_id, &profile)
        .map_err(ApiError::internal)?;
    let task_state = state.clone();
    let task_run_id = run_id.clone();
    tokio::task::spawn_blocking(move || {
        let _ = task_state.registry.mark_running(&task_run_id);
        match run_csv_research(&bars_path, &task_state.config.research) {
            Ok(report) => {
                let _ = task_state.registry.complete(&task_run_id, &report);
            }
            Err(error) => {
                let _ = task_state
                    .registry
                    .fail(&task_run_id, &format!("{error:#}"));
            }
        }
    });
    Ok((
        StatusCode::ACCEPTED,
        Json(StartRunResponse {
            run_id,
            status: "queued".to_string(),
        }),
    ))
}

async fn get_run(
    State(state): State<AppState>,
    Path(run_id): Path<String>,
) -> Result<Json<RunRecord>, ApiError> {
    state
        .registry
        .get(&run_id)
        .map_err(ApiError::internal)?
        .map(Json)
        .ok_or_else(|| ApiError {
            status: StatusCode::NOT_FOUND,
            message: "run not found".to_string(),
        })
}

async fn list_runs(State(state): State<AppState>) -> Result<Json<Vec<RunRecord>>, ApiError> {
    Ok(Json(state.registry.list(100).map_err(ApiError::internal)?))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::data::databento_inference::{TargetInferenceStage, TargetInferenceState};
    use crate::production_readiness::{
        ArtifactReadinessReceipt, ForecastCalibrationStatus, ForecastCoverageStatus,
        ForecastValidationStatus, LegacyMarketDataRightsStatus, LiveInferenceReadinessReceipt,
        LlmAuthStatus, LlmReadinessReceipt, MarketDataReadinessReceipt,
        MarketDataRightsReadinessReceipt, MarketDataRightsReason, SymbolForecastReadiness,
    };
    use chrono::{TimeZone, Utc};

    fn atomic_databento_symbols() -> BTreeSet<String> {
        [
            "AAPL", "BE", "IGV", "MU", "NBIS", "NVDA", "QQQ", "SOXX", "SPY",
        ]
        .into_iter()
        .map(str::to_string)
        .collect()
    }

    #[test]
    fn session_summary_returns_complete_spx_proxy_map_from_databento_rows() {
        let start = Utc.with_ymd_and_hms(2026, 7, 30, 13, 30, 0).unwrap();
        let rows = (0..390)
            .map(|minute| {
                let event_at = start + chrono::Duration::minutes(minute);
                let price = 100.0 + minute as f64 * 0.01;
                crate::data::market_store::StoredLiveMarketBar {
                    provider: "databento".into(),
                    dataset: "EQUS.MINI".into(),
                    schema_name: "ohlcv-1m".into(),
                    symbol: "SPY".into(),
                    event_at: event_at.to_rfc3339(),
                    available_at: (event_at + chrono::Duration::minutes(1)).to_rfc3339(),
                    recorded_at: (event_at + chrono::Duration::minutes(1)).to_rfc3339(),
                    finalized_at: (event_at + chrono::Duration::minutes(1)).to_rfc3339(),
                    open: price,
                    high: price + 0.02,
                    low: price - 0.02,
                    close: price + 0.01,
                    volume: 1_000.0,
                    vwap: None,
                    trade_count: None,
                    source: "Databento/EQUS.MINI".into(),
                    data_quality: "vendor_original_dbn".into(),
                    entitlement: "LICENSED_HISTORICAL_DOWNLOAD".into(),
                    symbol_mapping_verified: true,
                }
            })
            .collect();
        let summary = build_session_summary(rows, "SPX", "SPY").unwrap();
        assert_eq!(summary["status"], "COMPLETE_78_BAR_SESSION");
        assert_eq!(summary["result_kind"], "OBSERVED_SESSION_TREND");
        assert_eq!(summary["public_symbol"], "SPX");
        assert_eq!(summary["data_symbol"], "SPY");
        assert_eq!(summary["minute_rows"], 390);
        assert_eq!(summary["five_minute_bar_count"], 78);
        assert_eq!(summary["freshness"]["status"], "NOT_EVALUATED_FOR_LIVE_USE");
        assert_eq!(summary["coverage"]["expected_regular_session_minutes"], 390);
        assert_eq!(summary["coverage"]["observed_regular_session_minutes"], 390);
        assert_eq!(summary["coverage"]["ratio"], 1.0);
        assert!(summary["model_version"].is_null());
        assert!(summary["feature_version"].is_null());
        assert_eq!(
            summary["five_minute_bars"]
                .as_array()
                .expect("five-minute map")
                .len(),
            78
        );
        assert_eq!(
            summary["peak_windows"]
                .as_array()
                .expect("peak windows")
                .len(),
            3
        );
        assert_eq!(summary["automatic_execution_enabled"], false);
        assert_eq!(summary["probability_published"], false);
    }

    #[test]
    fn ticker_rag_preserves_cardinality_and_never_reuses_another_symbol() {
        let requested = ["GOOG", "AMZN", "MU", "SNDK"]
            .into_iter()
            .map(str::to_string)
            .collect::<Vec<_>>();
        let start = Utc.with_ymd_and_hms(2026, 7, 30, 13, 30, 0).unwrap();
        let bundle = build_ticker_rag_bundle(&requested, |symbol| {
            if symbol != "MU" {
                return Ok(Vec::new());
            }
            Ok((0..390)
                .map(|minute| {
                    let event_at = start + chrono::Duration::minutes(minute);
                    let price = 120.0 + minute as f64 * 0.01;
                    crate::data::market_store::StoredLiveMarketBar {
                        provider: "databento".into(),
                        dataset: "EQUS.MINI".into(),
                        schema_name: "ohlcv-1m".into(),
                        symbol: symbol.to_string(),
                        event_at: event_at.to_rfc3339(),
                        available_at: (event_at + chrono::Duration::minutes(1)).to_rfc3339(),
                        recorded_at: (event_at + chrono::Duration::minutes(1)).to_rfc3339(),
                        finalized_at: (event_at + chrono::Duration::minutes(1)).to_rfc3339(),
                        open: price,
                        high: price + 0.02,
                        low: price - 0.02,
                        close: price + 0.01,
                        volume: 1_000.0,
                        vwap: None,
                        trade_count: None,
                        source: "Databento/EQUS.MINI".into(),
                        data_quality: "vendor_original_dbn".into(),
                        entitlement: "LICENSED_HISTORICAL_DOWNLOAD".into(),
                        symbol_mapping_verified: true,
                    }
                })
                .collect())
        });
        let results = bundle["results"].as_array().expect("ticker RAG results");
        assert_eq!(bundle["requested_count"], 4);
        assert_eq!(bundle["result_count"], 4);
        assert_eq!(results.len(), 4);
        assert_eq!(results[0]["requested_symbol"], "GOOG");
        assert_eq!(results[0]["status"], "NO_STORED_OBSERVATIONS");
        assert_eq!(results[1]["requested_symbol"], "AMZN");
        assert_eq!(results[1]["status"], "NO_STORED_OBSERVATIONS");
        assert_eq!(results[2]["requested_symbol"], "MU");
        assert_eq!(results[2]["status"], "RETRIEVED");
        assert_eq!(results[2]["summary"]["public_symbol"], "MU");
        assert_eq!(results[3]["requested_symbol"], "SNDK");
        assert_eq!(results[3]["status"], "NO_STORED_OBSERVATIONS");
        assert!(results[0]["summary"].is_null());
        assert!(results[1]["summary"].is_null());
        assert!(results[3]["summary"].is_null());
        assert_eq!(bundle["probability_published"], false);
        assert_eq!(bundle["automatic_execution_enabled"], false);
    }

    #[test]
    fn ticker_rag_normalization_is_bounded_and_order_preserving() {
        assert_eq!(
            normalize_ticker_list("goog, AMZN,us.mu,GOOG").unwrap(),
            vec!["GOOG", "AMZN", "MU"]
        );
        assert!(normalize_ticker_list("GOOG,,MU").is_err());
        assert!(normalize_ticker_list("../../etc/passwd").is_err());
    }

    #[test]
    fn databento_customer_snapshot_requires_exact_nine_and_never_falls_back() {
        let directory = tempfile::tempdir().unwrap();
        fs::create_dir_all(directory.path().join("reports")).unwrap();
        fs::write(
            directory
                .path()
                .join("reports/forecast_contract_live_latest.json"),
            br#"{"generation":"legacy-per-symbol"}"#,
        )
        .unwrap();

        let undersized = BTreeSet::from(["SPY".to_string()]);
        let error =
            CustomerLiveForecastSnapshot::load(directory.path(), "databento", &undersized, 1)
                .unwrap_err();
        assert_eq!(error, "DATABENTO_ATOMIC_BATCH_EXACT_NINE_CONFIG_REQUIRED");

        let deduplicated_nine = atomic_databento_symbols();
        let duplicate_extra = CustomerLiveForecastSnapshot::load(
            directory.path(),
            "databento",
            &deduplicated_nine,
            10,
        )
        .unwrap_err();
        assert_eq!(
            duplicate_extra, "DATABENTO_ATOMIC_BATCH_EXACT_NINE_CONFIG_REQUIRED",
            "ten configured entries containing a duplicate must not pass as exact-nine"
        );

        let snapshot = CustomerLiveForecastSnapshot::load(
            directory.path(),
            "databento",
            &atomic_databento_symbols(),
            9,
        )
        .unwrap();
        assert!(
            snapshot.payload(directory.path(), "SPY").unwrap().is_none(),
            "a missing all-nine ledger commit must not fall back to the legacy SPY projection"
        );

        let legacy_snapshot =
            CustomerLiveForecastSnapshot::load(directory.path(), "moomoo", &undersized, 1).unwrap();
        assert_eq!(
            legacy_snapshot
                .payload(directory.path(), "SPY")
                .unwrap()
                .unwrap()["generation"],
            "legacy-per-symbol"
        );
    }

    #[test]
    fn databento_customer_snapshot_keeps_one_generation_for_all_symbol_lookups() {
        let symbols = atomic_databento_symbols();
        let forecasts = symbols
            .iter()
            .map(|symbol| {
                (
                    symbol.clone(),
                    json!({"symbol":symbol,"batch_marker":"one-request-generation"}),
                )
            })
            .collect();
        let snapshot = CustomerLiveForecastSnapshot::Databento(Some(
            crate::data::databento_inference::CommittedForecastBatch {
                batch_id: "batch-one".into(),
                cutoff: Utc.with_ymd_and_hms(2026, 7, 28, 14, 31, 0).unwrap(),
                committed_at: Utc.with_ymd_and_hms(2026, 7, 28, 14, 31, 2).unwrap(),
                forecasts,
            },
        ));

        for symbol in symbols {
            let payload = snapshot
                .payload(std::path::Path::new("unused"), &symbol)
                .unwrap()
                .unwrap();
            assert_eq!(payload["symbol"], symbol);
            assert_eq!(payload["batch_marker"], "one-request-generation");
        }
    }

    fn ready_public_research_receipt() -> ProductionReadinessReceipt {
        ProductionReadinessReceipt {
            schema_version: crate::production_readiness::PRODUCTION_READINESS_SCHEMA_VERSION,
            status: OverallReadiness::Ready,
            public_realtime_research_ready: true,
            llm: LlmReadinessReceipt {
                auth_status: LlmAuthStatus::ExternalUnknown,
            },
            market_data: MarketDataReadinessReceipt {
                selected_provider: "databento".to_string(),
                selected_product: Some("EQUS.MINI".to_string()),
                live_enabled: true,
                public_use_rights: MarketDataRightsReadinessReceipt {
                    status: MarketDataRightsStatus::Ready,
                    reason: MarketDataRightsReason::Verified,
                    legacy_environment_status: LegacyMarketDataRightsStatus::NotConfigured,
                },
                provider_entitlement: EvidenceStatus::Ready,
                stream_freshness: FreshnessStatus::Fresh,
                feed_freshness: FreshnessStatus::Fresh,
            },
            artifacts: ArtifactReadinessReceipt {
                promotion_registry_present: true,
                promotion_registry_status: PromotionRegistryStatus::ActivePinned,
                calibration_registry_present: true,
                calibration_registry_status: CalibrationRegistryStatus::Promoted,
                prediction_ledger_present: true,
            },
            forecasts: vec![SymbolForecastReadiness {
                symbol: "NVDA".to_string(),
                live_inference: LiveInferenceReadinessReceipt {
                    required: true,
                    status_available: true,
                    status: Some(TargetInferenceState::Published),
                    stage: Some(TargetInferenceStage::Published),
                    reason_code: None,
                    status_freshness: FreshnessStatus::Fresh,
                    cutoff: None,
                    latest_input_available_at: None,
                    compute_ms: Some(1),
                    end_to_end_ms: Some(2),
                    budget_ms: Some(5_000),
                    context_blockers: Vec::new(),
                    forecast_committed: true,
                    receipt_committed: true,
                    ledger_persisted: true,
                    ready: true,
                },
                artifact_present: true,
                validation_status: ForecastValidationStatus::Passed,
                freshness: FreshnessStatus::Fresh,
                horizon_coverage: ForecastCoverageStatus::Complete,
                calibration: ForecastCalibrationStatus::Promoted,
                promotion_registry_matches: true,
                ledger_backed: true,
                ready: true,
            }],
        }
    }

    fn model_horizon_candidate(symbol: &str, horizon: usize) -> ResearchCandidate {
        ResearchCandidate {
            symbol: symbol.to_string(),
            setup_type: MarketSetupType::ModelForecast,
            status: "UNCALIBRATED_RESEARCH_OUTPUT".into(),
            heuristic_structure_score: None,
            score_semantics: "test".into(),
            supporting_evidence: Vec::new(),
            contrary_evidence: Vec::new(),
            metrics: json!({"horizon_minutes":horizon}),
            freshness: Vec::new(),
        }
    }

    fn neutral_model_query(horizon_minutes: Option<usize>) -> MarketQuery {
        MarketQuery {
            version: crate::market_query::MARKET_QUERY_SCHEMA_VERSION.into(),
            intent: MarketQueryIntent::Forecast,
            setup_type: MarketSetupType::ModelForecast,
            symbols: vec!["SPX".into()],
            horizon_minutes,
            limit: 1,
            as_of: None,
            filters: crate::market_query::MarketQueryFilters::default(),
        }
    }

    #[test]
    fn model_forecast_horizon_contract_is_atomic_complete_and_spx_mapped() {
        let mut candidates = vec![
            model_horizon_candidate("SPX", 60),
            model_horizon_candidate("SPX", 5),
            model_horizon_candidate("SPX", 30),
            model_horizon_candidate("SPX", 15),
        ];
        let mut blockers = Vec::new();
        enforce_model_forecast_horizon_contract(
            &neutral_model_query(None),
            &[5, 15, 30, 60],
            &mut candidates,
            &mut blockers,
        );
        assert!(blockers.is_empty());
        assert_eq!(
            candidates
                .iter()
                .map(|candidate| candidate.metrics["horizon_minutes"].as_u64().unwrap())
                .collect::<Vec<_>>(),
            vec![5, 15, 30, 60]
        );

        let mut explicit = vec![model_horizon_candidate("SPX", 15)];
        enforce_model_forecast_horizon_contract(
            &neutral_model_query(Some(15)),
            &[5, 15, 30, 60],
            &mut explicit,
            &mut blockers,
        );
        assert!(blockers.is_empty());

        let mut incomplete = vec![
            model_horizon_candidate("SPX", 5),
            model_horizon_candidate("SPX", 15),
            model_horizon_candidate("SPX", 60),
        ];
        enforce_model_forecast_horizon_contract(
            &neutral_model_query(None),
            &[5, 15, 30, 60],
            &mut incomplete,
            &mut blockers,
        );
        assert!(
            blockers
                .iter()
                .any(|blocker| blocker == "SPX:MODEL_FORECAST_HORIZON_MISSING:horizon_minutes=30")
        );

        blockers.clear();
        let mut duplicate = vec![
            model_horizon_candidate("SPX", 15),
            model_horizon_candidate("SPX", 15),
        ];
        enforce_model_forecast_horizon_contract(
            &neutral_model_query(Some(15)),
            &[5, 15, 30, 60],
            &mut duplicate,
            &mut blockers,
        );
        assert!(
            blockers.iter().any(
                |blocker| blocker
                    == "SPX:MODEL_FORECAST_HORIZON_DUPLICATE:horizon_minutes=15"
            )
        );

        blockers.clear();
        let mut multi_symbol_query = neutral_model_query(None);
        multi_symbol_query.symbols = vec!["SPX".into(), "QQQ".into()];
        multi_symbol_query.limit = 1;
        let mut multi_symbol = ["SPX", "QQQ"]
            .into_iter()
            .flat_map(|symbol| {
                [5, 15, 30, 60]
                    .into_iter()
                    .map(move |horizon| model_horizon_candidate(symbol, horizon))
            })
            .collect::<Vec<_>>();
        apply_research_candidate_shape(&multi_symbol_query, &mut multi_symbol);
        enforce_model_forecast_horizon_contract(
            &multi_symbol_query,
            &[5, 15, 30, 60],
            &mut multi_symbol,
            &mut blockers,
        );
        assert!(blockers.is_empty());
        assert_eq!(multi_symbol.len(), 8);
        assert_eq!(
            multi_symbol
                .iter()
                .map(|candidate| candidate.symbol.as_str())
                .collect::<BTreeSet<_>>(),
            BTreeSet::from(["QQQ", "SPX"])
        );
    }

    #[test]
    fn factor_shadow_status_is_metadata_only_and_execution_disabled() {
        let payload = serde_json::to_value(factor_shadow_status_contract()).unwrap();
        assert_eq!(
            payload,
            json!({
                "schema_version":"axio.factor-shadow-status.v1",
                "candidate":{
                    "candidate_id":"axio.pv-multifactor-40-20-40",
                    "candidate_version":"v1",
                    "owner":"quant_engine_rs",
                    "scope":"IMPERSONAL_CROSS_SECTIONAL_MARKET_RESEARCH_SHADOW",
                    "status":"CANDIDATE_NOT_PROMOTED"
                },
                "fixed_weights_percent":{
                    "momentum":40,
                    "liquidity_proxy":20,
                    "regime_and_other_price_volume":40
                },
                "blockers":[
                    "POINT_IN_TIME_UNIVERSE_NOT_VALIDATED",
                    "LIQUIDITY_PROXY_NOT_VALIDATED",
                    "PURGED_WALK_FORWARD_AND_FORWARD_SHADOW_INCOMPLETE"
                ],
                "execution":"DISABLED"
            })
        );
        let weights = payload["fixed_weights_percent"].as_object().unwrap();
        assert_eq!(weights.values().filter_map(Value::as_u64).sum::<u64>(), 100);
        let forbidden_keys = [
            "rank",
            "score",
            "probability",
            "expected_return",
            "target",
            "order",
            "position",
            "quantity",
        ];
        fn contains_forbidden_key(value: &Value, forbidden_keys: &[&str]) -> bool {
            match value {
                Value::Object(object) => {
                    object.keys().any(|key| {
                        forbidden_keys
                            .iter()
                            .any(|forbidden| key.eq_ignore_ascii_case(forbidden))
                    }) || object
                        .values()
                        .any(|child| contains_forbidden_key(child, forbidden_keys))
                }
                Value::Array(values) => values
                    .iter()
                    .any(|child| contains_forbidden_key(child, forbidden_keys)),
                _ => false,
            }
        }
        assert!(!contains_forbidden_key(&payload, &forbidden_keys));
    }

    fn contains_forbidden_research_key(value: &Value) -> bool {
        match value {
            Value::Object(object) => {
                object
                    .keys()
                    .any(|key| PUBLIC_RESEARCH_FORBIDDEN_KEYS.contains(&key.as_str()))
                    || object.values().any(contains_forbidden_research_key)
            }
            Value::Array(values) => values.iter().any(contains_forbidden_research_key),
            _ => false,
        }
    }

    fn live_bundle_fixture(now: chrono::DateTime<chrono::Utc>, evidence_kind: &str) -> Value {
        let cutoff = now - chrono::Duration::seconds(30);
        let available_at = cutoff + chrono::Duration::seconds(2);
        let mut bundle = json!({
            "generated_at":now - chrono::Duration::seconds(20),
            "status":"NO_TRADE",
            "forecast_contract_version":"4.2",
            "prediction_layer":[{
                "prediction_id":"p-live",
                "observation_cutoff":cutoff,
                "as_of":cutoff,
                "decision_as_of":if evidence_kind == "live_shadow_prediction" {
                    available_at
                } else {
                    cutoff
                },
                "latest_input_available_at":if evidence_kind == "live_shadow_prediction" {
                    available_at
                } else {
                    cutoff
                },
                "symbol":"SPY",
                "timeframe":"1m",
                "horizon_minutes":15,
                "label_start":cutoff,
                "label_end":cutoff + chrono::Duration::minutes(15),
                "expected_return":0.001,
                "p_up":0.65,
                "p_down":0.30,
                "p_flat":0.05,
                "return_quantiles":[
                    {"probability":0.10,"value":-0.001},
                    {"probability":0.50,"value":0.0008},
                    {"probability":0.90,"value":0.003}
                ],
                "expected_volatility":0.002,
                "epistemic_uncertainty":0.0002,
                "ood_score":0.1,
                "dominant_regime_state":2,
                "dominant_regime_probability":0.7,
                "state_entropy":0.4,
                "regime_model_selection":{
                    "selected_state_count":4,
                    "eight_state_challenger_status":"EVALUATED_NOT_SELECTED"
                },
                "stochastic_research_layer":{
                    "model_family":"MARKOV_SWITCHING_LOG_RETURN_DIFFUSION",
                    "martingale_audit_status":"PASS_VETO_NOT_TRIGGERED",
                    "momentum_head":{
                        "status":"SHADOW_ONLY",
                        "momentum_direction":1,
                        "continuation_probability":0.62,
                        "reversal_probability":0.38,
                        "posterior_standard_deviation":0.04,
                        "effective_samples":45.0
                    },
                    "affects_decision":false
                },
                "model_id":"test-model",
                "feature_version":"test-feature-v1",
                "model_hash":"a".repeat(64),
                "feature_hash":"b".repeat(64),
                "data_manifest_hash":"c".repeat(64),
                "data_source":if evidence_kind == "live_shadow_prediction" {
                    "MOOMOO_OPEND:test"
                } else {
                    "MASSIVE_BATCH"
                },
                "evidence_grade":"FORWARD_SHADOW",
                "evidence_kind":evidence_kind,
                "calibration_status":"UNVALIDATED_CANDIDATE",
                "analog_engine_status":"AVAILABLE"
            }],
            "unavailable_horizons":[],
            "gamma_convexity_layer":{
                "availability":"unavailable",
                "unavailable_reasons":["empty_chain"]
            },
            "research_only_policy":{
                "product_scope":"IMPERSONAL_WHOLE_MARKET_STATISTICAL_RESEARCH"
            }
        });
        let interval = |estimate: f64| {
            json!({
                "estimate":estimate,
                "lower":(estimate - 0.1).max(0.0),
                "upper":(estimate + 0.1).min(1.0),
                "confidence_level":0.95,
                "effective_sample_size":30.0,
                "method":"wilson_score",
                "status":"EXPLORATORY_UNCALIBRATED_EFFECTIVE_SAMPLE_WILSON",
                "semantics":"TEST_UNCALIBRATED_EFFECTIVE_SAMPLE_INTERVAL"
            })
        };
        bundle["prediction_layer"][0]["reference_price"] = json!(100.0);
        bundle["prediction_layer"][0]["expected_price"] = json!(100.1);
        bundle["prediction_layer"][0]["return_definition"] = json!("SIMPLE_RETURN");
        bundle["prediction_layer"][0]["raw_analog_up_frequency"] = json!(0.65);
        bundle["prediction_layer"][0]["raw_analog_down_frequency"] = json!(0.30);
        bundle["prediction_layer"][0]["raw_analog_flat_frequency"] = json!(0.05);
        bundle["prediction_layer"][0]["probability_calibration"] = json!({
            "eligible_for_probability_use":false,
            "calibrated_probability_up":null
        });
        bundle["prediction_layer"][0]["kernel_regression"] = json!({
            "status":"AVAILABLE",
            "feature_dimension_count":12,
            "selected_dimensions":[
                "ret_1m","ret_5m","ret_15m","vwap_distance",
                "realized_volatility","normalized_range","volume_zscore","rvol",
                "session_range_position","cross_asset_breadth","slope_15m","minute_of_session"
            ],
            "metric":"shrinkage_mahalanobis",
            "kernel":"GAUSSIAN_RBF_ADAPTIVE_BANDWIDTH_NADARAYA_WATSON",
            "bandwidth":1.2,
            "neighbor_count":50,
            "effective_sample_size":30.0,
            "minimum_effective_sample_size":20.0,
            "nadaraya_watson_expected_return":0.001,
            "local_linear_intercept":0.0009,
            "direction_event_threshold_return":0.0003,
            "direction_probability_intervals":{
                "up":interval(0.65),
                "flat":interval(0.05),
                "down":interval(0.30)
            },
            "probability_status":"EXPLORATORY_UNCALIBRATED_EFFECTIVE_SAMPLE_WILSON",
            "probability_semantics":"TEST_RAW_FREQUENCY_INTERVALS"
        });
        bundle["prediction_layer"][0]["outcome_prediction_intervals"] = json!([
            {
                "probability_mass":0.80,
                "lower_return":-0.001,
                "upper_return":0.003,
                "lower_price":99.9,
                "upper_price":100.3,
                "method":"KERNEL_WEIGHTED_HISTORICAL_ANALOG_QUANTILES",
                "status":"UNCALIBRATED_EMPIRICAL_CONDITIONAL_RANGE",
                "semantics":"TEST_NOT_COVERAGE_GUARANTEE"
            },
            {
                "probability_mass":0.90,
                "lower_return":-0.002,
                "upper_return":0.004,
                "lower_price":99.8,
                "upper_price":100.4,
                "method":"KERNEL_WEIGHTED_HISTORICAL_ANALOG_QUANTILES",
                "status":"UNCALIBRATED_EMPIRICAL_CONDITIONAL_RANGE",
                "semantics":"TEST_NOT_COVERAGE_GUARANTEE"
            }
        ]);
        bundle
    }

    fn upgrade_fixture_to_v44(bundle: &mut Value) {
        bundle["forecast_contract_version"] = json!("4.4");
        let row = &mut bundle["prediction_layer"][0];
        row["p_up"] = Value::Null;
        row["p_down"] = Value::Null;
        row["p_flat"] = Value::Null;
        row["expected_price"] = Value::Null;
        row["return_definition"] = json!(KERNEL_RETURN_DEFINITION);
        row["price_quantiles"] = json!([]);
        row["current_close_reference_scenario_expected_price"] = json!(100.1);
        row["current_close_reference_scenario_price_quantiles"] = json!([
            {"probability":0.10,"value":99.9},
            {"probability":0.50,"value":100.08},
            {"probability":0.90,"value":100.3}
        ]);
        row["current_close_reference_scenario_basis"] = json!(CURRENT_CLOSE_SCENARIO_BASIS);
        row["current_close_reference_scenario_status"] = json!(CURRENT_CLOSE_SCENARIO_STATUS);
        row["current_close_reference_scenario_semantics"] = json!(CURRENT_CLOSE_SCENARIO_SEMANTICS);
        for interval in row["outcome_prediction_intervals"].as_array_mut().unwrap() {
            let legacy_lower = interval["lower_price"].take();
            let legacy_upper = interval["upper_price"].take();
            interval["lower_price"] = Value::Null;
            interval["upper_price"] = Value::Null;
            interval["current_close_reference_scenario_lower_price"] = legacy_lower;
            interval["current_close_reference_scenario_upper_price"] = legacy_upper;
            interval["current_close_reference_scenario_basis"] =
                json!(CURRENT_CLOSE_SCENARIO_BASIS);
            interval["current_close_reference_scenario_status"] =
                json!(CURRENT_CLOSE_SCENARIO_STATUS);
            interval["current_close_reference_scenario_semantics"] =
                json!(CURRENT_CLOSE_SCENARIO_SEMANTICS);
        }
        row["stochastic_research_layer"]["horizon_forecast"] = json!({
            "horizon_minutes":15,
            "direction_probabilities":{
                "p_up":0.45,
                "p_flat":0.20,
                "p_down":0.35,
                "material_move_lower_threshold_log_return":(-0.0003_f64).ln_1p(),
                "material_move_upper_threshold_log_return":0.0003_f64.ln_1p(),
                "method":"GAUSSIAN_MOMENT_MATCHED_FROM_FIRST_TWO_MOMENTS",
                "status":"UNCALIBRATED_RESEARCH_ONLY_GAUSSIAN_MOMENT_MATCHED",
                "semantics":"MODEL_IMPLIED_UNCALIBRATED_RESEARCH_ONLY; NOT_A_CONFIDENCE_GUARANTEE; JUMP_COMPONENT_EXCLUDED_FROM_TAILS"
            },
            "central_prediction_intervals":[
                {
                    "probability_mass":0.80,
                    "lower_log_return":-0.002,
                    "upper_log_return":0.003,
                    "method":"GAUSSIAN_MOMENT_MATCHED_FROM_FIRST_TWO_MOMENTS",
                    "status":"UNCALIBRATED_RESEARCH_ONLY_GAUSSIAN_MOMENT_MATCHED",
                    "semantics":"MODEL_IMPLIED_UNCALIBRATED_RESEARCH_ONLY; NOT_A_CONFIDENCE_GUARANTEE; JUMP_COMPONENT_EXCLUDED_FROM_TAILS"
                },
                {
                    "probability_mass":0.90,
                    "lower_log_return":-0.003,
                    "upper_log_return":0.004,
                    "method":"GAUSSIAN_MOMENT_MATCHED_FROM_FIRST_TWO_MOMENTS",
                    "status":"UNCALIBRATED_RESEARCH_ONLY_GAUSSIAN_MOMENT_MATCHED",
                    "semantics":"MODEL_IMPLIED_UNCALIBRATED_RESEARCH_ONLY; NOT_A_CONFIDENCE_GUARANTEE; JUMP_COMPONENT_EXCLUDED_FROM_TAILS"
                },
                {
                    "probability_mass":0.95,
                    "lower_log_return":-0.004,
                    "upper_log_return":0.005,
                    "method":"GAUSSIAN_MOMENT_MATCHED_FROM_FIRST_TWO_MOMENTS",
                    "status":"UNCALIBRATED_RESEARCH_ONLY_GAUSSIAN_MOMENT_MATCHED",
                    "semantics":"MODEL_IMPLIED_UNCALIBRATED_RESEARCH_ONLY; NOT_A_CONFIDENCE_GUARANTEE; JUMP_COMPONENT_EXCLUDED_FROM_TAILS"
                }
            ]
        });
    }

    fn attach_valid_market_emotion_proxy(bundle: &mut Value) {
        let cutoff = bundle["prediction_layer"][0]["observation_cutoff"].clone();
        let available_at = bundle["prediction_layer"][0]["latest_input_available_at"].clone();
        bundle["behavioral_state_layer"] = json!({
            "schema_version":"axio.behavioral-state.v3",
            "availability":"PARTIAL_PRICE_FLOW_ONLY",
            "observation_cutoff":cutoff,
            "decision_as_of":available_at,
            "latest_input_available_at":available_at,
            "input_availability_status":"VERIFIED_PROVIDER_AVAILABILITY",
            "source_scope":"MOOMOO_OPEND:test",
            "price_flow_feature_coverage_ratio":1.0,
            "required_domain_coverage_ratio":0.2,
            "affects_decision":false,
            "behavioral_regime":{
                "raw_scores":[
                    {
                        "regime":"STRESS_LIKE",
                        "raw_score":72.0,
                        "calibrated_probability":null
                    },
                    {
                        "regime":"CROWDING_LIKE",
                        "raw_score":61.0,
                        "calibrated_probability":null
                    }
                ]
            },
            "market_emotion_proxy":{
                "schema_version":"axio.market-emotion-proxy.v1",
                "publication_status":"AVAILABLE_PARTIAL_PRICE_FLOW_PROXY",
                "measurement_target":"AGGREGATE_MARKET_RESPONSE_PATTERNS",
                "measurement_semantics":"MARKET_DERIVED_PROXY_NOT_DIRECT_HUMAN_PSYCHOLOGY",
                "dominant_market_response_pattern":"STRESS_LIKE",
                "raw_compatibility_index":72.0,
                "score_margin":11.0,
                "units":"RAW_COMPATIBILITY_INDEX_0_100",
                "as_of":available_at,
                "source_scope":"MOOMOO_OPEND:test",
                "price_flow_feature_coverage_ratio":1.0,
                "required_domain_coverage_ratio":0.2,
                "calibrated_probability":null,
                "not_probability":true,
                "affects_decision":false,
                "reason_codes":[]
            }
        });
    }

    #[test]
    fn live_source_gate_binds_databento_exactly_and_rejects_non_live_variants() {
        assert!(live_source_matches_expected_provider(
            "databento",
            "DATABENTO:EQUS.MINI"
        ));
        for source in [
            "DATABENTO:EQUS.FULL",
            "DATABENTO:EQUS.MINI:REPLAY",
            "DATABENTO:EQUS.MINI:FIXTURE",
            "databento:equs.mini",
            " DATABENTO:EQUS.MINI",
            "DATABENTO:EQUS.MINI ",
            "MOOMOO_OPEND:test",
        ] {
            assert!(
                !live_source_matches_expected_provider("databento", source),
                "Databento source must be rejected: {source}"
            );
        }

        assert!(live_source_matches_expected_provider(
            "moomoo",
            "MOOMOO_OPEND:test"
        ));
        assert!(!live_source_matches_expected_provider(
            "moomoo",
            "MOOMOO_OPEND:test:fixture"
        ));
        assert!(!live_source_matches_expected_provider(
            "moomoo",
            "MOOMOO_OPEND:test:replay"
        ));
        assert!(!live_source_matches_expected_provider(
            "moomoo",
            "moomoo_opend:test"
        ));
        assert!(!live_source_matches_expected_provider(
            "moomoo",
            "DATABENTO:EQUS.MINI"
        ));
        assert!(!live_source_matches_expected_provider(
            "massive",
            "DATABENTO:EQUS.MINI"
        ));
    }

    #[test]
    fn databento_live_bundle_is_provider_bound_and_rejects_replay_or_fixture_sources() {
        let now = Utc
            .with_ymd_and_hms(2026, 7, 23, 14, 30, 30)
            .single()
            .unwrap();
        let mut valid = live_bundle_fixture(now, "live_shadow_prediction");
        valid["prediction_layer"][0]["data_source"] = json!("DATABENTO:EQUS.MINI");
        attach_valid_market_emotion_proxy(&mut valid);
        valid["behavioral_state_layer"]["source_scope"] = json!("DATABENTO:EQUS.MINI");
        valid["behavioral_state_layer"]["market_emotion_proxy"]["source_scope"] =
            json!("DATABENTO:EQUS.MINI");

        assert!(
            validate_live_forecast_bundle(&valid, "databento", "SPY", &[5, 15, 30, 60], now, 120)
                .is_ok()
        );
        assert!(
            evaluate_research_candidate(
                "databento",
                "SPY",
                &valid,
                &valid["prediction_layer"][0],
                15,
                now,
                120,
                0.60,
                2.0,
                false,
                true,
            )
            .is_ok()
        );

        let provider_mismatch =
            validate_live_forecast_bundle(&valid, "moomoo", "SPY", &[5, 15, 30, 60], now, 120)
                .unwrap_err();
        assert!(
            provider_mismatch
                .iter()
                .any(|reason| reason == "ROW_0_OFFICIAL_SDK_SOURCE_NOT_VERIFIED")
        );
        assert!(
            provider_mismatch
                .iter()
                .any(|reason| reason == "MARKET_EMOTION_PROXY_AVAILABLE_VALUE_INVALID")
        );

        for source in [
            "DATABENTO:EQUS.MINI:REPLAY",
            "DATABENTO:EQUS.MINI:FIXTURE",
            "MOOMOO_OPEND:test",
        ] {
            let mut rejected = valid.clone();
            rejected["prediction_layer"][0]["data_source"] = json!(source);
            let reasons = validate_live_forecast_bundle(
                &rejected,
                "databento",
                "SPY",
                &[5, 15, 30, 60],
                now,
                120,
            )
            .unwrap_err();
            assert!(
                reasons
                    .iter()
                    .any(|reason| reason == "ROW_0_OFFICIAL_SDK_SOURCE_NOT_VERIFIED"),
                "source must fail provider binding: {source}"
            );
            assert_eq!(
                evaluate_research_candidate(
                    "databento",
                    "SPY",
                    &rejected,
                    &rejected["prediction_layer"][0],
                    15,
                    now,
                    120,
                    0.60,
                    2.0,
                    false,
                    true,
                )
                .unwrap_err(),
                "NOT_VERIFIED_LIVE_SHADOW_EVIDENCE",
                "candidate gate must reject source: {source}"
            );
        }
    }

    #[test]
    fn strict_live_bundle_gate_rejects_legacy_and_noncausal_artifacts() {
        let now = Utc
            .with_ymd_and_hms(2026, 7, 23, 14, 30, 30)
            .single()
            .unwrap();
        let valid = live_bundle_fixture(now, "live_shadow_prediction");
        let accepted =
            validate_live_forecast_bundle(&valid, "moomoo", "SPY", &[5, 15, 30, 60], now, 120)
                .unwrap();
        assert!(accepted.maximum_forecast_age_seconds <= 30);

        let mut compatible_v41 = valid.clone();
        compatible_v41["forecast_contract_version"] = json!("4.1");
        assert!(
            validate_live_forecast_bundle(
                &compatible_v41,
                "moomoo",
                "SPY",
                &[5, 15, 30, 60],
                now,
                120
            )
            .is_ok()
        );

        let mut legacy = valid.clone();
        legacy["forecast_contract_version"] = json!("3.0");
        let legacy_reasons =
            validate_live_forecast_bundle(&legacy, "moomoo", "SPY", &[5, 15, 30, 60], now, 120)
                .unwrap_err();
        assert!(
            legacy_reasons
                .iter()
                .any(|reason| reason == "INCOMPATIBLE_FORECAST_CONTRACT_VERSION")
        );

        let mut noncausal = valid;
        noncausal["prediction_layer"][0]["latest_input_available_at"] =
            json!(now + chrono::Duration::minutes(1));
        noncausal["prediction_layer"][0]["decision_as_of"] =
            json!(now + chrono::Duration::minutes(1));
        let noncausal_reasons =
            validate_live_forecast_bundle(&noncausal, "moomoo", "SPY", &[5, 15, 30, 60], now, 120)
                .unwrap_err();
        assert!(noncausal_reasons.iter().any(|reason| {
            reason.contains("DECISION_OR_AVAILABILITY_CLOCK_INVALID")
                || reason.contains("STALE_OR_FUTURE")
        }));
    }

    #[test]
    fn market_emotion_proxy_is_validated_and_fails_closed() {
        let now = Utc
            .with_ymd_and_hms(2026, 7, 23, 14, 30, 30)
            .single()
            .unwrap();
        let mut valid = live_bundle_fixture(now, "live_shadow_prediction");
        attach_valid_market_emotion_proxy(&mut valid);
        assert!(
            validate_live_forecast_bundle(&valid, "moomoo", "SPY", &[5, 15, 30, 60], now, 120)
                .is_ok()
        );

        let mut decision_affecting = valid.clone();
        decision_affecting["behavioral_state_layer"]["market_emotion_proxy"]["affects_decision"] =
            json!(true);
        let reasons = validate_live_forecast_bundle(
            &decision_affecting,
            "moomoo",
            "SPY",
            &[5, 15, 30, 60],
            now,
            120,
        )
        .unwrap_err();
        assert!(
            reasons
                .iter()
                .any(|reason| reason == "MARKET_EMOTION_PROXY_SEMANTICS_INVALID")
        );

        let mut invented_probability = valid.clone();
        invented_probability["behavioral_state_layer"]["behavioral_regime"]["raw_scores"][0]["calibrated_probability"] =
            json!(0.72);
        let reasons = validate_live_forecast_bundle(
            &invented_probability,
            "moomoo",
            "SPY",
            &[5, 15, 30, 60],
            now,
            120,
        )
        .unwrap_err();
        assert!(
            reasons
                .iter()
                .any(|reason| { reason == "MARKET_EMOTION_PROXY_UNPROMOTED_PROBABILITY_PRESENT" })
        );

        let mut out_of_range = valid;
        out_of_range["behavioral_state_layer"]["market_emotion_proxy"]["raw_compatibility_index"] =
            json!(101.0);
        let reasons = validate_live_forecast_bundle(
            &out_of_range,
            "moomoo",
            "SPY",
            &[5, 15, 30, 60],
            now,
            120,
        )
        .unwrap_err();
        assert!(
            reasons
                .iter()
                .any(|reason| reason == "MARKET_EMOTION_PROXY_AVAILABLE_VALUE_INVALID")
        );
    }

    #[test]
    fn v43_distribution_contract_accepts_consistent_intervals_and_rejects_tampering() {
        let now = Utc
            .with_ymd_and_hms(2026, 7, 23, 14, 30, 30)
            .single()
            .unwrap();
        let mut valid = live_bundle_fixture(now, "live_shadow_prediction");
        valid["forecast_contract_version"] = json!("4.3");
        valid["prediction_layer"][0]["p_up"] = Value::Null;
        valid["prediction_layer"][0]["p_down"] = Value::Null;
        valid["prediction_layer"][0]["p_flat"] = Value::Null;
        valid["prediction_layer"][0]["stochastic_research_layer"]["horizon_forecast"] = json!({
            "horizon_minutes":15,
            "direction_probabilities":{
                "p_up":0.45,
                "p_flat":0.20,
                "p_down":0.35,
                "material_move_threshold_log_return":0.000299955,
                "method":"GAUSSIAN_MOMENT_MATCHED_FROM_FIRST_TWO_MOMENTS",
                "status":"UNCALIBRATED_RESEARCH_ONLY_GAUSSIAN_MOMENT_MATCHED",
                "semantics":"MODEL_IMPLIED_UNCALIBRATED_RESEARCH_ONLY; NOT_A_CONFIDENCE_GUARANTEE; JUMP_COMPONENT_EXCLUDED_FROM_TAILS"
            },
            "central_prediction_intervals":[
                {
                    "probability_mass":0.80,
                    "lower_log_return":-0.002,
                    "upper_log_return":0.003,
                    "method":"GAUSSIAN_MOMENT_MATCHED_FROM_FIRST_TWO_MOMENTS",
                    "status":"UNCALIBRATED_RESEARCH_ONLY_GAUSSIAN_MOMENT_MATCHED",
                    "semantics":"MODEL_IMPLIED_UNCALIBRATED_RESEARCH_ONLY; NOT_A_CONFIDENCE_GUARANTEE; JUMP_COMPONENT_EXCLUDED_FROM_TAILS"
                },
                {
                    "probability_mass":0.90,
                    "lower_log_return":-0.003,
                    "upper_log_return":0.004,
                    "method":"GAUSSIAN_MOMENT_MATCHED_FROM_FIRST_TWO_MOMENTS",
                    "status":"UNCALIBRATED_RESEARCH_ONLY_GAUSSIAN_MOMENT_MATCHED",
                    "semantics":"MODEL_IMPLIED_UNCALIBRATED_RESEARCH_ONLY; NOT_A_CONFIDENCE_GUARANTEE; JUMP_COMPONENT_EXCLUDED_FROM_TAILS"
                },
                {
                    "probability_mass":0.95,
                    "lower_log_return":-0.004,
                    "upper_log_return":0.005,
                    "method":"GAUSSIAN_MOMENT_MATCHED_FROM_FIRST_TWO_MOMENTS",
                    "status":"UNCALIBRATED_RESEARCH_ONLY_GAUSSIAN_MOMENT_MATCHED",
                    "semantics":"MODEL_IMPLIED_UNCALIBRATED_RESEARCH_ONLY; NOT_A_CONFIDENCE_GUARANTEE; JUMP_COMPONENT_EXCLUDED_FROM_TAILS"
                }
            ]
        });
        assert!(
            validate_live_forecast_bundle(&valid, "moomoo", "SPY", &[5, 15, 30, 60], now, 120)
                .is_ok()
        );

        let mut wrong_price = valid.clone();
        wrong_price["prediction_layer"][0]["expected_price"] = json!(101.0);
        let price_reasons = validate_live_forecast_bundle(
            &wrong_price,
            "moomoo",
            "SPY",
            &[5, 15, 30, 60],
            now,
            120,
        )
        .unwrap_err();
        assert!(
            price_reasons
                .iter()
                .any(|reason| { reason == "ROW_0_EXPECTED_PRICE_OR_RETURN_DEFINITION_INVALID" })
        );

        let mut wrong_probability_interval = valid;
        wrong_probability_interval["prediction_layer"][0]["kernel_regression"]["direction_probability_intervals"]
            ["up"]["estimate"] = json!(0.20);
        let probability_reasons = validate_live_forecast_bundle(
            &wrong_probability_interval,
            "moomoo",
            "SPY",
            &[5, 15, 30, 60],
            now,
            120,
        )
        .unwrap_err();
        assert!(
            probability_reasons
                .iter()
                .any(|reason| reason == "ROW_0_RAW_UP_INTERVAL_INVALID")
        );

        let mut wrong_sde = wrong_probability_interval;
        wrong_sde["prediction_layer"][0]["kernel_regression"]["direction_probability_intervals"]
            ["up"]["estimate"] = json!(0.65);
        wrong_sde["prediction_layer"][0]["stochastic_research_layer"]["horizon_forecast"]["direction_probabilities"]
            ["p_up"] = json!(0.80);
        let sde_reasons =
            validate_live_forecast_bundle(&wrong_sde, "moomoo", "SPY", &[5, 15, 30, 60], now, 120)
                .unwrap_err();
        assert!(
            sde_reasons
                .iter()
                .any(|reason| reason == "ROW_0_SDE_DISTRIBUTION_INVALID")
        );
    }

    #[test]
    fn v44_withholds_label_aligned_prices_and_validates_reference_scenario_and_cost_band() {
        let now = Utc
            .with_ymd_and_hms(2026, 7, 23, 14, 30, 30)
            .single()
            .unwrap();
        let mut valid = live_bundle_fixture(now, "live_shadow_prediction");
        upgrade_fixture_to_v44(&mut valid);
        assert!(
            validate_live_forecast_bundle(&valid, "moomoo", "SPY", &[5, 15, 30, 60], now, 120)
                .is_ok()
        );

        let mut invented_label_price = valid.clone();
        invented_label_price["prediction_layer"][0]["expected_price"] = json!(100.1);
        let price_reasons = validate_live_forecast_bundle(
            &invented_label_price,
            "moomoo",
            "SPY",
            &[5, 15, 30, 60],
            now,
            120,
        )
        .unwrap_err();
        assert!(
            price_reasons
                .iter()
                .any(|reason| reason == "ROW_0_EXPECTED_PRICE_OR_RETURN_DEFINITION_INVALID")
        );

        let mut mislabeled_scenario = valid.clone();
        mislabeled_scenario["prediction_layer"][0]["current_close_reference_scenario_expected_price"] =
            json!(101.0);
        let scenario_reasons = validate_live_forecast_bundle(
            &mislabeled_scenario,
            "moomoo",
            "SPY",
            &[5, 15, 30, 60],
            now,
            120,
        )
        .unwrap_err();
        assert!(
            scenario_reasons
                .iter()
                .any(|reason| reason == "ROW_0_EXPECTED_PRICE_OR_RETURN_DEFINITION_INVALID")
        );

        let mut decision_affecting_sde = valid.clone();
        decision_affecting_sde["prediction_layer"][0]["stochastic_research_layer"]["affects_decision"] =
            json!(true);
        let neutrality_reasons = validate_live_forecast_bundle(
            &decision_affecting_sde,
            "moomoo",
            "SPY",
            &[5, 15, 30, 60],
            now,
            120,
        )
        .unwrap_err();
        assert!(
            neutrality_reasons
                .iter()
                .any(|reason| reason == "ROW_0_SDE_MUST_BE_DECISION_NEUTRAL")
        );

        let mut missing_sde_distribution = valid.clone();
        missing_sde_distribution["prediction_layer"][0]["stochastic_research_layer"]["horizon_forecast"] =
            Value::Null;
        let missing_sde_reasons = validate_live_forecast_bundle(
            &missing_sde_distribution,
            "moomoo",
            "SPY",
            &[5, 15, 30, 60],
            now,
            120,
        )
        .unwrap_err();
        assert!(
            missing_sde_reasons
                .iter()
                .any(|reason| reason == "ROW_0_SDE_DISTRIBUTION_ABSENT")
        );

        let mut symmetric_log_band = valid;
        symmetric_log_band["prediction_layer"][0]["stochastic_research_layer"]["horizon_forecast"]
            ["direction_probabilities"]["material_move_lower_threshold_log_return"] =
            json!(-0.0003_f64.ln_1p());
        let sde_reasons = validate_live_forecast_bundle(
            &symmetric_log_band,
            "moomoo",
            "SPY",
            &[5, 15, 30, 60],
            now,
            120,
        )
        .unwrap_err();
        assert!(
            sde_reasons
                .iter()
                .any(|reason| reason == "ROW_0_SDE_DISTRIBUTION_INVALID")
        );
    }

    #[test]
    fn mixed_live_bundle_accepts_batch_rows_but_candidate_gate_rejects_them() {
        let now = Utc
            .with_ymd_and_hms(2026, 7, 23, 14, 30, 30)
            .single()
            .unwrap();
        let live = live_bundle_fixture(now, "live_shadow_prediction");
        let batch = live_bundle_fixture(now, "batch_research_prediction");
        let mut mixed = live.clone();
        let mut batch_row = batch["prediction_layer"][0].clone();
        batch_row["horizon_minutes"] = json!(60);
        let cutoff = parse_utc(batch_row.get("observation_cutoff")).unwrap();
        batch_row["label_end"] = json!(cutoff + chrono::Duration::minutes(60));
        mixed["prediction_layer"]
            .as_array_mut()
            .unwrap()
            .push(batch_row.clone());
        validate_live_forecast_bundle(&mixed, "moomoo", "SPY", &[5, 15, 30, 60], now, 120).unwrap();

        let result = evaluate_research_candidate(
            "moomoo", "SPY", &mixed, &batch_row, 60, now, 120, 0.60, 2.0, false, true,
        );
        assert_eq!(result.unwrap_err(), "NOT_VERIFIED_LIVE_SHADOW_EVIDENCE");
    }

    #[test]
    fn research_candidate_lineage_gate_rejects_unledgered_live_row() {
        let now = Utc
            .with_ymd_and_hms(2026, 7, 23, 14, 30, 30)
            .single()
            .unwrap();
        let bundle = live_bundle_fixture(now, "live_shadow_prediction");
        let row = &bundle["prediction_layer"][0];
        let directory = tempfile::tempdir().unwrap();

        assert!(!live_prediction_is_ledger_backed(
            directory.path(),
            "moomoo",
            row
        ));
    }

    #[test]
    fn opportunity_candidate_labels_raw_frequency_and_withholds_uncalibrated_probability() {
        let now = Utc
            .with_ymd_and_hms(2026, 7, 23, 14, 30, 30)
            .single()
            .unwrap();
        let bundle = live_bundle_fixture(now, "live_shadow_prediction");
        let row = &bundle["prediction_layer"][0];
        let candidate = evaluate_research_candidate(
            "moomoo", "SPY", &bundle, row, 15, now, 120, 0.60, 2.0, false, true,
        )
        .unwrap();
        assert_eq!(
            candidate.value.get("probability_up_percent"),
            Some(&Value::Null)
        );
        assert_eq!(
            candidate.value.get("conditional_probability_percent"),
            Some(&Value::Null)
        );
        assert_eq!(
            candidate
                .value
                .get("conditional_frequency_estimate_percent"),
            Some(&json!(65.0))
        );
        assert_eq!(
            candidate.value.get("conditional_probability_kind"),
            Some(&json!("UNCALIBRATED_KERNEL_WEIGHTED_HISTORICAL_FREQUENCY"))
        );
        assert_eq!(
            candidate.value.get("expected_move_percent"),
            Some(&json!(0.1))
        );
        assert!(!contains_forbidden_research_key(&candidate.value));
        assert_eq!(
            candidate.value.pointer("/gamma_feedback_risk/claim_policy"),
            Some(&json!(
                "NO_GAMMA_SQUEEZE_CLAIM_WITHOUT_FRESH_POINT_IN_TIME_OPTION_CHAIN_OI_AND_GREEKS"
            ))
        );
        let public_row = uncalibrated_scan_candidate_projection(&candidate, "moomoo");
        let scan = json!({
            "live_feed":{"provider":"moomoo"},
            "ranked_statistical_candidates":[public_row]
        });
        let projected = generic_statistical_candidates(
            MarketSetupType::StatisticalDislocation,
            &scan,
            &["SPY".to_string()],
        );
        assert_eq!(projected.len(), 1);
        assert_eq!(projected[0].status, "UNCALIBRATED_RESEARCH_OUTPUT");
        assert_eq!(projected[0].heuristic_structure_score, None);
        for key in [
            "conditional_probability_percent",
            "conditional_frequency_estimate_percent",
            "raw_analog_up_frequency_percent",
            "raw_analog_down_frequency_percent",
            "raw_analog_flat_frequency_percent",
            "expected_move_percent",
            "expected_price",
            "research_rank_score",
            "regime",
            "model_committee",
        ] {
            assert!(
                projected[0].metrics.get(key).is_none(),
                "public uncalibrated projection leaked {key}"
            );
        }
        assert!(projected[0].metrics.get("probability_up_percent").is_none());
        assert_eq!(projected[0].freshness[0].coverage, Some(1.0));
        assert!(projected[0].contrary_evidence.len() >= 3);
        let expected_observed_at = parse_utc(row.get("observation_cutoff"));
        let expected_available_at = parse_utc(row.get("latest_input_available_at"));
        assert_eq!(projected[0].freshness[0].observed_at, expected_observed_at);
        assert_eq!(
            projected[0].freshness[0].available_at,
            expected_available_at
        );
        assert_ne!(expected_observed_at, expected_available_at);
        assert_eq!(
            projected[0].metrics.get("observation_cutoff"),
            row.get("observation_cutoff")
        );
        assert_eq!(
            projected[0].metrics.get("latest_input_available_at"),
            row.get("latest_input_available_at")
        );
        assert_eq!(
            projected[0].metrics.pointer("/validation/model_version"),
            Some(&json!("test-model"))
        );
        assert_eq!(
            projected[0].metrics.pointer("/validation/feature_version"),
            Some(&json!("test-feature-v1"))
        );
        assert_eq!(
            projected[0].metrics.pointer("/validation/model_hash"),
            Some(&json!("a".repeat(64)))
        );
    }

    #[test]
    fn uncalibrated_direction_is_not_silenced_by_probability_publication_thresholds() {
        let now = Utc
            .with_ymd_and_hms(2026, 7, 23, 14, 30, 30)
            .single()
            .unwrap();
        let mut bundle = live_bundle_fixture(now, "live_shadow_prediction");
        bundle["prediction_layer"][0]["expected_return"] = json!(0.000001);
        bundle["prediction_layer"][0]["raw_analog_up_frequency"] = json!(0.34);
        bundle["prediction_layer"][0]["raw_analog_down_frequency"] = json!(0.33);
        bundle["prediction_layer"][0]["raw_analog_flat_frequency"] = json!(0.33);
        let row = &bundle["prediction_layer"][0];

        let candidate = evaluate_research_candidate(
            "moomoo", "SPY", &bundle, row, 15, now, 120, 0.60, 2.0, false, true,
        )
        .expect("fresh uncalibrated direction should remain visible");

        assert!(!candidate.validated);
        assert_eq!(
            candidate.value.get("statistical_orientation"),
            Some(&json!("POSITIVE_CONDITIONAL_MEAN"))
        );
    }

    #[test]
    fn uncalibrated_public_scan_neither_ranks_nor_survives_unverified_feed() {
        let row = |symbol: &str| {
            json!({
                "symbol":symbol,
                "horizon_minutes":15,
                "statistical_orientation":"POSITIVE_CONDITIONAL_MEAN",
                "observation_cutoff":"2026-07-23T14:30:00Z",
                "latest_input_available_at":"2026-07-23T14:30:01Z",
                "data_age_seconds":1,
                "research_rank_score":999.0,
                "expected_move_percent":42.0,
                "published_probability_status":"WITHHELD_NO_MATCHING_PROMOTED_OOS_CALIBRATION",
                "validation":{
                    "model_version":"model-v3",
                    "feature_version":"feature-v4",
                    "model_hash":"a".repeat(64),
                    "feature_hash":"b".repeat(64),
                    "data_manifest_hash":"c".repeat(64)
                }
            })
        };
        let candidates = vec![
            RankedResearchCandidate {
                rank_score: 999.0,
                symbol: "ZZZ".to_string(),
                validated: false,
                value: row("ZZZ"),
            },
            RankedResearchCandidate {
                rank_score: 1.0,
                symbol: "AAA".to_string(),
                validated: false,
                value: row("AAA"),
            },
        ];

        let projected = project_public_scan_candidates(candidates, 1, "moomoo", true);
        assert_eq!(projected.len(), 1);
        assert_eq!(projected[0].get("symbol"), Some(&json!("AAA")));
        assert!(projected[0].get("research_rank").is_none());
        assert!(projected[0].get("research_rank_score").is_none());
        assert!(projected[0].get("expected_move_percent").is_none());
        assert!(project_public_scan_candidates(Vec::new(), 1, "moomoo", false).is_empty());
        assert_eq!(effective_maximum_age_seconds(Some(1), 120), 1);
        assert_eq!(effective_maximum_age_seconds(Some(3_600), 120), 120);
    }

    #[test]
    fn direct_symbol_empty_scan_promotes_only_its_exact_exclusion_to_a_blocker() {
        let scan = json!({
            "status":"IMPERSONAL_REALTIME_RESEARCH_SCAN",
            "exclusions":[
                {"symbol":"NVDA","reason":"FORECAST_ARTIFACT_ABSENT"},
                {"symbol":"AAPL","reason":"STALE_OR_INCOMPATIBLE_LIVE_ARTIFACT"}
            ]
        });
        let mappings = BTreeMap::from([
            ("NVDA".to_string(), "NVDA".to_string()),
            ("AAPL".to_string(), "AAPL".to_string()),
        ]);

        let blockers =
            requested_statistical_exclusion_blockers(&scan, &["NVDA".to_string()], &mappings);

        assert_eq!(blockers, vec!["NVDA:FORECAST_ARTIFACT_ABSENT".to_string()]);
        assert!(blockers.iter().all(|blocker| !blocker.contains("AAPL")));
    }

    #[test]
    fn opportunity_candidate_rejects_legacy_promoted_probability_bypasses() {
        let now = Utc
            .with_ymd_and_hms(2026, 7, 23, 14, 30, 30)
            .single()
            .unwrap();
        for contract_version in ["4.1", "4.2"] {
            let mut promoted = live_bundle_fixture(now, "live_shadow_prediction");
            promoted["forecast_contract_version"] = json!(contract_version);
            promoted["prediction_layer"][0]["p_up"] = json!(0.72);
            promoted["prediction_layer"][0]["calibration_status"] =
                json!(PROMOTED_PROBABILITY_CALIBRATION_STATUS);
            promoted["prediction_layer"][0]["calibrated_probability_up"] = json!(0.72);
            promoted["prediction_layer"][0]["probability_calibration"] = json!({
                "status":PROMOTED_PROBABILITY_CALIBRATION_STATUS,
                "eligible_for_probability_use":true,
                "calibrated_probability_up":0.72,
                "reasons":[]
            });
            assert!(
                validate_live_forecast_bundle(
                    &promoted,
                    "moomoo",
                    "SPY",
                    &[5, 15, 30, 60],
                    now,
                    120
                )
                .is_ok()
            );
            let promoted_candidate = evaluate_research_candidate(
                "moomoo",
                "SPY",
                &promoted,
                &promoted["prediction_layer"][0],
                15,
                now,
                120,
                0.60,
                2.0,
                true,
                false,
            )
            .unwrap();
            assert!(promoted_candidate.validated);
            assert_eq!(
                promoted_candidate.value.get("probability_up_percent"),
                Some(&json!(72.0))
            );

            for tampering in ["eligibility", "status", "value", "reasons"] {
                let mut malformed = promoted.clone();
                match tampering {
                    "eligibility" => {
                        malformed["prediction_layer"][0]["probability_calibration"]["eligible_for_probability_use"] =
                            json!(false);
                    }
                    "status" => {
                        malformed["prediction_layer"][0]["calibration_status"] =
                            json!("OOS_VALIDATED");
                        malformed["prediction_layer"][0]["probability_calibration"]["status"] =
                            json!("OOS_VALIDATED");
                    }
                    "value" => {
                        malformed["prediction_layer"][0]["calibrated_probability_up"] = json!(0.71);
                    }
                    "reasons" => {
                        malformed["prediction_layer"][0]["probability_calibration"]["reasons"] =
                            json!(["LIFECYCLE_NOT_PROMOTED_OOS"]);
                    }
                    _ => unreachable!(),
                }
                assert!(
                    validate_live_forecast_bundle(
                        &malformed,
                        "moomoo",
                        "SPY",
                        &[5, 15, 30, 60],
                        now,
                        120
                    )
                    .is_ok(),
                    "legacy contract {contract_version} fixture should reach the candidate guard"
                );
                let candidate = evaluate_research_candidate(
                    "moomoo",
                    "SPY",
                    &malformed,
                    &malformed["prediction_layer"][0],
                    15,
                    now,
                    120,
                    0.60,
                    2.0,
                    true,
                    true,
                )
                .unwrap();
                assert!(!candidate.validated, "tampering={tampering}");
                assert_eq!(
                    candidate.value.get("probability_up_percent"),
                    Some(&Value::Null),
                    "tampering={tampering}"
                );
                assert_eq!(
                    candidate.value.get("calibrated_probability_up_percent"),
                    Some(&Value::Null),
                    "tampering={tampering}"
                );
                assert_eq!(
                    candidate.value.get("published_probability_status"),
                    Some(&json!("WITHHELD_NO_MATCHING_PROMOTED_OOS_CALIBRATION")),
                    "tampering={tampering}"
                );
                let excluded = evaluate_research_candidate(
                    "moomoo",
                    "SPY",
                    &malformed,
                    &malformed["prediction_layer"][0],
                    15,
                    now,
                    120,
                    0.60,
                    2.0,
                    true,
                    false,
                );
                assert_eq!(
                    excluded.unwrap_err(),
                    "UNVALIDATED_SHADOW_CANDIDATE_EXCLUDED_BY_QUERY"
                );
            }
        }
    }

    #[test]
    fn public_forecast_projection_strips_advice_and_execution_fields() {
        let raw = json!({
            "status":"PAPER_CANDIDATE",
            "gamma_convexity_layer":{"availability":"unavailable"},
            "option_execution_layer":{"side":"BUY","qty":2},
            "prediction_layer":[{
                "expected_return":0.001,
                "p_up":0.61,
                "stochastic_research_layer":{"status":"SHADOW_ONLY"},
                "return_quantiles":[{"probability":0.5,"value":0.0002}],
                "calibration_status":"UNVALIDATED_CANDIDATE",
                "suggested_direction":1,
                "strategy_win_probability":0.61,
                "decision":{
                    "action":"PAPER_LONG_CANDIDATE",
                    "eligible":true,
                    "expected_edge_after_cost":0.0008,
                    "no_trade_reasons":["MODEL_NOT_PROMOTED_NO_OOS_EDGE"]
                }
            }]
        });
        let projected = public_research_forecast_projection(raw);
        assert!(!contains_forbidden_research_key(&projected));
        assert_eq!(
            projected.pointer("/prediction_layer/0/research_status"),
            Some(&json!("NO_VALIDATED_EDGE"))
        );
        assert_eq!(
            projected.pointer("/prediction_layer/0/statistical_condition"),
            Some(&json!("POSITIVE_CONDITIONAL_MEAN"))
        );
        assert_eq!(
            projected.pointer("/prediction_layer/0/p_up"),
            Some(&Value::Null)
        );
        assert_eq!(
            projected.pointer("/prediction_layer/0/published_probability_status"),
            Some(&json!("WITHHELD_NO_MATCHING_PROMOTED_OOS_CALIBRATION"))
        );
        assert_eq!(
            projected.pointer("/research_only_policy/personalization_used"),
            Some(&json!(false))
        );
        assert_eq!(
            projected.pointer("/gamma_convexity_layer/availability"),
            Some(&json!("unavailable"))
        );
        assert_eq!(
            projected.pointer("/prediction_layer/0/stochastic_research_layer/status"),
            Some(&json!("SHADOW_ONLY"))
        );
        assert!(projected.get("option_execution_layer").is_none());
    }

    #[test]
    fn public_projection_publishes_only_promoted_binary_up_probability() {
        let raw = json!({
            "prediction_layer":[{
                "expected_return":0.001,
                "p_up":0.99,
                "p_down":0.005,
                "p_flat":0.005,
                "calibration_status":"PROMOTED_OOS_CALIBRATION_APPLIED",
                "calibrated_probability_up":0.72,
                "probability_calibration":{
                    "status":"PROMOTED_OOS_CALIBRATION_APPLIED",
                    "eligible_for_probability_use":true,
                    "calibrated_probability_up":0.72,
                    "reasons":[]
                },
                "decision":{"no_trade_reasons":[]}
            }]
        });
        let projected = public_research_forecast_projection(raw);
        assert_eq!(
            projected.pointer("/prediction_layer/0/p_up"),
            Some(&json!(0.72))
        );
        assert_eq!(
            projected.pointer("/prediction_layer/0/p_down"),
            Some(&Value::Null)
        );
        assert_eq!(
            projected.pointer("/prediction_layer/0/p_flat"),
            Some(&Value::Null)
        );
        assert_eq!(
            projected.pointer("/prediction_layer/0/published_probability_status"),
            Some(&json!(
                "PROMOTED_BINARY_UP_ONLY_NO_JOINT_MULTICLASS_CALIBRATION"
            ))
        );
    }

    #[test]
    fn owner_projection_clears_nested_calibration_values() {
        let mut projected = public_research_forecast_projection(json!({
            "prediction_layer":[{
                "p_up":0.8,
                "calibrated_probability_up":0.8,
                "probability_calibration":{
                    "artifact_id":"secret-calibrator",
                    "method":"ISOTONIC",
                    "eligible_for_probability_use":true,
                    "calibrated_probability_up":0.8,
                    "calibrated_probability_up_interval":{"estimate":0.8},
                    "oos_metrics":{"brier_score":0.1}
                },
                "decision":{"no_trade_reasons":[]}
            }]
        }));
        withhold_owner_probability_fields(&mut projected);
        for pointer in [
            "/prediction_layer/0/p_up",
            "/prediction_layer/0/calibrated_probability_up",
            "/prediction_layer/0/probability_calibration/artifact_id",
            "/prediction_layer/0/probability_calibration/calibrated_probability_up",
            "/prediction_layer/0/probability_calibration/calibrated_probability_up_interval",
            "/prediction_layer/0/probability_calibration/oos_metrics",
        ] {
            assert_eq!(projected.pointer(pointer), Some(&Value::Null), "{pointer}");
        }
        assert_eq!(
            projected.pointer(
                "/prediction_layer/0/probability_calibration/eligible_for_probability_use"
            ),
            Some(&json!(false))
        );
    }

    #[test]
    fn public_v44_projection_keeps_reference_scenario_but_withholds_expected_price() {
        let raw = json!({
            "forecast_contract_version":"4.4",
            "prediction_layer":[{
                "expected_return":0.001,
                "expected_price":100.1,
                "current_close_reference_scenario_expected_price":100.1,
                "current_close_reference_scenario_basis":CURRENT_CLOSE_SCENARIO_BASIS,
                "current_close_reference_scenario_status":CURRENT_CLOSE_SCENARIO_STATUS,
                "current_close_reference_scenario_semantics":CURRENT_CLOSE_SCENARIO_SEMANTICS,
                "probability_calibration":{
                    "eligible_for_probability_use":false,
                    "calibrated_probability_up":null
                },
                "decision":{"no_trade_reasons":["RESEARCH_ONLY_NO_TRADE"]}
            }]
        });
        let projected = public_research_forecast_projection(raw);
        assert_eq!(
            projected.pointer("/prediction_layer/0/expected_price"),
            Some(&Value::Null)
        );
        assert_eq!(
            projected
                .pointer("/prediction_layer/0/current_close_reference_scenario_expected_price"),
            Some(&json!(100.1))
        );
        assert_eq!(
            projected.pointer("/prediction_layer/0/current_close_reference_scenario_status"),
            Some(&json!(CURRENT_CLOSE_SCENARIO_STATUS))
        );
    }

    #[test]
    fn public_projection_rejects_legacy_probability_publication_bypasses() {
        let cases = [
            (
                false,
                "PROMOTED_OOS_CALIBRATION_APPLIED",
                "PROMOTED_OOS_CALIBRATION_APPLIED",
                0.72,
                0.72,
            ),
            (true, "OOS_VALIDATED", "OOS_VALIDATED", 0.72, 0.72),
            (
                true,
                "PROMOTED_OOS_CALIBRATION_APPLIED",
                "PROMOTED_OOS_CALIBRATION_APPLIED",
                0.72,
                0.71,
            ),
        ];
        for contract_version in ["4.1", "4.2"] {
            for (eligible, runtime_status, contract_status, runtime_value, contract_value) in cases
            {
                let raw = json!({
                    "forecast_contract_version":contract_version,
                    "prediction_layer":[{
                        "expected_return":0.001,
                        "p_up":0.99,
                        "calibration_status":contract_status,
                        "calibrated_probability_up":contract_value,
                        "probability_calibration":{
                            "status":runtime_status,
                            "eligible_for_probability_use":eligible,
                            "calibrated_probability_up":runtime_value,
                            "reasons":[]
                        },
                        "decision":{"no_trade_reasons":[]}
                    }]
                });
                let projected = public_research_forecast_projection(raw);
                assert_eq!(
                    projected.pointer("/prediction_layer/0/p_up"),
                    Some(&Value::Null),
                    "legacy contract {contract_version} published an invalid probability"
                );
                assert_eq!(
                    projected.pointer("/prediction_layer/0/published_probability_status"),
                    Some(&json!("WITHHELD_NO_MATCHING_PROMOTED_OOS_CALIBRATION"))
                );
                assert_eq!(
                    projected.pointer("/prediction_layer/0/research_status"),
                    Some(&json!("NO_VALIDATED_EDGE"))
                );
            }
        }
    }

    #[test]
    fn control_token_comparison_requires_exact_value() {
        let token = "0123456789abcdef0123456789abcdef";
        assert!(constant_time_token_match(token, token));
        assert!(!constant_time_token_match(
            token,
            "0123456789abcdef0123456789abcdeg"
        ));
        assert!(!constant_time_token_match(token, "short"));
    }

    #[test]
    fn model_lineage_hashes_require_nonzero_sha256() {
        assert!(valid_nonzero_sha256(&"a".repeat(64)));
        assert!(valid_nonzero_sha256(&"F".repeat(64)));
        assert!(!valid_nonzero_sha256(&"0".repeat(64)));
        assert!(!valid_nonzero_sha256(&"g".repeat(64)));
        assert!(!valid_nonzero_sha256("short"));
    }

    #[test]
    fn only_health_reads_bypass_control_plane_authentication() {
        assert!(is_public_health_request(&Method::GET, "/health"));
        assert!(is_public_health_request(&Method::HEAD, "/health"));
        assert!(is_public_health_request(&Method::GET, "/ready"));
        assert!(is_public_health_request(&Method::HEAD, "/ready"));
        assert!(!is_public_health_request(&Method::GET, "/api/v1/system"));
        assert!(!is_public_health_request(&Method::POST, "/health"));
        assert!(!is_public_health_request(&Method::POST, "/ready"));
        assert!(!is_public_health_request(&Method::OPTIONS, "/health"));
    }

    #[test]
    fn live_readiness_requires_fresh_authenticated_entitled_supervisor() {
        let now = Utc.with_ymd_and_hms(2026, 7, 26, 15, 0, 0).unwrap();
        let mut status = json!({
            "updated_at":now,
            "state":"STREAMING_REALTIME",
            "authenticated":true,
            "entitlement_verified":true
        });
        let (ready, reasons) = evaluate_live_supervisor_status(
            "databento",
            &status,
            now + chrono::Duration::seconds(5),
            30_000,
        );
        assert!(ready);
        assert!(reasons.is_empty());

        status["state"] = json!("FAIL_CLOSED_RECONNECTING");
        status["authenticated"] = json!(false);
        status["entitlement_verified"] = json!(false);
        let (ready, reasons) = evaluate_live_supervisor_status(
            "databento",
            &status,
            now + chrono::Duration::seconds(5),
            30_000,
        );
        assert!(!ready);
        assert!(reasons.contains(&"DATABENTO_STREAM_NOT_RUNNING".to_string()));
        assert!(reasons.contains(&"DATABENTO_NOT_AUTHENTICATED".to_string()));
        assert!(reasons.contains(&"DATABENTO_ENTITLEMENT_NOT_VERIFIED".to_string()));
    }

    #[test]
    fn live_readiness_rejects_stale_or_timestamp_free_status() {
        let now = Utc.with_ymd_and_hms(2026, 7, 26, 15, 0, 0).unwrap();
        let stale = json!({
            "updated_at":now - chrono::Duration::minutes(5),
            "state":"STREAMING_REALTIME",
            "authenticated":true
        });
        let (ready, reasons) = evaluate_live_supervisor_status("massive", &stale, now, 30_000);
        assert!(!ready);
        assert!(reasons.contains(&"LIVE_SUPERVISOR_STATUS_STALE".to_string()));

        let timestamp_free = json!({
            "state":"STREAMING_REALTIME",
            "authenticated":true
        });
        let (ready, reasons) =
            evaluate_live_supervisor_status("massive", &timestamp_free, now, 30_000);
        assert!(!ready);
        assert!(reasons.contains(&"LIVE_SUPERVISOR_STATUS_TIMESTAMP_MISSING".to_string()));
    }

    #[test]
    fn live_readiness_rejects_nonempty_or_malformed_supervisor_blocker() {
        let now = Utc.with_ymd_and_hms(2026, 7, 26, 15, 0, 0).unwrap();
        let base = json!({
            "updated_at":now,
            "state":"STREAMING_REALTIME",
            "authenticated":true
        });
        let (ready, reasons) = evaluate_live_supervisor_status("massive", &base, now, 30_000);
        assert!(ready);
        assert!(reasons.is_empty());

        let mut blocked = base.clone();
        blocked["blocker"] = json!("STALE_DATABENTO_BAR_REJECTED");
        let (ready, reasons) = evaluate_live_supervisor_status("massive", &blocked, now, 30_000);
        assert!(!ready);
        assert!(reasons.contains(&"LIVE_SUPERVISOR_BLOCKED".to_string()));

        blocked["blocker"] = json!({"unexpected":"shape"});
        let (ready, reasons) = evaluate_live_supervisor_status("massive", &blocked, now, 30_000);
        assert!(!ready);
        assert!(reasons.contains(&"LIVE_SUPERVISOR_BLOCKED".to_string()));

        blocked["blocker"] = json!("   ");
        assert!(evaluate_live_supervisor_status("massive", &blocked, now, 30_000).0);
    }

    #[test]
    fn public_observation_gate_requires_entitlement_and_fresh_stream_and_feed() {
        let mut receipt = ready_public_research_receipt();
        assert!(public_observation_readiness_blockers("databento", &receipt).is_empty());

        receipt.status = OverallReadiness::Blocked;
        receipt.public_realtime_research_ready = false;
        receipt.market_data.provider_entitlement = EvidenceStatus::Blocked;
        receipt.market_data.stream_freshness = FreshnessStatus::Stale;
        receipt.market_data.feed_freshness = FreshnessStatus::Unavailable;
        let blockers = public_observation_readiness_blockers("databento", &receipt);
        assert!(
            blockers.contains(&"PUBLIC_MARKET_DATA_PROVIDER_ENTITLEMENT_NOT_READY".to_string())
        );
        assert!(blockers.contains(&"PUBLIC_MARKET_DATA_STREAM_NOT_FRESH".to_string()));
        assert!(blockers.contains(&"PUBLIC_MARKET_DATA_FINALIZED_FEED_NOT_FRESH".to_string()));
        assert!(!blockers.contains(&"PUBLIC_REALTIME_RESEARCH_READINESS_BLOCKED".to_string()));
    }

    #[test]
    fn probability_publication_gate_requires_active_pinned_promotion_and_calibration() {
        let mut receipt = ready_public_research_receipt();
        receipt.status = OverallReadiness::Blocked;
        receipt.public_realtime_research_ready = false;
        receipt.artifacts.promotion_registry_present = false;
        receipt.artifacts.promotion_registry_status = PromotionRegistryStatus::Absent;
        receipt.artifacts.calibration_registry_present = false;
        receipt.artifacts.calibration_registry_status = CalibrationRegistryStatus::Absent;
        assert!(public_observation_readiness_blockers("databento", &receipt).is_empty());
        let blockers = probability_publication_readiness_blockers(&receipt);
        assert!(blockers.contains(&"MODEL_PROMOTION_REGISTRY_NOT_ACTIVE_PINNED".to_string()));
        assert!(blockers.contains(&"MODEL_CALIBRATION_REGISTRY_NOT_PROMOTED".to_string()));
        assert!(blockers.contains(&"PUBLIC_REALTIME_RESEARCH_READINESS_BLOCKED".to_string()));
    }

    #[test]
    fn observation_and_probability_gates_keep_provider_and_forecast_checks_separate() {
        let mut receipt = ready_public_research_receipt();
        receipt.status = OverallReadiness::Blocked;
        receipt.public_realtime_research_ready = false;
        receipt.forecasts[0].ready = false;
        let observation_blockers = public_observation_readiness_blockers("massive", &receipt);
        let probability_blockers = probability_publication_readiness_blockers(&receipt);
        assert!(observation_blockers.contains(&"PUBLIC_MARKET_DATA_PROVIDER_MISMATCH".to_string()));
        assert!(!observation_blockers.contains(&"PRODUCTION_FORECASTS_NOT_READY".to_string()));
        assert!(probability_blockers.contains(&"PRODUCTION_FORECASTS_NOT_READY".to_string()));
    }

    #[test]
    fn model_runtime_connection_is_separate_from_quality_and_publication() {
        assert_eq!(model_runtime_status(9, 9, 0), "LOADED");
        assert_eq!(model_runtime_status(9, 8, 1), "PARTIAL");
        assert_eq!(model_runtime_status(9, 0, 9), "UNAVAILABLE");
        assert_eq!(model_runtime_status(0, 0, 0), "UNAVAILABLE");
    }

    #[test]
    fn calibrated_full_distribution_forms_allocation_scenarios() {
        let row = json!({
            "allocation_distribution_status":"OOS_CALIBRATED_FULL_DISTRIBUTION",
            "tail_model_status":"OOS_VALIDATED",
            "allocation_scenarios":[
                {"kind":"LOWER_TAIL","probability":0.05,"return_fraction":-0.08},
                {"kind":"BODY","probability":0.20,"return_fraction":-0.02},
                {"kind":"BODY","probability":0.50,"return_fraction":0.0},
                {"kind":"BODY","probability":0.20,"return_fraction":0.03},
                {"kind":"UPPER_TAIL","probability":0.05,"return_fraction":0.10}
            ]
        });
        let scenarios = scenarios_from_allocation_distribution(&row).unwrap();
        assert_eq!(scenarios.len(), 5);
        assert!((scenarios.iter().map(|row| row.probability).sum::<f64>() - 1.0).abs() < 1.0e-12);
    }

    #[test]
    fn sparse_quantiles_are_rejected_for_kelly_allocation() {
        let row = json!({
            "return_quantiles":[
                {"probability":0.1,"value":-0.02},
                {"probability":0.5,"value":0.0},
                {"probability":0.9,"value":0.03}
            ]
        });
        assert!(scenarios_from_allocation_distribution(&row).is_err());
    }

    #[test]
    fn forecast_and_inputs_must_be_fresh_and_causally_ordered() {
        let now = chrono::Utc
            .with_ymd_and_hms(2026, 7, 21, 15, 30, 0)
            .unwrap();
        let forecast = now - chrono::Duration::seconds(30);
        assert_eq!(
            forecast_timestamps_are_fresh_and_causal(
                forecast,
                Some(forecast - chrono::Duration::seconds(1)),
                now,
                300,
            ),
            (true, true)
        );
        assert_eq!(
            forecast_timestamps_are_fresh_and_causal(
                forecast,
                Some(forecast + chrono::Duration::seconds(1)),
                now,
                300,
            ),
            (true, false)
        );
        assert_eq!(
            forecast_timestamps_are_fresh_and_causal(
                now + chrono::Duration::seconds(1),
                Some(now),
                now,
                300,
            ),
            (false, true)
        );
    }

    #[test]
    fn allocation_distribution_without_explicit_tail_buckets_is_rejected() {
        let row = json!({
            "allocation_distribution_status":"OOS_CALIBRATED_FULL_DISTRIBUTION",
            "tail_model_status":"OOS_VALIDATED",
            "allocation_scenarios":[
                {"kind":"BODY","probability":0.1,"return_fraction":-0.03},
                {"kind":"BODY","probability":0.2,"return_fraction":-0.01},
                {"kind":"BODY","probability":0.4,"return_fraction":0.0},
                {"kind":"BODY","probability":0.2,"return_fraction":0.01},
                {"kind":"BODY","probability":0.1,"return_fraction":0.03}
            ]
        });
        assert!(scenarios_from_allocation_distribution(&row).is_err());
    }

    #[test]
    fn allocation_requires_consistent_distribution_mean_and_validated_cost() {
        let scenarios = vec![
            crate::allocation::ScenarioOutcome {
                probability: 0.5,
                return_fraction: -0.01,
            },
            crate::allocation::ScenarioOutcome {
                probability: 0.5,
                return_fraction: 0.02,
            },
        ];
        let row = json!({
            "expected_return":0.005,
            "decision":{
                "cost_model_status":"CONSERVATIVE_BOUND",
                "estimated_round_trip_cost_bps":3.5
            }
        });
        assert!(forecast_distribution_mean_matches(&row, &scenarios));
        assert_eq!(validated_round_trip_cost_bps(&row), Some(3.5));

        let mismatched = json!({
            "expected_return":0.05,
            "decision":{
                "cost_model_status":"UNVALIDATED",
                "estimated_round_trip_cost_bps":-1.0
            }
        });
        assert!(!forecast_distribution_mean_matches(&mismatched, &scenarios));
        assert_eq!(validated_round_trip_cost_bps(&mismatched), None);
    }

    #[test]
    fn independent_risk_snapshot_must_match_runtime_portfolio() {
        let as_of = chrono::Utc
            .with_ymd_and_hms(2026, 7, 21, 15, 30, 0)
            .unwrap();
        let runtime = crate::os_domain::PortfolioSnapshot {
            as_of,
            cash: 95_000.0,
            equity: 100_000.0,
            gross_exposure: 0.05,
            net_exposure: 0.05,
            positions: vec![crate::os_domain::Position {
                symbol: "SPY".into(),
                quantity: 10.0,
                average_price: 490.0,
                mark_price: 500.0,
                realized_pnl: 0.0,
                unrealized_pnl: 100.0,
            }],
        };
        let mut input = crate::portfolio_risk::PortfolioRiskInput {
            as_of,
            observed_at: None,
            source_content_sha256: None,
            equity: 100_000.0,
            peak_equity: 100_000.0,
            day_start_equity: 100_000.0,
            positions: vec![crate::portfolio_risk::PositionRiskInput {
                symbol: " spy ".into(),
                market_value: 5_000.0,
                observed_at: None,
                source_content_sha256: None,
                average_daily_dollar_volume: 1_000_000.0,
                adv_as_of: None,
                adv_source_content_sha256: None,
                beta: 1.0,
                factor_loadings: BTreeMap::new(),
            }],
            historical_portfolio_returns: Vec::new(),
            history_as_of: None,
            history_source_content_sha256: None,
            stress_scenarios: Vec::new(),
            stress_scenarios_as_of: None,
            stress_source_content_sha256: None,
        };
        assert!(risk_input_matches_runtime_portfolio(&input, &runtime));
        input.positions[0].market_value = 4_000.0;
        assert!(!risk_input_matches_runtime_portfolio(&input, &runtime));

        input.positions[0].market_value = 5_000.0;
        input.positions.push(input.positions[0].clone());
        assert!(!risk_input_matches_runtime_portfolio(&input, &runtime));
    }
}
