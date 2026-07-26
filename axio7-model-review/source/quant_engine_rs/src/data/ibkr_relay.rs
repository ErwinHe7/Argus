//! Quote-only ingress contract for a local IBKR Client Portal Gateway relay.
//!
//! The Gateway remains on the operator's loopback interface. A narrow local
//! bridge sends only normalized Level-1 quote fields over outbound HTTPS.
//! Account state, cookies, orders, and trading methods are intentionally absent
//! from this wire schema.

use std::{
    collections::BTreeSet,
    fs,
    path::Path,
    sync::{Mutex, OnceLock},
};

use anyhow::{Context, Result, bail};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use uuid::Uuid;

use crate::live::append_jsonl;

pub const QUOTE_BATCH_SCHEMA_VERSION: &str = "axio7.ibkr.quote-batch.v1";
pub const PROVIDER: &str = "IBKR_CLIENT_PORTAL";

static WRITE_LOCK: OnceLock<Mutex<()>> = OnceLock::new();

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(deny_unknown_fields)]
pub struct IbkrQuoteBatch {
    pub schema_version: String,
    pub batch_id: String,
    pub source: String,
    pub bridge_version: String,
    pub captured_at: DateTime<Utc>,
    pub session_authenticated: bool,
    pub quotes: Vec<IbkrQuote>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(deny_unknown_fields)]
pub struct IbkrQuote {
    pub symbol: String,
    pub conid: u64,
    pub provider_observed_at: DateTime<Utc>,
    /// IBKR field 6509. Only values beginning with `R` are accepted.
    pub market_data_availability: String,
    pub bid: f64,
    pub ask: f64,
    pub bid_size: Option<f64>,
    pub ask_size: Option<f64>,
    pub last: Option<f64>,
}

#[derive(Debug, Clone)]
pub struct QuoteBatchPolicy {
    pub allowed_symbols: BTreeSet<String>,
    pub maximum_age_ms: i64,
    pub maximum_future_skew_ms: i64,
    pub require_complete_coverage: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct QuoteBatchReceipt {
    pub schema_version: String,
    pub batch_id: String,
    pub provider: String,
    pub bridge_version: String,
    pub received_at: DateTime<Utc>,
    pub observation_cutoff: DateTime<Utc>,
    pub availability_time: DateTime<Utc>,
    pub freshness_ms: i64,
    pub quote_count: usize,
    pub expected_symbols: Vec<String>,
    pub received_symbols: Vec<String>,
    pub coverage_complete: bool,
    pub realtime_entitlement_verified: bool,
    pub quote_only: bool,
    pub execution_enabled: bool,
    pub public_redistribution_authorized: bool,
    pub payload_sha256: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AcceptedQuoteBatch {
    pub receipt: QuoteBatchReceipt,
    pub batch: IbkrQuoteBatch,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IbkrRelayStatus {
    pub status: String,
    #[serde(flatten)]
    pub receipt: QuoteBatchReceipt,
    pub caveats: Vec<String>,
}

pub fn policy_from_symbols(
    symbols: &[String],
    maximum_age_ms: i64,
    maximum_future_skew_ms: i64,
) -> QuoteBatchPolicy {
    QuoteBatchPolicy {
        allowed_symbols: symbols
            .iter()
            .filter_map(|symbol| normalize_symbol(symbol).ok())
            .collect(),
        maximum_age_ms,
        maximum_future_skew_ms,
        require_complete_coverage: true,
    }
}

pub fn validate_quote_batch(
    batch: &IbkrQuoteBatch,
    received_at: DateTime<Utc>,
    policy: &QuoteBatchPolicy,
) -> Result<QuoteBatchReceipt> {
    if batch.schema_version != QUOTE_BATCH_SCHEMA_VERSION {
        bail!("unsupported IBKR quote-batch schema");
    }
    Uuid::parse_str(&batch.batch_id).context("batch_id must be a UUID")?;
    if batch.source != "ibkr_client_portal" {
        bail!("IBKR relay source must be ibkr_client_portal");
    }
    if !batch.bridge_version.starts_with("axio7-ibkr-quote-relay/") {
        bail!("unrecognized IBKR quote-relay version");
    }
    if !batch.session_authenticated {
        bail!("IBKR Client Portal session is not authenticated");
    }
    if policy.allowed_symbols.is_empty() {
        bail!("IBKR relay has no allow-listed symbols");
    }
    if policy.maximum_age_ms <= 0 || policy.maximum_future_skew_ms < 0 {
        bail!("IBKR relay freshness policy is invalid");
    }
    if batch.quotes.is_empty() || batch.quotes.len() > policy.allowed_symbols.len() {
        bail!("IBKR quote batch has invalid coverage");
    }

    let captured_age_ms = received_at
        .signed_duration_since(batch.captured_at)
        .num_milliseconds();
    if captured_age_ms > policy.maximum_age_ms {
        bail!("IBKR quote batch is stale");
    }
    if captured_age_ms < -policy.maximum_future_skew_ms {
        bail!("IBKR quote batch timestamp is in the future");
    }

    let mut received_symbols = BTreeSet::new();
    let mut observation_cutoff = batch.captured_at;
    let mut oldest_observation = batch.captured_at;
    for quote in &batch.quotes {
        let symbol = normalize_symbol(&quote.symbol)?;
        if !policy.allowed_symbols.contains(&symbol) {
            bail!("IBKR quote symbol {symbol} is not allow-listed");
        }
        if !received_symbols.insert(symbol.clone()) {
            bail!("duplicate IBKR quote symbol {symbol}");
        }
        if quote.conid == 0 {
            bail!("IBKR conid must be non-zero");
        }
        if !quote.market_data_availability.starts_with('R') {
            bail!(
                "IBKR realtime entitlement is not verified for {symbol} (field 6509={})",
                quote.market_data_availability
            );
        }
        if !valid_price(quote.bid)
            || !valid_price(quote.ask)
            || quote.ask < quote.bid
            || quote.last.is_some_and(|value| !valid_price(value))
            || quote.bid_size.is_some_and(|value| !valid_size(value))
            || quote.ask_size.is_some_and(|value| !valid_size(value))
        {
            bail!("IBKR quote fields are invalid for {symbol}");
        }
        let age_ms = received_at
            .signed_duration_since(quote.provider_observed_at)
            .num_milliseconds();
        if age_ms > policy.maximum_age_ms {
            bail!("IBKR quote is stale for {symbol}");
        }
        if age_ms < -policy.maximum_future_skew_ms {
            bail!("IBKR quote timestamp is in the future for {symbol}");
        }
        if quote.provider_observed_at
            > batch.captured_at + chrono::Duration::milliseconds(policy.maximum_future_skew_ms)
        {
            bail!("IBKR quote timestamp exceeds batch capture time for {symbol}");
        }
        observation_cutoff = observation_cutoff.max(quote.provider_observed_at);
        oldest_observation = oldest_observation.min(quote.provider_observed_at);
    }

    let coverage_complete = received_symbols == policy.allowed_symbols;
    if policy.require_complete_coverage && !coverage_complete {
        let missing = policy
            .allowed_symbols
            .difference(&received_symbols)
            .cloned()
            .collect::<Vec<_>>();
        bail!("IBKR quote coverage is incomplete: {}", missing.join(","));
    }
    let payload = serde_json::to_vec(batch)?;
    Ok(QuoteBatchReceipt {
        schema_version: QUOTE_BATCH_SCHEMA_VERSION.into(),
        batch_id: batch.batch_id.clone(),
        provider: PROVIDER.into(),
        bridge_version: batch.bridge_version.clone(),
        received_at,
        observation_cutoff,
        availability_time: received_at,
        freshness_ms: received_at
            .signed_duration_since(oldest_observation)
            .num_milliseconds()
            .max(0),
        quote_count: batch.quotes.len(),
        expected_symbols: policy.allowed_symbols.iter().cloned().collect(),
        received_symbols: received_symbols.into_iter().collect(),
        coverage_complete,
        realtime_entitlement_verified: true,
        quote_only: true,
        execution_enabled: false,
        public_redistribution_authorized: false,
        payload_sha256: format!("{:x}", Sha256::digest(payload)),
    })
}

pub fn persist_quote_batch(
    live_root: &Path,
    batch: IbkrQuoteBatch,
    receipt: QuoteBatchReceipt,
) -> Result<IbkrRelayStatus> {
    let _guard = WRITE_LOCK
        .get_or_init(|| Mutex::new(()))
        .lock()
        .map_err(|_| anyhow::anyhow!("IBKR relay writer lock poisoned"))?;
    fs::create_dir_all(live_root)?;
    let status_path = live_root.join("ibkr_relay_status.json");
    if let Some(previous) = read_status(&status_path)?
        && previous.receipt.batch_id == receipt.batch_id
        && previous.receipt.payload_sha256 == receipt.payload_sha256
    {
        return Ok(previous);
    }

    append_jsonl(
        &live_root.join("ibkr_quote_batches.jsonl"),
        &AcceptedQuoteBatch {
            receipt: receipt.clone(),
            batch,
        },
    )?;
    let status = IbkrRelayStatus {
        status: "CONNECTED_REALTIME_ENTITLED_QUOTE_ONLY".into(),
        receipt,
        caveats: vec![
            "Owner-authorized internal research display only; no public redistribution right is inferred."
                .into(),
            "The relay carries Level-1 quotes only and exposes no account, cookie, order, or trading capability."
                .into(),
            "A stale, delayed, frozen, unentitled, malformed, or incomplete batch is rejected before persistence."
                .into(),
        ],
    };
    fs::write(&status_path, serde_json::to_vec_pretty(&status)?)
        .with_context(|| format!("write IBKR relay status {}", status_path.display()))?;
    Ok(status)
}

pub fn read_status(path: &Path) -> Result<Option<IbkrRelayStatus>> {
    if !path.exists() {
        return Ok(None);
    }
    let bytes =
        fs::read(path).with_context(|| format!("read IBKR relay status {}", path.display()))?;
    Ok(Some(serde_json::from_slice(&bytes)?))
}

fn normalize_symbol(value: &str) -> Result<String> {
    let symbol = value
        .trim()
        .strip_prefix("US.")
        .unwrap_or(value.trim())
        .to_ascii_uppercase();
    if symbol.is_empty()
        || symbol.len() > 16
        || !symbol
            .chars()
            .all(|character| character.is_ascii_alphanumeric() || matches!(character, '.' | '-'))
    {
        bail!("invalid IBKR quote symbol");
    }
    Ok(symbol)
}

fn valid_price(value: f64) -> bool {
    value.is_finite() && value > 0.0
}

fn valid_size(value: f64) -> bool {
    value.is_finite() && value >= 0.0
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::Duration;

    fn quote(symbol: &str, observed_at: DateTime<Utc>) -> IbkrQuote {
        IbkrQuote {
            symbol: symbol.into(),
            conid: 756_733,
            provider_observed_at: observed_at,
            market_data_availability: "RpB".into(),
            bid: 100.0,
            ask: 100.02,
            bid_size: Some(10.0),
            ask_size: Some(12.0),
            last: Some(100.01),
        }
    }

    fn batch(now: DateTime<Utc>) -> IbkrQuoteBatch {
        IbkrQuoteBatch {
            schema_version: QUOTE_BATCH_SCHEMA_VERSION.into(),
            batch_id: Uuid::new_v4().to_string(),
            source: "ibkr_client_portal".into(),
            bridge_version: "axio7-ibkr-quote-relay/1.0".into(),
            captured_at: now - Duration::milliseconds(100),
            session_authenticated: true,
            quotes: vec![quote("SPY", now - Duration::milliseconds(200))],
        }
    }

    fn policy() -> QuoteBatchPolicy {
        QuoteBatchPolicy {
            allowed_symbols: BTreeSet::from(["SPY".into()]),
            maximum_age_ms: 2_000,
            maximum_future_skew_ms: 500,
            require_complete_coverage: true,
        }
    }

    #[test]
    fn accepts_fresh_realtime_complete_quote_batch() {
        let now = Utc::now();
        let receipt = validate_quote_batch(&batch(now), now, &policy()).unwrap();
        assert!(receipt.coverage_complete);
        assert!(receipt.realtime_entitlement_verified);
        assert!(receipt.quote_only);
        assert!(!receipt.execution_enabled);
        assert!(!receipt.public_redistribution_authorized);
    }

    #[test]
    fn rejects_delayed_unentitled_or_stale_quotes() {
        let now = Utc::now();
        let mut delayed = batch(now);
        delayed.quotes[0].market_data_availability = "D".into();
        assert!(validate_quote_batch(&delayed, now, &policy()).is_err());

        let mut unsubscribed = batch(now);
        unsubscribed.quotes[0].market_data_availability = "N".into();
        assert!(validate_quote_batch(&unsubscribed, now, &policy()).is_err());

        let mut stale = batch(now);
        stale.quotes[0].provider_observed_at = now - Duration::seconds(3);
        assert!(validate_quote_batch(&stale, now, &policy()).is_err());
    }

    #[test]
    fn rejects_incomplete_or_extra_coverage() {
        let now = Utc::now();
        let mut required = policy();
        required.allowed_symbols.insert("NVDA".into());
        assert!(validate_quote_batch(&batch(now), now, &required).is_err());

        let mut extra = batch(now);
        extra.quotes.push(quote("AAPL", now));
        assert!(validate_quote_batch(&extra, now, &policy()).is_err());
    }

    #[test]
    fn wire_schema_rejects_account_or_trading_fields() {
        let now = Utc::now();
        let mut value = serde_json::to_value(batch(now)).unwrap();
        value["account_id"] = serde_json::json!("forbidden");
        assert!(serde_json::from_value::<IbkrQuoteBatch>(value).is_err());
    }

    #[test]
    fn persistence_is_idempotent_for_latest_batch() {
        let now = Utc::now();
        let batch = batch(now);
        let receipt = validate_quote_batch(&batch, now, &policy()).unwrap();
        let dir = tempfile::tempdir().unwrap();
        let first = persist_quote_batch(dir.path(), batch.clone(), receipt.clone()).unwrap();
        let second = persist_quote_batch(dir.path(), batch, receipt).unwrap();
        assert_eq!(first.receipt.batch_id, second.receipt.batch_id);
        let rows = fs::read_to_string(dir.path().join("ibkr_quote_batches.jsonl")).unwrap();
        assert_eq!(rows.lines().count(), 1);
    }
}
