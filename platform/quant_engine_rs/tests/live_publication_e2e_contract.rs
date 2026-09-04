use std::{
    collections::{BTreeMap, BTreeSet},
    fs,
    path::Path,
    sync::Arc,
};

use axio_quant_engine::{
    config::ContextObservationPolicyConfig,
    data::databento_inference::read_latest_committed_forecast,
    domain::MarketBar,
    engine::{
        features::context_observation_readiness_at_cutoff,
        gamma_convexity::{GammaConvexityRequest, gamma_convexity_feedback_risk},
    },
    market_query::{
        DataFreshness, EVIDENCE_ENVELOPE_SCHEMA_VERSION, EvidenceEnvelope, EvidenceItem,
        MarketQuery, MarketSetupType, PipelineReadiness, PipelineReadinessStage,
        PipelineReadinessState, ResearchCandidate,
    },
    prediction_ledger::{PredictionLedger, PredictionPublicationCommit},
    predictor::{
        BarrierProbabilities, DecisionPolicyResult, ForecastBundle, ForecastContract,
        ResearchOnlyPolicy,
    },
};
use axum::{Json, body::to_bytes, response::IntoResponse};
use chrono::{DateTime, Duration, Utc};
use serde::Deserialize;
use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use tempfile::tempdir;

const FIXTURE_JSON: &str = include_str!("fixtures/live_publication_e2e_contract.json");

#[derive(Debug, Deserialize)]
struct LineageFixture {
    model_version: String,
    feature_version: String,
    model_hash: String,
    feature_hash: String,
    data_manifest_hash: String,
    expected_source_envelopes_sha256: String,
    expected_forecast_sha256: String,
}

#[derive(Debug, Deserialize)]
struct LivePublicationFixture {
    schema_version: String,
    request_id: String,
    target_market_symbol: String,
    public_symbol: String,
    observation_cutoff: DateTime<Utc>,
    latest_input_available_at: DateTime<Utc>,
    published_at: DateTime<Utc>,
    generated_at: DateTime<Utc>,
    required_context_symbols: Vec<String>,
    configured_horizons: Vec<usize>,
    prediction_ids: BTreeMap<String, String>,
    expected_orientations: BTreeMap<String, String>,
    lineage: LineageFixture,
    query_sha256: String,
    query: MarketQuery,
    finalized_market_bars: Vec<MarketBar>,
    ui_required_json_pointers: Vec<String>,
}

struct InstalledGeneration {
    bundle: ForecastBundle,
    forecast_sha256: String,
    source_envelopes_sha256: String,
    publication_sha256: String,
    published_at: DateTime<Utc>,
}

fn sha256(bytes: &[u8]) -> String {
    format!("{:x}", Sha256::digest(bytes))
}

fn fixture() -> LivePublicationFixture {
    serde_json::from_str(FIXTURE_JSON).expect("deserialize deterministic live publication fixture")
}

fn fixture_contract(
    fixture: &LivePublicationFixture,
    horizon_minutes: usize,
    prediction_id: String,
) -> ForecastContract {
    let orientation = fixture
        .expected_orientations
        .get(&horizon_minutes.to_string())
        .expect("fixture orientation for every configured horizon");
    let expected_return = if orientation == "POSITIVE_CONDITIONAL_MEAN" {
        0.0004
    } else {
        -0.0003
    };
    ForecastContract {
        prediction_id,
        created_at: fixture.latest_input_available_at,
        observation_cutoff: fixture.observation_cutoff,
        as_of: fixture.observation_cutoff,
        decision_as_of: fixture.latest_input_available_at,
        latest_input_available_at: fixture.latest_input_available_at,
        earliest_executable_time: fixture.observation_cutoff + Duration::minutes(1),
        symbol: fixture.target_market_symbol.clone(),
        timeframe: "1m".into(),
        horizon_minutes,
        label_start: fixture.observation_cutoff,
        label_end: fixture.observation_cutoff + Duration::minutes(horizon_minutes as i64),
        session: "2026-07-28".into(),
        timezone: "America/New_York".into(),
        reference_price: 635.6,
        reference_price_source: "FINALIZED_1M_CLOSE_REFERENCE_ONLY".into(),
        expected_return,
        expected_price: None,
        return_definition: "NEXT_1M_OPEN_TO_HORIZON_CLOSE_SIMPLE_RETURN".into(),
        current_close_reference_scenario_expected_price: 635.6 * (1.0 + expected_return),
        current_close_reference_scenario_price_quantiles: Vec::new(),
        current_close_reference_scenario_basis:
            "FINALIZED_CURRENT_1M_CLOSE_TIMES_ONE_PLUS_NEXT_1M_OPEN_TO_HORIZON_CLOSE_SIMPLE_RETURN"
                .into(),
        current_close_reference_scenario_status:
            "REFERENCE_SCENARIO_ONLY_NOT_LABEL_ALIGNED_PRICE_FORECAST".into(),
        current_close_reference_scenario_semantics:
            "NOT_AN_EXPECTED_EXECUTABLE_OR_LABEL_ALIGNED_PRICE".into(),
        median_return: expected_return,
        return_quantiles: Vec::new(),
        price_quantiles: Vec::new(),
        p_up: None,
        p_down: None,
        p_flat: None,
        raw_analog_up_frequency: 0.5,
        raw_analog_down_frequency: 0.5,
        raw_analog_flat_frequency: 0.0,
        calibrated_probability_up: None,
        probability_calibration: Default::default(),
        suggested_direction: if expected_return > 0.0 { 1 } else { -1 },
        strategy_win_probability: None,
        kernel_regression: Default::default(),
        outcome_prediction_intervals: Vec::new(),
        expected_volatility: 0.002,
        expected_absolute_move: 0.001,
        mfe_distribution: Vec::new(),
        mae_distribution: Vec::new(),
        barrier_probabilities: BarrierProbabilities {
            upper_first: None,
            lower_first: None,
            neither: None,
            status: "WITHHELD_UNPROMOTED_RESEARCH_OUTPUT".into(),
        },
        filtered_state_probabilities: vec![0.55, 0.45],
        predicted_state_probabilities: vec![0.52, 0.48],
        state_entropy: Some(0.69),
        dominant_regime_state: Some(0),
        dominant_regime_probability: Some(0.55),
        regime_model_selection: None,
        stochastic_research_layer: Default::default(),
        epistemic_uncertainty: 0.4,
        ood_score: 0.2,
        market_snapshot_id: None,
        snapshot_link_status: "NOT_MATERIALIZED_FIXTURE".into(),
        top_analogs: Vec::new(),
        analog_effective_sample_size: 32.0,
        analog_similarity_score: 0.74,
        analog_max_day_weight: 0.08,
        analog_concentration_penalty: 0.0,
        analog_engine_status: "FIXTURE_UNCALIBRATED".into(),
        analog_metric: "SHRINKAGE_MAHALANOBIS".into(),
        analog_bandwidth: 1.0,
        analog_diagnostics: None,
        analog_sensitivity: Vec::new(),
        model_id: fixture.lineage.model_version.clone(),
        model_hash: fixture.lineage.model_hash.clone(),
        feature_version: fixture.lineage.feature_version.clone(),
        feature_hash: fixture.lineage.feature_hash.clone(),
        data_source: "DATABENTO:EQUS.MINI".into(),
        data_capability_level: "LICENSED_REALTIME_FINALIZED_OHLCV_1M".into(),
        market_coverage: "TARGET_AND_REQUIRED_CONTEXT_AT_EXACT_CUTOFF".into(),
        model_trained_through: "2026-07-17".into(),
        target_status: "SPX_RESEARCH_USING_SPY_PRICE_VOLUME_PROXY".into(),
        data_manifest_hash: fixture.lineage.data_manifest_hash.clone(),
        evidence_grade: "FORWARD_SHADOW".into(),
        evidence_kind: "live_shadow_prediction".into(),
        sample_size: 32,
        calibration_status: "CANDIDATE_NOT_PROMOTED".into(),
        availability_semantics: "DATABENTO_SERVER_RECEIPT_AVAILABLE_FINALIZED_TIMESTAMP".into(),
        decision: DecisionPolicyResult {
            action: "NO_TRADE".into(),
            eligible: false,
            expected_edge_after_cost: 0.0,
            no_trade_reasons: vec!["UNPROMOTED_RESEARCH_OUTPUT".into()],
            policy_version: "research-only-no-execution.v1".into(),
        },
    }
}

fn fixture_bundle(
    fixture: &LivePublicationFixture,
    prediction_ids: &BTreeMap<String, String>,
) -> ForecastBundle {
    let prediction_layer = fixture
        .configured_horizons
        .iter()
        .map(|horizon| {
            fixture_contract(
                fixture,
                *horizon,
                prediction_ids
                    .get(&horizon.to_string())
                    .expect("prediction id for every configured horizon")
                    .clone(),
            )
        })
        .collect();
    ForecastBundle {
        generated_at: fixture.latest_input_available_at,
        status: "RESEARCH_ONLY_NO_TRADE".into(),
        forecast_contract_version: "4.4".into(),
        prediction_layer,
        unavailable_horizons: Vec::new(),
        regime_context: None,
        gamma_convexity_layer: gamma_convexity_feedback_risk(
            &[],
            &GammaConvexityRequest {
                as_of: fixture.observation_cutoff,
                underlying: fixture.target_market_symbol.clone(),
                spot: 635.6,
                contract_multiplier: 100.0,
                oi_as_of: None,
                greeks_as_of: None,
                max_quote_age_seconds: 60,
                max_oi_age_seconds: 86_400,
                max_greeks_age_seconds: 60,
            },
        ),
        behavioral_state_layer: Default::default(),
        option_surface_layer: json!({"status":"UNAVAILABLE_NOT_REQUIRED_FOR_CORE_FIXTURE"}),
        option_execution_layer: json!({"status":"DISABLED"}),
        research_only_policy: ResearchOnlyPolicy::default(),
        conclusions: vec![
            "Deterministic end-to-end contract fixture; not evidence of predictive accuracy."
                .into(),
        ],
    }
}

fn source_envelopes(fixture: &LivePublicationFixture) -> Vec<Value> {
    fixture
        .finalized_market_bars
        .iter()
        .map(|bar| {
            json!({
                "symbol":bar.symbol,
                "bar_start":bar.timestamp,
                "bar_end":bar.timestamp + Duration::minutes(1),
                "provider_available_at":bar.timestamp + Duration::minutes(1) + Duration::milliseconds(100),
                "envelope_sha256":sha256(&serde_json::to_vec(bar).expect("serialize source bar")),
                "observation_state":"observed_trade_bar"
            })
        })
        .collect()
}

fn install_immutable_generation(
    root: &Path,
    fixture: &LivePublicationFixture,
    bundle: ForecastBundle,
    published_at: DateTime<Utc>,
) -> InstalledGeneration {
    let forecast_json = serde_json::to_string(&bundle).expect("serialize deterministic bundle");
    let forecast_sha256 = sha256(forecast_json.as_bytes());
    let source_envelopes = source_envelopes(fixture);
    let source_envelopes_sha256 =
        sha256(&serde_json::to_vec(&source_envelopes).expect("serialize source envelopes"));
    let prediction_ids = bundle
        .prediction_layer
        .iter()
        .map(|contract| contract.prediction_id.clone())
        .collect::<Vec<_>>();
    let published_nanos = published_at
        .timestamp_nanos_opt()
        .expect("fixture publication timestamp is representable");
    let publication_id = format!(
        "databento:{}:{published_nanos}:{}",
        fixture.target_market_symbol,
        &forecast_sha256[..16]
    );
    let receipt = json!({
        "schema_version":"databento_inference_receipt.v3",
        "generated_at":fixture.generated_at,
        "published_at":published_at,
        "end_to_end_ms":1000,
        "budget_ms":5000,
        "provider":"DATABENTO",
        "dataset":"EQUS.MINI",
        "data_source":"DATABENTO:EQUS.MINI",
        "model_symbol":fixture.target_market_symbol,
        "model_hash":fixture.lineage.model_hash,
        "forecast_path":"reports/forecast_contract_live_latest.json",
        "forecast_sha256":forecast_sha256,
        "prediction_ids":prediction_ids,
        "latest_input_available_at":fixture.latest_input_available_at,
        "required_context_symbols":fixture.required_context_symbols,
        "max_context_skew_ms":60000,
        "source_envelope_count":source_envelopes.len(),
        "source_envelopes_sha256":source_envelopes_sha256,
        "source_envelopes":source_envelopes,
        "cutoff_source_envelopes":[],
        "cutoff_context_observations":[],
        "ledger_persisted":true,
        "execution_enabled":false
    });
    let publication = json!({
        "schema_version":"databento_forecast_publication.v1",
        "publication_id":publication_id,
        "published_at":published_at,
        "model_symbol":fixture.target_market_symbol,
        "forecast_json":forecast_json,
        "receipt":receipt
    });
    let publication_bytes =
        serde_json::to_vec(&publication).expect("serialize immutable publication");
    let publication_sha256 = sha256(&publication_bytes);
    let directory = root
        .join("live/databento_publications")
        .join(fixture.target_market_symbol.to_ascii_lowercase());
    fs::create_dir_all(&directory).expect("create immutable publication directory");
    fs::write(
        directory.join(format!("{published_nanos}-{}.json", &forecast_sha256[..16])),
        publication_bytes,
    )
    .expect("write immutable fixture publication");
    InstalledGeneration {
        bundle,
        forecast_sha256,
        source_envelopes_sha256,
        publication_sha256,
        published_at,
    }
}

fn append_predictions(ledger: &Arc<PredictionLedger>, generation: &InstalledGeneration) {
    for contract in &generation.bundle.prediction_layer {
        ledger
            .append_prediction(contract)
            .expect("append immutable forecast attempt");
    }
}

fn commit_prediction(
    ledger: &Arc<PredictionLedger>,
    generation: &InstalledGeneration,
    index: usize,
) {
    let contract = &generation.bundle.prediction_layer[index];
    ledger
        .append_publication_commit(&PredictionPublicationCommit {
            publication_id: format!(
                "databento:{}:{}:{}",
                contract.symbol, generation.forecast_sha256, contract.prediction_id
            ),
            prediction_id: contract.prediction_id.clone(),
            published_at: generation.published_at,
            provider: "DATABENTO".into(),
            forecast_sha256: generation.forecast_sha256.clone(),
            publication_sha256: generation.publication_sha256.clone(),
            evidence_kind: "live_forecast_publication_commit".into(),
        })
        .expect("append immutable publication commit");
}

fn ready_stage(code: &str, at: DateTime<Utc>) -> PipelineReadinessStage {
    PipelineReadinessStage {
        state: PipelineReadinessState::Ready,
        code: Some(code.into()),
        detail: Some(format!(
            "{code} verified by the deterministic contract fixture"
        )),
        observed_at: Some(at),
    }
}

fn public_candidate(
    fixture: &LivePublicationFixture,
    horizon_minutes: usize,
    generation: &InstalledGeneration,
) -> ResearchCandidate {
    let orientation = fixture
        .expected_orientations
        .get(&horizon_minutes.to_string())
        .expect("orientation for public candidate")
        .clone();
    ResearchCandidate {
        symbol: fixture.public_symbol.clone(),
        setup_type: MarketSetupType::ModelForecast,
        status: "UNCALIBRATED_RESEARCH_OUTPUT".into(),
        heuristic_structure_score: None,
        score_semantics:
            "Fresh frozen-model direction condition; probability and rank remain withheld.".into(),
        supporting_evidence: vec![
            EvidenceItem {
                code: "FINALIZED_MARKET_BARS".into(),
                statement: "The exact completed one-minute target and context bars were finalized."
                    .into(),
                observed_value: Some(json!(fixture.finalized_market_bars.len())),
            },
            EvidenceItem {
                code: "CAUSAL_CONTEXT_ELIGIBLE".into(),
                statement:
                    "Every required context symbol passed the exact-cutoff causal eligibility gate."
                        .into(),
                observed_value: Some(json!(fixture.required_context_symbols)),
            },
            EvidenceItem {
                code: "IMMUTABLE_MULTI_HORIZON_PUBLICATION".into(),
                statement:
                    "This horizon belongs to one fully committed immutable multi-horizon generation."
                        .into(),
                observed_value: Some(json!(horizon_minutes)),
            },
        ],
        contrary_evidence: vec![EvidenceItem {
            code: "PROBABILITY_AND_EXPECTED_MOVE_WITHHELD".into(),
            statement:
                "No matching promoted out-of-sample calibration exists; probability, expected move, rank, and execution remain withheld."
                    .into(),
            observed_value: Some(json!(
                "WITHHELD_NO_MATCHING_PROMOTED_OOS_CALIBRATION"
            )),
        }],
        metrics: json!({
            "horizon_minutes":horizon_minutes,
            "statistical_orientation":orientation,
            "observation_cutoff":fixture.observation_cutoff,
            "latest_input_available_at":fixture.latest_input_available_at,
            "data_age_seconds":fixture.generated_at.signed_duration_since(fixture.latest_input_available_at).num_seconds(),
            "data_source":"DATABENTO:EQUS.MINI",
            "coverage":1.0,
            "coverage_semantics":"ALL_REQUIRED_TARGET_AND_CONTEXT_SYMBOLS_PRESENT_AT_THE_DECISION_CUTOFF",
            "caveats":[
                "The direction state is uncalibrated and is not a probability.",
                "Automatic execution is disabled."
            ],
            "published_probability_status":"WITHHELD_NO_MATCHING_PROMOTED_OOS_CALIBRATION",
            "validation":{
                "model_version":fixture.lineage.model_version,
                "feature_version":fixture.lineage.feature_version,
                "model_hash":fixture.lineage.model_hash,
                "feature_hash":fixture.lineage.feature_hash,
                "data_manifest_hash":fixture.lineage.data_manifest_hash,
                "schema_version":"databento_inference_receipt.v3",
                "source_envelopes_sha256":generation.source_envelopes_sha256,
                "forecast_sha256":generation.forecast_sha256,
                "published_at":generation.published_at,
                "end_to_end_ms":1000,
                "budget_ms":5000
            },
            "interpretation":"MODEL_DIRECTION_CONDITION_ONLY_NOT_A_TRADE"
        }),
        freshness: vec![DataFreshness {
            source: "DATABENTO:EQUS.MINI".into(),
            observed_at: Some(fixture.observation_cutoff),
            available_at: Some(fixture.latest_input_available_at),
            age_seconds: Some(
                fixture
                    .generated_at
                    .signed_duration_since(fixture.latest_input_available_at)
                    .num_seconds(),
            ),
            realtime: true,
            entitlement: "LICENSED_REALTIME_SHADOW_EVIDENCE_VERIFIED".into(),
            coverage: Some(1.0),
        }],
    }
}

fn evidence_envelope(
    fixture: &LivePublicationFixture,
    generation: &InstalledGeneration,
) -> EvidenceEnvelope {
    EvidenceEnvelope {
        schema_version: EVIDENCE_ENVELOPE_SCHEMA_VERSION.into(),
        evidence_mode: Default::default(),
        request_id: fixture.request_id.clone(),
        query_sha256: fixture.query_sha256.clone(),
        response_sha256: None,
        generated_at: fixture.generated_at,
        observation_cutoff: fixture.observation_cutoff,
        status: "UNCALIBRATED_RESEARCH_OUTPUT".into(),
        query: fixture.query.clone(),
        candidates: fixture
            .configured_horizons
            .iter()
            .map(|horizon| public_candidate(fixture, *horizon, generation))
            .collect(),
        exclusions: Vec::new(),
        historical: Vec::new(),
        data_blockers: Vec::new(),
        readiness: PipelineReadiness {
            model: ready_stage("FROZEN_MODEL_ARTIFACT_VERIFIED", fixture.published_at),
            feed: ready_stage("FINALIZED_REALTIME_BARS_VERIFIED", fixture.published_at),
            context: ready_stage("CAUSAL_CONTEXT_VERIFIED", fixture.published_at),
            inference: ready_stage("ALL_HORIZONS_INFERRED", fixture.published_at),
            publication: ready_stage(
                "IMMUTABLE_MULTI_HORIZON_GENERATION_COMMITTED",
                fixture.published_at,
            ),
        },
        model_contract: json!({
            "runtime_owner":"RUST",
            "forecast_horizons_minutes":fixture.configured_horizons,
            "model_version":fixture.lineage.model_version,
            "feature_schema_version":fixture.lineage.feature_version,
            "probability_policy":"CALIBRATED_PROBABILITIES_REQUIRE_A_MATCHING_PROMOTED_OOS_ARTIFACT"
        }),
        research_only_policy: json!({
            "product_scope":"IMPERSONAL_WHOLE_MARKET_STATISTICAL_RESEARCH",
            "personalization_used":false,
            "investment_advice":false,
            "execution_instruction":false,
            "automatic_order_execution":false
        }),
        caveats: vec![
            "No candidate is an order, personalized recommendation, or guaranteed outcome.".into(),
            "UNCALIBRATED_RESEARCH_OUTPUT exposes a direction condition only; probability, expected move, rank, and execution remain withheld.".into(),
            "A neutral ticker query publishes every configured horizon atomically; automatic execution is disabled.".into(),
        ],
    }
}

fn prediction_ids_with_prefix(
    fixture: &LivePublicationFixture,
    prefix: &str,
) -> BTreeMap<String, String> {
    fixture
        .configured_horizons
        .iter()
        .map(|horizon| (horizon.to_string(), format!("{prefix}-h{horizon}")))
        .collect()
}

#[tokio::test]
async fn finalized_bars_to_visible_evidence_is_atomic_and_fail_closed() {
    let fixture = fixture();
    assert_eq!(
        fixture.schema_version,
        "axio.live-publication-e2e-fixture.v1"
    );
    assert_eq!(
        fixture.query.canonical_sha256().unwrap(),
        fixture.query_sha256,
        "the public query identity must be the Rust canonical hash"
    );
    let query = fixture.query.clone().normalize_and_validate().unwrap();
    assert_eq!(query.setup_type, MarketSetupType::ModelForecast);
    assert!(
        query.horizon_minutes.is_none(),
        "a ticker-only model query must keep the horizon model-owned"
    );
    assert!(
        query.filters.direction.is_none(),
        "a ticker-only model query must not invent a direction"
    );

    assert!(
        fixture.finalized_market_bars.iter().all(|bar| {
            bar.data_quality == "FINALIZED_REALTIME_OBSERVED_TRADE_BAR"
                && bar.is_observed_trade_bar()
        }),
        "only finalized positive-volume observed-trade bars enter the fixture"
    );
    let context = context_observation_readiness_at_cutoff(
        &fixture.finalized_market_bars,
        &[],
        fixture.observation_cutoff,
        &fixture.required_context_symbols,
        60_000,
        &ContextObservationPolicyConfig::default(),
    );
    assert!(context.ready, "{:?}", context.blockers);
    assert!(
        context.symbols.iter().all(|symbol| symbol.ready
            && symbol.observed_trade_intervals == 6
            && symbol.unknown_missing_intervals == 0),
        "the causal context gate must see all six exact completed intervals"
    );
    let mut incomplete_bars = fixture.finalized_market_bars.clone();
    incomplete_bars
        .iter_mut()
        .find(|bar| bar.symbol == "QQQ" && bar.timestamp == fixture.observation_cutoff)
        .expect("QQQ cutoff row")
        .volume = 0.0;
    let incomplete_context = context_observation_readiness_at_cutoff(
        &incomplete_bars,
        &[],
        fixture.observation_cutoff,
        &fixture.required_context_symbols,
        60_000,
        &ContextObservationPolicyConfig::default(),
    );
    assert!(!incomplete_context.ready);
    assert!(
        incomplete_context
            .blockers
            .iter()
            .any(|blocker| blocker.starts_with("QQQ:")),
        "an invalid finalized context row must fail closed for that symbol"
    );

    let directory = tempdir().unwrap();
    let root = directory.path();
    let ledger = PredictionLedger::open(&root.join("state/prediction_ledger.sqlite3")).unwrap();
    let baseline = install_immutable_generation(
        root,
        &fixture,
        fixture_bundle(&fixture, &fixture.prediction_ids),
        fixture.published_at,
    );
    assert_eq!(
        baseline.source_envelopes_sha256, fixture.lineage.expected_source_envelopes_sha256,
        "update the reviewed fixture digest only when finalized source-bar semantics change"
    );
    assert_eq!(
        baseline.forecast_sha256, fixture.lineage.expected_forecast_sha256,
        "update the reviewed fixture digest only when the frozen forecast contract changes"
    );
    append_predictions(&ledger, &baseline);
    assert!(
        read_latest_committed_forecast(root, &fixture.target_market_symbol).is_none(),
        "an immutable file without ledger publication commits is an orphan, not a public result"
    );
    for index in 0..baseline.bundle.prediction_layer.len() - 1 {
        commit_prediction(&ledger, &baseline, index);
    }
    assert!(
        read_latest_committed_forecast(root, &fixture.target_market_symbol).is_none(),
        "three committed horizons out of four must not expose a partial generation"
    );
    commit_prediction(
        &ledger,
        &baseline,
        baseline.bundle.prediction_layer.len() - 1,
    );
    let visible = read_latest_committed_forecast(root, &fixture.target_market_symbol)
        .expect("the fully committed generation becomes visible");
    let visible_bundle: ForecastBundle =
        serde_json::from_value(visible).expect("deserialize visible immutable generation");
    let visible_horizons = visible_bundle
        .prediction_layer
        .iter()
        .map(|contract| contract.horizon_minutes)
        .collect::<BTreeSet<_>>();
    assert_eq!(
        visible_horizons,
        fixture
            .configured_horizons
            .iter()
            .copied()
            .collect::<BTreeSet<_>>()
    );
    assert_eq!(
        visible_bundle.prediction_layer.len(),
        fixture.configured_horizons.len()
    );

    let next_ids = prediction_ids_with_prefix(&fixture, "fixture-spy-generation-b");
    let newer_partial = install_immutable_generation(
        root,
        &fixture,
        fixture_bundle(&fixture, &next_ids),
        fixture.published_at + Duration::seconds(1),
    );
    append_predictions(&ledger, &newer_partial);
    for index in 0..newer_partial.bundle.prediction_layer.len() - 1 {
        commit_prediction(&ledger, &newer_partial, index);
    }
    let still_visible = read_latest_committed_forecast(root, &fixture.target_market_symbol)
        .expect("the previous full generation remains visible");
    let still_visible_ids = still_visible
        .get("prediction_layer")
        .and_then(Value::as_array)
        .expect("visible prediction layer")
        .iter()
        .filter_map(|row| row.get("prediction_id").and_then(Value::as_str))
        .collect::<BTreeSet<_>>();
    assert!(
        fixture
            .prediction_ids
            .values()
            .all(|prediction_id| still_visible_ids.contains(prediction_id.as_str()))
    );
    assert!(
        next_ids
            .values()
            .all(|prediction_id| !still_visible_ids.contains(prediction_id.as_str())),
        "a newer partially committed generation cannot replace the previous full generation"
    );

    let mut envelope = evidence_envelope(&fixture, &baseline);
    envelope.seal().expect("seal Rust public evidence envelope");
    let api_response = Json(envelope.clone()).into_response();
    let api_bytes = to_bytes(api_response.into_body(), 1_000_000)
        .await
        .expect("serialize Axum JSON response body");
    let api_envelope: EvidenceEnvelope =
        serde_json::from_slice(&api_bytes).expect("deserialize Axum evidence response");
    assert_eq!(api_envelope, envelope);
    assert!(
        api_envelope
            .response_sha256
            .as_deref()
            .is_some_and(|hash| hash.len() == 64)
    );
    let api_value = serde_json::to_value(&api_envelope).unwrap();
    for pointer in &fixture.ui_required_json_pointers {
        assert!(
            api_value
                .pointer(pointer)
                .is_some_and(|value| !value.is_null()),
            "customer UI field {pointer} is absent from the Rust API envelope"
        );
    }
    assert_eq!(
        api_envelope
            .candidates
            .iter()
            .filter_map(|candidate| {
                candidate
                    .metrics
                    .get("horizon_minutes")
                    .and_then(Value::as_u64)
                    .and_then(|value| usize::try_from(value).ok())
            })
            .collect::<BTreeSet<_>>(),
        fixture
            .configured_horizons
            .iter()
            .copied()
            .collect::<BTreeSet<_>>()
    );
    for forbidden in [
        "probability_up_percent",
        "expected_move_percent",
        "research_rank_score",
        "target_price",
        "order",
    ] {
        assert!(
            api_envelope
                .candidates
                .iter()
                .all(|candidate| candidate.metrics.get(forbidden).is_none()),
            "unpromoted fixture must not fabricate {forbidden}"
        );
    }
    assert_eq!(
        api_value.pointer("/research_only_policy/automatic_order_execution"),
        Some(&Value::Bool(false))
    );
}
