use crate::protocol::{PollResponse, Quote, Snapshot};
use anyhow::{Result, bail, ensure};
use chrono::{DateTime, Utc};
use rust_decimal::Decimal;
use std::{
    str::FromStr,
    time::{Duration, Instant},
};

pub const CONTROL_INTERVAL: Duration = Duration::from_secs(5);
pub const LEASE_LIMIT: Duration = Duration::from_secs(15);
pub const QUOTE_MAX_AGE_SECONDS: i64 = 5;

pub fn money(value: &str) -> Result<Decimal> {
    ensure!(
        value.len() <= 48 && !value.contains(['e', 'E', '+']),
        "invalid_decimal"
    );
    Decimal::from_str(value).map_err(|_| anyhow::anyhow!("invalid_decimal"))
}

#[derive(Debug)]
pub struct Lease {
    deadline: Instant,
    pub generation: u64,
}

impl Lease {
    pub fn accept(response: &PollResponse, started: Instant, now: DateTime<Utc>) -> Result<Self> {
        let seconds = (response.lease_expires_at - response.server_time).num_milliseconds();
        ensure!((1..=15_000).contains(&seconds), "invalid_control_lease");
        ensure!(
            (response.server_time - now).num_seconds().abs() <= 5,
            "control_clock_skew"
        );
        let duration = Duration::from_millis(seconds as u64).min(LEASE_LIMIT);
        let deadline = started + duration;
        ensure!(Instant::now() < deadline, "expired_control_lease");
        Ok(Self {
            deadline,
            generation: response.lease_generation,
        })
    }

    pub fn active(&self) -> bool {
        Instant::now() < self.deadline
    }
    pub fn remaining_millis(&self) -> u64 {
        self.deadline
            .saturating_duration_since(Instant::now())
            .as_millis()
            .min(15_000) as u64
    }
}

pub fn validate_snapshot(snapshot: &Snapshot, account: &str, now: DateTime<Utc>) -> Result<()> {
    ensure!(
        snapshot.environment == "SIMULATE" && snapshot.account_id == account,
        "paper_account_mismatch"
    );
    let age = (now - snapshot.observed_at).num_seconds();
    ensure!((0..=10).contains(&age), "stale_broker_snapshot");
    ensure!(money(&snapshot.equity)? > Decimal::ZERO, "invalid_equity");
    ensure!(
        money(&snapshot.cash)? >= Decimal::ZERO,
        "borrowing_prohibited"
    );
    for position in &snapshot.positions {
        ensure!(
            money(&position.quantity)? >= Decimal::ZERO
                && money(&position.available_quantity)? >= Decimal::ZERO,
            "unexpected_short_position"
        );
        money(&position.market_value)?;
    }
    Ok(())
}

pub fn validate_quote(quote: &Quote, symbol: &str, now: DateTime<Utc>) -> Result<()> {
    ensure!(
        quote.symbol == symbol && !quote.source.is_empty(),
        "quote_identity_mismatch"
    );
    let age = (now - quote.observed_at).num_milliseconds();
    ensure!(
        (0..=QUOTE_MAX_AGE_SECONDS * 1000).contains(&age),
        "quote_stale"
    );
    let bid = money(&quote.bid)?;
    let ask = money(&quote.ask)?;
    ensure!(bid > Decimal::ZERO && ask >= bid, "quote_unusable");
    ensure!(quote.market_open, "outside_regular_session");
    Ok(())
}

pub fn validated_symbol(symbol: &str) -> Result<()> {
    ensure!(
        !symbol.is_empty()
            && symbol.len() <= 14
            && symbol
                .bytes()
                .all(|c| c.is_ascii_uppercase() || c.is_ascii_digit() || matches!(c, b'.' | b'-')),
        "invalid_symbol"
    );
    Ok(())
}

pub fn validate_entry_spread(quote: &Quote) -> Result<()> {
    let bid = money(&quote.bid)?;
    let ask = money(&quote.ask)?;
    ensure!(ask >= bid && bid > Decimal::ZERO, "quote_unusable");
    ensure!(
        (ask - bid) * Decimal::from(20_000) <= (ask + bid) * Decimal::from(20),
        "entry_spread_exceeds_twenty_basis_points"
    );
    Ok(())
}

pub fn verify_endpoint(value: &str, allow_local: bool) -> Result<reqwest::Url> {
    let url = reqwest::Url::parse(value)?;
    ensure!(
        url.username().is_empty()
            && url.password().is_none()
            && url.query().is_none()
            && url.fragment().is_none(),
        "invalid_control_endpoint"
    );
    if url.scheme() != "https"
        && !(allow_local && url.scheme() == "http" && url.host_str() == Some("127.0.0.1"))
    {
        bail!("https_control_endpoint_required");
    }
    Ok(url)
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::Duration as CD;
    #[test]
    fn lease_never_exceeds_fifteen_seconds_or_accepts_clock_skew() {
        let now = Utc::now();
        let mut p = PollResponse {
            server_time: now,
            lease_expires_at: now + CD::seconds(16),
            lease_generation: 1,
            deployments: vec![],
            controls: vec![],
        };
        assert!(Lease::accept(&p, Instant::now(), now).is_err());
        p.lease_expires_at = now + CD::seconds(15);
        assert!(Lease::accept(&p, Instant::now(), now).unwrap().active());
        assert!(Lease::accept(&p, Instant::now() - Duration::from_secs(16), now).is_err());
        assert!(Lease::accept(&p, Instant::now(), now + CD::seconds(7)).is_err());
    }
    #[test]
    fn stale_crossed_and_closed_quotes_never_authorize_entries() {
        let now = Utc::now();
        let mut q = Quote {
            symbol: "SPY".into(),
            observed_at: now,
            bid: "100".into(),
            ask: "100.01".into(),
            market_open: true,
            source: "moomoo".into(),
        };
        assert!(validate_quote(&q, "SPY", now).is_ok());
        q.bid = "101".into();
        assert!(validate_quote(&q, "SPY", now).is_err());
        q.bid = "100".into();
        q.observed_at = now - CD::seconds(6);
        assert!(validate_quote(&q, "SPY", now).is_err());
        q.observed_at = now;
        q.market_open = false;
        assert!(validate_quote(&q, "SPY", now).is_err());
    }
    #[test]
    fn transport_requires_https_without_credential_overrides() {
        assert!(verify_endpoint("https://example.test/functions/v1/strategy-api", false).is_ok());
        assert!(verify_endpoint("http://127.0.0.1:8181", false).is_err());
        assert!(verify_endpoint("http://127.0.0.1:8181", true).is_ok());
        assert!(verify_endpoint("https://token@example.test", false).is_err());
        assert!(verify_endpoint("https://example.test?token=a", false).is_err());
    }
}
