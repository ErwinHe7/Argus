use axio_quant_engine::market_query::{EvidenceEnvelope, MarketSetupType, PipelineReadinessState};
use chrono::{DateTime, Duration, Utc};
use serde_json::Value;

const FIXTURE_JSON: &str = include_str!("fixtures/explicit_rule_completed_bar_contract.json");

#[test]
fn shared_explicit_rule_response_uses_only_the_last_completed_five_minute_bar() {
    let mut envelope: EvidenceEnvelope =
        serde_json::from_str(FIXTURE_JSON).expect("deserialize shared explicit-rule fixture");
    let completed_bucket_start: DateTime<Utc> = "2026-07-27T13:35:00Z"
        .parse()
        .expect("parse completed bucket start");
    let completed_bucket_end: DateTime<Utc> = "2026-07-27T13:40:00Z"
        .parse()
        .expect("parse completed bucket end");
    let final_minute_start: DateTime<Utc> = "2026-07-27T13:39:00Z"
        .parse()
        .expect("parse final minute start");
    let final_minute_available_at: DateTime<Utc> = "2026-07-27T13:40:00.250Z"
        .parse()
        .expect("parse final minute availability");

    assert_eq!(envelope.query.setup_type, MarketSetupType::VwapReversal);
    assert!(
        envelope
            .candidates
            .iter()
            .all(|candidate| candidate.setup_type != MarketSetupType::ModelForecast)
    );
    assert!(envelope.historical.is_empty());
    assert_eq!(envelope.status, "AVAILABLE");
    assert_eq!(
        envelope.readiness.publication.state,
        PipelineReadinessState::NotChecked
    );

    assert_eq!(
        completed_bucket_start + Duration::minutes(5),
        completed_bucket_end
    );
    assert_eq!(
        final_minute_start + Duration::minutes(1),
        completed_bucket_end
    );

    assert_eq!(envelope.observation_cutoff, completed_bucket_end);
    let candidate = envelope
        .candidates
        .first()
        .expect("fixture contains one explicit-rule candidate");
    assert_eq!(
        candidate.metrics["observation_cutoff"]
            .as_str()
            .expect("candidate cutoff is an RFC 3339 timestamp")
            .parse::<DateTime<Utc>>()
            .expect("parse candidate observation cutoff"),
        completed_bucket_end
    );
    assert_eq!(candidate.metrics["coverage"], Value::from(1.0));
    for forbidden in [
        "statistical_orientation",
        "expected_return",
        "expected_price",
        "probability_up_percent",
        "forecast_sha256",
    ] {
        assert!(
            candidate.metrics.get(forbidden).is_none(),
            "explicit-rule fixture must not invent model field {forbidden}"
        );
    }

    let freshness = candidate
        .freshness
        .first()
        .expect("fixture contains primary freshness evidence");
    assert_eq!(freshness.observed_at, Some(completed_bucket_end));
    assert_eq!(freshness.available_at, Some(final_minute_available_at));
    assert_eq!(freshness.coverage, Some(1.0));

    let declared_response_sha256 = envelope
        .response_sha256
        .clone()
        .expect("fixture contains a response seal");
    envelope
        .seal()
        .expect("shared explicit-rule envelope satisfies the Rust contract");
    assert_eq!(
        envelope.response_sha256.as_deref(),
        Some(declared_response_sha256.as_str())
    );
}
