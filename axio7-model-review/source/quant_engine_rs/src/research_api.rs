use std::{
    collections::{BTreeMap, BTreeSet},
    fs,
    path::Path,
};

use axum::{Json, extract::State};
use chrono::{DateTime, NaiveDate, Utc};
use serde_json::{Value, json};
use sha2::{Digest, Sha256};

use crate::{
    anomaly_research::{DurableHypothesisRegistry, HypothesisStatus},
    api::AppState,
    market_memory::{
        AUTHORITATIVE_STORE_FORMAT, EXPORT_STATUS, MARKET_SNAPSHOT_SCHEMA_VERSION,
        MarketMemoryStore,
    },
    market_state::STATE_FEATURE_SCHEMA,
    os_domain::stable_id,
    prediction_ledger::PredictionLedger,
};

fn data_root(state: &AppState) -> &Path {
    state
        .config
        .data
        .raw_root
        .parent()
        .unwrap_or(Path::new("data"))
}

fn read_json(path: &Path) -> Option<Value> {
    fs::read(path)
        .ok()
        .and_then(|bytes| serde_json::from_slice(&bytes).ok())
}
fn sha256_hex(bytes: &[u8]) -> String {
    format!("{:x}", Sha256::digest(bytes))
}

fn latest_forecast_contract(state: &AppState) -> Option<Value> {
    let reports = data_root(state).join("reports");
    [
        "forecast_contract_live_latest.json",
        "forecast_contract_latest.json",
    ]
    .into_iter()
    .find_map(|name| read_json(&reports.join(name)))
}

pub async fn memory_summary(State(state): State<AppState>) -> Json<Value> {
    let store_path = data_root(&state).join("state/market_memory.sqlite3");
    if store_path.exists() {
        let response = tokio::task::spawn_blocking(move || -> anyhow::Result<Value> {
            let store = MarketMemoryStore::open(&store_path)?;
            let audit = store.audit_counts()?;
            let latest = store.latest_active_snapshot_any()?;
            let coverage = store.coverage_by_symbol()?;
            let latest_labels = latest
                .as_ref()
                .map(|snapshot| store.latest_forward_labels(&snapshot.snapshot_id))
                .transpose()?
                .flatten();
            let current_snapshot = latest.as_ref().map(|snapshot| {
                json!({
                    "snapshot_id": snapshot.snapshot_id,
                    "symbol": snapshot.record.symbol,
                    "decision_as_of": snapshot.record.decision_as_of,
                    "information_available_as_of": snapshot.record.information_available_as_of,
                    "session_date": snapshot.record.session_date,
                    "minute_of_session": snapshot.record.minute_of_session,
                    "reference_price": snapshot.record.reference_price.value,
                    "regime_entropy": snapshot.record.regime_entropy.value,
                    "label_available_at": latest_labels.as_ref().map(|row| row.record.label_available_at),
                    "data_quality_flags": snapshot.record.data_quality_flags.value,
                    "content_sha256": snapshot.content_sha256,
                    "lineage_sha256": snapshot.lineage_sha256,
                })
            });
            let coverage_by_symbol = coverage
                .iter()
                .map(|row| {
                    json!({
                        "symbol": row.symbol,
                        "snapshot_count": row.active_snapshot_count,
                        "session_count": row.independent_sessions,
                        "first_as_of": row.first_decision_as_of,
                        "last_as_of": row.last_decision_as_of,
                        "settled_snapshot_count": row.settled_snapshot_count,
                        "pending_snapshot_count": row.pending_snapshot_count,
                        "quality_status": "FAST_SQL_SUMMARY_NOT_FULL_CHAIN_RECONSTRUCTION",
                    })
                })
                .collect::<Vec<_>>();
            let symbol_names = coverage
                .iter()
                .map(|row| row.symbol.as_str())
                .collect::<Vec<_>>();
            Ok(json!({
                "status": if audit.active_snapshots == 0 { "EMPTY" } else { "AVAILABLE" },
                "schema_version": MARKET_SNAPSHOT_SCHEMA_VERSION,
                "dataset_version": latest.as_ref().map(|snapshot| snapshot.record.dataset_version.as_str()),
                "storage_format": AUTHORITATIVE_STORE_FORMAT,
                "export_status": EXPORT_STATUS,
                "append_only_guards_present": true,
                "manifest_sha256": Value::Null,
                "manifest_status": "NOT_RECOMPUTED_BY_STATUS_ENDPOINT",
                "snapshot_count": audit.active_snapshots,
                "session_count": audit.independent_sessions,
                "symbol_count": audit.symbols,
                "symbol_names": symbol_names,
                "latest_decision_as_of": latest.as_ref().map(|snapshot| snapshot.record.decision_as_of),
                "duplicates_rejected": audit.duplicate_snapshot_attempts,
                "correction_count": audit.snapshot_corrections,
                "forward_label_count": audit.active_forward_label_records,
                "pending_forward_label_count": audit.pending_active_snapshots,
                "current_snapshot": current_snapshot,
                "coverage_by_symbol": coverage_by_symbol,
                "reconstruction": {
                    "status": "NOT_RUN_FAST_STATUS_ENDPOINT",
                    "full_hash_verification": false,
                    "instruction": "Run the explicit Market Memory reconstruction acceptance command before claiming HASH_VERIFIED",
                },
                "evidence_grade": "FAST_OPERATIONAL_SUMMARY_NOT_EDGE_EVIDENCE",
            }))
        })
        .await
        .map_err(anyhow::Error::from)
        .and_then(|result| result);
        return Json(response.unwrap_or_else(|error| {
            json!({
                "status": "DEGRADED",
                "reason": "MARKET_MEMORY_FAST_SUMMARY_FAILED",
                "detail": error.to_string(),
                "storage_format": AUTHORITATIVE_STORE_FORMAT,
                "export_status": EXPORT_STATUS,
            })
        }));
    }
    let forecast = latest_forecast_contract(&state);
    let prediction_rows = forecast
        .as_ref()
        .and_then(|artifact| artifact.get("prediction_layer"))
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();
    let latest = prediction_rows
        .iter()
        .max_by_key(|row| row.get("decision_as_of").and_then(Value::as_str));
    let symbols = prediction_rows
        .iter()
        .filter_map(|row| row.get("symbol").and_then(Value::as_str))
        .collect::<BTreeSet<_>>();
    Json(json!({
        "status": "BLOCKED",
        "reason": "MARKET_MEMORY_STORE_NOT_MATERIALIZED",
        "message": "The immutable schema/store is operational, but the historical archive has not been materialized into market_memory.sqlite3.",
        "schema_version": MARKET_SNAPSHOT_SCHEMA_VERSION,
        "storage_format": AUTHORITATIVE_STORE_FORMAT,
        "export_status": EXPORT_STATUS,
        "append_only": true,
        "snapshot_count": 0,
        "reconstructible_market_state_rows": Value::Null,
        "session_count": 0,
        "symbol_count": symbols.len(),
        "latest_decision_as_of": latest.and_then(|row| row.get("decision_as_of")),
        "current_snapshot": latest.map(|row| json!({
            "snapshot_id": row.get("market_snapshot_id").cloned().unwrap_or(Value::Null),
            "snapshot_link_status": row.get("snapshot_link_status").cloned().unwrap_or_else(|| json!("MARKET_MEMORY_NOT_MATERIALIZED")),
            "symbol": row.get("symbol"),
            "decision_as_of": row.get("decision_as_of"),
            "information_available_as_of": row.get("latest_input_available_at"),
            "data_quality_flags": ["NOT_MATERIALIZED"],
        })),
        "coverage_by_symbol": [],
        "evidence_grade": "SCHEMA_TESTED_STORE_EMPTY",
    }))
}

pub async fn event_atlas(State(_state): State<AppState>) -> Json<Value> {
    // Legacy time-bucket reports are intentionally not loaded here: they are
    // large research artifacts and are not event-atlas evidence.
    let effect_rows = Vec::<Value>::new();
    Json(json!({
        "status": "PENDING",
        "reason": "EVENT_DETECTOR_IMPLEMENTED_ATLAS_STORE_NOT_MATERIALIZED",
        "schema_version": "axio.event-response-atlas.v1",
        "event_count": 0,
        "event_type_count": 33,
        "effective_sample_size": 0,
        "last_detection_at": Value::Null,
        "taxonomy": {
            "endogenous": [
                "opening_gap", "opening_range_breakout", "opening_range_failure",
                "abnormal_volume", "volatility_expansion", "volatility_compression",
                "vwap_reclaim", "vwap_rejection", "prior_day_high_break",
                "prior_day_low_break", "intraday_drawdown_threshold", "rapid_sell_off",
                "rapid_rebound", "price_volume_divergence", "relative_strength_divergence",
                "cross_asset_correlation_breakdown", "repeated_same_direction_bars",
                "failed_breakout", "liquidity_spread_shock", "power_hour_acceleration",
                "closing_imbalance_proxy"
            ],
            "scheduled": [
                "cpi", "ppi", "nfp", "fomc", "opex", "monthly_expiration",
                "quarterly_expiration", "month_end", "quarter_end", "early_close",
                "major_earnings", "scheduled_treasury_fed"
            ]
        },
        "responses": [],
        "legacy_time_bucket_controls": effect_rows,
        "calendar_status": "BLOCKED_UNTIL_VERSIONED_POINT_IN_TIME_CALENDAR",
        "liquidity_event_status": "BLOCKED_WITHOUT_HISTORICAL_BID_ASK",
        "evidence_grade": "NO_EVENT_RESPONSE_SAMPLE_MATERIALIZED",
    }))
}

pub async fn analogs_current(State(state): State<AppState>) -> Json<Value> {
    let Some(artifact) = latest_forecast_contract(&state) else {
        return Json(json!({
            "status": "UNAVAILABLE",
            "analog_status": "NO_RELIABLE_ANALOG",
            "reason": "NO_FORECAST_CONTRACT",
            "schema_version": "axio.current-analogs.v2",
            "analogs": [],
        }));
    };
    let prediction_rows = artifact
        .get("prediction_layer")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();
    let Some(row) = prediction_rows.iter().min_by_key(|row| {
        row.get("horizon_minutes")
            .and_then(Value::as_u64)
            .unwrap_or_default()
            .abs_diff(15)
    }) else {
        return Json(json!({
            "status": "UNAVAILABLE",
            "analog_status": "NO_RELIABLE_ANALOG",
            "reason": "FORECAST_CONTRACT_HAS_NO_PREDICTIONS",
            "schema_version": "axio.current-analogs.v2",
            "analogs": [],
        }));
    };

    let raw_analogs = row
        .get("top_analogs")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();
    let analogs = raw_analogs
        .iter()
        .map(|analog| {
            let canonical_id = analog
                .get("market_snapshot_id")
                .filter(|value| !value.is_null())
                .cloned();
            let trace_id = analog
                .get("derived_trace_id")
                .cloned()
                .unwrap_or(Value::Null);
            let retrieval_id = analog
                .get("retrieval_snapshot_id")
                .filter(|value| !value.is_null())
                .cloned();
            json!({
                "rank": analog.get("rank"),
                "analog_id": canonical_id.clone().or(retrieval_id.clone()).unwrap_or_else(|| trace_id.clone()),
                "market_snapshot_id": canonical_id,
                "retrieval_snapshot_id": retrieval_id,
                "derived_trace_id": trace_id,
                "snapshot_link_status": if analog.get("market_snapshot_id").is_some_and(|value| !value.is_null()) {
                    "CANONICAL_MARKET_MEMORY_ID"
                } else if analog.get("retrieval_snapshot_id").is_some_and(|value| !value.is_null()) {
                    "DETERMINISTIC_RETRIEVAL_ID_NOT_A_MARKET_MEMORY_FOREIGN_KEY"
                } else {
                    "TRACE_NOT_A_MARKET_SNAPSHOT_ID"
                },
                "analog_timestamp": analog.get("analog_timestamp"),
                "session_date": analog.get("session_date"),
                "distance": analog.get("distance"),
                "weight": analog.get("weight"),
                "regime_similarity": analog.get("regime_similarity"),
                "feature_similarity": analog.get("feature_similarity").cloned().unwrap_or_else(|| json!([])),
                "subsequent_realized_path": analog.get("subsequent_realized_path").cloned().unwrap_or_else(|| json!([])),
                "forward_return": analog.get("forward_return"),
                "mfe": analog.get("mfe"),
                "mae": analog.get("mae"),
                "label_available_at": analog.get("label_available_at"),
                "path_status": analog.get("path_status").cloned().unwrap_or_else(|| json!("TERMINAL_LABEL_ONLY")),
            })
        })
        .collect::<Vec<_>>();
    let effective_sample_size = row
        .pointer("/kernel_regression/effective_sample_size")
        .or_else(|| row.get("analog_effective_sample_size"))
        .and_then(Value::as_f64)
        .unwrap_or_default();
    let minimum_effective_sample_size = row
        .pointer("/kernel_regression/minimum_effective_sample_size")
        .and_then(Value::as_f64)
        .unwrap_or(state.config.research.regime.minimum_effective_sample_size);
    let ood_score = row.get("ood_score").and_then(Value::as_f64).unwrap_or(1.0);
    let engine_status = row
        .get("analog_engine_status")
        .and_then(Value::as_str)
        .unwrap_or("UNAVAILABLE");
    let mut reasons = row
        .get("decision")
        .and_then(|decision| decision.get("no_trade_reasons"))
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .filter_map(Value::as_str)
        .map(str::to_string)
        .collect::<Vec<_>>();
    if analogs.is_empty() {
        reasons.push("ANALOG_ROWS_NOT_PERSISTED_IN_FORECAST_CONTRACT".into());
    }
    if effective_sample_size < minimum_effective_sample_size {
        reasons.push("NO_RELIABLE_ANALOG_INSUFFICIENT_ESS".into());
    }
    if ood_score > 1.0 {
        reasons.push("OUT_OF_DISTRIBUTION".into());
    }
    reasons.sort();
    reasons.dedup();
    let analog_status =
        if analogs.is_empty() || effective_sample_size < minimum_effective_sample_size {
            "NO_RELIABLE_ANALOG"
        } else if ood_score > 1.0 {
            "OUT_OF_DISTRIBUTION"
        } else if engine_status != "AVAILABLE" {
            "NO_RELIABLE_ANALOG"
        } else {
            "AVAILABLE"
        };
    let horizon_minutes = row
        .get("horizon_minutes")
        .and_then(Value::as_u64)
        .unwrap_or_default();
    let diagnostics_payload = json!({
        "effective_sample_size": effective_sample_size,
        "max_day_weight": row.get("analog_max_day_weight"),
        "concentration_penalty": row.get("analog_concentration_penalty"),
        "nearest_neighbor_distance": row.pointer("/analog_diagnostics/nearest_neighbor_distance"),
        "ood_distance_threshold": row.pointer("/analog_diagnostics/ood_distance_threshold"),
        "distance_concentration": row.pointer("/analog_diagnostics/distance_concentration"),
        "analog_age_mean_days": row.pointer("/analog_diagnostics/analog_age_days_mean"),
        "analog_age_quantiles": row.pointer("/analog_diagnostics/analog_age_days_quantiles"),
        "dominant_period_share": row.pointer("/analog_diagnostics/maximum_year_weight"),
        "dominant_year": row.pointer("/analog_diagnostics/dominant_year"),
        "same_day_overlap": row.pointer("/analog_diagnostics/highly_overlapping_neighbors"),
        "same_day_overlap_status": if row.pointer("/analog_diagnostics/highly_overlapping_neighbors").and_then(Value::as_bool) == Some(false) { "PASSED" } else { "BLOCKED_OR_UNAVAILABLE" },
        "regime_conditioned": true,
        "regime_match_policy": "same_dominant_raw_state_and_posterior_cosine",
        "minimum_regime_similarity": state.config.research.regime.minimum_posterior_cosine_similarity,
        "minimum_dominant_probability": state.config.research.regime.minimum_dominant_probability,
        "time_of_day_conditioned": true,
        "scaler_scope": row.pointer("/analog_diagnostics/scaler_fit_period_end"),
        "feature_selection_scope": "predeclared_12_dimensions",
        "covariance_inverse_status": row.pointer("/analog_diagnostics/covariance_inverse_status"),
        "limitations": [
            "same-regime filtering can materially reduce independent sample size and must fail closed",
            "research distance/kernel comparison remains unvalidated and cannot be promoted"
        ]
    });
    let mut response = json!({
        "status": if analog_status == "AVAILABLE" { "AVAILABLE" } else { "NO_VALIDATED_EDGE" },
        "analog_status": analog_status,
        "reason": if analogs.is_empty() {
            "FORECAST_CONTRACT_PRE_DATES_ANALOG_AUDIT_FIELDS_OR_RETRIEVAL_FAILED"
        } else {
            "LATEST_MODERN_ANALOG_FORECAST_CONTRACT"
        },
        "schema_version": "axio.current-analogs.v2",
        "source_contract_generated_at": artifact.get("generated_at"),
        "decision_as_of": row.get("decision_as_of"),
        "symbol": row.get("symbol"),
        "horizon_minutes": horizon_minutes,
        "horizon_label": format!("{horizon_minutes}m"),
        "current_market_snapshot_id": row.get("market_snapshot_id"),
        "snapshot_link_status": row.get("snapshot_link_status"),
        "neighbor_count": row.pointer("/kernel_regression/neighbor_count").or_else(|| row.get("sample_size")),
        "effective_sample_size": effective_sample_size,
        "ood_score": ood_score,
        "kernel": row.pointer("/kernel_regression/kernel"),
        "metric": row.pointer("/kernel_regression/metric").or_else(|| row.get("analog_metric")),
        "bandwidth": row.pointer("/kernel_regression/bandwidth").or_else(|| row.get("analog_bandwidth")),
        "expected_return": row.get("expected_return"),
        "median_return": row.get("median_return"),
        "raw_analog_up_frequency": row.get("raw_analog_up_frequency"),
        "calibrated_probability_up": row.get("calibrated_probability_up"),
        "probability_calibration": row.get("probability_calibration"),
        "statistical_condition": row.get("expected_return").and_then(Value::as_f64).map(|value| if value > 0.0 { "POSITIVE_CONDITIONAL_MEAN" } else if value < 0.0 { "NEGATIVE_CONDITIONAL_MEAN" } else { "NO_DIRECTIONAL_ASYMMETRY" }),
        "dispersion": row.get("expected_volatility"),
        "analogs": analogs,
        "diagnostics": diagnostics_payload,
        "sensitivity": row.get("analog_sensitivity").cloned().unwrap_or_else(|| json!([])),
        "validation_flags": reasons,
        "research_only_policy": {
            "product_scope": "IMPERSONAL_WHOLE_MARKET_STATISTICAL_RESEARCH",
            "personalization_used": false,
            "execution_eligible": false,
            "investment_advice": false
        },
        "evidence_grade": row.get("evidence_grade"),
    });
    if let Some(object) = response.as_object_mut() {
        object.insert(
            "minimum_effective_sample_size".into(),
            json!(minimum_effective_sample_size),
        );
        for (key, value) in [
            ("expected_price", row.get("expected_price")),
            ("return_definition", row.get("return_definition")),
            (
                "current_close_reference_scenario_expected_price",
                row.get("current_close_reference_scenario_expected_price"),
            ),
            (
                "current_close_reference_scenario_price_quantiles",
                row.get("current_close_reference_scenario_price_quantiles"),
            ),
            (
                "current_close_reference_scenario_basis",
                row.get("current_close_reference_scenario_basis"),
            ),
            (
                "current_close_reference_scenario_status",
                row.get("current_close_reference_scenario_status"),
            ),
            (
                "current_close_reference_scenario_semantics",
                row.get("current_close_reference_scenario_semantics"),
            ),
            (
                "raw_analog_down_frequency",
                row.get("raw_analog_down_frequency"),
            ),
            (
                "raw_analog_flat_frequency",
                row.get("raw_analog_flat_frequency"),
            ),
            (
                "direction_probability_intervals",
                row.pointer("/kernel_regression/direction_probability_intervals"),
            ),
            (
                "probability_status",
                row.pointer("/kernel_regression/probability_status"),
            ),
            (
                "probability_semantics",
                row.pointer("/kernel_regression/probability_semantics"),
            ),
            (
                "outcome_prediction_intervals",
                row.get("outcome_prediction_intervals"),
            ),
            (
                "stochastic_research_layer",
                row.get("stochastic_research_layer"),
            ),
            ("kernel_regression", row.get("kernel_regression")),
        ] {
            object.insert(key.into(), value.cloned().unwrap_or(Value::Null));
        }
    }
    Json(response)
}

const ALLOWED_PRICE_FLOW_STATE_NAMES: [&str; 8] = [
    "UNCLASSIFIED_PRICE_FLOW_STATE",
    "LOW_VOL_TREND_UP",
    "LOW_VOL_TREND_DOWN",
    "HIGH_VOL_SELL_OFF",
    "HIGH_VOL_RECOVERY",
    "MEAN_REVERSION",
    "HIGH_ACTIVITY_HIGH_VOLATILITY",
    "RANGE_COMPRESSION",
];

fn state_profile_names(report: &Value, transition: &[Value], states: usize) -> Option<Vec<String>> {
    let profiles = report.get("state_profiles")?.as_array()?;
    if profiles.len() != states || transition.len() != states {
        return None;
    }
    let mut names = vec![None; states];
    for profile in profiles {
        let raw_state_id = profile.get("raw_state_id")?.as_u64()? as usize;
        let name = profile.get("name")?.as_str()?.trim();
        if raw_state_id >= states
            || !ALLOWED_PRICE_FLOW_STATE_NAMES.contains(&name)
            || names[raw_state_id].is_some()
        {
            return None;
        }
        for key in [
            "standardized_return_mean",
            "standardized_vwap_distance_mean",
            "standardized_volatility_mean",
            "standardized_activity_mean",
        ] {
            if !profile.get(key)?.as_f64()?.is_finite() {
                return None;
            }
        }
        let self_transition = profile.get("self_transition_probability")?.as_f64()?;
        let matrix_self_transition = transition
            .get(raw_state_id)?
            .as_array()?
            .get(raw_state_id)?
            .as_f64()?;
        if !self_transition.is_finite()
            || !(0.0..=1.0).contains(&self_transition)
            || !values_close(self_transition, matrix_self_transition)
            || non_empty_string(profile.get("duration_model")).is_none()
        {
            return None;
        }
        let expected_duration = profile.get("expected_duration_observations")?;
        let expected_future = profile.get("expected_future_self_transitions")?;
        if 1.0 - self_transition <= STATE_DURATION_ABSORBING_TOLERANCE {
            if !expected_duration.is_null() || !expected_future.is_null() {
                return None;
            }
        } else {
            let expected_duration_value = expected_duration.as_f64()?;
            let expected_future_value = expected_future.as_f64()?;
            if !expected_duration_value.is_finite()
                || !expected_future_value.is_finite()
                || !values_close(expected_duration_value, 1.0 / (1.0 - self_transition))
                || !values_close(
                    expected_future_value,
                    self_transition / (1.0 - self_transition),
                )
            {
                return None;
            }
        }
        names[raw_state_id] = Some(name.to_string());
    }
    names.into_iter().collect()
}
const STATE_INTEGRITY_TOLERANCE: f64 = 1.0e-8;
const STATE_DURATION_ABSORBING_TOLERANCE: f64 = 1.0e-12;
const REQUIRED_STATE_HORIZONS: [(u64, u64); 4] = [(1, 5), (3, 15), (6, 30), (12, 60)];

fn values_close(left: f64, right: f64) -> bool {
    let scale = left.abs().max(right.abs()).max(1.0);
    (left - right).abs() <= STATE_INTEGRITY_TOLERANCE * scale
}

fn probability_values(values: &[Value], expected_len: Option<usize>) -> Option<Vec<f64>> {
    if values.is_empty() || expected_len.is_some_and(|length| values.len() != length) {
        return None;
    }
    let probabilities = values
        .iter()
        .map(Value::as_f64)
        .collect::<Option<Vec<_>>>()?;
    (probabilities
        .iter()
        .all(|value| value.is_finite() && (0.0..=1.0).contains(value))
        && values_close(probabilities.iter().sum::<f64>(), 1.0))
    .then_some(probabilities)
}

fn probability_vector_is_valid(values: &[Value], expected_len: Option<usize>) -> bool {
    probability_values(values, expected_len).is_some()
}

fn transition_matrix_is_valid(matrix: &[Value], states: usize) -> bool {
    matrix.len() == states
        && matrix.iter().all(|row| {
            row.as_array()
                .is_some_and(|values| probability_vector_is_valid(values, Some(states)))
        })
}

fn non_empty_string(value: Option<&Value>) -> Option<&str> {
    value
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|value| !value.is_empty())
}

fn is_sha256_hex(value: &str) -> bool {
    value.len() == 64 && value.bytes().all(|byte| byte.is_ascii_hexdigit())
}

fn state_feature_schema(report: &Value) -> Option<Vec<String>> {
    let entries = report.get("state_feature_schema")?.as_array()?;
    if entries.is_empty() {
        return None;
    }
    let mut seen = BTreeSet::new();
    let mut schema = Vec::with_capacity(entries.len());
    for entry in entries {
        let original = entry.as_str()?;
        let name = original.trim();
        if name.is_empty() || name != original || !seen.insert(name.to_string()) {
            return None;
        }
        schema.push(name.to_string());
    }
    schema
        .iter()
        .map(String::as_str)
        .eq(STATE_FEATURE_SCHEMA)
        .then_some(schema)
}

fn finite_matrix(
    value: &Value,
    rows: usize,
    columns: usize,
    positive: bool,
) -> Option<Vec<Vec<f64>>> {
    let matrix = value.as_array()?;
    if matrix.len() != rows {
        return None;
    }
    matrix
        .iter()
        .map(|row| {
            let values = row.as_array()?;
            if values.len() != columns {
                return None;
            }
            values
                .iter()
                .map(|value| {
                    value
                        .as_f64()
                        .filter(|number| number.is_finite() && (!positive || *number > 0.0))
                })
                .collect::<Option<Vec<_>>>()
        })
        .collect()
}

fn matrices_close(left: &[Vec<f64>], right: &[Vec<f64>]) -> bool {
    left.len() == right.len()
        && left.iter().zip(right).all(|(left_row, right_row)| {
            left_row.len() == right_row.len()
                && left_row
                    .iter()
                    .zip(right_row)
                    .all(|(left_value, right_value)| values_close(*left_value, *right_value))
        })
}

fn model_artifact_is_content_bound(
    report: &Value,
    transition: &[Value],
    states: usize,
    dimensions: usize,
    reported_sha256: &str,
) -> bool {
    let Some(model_artifact) = report.get("model_artifact").and_then(Value::as_object) else {
        return false;
    };
    let serialized_model = match serde_json::to_vec(&Value::Object(model_artifact.clone())) {
        Ok(bytes) => bytes,
        Err(_) => return false,
    };
    if !sha256_hex(&serialized_model).eq_ignore_ascii_case(reported_sha256)
        || model_artifact.get("states").and_then(Value::as_u64) != Some(states as u64)
        || model_artifact.get("dimensions").and_then(Value::as_u64) != Some(dimensions as u64)
    {
        return false;
    }
    let Some(report_dimensions) = report.get("dimensions").and_then(Value::as_array) else {
        return false;
    };
    if report_dimensions.len() != dimensions
        || report_dimensions
            .iter()
            .any(|dimension| non_empty_string(Some(dimension)).is_none())
    {
        return false;
    }

    let Some(model_transition) = finite_matrix(
        model_artifact.get("transition").unwrap_or(&Value::Null),
        states,
        states,
        false,
    ) else {
        return false;
    };
    let Some(report_transition) =
        finite_matrix(&Value::Array(transition.to_vec()), states, states, false)
    else {
        return false;
    };
    let Some(model_means) = finite_matrix(
        model_artifact.get("means").unwrap_or(&Value::Null),
        states,
        dimensions,
        false,
    ) else {
        return false;
    };
    let Some(report_means) = finite_matrix(
        report.get("standardized_means").unwrap_or(&Value::Null),
        states,
        dimensions,
        false,
    ) else {
        return false;
    };
    let Some(model_variances) = finite_matrix(
        model_artifact.get("variances").unwrap_or(&Value::Null),
        states,
        dimensions,
        true,
    ) else {
        return false;
    };
    let Some(report_variances) = finite_matrix(
        report.get("standardized_variances").unwrap_or(&Value::Null),
        states,
        dimensions,
        true,
    ) else {
        return false;
    };
    if !matrices_close(&model_transition, &report_transition)
        || !matrices_close(&model_means, &report_means)
        || !matrices_close(&model_variances, &report_variances)
    {
        return false;
    }

    let Some(profiles) = report.get("state_profiles").and_then(Value::as_array) else {
        return false;
    };
    profiles.iter().all(|profile| {
        let Some(state) = profile.get("raw_state_id").and_then(Value::as_u64) else {
            return false;
        };
        let state = state as usize;
        state < states
            && [
                "standardized_return_mean",
                "standardized_vwap_distance_mean",
                "standardized_volatility_mean",
                "standardized_activity_mean",
            ]
            .iter()
            .enumerate()
            .all(|(column, key)| {
                profile
                    .get(*key)
                    .and_then(Value::as_f64)
                    .is_some_and(|value| values_close(value, model_means[state][column]))
            })
    })
}
fn labeled_state_name(names: &[String], index: usize) -> String {
    format!(
        "{}#raw_{}",
        names.get(index).map(String::as_str).unwrap_or("STATE"),
        index
    )
}

fn named_probability_map(values: &[Value], names: &[String]) -> BTreeMap<String, Value> {
    values
        .iter()
        .enumerate()
        .map(|(index, value)| (labeled_state_name(names, index), value.clone()))
        .collect()
}

fn entropy(probabilities: &[f64]) -> f64 {
    probabilities
        .iter()
        .copied()
        .filter(|probability| *probability > 0.0)
        .map(|probability| -probability * probability.ln())
        .sum()
}

fn projected_probabilities(filtered: &[f64], transition: &[Value], steps: u64) -> Vec<f64> {
    let mut projected = filtered.to_vec();
    for _ in 0..steps {
        let mut next = vec![0.0; projected.len()];
        for (from, probability) in projected.iter().copied().enumerate() {
            let row = transition[from]
                .as_array()
                .expect("validated transition row");
            for (to, transition_probability) in row.iter().enumerate() {
                next[to] += probability * transition_probability.as_f64().unwrap_or_default();
            }
        }
        projected = next;
    }
    projected
}

fn posterior_transition_diagnostics(filtered: &[Value], transition: &[Value]) -> (f64, f64) {
    let states = filtered.len();
    let normalization = (states.max(2) as f64).ln();
    let mut stay_probability = 0.0;
    let mut transition_row_normalized_entropy = 0.0;
    for (from, posterior) in filtered.iter().enumerate() {
        let posterior = posterior.as_f64().unwrap_or_default();
        let row = transition[from]
            .as_array()
            .expect("validated transition row");
        stay_probability += posterior * row[from].as_f64().unwrap_or_default();
        let row_entropy = row
            .iter()
            .filter_map(Value::as_f64)
            .filter(|probability| *probability > 0.0)
            .map(|probability| -probability * probability.ln())
            .sum::<f64>();
        transition_row_normalized_entropy += posterior * row_entropy / normalization;
    }
    (
        (1.0 - stay_probability).clamp(0.0, 1.0),
        transition_row_normalized_entropy.clamp(0.0, 1.0),
    )
}

fn normalized_transition_audit(
    report: &Value,
    transition: &[Value],
    names: &[String],
) -> Option<Vec<Value>> {
    let cells = report.get("transition_audit")?.as_array()?;
    let states = names.len();
    if cells.len() != states.checked_mul(states)? {
        return None;
    }

    let mut normalized = vec![None; cells.len()];
    let mut row_sums = vec![0.0; states];
    let mut row_origins = vec![None; states];
    for cell in cells {
        let from = cell.get("from_raw_state_id")?.as_u64()? as usize;
        let to = cell.get("to_raw_state_id")?.as_u64()? as usize;
        if from >= states || to >= states {
            return None;
        }
        let index = from * states + to;
        if normalized[index].is_some() {
            return None;
        }
        let probability = cell.get("transition_probability")?.as_f64()?;
        let expected_count = cell.get("train_expected_transition_count")?.as_f64()?;
        let expected_origin = cell.get("train_expected_origin_count")?.as_f64()?;
        let count_semantics = non_empty_string(cell.get("count_semantics"))?;
        let matrix_probability = transition[from].as_array()?.get(to)?.as_f64()?;
        if !probability.is_finite()
            || !(0.0..=1.0).contains(&probability)
            || !values_close(probability, matrix_probability)
            || !expected_count.is_finite()
            || expected_count < 0.0
            || !expected_origin.is_finite()
            || expected_origin < 0.0
        {
            return None;
        }
        if let Some(origin) = row_origins[from] {
            if !values_close(origin, expected_origin) {
                return None;
            }
        } else {
            row_origins[from] = Some(expected_origin);
        }
        row_sums[from] += expected_count;
        normalized[index] = Some(json!({
            "from_state": labeled_state_name(names, from),
            "to_state": labeled_state_name(names, to),
            "from_raw_state_id": from,
            "to_raw_state_id": to,
            "transition_probability": probability,
            "train_expected_transition_count": expected_count,
            "train_expected_origin_count": expected_origin,
            "count_semantics": count_semantics,
            "status": "TRAIN_ONLY_SOFT_EXPECTED_COUNTS",
        }));
    }
    for from in 0..states {
        if !values_close(row_sums[from], row_origins[from]?) {
            return None;
        }
    }
    normalized.into_iter().collect::<Option<Vec<_>>>()
}

fn normalized_horizon_forecasts(
    report: &Value,
    filtered: &[Value],
    transition: &[Value],
    names: &[String],
    cadence_minutes: u64,
) -> Option<Vec<Value>> {
    if cadence_minutes != 5 {
        return None;
    }
    let rows = report.get("horizon_state_forecasts")?.as_array()?;
    if rows.len() != REQUIRED_STATE_HORIZONS.len() {
        return None;
    }
    let filtered_probabilities = probability_values(filtered, Some(names.len()))?;
    let mut normalized = vec![None; REQUIRED_STATE_HORIZONS.len()];

    for row in rows {
        let steps = row.get("horizon_steps")?.as_u64()?;
        let horizon_minutes = row.get("horizon_minutes")?.as_u64()?;
        let position = REQUIRED_STATE_HORIZONS
            .iter()
            .position(|expected| *expected == (steps, horizon_minutes))?;
        if normalized[position].is_some() {
            return None;
        }
        let status = non_empty_string(row.get("status"))?;
        let probability_semantics = non_empty_string(row.get("probability_semantics"))?;
        let available = status.starts_with("AVAILABLE");
        if !available && !status.starts_with("UNAVAILABLE") {
            return None;
        }
        let expected_endpoint = projected_probabilities(&filtered_probabilities, transition, steps);

        let (
            endpoint_probabilities,
            dominant_raw_state_id,
            dominant_state,
            dominant_probability,
            endpoint_entropy,
            normalized_endpoint_entropy,
            survival,
        ) = if available {
            let endpoint_values = row.get("endpoint_state_probabilities")?.as_array()?;
            let endpoint = probability_values(endpoint_values, Some(names.len()))?;
            if !endpoint
                .iter()
                .zip(&expected_endpoint)
                .all(|(reported, expected)| values_close(*reported, *expected))
            {
                return None;
            }
            let dominant = row.get("dominant_raw_state_id")?.as_u64()? as usize;
            let expected_dominant = endpoint
                .iter()
                .copied()
                .enumerate()
                .max_by(|left, right| left.1.total_cmp(&right.1))?
                .0;
            let reported_dominant_probability = row.get("dominant_probability")?.as_f64()?;
            let expected_entropy = entropy(&endpoint);
            let expected_normalized_entropy =
                (expected_entropy / (names.len().max(2) as f64).ln()).clamp(0.0, 1.0);
            let reported_entropy = row.get("endpoint_entropy")?.as_f64()?;
            let reported_normalized_entropy = row.get("normalized_endpoint_entropy")?.as_f64()?;
            let reported_survival = row
                .get("posterior_weighted_no_state_change_probability")?
                .as_f64()?;
            let expected_survival = filtered_probabilities
                .iter()
                .enumerate()
                .map(|(state, probability)| {
                    let self_transition = transition[state]
                        .as_array()
                        .and_then(|values| values.get(state))
                        .and_then(Value::as_f64)
                        .unwrap_or_default();
                    probability * self_transition.powf(steps as f64)
                })
                .sum::<f64>();
            if dominant != expected_dominant
                || !values_close(reported_dominant_probability, endpoint[dominant])
                || !values_close(reported_entropy, expected_entropy)
                || !values_close(reported_normalized_entropy, expected_normalized_entropy)
                || !values_close(reported_survival, expected_survival)
            {
                return None;
            }
            (
                Some(named_probability_map(endpoint_values, names)),
                Some(dominant),
                Some(labeled_state_name(names, dominant)),
                Some(reported_dominant_probability),
                Some(reported_entropy),
                Some(reported_normalized_entropy),
                Some(reported_survival),
            )
        } else {
            for key in [
                "endpoint_state_probabilities",
                "dominant_raw_state_id",
                "dominant_probability",
                "endpoint_entropy",
                "normalized_endpoint_entropy",
                "posterior_weighted_no_state_change_probability",
            ] {
                if !row.get(key).is_some_and(Value::is_null) {
                    return None;
                }
            }
            (None, None, None, None, None, None, None)
        };

        normalized[position] = Some(json!({
            "horizon_steps": steps,
            "transitions_ahead": steps,
            "horizon_minutes": horizon_minutes,
            "status": status,
            "endpoint_state_probabilities": endpoint_probabilities,
            "dominant_raw_state_id": dominant_raw_state_id,
            "dominant_state": dominant_state,
            "dominant_probability": dominant_probability,
            "endpoint_entropy": endpoint_entropy,
            "normalized_endpoint_entropy": normalized_endpoint_entropy,
            "posterior_weighted_no_state_change_probability": survival,
            "probability_semantics": probability_semantics,
        }));
    }
    normalized.into_iter().collect::<Option<Vec<_>>>()
}

fn validated_raw_state_certainty(
    report: &Value,
    filtered: &[Value],
    normalized_entropy: f64,
) -> Option<Value> {
    let source = report.get("raw_state_certainty")?.as_object()?;
    let mut ranked = probability_values(filtered, None)?;
    ranked.sort_by(|left, right| right.total_cmp(left));
    let expected_top = ranked.first().copied()?;
    let expected_margin =
        (expected_top - ranked.get(1).copied().unwrap_or_default()).clamp(0.0, 1.0);
    let top = source.get("top_probability")?.as_f64()?;
    let margin = source.get("top_two_probability_margin")?.as_f64()?;
    let reported_entropy = source.get("normalized_entropy")?.as_f64()?;
    let calibration_status = non_empty_string(source.get("calibration_status"))?;
    let semantics = non_empty_string(source.get("semantics"))?;
    if !values_close(top, expected_top)
        || !values_close(margin, expected_margin)
        || !values_close(reported_entropy, normalized_entropy)
        || source
            .get("direct_allocation_impact")
            .and_then(Value::as_bool)
            != Some(true)
        || source
            .get("continuous_sizing_impact")
            .and_then(Value::as_bool)
            != Some(false)
        || source
            .get("hard_no_trade_veto_impact")
            .and_then(Value::as_bool)
            != Some(true)
    {
        return None;
    }
    Some(json!({
        "top_probability": top,
        "top_two_probability_margin": margin,
        "normalized_entropy": reported_entropy,
        "calibration_status": calibration_status,
        "direct_allocation_impact": true,
        "continuous_sizing_impact": false,
        "hard_no_trade_veto_impact": true,
        "allocation_impact_semantics": "NO_CONTINUOUS_SIZING_IMPACT; HIGH_ENTROPY_CAN_TRIGGER_A_HARD_NO_TRADE_VETO",
        "semantics": semantics,
    }))
}
fn validated_duration_diagnostics(
    report: &Value,
    cadence_minutes: u64,
    filtered: &[Value],
) -> Option<Value> {
    let source = report.get("duration_diagnostics")?.as_object()?;
    let duration_model = non_empty_string(source.get("duration_model"))?;
    let observation_minutes = source.get("observation_minutes")?.as_u64()?;
    if observation_minutes != cadence_minutes
        || source
            .get("untruncated_geometric_diagnostic")
            .and_then(Value::as_bool)
            != Some(true)
        || source
            .get("session_close_truncation_applied")
            .and_then(Value::as_bool)
            != Some(false)
        || source
            .get("must_not_extrapolate_past_session_close")
            .and_then(Value::as_bool)
            != Some(true)
    {
        return None;
    }
    let optional_nonnegative_finite = |key: &str| match source.get(key)? {
        Value::Null => Some(None),
        value => value
            .as_f64()
            .filter(|number| number.is_finite() && *number >= 0.0)
            .map(Some),
    };
    let reported_spell =
        optional_nonnegative_finite("expected_spell_observations_including_current")?;
    let reported_future = optional_nonnegative_finite("expected_future_self_transitions")?;
    if reported_spell.is_some() != reported_future.is_some() {
        return None;
    }

    let probabilities = probability_values(filtered, None)?;
    let profiles = report.get("state_profiles")?.as_array()?;
    let mut expected_spell = 0.0;
    let mut expected_future = 0.0;
    let mut unbounded = false;
    for profile in profiles {
        let state = profile.get("raw_state_id")?.as_u64()? as usize;
        let probability = *probabilities.get(state)?;
        if non_empty_string(profile.get("duration_model"))? != duration_model {
            return None;
        }
        match (
            profile.get("expected_duration_observations")?,
            profile.get("expected_future_self_transitions")?,
        ) {
            (Value::Null, Value::Null) => {
                if probability > STATE_DURATION_ABSORBING_TOLERANCE {
                    unbounded = true;
                }
            }
            (duration, future) => {
                let duration = duration.as_f64()?;
                let future = future.as_f64()?;
                if !duration.is_finite() || !future.is_finite() || duration < 0.0 || future < 0.0 {
                    return None;
                }
                expected_spell += probability * duration;
                expected_future += probability * future;
            }
        }
    }
    if unbounded {
        if reported_spell.is_some() || reported_future.is_some() {
            return None;
        }
    } else if !reported_spell.is_some_and(|value| values_close(value, expected_spell))
        || !reported_future.is_some_and(|value| values_close(value, expected_future))
    {
        return None;
    }

    let semantics = non_empty_string(source.get("semantics"))?;
    Some(json!({
        "status": "AVAILABLE_MODEL_DIAGNOSTIC",
        "duration_model": duration_model,
        "expected_spell_observations_including_current": reported_spell,
        "expected_future_self_transitions": reported_future,
        "observation_minutes": observation_minutes,
        "expected_spell_minutes_including_current": reported_spell.map(|value| value * observation_minutes as f64),
        "untruncated_geometric_diagnostic": true,
        "censored_at_session_close": false,
        "session_close_truncation_applied": false,
        "must_not_extrapolate_past_session_close": true,
        "semantics": semantics,
    }))
}
fn freshness_payload(
    artifact_as_of: Option<&DateTime<Utc>>,
    evaluated_at: &DateTime<Utc>,
    maximum_age_seconds: i64,
) -> (Value, bool, &'static str) {
    let maximum_age_seconds = maximum_age_seconds.max(1);
    let Some(artifact_as_of) = artifact_as_of else {
        return (
            json!({
                "status": "UNAVAILABLE_NATIVE_AS_OF_MISSING",
                "evaluated_at": evaluated_at,
                "age_seconds": Value::Null,
                "maximum_age_seconds": maximum_age_seconds,
            }),
            false,
            "REGIME_ARTIFACT_NATIVE_AS_OF_MISSING_OR_INVALID",
        );
    };
    let age_seconds = evaluated_at
        .signed_duration_since(*artifact_as_of)
        .num_seconds();
    if age_seconds < 0 {
        return (
            json!({
                "status": "INVALID_FUTURE_OBSERVATION_CUTOFF",
                "evaluated_at": evaluated_at,
                "age_seconds": age_seconds,
                "maximum_age_seconds": maximum_age_seconds,
            }),
            false,
            "REGIME_ARTIFACT_OBSERVATION_CUTOFF_IS_IN_THE_FUTURE",
        );
    }
    let fresh = age_seconds <= maximum_age_seconds;
    (
        json!({
            "status": if fresh { "FRESH" } else { "STALE" },
            "evaluated_at": evaluated_at,
            "age_seconds": age_seconds,
            "maximum_age_seconds": maximum_age_seconds,
        }),
        fresh,
        if fresh {
            "REGIME_ARTIFACT_FRESH"
        } else {
            "REGIME_ARTIFACT_STALE_FAIL_CLOSED"
        },
    )
}

#[allow(clippy::too_many_arguments)]
fn build_state_current_payload(
    report: &Value,
    artifact_path: &Path,
    artifact_file_sha256: Option<String>,
    artifact_file_modified_at: Option<DateTime<Utc>>,
    unified_oof_competition: Option<&Value>,
    display_context_as_of: Option<&Value>,
    evaluated_at: DateTime<Utc>,
    maximum_age_seconds: i64,
) -> Value {
    let blocked = |reason: &str| {
        json!({
            "status": "BLOCKED",
            "reason": reason,
            "schema_version": "axio.market-state-engine.v2",
            "artifact_schema_version": report.get("schema_version"),
            "artifact_path": artifact_path,
            "artifact_file_sha256": artifact_file_sha256,
            "probability_semantics": "FORWARD_FILTERED_ONLY_NO_SMOOTHING",
        })
    };
    if report.get("schema_version").and_then(Value::as_str) != Some("axio.regime-artifact.v2") {
        return blocked("REGIME_ARTIFACT_V2_SCHEMA_VERSION_REQUIRED");
    }
    if non_empty_string(report.get("source")).is_none()
        || non_empty_string(report.get("model")).is_none()
    {
        return blocked("REGIME_ARTIFACT_V2_SOURCE_OR_MODEL_MISSING");
    }

    let Some(native_as_of) = report
        .get("as_of")
        .and_then(Value::as_str)
        .and_then(|value| DateTime::parse_from_rfc3339(value).ok())
        .map(|value| value.with_timezone(&Utc))
    else {
        return blocked("REGIME_ARTIFACT_V2_AS_OF_MISSING_OR_INVALID");
    };
    let Some(latest_input_available_at) = report
        .get("latest_input_available_at")
        .and_then(Value::as_str)
        .and_then(|value| DateTime::parse_from_rfc3339(value).ok())
        .map(|value| value.with_timezone(&Utc))
    else {
        return blocked("REGIME_ARTIFACT_V2_INPUT_AVAILABILITY_MISSING_OR_INVALID");
    };
    if report
        .get("input_availability_status")
        .and_then(Value::as_str)
        != Some("PERSISTED_POINT_IN_TIME")
        || latest_input_available_at > native_as_of
        || latest_input_available_at > evaluated_at
        || native_as_of > evaluated_at
    {
        return blocked("REGIME_ARTIFACT_V2_INPUT_AVAILABILITY_NOT_CAUSAL");
    }

    let Some(sessions) = report.get("sessions").and_then(Value::as_u64) else {
        return blocked("REGIME_ARTIFACT_V2_COVERAGE_INCOMPLETE");
    };
    let Some(observations) = report.get("observations").and_then(Value::as_u64) else {
        return blocked("REGIME_ARTIFACT_V2_COVERAGE_INCOMPLETE");
    };
    let Some(trained_through) = non_empty_string(report.get("trained_through"))
        .and_then(|value| NaiveDate::parse_from_str(value, "%Y-%m-%d").ok())
    else {
        return blocked("REGIME_ARTIFACT_V2_COVERAGE_INCOMPLETE");
    };
    let Some(current_session) = non_empty_string(report.get("current_session"))
        .and_then(|value| NaiveDate::parse_from_str(value, "%Y-%m-%d").ok())
    else {
        return blocked("REGIME_ARTIFACT_V2_COVERAGE_INCOMPLETE");
    };
    if sessions < 2
        || observations == 0
        || trained_through >= current_session
        || current_session > native_as_of.date_naive()
    {
        return blocked("REGIME_ARTIFACT_V2_COVERAGE_INVALID_OR_NON_CAUSAL");
    }

    let Some(feature_schema) = state_feature_schema(report) else {
        return blocked("REGIME_ARTIFACT_V2_FEATURE_SCHEMA_REQUIRED");
    };
    let Some(feature_schema_sha256) = non_empty_string(report.get("state_feature_schema_sha256"))
    else {
        return blocked("REGIME_ARTIFACT_V2_FEATURE_SCHEMA_HASH_REQUIRED");
    };
    let Some(model_artifact_sha256) = non_empty_string(report.get("model_artifact_sha256")) else {
        return blocked("REGIME_ARTIFACT_V2_MODEL_HASH_REQUIRED");
    };
    let recomputed_feature_schema_sha256 = sha256_hex(feature_schema.join("\u{1f}").as_bytes());
    if !is_sha256_hex(feature_schema_sha256)
        || !is_sha256_hex(model_artifact_sha256)
        || !feature_schema_sha256.eq_ignore_ascii_case(&recomputed_feature_schema_sha256)
    {
        return blocked("REGIME_ARTIFACT_V2_MODEL_OR_FEATURE_HASH_INVALID");
    }

    let Some(filtered) = report
        .get("current_filtered_probability")
        .and_then(Value::as_array)
        .cloned()
    else {
        return blocked("REGIME_ARTIFACT_V2_FILTERED_PROBABILITIES_REQUIRED");
    };
    let Some(transition) = report.get("transition").and_then(Value::as_array).cloned() else {
        return blocked("REGIME_ARTIFACT_V2_TRANSITION_MATRIX_REQUIRED");
    };
    let Some(filtered_probabilities) = probability_values(&filtered, None) else {
        return blocked("REGIME_ARTIFACT_V2_FILTERED_PROBABILITIES_INVALID");
    };
    let states = filtered.len();
    if states < 2
        || report.get("states").and_then(Value::as_u64) != Some(states as u64)
        || !transition_matrix_is_valid(&transition, states)
    {
        return blocked("REGIME_ARTIFACT_V2_STATE_COUNT_OR_TRANSITION_MATRIX_INVALID");
    }
    let Some(names) = state_profile_names(report, &transition, states) else {
        return blocked("REGIME_ARTIFACT_V2_STATE_PROFILES_INVALID_OR_SEMANTIC_LABEL_DISALLOWED");
    };
    if !model_artifact_is_content_bound(
        report,
        &transition,
        states,
        feature_schema.len(),
        model_artifact_sha256,
    ) {
        return blocked("REGIME_ARTIFACT_V2_MODEL_ARTIFACT_CONTENT_OR_HASH_INVALID");
    }
    let Some(state_definition) = report.get("state_definition").and_then(Value::as_object) else {
        return blocked("REGIME_ARTIFACT_V2_STATE_DEFINITION_REQUIRED");
    };
    let Some(cadence_minutes) = state_definition
        .get("cadence_minutes")
        .and_then(Value::as_u64)
    else {
        return blocked("REGIME_ARTIFACT_V2_STATE_DEFINITION_REQUIRED");
    };
    if cadence_minutes != 5
        || state_definition
            .get("session_reset")
            .and_then(Value::as_bool)
            != Some(true)
        || state_definition
            .get("cross_session_model_available")
            .and_then(Value::as_bool)
            != Some(false)
        || non_empty_string(report.get("probability_semantics")).is_none()
    {
        return blocked("REGIME_ARTIFACT_V2_STATE_DEFINITION_INVALID");
    }

    let expected_one_step = projected_probabilities(&filtered_probabilities, &transition, 1);
    let Some(model_implied_one_step) = report
        .get("one_step_model_implied_state_probability")
        .and_then(Value::as_array)
        .cloned()
    else {
        return blocked("REGIME_ARTIFACT_V2_ONE_STEP_MODEL_PROBABILITY_REQUIRED");
    };
    let Some(model_implied_values) = probability_values(&model_implied_one_step, Some(states))
    else {
        return blocked("REGIME_ARTIFACT_V2_ONE_STEP_MODEL_PROBABILITY_INVALID");
    };
    if !model_implied_values
        .iter()
        .zip(&expected_one_step)
        .all(|(reported, expected)| values_close(*reported, *expected))
    {
        return blocked("REGIME_ARTIFACT_V2_ONE_STEP_MODEL_PROBABILITY_INCONSISTENT");
    }

    let Some(next_probability_status) =
        non_empty_string(report.get("next_state_probability_status"))
    else {
        return blocked("REGIME_ARTIFACT_V2_SAME_SESSION_NEXT_STATUS_REQUIRED");
    };
    let optional_next = match report.get("next_state_probability") {
        Some(Value::Null) if next_probability_status.starts_with("UNAVAILABLE") => None,
        Some(Value::Array(values)) if next_probability_status.starts_with("AVAILABLE") => {
            let Some(probabilities) = probability_values(values, Some(states)) else {
                return blocked("REGIME_ARTIFACT_V2_SAME_SESSION_NEXT_PROBABILITY_INVALID");
            };
            if !probabilities
                .iter()
                .zip(&expected_one_step)
                .all(|(reported, expected)| values_close(*reported, *expected))
            {
                return blocked("REGIME_ARTIFACT_V2_SAME_SESSION_NEXT_PROBABILITY_INCONSISTENT");
            }
            Some(values.clone())
        }
        _ => return blocked("REGIME_ARTIFACT_V2_SAME_SESSION_NEXT_STATUS_OR_VALUE_INVALID"),
    };

    let Some(transition_audit) = normalized_transition_audit(report, &transition, &names) else {
        return blocked("REGIME_ARTIFACT_V2_TRANSITION_AUDIT_INVALID");
    };
    let Some(horizon_state_forecasts) =
        normalized_horizon_forecasts(report, &filtered, &transition, &names, cadence_minutes)
    else {
        return blocked("REGIME_ARTIFACT_V2_HORIZON_FORECASTS_INVALID_OR_INCOMPLETE");
    };
    let one_step_horizon_available = horizon_state_forecasts
        .first()
        .and_then(|row| row.get("status"))
        .and_then(Value::as_str)
        .is_some_and(|status| status.starts_with("AVAILABLE"));
    if one_step_horizon_available != optional_next.is_some() {
        return blocked("REGIME_ARTIFACT_V2_ONE_STEP_HORIZON_AND_NEXT_STATUS_INCONSISTENT");
    }

    let expected_entropy = entropy(&filtered_probabilities);
    let expected_normalized_entropy =
        (expected_entropy / (states.max(2) as f64).ln()).clamp(0.0, 1.0);
    let Some(reported_entropy) = report.get("regime_entropy").and_then(Value::as_f64) else {
        return blocked("REGIME_ARTIFACT_V2_REGIME_ENTROPY_REQUIRED");
    };
    let Some(normalized_entropy) = report
        .get("normalized_regime_entropy")
        .and_then(Value::as_f64)
    else {
        return blocked("REGIME_ARTIFACT_V2_NORMALIZED_REGIME_ENTROPY_REQUIRED");
    };
    let (derived_change_probability, derived_transition_entropy) =
        posterior_transition_diagnostics(&filtered, &transition);
    let Some(one_step_change_probability) = report
        .get("one_step_change_probability")
        .and_then(Value::as_f64)
    else {
        return blocked("REGIME_ARTIFACT_V2_ONE_STEP_CHANGE_PROBABILITY_REQUIRED");
    };
    let Some(transition_row_normalized_entropy) = report
        .get("transition_row_normalized_entropy")
        .and_then(Value::as_f64)
    else {
        return blocked("REGIME_ARTIFACT_V2_TRANSITION_ROW_ENTROPY_REQUIRED");
    };
    if !reported_entropy.is_finite()
        || !normalized_entropy.is_finite()
        || !one_step_change_probability.is_finite()
        || !transition_row_normalized_entropy.is_finite()
        || !values_close(reported_entropy, expected_entropy)
        || !values_close(normalized_entropy, expected_normalized_entropy)
        || !values_close(one_step_change_probability, derived_change_probability)
        || !values_close(
            transition_row_normalized_entropy,
            derived_transition_entropy,
        )
    {
        return blocked("REGIME_ARTIFACT_V2_REPORTED_STATE_DIAGNOSTICS_INCONSISTENT");
    }
    let Some(certainty) = validated_raw_state_certainty(report, &filtered, normalized_entropy)
    else {
        return blocked("REGIME_ARTIFACT_V2_RAW_STATE_CERTAINTY_INVALID_OR_INCONSISTENT");
    };
    let Some(artifact_decision_boundary) =
        report.get("decision_boundary").and_then(Value::as_object)
    else {
        return blocked("REGIME_ARTIFACT_V2_DECISION_BOUNDARY_REQUIRED");
    };
    if artifact_decision_boundary
        .get("direct_allocation_impact")
        .and_then(Value::as_bool)
        != Some(true)
        || artifact_decision_boundary
            .get("continuous_sizing_impact")
            .and_then(Value::as_bool)
            != Some(false)
        || artifact_decision_boundary
            .get("hard_no_trade_veto_impact")
            .and_then(Value::as_bool)
            != Some(true)
        || artifact_decision_boundary
            .get("execution_eligible")
            .and_then(Value::as_bool)
            != Some(false)
        || non_empty_string(artifact_decision_boundary.get("forecast_conditioning_role")).is_none()
        || non_empty_string(artifact_decision_boundary.get("allocation_impact_semantics")).is_none()
        || non_empty_string(artifact_decision_boundary.get("confidence_semantics")).is_none()
    {
        return blocked("REGIME_ARTIFACT_V2_DECISION_BOUNDARY_INVALID_OR_CONFLICTING");
    }
    let Some(duration_diagnostics) =
        validated_duration_diagnostics(report, cadence_minutes, &filtered)
    else {
        return blocked("REGIME_ARTIFACT_V2_DURATION_DIAGNOSTICS_INVALID_OR_INCOMPLETE");
    };

    let (freshness, fresh, freshness_reason) =
        freshness_payload(Some(&native_as_of), &evaluated_at, maximum_age_seconds);
    let state_count_unresolved = match report
        .pointer("/model_selection/selected_at_candidate_boundary")
        .and_then(Value::as_bool)
    {
        Some(value) => value,
        None => return blocked("REGIME_ARTIFACT_V2_MODEL_SELECTION_STATUS_REQUIRED"),
    };
    let (artifact_status, reason) = if !fresh {
        ("STALE_UNAVAILABLE", freshness_reason)
    } else if state_count_unresolved {
        (
            "DEGRADED",
            "REGIME_STATE_COUNT_OPTIMUM_UNRESOLVED_AT_CANDIDATE_BOUNDARY",
        )
    } else {
        ("AVAILABLE", "CURRENT_CAUSAL_REGIME_ARTIFACT")
    };
    let top_state_index = filtered
        .iter()
        .enumerate()
        .max_by(|left, right| {
            left.1
                .as_f64()
                .unwrap_or_default()
                .total_cmp(&right.1.as_f64().unwrap_or_default())
        })
        .map(|(index, _)| index);
    let probabilities = named_probability_map(&filtered, &names);
    let next_probabilities = optional_next
        .as_deref()
        .map(|values| named_probability_map(values, &names));
    let model_implied_one_step_probabilities =
        named_probability_map(&model_implied_one_step, &names);
    let Some(cross_session_source) = report
        .get("cross_session_state_forecast")
        .and_then(Value::as_object)
    else {
        return blocked("REGIME_ARTIFACT_V2_CROSS_SESSION_STATUS_REQUIRED");
    };
    let Some(cross_session_status) = non_empty_string(cross_session_source.get("status")) else {
        return blocked("REGIME_ARTIFACT_V2_CROSS_SESSION_STATUS_INVALID");
    };
    if !cross_session_status.starts_with("UNAVAILABLE")
        || cross_session_source
            .get("today_to_tomorrow_claim_supported")
            .and_then(Value::as_bool)
            != Some(false)
    {
        return blocked("REGIME_ARTIFACT_V2_CROSS_SESSION_STATUS_INVALID");
    }
    let optional_cross_session_text = |key: &str| match cross_session_source.get(key) {
        None | Some(Value::Null) => Some(None),
        value => non_empty_string(value).map(Some),
    };
    let Some(cross_session_reason) = optional_cross_session_text("reason") else {
        return blocked("REGIME_ARTIFACT_V2_CROSS_SESSION_REASON_INVALID");
    };
    let Some(cross_session_semantics) = optional_cross_session_text("semantics") else {
        return blocked("REGIME_ARTIFACT_V2_CROSS_SESSION_SEMANTICS_INVALID");
    };
    let cross_session_state_forecast = json!({
        "status": cross_session_status,
        "today_to_tomorrow_claim_supported": false,
        "reason": cross_session_reason,
        "semantics": cross_session_semantics,
    });
    let decision_boundary = json!({
        "forecast_conditioning_role": artifact_decision_boundary.get("forecast_conditioning_role"),
        "direct_allocation_impact": artifact_decision_boundary.get("direct_allocation_impact"),
        "continuous_sizing_impact": artifact_decision_boundary.get("continuous_sizing_impact"),
        "hard_no_trade_veto_impact": artifact_decision_boundary.get("hard_no_trade_veto_impact"),
        "allocation_impact_semantics": artifact_decision_boundary.get("allocation_impact_semantics"),
        "execution_eligible": artifact_decision_boundary.get("execution_eligible"),
        "confidence_semantics": artifact_decision_boundary.get("confidence_semantics"),
        "same_session_only": true,
        "cross_session_forecast_status": cross_session_state_forecast.get("status").cloned().unwrap_or_else(|| json!("UNAVAILABLE")),
    });

    let live_outputs_available = artifact_status == "AVAILABLE";
    let current_state = if live_outputs_available {
        json!({
            "status": "AVAILABLE",
            "semantic_state": top_state_index.and_then(|index| names.get(index)),
            "raw_state_id": top_state_index,
            "filtered_state_probabilities": probabilities,
            "next_state_probabilities": next_probabilities,
            "next_state_probability_status": next_probability_status,
            "one_step_model_implied_state_probabilities": model_implied_one_step_probabilities,
            "one_step_model_implied_status": "DIAGNOSTIC_ONLY_DO_NOT_EXTRAPOLATE_ACROSS_SESSION_BOUNDARY",
            "regime_entropy": reported_entropy,
            "normalized_regime_entropy": normalized_entropy,
            "one_step_change_probability": one_step_change_probability,
            "transition_row_normalized_entropy": transition_row_normalized_entropy,
            "probability_semantics": report.get("probability_semantics"),
        })
    } else {
        json!({
            "status": "UNAVAILABLE_LIVE_ARTIFACT_NOT_AVAILABLE",
            "reason": reason,
            "semantic_state": Value::Null,
            "raw_state_id": Value::Null,
            "filtered_state_probabilities": Value::Null,
            "next_state_probabilities": Value::Null,
            "next_state_probability_status": "UNAVAILABLE_LIVE_ARTIFACT_NOT_AVAILABLE",
            "one_step_model_implied_state_probabilities": Value::Null,
            "one_step_model_implied_status": "UNAVAILABLE_LIVE_ARTIFACT_NOT_AVAILABLE",
            "regime_entropy": Value::Null,
            "normalized_regime_entropy": Value::Null,
            "one_step_change_probability": Value::Null,
            "transition_row_normalized_entropy": Value::Null,
            "probability_semantics": report.get("probability_semantics"),
        })
    };
    let public_horizon_state_forecasts = if live_outputs_available {
        horizon_state_forecasts
    } else {
        horizon_state_forecasts
            .iter()
            .map(|row| {
                json!({
                    "horizon_steps": row.get("horizon_steps"),
                    "transitions_ahead": row.get("transitions_ahead"),
                    "horizon_minutes": row.get("horizon_minutes"),
                    "status": "UNAVAILABLE_LIVE_ARTIFACT_NOT_AVAILABLE",
                    "artifact_forecast_status": row.get("status"),
                    "endpoint_state_probabilities": Value::Null,
                    "dominant_raw_state_id": Value::Null,
                    "dominant_state": Value::Null,
                    "dominant_probability": Value::Null,
                    "endpoint_entropy": Value::Null,
                    "normalized_endpoint_entropy": Value::Null,
                    "posterior_weighted_no_state_change_probability": Value::Null,
                    "probability_semantics": row.get("probability_semantics"),
                })
            })
            .collect::<Vec<_>>()
    };
    let public_certainty = if live_outputs_available {
        certainty
    } else {
        json!({
            "status": "UNAVAILABLE_LIVE_ARTIFACT_NOT_AVAILABLE",
            "top_probability": Value::Null,
            "top_two_probability_margin": Value::Null,
            "normalized_entropy": Value::Null,
            "calibration_status": "UNAVAILABLE_LIVE_ARTIFACT_NOT_AVAILABLE",
            "direct_allocation_impact": true,
            "continuous_sizing_impact": false,
            "hard_no_trade_veto_impact": true,
            "allocation_impact_semantics": "NO_CONTINUOUS_SIZING_IMPACT; HIGH_ENTROPY_CAN_TRIGGER_A_HARD_NO_TRADE_VETO",
        })
    };
    let public_duration_diagnostics = if live_outputs_available {
        duration_diagnostics
    } else {
        json!({
            "status": "UNAVAILABLE_LIVE_ARTIFACT_NOT_AVAILABLE",
            "duration_model": duration_diagnostics.get("duration_model"),
            "expected_spell_observations_including_current": Value::Null,
            "expected_future_self_transitions": Value::Null,
            "observation_minutes": duration_diagnostics.get("observation_minutes"),
            "expected_spell_minutes_including_current": Value::Null,
            "untruncated_geometric_diagnostic": true,
            "censored_at_session_close": false,
            "session_close_truncation_applied": false,
            "must_not_extrapolate_past_session_close": true,
            "semantics": duration_diagnostics.get("semantics"),
        })
    };
    let coverage = json!({
        "trained_through": report.get("trained_through"),
        "current_session": report.get("current_session"),
        "sessions": report.get("sessions"),
        "observations": report.get("observations"),
    });
    let competitor_status = if unified_oof_competition.is_some() {
        "OOF_COMPETITOR_MATERIALIZED"
    } else {
        "RUNNER_AVAILABLE_NO_ARTIFACT"
    };
    let baseline_status = if unified_oof_competition.is_some() {
        "OOF_BASELINE_MATERIALIZED"
    } else {
        "RUNNER_AVAILABLE_NO_ARTIFACT"
    };
    let public_comparison = json!({
        "model": "public_gmm4_detector",
        "states": 4,
        "selected": false,
        "status": "BLOCKED_MISSING_POINT_IN_TIME_17_FACTOR_ARCHIVE",
        "purpose": "CURRENT_MACRO_REGIME_DESCRIPTION_ONLY_NOT_A_TRANSITION_FORECAST",
    });
    let hmm_comparison = json!({
        "model": "diagonal_gaussian_hmm",
        "states": report.get("states"),
        "validation_log_likelihood": report.pointer("/model_selection/candidate_scores"),
        "test_log_likelihood": report.pointer("/purged_forward_validation/test_average_log_likelihood"),
        "selected": true,
        "selection_criterion": report.pointer("/model_selection/criterion"),
        "eight_state_challenger_status": report.pointer("/model_selection/eight_state_challenger_status"),
        "status": "CHRONOLOGICAL_K_SELECTION_THEN_PRIOR_SESSION_REFIT",
    });
    let model_comparisons = vec![
        public_comparison,
        hmm_comparison,
        json!({"model":"student_t_hmm","selected":false,"status":competitor_status}),
        json!({"model":"minimum_duration_hsmm","selected":false,"status":competitor_status}),
        json!({"model":"tvtp_gaussian_hmm","selected":false,"status":competitor_status}),
        json!({"model":"no_regime_diagonal_gaussian","selected":false,"status":baseline_status}),
    ];
    let caveats = json!([
        "Latent-state probabilities are raw model-implied diagnostics, not calibrated return confidence.",
        "The intraday HMM resets by session and does not support a today-to-tomorrow state forecast.",
        "Train expected transition counts are fractional smoothed-xi mass, not observed hard tallies.",
        "Duration is untruncated geometric-HMM implied and must not be extrapolated past the session boundary."
    ]);
    let research_only_policy = json!({
        "product_scope": "IMPERSONAL_WHOLE_MARKET_STATISTICAL_RESEARCH",
        "personalization_used": false,
        "direct_allocation_impact": true,
        "continuous_sizing_impact": false,
        "hard_no_trade_veto_impact": true,
        "allocation_impact_semantics": "NO_CONTINUOUS_SIZING_IMPACT; HIGH_ENTROPY_CAN_TRIGGER_A_HARD_NO_TRADE_VETO",
        "execution_eligible": false,
        "investment_advice": false,
    });
    let metadata = json!({
        "status": artifact_status,
        "reason": reason,
        "schema_version": "axio.market-state-engine.v2",
        "artifact_schema_version": report.get("schema_version"),
        "as_of": native_as_of,
        "observation_cutoff": native_as_of,
        "latest_input_available_at": latest_input_available_at,
        "input_availability_status": report.get("input_availability_status"),
        "freshness": freshness,
        "artifact_file_modified_at": artifact_file_modified_at,
        "display_context_as_of": display_context_as_of,
    });
    let integrity = json!({
        "state_artifact_as_of_status": "PERSISTED_POINT_IN_TIME",
        "artifact_path": artifact_path,
        "artifact_file_sha256": artifact_file_sha256,
        "model_artifact_sha256": report.get("model_artifact_sha256"),
        "model_artifact_integrity_status": "CONTENT_BOUND_SELF_HASH_NOT_TRUSTED_REGISTRY",
        "model_validation_status": report.get("model_validation_status").cloned().unwrap_or_else(|| json!(if state_count_unresolved { "EXPLORATORY_BOUNDARY_OPTIMUM_NOT_PROMOTABLE" } else { "ARTIFACT_STRUCTURE_VALIDATED_PREDICTIVE_VALIDATION_SEPARATE" })),
        "source": report.get("source"),
        "coverage": coverage,
        "state_definition": report.get("state_definition"),
        "state_feature_schema": feature_schema,
        "state_feature_schema_sha256": feature_schema_sha256,
        "state_mapping_semantics": "DIRECT_FROM_ARTIFACT_STATE_PROFILES_TRAIN_ONLY_SEMANTIC_MAPPING",
        "probability_semantics": report.get("probability_semantics"),
    });
    let diagnostics = json!({
        "current_state": current_state,
        "raw_state_certainty": public_certainty,
        "duration_diagnostics": public_duration_diagnostics,
        "state_profiles": report.get("state_profiles"),
        "state_names": names,
        "horizon_state_forecasts": public_horizon_state_forecasts,
        "cross_session_state_forecast": cross_session_state_forecast,
        "transition_audit": transition_audit,
        "decision_boundary": decision_boundary,
    });
    let evidence = json!({
        "model_comparisons": model_comparisons,
        "unified_oof_competition": unified_oof_competition,
        "evidence_grade": report.get("evidence"),
        "causality": report.get("causality"),
        "caveats": caveats,
        "research_only_policy": research_only_policy,
    });
    let mut payload = serde_json::Map::new();
    for chunk in [metadata, integrity, diagnostics, evidence] {
        payload.extend(
            chunk
                .as_object()
                .expect("state response chunks are JSON objects")
                .clone(),
        );
    }
    Value::Object(payload)
}

pub async fn state_current(State(state): State<AppState>) -> Json<Value> {
    let path = data_root(&state).join("reports/regime_latest.json");
    let unified_oof_competition =
        read_json(&data_root(&state).join("reports/regime_oof_competition_latest.json"));
    let Some(report) = read_json(&path) else {
        return Json(json!({
            "status": "UNAVAILABLE",
            "reason": "REGIME_ARTIFACT_ABSENT",
            "schema_version": "axio.market-state-engine.v2",
            "probability_semantics": "FORWARD_FILTERED_ONLY_NO_SMOOTHING",
        }));
    };
    let artifact_file_sha256 = fs::read(&path).ok().map(|bytes| sha256_hex(&bytes));
    let artifact_file_modified_at = fs::metadata(&path)
        .and_then(|metadata| metadata.modified())
        .ok()
        .map(DateTime::<Utc>::from);
    let forecast_as_of = latest_forecast_contract(&state)
        .and_then(|artifact| {
            artifact
                .get("prediction_layer")
                .and_then(Value::as_array)
                .cloned()
        })
        .and_then(|rows| {
            rows.into_iter()
                .filter_map(|row| row.get("decision_as_of").cloned())
                .max_by(|left, right| left.as_str().cmp(&right.as_str()))
        });
    Json(build_state_current_payload(
        &report,
        &path,
        artifact_file_sha256,
        artifact_file_modified_at,
        unified_oof_competition.as_ref(),
        forecast_as_of.as_ref(),
        Utc::now(),
        state.config.os.freshness_limit_seconds,
    ))
}

pub async fn research_factory(State(state): State<AppState>) -> Json<Value> {
    let root = data_root(&state);
    let validation = read_json(&root.join("reports/negative_controls_latest.json"));
    let pattern_run = read_json(&root.join("reports/pattern_factory_latest.json"));
    let shadow = {
        let path = root.join("state/prediction_ledger.sqlite3");
        if path.exists() {
            PredictionLedger::open(&path)
                .ok()
                .and_then(|ledger| ledger.shadow_status().ok())
        } else {
            None
        }
    };
    let registry_path = root.join("state/research_hypotheses.sqlite3");
    let registry_payload = if registry_path.exists() {
        let worker_path = registry_path.clone();
        tokio::task::spawn_blocking(move || -> anyhow::Result<Value> {
            let registry = DurableHypothesisRegistry::open(&worker_path)?;
            let reconstruction = registry.reconstruct()?;
            let records = reconstruction.latest_records;
            let variant_count = records
                .iter()
                .map(|record| record.number_of_variants_tried)
                .sum::<usize>();
            let promoted_count = records
                .iter()
                .filter(|record| record.current_status == HypothesisStatus::PaperEligible)
                .count();
            let motif_count = records
                .iter()
                .filter(|record| {
                    let identity = format!(
                        "{} {}",
                        record.identity.target,
                        record.identity.feature_specification.join(" ")
                    )
                    .to_ascii_lowercase();
                    identity.contains("motif") || identity.contains("path")
                })
                .count();
            let anomaly_count = records
                .iter()
                .filter(|record| {
                    record
                        .identity
                        .target
                        .to_ascii_lowercase()
                        .contains("anomal")
                })
                .count();
            let mut status_counts = BTreeMap::<String, usize>::new();
            for record in &records {
                let status = serde_json::to_value(record.current_status)?
                    .as_str()
                    .unwrap_or("UNKNOWN")
                    .to_string();
                *status_counts.entry(status).or_default() += 1;
            }
            Ok(json!({
                "status": if reconstruction.audit.hypothesis_count == 0 { "EMPTY" } else { "AVAILABLE" },
                "reason": if reconstruction.audit.hypothesis_count == 0 {
                    "DURABLE_REGISTRY_MATERIALIZED_BUT_EMPTY"
                } else {
                    "DURABLE_APPEND_ONLY_REGISTRY_RECONSTRUCTED"
                },
                "registry_materialized": true,
                "append_only_registry": true,
                "registry_chain_sha256": reconstruction.chain_sha256,
                "registry_audit": reconstruction.audit,
                "hypothesis_count": records.len(),
                "variant_count": variant_count,
                "promoted_count": promoted_count,
                "motif_count": motif_count,
                "anomaly_count": anomaly_count,
                "status_counts": status_counts,
                "hypotheses": records,
            }))
        })
        .await
        .map_err(anyhow::Error::from)
        .and_then(|result| result)
        .unwrap_or_else(|error| {
            json!({
                "status": "DEGRADED",
                "reason": "DURABLE_REGISTRY_RECONSTRUCTION_FAILED",
                "detail": error.to_string(),
                "registry_materialized": true,
                "hypothesis_count": 0,
                "variant_count": 0,
                "promoted_count": 0,
                "motif_count": 0,
                "anomaly_count": 0,
                "hypotheses": [],
            })
        })
    } else {
        json!({
            "status": "BLOCKED",
            "reason": "DURABLE_REGISTRY_NOT_MATERIALIZED",
            "registry_materialized": false,
            "hypothesis_count": 0,
            "variant_count": 0,
            "promoted_count": 0,
            "motif_count": 0,
            "anomaly_count": 0,
            "status_counts": {},
            "hypotheses": [],
        })
    };
    let mut response = registry_payload;
    if let Some(object) = response.as_object_mut() {
        let motif_rows = pattern_run
            .as_ref()
            .and_then(|report| report.get("candidates"))
            .and_then(Value::as_array)
            .map(|rows| {
                rows.iter()
                    .map(|candidate| {
                        let bps_to_return = |pointer: &str| {
                            candidate.pointer(pointer).and_then(Value::as_f64).map(|value| value / 10_000.0)
                        };
                        json!({
                            "hypothesis_id": candidate.pointer("/motif/motif_id"),
                            "method": "projection_seeded_exact_normalized_distance",
                            "window_minutes": candidate.pointer("/motif/metadata/duration_minutes"),
                            "symbol": candidate.pointer("/motif/symbol"),
                            "independent_episodes": candidate.pointer("/motif/concentration/independent_days"),
                            "oos_effect": bps_to_return("/motif/oos_evidence/test_gross_mean_bps"),
                            "bootstrap_ci_low": bps_to_return("/motif/oos_evidence/test_net_day_block_bootstrap/lower_bps"),
                            "bootstrap_ci_high": bps_to_return("/motif/oos_evidence/test_net_day_block_bootstrap/upper_bps"),
                            "net_effect_after_cost": bps_to_return("/motif/oos_evidence/test_net_mean_bps"),
                            "decay_status": if candidate.pointer("/motif/recent_decay/decayed").and_then(Value::as_bool) == Some(true) { "DECAYED" } else { "NO_DECAY_DETECTED" },
                            "negative_control_status": if candidate.pointer("/motif/negative_controls/passed").and_then(Value::as_bool) == Some(true) { "PASSED_MOTIF_SPECIFIC_CONTROLS" } else { "FAILED_OR_INCOMPLETE" },
                            "raw_p_value": candidate.get("raw_permutation_p_value"),
                            "q_value": candidate.get("fdr_adjusted_p_value"),
                            "status": candidate.get("lifecycle_status"),
                            "strategy": candidate.get("strategy"),
                        })
                    })
                    .collect::<Vec<_>>()
            })
            .unwrap_or_default();
        let independent_episode_count = motif_rows
            .iter()
            .filter_map(|row| row.get("independent_episodes").and_then(Value::as_u64))
            .sum::<u64>();
        let motif_count = motif_rows.len();
        if pattern_run.is_some() {
            object.insert("status".into(), json!("AVAILABLE"));
            object.insert(
                "reason".into(),
                json!("AUTONOMOUS_PATTERN_RUN_MATERIALIZED_DURABLE_REGISTRY_OPTIONAL"),
            );
        }
        object.insert("schema_version".into(), json!("axio.research-factory.v1"));
        object.insert("motif_count".into(), json!(motif_count));
        object.insert(
            "independent_episode_count".into(),
            json!(independent_episode_count),
        );
        object.insert(
            "negative_control_survival_rate".into(),
            if motif_count == 0 {
                Value::Null
            } else {
                json!(
                    motif_rows
                        .iter()
                        .filter(
                            |row| row.get("negative_control_status").and_then(Value::as_str)
                                == Some("PASSED_MOTIF_SPECIFIC_CONTROLS")
                        )
                        .count() as f64
                        / motif_count as f64
                )
            },
        );
        object.insert(
            "pipeline_stages".into(),
            json!([
                {"stage":"candidate_generation","status":if pattern_run.is_some(){"MATERIALIZED"}else{"RUNNER_AVAILABLE_NO_ARTIFACT"}},
                {"stage":"deduplication","status":"DURABLE_REGISTRY_IMPLEMENTED"},
                {"stage":"train_only_screening","status":if pattern_run.is_some(){"MATERIALIZED_DISCOVERY_ONLY"}else{"RUNNER_AVAILABLE_NO_ARTIFACT"}},
                {"stage":"purged_validation","status":if pattern_run.is_some(){"MATERIALIZED"}else{"RUNNER_AVAILABLE_NO_ARTIFACT"}},
                {"stage":"calibration","status":"CONTRACT_DEFINED_NOT_MATERIALIZED"},
                {"stage":"untouched_test","status":if pattern_run.is_some(){"REPLAY_TEST_REPORTED_NOT_NEW_UNTOUCHED_HOLDOUT"}else{"NOT_MATERIALIZED"}},
                {"stage":"forward_shadow","count":shadow.as_ref().and_then(|row| row.get("verified_realtime_forward_predictions")).cloned().unwrap_or(json!(0)),"status":"SEPARATE_PREDICTION_LEDGER_ACCUMULATING"},
                {"stage":"decay_monitoring","status":"PENDING_MINIMUM_FORWARD_SAMPLE"}
            ]),
        );
        object.insert("motifs".into(), json!(motif_rows));
        object.insert("anomalies".into(), json!([]));
        object.insert(
            "motif_windows".into(),
            json!(["3m", "5m", "10m", "15m", "30m", "60m"]),
        );
        object.insert(
            "motif_representations".into(),
            json!([
                "log_return",
                "volatility_adjusted_return",
                "residual_return",
                "relative_strength_return",
                "volume_log_change",
                "volatility_change"
            ]),
        );
        object.insert(
            "motif_methods".into(),
            json!([
                "exact_matrix_profile",
                "deterministic_projection_seeded_exact_distance",
                "nonoverlapping_subsequence_nearest_neighbor",
                "change_point_diagnostic"
            ]),
        );
        object.insert(
            "negative_controls".into(),
            json!([
                {"control":"label_shuffle","status":"REQUIRED_NOT_EXECUTED_BY_FACTORY_RUNNER"},
                {"control":"timestamp_shuffle","status":if pattern_run.is_some(){"EXECUTED_PER_MOTIF"}else{"NOT_EXECUTED"}},
                {"control":"return_sign_shuffle","status":if pattern_run.is_some(){"EXECUTED_PER_MOTIF"}else{"NOT_EXECUTED"}},
                {"control":"within_day_block_permutation","status":"REQUIRED_NOT_EXECUTED_BY_FACTORY_RUNNER"},
                {"control":"cross_symbol_placebo","status":"REQUIRED_NOT_EXECUTED_BY_FACTORY_RUNNER"},
                {"control":"future_feature_trap","status":"REQUIRED_NOT_EXECUTED_BY_FACTORY_RUNNER"},
                {"control":"random_motif","status":if pattern_run.is_some(){"EXECUTED_PER_MOTIF"}else{"NOT_EXECUTED"}},
                {"control":"random_analog_neighbor","status":if pattern_run.is_some(){"EXECUTED_PER_MOTIF"}else{"NOT_EXECUTED"}},
                {"control":"wrong_regime_placebo","status":"REQUIRED_NOT_EXECUTED_BY_FACTORY_RUNNER"},
                {"control":"reversed_lead_lag","status":"REQUIRED_NOT_EXECUTED_BY_FACTORY_RUNNER"},
                {"control":"delayed_availability","status":"REQUIRED_NOT_EXECUTED_BY_FACTORY_RUNNER"},
                {"control":"duplicated_row","status":"REQUIRED_NOT_EXECUTED_BY_FACTORY_RUNNER"},
                {"control":"synthetic_gap","status":"REQUIRED_NOT_EXECUTED_BY_FACTORY_RUNNER"}
            ]),
        );
        object.insert(
            "stored_validation_artifact".into(),
            validation.unwrap_or(Value::Null),
        );
        object.insert("forward_shadow".into(), shadow.unwrap_or(Value::Null));
        object.insert(
            "execution_runner_status".into(),
            json!(if pattern_run.is_some() {
                "MATERIALIZED_RESEARCH_AND_SHADOW_ONLY"
            } else {
                "AVAILABLE_NO_RUN_ARTIFACT"
            }),
        );
        object.insert("pattern_run".into(), pattern_run.unwrap_or(Value::Null));
        object.insert(
            "decay".into(),
            json!({
                "status": "PENDING_MINIMUM_FORWARD_SAMPLE",
                "retirement_rule": "DECAYED when predeclared recent-window effect or calibration gate fails"
            }),
        );
        object.insert(
            "promotion_status".into(),
            json!("NO_REPRODUCIBLE_PAPER_ELIGIBILITY_CLAIM"),
        );
        object.insert(
            "evidence_grade".into(),
            json!("RESEARCH_MECHANISMS_ONLY_NO_VALIDATED_EDGE"),
        );
    }
    Json(response)
}

pub async fn audit_predictions(State(state): State<AppState>) -> Json<Value> {
    let forecast_path = data_root(&state).join("reports/forecast_contract_live_latest.json");
    let artifact = read_json(&forecast_path).unwrap_or_else(|| json!({}));
    let contracts = artifact
        .get("prediction_layer")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();
    let ledger_path = data_root(&state).join("state/prediction_ledger.sqlite3");
    let (ledger_status, settlement_statuses, append_only_guards_present) = if ledger_path.exists() {
        match PredictionLedger::open(&ledger_path) {
            Ok(ledger) => (
                ledger.shadow_status().ok(),
                ledger
                    .settlement_status_by_prediction_id()
                    .unwrap_or_default(),
                true,
            ),
            Err(_) => (None, BTreeMap::new(), false),
        }
    } else {
        (None, BTreeMap::new(), false)
    };
    let predictions = contracts
        .iter()
        .map(|row| {
            let prediction_id = row
                .get("prediction_id")
                .and_then(Value::as_str)
                .unwrap_or_default();
            let symbol = row.get("symbol").and_then(Value::as_str).unwrap_or_default();
            let decision = row
                .get("decision_as_of")
                .and_then(Value::as_str)
                .unwrap_or_default();
            let feature_hash = row
                .get("feature_hash")
                .and_then(Value::as_str)
                .unwrap_or_default();
            json!({
                "prediction_id": prediction_id,
                "decision_as_of": row.get("decision_as_of"),
                "symbol": symbol,
                "horizon_minutes": row.get("horizon_minutes"),
                "market_snapshot_id": row.get("market_snapshot_id").cloned().unwrap_or(Value::Null),
                "derived_trace_id": stable_id(&["prediction_trace", prediction_id, symbol, decision, feature_hash]),
                "snapshot_link_status": row.get("snapshot_link_status").cloned().unwrap_or_else(|| json!("UNAVAILABLE_NOT_MATERIALIZED_OR_NOT_RESOLVED")),
                "feature_hash": row.get("feature_hash"),
                "model_hash": row.get("model_hash"),
                "data_manifest_hash": row.get("data_manifest_hash"),
                "decision": row.get("decision"),
                "settlement_status": settlement_statuses.get(prediction_id).map(String::as_str).unwrap_or("NOT_LEDGERED"),
                "evidence_grade": row.get("evidence_grade"),
                "availability_semantics": row.get("availability_semantics"),
                "top_analog_trace_ids": row.get("top_analogs").and_then(Value::as_array).map(|analogs| analogs.iter().filter_map(|analog| analog.get("derived_trace_id")).collect::<Vec<_>>()).unwrap_or_default(),
                "top_analog_market_snapshot_ids": row.get("top_analogs").and_then(Value::as_array).map(|analogs| analogs.iter().filter_map(|analog| analog.get("market_snapshot_id")).filter(|id| !id.is_null()).collect::<Vec<_>>()).unwrap_or_default(),
                "top_analog_ids_status": if row.get("top_analogs").is_some() { "TRACE_IDS_PERSISTED_CANONICAL_IDS_OPTIONAL" } else { "NOT_PERSISTED_IN_LEGACY_FORECAST_CONTRACT" },
            })
        })
        .collect::<Vec<_>>();
    let all = |field: &str| {
        !contracts.is_empty()
            && contracts.iter().all(|row| {
                row.get(field)
                    .is_some_and(|value| !value.is_null() && value.as_str() != Some("MISSING"))
            })
    };
    let analog_trace_ids_present = !contracts.is_empty()
        && contracts.iter().all(|row| {
            row.get("top_analogs")
                .and_then(Value::as_array)
                .is_some_and(|analogs| {
                    !analogs.is_empty()
                        && analogs
                            .iter()
                            .all(|analog| analog.get("derived_trace_id").is_some())
                })
        });
    let canonical_snapshot_ids_present = !contracts.is_empty()
        && contracts.iter().all(|row| {
            row.get("market_snapshot_id")
                .is_some_and(|value| !value.is_null())
        });
    Json(json!({
        "status": if contracts.is_empty() { "UNAVAILABLE" } else { "AVAILABLE" },
        "reason": if contracts.is_empty() { "NO_LIVE_FORECAST_CONTRACT" } else { "LATEST_LIVE_SHADOW_CONTRACT" },
        "schema_version": "axio.prediction-audit.v1",
        "prediction_count": predictions.len(),
        "predictions": predictions,
        "checks": {
            "observation_cutoff_present": all("observation_cutoff") && all("decision_as_of"),
            "feature_lineage_present": all("feature_hash") && all("feature_version"),
            "analog_trace_ids_present": analog_trace_ids_present,
            "canonical_market_snapshot_ids_present": canonical_snapshot_ids_present,
            "model_policy_present": all("model_hash") && contracts.iter().all(|row| row.pointer("/decision/policy_version").is_some()),
            "manifest_hash_declared": all("data_manifest_hash"),
            "manifest_verified": false,
            "append_only_guards_present": append_only_guards_present,
            "append_only_history_verified": false,
        },
        "reproducibility": {
            "observation_cutoff_present": all("observation_cutoff"),
            "feature_hash_present": all("feature_hash"),
            "analog_trace_ids_present": analog_trace_ids_present,
            "canonical_market_snapshot_ids_present": canonical_snapshot_ids_present,
            "model_policy_present": all("model_hash"),
            "manifest_hash_declared_not_recomputed": all("data_manifest_hash"),
            "append_only_guards_present": append_only_guards_present,
        },
        "ledger": ledger_status,
        "artifact_path": forecast_path,
        "evidence_grade": if analog_trace_ids_present {
            "PARTIAL_TRACE_IDS_PRESENT_CANONICAL_MARKET_MEMORY_LINKS_OPTIONAL"
        } else {
            "PARTIAL_TRACE_ANALOG_IDS_NOT_YET_IN_LEGACY_CONTRACT"
        },
        "audit_limitations": [
            "declared manifest hashes are displayed but not recomputed by this endpoint",
            "append-only triggers are present, but historical ledger provenance is not independently proven",
            "canonical Market Memory IDs remain unavailable until the store is materialized and joined"
        ],
    }))
}

#[cfg(test)]
mod tests {
    use super::{
        build_state_current_payload, sha256_hex, state_profile_names,
        validated_duration_diagnostics,
    };
    use chrono::{Duration, TimeZone, Utc};
    use serde_json::{Value, json};
    use std::path::Path;

    fn artifact(now: chrono::DateTime<Utc>) -> Value {
        let model_artifact = json!({
            "states": 2,
            "dimensions": 4,
            "initial": [0.5, 0.5],
            "transition": [[0.8, 0.2], [0.3, 0.7]],
            "means": [[0.1, -0.2, 0.3, 0.4], [-0.2, 0.3, 1.1, 1.2]],
            "variances": [[1.0, 1.1, 1.2, 1.3], [1.4, 1.5, 1.6, 1.7]],
            "center": [0.0, 0.0, 0.0, 0.0],
            "scale": [1.0, 1.0, 1.0, 1.0],
            "log_likelihood": -10.0,
            "bic": 42.0,
            "training_likelihoods": [-12.0, -10.0],
            "state_permutation": [0, 1]
        });
        let model_artifact_sha256 =
            sha256_hex(&serde_json::to_vec(&model_artifact).expect("serialize fixture model"));
        let metadata = json!({
            "schema_version": "axio.regime-artifact.v2",
            "model": "diagonal_gaussian_hmm",
            "source": "fixture",
            "as_of": now,
            "latest_input_available_at": now - Duration::seconds(1),
            "input_availability_status": "PERSISTED_POINT_IN_TIME",
            "states": 2,
            "sessions": 20,
            "observations": 100,
            "trained_through": "2026-07-24",
            "current_session": "2026-07-25",
            "state_feature_schema": [
                "standardized_return",
                "standardized_vwap_distance",
                "standardized_volatility",
                "standardized_activity"
            ],
            "state_feature_schema_sha256": "b9d8b18fa1b7f5d4073c0e7980a220b049212eb7abb361382363fd52ab4b712d",
            "model_artifact": model_artifact,
            "model_artifact_sha256": model_artifact_sha256,
            "dimensions": ["ret_5m", "dist_session_vwap", "realized_vol", "volume_zscore"],
            "standardized_means": [[0.1, -0.2, 0.3, 0.4], [-0.2, 0.3, 1.1, 1.2]],
            "standardized_variances": [[1.0, 1.1, 1.2, 1.3], [1.4, 1.5, 1.6, 1.7]],
            "state_definition": {
                "cadence_minutes": 5,
                "session_reset": true,
                "cross_session_model_available": false,
            },
        });
        let state_inference = json!({
            "current_filtered_probability": [0.75, 0.25],
            "transition": [[0.8, 0.2], [0.3, 0.7]],
            "next_state_probability": [0.675, 0.325],
            "next_state_probability_status": "AVAILABLE_SAME_SESSION",
            "one_step_model_implied_state_probability": [0.675, 0.325],
            "regime_entropy": 0.5623351446188083,
            "normalized_regime_entropy": 0.8112781244591328,
            "one_step_change_probability": 0.22499999999999987,
            "transition_row_normalized_entropy": 0.7617687959731949,
            "raw_state_certainty": {
                "top_probability": 0.75,
                "top_two_probability_margin": 0.5,
                "normalized_entropy": 0.8112781244591328,
                "calibration_status": "UNCALIBRATED_LATENT_STATE_POSTERIOR",
                "direct_allocation_impact": true,
                "continuous_sizing_impact": false,
                "hard_no_trade_veto_impact": true,
                "semantics": "RAW_FILTERED_LATENT_STATE_CERTAINTY_NOT_RETURN_CONFIDENCE",
            },
            "duration_diagnostics": {
                "duration_model": "GEOMETRIC_MEMORYLESS_HMM",
                "expected_spell_observations_including_current": 4.583333333333334,
                "expected_future_self_transitions": 3.583333333333334,
                "observation_minutes": 5,
                "untruncated_geometric_diagnostic": true,
                "session_close_truncation_applied": false,
                "must_not_extrapolate_past_session_close": true,
                "semantics": "POSTERIOR_WEIGHTED_UNTRUNCATED_GEOMETRIC_SPELL_INCLUDING_CURRENT",
            },
        });
        let profiles_and_horizons = json!({
            "state_profiles": [
                {
                    "raw_state_id": 0,
                    "name": "MEAN_REVERSION",
                    "standardized_return_mean": 0.1,
                    "standardized_vwap_distance_mean": -0.2,
                    "standardized_volatility_mean": 0.3,
                    "standardized_activity_mean": 0.4,
                    "self_transition_probability": 0.8,
                    "expected_duration_observations": 5.000000000000001,
                    "expected_future_self_transitions": 4.000000000000001,
                    "duration_model": "GEOMETRIC_MEMORYLESS_HMM"
                },
                {
                    "raw_state_id": 1,
                    "name": "HIGH_ACTIVITY_HIGH_VOLATILITY",
                    "standardized_return_mean": -0.2,
                    "standardized_vwap_distance_mean": 0.3,
                    "standardized_volatility_mean": 1.1,
                    "standardized_activity_mean": 1.2,
                    "self_transition_probability": 0.7,
                    "expected_duration_observations": 3.333333333333333,
                    "expected_future_self_transitions": 2.333333333333333,
                    "duration_model": "GEOMETRIC_MEMORYLESS_HMM"
                }
            ],
            "horizon_state_forecasts": [
                {
                    "horizon_steps": 1,
                    "horizon_minutes": 5,
                    "status": "AVAILABLE_MODEL_IMPLIED_UNCALIBRATED",
                    "endpoint_state_probabilities": [0.675, 0.325],
                    "dominant_raw_state_id": 0,
                    "dominant_probability": 0.675,
                    "endpoint_entropy": 0.6305810283860147,
                    "normalized_endpoint_entropy": 0.9097361225311661,
                    "posterior_weighted_no_state_change_probability": 0.7750000000000001,
                    "probability_semantics": "ENDPOINT_IS_Q_T_TIMES_A_POWER_H; SURVIVAL_IS_NO_STATE_CHANGE_PATH",
                },
                {
                    "horizon_steps": 3,
                    "horizon_minutes": 15,
                    "status": "AVAILABLE_MODEL_IMPLIED_UNCALIBRATED",
                    "endpoint_state_probabilities": [0.6187500000000001, 0.38125],
                    "dominant_raw_state_id": 0,
                    "dominant_probability": 0.6187500000000001,
                    "endpoint_entropy": 0.6646727472469744,
                    "normalized_endpoint_entropy": 0.9589200762672535,
                    "posterior_weighted_no_state_change_probability": 0.4697500000000001,
                    "probability_semantics": "ENDPOINT_IS_Q_T_TIMES_A_POWER_H; SURVIVAL_IS_NO_STATE_CHANGE_PATH",
                },
                {
                    "horizon_steps": 6,
                    "horizon_minutes": 30,
                    "status": "AVAILABLE_MODEL_IMPLIED_UNCALIBRATED",
                    "endpoint_state_probabilities": [0.6023437500000001, 0.39765625000000004],
                    "dominant_raw_state_id": 0,
                    "dominant_probability": 0.6023437500000001,
                    "endpoint_entropy": 0.6720499065687073,
                    "normalized_endpoint_entropy": 0.9695630674365653,
                    "posterior_weighted_no_state_change_probability": 0.22602025000000006,
                    "probability_semantics": "ENDPOINT_IS_Q_T_TIMES_A_POWER_H; SURVIVAL_IS_NO_STATE_CHANGE_PATH",
                },
                {
                    "horizon_steps": 12,
                    "horizon_minutes": 60,
                    "status": "UNAVAILABLE_CROSSES_SESSION_BOUNDARY_REQUIRES_OVERNIGHT_MODEL",
                    "endpoint_state_probabilities": null,
                    "dominant_raw_state_id": null,
                    "dominant_probability": null,
                    "endpoint_entropy": null,
                    "normalized_endpoint_entropy": null,
                    "posterior_weighted_no_state_change_probability": null,
                    "probability_semantics": "NO_CROSS_SESSION_EXTRAPOLATION_FROM_SESSION_RESET_INTRADAY_HMM",
                }
            ],
            "cross_session_state_forecast": {
                "status": "UNAVAILABLE_REQUIRES_SEPARATELY_VALIDATED_OVERNIGHT_MODEL",
                "today_to_tomorrow_claim_supported": false,
            },
        });
        let audit_and_policy = json!({
            "transition_audit": [
                {
                    "from_raw_state_id": 0,
                    "to_raw_state_id": 0,
                    "transition_probability": 0.8,
                    "train_expected_transition_count": 9.6,
                    "train_expected_origin_count": 12.0,
                    "count_semantics": "TRAIN_ONLY_SMOOTHED_XI_EXPECTED_MASS_NOT_HARD_OBSERVED_COUNT",
                },
                {
                    "from_raw_state_id": 0,
                    "to_raw_state_id": 1,
                    "transition_probability": 0.2,
                    "train_expected_transition_count": 2.4,
                    "train_expected_origin_count": 12.0,
                    "count_semantics": "TRAIN_ONLY_SMOOTHED_XI_EXPECTED_MASS_NOT_HARD_OBSERVED_COUNT",
                },
                {
                    "from_raw_state_id": 1,
                    "to_raw_state_id": 0,
                    "transition_probability": 0.3,
                    "train_expected_transition_count": 3.0,
                    "train_expected_origin_count": 10.0,
                    "count_semantics": "TRAIN_ONLY_SMOOTHED_XI_EXPECTED_MASS_NOT_HARD_OBSERVED_COUNT",
                },
                {
                    "from_raw_state_id": 1,
                    "to_raw_state_id": 1,
                    "transition_probability": 0.7,
                    "train_expected_transition_count": 7.0,
                    "train_expected_origin_count": 10.0,
                    "count_semantics": "TRAIN_ONLY_SMOOTHED_XI_EXPECTED_MASS_NOT_HARD_OBSERVED_COUNT",
                }
            ],
            "decision_boundary": {
                "forecast_conditioning_role": "DESCRIPTIVE_MODEL_CONTEXT",
                "direct_allocation_impact": true,
                "continuous_sizing_impact": false,
                "hard_no_trade_veto_impact": true,
                "allocation_impact_semantics": "NORMALIZED_REGIME_ENTROPY_CAN_ONLY_TRIGGER_A_HARD_NO_TRADE_VETO; IT_DOES_NOT_SCALE_POSITION_SIZE",
                "execution_eligible": false,
                "confidence_semantics": "RAW_STATE_CERTAINTY_IS_NOT_RETURN_CONFIDENCE",
            },
            "model_selection": {"selected_at_candidate_boundary": false},
            "probability_semantics": "FORWARD_FILTERED_P_ZT_GIVEN_X_1_TO_T_NO_SMOOTHING",
        });
        let mut report = serde_json::Map::new();
        for chunk in [
            metadata,
            state_inference,
            profiles_and_horizons,
            audit_and_policy,
        ] {
            report.extend(
                chunk
                    .as_object()
                    .expect("fixture chunks are objects")
                    .clone(),
            );
        }
        Value::Object(report)
    }
    fn build(report: &Value, now: chrono::DateTime<Utc>, maximum_age_seconds: i64) -> Value {
        build_state_current_payload(
            report,
            Path::new("fixture/regime_latest.json"),
            None,
            None,
            None,
            None,
            now,
            maximum_age_seconds,
        )
    }

    fn make_session_boundary(report: &mut Value) {
        report["next_state_probability"] = Value::Null;
        report["next_state_probability_status"] = json!("UNAVAILABLE_CROSSES_SESSION_BOUNDARY");
        for row in report["horizon_state_forecasts"]
            .as_array_mut()
            .expect("fixture horizon rows")
        {
            row["status"] = json!("UNAVAILABLE_CROSSES_SESSION_BOUNDARY_REQUIRES_OVERNIGHT_MODEL");
            row["probability_semantics"] =
                json!("NO_CROSS_SESSION_EXTRAPOLATION_FROM_SESSION_RESET_INTRADAY_HMM");
            for key in [
                "endpoint_state_probabilities",
                "dominant_raw_state_id",
                "dominant_probability",
                "endpoint_entropy",
                "normalized_endpoint_entropy",
                "posterior_weighted_no_state_change_probability",
            ] {
                row[key] = Value::Null;
            }
        }
    }

    #[test]
    fn v2_contract_uses_artifact_profiles_and_keeps_transition_metrics_distinct() {
        let now = Utc.with_ymd_and_hms(2026, 7, 25, 20, 0, 0).unwrap();
        let payload = build(&artifact(now), now, 120);
        assert_eq!(payload["status"], "AVAILABLE");
        assert_eq!(payload["schema_version"], "axio.market-state-engine.v2");
        assert_eq!(payload["current_state"]["semantic_state"], "MEAN_REVERSION");
        assert_eq!(
            payload["current_state"]["one_step_change_probability"],
            0.22499999999999987
        );
        assert_eq!(
            payload["current_state"]["transition_row_normalized_entropy"],
            0.7617687959731949
        );
        assert_ne!(
            payload["current_state"]["one_step_change_probability"],
            payload["current_state"]["transition_row_normalized_entropy"]
        );
        assert_eq!(payload["transition_audit"].as_array().unwrap().len(), 4);
        assert_eq!(
            payload["transition_audit"][1]["train_expected_transition_count"],
            2.4
        );
        assert_eq!(
            payload["transition_audit"][1]["count_semantics"],
            "TRAIN_ONLY_SMOOTHED_XI_EXPECTED_MASS_NOT_HARD_OBSERVED_COUNT"
        );
        assert_eq!(
            payload["horizon_state_forecasts"][0]["endpoint_state_probabilities"]["MEAN_REVERSION#raw_0"],
            0.675
        );
        assert!(payload["horizon_state_forecasts"][3]["endpoint_state_probabilities"].is_null());
        assert_eq!(
            payload["decision_boundary"]["direct_allocation_impact"],
            true
        );
        assert_eq!(
            payload["decision_boundary"]["continuous_sizing_impact"],
            false
        );
        assert_eq!(
            payload["decision_boundary"]["hard_no_trade_veto_impact"],
            true
        );
        assert_eq!(
            payload["raw_state_certainty"]["direct_allocation_impact"],
            true
        );
        assert_eq!(
            payload["raw_state_certainty"]["continuous_sizing_impact"],
            false
        );
        assert_eq!(
            payload["raw_state_certainty"]["hard_no_trade_veto_impact"],
            true
        );
        assert_eq!(
            payload["duration_diagnostics"]["untruncated_geometric_diagnostic"],
            true
        );
        assert_eq!(
            payload["duration_diagnostics"]["session_close_truncation_applied"],
            false
        );
        assert_eq!(
            payload["duration_diagnostics"]["must_not_extrapolate_past_session_close"],
            true
        );
        assert_eq!(
            payload["cross_session_state_forecast"]["today_to_tomorrow_claim_supported"],
            false
        );
        assert_eq!(
            payload["model_artifact_integrity_status"],
            "CONTENT_BOUND_SELF_HASH_NOT_TRUSTED_REGISTRY"
        );
    }

    #[test]
    fn null_same_session_next_probability_is_valid_boundary_fail_close() {
        let now = Utc.with_ymd_and_hms(2026, 7, 25, 20, 0, 0).unwrap();
        let mut report = artifact(now);
        make_session_boundary(&mut report);
        let payload = build(&report, now, 120);
        assert_eq!(payload["status"], "AVAILABLE");
        assert!(payload["current_state"]["next_state_probabilities"].is_null());
        assert_eq!(
            payload["current_state"]["next_state_probability_status"],
            "UNAVAILABLE_CROSSES_SESSION_BOUNDARY"
        );
        assert!(
            payload["horizon_state_forecasts"]
                .as_array()
                .unwrap()
                .iter()
                .all(|row| row["endpoint_state_probabilities"].is_null()
                    && row["dominant_raw_state_id"].is_null())
        );
    }

    #[test]
    fn stale_artifact_hides_all_live_state_and_horizon_probabilities() {
        let as_of = Utc.with_ymd_and_hms(2026, 7, 25, 20, 0, 0).unwrap();
        let now = as_of + Duration::seconds(121);
        let payload = build(&artifact(as_of), now, 120);
        assert_eq!(payload["status"], "STALE_UNAVAILABLE");
        assert_eq!(payload["freshness"]["status"], "STALE");
        assert_eq!(payload["freshness"]["age_seconds"], 121);
        assert!(payload["current_state"]["filtered_state_probabilities"].is_null());
        assert!(payload["current_state"]["one_step_change_probability"].is_null());
        assert!(payload["raw_state_certainty"]["top_probability"].is_null());
        assert!(
            payload["duration_diagnostics"]["expected_spell_observations_including_current"]
                .is_null()
        );
        assert!(payload["duration_diagnostics"]["expected_future_self_transitions"].is_null());
        assert!(
            payload["duration_diagnostics"]["expected_spell_minutes_including_current"].is_null()
        );
        assert_eq!(
            payload["duration_diagnostics"]["status"],
            "UNAVAILABLE_LIVE_ARTIFACT_NOT_AVAILABLE"
        );
        assert!(
            payload["horizon_state_forecasts"]
                .as_array()
                .unwrap()
                .iter()
                .all(|row| row["endpoint_state_probabilities"].is_null()
                    && row["dominant_probability"].is_null()
                    && row["posterior_weighted_no_state_change_probability"].is_null())
        );
        assert_eq!(payload["transition_audit"].as_array().unwrap().len(), 4);
    }

    #[test]
    fn degraded_artifact_hides_all_live_state_and_horizon_probabilities() {
        let now = Utc.with_ymd_and_hms(2026, 7, 25, 20, 0, 0).unwrap();
        let mut report = artifact(now);
        report["model_selection"]["selected_at_candidate_boundary"] = json!(true);
        let payload = build(&report, now, 120);
        assert_eq!(payload["status"], "DEGRADED");
        assert!(payload["current_state"]["filtered_state_probabilities"].is_null());
        assert!(
            payload["horizon_state_forecasts"]
                .as_array()
                .unwrap()
                .iter()
                .all(|row| row["endpoint_state_probabilities"].is_null())
        );
    }

    #[test]
    fn absent_state_profiles_fail_closed_instead_of_recomputing_names() {
        let now = Utc.with_ymd_and_hms(2026, 7, 25, 20, 0, 0).unwrap();
        let mut report = artifact(now);
        report.as_object_mut().unwrap().remove("state_profiles");
        let payload = build(&report, now, 120);
        assert_eq!(payload["status"], "BLOCKED");
        assert_eq!(
            payload["reason"],
            "REGIME_ARTIFACT_V2_STATE_PROFILES_INVALID_OR_SEMANTIC_LABEL_DISALLOWED"
        );
    }

    #[test]
    fn legacy_schema_and_disallowed_semantic_labels_are_blocked() {
        let now = Utc.with_ymd_and_hms(2026, 7, 25, 20, 0, 0).unwrap();
        let mut legacy = artifact(now);
        legacy["schema_version"] = json!("axio.regime-artifact.v1");
        assert_eq!(build(&legacy, now, 120)["status"], "BLOCKED");

        let mut over_interpreted = artifact(now);
        over_interpreted["state_profiles"][1]["name"] = json!("LIQUIDITY_STRESS");
        let payload = build(&over_interpreted, now, 120);
        assert_eq!(payload["status"], "BLOCKED");
        assert_eq!(
            payload["reason"],
            "REGIME_ARTIFACT_V2_STATE_PROFILES_INVALID_OR_SEMANTIC_LABEL_DISALLOWED"
        );
    }

    #[test]
    fn missing_required_lineage_and_coverage_fields_are_blocked() {
        let now = Utc.with_ymd_and_hms(2026, 7, 25, 20, 0, 0).unwrap();
        for key in [
            "source",
            "latest_input_available_at",
            "sessions",
            "observations",
            "trained_through",
            "current_session",
            "state_feature_schema",
            "state_feature_schema_sha256",
            "model_artifact",
            "model_artifact_sha256",
            "dimensions",
            "standardized_means",
            "standardized_variances",
            "decision_boundary",
            "transition_audit",
            "horizon_state_forecasts",
            "raw_state_certainty",
            "duration_diagnostics",
            "regime_entropy",
            "normalized_regime_entropy",
            "one_step_change_probability",
            "transition_row_normalized_entropy",
            "model_selection",
            "cross_session_state_forecast",
        ] {
            let mut report = artifact(now);
            report.as_object_mut().unwrap().remove(key);
            assert_eq!(
                build(&report, now, 120)["status"],
                "BLOCKED",
                "missing {key} must block"
            );
        }
    }

    #[test]
    fn invalid_hash_or_noncausal_availability_is_blocked() {
        let now = Utc.with_ymd_and_hms(2026, 7, 25, 20, 0, 0).unwrap();
        let mut bad_hash = artifact(now);
        bad_hash["state_feature_schema_sha256"] = json!("abcd");
        assert_eq!(build(&bad_hash, now, 120)["status"], "BLOCKED");

        let mut self_consistent_but_wrong_schema = artifact(now);
        self_consistent_but_wrong_schema["state_feature_schema"][0] =
            json!("tampered_standardized_return");
        let joined_schema = self_consistent_but_wrong_schema["state_feature_schema"]
            .as_array()
            .unwrap()
            .iter()
            .map(|value| value.as_str().unwrap())
            .collect::<Vec<_>>()
            .join("\u{1f}");
        self_consistent_but_wrong_schema["state_feature_schema_sha256"] =
            json!(sha256_hex(joined_schema.as_bytes()));
        assert_eq!(
            build(&self_consistent_but_wrong_schema, now, 120)["status"],
            "BLOCKED"
        );

        let mut bad_model_hash = artifact(now);
        bad_model_hash["model_artifact_sha256"] =
            json!("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb");
        assert_eq!(build(&bad_model_hash, now, 120)["status"], "BLOCKED");

        let mut content_bound_but_inconsistent_model = artifact(now);
        content_bound_but_inconsistent_model["model_artifact"]["means"][0][0] = json!(9.0);
        let inconsistent_model_sha256 = sha256_hex(
            &serde_json::to_vec(&content_bound_but_inconsistent_model["model_artifact"])
                .expect("serialize tampered model"),
        );
        content_bound_but_inconsistent_model["model_artifact_sha256"] =
            json!(inconsistent_model_sha256);
        assert_eq!(
            build(&content_bound_but_inconsistent_model, now, 120)["status"],
            "BLOCKED"
        );

        let mut noncausal = artifact(now);
        noncausal["latest_input_available_at"] = json!(now + Duration::seconds(1));
        assert_eq!(build(&noncausal, now, 120)["status"], "BLOCKED");
    }

    #[test]
    fn tampered_q_a_and_horizon_projection_are_blocked() {
        let now = Utc.with_ymd_and_hms(2026, 7, 25, 20, 0, 0).unwrap();
        let mut bad_one_step = artifact(now);
        bad_one_step["one_step_model_implied_state_probability"] = json!([0.65, 0.35]);
        assert_eq!(build(&bad_one_step, now, 120)["status"], "BLOCKED");

        let mut bad_horizon = artifact(now);
        bad_horizon["horizon_state_forecasts"][1]["endpoint_state_probabilities"] =
            json!([0.61, 0.39]);
        let payload = build(&bad_horizon, now, 120);
        assert_eq!(payload["status"], "BLOCKED");
        assert_eq!(
            payload["reason"],
            "REGIME_ARTIFACT_V2_HORIZON_FORECASTS_INVALID_OR_INCOMPLETE"
        );
    }

    #[test]
    fn duplicate_horizon_or_inconsistent_transition_audit_is_blocked() {
        let now = Utc.with_ymd_and_hms(2026, 7, 25, 20, 0, 0).unwrap();
        let mut duplicate_horizon = artifact(now);
        duplicate_horizon["horizon_state_forecasts"][1]["horizon_steps"] = json!(1);
        duplicate_horizon["horizon_state_forecasts"][1]["horizon_minutes"] = json!(5);
        assert_eq!(build(&duplicate_horizon, now, 120)["status"], "BLOCKED");

        let mut inconsistent_audit = artifact(now);
        inconsistent_audit["transition_audit"][1]["train_expected_origin_count"] = json!(11.0);
        assert_eq!(build(&inconsistent_audit, now, 120)["status"], "BLOCKED");
    }

    #[test]
    fn tampered_reported_diagnostics_are_blocked() {
        let now = Utc.with_ymd_and_hms(2026, 7, 25, 20, 0, 0).unwrap();
        let mut report = artifact(now);
        report["transition_row_normalized_entropy"] = json!(0.5);
        assert_eq!(build(&report, now, 120)["status"], "BLOCKED");

        let mut certainty = artifact(now);
        certainty["raw_state_certainty"]["top_probability"] = json!(0.7);
        assert_eq!(build(&certainty, now, 120)["status"], "BLOCKED");
    }
    #[test]
    fn state_profiles_duration_and_statuses_are_integrity_checked() {
        let now = Utc.with_ymd_and_hms(2026, 7, 25, 20, 0, 0).unwrap();
        let mut bad_profile = artifact(now);
        bad_profile["state_profiles"][0]["self_transition_probability"] = json!(0.75);
        assert_eq!(build(&bad_profile, now, 120)["status"], "BLOCKED");

        let mut bad_duration = artifact(now);
        bad_duration["duration_diagnostics"]
            .as_object_mut()
            .unwrap()
            .remove("must_not_extrapolate_past_session_close");
        assert_eq!(build(&bad_duration, now, 120)["status"], "BLOCKED");

        let mut mismatched_duration = artifact(now);
        mismatched_duration["duration_diagnostics"]["expected_spell_observations_including_current"] =
            json!(4.0);
        assert_eq!(build(&mismatched_duration, now, 120)["status"], "BLOCKED");

        let mut bad_untruncated_duration = artifact(now);
        bad_untruncated_duration["duration_diagnostics"]
            .as_object_mut()
            .unwrap()
            .remove("untruncated_geometric_diagnostic");
        assert_eq!(
            build(&bad_untruncated_duration, now, 120)["status"],
            "BLOCKED"
        );

        let mut bad_horizon_status = artifact(now);
        bad_horizon_status["horizon_state_forecasts"][3]["status"] = json!("BROKEN");
        assert_eq!(build(&bad_horizon_status, now, 120)["status"], "BLOCKED");

        let mut bad_cross_session_status = artifact(now);
        bad_cross_session_status["cross_session_state_forecast"]["status"] =
            json!("AVAILABLE_UNVALIDATED");
        assert_eq!(
            build(&bad_cross_session_status, now, 120)["status"],
            "BLOCKED"
        );
    }
    #[test]
    fn allocation_metadata_conflicts_or_missing_fields_are_blocked() {
        let now = Utc.with_ymd_and_hms(2026, 7, 25, 20, 0, 0).unwrap();
        let mut raw_conflict = artifact(now);
        raw_conflict["raw_state_certainty"]["continuous_sizing_impact"] = json!(true);
        assert_eq!(build(&raw_conflict, now, 120)["status"], "BLOCKED");

        let mut decision_conflict = artifact(now);
        decision_conflict["decision_boundary"]["direct_allocation_impact"] = json!(false);
        assert_eq!(build(&decision_conflict, now, 120)["status"], "BLOCKED");

        let mut missing_execution_guard = artifact(now);
        missing_execution_guard["decision_boundary"]
            .as_object_mut()
            .unwrap()
            .remove("execution_eligible");
        assert_eq!(
            build(&missing_execution_guard, now, 120)["status"],
            "BLOCKED"
        );
    }
    #[test]
    fn absorbing_state_and_duration_threshold_match_market_state_one_e_minus_twelve() {
        let near_absorbing = 1.0 - 5.0e-10;
        let near_exit = 1.0 - near_absorbing;
        let transition = json!([[near_absorbing, near_exit], [0.2, 0.8]]);
        let report = json!({
            "state_profiles": [
                {
                    "raw_state_id": 0,
                    "name": "UNCLASSIFIED_PRICE_FLOW_STATE",
                    "standardized_return_mean": 0.0,
                    "standardized_vwap_distance_mean": 0.0,
                    "standardized_volatility_mean": 0.0,
                    "standardized_activity_mean": 0.0,
                    "self_transition_probability": near_absorbing,
                    "expected_duration_observations": 1.0 / near_exit,
                    "expected_future_self_transitions": near_absorbing / near_exit,
                    "duration_model": "GEOMETRIC_MEMORYLESS_HMM"
                },
                {
                    "raw_state_id": 1,
                    "name": "RANGE_COMPRESSION",
                    "standardized_return_mean": 0.0,
                    "standardized_vwap_distance_mean": 0.0,
                    "standardized_volatility_mean": 0.0,
                    "standardized_activity_mean": 0.0,
                    "self_transition_probability": 0.8,
                    "expected_duration_observations": 5.0,
                    "expected_future_self_transitions": 4.0,
                    "duration_model": "GEOMETRIC_MEMORYLESS_HMM"
                }
            ]
        });
        assert!(
            state_profile_names(&report, transition.as_array().unwrap(), 2).is_some(),
            "an exit probability above 1e-12 must remain finite"
        );

        let absorbing = 1.0 - 5.0e-13;
        let absorbing_transition = json!([[absorbing, 1.0 - absorbing], [0.2, 0.8]]);
        let mut absorbing_report = report.clone();
        absorbing_report["state_profiles"][0]["self_transition_probability"] = json!(absorbing);
        absorbing_report["state_profiles"][0]["expected_duration_observations"] = Value::Null;
        absorbing_report["state_profiles"][0]["expected_future_self_transitions"] = Value::Null;
        assert!(
            state_profile_names(
                &absorbing_report,
                absorbing_transition.as_array().unwrap(),
                2,
            )
            .is_some(),
            "an exit probability at or below 1e-12 is represented as unbounded"
        );

        let duration_report = json!({
            "duration_diagnostics": {
                "duration_model": "GEOMETRIC_MEMORYLESS_HMM",
                "expected_spell_observations_including_current": null,
                "expected_future_self_transitions": null,
                "observation_minutes": 5,
                "untruncated_geometric_diagnostic": true,
                "session_close_truncation_applied": false,
                "must_not_extrapolate_past_session_close": true,
                "semantics": "UNBOUNDED_POSTERIOR_WEIGHTED_GEOMETRIC_DURATION"
            },
            "state_profiles": [
                {
                    "raw_state_id": 0,
                    "duration_model": "GEOMETRIC_MEMORYLESS_HMM",
                    "expected_duration_observations": null,
                    "expected_future_self_transitions": null
                },
                {
                    "raw_state_id": 1,
                    "duration_model": "GEOMETRIC_MEMORYLESS_HMM",
                    "expected_duration_observations": 5.0,
                    "expected_future_self_transitions": 4.0
                }
            ]
        });
        assert!(
            validated_duration_diagnostics(
                &duration_report,
                5,
                &json!([5.0e-10, 0.9999999995]).as_array().unwrap().to_vec(),
            )
            .is_some(),
            "posterior mass above 1e-12 on an absorbing state makes duration unbounded"
        );
    }

    #[test]
    fn cross_session_output_strips_unapproved_forecast_and_probability_fields() {
        let now = Utc.with_ymd_and_hms(2026, 7, 25, 20, 0, 0).unwrap();
        let mut report = artifact(now);
        report["cross_session_state_forecast"]["reason"] =
            json!("SEPARATE_OVERNIGHT_MODEL_REQUIRED");
        report["cross_session_state_forecast"]["semantics"] =
            json!("NO_INTRADAY_HMM_CROSS_SESSION_EXTRAPOLATION");
        report["cross_session_state_forecast"]["endpoint_state_probabilities"] = json!([0.9, 0.1]);
        report["cross_session_state_forecast"]["forecast_confidence"] = json!(0.99);
        report["cross_session_state_forecast"]["dominant_raw_state_id"] = json!(0);

        let payload = build(&report, now, 120);
        assert_eq!(payload["status"], "AVAILABLE");
        let cross_session = payload["cross_session_state_forecast"]
            .as_object()
            .expect("allow-listed cross-session object");
        assert_eq!(cross_session.len(), 4);
        assert!(cross_session.contains_key("status"));
        assert!(cross_session.contains_key("today_to_tomorrow_claim_supported"));
        assert!(cross_session.contains_key("reason"));
        assert!(cross_session.contains_key("semantics"));
        assert!(!cross_session.contains_key("endpoint_state_probabilities"));
        assert!(!cross_session.contains_key("forecast_confidence"));
        assert!(!cross_session.contains_key("dominant_raw_state_id"));

        let mut invalid_reason = artifact(now);
        invalid_reason["cross_session_state_forecast"]["reason"] = json!(0.5);
        assert_eq!(build(&invalid_reason, now, 120)["status"], "BLOCKED");
    }
}
