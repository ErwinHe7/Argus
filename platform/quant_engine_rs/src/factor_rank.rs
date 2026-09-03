//! Deterministic, point-in-time cross-sectional factor research.
//!
//! This module deliberately does not participate in production forecast
//! publication. It produces a sealed, unpromoted research rank with fixed
//! factor-group weights and no trading or portfolio-allocation fields.

use std::collections::{BTreeMap, BTreeSet};
use std::error::Error;
use std::fmt::{Display, Formatter};

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

pub const OUTPUT_TYPE: &str = "DETERMINISTIC_FACTOR_RESEARCH_RANK";
pub const CANDIDATE_STATUS: &str = "CANDIDATE_NOT_PROMOTED";
pub const MOMENTUM_WEIGHT_PERCENT: u8 = 40;
pub const LIQUIDITY_PROXY_WEIGHT_PERCENT: u8 = 20;
pub const REGIME_CONDITIONED_PRICE_VOLUME_WEIGHT_PERCENT: u8 = 40;

const SCORE_SCALE: u64 = 1_000_000;
const MAX_UNIVERSE_SIZE: usize = 100_000;

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct CoverageEvidence {
    pub observed_units: u64,
    pub expected_units: u64,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct PointInTimeProvenance {
    pub observation_cutoff: DateTime<Utc>,
    pub available_at: DateTime<Utc>,
    pub source: String,
    pub source_content_sha256: String,
    pub entitled_for_research: bool,
    pub complete: bool,
    pub coverage: CoverageEvidence,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct PointInTimeFactorValue {
    /// A higher value must mean a stronger cross-sectional research score.
    pub value: f64,
    pub provenance: PointInTimeProvenance,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(tag = "kind", rename_all = "SCREAMING_SNAKE_CASE", deny_unknown_fields)]
pub enum LiquidityEvidence {
    OhlcvDollarVolumeProxy {
        aggregation_window: String,
    },
    QuoteSpreadEvidence {
        quote_source: String,
        quote_source_content_sha256: String,
    },
}

impl LiquidityEvidence {
    fn output_label(&self) -> &'static str {
        match self {
            Self::OhlcvDollarVolumeProxy { .. } => "OHLCV_DOLLAR_VOLUME_PROXY",
            Self::QuoteSpreadEvidence { .. } => "QUOTE_SPREAD_EVIDENCE",
        }
    }
}

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct LiquidityFactorValue {
    /// A higher value must mean more liquid. Raw spreads therefore need a
    /// causally computed inverse/rank before entering this contract.
    pub higher_is_more_liquid_value: f64,
    pub provenance: PointInTimeProvenance,
    pub evidence: LiquidityEvidence,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct FactorSnapshot {
    pub symbol: String,
    pub snapshot_cutoff: DateTime<Utc>,
    pub momentum: PointInTimeFactorValue,
    pub liquidity: LiquidityFactorValue,
    pub regime_conditioned_price_volume: PointInTimeFactorValue,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct RegimeEvidence {
    pub regime_id: String,
    pub provenance: PointInTimeProvenance,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct FactorResearchRequest {
    /// The exact, frozen cross-sectional universe. Runtime callers cannot
    /// provide weights; the only weights are the constants in this module.
    pub expected_universe: Vec<String>,
    pub universe_provenance: PointInTimeProvenance,
    /// May contain later snapshots from an offline store. Only the exact
    /// requested cutoff is selected, so later mutations cannot affect a prior
    /// result.
    pub snapshots: Vec<FactorSnapshot>,
    pub observation_cutoff: DateTime<Utc>,
    pub evaluation_as_of: DateTime<Utc>,
    pub maximum_age_seconds: u64,
    pub regime: RegimeEvidence,
    pub feature_version: String,
    pub input_manifest_sha256: String,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct FixedFactorWeights {
    pub momentum_percent: u8,
    pub liquidity_proxy_percent: u8,
    pub regime_conditioned_price_volume_percent: u8,
}

impl FixedFactorWeights {
    fn fixed() -> Self {
        Self {
            momentum_percent: MOMENTUM_WEIGHT_PERCENT,
            liquidity_proxy_percent: LIQUIDITY_PROXY_WEIGHT_PERCENT,
            regime_conditioned_price_volume_percent: REGIME_CONDITIONED_PRICE_VOLUME_WEIGHT_PERCENT,
        }
    }
}

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct RankedFactorRow {
    pub rank: usize,
    pub symbol: String,
    pub composite_score_microunits: u64,
    pub momentum_percentile_microunits: u64,
    pub liquidity_percentile_microunits: u64,
    pub regime_conditioned_price_volume_percentile_microunits: u64,
    pub composite_score_tied: bool,
    pub liquidity_input_label: String,
    pub momentum_provenance: PointInTimeProvenance,
    pub liquidity_provenance: PointInTimeProvenance,
    pub regime_conditioned_price_volume_provenance: PointInTimeProvenance,
    pub selected_snapshot_sha256: String,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct UniverseCoverage {
    pub expected_symbols: usize,
    pub ranked_symbols: usize,
    pub exact_universe_complete: bool,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct FactorResearchRank {
    pub output_type: String,
    pub candidate_status: String,
    pub execution_disabled: bool,
    pub production_publication_disabled: bool,
    pub observation_cutoff: DateTime<Utc>,
    pub evaluation_as_of: DateTime<Utc>,
    pub maximum_age_seconds: u64,
    pub freshness: String,
    pub regime_id: String,
    pub regime_provenance: PointInTimeProvenance,
    pub feature_version: String,
    pub input_manifest_sha256: String,
    /// Hash of only the exact point-in-time inputs selected for this result.
    /// Later snapshots are intentionally outside this hash.
    pub selected_input_sha256: String,
    pub fixed_weights: FixedFactorWeights,
    pub tie_break_policy: String,
    pub liquidity_disclosure: String,
    pub material_caveats: Vec<String>,
    pub universe: Vec<String>,
    pub universe_provenance: PointInTimeProvenance,
    pub coverage: UniverseCoverage,
    pub rows: Vec<RankedFactorRow>,
    /// SHA-256 of this deterministic JSON structure with this field empty.
    pub content_sha256: String,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum FactorRankError {
    UniverseTooSmall,
    UniverseTooLarge,
    InvalidMaximumAge,
    InvalidSymbol(String),
    DuplicateExpectedSymbol(String),
    UnexpectedSnapshotSymbol(String),
    DuplicateExactSnapshot(String),
    IncompleteUniverse(Vec<String>),
    InvalidFeatureVersion,
    InvalidManifestHash,
    InvalidRegime(String),
    InvalidPointInTime {
        symbol: String,
        factor: String,
        reason: String,
    },
    Serialization(String),
    SealMismatch,
}

impl Display for FactorRankError {
    fn fmt(&self, formatter: &mut Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::UniverseTooSmall => {
                write!(
                    formatter,
                    "cross-sectional universe must contain at least two symbols"
                )
            }
            Self::UniverseTooLarge => write!(formatter, "cross-sectional universe is too large"),
            Self::InvalidMaximumAge => write!(formatter, "maximum_age_seconds must be positive"),
            Self::InvalidSymbol(symbol) => write!(formatter, "invalid canonical symbol: {symbol}"),
            Self::DuplicateExpectedSymbol(symbol) => {
                write!(formatter, "duplicate expected-universe symbol: {symbol}")
            }
            Self::UnexpectedSnapshotSymbol(symbol) => {
                write!(
                    formatter,
                    "snapshot symbol is outside the frozen universe: {symbol}"
                )
            }
            Self::DuplicateExactSnapshot(symbol) => {
                write!(formatter, "duplicate exact-cutoff snapshot for {symbol}")
            }
            Self::IncompleteUniverse(symbols) => write!(
                formatter,
                "exact-cutoff snapshot is missing for: {}",
                symbols.join(",")
            ),
            Self::InvalidFeatureVersion => write!(formatter, "feature_version is missing"),
            Self::InvalidManifestHash => write!(formatter, "input manifest SHA-256 is invalid"),
            Self::InvalidRegime(reason) => write!(formatter, "invalid regime evidence: {reason}"),
            Self::InvalidPointInTime {
                symbol,
                factor,
                reason,
            } => write!(
                formatter,
                "invalid point-in-time input for {symbol}/{factor}: {reason}"
            ),
            Self::Serialization(reason) => write!(formatter, "serialization failed: {reason}"),
            Self::SealMismatch => write!(formatter, "factor-rank content seal does not match"),
        }
    }
}

impl Error for FactorRankError {}

#[derive(Clone, Debug, Serialize)]
struct SelectedInput<'a> {
    observation_cutoff: DateTime<Utc>,
    evaluation_as_of: DateTime<Utc>,
    maximum_age_seconds: u64,
    regime: &'a RegimeEvidence,
    universe_provenance: &'a PointInTimeProvenance,
    feature_version: &'a str,
    input_manifest_sha256: &'a str,
    expected_universe: &'a [String],
    snapshots: &'a [FactorSnapshot],
}

/// Build an offline-only, deterministic cross-sectional research rank.
///
/// Snapshots after `observation_cutoff` are deliberately not selected or
/// hashed. Every selected factor and the regime evidence must have the exact
/// requested cutoff and must have become available by `evaluation_as_of`.
pub fn build_factor_research_rank(
    request: &FactorResearchRequest,
) -> Result<FactorResearchRank, FactorRankError> {
    if request.expected_universe.len() < 2 {
        return Err(FactorRankError::UniverseTooSmall);
    }
    if request.expected_universe.len() > MAX_UNIVERSE_SIZE {
        return Err(FactorRankError::UniverseTooLarge);
    }
    if request.maximum_age_seconds == 0 || request.maximum_age_seconds > i64::MAX as u64 {
        return Err(FactorRankError::InvalidMaximumAge);
    }
    if request.feature_version.trim().is_empty() {
        return Err(FactorRankError::InvalidFeatureVersion);
    }
    if !valid_sha256(&request.input_manifest_sha256) {
        return Err(FactorRankError::InvalidManifestHash);
    }
    if request.evaluation_as_of < request.observation_cutoff {
        return Err(FactorRankError::InvalidPointInTime {
            symbol: "UNIVERSE".to_string(),
            factor: "evaluation".to_string(),
            reason: "evaluation_as_of precedes observation_cutoff".to_string(),
        });
    }
    let age_seconds = request
        .evaluation_as_of
        .signed_duration_since(request.observation_cutoff)
        .num_seconds();
    if age_seconds < 0 || age_seconds as u64 > request.maximum_age_seconds {
        return Err(FactorRankError::InvalidPointInTime {
            symbol: "UNIVERSE".to_string(),
            factor: "freshness".to_string(),
            reason: "selected cutoff is stale".to_string(),
        });
    }

    let mut expected = request.expected_universe.clone();
    expected.sort();
    let mut expected_set = BTreeSet::new();
    for symbol in &expected {
        validate_symbol(symbol)?;
        if !expected_set.insert(symbol.clone()) {
            return Err(FactorRankError::DuplicateExpectedSymbol(symbol.clone()));
        }
    }
    validate_provenance(
        request,
        "UNIVERSE",
        "point_in_time_membership",
        &request.universe_provenance,
    )?;
    if request.universe_provenance.coverage.observed_units != expected.len() as u64 {
        return Err(FactorRankError::InvalidPointInTime {
            symbol: "UNIVERSE".to_string(),
            factor: "point_in_time_membership".to_string(),
            reason: "universe evidence count does not match expected_universe".to_string(),
        });
    }

    validate_regime(request)?;

    let mut selected_by_symbol: BTreeMap<String, FactorSnapshot> = BTreeMap::new();
    for snapshot in &request.snapshots {
        validate_symbol(&snapshot.symbol)?;
        if !expected_set.contains(&snapshot.symbol) {
            return Err(FactorRankError::UnexpectedSnapshotSymbol(
                snapshot.symbol.clone(),
            ));
        }
        if snapshot.snapshot_cutoff != request.observation_cutoff {
            // Earlier and later rows can coexist in an offline store. Neither
            // is eligible for an exact-cutoff evaluation.
            continue;
        }
        if selected_by_symbol
            .insert(snapshot.symbol.clone(), snapshot.clone())
            .is_some()
        {
            return Err(FactorRankError::DuplicateExactSnapshot(
                snapshot.symbol.clone(),
            ));
        }
    }

    let missing: Vec<String> = expected
        .iter()
        .filter(|symbol| !selected_by_symbol.contains_key(*symbol))
        .cloned()
        .collect();
    if !missing.is_empty() {
        return Err(FactorRankError::IncompleteUniverse(missing));
    }

    let selected: Vec<FactorSnapshot> = expected
        .iter()
        .filter_map(|symbol| selected_by_symbol.remove(symbol))
        .collect();
    for snapshot in &selected {
        validate_snapshot(request, snapshot)?;
    }

    let momentum_ranks = fractional_rank_twice(&selected, |snapshot| snapshot.momentum.value);
    let liquidity_ranks = fractional_rank_twice(&selected, |snapshot| {
        snapshot.liquidity.higher_is_more_liquid_value
    });
    let price_volume_ranks = fractional_rank_twice(&selected, |snapshot| {
        snapshot.regime_conditioned_price_volume.value
    });

    let selected_input = SelectedInput {
        observation_cutoff: request.observation_cutoff,
        evaluation_as_of: request.evaluation_as_of,
        maximum_age_seconds: request.maximum_age_seconds,
        regime: &request.regime,
        universe_provenance: &request.universe_provenance,
        feature_version: request.feature_version.trim(),
        input_manifest_sha256: &request.input_manifest_sha256,
        expected_universe: &expected,
        snapshots: &selected,
    };
    let selected_input_sha256 = deterministic_json_sha256(&selected_input)?;

    let factor_denominator = 2_u64
        .checked_mul((selected.len() - 1) as u64)
        .ok_or(FactorRankError::UniverseTooLarge)?;
    let composite_denominator = 10_u64
        .checked_mul(factor_denominator)
        .ok_or(FactorRankError::UniverseTooLarge)?;

    let mut scored = Vec::with_capacity(selected.len());
    let mut composite_counts: BTreeMap<u64, usize> = BTreeMap::new();
    for (index, snapshot) in selected.iter().enumerate() {
        let momentum = momentum_ranks[index];
        let liquidity = liquidity_ranks[index];
        let price_volume = price_volume_ranks[index];
        let composite_numerator = u64::from(MOMENTUM_WEIGHT_PERCENT)
            .checked_mul(momentum)
            .and_then(|value| {
                value.checked_add(u64::from(LIQUIDITY_PROXY_WEIGHT_PERCENT) * liquidity)
            })
            .and_then(|value| {
                value.checked_add(
                    u64::from(REGIME_CONDITIONED_PRICE_VOLUME_WEIGHT_PERCENT) * price_volume,
                )
            })
            .ok_or(FactorRankError::UniverseTooLarge)?;
        let normalized_composite_numerator = composite_numerator / 10;
        *composite_counts
            .entry(normalized_composite_numerator)
            .or_default() += 1;
        scored.push((
            snapshot,
            momentum,
            liquidity,
            price_volume,
            normalized_composite_numerator,
        ));
    }
    scored.sort_by(|left, right| {
        right
            .4
            .cmp(&left.4)
            .then_with(|| left.0.symbol.cmp(&right.0.symbol))
    });

    let mut rows = Vec::with_capacity(scored.len());
    for (index, (snapshot, momentum, liquidity, price_volume, composite)) in
        scored.into_iter().enumerate()
    {
        rows.push(RankedFactorRow {
            rank: index + 1,
            symbol: snapshot.symbol.clone(),
            composite_score_microunits: ratio_microunits(composite, composite_denominator),
            momentum_percentile_microunits: ratio_microunits(momentum, factor_denominator),
            liquidity_percentile_microunits: ratio_microunits(liquidity, factor_denominator),
            regime_conditioned_price_volume_percentile_microunits: ratio_microunits(
                price_volume,
                factor_denominator,
            ),
            composite_score_tied: composite_counts.get(&composite).copied().unwrap_or(0) > 1,
            liquidity_input_label: snapshot.liquidity.evidence.output_label().to_string(),
            momentum_provenance: snapshot.momentum.provenance.clone(),
            liquidity_provenance: snapshot.liquidity.provenance.clone(),
            regime_conditioned_price_volume_provenance: snapshot
                .regime_conditioned_price_volume
                .provenance
                .clone(),
            selected_snapshot_sha256: deterministic_json_sha256(snapshot)?,
        });
    }

    let mut report = FactorResearchRank {
        output_type: OUTPUT_TYPE.to_string(),
        candidate_status: CANDIDATE_STATUS.to_string(),
        execution_disabled: true,
        production_publication_disabled: true,
        observation_cutoff: request.observation_cutoff,
        evaluation_as_of: request.evaluation_as_of,
        maximum_age_seconds: request.maximum_age_seconds,
        freshness: "FRESH_AT_EVALUATION_AS_OF".to_string(),
        regime_id: request.regime.regime_id.trim().to_string(),
        regime_provenance: request.regime.provenance.clone(),
        feature_version: request.feature_version.trim().to_string(),
        input_manifest_sha256: request.input_manifest_sha256.clone(),
        selected_input_sha256,
        fixed_weights: FixedFactorWeights::fixed(),
        tie_break_policy: "COMPOSITE_DESC_THEN_SYMBOL_ASC".to_string(),
        liquidity_disclosure:
            "OHLCV/dollar-volume is a liquidity proxy; quote/spread inputs are labeled separately."
                .to_string(),
        material_caveats: vec![
            "Deterministic, unpromoted offline-shadow research heuristic.".to_string(),
            "The rank is not a calibrated probability, expected return, personalized recommendation, target portfolio, or broker order.".to_string(),
            "No production publication or automatic execution path consumes this report.".to_string(),
        ],
        universe: expected,
        universe_provenance: request.universe_provenance.clone(),
        coverage: UniverseCoverage {
            expected_symbols: selected.len(),
            ranked_symbols: rows.len(),
            exact_universe_complete: selected.len() == rows.len(),
        },
        rows,
        content_sha256: String::new(),
    };
    report.content_sha256 = report_content_sha256(&report)?;
    Ok(report)
}

pub fn verify_factor_rank_seal(report: &FactorResearchRank) -> Result<(), FactorRankError> {
    if !valid_sha256(&report.content_sha256)
        || report.content_sha256 != report_content_sha256(report)?
    {
        return Err(FactorRankError::SealMismatch);
    }
    Ok(())
}

fn validate_regime(request: &FactorResearchRequest) -> Result<(), FactorRankError> {
    if request.regime.regime_id.trim().is_empty() {
        return Err(FactorRankError::InvalidRegime(
            "regime_id is missing".to_string(),
        ));
    }
    validate_provenance(request, "REGIME", "regime", &request.regime.provenance)
        .map_err(|error| FactorRankError::InvalidRegime(error.to_string()))
}

fn validate_snapshot(
    request: &FactorResearchRequest,
    snapshot: &FactorSnapshot,
) -> Result<(), FactorRankError> {
    validate_factor(
        request,
        &snapshot.symbol,
        "momentum",
        snapshot.momentum.value,
        &snapshot.momentum.provenance,
    )?;
    validate_factor(
        request,
        &snapshot.symbol,
        "liquidity",
        snapshot.liquidity.higher_is_more_liquid_value,
        &snapshot.liquidity.provenance,
    )?;
    validate_factor(
        request,
        &snapshot.symbol,
        "regime_conditioned_price_volume",
        snapshot.regime_conditioned_price_volume.value,
        &snapshot.regime_conditioned_price_volume.provenance,
    )?;
    match &snapshot.liquidity.evidence {
        LiquidityEvidence::OhlcvDollarVolumeProxy { aggregation_window } => {
            if aggregation_window.trim().is_empty() {
                return Err(FactorRankError::InvalidPointInTime {
                    symbol: snapshot.symbol.clone(),
                    factor: "liquidity".to_string(),
                    reason: "OHLCV proxy aggregation_window is missing".to_string(),
                });
            }
        }
        LiquidityEvidence::QuoteSpreadEvidence {
            quote_source,
            quote_source_content_sha256,
        } => {
            if quote_source.trim().is_empty() || !valid_sha256(quote_source_content_sha256) {
                return Err(FactorRankError::InvalidPointInTime {
                    symbol: snapshot.symbol.clone(),
                    factor: "liquidity".to_string(),
                    reason: "quote/spread evidence is incomplete".to_string(),
                });
            }
        }
    }
    Ok(())
}

fn validate_factor(
    request: &FactorResearchRequest,
    symbol: &str,
    factor: &str,
    value: f64,
    provenance: &PointInTimeProvenance,
) -> Result<(), FactorRankError> {
    if !value.is_finite() {
        return Err(FactorRankError::InvalidPointInTime {
            symbol: symbol.to_string(),
            factor: factor.to_string(),
            reason: "factor value is non-finite".to_string(),
        });
    }
    validate_provenance(request, symbol, factor, provenance)
}

fn validate_provenance(
    request: &FactorResearchRequest,
    symbol: &str,
    factor: &str,
    provenance: &PointInTimeProvenance,
) -> Result<(), FactorRankError> {
    let fail = |reason: &str| FactorRankError::InvalidPointInTime {
        symbol: symbol.to_string(),
        factor: factor.to_string(),
        reason: reason.to_string(),
    };
    if provenance.observation_cutoff != request.observation_cutoff {
        return Err(fail("observation cutoff is not the exact requested cutoff"));
    }
    if provenance.available_at < provenance.observation_cutoff {
        return Err(fail("available_at precedes observation cutoff"));
    }
    if provenance.available_at > request.evaluation_as_of {
        return Err(fail("input was not available at evaluation_as_of"));
    }
    if !provenance.entitled_for_research {
        return Err(fail("source is not entitled for this research use"));
    }
    if !provenance.complete {
        return Err(fail("input is incomplete"));
    }
    if provenance.coverage.expected_units == 0
        || provenance.coverage.observed_units != provenance.coverage.expected_units
    {
        return Err(fail("coverage is incomplete"));
    }
    if provenance.source.trim().is_empty() {
        return Err(fail("source is missing"));
    }
    if !valid_sha256(&provenance.source_content_sha256) {
        return Err(fail("source content SHA-256 is invalid"));
    }
    Ok(())
}

fn validate_symbol(symbol: &str) -> Result<(), FactorRankError> {
    let canonical = symbol.trim().to_ascii_uppercase();
    let valid = !symbol.is_empty()
        && symbol.len() <= 24
        && symbol == canonical
        && symbol
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || byte == b'.' || byte == b'-');
    if valid {
        Ok(())
    } else {
        Err(FactorRankError::InvalidSymbol(symbol.to_string()))
    }
}

fn valid_sha256(value: &str) -> bool {
    value.len() == 64
        && value
            .bytes()
            .all(|byte| byte.is_ascii_digit() || (b'a'..=b'f').contains(&byte))
        && value.bytes().any(|byte| byte != b'0')
}

fn fractional_rank_twice<F>(rows: &[FactorSnapshot], value: F) -> Vec<u64>
where
    F: Fn(&FactorSnapshot) -> f64,
{
    let mut ordered: Vec<usize> = (0..rows.len()).collect();
    ordered.sort_by(|left, right| {
        value(&rows[*left])
            .total_cmp(&value(&rows[*right]))
            .then_with(|| rows[*left].symbol.cmp(&rows[*right].symbol))
    });
    let mut ranks = vec![0; rows.len()];
    let mut start = 0;
    while start < ordered.len() {
        let mut end = start;
        while end + 1 < ordered.len()
            && value(&rows[ordered[start]]).total_cmp(&value(&rows[ordered[end + 1]]))
                == std::cmp::Ordering::Equal
        {
            end += 1;
        }
        let average_rank_twice = (start + end) as u64;
        for position in start..=end {
            ranks[ordered[position]] = average_rank_twice;
        }
        start = end + 1;
    }
    ranks
}

fn ratio_microunits(numerator: u64, denominator: u64) -> u64 {
    numerator
        .saturating_mul(SCORE_SCALE)
        .saturating_add(denominator / 2)
        / denominator
}

fn deterministic_json_sha256<T: Serialize>(value: &T) -> Result<String, FactorRankError> {
    let bytes = serde_json::to_vec(value)
        .map_err(|error| FactorRankError::Serialization(error.to_string()))?;
    Ok(format!("{:x}", Sha256::digest(bytes)))
}

fn report_content_sha256(report: &FactorResearchRank) -> Result<String, FactorRankError> {
    let mut unsigned = report.clone();
    unsigned.content_sha256.clear();
    deterministic_json_sha256(&unsigned)
}

#[cfg(test)]
mod tests {
    use chrono::TimeZone;
    use serde_json::json;

    use super::*;

    fn time(minute: u32) -> DateTime<Utc> {
        Utc.with_ymd_and_hms(2026, 7, 28, 14, minute, 0)
            .single()
            .expect("valid timestamp")
    }

    fn provenance(cutoff: DateTime<Utc>) -> PointInTimeProvenance {
        PointInTimeProvenance {
            observation_cutoff: cutoff,
            available_at: cutoff + chrono::Duration::seconds(2),
            source: "LICENSED_PIT_FIXTURE".to_string(),
            source_content_sha256: "a".repeat(64),
            entitled_for_research: true,
            complete: true,
            coverage: CoverageEvidence {
                observed_units: 20,
                expected_units: 20,
            },
        }
    }

    fn snapshot(
        symbol: &str,
        cutoff: DateTime<Utc>,
        momentum: f64,
        liquidity: f64,
        price_volume: f64,
    ) -> FactorSnapshot {
        FactorSnapshot {
            symbol: symbol.to_string(),
            snapshot_cutoff: cutoff,
            momentum: PointInTimeFactorValue {
                value: momentum,
                provenance: provenance(cutoff),
            },
            liquidity: LiquidityFactorValue {
                higher_is_more_liquid_value: liquidity,
                provenance: provenance(cutoff),
                evidence: LiquidityEvidence::OhlcvDollarVolumeProxy {
                    aggregation_window: "20_COMPLETED_SESSIONS".to_string(),
                },
            },
            regime_conditioned_price_volume: PointInTimeFactorValue {
                value: price_volume,
                provenance: provenance(cutoff),
            },
        }
    }

    fn request() -> FactorResearchRequest {
        let cutoff = time(30);
        let mut universe_provenance = provenance(cutoff);
        universe_provenance.coverage = CoverageEvidence {
            observed_units: 3,
            expected_units: 3,
        };
        FactorResearchRequest {
            expected_universe: vec!["AAA".to_string(), "BBB".to_string(), "CCC".to_string()],
            universe_provenance,
            snapshots: vec![
                snapshot("CCC", cutoff, 3.0, 1.0, 2.0),
                snapshot("AAA", cutoff, 1.0, 2.0, 1.0),
                snapshot("BBB", cutoff, 2.0, 3.0, 3.0),
            ],
            observation_cutoff: cutoff,
            evaluation_as_of: cutoff + chrono::Duration::seconds(5),
            maximum_age_seconds: 60,
            regime: RegimeEvidence {
                regime_id: "HMM_REGIME_2".to_string(),
                provenance: provenance(cutoff),
            },
            feature_version: "factor-rank-v1".to_string(),
            input_manifest_sha256: "b".repeat(64),
        }
    }

    #[test]
    fn fixed_weights_sum_to_one_hundred_and_are_not_request_configurable() {
        assert_eq!(
            u16::from(MOMENTUM_WEIGHT_PERCENT)
                + u16::from(LIQUIDITY_PROXY_WEIGHT_PERCENT)
                + u16::from(REGIME_CONDITIONED_PRICE_VOLUME_WEIGHT_PERCENT),
            100
        );

        let mut encoded = serde_json::to_value(request()).expect("serialize request");
        encoded
            .as_object_mut()
            .expect("request object")
            .insert("weights".to_string(), json!({"momentum": 100}));
        assert!(serde_json::from_value::<FactorResearchRequest>(encoded).is_err());
    }

    #[test]
    fn rank_is_deterministic_with_symbol_tie_break_and_proxy_disclosure() {
        let mut input = request();
        input.snapshots = vec![
            snapshot("BBB", input.observation_cutoff, 1.0, 1.0, 1.0),
            snapshot("CCC", input.observation_cutoff, 0.0, 0.0, 0.0),
            snapshot("AAA", input.observation_cutoff, 1.0, 1.0, 1.0),
        ];
        let first = build_factor_research_rank(&input).expect("rank");
        input.snapshots.reverse();
        let second = build_factor_research_rank(&input).expect("rank after input reorder");

        assert_eq!(first.content_sha256, second.content_sha256);
        assert_eq!(first.rows[0].symbol, "AAA");
        assert_eq!(first.rows[1].symbol, "BBB");
        assert!(first.rows[0].composite_score_tied);
        assert_eq!(
            first.rows[0].liquidity_input_label,
            "OHLCV_DOLLAR_VOLUME_PROXY"
        );
        assert_eq!(first.output_type, OUTPUT_TYPE);
        assert_eq!(first.candidate_status, CANDIDATE_STATUS);
        assert!(first.execution_disabled);
        assert!(first.production_publication_disabled);
        verify_factor_rank_seal(&first).expect("valid seal");
    }

    #[test]
    fn composite_score_applies_the_fixed_forty_twenty_forty_groups() {
        let report = build_factor_research_rank(&request()).expect("rank");
        let scores = report
            .rows
            .iter()
            .map(|row| (row.symbol.as_str(), row.composite_score_microunits))
            .collect::<BTreeMap<_, _>>();
        assert_eq!(scores["BBB"], 800_000);
        assert_eq!(scores["CCC"], 600_000);
        assert_eq!(scores["AAA"], 100_000);
    }

    #[test]
    fn future_snapshot_mutation_cannot_change_prior_rank_or_seal() {
        let mut input = request();
        let future_cutoff = input.observation_cutoff + chrono::Duration::minutes(1);
        input
            .snapshots
            .push(snapshot("AAA", future_cutoff, 10.0, 10.0, 10.0));
        let first = build_factor_research_rank(&input).expect("rank");

        let future = input.snapshots.last_mut().expect("future row");
        future.momentum.value = -999_999.0;
        future.liquidity.higher_is_more_liquid_value = 999_999.0;
        future.regime_conditioned_price_volume.value = -123_456.0;
        let second = build_factor_research_rank(&input).expect("rank after future mutation");

        assert_eq!(first.selected_input_sha256, second.selected_input_sha256);
        assert_eq!(first.content_sha256, second.content_sha256);
        assert_eq!(
            first
                .rows
                .iter()
                .map(|row| (&row.symbol, row.composite_score_microunits))
                .collect::<Vec<_>>(),
            second
                .rows
                .iter()
                .map(|row| (&row.symbol, row.composite_score_microunits))
                .collect::<Vec<_>>()
        );
    }

    #[test]
    fn fails_closed_for_missing_stale_unentitled_nonfinite_and_future_data() {
        let mut missing = request();
        missing
            .snapshots
            .retain(|snapshot| snapshot.symbol != "CCC");
        assert!(matches!(
            build_factor_research_rank(&missing),
            Err(FactorRankError::IncompleteUniverse(_))
        ));

        let mut stale = request();
        stale.evaluation_as_of = stale.observation_cutoff + chrono::Duration::seconds(61);
        assert!(matches!(
            build_factor_research_rank(&stale),
            Err(FactorRankError::InvalidPointInTime { .. })
        ));

        let mut unentitled = request();
        unentitled.snapshots[0]
            .momentum
            .provenance
            .entitled_for_research = false;
        assert!(matches!(
            build_factor_research_rank(&unentitled),
            Err(FactorRankError::InvalidPointInTime { .. })
        ));

        let mut nonfinite = request();
        nonfinite.snapshots[0].momentum.value = f64::NAN;
        assert!(matches!(
            build_factor_research_rank(&nonfinite),
            Err(FactorRankError::InvalidPointInTime { .. })
        ));

        let mut future_available = request();
        future_available.snapshots[0]
            .liquidity
            .provenance
            .available_at = future_available.evaluation_as_of + chrono::Duration::seconds(1);
        assert!(matches!(
            build_factor_research_rank(&future_available),
            Err(FactorRankError::InvalidPointInTime { .. })
        ));

        let mut incomplete_coverage = request();
        incomplete_coverage.snapshots[0]
            .regime_conditioned_price_volume
            .provenance
            .coverage
            .observed_units = 19;
        assert!(matches!(
            build_factor_research_rank(&incomplete_coverage),
            Err(FactorRankError::InvalidPointInTime { .. })
        ));
    }

    #[test]
    fn quote_label_requires_sealed_quote_evidence_and_seal_detects_tampering() {
        let mut input = request();
        input.snapshots[0].liquidity.evidence = LiquidityEvidence::QuoteSpreadEvidence {
            quote_source: "LICENSED_QUOTES".to_string(),
            quote_source_content_sha256: "c".repeat(64),
        };
        let mut report = build_factor_research_rank(&input).expect("rank");
        let ccc = report
            .rows
            .iter()
            .find(|row| row.symbol == "CCC")
            .expect("CCC row");
        assert_eq!(ccc.liquidity_input_label, "QUOTE_SPREAD_EVIDENCE");

        report.rows[0].rank = 99;
        assert_eq!(
            verify_factor_rank_seal(&report),
            Err(FactorRankError::SealMismatch)
        );

        let mut invalid = input;
        invalid.snapshots[0].liquidity.evidence = LiquidityEvidence::QuoteSpreadEvidence {
            quote_source: "LICENSED_QUOTES".to_string(),
            quote_source_content_sha256: "0".repeat(64),
        };
        assert!(matches!(
            build_factor_research_rank(&invalid),
            Err(FactorRankError::InvalidPointInTime { .. })
        ));
    }

    #[test]
    fn serialized_contract_has_no_trading_or_forecast_fields() {
        let report = build_factor_research_rank(&request()).expect("rank");
        let value = serde_json::to_value(report).expect("serialize report");

        fn visit(value: &serde_json::Value) {
            match value {
                serde_json::Value::Object(map) => {
                    for (key, nested) in map {
                        assert!(
                            ![
                                "probability",
                                "expected_return",
                                "buy",
                                "sell",
                                "target_weight",
                                "order",
                            ]
                            .contains(&key.as_str())
                        );
                        visit(nested);
                    }
                }
                serde_json::Value::Array(values) => {
                    for nested in values {
                        visit(nested);
                    }
                }
                _ => {}
            }
        }
        visit(&value);
    }
}
