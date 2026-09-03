//! Research-only aggregation of option-chain gamma convexity magnitude.
//!
//! The calculation is deliberately unsigned:
//!
//! `|gamma| * open_interest * contract_multiplier * spot^2 * 0.01`
//!
//! This is a sensitivity-magnitude proxy for a one-percent underlying move.
//! Open interest does not reveal holder identity or position sign, so this
//! module reports explicit algebraic sign scenarios instead of inferring
//! participant positioning. Incomplete, non-causal, or stale lineage makes the
//! entire aggregate unavailable; partial exposure is never published.

use std::collections::{BTreeMap, HashMap, HashSet};

use chrono::{DateTime, NaiveDate, Utc};
use serde::{Deserialize, Serialize};

use crate::domain::{CallPut, OptionQuote};

pub const GAMMA_CONVEXITY_SCHEMA_VERSION: &str = "gamma_convexity_feedback_risk.v1";
pub const GAMMA_CONVEXITY_METHOD_VERSION: &str = "unsigned_oi_gamma_1pct.v1";

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct GammaConvexityRequest {
    /// Causal cutoff for the report.
    pub as_of: DateTime<Utc>,
    /// Underlying represented by every quote in `quotes`.
    pub underlying: String,
    /// Explicit point-in-time underlying value used by the formula.
    pub spot: f64,
    /// Contract multiplier shared by the supplied chain slice.
    pub contract_multiplier: f64,
    /// Timestamp at which the supplied open-interest snapshot was known.
    pub oi_as_of: Option<DateTime<Utc>>,
    /// Timestamp at which the supplied gamma values were known.
    pub greeks_as_of: Option<DateTime<Utc>>,
    /// Maximum permitted age of each option quote.
    pub max_quote_age_seconds: i64,
    /// Maximum permitted age of the open-interest snapshot.
    pub max_oi_age_seconds: i64,
    /// Maximum permitted age of the Greeks snapshot.
    pub max_greeks_age_seconds: i64,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum GammaConvexityAvailability {
    Available,
    Unavailable,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum GammaConvexityUnavailableReason {
    EmptyChain,
    EmptyUnderlying,
    InvalidSpot,
    InvalidContractMultiplier,
    InvalidStalenessLimit,
    MissingOiAsOf,
    MissingGreeksAsOf,
    OiTimestampAfterCutoff,
    GreeksTimestampAfterCutoff,
    OiStale,
    GreeksStale,
    QuoteTimestampAfterCutoff,
    QuoteStale,
    EmptyOptionSymbol,
    DuplicateContract,
    UnderlyingMismatch,
    ExpiredContract,
    InvalidStrike,
    InvalidQuoteUnderlyingPrice,
    MissingOpenInterest,
    MissingGamma,
    InvalidGamma,
    NonFiniteExposure,
    IncompleteContractCoverage,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct GammaConvexityCoverage {
    pub total_contracts: usize,
    pub usable_contracts: usize,
    pub contract_coverage_ratio: f64,
    pub missing_open_interest_contracts: usize,
    pub missing_gamma_contracts: usize,
    pub invalid_gamma_contracts: usize,
    pub stale_quote_contracts: usize,
    pub future_quote_contracts: usize,
    pub invalid_contracts: usize,
    pub lineage_present: bool,
    pub lineage_fresh_and_causal: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct GammaConvexityFreshness {
    pub oi_as_of: Option<DateTime<Utc>>,
    pub greeks_as_of: Option<DateTime<Utc>>,
    pub oldest_quote_as_of: Option<DateTime<Utc>>,
    pub newest_quote_as_of: Option<DateTime<Utc>>,
    /// Negative values identify non-causal future timestamps.
    pub oi_age_seconds: Option<i64>,
    /// Negative values identify non-causal future timestamps.
    pub greeks_age_seconds: Option<i64>,
    pub maximum_observed_quote_age_seconds: Option<i64>,
    pub max_quote_age_seconds: i64,
    pub max_oi_age_seconds: i64,
    pub max_greeks_age_seconds: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct GammaExposureBreakdown {
    /// Dollar delta-change magnitude for a one-percent underlying move.
    pub unsigned_total_per_one_percent_move: f64,
    pub unsigned_call_per_one_percent_move: f64,
    pub unsigned_put_per_one_percent_move: f64,
    pub call_share_of_unsigned_exposure: Option<f64>,
    pub put_share_of_unsigned_exposure: Option<f64>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct GammaBucketConcentration {
    /// Number of distinct listed buckets, including buckets with zero exposure.
    pub listed_bucket_count: usize,
    /// Number of buckets with strictly positive unsigned exposure.
    pub exposure_bucket_count: usize,
    /// Herfindahl-Hirschman concentration of unsigned exposure.
    pub hhi: Option<f64>,
    /// Reciprocal of HHI when exposure is positive.
    pub effective_bucket_count: Option<f64>,
    pub largest_bucket_share: Option<f64>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct GammaExpiryConcentration {
    pub summary: GammaBucketConcentration,
    pub dominant_expiry: Option<NaiveDate>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct GammaStrikeConcentration {
    pub summary: GammaBucketConcentration,
    pub dominant_strike: Option<f64>,
    pub dominant_strike_abs_distance_pct: Option<f64>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct GammaAtmDistance {
    pub nearest_listed_strike: Option<f64>,
    pub nearest_strike_abs_distance_pct: Option<f64>,
    pub exposure_weighted_abs_moneyness_pct: Option<f64>,
    pub unsigned_exposure_share_within_one_pct: Option<f64>,
    pub unsigned_exposure_share_within_two_pct: Option<f64>,
    pub unsigned_exposure_share_within_five_pct: Option<f64>,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "snake_case")]
pub enum GammaSignScenarioKind {
    UniformPositiveSign,
    UniformNegativeSign,
    CallsPositivePutsNegative,
    CallsNegativePutsPositive,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct GammaSignScenario {
    pub scenario: GammaSignScenarioKind,
    pub signed_exposure_per_one_percent_move: f64,
    pub assumption: String,
    /// Always false: sign is an explicit mathematical assumption, not an observation.
    pub is_observed: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct GammaConvexityResearchPolicy {
    pub product_scope: String,
    pub participant_identity_inferred: bool,
    pub participant_position_sign_observed: bool,
    pub personalization_used: bool,
    pub investment_advice: bool,
    pub execution_instruction: bool,
}

impl Default for GammaConvexityResearchPolicy {
    fn default() -> Self {
        Self {
            product_scope: "IMPERSONAL_WHOLE_MARKET_STATISTICAL_RESEARCH".to_string(),
            participant_identity_inferred: false,
            participant_position_sign_observed: false,
            personalization_used: false,
            investment_advice: false,
            execution_instruction: false,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct GammaConvexityFeedbackRisk {
    pub schema_version: String,
    pub method_version: String,
    pub availability: GammaConvexityAvailability,
    pub unavailable_reasons: Vec<GammaConvexityUnavailableReason>,
    pub as_of: DateTime<Utc>,
    pub underlying: String,
    /// `None` when the explicit spot input is invalid or non-finite.
    pub spot: Option<f64>,
    pub units: String,
    pub coverage: GammaConvexityCoverage,
    pub freshness: GammaConvexityFreshness,
    /// `None` whenever availability is `unavailable`; no partial aggregate leaks.
    pub exposure: Option<GammaExposureBreakdown>,
    pub expiry_concentration: Option<GammaExpiryConcentration>,
    pub strike_concentration: Option<GammaStrikeConcentration>,
    pub atm_distance: Option<GammaAtmDistance>,
    /// Empty whenever availability is `unavailable`.
    pub sign_scenarios: Vec<GammaSignScenario>,
    pub research_only_policy: GammaConvexityResearchPolicy,
    pub caveats: Vec<String>,
}

#[derive(Debug, Clone)]
struct Contribution {
    expiry: NaiveDate,
    strike: f64,
    call_put: CallPut,
    unsigned_exposure: f64,
}

/// Aggregate a complete point-in-time option-chain slice into an unsigned
/// convexity-magnitude report.
///
/// The function returns a serializable unavailable report instead of an error
/// when inputs are incomplete or stale. This is intentional: unknown risk must
/// remain observable without being silently converted to zero.
pub fn gamma_convexity_feedback_risk(
    quotes: &[OptionQuote],
    request: &GammaConvexityRequest,
) -> GammaConvexityFeedbackRisk {
    let mut reasons = Vec::new();

    if quotes.is_empty() {
        push_reason(&mut reasons, GammaConvexityUnavailableReason::EmptyChain);
    }
    if request.underlying.trim().is_empty() {
        push_reason(
            &mut reasons,
            GammaConvexityUnavailableReason::EmptyUnderlying,
        );
    }
    if !request.spot.is_finite() || request.spot <= 0.0 {
        push_reason(&mut reasons, GammaConvexityUnavailableReason::InvalidSpot);
    }
    if !request.contract_multiplier.is_finite() || request.contract_multiplier <= 0.0 {
        push_reason(
            &mut reasons,
            GammaConvexityUnavailableReason::InvalidContractMultiplier,
        );
    }

    let staleness_limits_valid = request.max_quote_age_seconds >= 0
        && request.max_oi_age_seconds >= 0
        && request.max_greeks_age_seconds >= 0;
    if !staleness_limits_valid {
        push_reason(
            &mut reasons,
            GammaConvexityUnavailableReason::InvalidStalenessLimit,
        );
    }

    let oi_age_seconds = request
        .oi_as_of
        .map(|timestamp| age_seconds(request.as_of, timestamp));
    let greeks_age_seconds = request
        .greeks_as_of
        .map(|timestamp| age_seconds(request.as_of, timestamp));

    match oi_age_seconds {
        None => push_reason(&mut reasons, GammaConvexityUnavailableReason::MissingOiAsOf),
        Some(age) if age < 0 => push_reason(
            &mut reasons,
            GammaConvexityUnavailableReason::OiTimestampAfterCutoff,
        ),
        Some(age) if staleness_limits_valid && age > request.max_oi_age_seconds => {
            push_reason(&mut reasons, GammaConvexityUnavailableReason::OiStale);
        }
        Some(_) => {}
    }

    match greeks_age_seconds {
        None => push_reason(
            &mut reasons,
            GammaConvexityUnavailableReason::MissingGreeksAsOf,
        ),
        Some(age) if age < 0 => push_reason(
            &mut reasons,
            GammaConvexityUnavailableReason::GreeksTimestampAfterCutoff,
        ),
        Some(age) if staleness_limits_valid && age > request.max_greeks_age_seconds => {
            push_reason(&mut reasons, GammaConvexityUnavailableReason::GreeksStale);
        }
        Some(_) => {}
    }

    let mut missing_open_interest_contracts = 0;
    let mut missing_gamma_contracts = 0;
    let mut invalid_gamma_contracts = 0;
    let mut stale_quote_contracts = 0;
    let mut future_quote_contracts = 0;
    let mut invalid_contracts = 0;
    let mut contributions = Vec::with_capacity(quotes.len());
    let mut seen_contracts = HashSet::with_capacity(quotes.len());
    let mut oldest_quote_as_of = None;
    let mut newest_quote_as_of = None;
    let mut maximum_observed_quote_age_seconds = None;

    for quote in quotes {
        oldest_quote_as_of = Some(
            oldest_quote_as_of.map_or(quote.timestamp, |current: DateTime<Utc>| {
                current.min(quote.timestamp)
            }),
        );
        newest_quote_as_of = Some(
            newest_quote_as_of.map_or(quote.timestamp, |current: DateTime<Utc>| {
                current.max(quote.timestamp)
            }),
        );

        let quote_age = age_seconds(request.as_of, quote.timestamp);
        if quote_age >= 0 {
            maximum_observed_quote_age_seconds = Some(
                maximum_observed_quote_age_seconds
                    .map_or(quote_age, |current: i64| current.max(quote_age)),
            );
        }

        let mut row_valid = true;
        if quote_age < 0 {
            future_quote_contracts += 1;
            row_valid = false;
            push_reason(
                &mut reasons,
                GammaConvexityUnavailableReason::QuoteTimestampAfterCutoff,
            );
        } else if staleness_limits_valid && quote_age > request.max_quote_age_seconds {
            stale_quote_contracts += 1;
            row_valid = false;
            push_reason(&mut reasons, GammaConvexityUnavailableReason::QuoteStale);
        }

        if quote.option_symbol.trim().is_empty() {
            row_valid = false;
            push_reason(
                &mut reasons,
                GammaConvexityUnavailableReason::EmptyOptionSymbol,
            );
        } else if !seen_contracts.insert(quote.option_symbol.clone()) {
            row_valid = false;
            push_reason(
                &mut reasons,
                GammaConvexityUnavailableReason::DuplicateContract,
            );
        }

        if !quote
            .underlying
            .eq_ignore_ascii_case(request.underlying.trim())
        {
            row_valid = false;
            push_reason(
                &mut reasons,
                GammaConvexityUnavailableReason::UnderlyingMismatch,
            );
        }
        if quote.expiry < request.as_of.date_naive() {
            row_valid = false;
            push_reason(
                &mut reasons,
                GammaConvexityUnavailableReason::ExpiredContract,
            );
        }
        if !quote.strike.is_finite() || quote.strike <= 0.0 {
            row_valid = false;
            push_reason(&mut reasons, GammaConvexityUnavailableReason::InvalidStrike);
        }
        if !quote.underlying_price.is_finite() || quote.underlying_price <= 0.0 {
            row_valid = false;
            push_reason(
                &mut reasons,
                GammaConvexityUnavailableReason::InvalidQuoteUnderlyingPrice,
            );
        }

        let open_interest = match quote.open_interest_at_open {
            Some(value) => Some(value as f64),
            None => {
                missing_open_interest_contracts += 1;
                row_valid = false;
                push_reason(
                    &mut reasons,
                    GammaConvexityUnavailableReason::MissingOpenInterest,
                );
                None
            }
        };

        let gamma = match quote.gamma {
            Some(value) if value.is_finite() && value >= 0.0 => Some(value),
            Some(_) => {
                invalid_gamma_contracts += 1;
                row_valid = false;
                push_reason(&mut reasons, GammaConvexityUnavailableReason::InvalidGamma);
                None
            }
            None => {
                missing_gamma_contracts += 1;
                row_valid = false;
                push_reason(&mut reasons, GammaConvexityUnavailableReason::MissingGamma);
                None
            }
        };

        if row_valid {
            let unsigned_exposure = gamma.expect("validated gamma").abs()
                * open_interest.expect("validated open interest")
                * request.contract_multiplier
                * request.spot
                * request.spot
                * 0.01;
            if unsigned_exposure.is_finite() && unsigned_exposure >= 0.0 {
                contributions.push(Contribution {
                    expiry: quote.expiry,
                    strike: quote.strike,
                    call_put: quote.call_put,
                    unsigned_exposure,
                });
            } else {
                row_valid = false;
                push_reason(
                    &mut reasons,
                    GammaConvexityUnavailableReason::NonFiniteExposure,
                );
            }
        }

        if !row_valid {
            invalid_contracts += 1;
        }
    }

    if contributions.len() != quotes.len() {
        push_reason(
            &mut reasons,
            GammaConvexityUnavailableReason::IncompleteContractCoverage,
        );
    }

    let lineage_present = request.oi_as_of.is_some() && request.greeks_as_of.is_some();
    let lineage_fresh_and_causal = lineage_present
        && staleness_limits_valid
        && oi_age_seconds.is_some_and(|age| age >= 0 && age <= request.max_oi_age_seconds)
        && greeks_age_seconds.is_some_and(|age| age >= 0 && age <= request.max_greeks_age_seconds);
    let contract_coverage_ratio = if quotes.is_empty() {
        0.0
    } else {
        contributions.len() as f64 / quotes.len() as f64
    };

    let coverage = GammaConvexityCoverage {
        total_contracts: quotes.len(),
        usable_contracts: contributions.len(),
        contract_coverage_ratio,
        missing_open_interest_contracts,
        missing_gamma_contracts,
        invalid_gamma_contracts,
        stale_quote_contracts,
        future_quote_contracts,
        invalid_contracts,
        lineage_present,
        lineage_fresh_and_causal,
    };
    let freshness = GammaConvexityFreshness {
        oi_as_of: request.oi_as_of,
        greeks_as_of: request.greeks_as_of,
        oldest_quote_as_of,
        newest_quote_as_of,
        oi_age_seconds,
        greeks_age_seconds,
        maximum_observed_quote_age_seconds,
        max_quote_age_seconds: request.max_quote_age_seconds,
        max_oi_age_seconds: request.max_oi_age_seconds,
        max_greeks_age_seconds: request.max_greeks_age_seconds,
    };

    let available = reasons.is_empty();
    let (exposure, expiry_concentration, strike_concentration, atm_distance, sign_scenarios) =
        if available {
            let exposure = exposure_breakdown(&contributions);
            let expiry = expiry_concentration(&contributions);
            let strike = strike_concentration(&contributions, request.spot);
            let atm = atm_distance(&contributions, request.spot);
            let scenarios = sign_scenarios(&exposure);
            (
                Some(exposure),
                Some(expiry),
                Some(strike),
                Some(atm),
                scenarios,
            )
        } else {
            (None, None, None, None, Vec::new())
        };

    GammaConvexityFeedbackRisk {
        schema_version: GAMMA_CONVEXITY_SCHEMA_VERSION.to_string(),
        method_version: GAMMA_CONVEXITY_METHOD_VERSION.to_string(),
        availability: if available {
            GammaConvexityAvailability::Available
        } else {
            GammaConvexityAvailability::Unavailable
        },
        unavailable_reasons: reasons,
        as_of: request.as_of,
        underlying: request.underlying.trim().to_uppercase(),
        spot: (request.spot.is_finite() && request.spot > 0.0).then_some(request.spot),
        units: "DELTA_NOTIONAL_CHANGE_MAGNITUDE_PER_ONE_PERCENT_UNDERLYING_MOVE".to_string(),
        coverage,
        freshness,
        exposure,
        expiry_concentration,
        strike_concentration,
        atm_distance,
        sign_scenarios,
        research_only_policy: GammaConvexityResearchPolicy::default(),
        caveats: vec![
            "Unsigned exposure is |gamma| x open interest x contract multiplier x spot^2 x 1%; it measures sensitivity magnitude only.".to_string(),
            "Open interest does not reveal holder identity or the sign of any participant exposure.".to_string(),
            "Sign scenarios are algebraic assumptions, not observed positioning.".to_string(),
            "Availability requires complete, causal, fresh OI, Greeks, and quote lineage for every included contract.".to_string(),
            "Whole-market statistical research only; not investment advice or an execution instruction.".to_string(),
        ],
    }
}

fn age_seconds(as_of: DateTime<Utc>, observed_at: DateTime<Utc>) -> i64 {
    as_of.signed_duration_since(observed_at).num_seconds()
}

fn push_reason(
    reasons: &mut Vec<GammaConvexityUnavailableReason>,
    reason: GammaConvexityUnavailableReason,
) {
    if !reasons.contains(&reason) {
        reasons.push(reason);
    }
}

fn exposure_breakdown(contributions: &[Contribution]) -> GammaExposureBreakdown {
    let mut call = 0.0;
    let mut put = 0.0;
    for contribution in contributions {
        match contribution.call_put {
            CallPut::Call => call += contribution.unsigned_exposure,
            CallPut::Put => put += contribution.unsigned_exposure,
        }
    }
    let total = call + put;
    GammaExposureBreakdown {
        unsigned_total_per_one_percent_move: total,
        unsigned_call_per_one_percent_move: call,
        unsigned_put_per_one_percent_move: put,
        call_share_of_unsigned_exposure: positive_ratio(call, total),
        put_share_of_unsigned_exposure: positive_ratio(put, total),
    }
}

fn expiry_concentration(contributions: &[Contribution]) -> GammaExpiryConcentration {
    let mut buckets = BTreeMap::<NaiveDate, f64>::new();
    for contribution in contributions {
        *buckets.entry(contribution.expiry).or_default() += contribution.unsigned_exposure;
    }
    let values = buckets.values().copied().collect::<Vec<_>>();
    let summary = bucket_concentration(&values);
    let dominant_expiry = if summary.largest_bucket_share.is_some() {
        buckets
            .iter()
            .max_by(|left, right| left.1.total_cmp(right.1).then_with(|| right.0.cmp(left.0)))
            .map(|(expiry, _)| *expiry)
    } else {
        None
    };
    GammaExpiryConcentration {
        summary,
        dominant_expiry,
    }
}

fn strike_concentration(contributions: &[Contribution], spot: f64) -> GammaStrikeConcentration {
    let mut buckets = HashMap::<u64, (f64, f64)>::new();
    for contribution in contributions {
        let entry = buckets
            .entry(contribution.strike.to_bits())
            .or_insert((contribution.strike, 0.0));
        entry.1 += contribution.unsigned_exposure;
    }
    let mut rows = buckets.into_values().collect::<Vec<_>>();
    rows.sort_by(|left, right| left.0.total_cmp(&right.0));
    let values = rows.iter().map(|row| row.1).collect::<Vec<_>>();
    let summary = bucket_concentration(&values);
    let dominant_strike = if summary.largest_bucket_share.is_some() {
        rows.iter()
            .max_by(|left, right| {
                left.1
                    .total_cmp(&right.1)
                    .then_with(|| right.0.total_cmp(&left.0))
            })
            .map(|row| row.0)
    } else {
        None
    };
    GammaStrikeConcentration {
        summary,
        dominant_strike,
        dominant_strike_abs_distance_pct: dominant_strike.map(|strike| (strike / spot - 1.0).abs()),
    }
}

fn bucket_concentration(values: &[f64]) -> GammaBucketConcentration {
    let listed_bucket_count = values.len();
    let exposure_bucket_count = values.iter().filter(|value| **value > 0.0).count();
    let total = values.iter().sum::<f64>();
    if total <= 0.0 {
        return GammaBucketConcentration {
            listed_bucket_count,
            exposure_bucket_count,
            hhi: None,
            effective_bucket_count: None,
            largest_bucket_share: None,
        };
    }

    let mut hhi = 0.0;
    let mut largest_bucket_share = 0.0_f64;
    for value in values {
        let share = *value / total;
        hhi += share * share;
        largest_bucket_share = largest_bucket_share.max(share);
    }
    GammaBucketConcentration {
        listed_bucket_count,
        exposure_bucket_count,
        hhi: Some(hhi),
        effective_bucket_count: (hhi > 0.0).then_some(1.0 / hhi),
        largest_bucket_share: Some(largest_bucket_share),
    }
}

fn atm_distance(contributions: &[Contribution], spot: f64) -> GammaAtmDistance {
    let nearest_listed_strike = contributions
        .iter()
        .map(|row| row.strike)
        .min_by(|left, right| {
            let left_distance = (*left / spot - 1.0).abs();
            let right_distance = (*right / spot - 1.0).abs();
            left_distance
                .total_cmp(&right_distance)
                .then_with(|| left.total_cmp(right))
        });
    let nearest_strike_abs_distance_pct =
        nearest_listed_strike.map(|strike| (strike / spot - 1.0).abs());

    let total = contributions
        .iter()
        .map(|row| row.unsigned_exposure)
        .sum::<f64>();
    if total <= 0.0 {
        return GammaAtmDistance {
            nearest_listed_strike,
            nearest_strike_abs_distance_pct,
            exposure_weighted_abs_moneyness_pct: None,
            unsigned_exposure_share_within_one_pct: None,
            unsigned_exposure_share_within_two_pct: None,
            unsigned_exposure_share_within_five_pct: None,
        };
    }

    let mut weighted_distance = 0.0;
    let mut within_one = 0.0;
    let mut within_two = 0.0;
    let mut within_five = 0.0;
    for contribution in contributions {
        let distance = (contribution.strike / spot - 1.0).abs();
        weighted_distance += contribution.unsigned_exposure * distance;
        if distance <= 0.01 {
            within_one += contribution.unsigned_exposure;
        }
        if distance <= 0.02 {
            within_two += contribution.unsigned_exposure;
        }
        if distance <= 0.05 {
            within_five += contribution.unsigned_exposure;
        }
    }
    GammaAtmDistance {
        nearest_listed_strike,
        nearest_strike_abs_distance_pct,
        exposure_weighted_abs_moneyness_pct: Some(weighted_distance / total),
        unsigned_exposure_share_within_one_pct: Some(within_one / total),
        unsigned_exposure_share_within_two_pct: Some(within_two / total),
        unsigned_exposure_share_within_five_pct: Some(within_five / total),
    }
}

fn positive_ratio(numerator: f64, denominator: f64) -> Option<f64> {
    (denominator > 0.0).then_some(numerator / denominator)
}

fn sign_scenarios(exposure: &GammaExposureBreakdown) -> Vec<GammaSignScenario> {
    let total = exposure.unsigned_total_per_one_percent_move;
    let call = exposure.unsigned_call_per_one_percent_move;
    let put = exposure.unsigned_put_per_one_percent_move;
    vec![
        GammaSignScenario {
            scenario: GammaSignScenarioKind::UniformPositiveSign,
            signed_exposure_per_one_percent_move: total,
            assumption: "Every included contract is assigned a positive gamma sign.".to_string(),
            is_observed: false,
        },
        GammaSignScenario {
            scenario: GammaSignScenarioKind::UniformNegativeSign,
            signed_exposure_per_one_percent_move: -total,
            assumption: "Every included contract is assigned a negative gamma sign.".to_string(),
            is_observed: false,
        },
        GammaSignScenario {
            scenario: GammaSignScenarioKind::CallsPositivePutsNegative,
            signed_exposure_per_one_percent_move: call - put,
            assumption: "Calls are assigned a positive sign and puts a negative sign.".to_string(),
            is_observed: false,
        },
        GammaSignScenario {
            scenario: GammaSignScenarioKind::CallsNegativePutsPositive,
            signed_exposure_per_one_percent_move: put - call,
            assumption: "Calls are assigned a negative sign and puts a positive sign.".to_string(),
            is_observed: false,
        },
    ]
}

#[cfg(test)]
mod tests {
    use chrono::{Duration, TimeZone};

    use super::*;

    fn timestamp() -> DateTime<Utc> {
        Utc.with_ymd_and_hms(2026, 7, 23, 14, 0, 0)
            .single()
            .unwrap()
    }

    fn request() -> GammaConvexityRequest {
        let as_of = timestamp();
        GammaConvexityRequest {
            as_of,
            underlying: "SPX".to_string(),
            spot: 100.0,
            contract_multiplier: 100.0,
            oi_as_of: Some(as_of - Duration::minutes(5)),
            greeks_as_of: Some(as_of - Duration::seconds(10)),
            max_quote_age_seconds: 60,
            max_oi_age_seconds: 3_600,
            max_greeks_age_seconds: 60,
        }
    }

    fn quote(
        symbol: &str,
        call_put: CallPut,
        strike: f64,
        expiry_days: i64,
        open_interest: Option<u64>,
        gamma: Option<f64>,
    ) -> OptionQuote {
        let as_of = timestamp();
        OptionQuote {
            timestamp: as_of - Duration::seconds(5),
            underlying: "SPX".to_string(),
            option_symbol: symbol.to_string(),
            expiry: (as_of + Duration::days(expiry_days)).date_naive(),
            dte: expiry_days as i32,
            strike,
            call_put,
            bid: 1.0,
            ask: 1.2,
            bid_size: 10,
            ask_size: 12,
            last: Some(1.1),
            volume: Some(50),
            open_interest_at_open: open_interest,
            iv: Some(0.2),
            delta: Some(0.5),
            gamma,
            theta: Some(-0.1),
            vega: Some(0.2),
            underlying_price: 100.0,
            source: "TEST".to_string(),
        }
    }

    fn available_chain() -> Vec<OptionQuote> {
        vec![
            quote("SPX-C-100", CallPut::Call, 100.0, 1, Some(100), Some(0.02)),
            quote("SPX-P-104", CallPut::Put, 104.0, 2, Some(200), Some(0.01)),
        ]
    }

    fn assert_close(actual: f64, expected: f64) {
        assert!(
            (actual - expected).abs() <= 1e-10_f64.max(expected.abs() * 1e-12),
            "actual={actual}, expected={expected}"
        );
    }

    fn has_reason(
        report: &GammaConvexityFeedbackRisk,
        reason: GammaConvexityUnavailableReason,
    ) -> bool {
        report.unavailable_reasons.contains(&reason)
    }

    #[test]
    fn aggregates_unsigned_exposure_call_put_concentration_and_atm_distance() {
        let report = gamma_convexity_feedback_risk(&available_chain(), &request());
        assert_eq!(report.availability, GammaConvexityAvailability::Available);
        assert!(report.unavailable_reasons.is_empty());

        let exposure = report.exposure.unwrap();
        assert_close(exposure.unsigned_call_per_one_percent_move, 20_000.0);
        assert_close(exposure.unsigned_put_per_one_percent_move, 20_000.0);
        assert_close(exposure.unsigned_total_per_one_percent_move, 40_000.0);
        assert_close(exposure.call_share_of_unsigned_exposure.unwrap(), 0.5);
        assert_close(exposure.put_share_of_unsigned_exposure.unwrap(), 0.5);

        let expiry = report.expiry_concentration.unwrap();
        assert_eq!(expiry.summary.listed_bucket_count, 2);
        assert_eq!(expiry.summary.exposure_bucket_count, 2);
        assert_close(expiry.summary.hhi.unwrap(), 0.5);
        assert_close(expiry.summary.effective_bucket_count.unwrap(), 2.0);
        assert_close(expiry.summary.largest_bucket_share.unwrap(), 0.5);
        assert_eq!(
            expiry.dominant_expiry,
            Some((timestamp() + Duration::days(1)).date_naive())
        );

        let strike = report.strike_concentration.unwrap();
        assert_eq!(strike.summary.listed_bucket_count, 2);
        assert_eq!(strike.dominant_strike, Some(100.0));
        assert_close(strike.dominant_strike_abs_distance_pct.unwrap(), 0.0);

        let atm = report.atm_distance.unwrap();
        assert_eq!(atm.nearest_listed_strike, Some(100.0));
        assert_close(atm.nearest_strike_abs_distance_pct.unwrap(), 0.0);
        assert_close(atm.exposure_weighted_abs_moneyness_pct.unwrap(), 0.02);
        assert_close(atm.unsigned_exposure_share_within_one_pct.unwrap(), 0.5);
        assert_close(atm.unsigned_exposure_share_within_two_pct.unwrap(), 0.5);
        assert_close(atm.unsigned_exposure_share_within_five_pct.unwrap(), 1.0);
    }

    #[test]
    fn sign_scenarios_are_explicit_symmetric_and_never_observed() {
        let report = gamma_convexity_feedback_risk(&available_chain(), &request());
        assert_eq!(report.sign_scenarios.len(), 4);
        let values = report
            .sign_scenarios
            .iter()
            .map(|row| (row.scenario, row.signed_exposure_per_one_percent_move))
            .collect::<HashMap<_, _>>();
        assert_close(
            values[&GammaSignScenarioKind::UniformPositiveSign],
            40_000.0,
        );
        assert_close(
            values[&GammaSignScenarioKind::UniformNegativeSign],
            -40_000.0,
        );
        assert_close(
            values[&GammaSignScenarioKind::CallsPositivePutsNegative],
            0.0,
        );
        assert_close(
            values[&GammaSignScenarioKind::CallsNegativePutsPositive],
            0.0,
        );
        assert!(report.sign_scenarios.iter().all(|row| !row.is_observed));
        assert!(!report.research_only_policy.participant_identity_inferred);
        assert!(
            !report
                .research_only_policy
                .participant_position_sign_observed
        );
    }

    #[test]
    fn any_missing_open_interest_makes_the_entire_report_unavailable() {
        let mut quotes = available_chain();
        quotes[1].open_interest_at_open = None;
        let report = gamma_convexity_feedback_risk(&quotes, &request());
        assert_eq!(report.availability, GammaConvexityAvailability::Unavailable);
        assert!(has_reason(
            &report,
            GammaConvexityUnavailableReason::MissingOpenInterest
        ));
        assert!(has_reason(
            &report,
            GammaConvexityUnavailableReason::IncompleteContractCoverage
        ));
        assert_eq!(report.coverage.missing_open_interest_contracts, 1);
        assert_eq!(report.coverage.usable_contracts, 1);
        assert_close(report.coverage.contract_coverage_ratio, 0.5);
        assert!(report.exposure.is_none());
        assert!(report.expiry_concentration.is_none());
        assert!(report.strike_concentration.is_none());
        assert!(report.atm_distance.is_none());
        assert!(report.sign_scenarios.is_empty());
    }

    #[test]
    fn any_missing_or_invalid_gamma_makes_the_entire_report_unavailable() {
        let mut missing = available_chain();
        missing[0].gamma = None;
        let missing_report = gamma_convexity_feedback_risk(&missing, &request());
        assert!(has_reason(
            &missing_report,
            GammaConvexityUnavailableReason::MissingGamma
        ));
        assert_eq!(missing_report.coverage.missing_gamma_contracts, 1);
        assert!(missing_report.exposure.is_none());

        let mut negative = available_chain();
        negative[0].gamma = Some(-0.01);
        let negative_report = gamma_convexity_feedback_risk(&negative, &request());
        assert!(has_reason(
            &negative_report,
            GammaConvexityUnavailableReason::InvalidGamma
        ));
        assert_eq!(negative_report.coverage.invalid_gamma_contracts, 1);
        assert!(negative_report.exposure.is_none());

        let mut non_finite = available_chain();
        non_finite[0].gamma = Some(f64::NAN);
        let non_finite_report = gamma_convexity_feedback_risk(&non_finite, &request());
        assert!(has_reason(
            &non_finite_report,
            GammaConvexityUnavailableReason::InvalidGamma
        ));
        assert!(non_finite_report.exposure.is_none());
    }

    #[test]
    fn missing_lineage_timestamps_are_unavailable_even_with_complete_contracts() {
        let mut missing_oi = request();
        missing_oi.oi_as_of = None;
        let oi_report = gamma_convexity_feedback_risk(&available_chain(), &missing_oi);
        assert!(has_reason(
            &oi_report,
            GammaConvexityUnavailableReason::MissingOiAsOf
        ));
        assert!(!oi_report.coverage.lineage_present);
        assert!(!oi_report.coverage.lineage_fresh_and_causal);
        assert!(oi_report.exposure.is_none());

        let mut missing_greeks = request();
        missing_greeks.greeks_as_of = None;
        let greeks_report = gamma_convexity_feedback_risk(&available_chain(), &missing_greeks);
        assert!(has_reason(
            &greeks_report,
            GammaConvexityUnavailableReason::MissingGreeksAsOf
        ));
        assert!(!greeks_report.coverage.lineage_present);
        assert!(greeks_report.exposure.is_none());
    }

    #[test]
    fn stale_oi_greeks_or_quotes_are_unavailable() {
        let mut stale_oi = request();
        stale_oi.oi_as_of = Some(stale_oi.as_of - Duration::seconds(3_601));
        let oi_report = gamma_convexity_feedback_risk(&available_chain(), &stale_oi);
        assert!(has_reason(
            &oi_report,
            GammaConvexityUnavailableReason::OiStale
        ));
        assert_eq!(oi_report.freshness.oi_age_seconds, Some(3_601));
        assert!(oi_report.exposure.is_none());

        let mut stale_greeks = request();
        stale_greeks.greeks_as_of = Some(stale_greeks.as_of - Duration::seconds(61));
        let greeks_report = gamma_convexity_feedback_risk(&available_chain(), &stale_greeks);
        assert!(has_reason(
            &greeks_report,
            GammaConvexityUnavailableReason::GreeksStale
        ));
        assert!(greeks_report.exposure.is_none());

        let mut stale_quotes = available_chain();
        stale_quotes[0].timestamp = timestamp() - Duration::seconds(61);
        let quote_report = gamma_convexity_feedback_risk(&stale_quotes, &request());
        assert!(has_reason(
            &quote_report,
            GammaConvexityUnavailableReason::QuoteStale
        ));
        assert_eq!(quote_report.coverage.stale_quote_contracts, 1);
        assert_eq!(
            quote_report.freshness.maximum_observed_quote_age_seconds,
            Some(61)
        );
        assert!(quote_report.exposure.is_none());
    }

    #[test]
    fn future_timestamps_are_non_causal_and_unavailable() {
        let mut future_oi = request();
        future_oi.oi_as_of = Some(future_oi.as_of + Duration::seconds(1));
        let oi_report = gamma_convexity_feedback_risk(&available_chain(), &future_oi);
        assert!(has_reason(
            &oi_report,
            GammaConvexityUnavailableReason::OiTimestampAfterCutoff
        ));
        assert_eq!(oi_report.freshness.oi_age_seconds, Some(-1));
        assert!(oi_report.exposure.is_none());

        let mut future_greeks = request();
        future_greeks.greeks_as_of = Some(future_greeks.as_of + Duration::seconds(1));
        let greeks_report = gamma_convexity_feedback_risk(&available_chain(), &future_greeks);
        assert!(has_reason(
            &greeks_report,
            GammaConvexityUnavailableReason::GreeksTimestampAfterCutoff
        ));
        assert!(greeks_report.exposure.is_none());

        let mut future_quotes = available_chain();
        future_quotes[0].timestamp = timestamp() + Duration::seconds(1);
        let quote_report = gamma_convexity_feedback_risk(&future_quotes, &request());
        assert!(has_reason(
            &quote_report,
            GammaConvexityUnavailableReason::QuoteTimestampAfterCutoff
        ));
        assert_eq!(quote_report.coverage.future_quote_contracts, 1);
        assert!(quote_report.exposure.is_none());
    }

    #[test]
    fn empty_chain_and_invalid_explicit_parameters_are_unavailable() {
        let empty_report = gamma_convexity_feedback_risk(&[], &request());
        assert!(has_reason(
            &empty_report,
            GammaConvexityUnavailableReason::EmptyChain
        ));
        assert_eq!(empty_report.coverage.contract_coverage_ratio, 0.0);

        let mut invalid = request();
        invalid.underlying.clear();
        invalid.spot = 0.0;
        invalid.contract_multiplier = f64::NAN;
        invalid.max_quote_age_seconds = -1;
        let invalid_report = gamma_convexity_feedback_risk(&available_chain(), &invalid);
        assert!(has_reason(
            &invalid_report,
            GammaConvexityUnavailableReason::EmptyUnderlying
        ));
        assert!(has_reason(
            &invalid_report,
            GammaConvexityUnavailableReason::InvalidSpot
        ));
        assert!(has_reason(
            &invalid_report,
            GammaConvexityUnavailableReason::InvalidContractMultiplier
        ));
        assert!(has_reason(
            &invalid_report,
            GammaConvexityUnavailableReason::InvalidStalenessLimit
        ));
        assert!(invalid_report.exposure.is_none());
    }

    #[test]
    fn malformed_or_mixed_chain_is_unavailable_and_never_partially_published() {
        let mut quotes = available_chain();
        quotes[0].underlying = "NDX".to_string();
        quotes[0].strike = -1.0;
        quotes[0].underlying_price = f64::INFINITY;
        quotes[1].option_symbol = quotes[0].option_symbol.clone();
        quotes[1].expiry = (timestamp() - Duration::days(1)).date_naive();
        let report = gamma_convexity_feedback_risk(&quotes, &request());
        for reason in [
            GammaConvexityUnavailableReason::UnderlyingMismatch,
            GammaConvexityUnavailableReason::InvalidStrike,
            GammaConvexityUnavailableReason::InvalidQuoteUnderlyingPrice,
            GammaConvexityUnavailableReason::DuplicateContract,
            GammaConvexityUnavailableReason::ExpiredContract,
            GammaConvexityUnavailableReason::IncompleteContractCoverage,
        ] {
            assert!(has_reason(&report, reason), "missing reason {reason:?}");
        }
        assert_eq!(report.coverage.invalid_contracts, 2);
        assert_eq!(report.coverage.usable_contracts, 0);
        assert!(report.exposure.is_none());
        assert!(report.sign_scenarios.is_empty());
    }

    #[test]
    fn zero_exposure_with_complete_fresh_lineage_is_available_but_not_concentrated() {
        let quotes = vec![
            quote("SPX-C-100", CallPut::Call, 100.0, 1, Some(0), Some(0.02)),
            quote("SPX-P-105", CallPut::Put, 105.0, 1, Some(100), Some(0.0)),
        ];
        let report = gamma_convexity_feedback_risk(&quotes, &request());
        assert_eq!(report.availability, GammaConvexityAvailability::Available);
        let exposure = report.exposure.unwrap();
        assert_eq!(exposure.unsigned_total_per_one_percent_move, 0.0);
        assert!(exposure.call_share_of_unsigned_exposure.is_none());
        assert!(exposure.put_share_of_unsigned_exposure.is_none());
        assert!(report.expiry_concentration.unwrap().summary.hhi.is_none());
        assert!(report.strike_concentration.unwrap().summary.hhi.is_none());
        assert!(
            report
                .atm_distance
                .unwrap()
                .exposure_weighted_abs_moneyness_pct
                .is_none()
        );
        assert_eq!(report.sign_scenarios.len(), 4);
        assert!(
            report
                .sign_scenarios
                .iter()
                .all(|scenario| scenario.signed_exposure_per_one_percent_move == 0.0)
        );
    }

    #[test]
    fn ties_are_deterministic_for_dominant_expiry_strike_and_nearest_strike() {
        let quotes = vec![
            quote("SPX-C-096", CallPut::Call, 96.0, 2, Some(100), Some(0.02)),
            quote("SPX-P-104", CallPut::Put, 104.0, 1, Some(100), Some(0.02)),
        ];
        let report = gamma_convexity_feedback_risk(&quotes, &request());
        assert_eq!(
            report.expiry_concentration.unwrap().dominant_expiry,
            Some((timestamp() + Duration::days(1)).date_naive())
        );
        assert_eq!(
            report.strike_concentration.unwrap().dominant_strike,
            Some(96.0)
        );
        assert_eq!(
            report.atm_distance.unwrap().nearest_listed_strike,
            Some(96.0)
        );
    }

    #[test]
    fn serde_contract_is_round_trippable_and_contains_no_action_or_certainty_fields() {
        let report = gamma_convexity_feedback_risk(&available_chain(), &request());
        let json = serde_json::to_string(&report).unwrap();
        let decoded: GammaConvexityFeedbackRisk = serde_json::from_str(&json).unwrap();
        assert_eq!(decoded.availability, report.availability);
        assert_eq!(decoded.coverage, report.coverage);
        assert_eq!(decoded.freshness, report.freshness);
        assert_eq!(decoded.research_only_policy, report.research_only_policy);
        assert_close(
            decoded
                .exposure
                .as_ref()
                .unwrap()
                .unsigned_total_per_one_percent_move,
            report
                .exposure
                .as_ref()
                .unwrap()
                .unsigned_total_per_one_percent_move,
        );
        assert_close(
            decoded
                .atm_distance
                .as_ref()
                .unwrap()
                .exposure_weighted_abs_moneyness_pct
                .unwrap(),
            report
                .atm_distance
                .as_ref()
                .unwrap()
                .exposure_weighted_abs_moneyness_pct
                .unwrap(),
        );
        assert_eq!(decoded.schema_version, "gamma_convexity_feedback_risk.v1");
        assert_eq!(decoded.method_version, "unsigned_oi_gamma_1pct.v1");

        let lower = json.to_lowercase();
        for forbidden in [
            "\"buy\"",
            "\"sell\"",
            "suggested_direction",
            "entry_price",
            "exit_price",
            "position_size",
            "dealer",
            "squeeze",
        ] {
            assert!(
                !lower.contains(forbidden),
                "serialized DTO contains forbidden term: {forbidden}"
            );
        }
        assert!(!decoded.research_only_policy.personalization_used);
        assert!(!decoded.research_only_policy.investment_advice);
        assert!(!decoded.research_only_policy.execution_instruction);
    }
}
