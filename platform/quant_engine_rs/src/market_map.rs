//! Causal daily research snapshots. All numerical features are computed here;
//! browser code only renders the exported, validated artifact.
use anyhow::{Context, Result, bail, ensure};
use chrono::{DateTime, Datelike, Duration, Utc};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use std::collections::{HashMap, HashSet};

const VERSION: &str = "market-map-engine-v1";
const TRIALS: usize = 5_000;
const BLOCK: usize = 5;

#[derive(Debug, Clone, Copy, Default, Deserialize)]
pub enum MarketMapHorizon {
    #[serde(rename = "5d")]
    Five,
    #[serde(rename = "10d")]
    Ten,
    #[default]
    #[serde(rename = "20d")]
    Twenty,
    #[serde(rename = "60d")]
    Sixty,
}

/// Compatibility with the existing authenticated Rust research route. A route
/// may shorten an input's supplied exchange calendar, but never invent dates.
pub fn build_market_map(
    input: &MarketMapInput,
    horizon: MarketMapHorizon,
    now: DateTime<Utc>,
) -> Result<Value> {
    let value = match horizon {
        MarketMapHorizon::Five => "5d",
        MarketMapHorizon::Ten => "10d",
        MarketMapHorizon::Twenty => "20d",
        MarketMapHorizon::Sixty => "60d",
    };
    let mut request = input.clone();
    request.horizon = value.into();
    request
        .projected_sessions
        .truncate(horizon_sessions(value)?);
    request.generated_at = now.to_rfc3339();
    build_snapshot(&request)
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Asset {
    pub asset_id: String,
    pub symbol: String,
    pub name: String,
    pub asset_type: String,
    pub exchange: String,
    pub currency: String,
    pub market_timezone: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Bar {
    pub observed_at: String,
    pub open: f64,
    pub high: f64,
    pub low: f64,
    pub close: f64,
    pub volume: f64,
    pub session: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Source {
    pub id: String,
    pub provider: String,
    pub dataset: String,
    pub observed_at: String,
    pub available_at: String,
    pub retrieved_at: String,
    pub delay_minutes: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct IvPoint {
    pub observed_at: String,
    pub percent: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct IvInput {
    pub source_id: String,
    pub tenor_days: u32,
    pub series: Vec<IvPoint>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ValuePoint {
    pub observed_at: String,
    pub value: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SectorInput {
    pub source_id: String,
    pub sector_id: String,
    pub sector_name: String,
    pub benchmark_symbol: String,
    pub series: Vec<ValuePoint>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Trade {
    pub observed_at: String,
    pub price: f64,
    pub volume: f64,
}

/// All timestamps are RFC3339. `projected_sessions` must come from a real
/// exchange calendar. Source rights are checked by the importing orchestrator;
/// the engine also fails closed when its explicit authorization claim is absent.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct MarketMapInput {
    pub asset: Asset,
    pub horizon: String,
    pub bars: Vec<Bar>,
    pub sources: Vec<Source>,
    pub ohlcv_source_id: String,
    pub corporate_actions_source_id: String,
    pub options_iv: IvInput,
    pub sector: SectorInput,
    pub corporate_actions_adjusted: bool,
    pub display_authorized: bool,
    pub generated_at: String,
    pub max_age_seconds: i64,
    pub expected_sessions: usize,
    pub projected_sessions: Vec<String>,
    #[serde(default)]
    pub seed: Option<String>,
    #[serde(default)]
    pub trades: Vec<Trade>,
    #[serde(default)]
    pub trades_source_id: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct PublicBenchmark {
    pub source_id: String,
    pub benchmark_symbol: String,
    pub name: String,
    pub series: Vec<ValuePoint>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct PublicDataRights {
    pub access: String,
    pub terms_url: String,
    pub usage_note: String,
}

/// Public research is a separate contract: it never inherits member entitlements
/// or invents option observations, adjustment status, or a stock-sector identity.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct PublicMarketMapInput {
    pub mode: String,
    pub asset: Asset,
    pub calendar: String,
    pub price_adjustment: String,
    pub horizon: String,
    pub bars: Vec<Bar>,
    pub sources: Vec<Source>,
    pub ohlcv_source_id: String,
    pub benchmark: PublicBenchmark,
    pub rights: PublicDataRights,
    pub generated_at: String,
    pub max_age_seconds: i64,
    pub expected_sessions: usize,
    pub projected_sessions: Vec<String>,
    #[serde(default)]
    pub seed: Option<String>,
}

fn timestamp(value: &str) -> Result<DateTime<Utc>> {
    Ok(DateTime::parse_from_rfc3339(value)
        .context("invalid RFC3339 market timestamp")?
        .with_timezone(&Utc))
}

fn market_date(value: &str) -> Result<chrono::NaiveDate> {
    Ok(timestamp(value)?
        .with_timezone(&chrono_tz::America::New_York)
        .date_naive())
}

fn positive(value: f64) -> bool {
    value.is_finite() && value > 0.0 && value <= 1_000_000_000.0
}

fn valid_id(value: &str) -> bool {
    !value.is_empty()
        && value.len() <= 64
        && (value.as_bytes()[0].is_ascii_lowercase() || value.as_bytes()[0].is_ascii_digit())
        && value
            .bytes()
            .all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b"._:-".contains(&b))
}

fn horizon_sessions(value: &str) -> Result<usize> {
    match value {
        "5d" => Ok(5),
        "10d" => Ok(10),
        "20d" => Ok(20),
        "60d" => Ok(60),
        _ => bail!("unsupported market-map horizon"),
    }
}

fn validate(input: &MarketMapInput) -> Result<()> {
    let horizon = horizon_sessions(&input.horizon)?;
    ensure!(
        (60..=756).contains(&input.bars.len()),
        "60–756 completed daily bars are required"
    );
    ensure!(
        input.expected_sessions == input.bars.len(),
        "incomplete daily session coverage"
    );
    ensure!(
        input.corporate_actions_adjusted,
        "corporate-action-adjusted OHLCV required"
    );
    ensure!(
        input.display_authorized,
        "member research display entitlement required"
    );
    ensure!(
        (1..=604_800).contains(&input.max_age_seconds),
        "invalid freshness policy"
    );
    ensure!(
        uuid::Uuid::parse_str(&input.asset.asset_id).is_ok(),
        "invalid asset UUID"
    );
    ensure!(
        !input.asset.symbol.is_empty()
            && input.asset.symbol.len() <= 32
            && input
                .asset
                .symbol
                .bytes()
                .all(|b| b.is_ascii_uppercase() || b.is_ascii_digit() || b".^/-".contains(&b)),
        "invalid asset symbol"
    );
    ensure!(
        matches!(
            input.asset.asset_type.as_str(),
            "equity" | "etf" | "market_index"
        ),
        "invalid asset type"
    );
    ensure!(
        !input.asset.name.is_empty() && input.asset.name.len() <= 160,
        "invalid asset name"
    );
    ensure!(
        input.asset.currency.len() == 3
            && input.asset.currency.bytes().all(|b| b.is_ascii_uppercase()),
        "invalid currency"
    );
    ensure!(
        !input.asset.exchange.is_empty()
            && input.asset.exchange.len() <= 64
            && !input.asset.market_timezone.is_empty()
            && input.asset.market_timezone.len() <= 64,
        "invalid exchange or market timezone"
    );
    ensure!(
        valid_id(&input.sector.sector_id)
            && !input.sector.sector_id.contains(':')
            && !input.sector.sector_name.is_empty()
            && input.sector.sector_name.len() <= 120,
        "invalid sector identity"
    );
    let now = timestamp(&input.generated_at)?;
    let last = input.bars.last().context("missing bar")?;
    let cutoff = timestamp(&last.observed_at)?;
    ensure!(
        cutoff <= now && now.signed_duration_since(cutoff).num_seconds() <= input.max_age_seconds,
        "latest completed session is future-dated or stale"
    );
    let mut previous = None;
    for bar in &input.bars {
        let time = timestamp(&bar.observed_at)?;
        ensure!(
            previous.is_none_or(|p| time > p),
            "bars must be strictly time ordered"
        );
        ensure!(
            bar.session == "regular",
            "only completed regular sessions are supported"
        );
        ensure!(
            [bar.open, bar.high, bar.low, bar.close]
                .into_iter()
                .all(positive)
                && bar.low <= bar.open
                && bar.open <= bar.high
                && bar.low <= bar.close
                && bar.close <= bar.high,
            "invalid OHLC price geometry"
        );
        ensure!(
            bar.volume.is_finite() && (0.0..=1e18).contains(&bar.volume),
            "invalid observed volume"
        );
        previous = Some(time);
    }
    ensure!(
        (3..=20).contains(&input.sources.len()),
        "at least three identified input sources required"
    );
    let mut source_ids = HashSet::new();
    for source in &input.sources {
        ensure!(
            valid_id(&source.id) && source_ids.insert(source.id.as_str()),
            "source IDs must be valid and unique"
        );
        ensure!(
            !source.provider.is_empty()
                && source.provider.len() <= 120
                && !source.dataset.is_empty()
                && source.dataset.len() <= 160,
            "invalid provider or dataset description"
        );
        let observed = timestamp(&source.observed_at)?;
        let available = timestamp(&source.available_at)?;
        let retrieved = timestamp(&source.retrieved_at)?;
        ensure!(
            observed <= cutoff
                && observed <= available
                && available <= retrieved
                && retrieved <= now,
            "non-causal source availability"
        );
        ensure!(
            now.signed_duration_since(observed).num_seconds() <= input.max_age_seconds,
            "stale input source"
        );
        ensure!(source.delay_minutes <= 10_080, "invalid source delay");
    }
    for source_id in [
        &input.ohlcv_source_id,
        &input.corporate_actions_source_id,
        &input.options_iv.source_id,
        &input.sector.source_id,
    ] {
        ensure!(
            source_ids.contains(source_id.as_str()),
            "input source reference does not resolve"
        );
    }
    ensure!(
        (1..=730).contains(&input.options_iv.tenor_days)
            && (6..=252).contains(&input.options_iv.series.len()),
        "six consistent historical ATM IV observations required"
    );
    ensure!(
        (6..=252).contains(&input.sector.series.len()),
        "six benchmark observations required"
    );
    let bar_times: HashSet<_> = input
        .bars
        .iter()
        .map(|bar| bar.observed_at.as_str())
        .collect();
    let bar_dates: HashMap<_, _> = input
        .bars
        .iter()
        .map(|bar| Ok((market_date(&bar.observed_at)?, timestamp(&bar.observed_at)?)))
        .collect::<Result<_>>()?;
    let mut previous = None;
    let mut iv_dates = HashSet::new();
    for point in &input.options_iv.series {
        let time = timestamp(&point.observed_at)?;
        let date = market_date(&point.observed_at)?;
        ensure!(
            time <= cutoff
                && previous.is_none_or(|p| time > p)
                && bar_dates.get(&date).is_some_and(|close| time <= *close)
                && iv_dates.insert(date),
            "IV must reference completed, ordered asset sessions"
        );
        ensure!(
            point.percent.is_finite() && (0.0..=1_000.0).contains(&point.percent),
            "invalid ATM IV observation"
        );
        previous = Some(time);
    }
    let mut previous = None;
    for point in &input.sector.series {
        let time = timestamp(&point.observed_at)?;
        ensure!(
            positive(point.value)
                && time <= cutoff
                && previous.is_none_or(|p| time > p)
                && bar_times.contains(point.observed_at.as_str()),
            "invalid benchmark observation or session alignment"
        );
        previous = Some(time);
    }
    let last_six = &input.bars[input.bars.len() - 6..];
    for (point, bar) in input.options_iv.series[input.options_iv.series.len() - 6..]
        .iter()
        .zip(last_six)
    {
        ensure!(
            market_date(&point.observed_at)? == market_date(&bar.observed_at)?
                && timestamp(&point.observed_at)? <= timestamp(&bar.observed_at)?,
            "ATM IV must cover the latest six completed sessions without using post-close observations"
        );
    }
    ensure!(
        input.sector.series[input.sector.series.len() - 6..]
            .iter()
            .zip(last_six)
            .all(|(point, bar)| point.observed_at == bar.observed_at),
        "benchmark must cover the latest six completed sessions"
    );
    for source_id in [&input.ohlcv_source_id, &input.sector.source_id] {
        let source = input
            .sources
            .iter()
            .find(|source| &source.id == source_id)
            .context("missing source")?;
        ensure!(
            timestamp(&source.observed_at)? == cutoff,
            "source observation cutoff must match latest completed session"
        );
    }
    let iv_source = input
        .sources
        .iter()
        .find(|source| source.id == input.options_iv.source_id)
        .context("missing IV source")?;
    ensure!(
        timestamp(&iv_source.observed_at)?
            == timestamp(&input.options_iv.series[input.options_iv.series.len() - 1].observed_at)?,
        "IV source observation timestamp must match its latest actual observation"
    );
    ensure!(
        input.projected_sessions.len() == horizon,
        "exchange calendar must cover the entire requested horizon"
    );
    let mut previous = cutoff;
    for session in &input.projected_sessions {
        let time = timestamp(session)?;
        ensure!(
            time > previous && time.weekday().number_from_monday() <= 5,
            "invalid projected exchange session"
        );
        previous = time;
    }
    if !input.trades.is_empty() {
        let source_id = input
            .trades_source_id
            .as_ref()
            .context("trade source required for observed volume profile")?;
        ensure!(
            source_ids.contains(source_id.as_str()),
            "trade source does not resolve"
        );
        let start = timestamp(&input.bars[0].observed_at)? - Duration::days(1);
        for trade in &input.trades {
            let time = timestamp(&trade.observed_at)?;
            ensure!(
                time >= start
                    && time <= cutoff
                    && positive(trade.price)
                    && trade.volume.is_finite()
                    && (0.0..=1e18).contains(&trade.volume),
                "invalid observed trade"
            );
        }
    }
    Ok(())
}

fn average(values: &[f64]) -> f64 {
    values.iter().sum::<f64>() / values.len() as f64
}

fn quantile(sorted: &[f64], probability: f64) -> f64 {
    let location = probability * (sorted.len() - 1) as f64;
    let low = location.floor() as usize;
    let high = location.ceil() as usize;
    sorted[low] + (sorted[high] - sorted[low]) * (location - low as f64)
}

fn rsi(gain: f64, loss: f64) -> f64 {
    if gain == 0.0 && loss == 0.0 {
        50.0
    } else if loss == 0.0 {
        100.0
    } else {
        100.0 - 100.0 / (1.0 + gain / loss)
    }
}

struct Features {
    serialized: Value,
    sma: f64,
    lower: f64,
    upper: f64,
    rsi: f64,
    atr: f64,
    velocity: f64,
    acceleration: f64,
    momentum_state: &'static str,
}

fn features(bars: &[Bar]) -> Result<Features> {
    let closes: Vec<_> = bars.iter().map(|bar| bar.close).collect();
    let mut sma = Vec::new();
    let mut bands = Vec::new();
    let mut rsi_points = Vec::new();
    let mut atr_points = Vec::new();
    let mut momentum = Vec::new();
    let mut rocs = Vec::new();
    let mut gain = 0.0;
    let mut loss = 0.0;
    let mut atr = 0.0;
    let mut velocity = 0.0;
    let mut acceleration = 0.0;
    for (index, bar) in bars.iter().enumerate() {
        if index >= 19 {
            let window = &closes[index - 19..=index];
            let middle = average(window);
            let deviation = (window
                .iter()
                .map(|close| (close - middle).powi(2))
                .sum::<f64>()
                / 20.0)
                .sqrt();
            ensure!(
                positive(middle - 2.0 * deviation),
                "Bollinger lower band is outside supported positive-price domain"
            );
            sma.push(json!({"observed_at":bar.observed_at,"price":middle}));
            bands.push(json!({"observed_at":bar.observed_at,"lower":middle - 2.0 * deviation,"middle":middle,"upper":middle + 2.0 * deviation}));
        }
        if index > 0 {
            let change = bar.close - closes[index - 1];
            let current_gain = change.max(0.0);
            let current_loss = (-change).max(0.0);
            let true_range = (bar.high - bar.low)
                .max((bar.high - closes[index - 1]).abs())
                .max((bar.low - closes[index - 1]).abs());
            if index <= 14 {
                gain += current_gain / 14.0;
                loss += current_loss / 14.0;
                atr += true_range / 14.0;
            } else {
                gain = (gain * 13.0 + current_gain) / 14.0;
                loss = (loss * 13.0 + current_loss) / 14.0;
                atr = (atr * 13.0 + true_range) / 14.0;
            }
            if index >= 14 {
                rsi_points.push(json!({"observed_at":bar.observed_at,"value":rsi(gain,loss)}));
                atr_points.push(json!({"observed_at":bar.observed_at,"value":atr}));
            }
            let next_velocity = (bar.close / closes[index - 1]).ln() * 100.0;
            acceleration = next_velocity - velocity;
            velocity = next_velocity;
        }
        if index >= 5 {
            let roc = (bar.close / closes[index - 5] - 1.0) * 100.0;
            rocs.push(roc);
            if rocs.len() >= 5 {
                momentum.push(json!({"observed_at":bar.observed_at,"value":roc,"signal":average(&rocs[rocs.len()-5..]),"velocity_percent_per_session":velocity,"acceleration_percent_per_session_squared":acceleration}));
            }
        }
    }
    let roc = *rocs.last().context("momentum history missing")?;
    let state = if roc < -3.0 && velocity < -0.5 && acceleration < 0.0 {
        "knife"
    } else if roc > 3.0 && velocity > 0.5 && acceleration > 0.0 {
        "spike"
    } else if roc < -0.5 {
        "falling"
    } else if roc > 0.5 {
        "rising"
    } else {
        "flat"
    };
    let latest_sma = sma.last().context("SMA history missing")?["price"]
        .as_f64()
        .context("invalid SMA")?;
    let latest_band = bands.last().context("band history missing")?;
    let lower = latest_band["lower"].as_f64().context("invalid band")?;
    let upper = latest_band["upper"].as_f64().context("invalid band")?;
    Ok(Features {
        sma: latest_sma,
        lower,
        upper,
        rsi: rsi(gain, loss),
        atr,
        velocity,
        acceleration,
        momentum_state: state,
        serialized: json!({
            "sma20":{"period_sessions":20,"points":sma},
            "bollinger20":{"period_sessions":20,"standard_deviations":2.0,"points":bands},
            "rsi14":{"period_sessions":14,"latest":rsi(gain,loss),"points":rsi_points},
            "atr14":{"period_sessions":14,"latest":atr,"points":atr_points},
            "momentum":{"lookback_sessions":5,"signal_sessions":5,"state":state,"points":momentum}
        }),
    })
}

fn zigzag(bars: &[Bar]) -> Value {
    let threshold = 0.03;
    let mut direction = 0_i8;
    let mut extreme = 0_usize;
    let mut pivots = Vec::new();
    for index in 1..bars.len() {
        let current = bars[index].close;
        let candidate = bars[extreme].close;
        let mut confirmed = None;
        if direction == 0 {
            if current >= candidate * (1.0 + threshold) {
                confirmed = Some("low");
                direction = 1;
            } else if current <= candidate * (1.0 - threshold) {
                confirmed = Some("high");
                direction = -1;
            }
        } else if direction == 1 {
            if current >= candidate {
                extreme = index;
            } else if current <= candidate * (1.0 - threshold) {
                confirmed = Some("high");
                direction = -1;
            }
        } else if current <= candidate {
            extreme = index;
        } else if current >= candidate * (1.0 + threshold) {
            confirmed = Some("low");
            direction = 1;
        }
        if let Some(kind) = confirmed {
            pivots.push(json!({"id":format!("pivot-{extreme}"),"observed_at":bars[extreme].observed_at,"confirmed_at":bars[index].observed_at,"price":bars[extreme].close,"kind":kind,"confirmed":true}));
            extreme = index;
        }
    }
    let latest = &bars[bars.len() - 1];
    let provisional = pivots.last().map(|pivot| json!({
        "from_observed_at":pivot["observed_at"],"from_price":pivot["price"],
        "to_observed_at":latest.observed_at,"to_price":latest.close,
        "direction":if latest.close >= pivot["price"].as_f64().unwrap_or(latest.close) {"up"} else {"down"},"confirmed":false
    }));
    let skip = pivots.len().saturating_sub(100);
    json!({"reversal_threshold_percent":3.0,"confirmed_pivots":&pivots[skip..],"provisional_leg":provisional})
}

/// SplitMix64: explicit algorithm and seed make exports reproducible across hosts.
struct Random(u64);
impl Random {
    fn next(&mut self) -> u64 {
        self.0 = self.0.wrapping_add(0x9e3779b97f4a7c15);
        let mut value = self.0;
        value = (value ^ (value >> 30)).wrapping_mul(0xbf58476d1ce4e5b9);
        value = (value ^ (value >> 27)).wrapping_mul(0x94d049bb133111eb);
        value ^ (value >> 31)
    }
    fn index(&mut self, size: usize) -> usize {
        let bound = size as u64;
        let threshold = bound.wrapping_neg() % bound;
        loop {
            let value = self.next();
            if value >= threshold {
                return (value % bound) as usize;
            }
        }
    }
}

fn digest(bytes: &[u8]) -> String {
    format!("{:x}", Sha256::digest(bytes))
}

fn point(offset: usize, price: f64, times: &[String]) -> Value {
    json!({"session_offset":offset,"projected_at":times[offset],"price":price})
}

fn simulation(input: &MarketMapInput, input_hash: &str) -> Result<(Value, Value)> {
    simulate(
        &input.bars,
        &input.horizon,
        &input.projected_sessions,
        input.seed.as_deref(),
        input_hash,
    )
}

fn simulate(
    bars: &[Bar],
    requested_horizon: &str,
    projected_sessions: &[String],
    requested_seed: Option<&str>,
    input_hash: &str,
) -> Result<(Value, Value)> {
    let last = &bars[bars.len() - 1];
    let horizon = horizon_sessions(requested_horizon)?;
    let returns: Vec<_> = bars
        .windows(2)
        .map(|pair| (pair[1].close / pair[0].close).ln())
        .collect();
    let seed = digest(
        format!(
            "{VERSION}:{input_hash}:{}",
            requested_seed.unwrap_or("default")
        )
        .as_bytes(),
    );
    let seed_number = u64::from_str_radix(&seed[..16], 16)?;
    let mut random = Random(seed_number);
    let mut paths = Vec::with_capacity(TRIALS);
    let mut times = vec![last.observed_at.clone()];
    times.extend_from_slice(projected_sessions);
    for _ in 0..TRIALS {
        let mut path = vec![last.close];
        while path.len() <= horizon {
            let start = random.index(returns.len() - BLOCK + 1);
            for change in &returns[start..start + BLOCK] {
                if path.len() > horizon {
                    break;
                }
                let price = path[path.len() - 1] * change.exp();
                ensure!(
                    positive(price),
                    "simulated path exceeds supported price domain"
                );
                path.push(price);
            }
        }
        paths.push(path);
    }
    let mut order: Vec<_> = (0..TRIALS).collect();
    order.sort_by(|a, b| {
        paths[*a][horizon]
            .total_cmp(&paths[*b][horizon])
            .then(a.cmp(b))
    });
    let terminal: Vec<_> = order.iter().map(|index| paths[*index][horizon]).collect();
    let sampled_paths: Vec<_> = (0..24).map(|rank| {
        let index = order[rank * (TRIALS-1) / 23];
        json!({"sample_id":index,"points":paths[index].iter().enumerate().map(|(offset,price)|point(offset,*price,&times)).collect::<Vec<_>>()})
    }).collect();
    let particles: Vec<_> = (0..512).map(|rank| {
        let index = order[rank * (TRIALS-1) / 511];
        json!({"sample_id":index,"terminal_price":paths[index][horizon],"terminal_return_percent":(paths[index][horizon]/last.close-1.0)*100.0})
    }).collect();
    let lower = terminal[0];
    let upper = terminal[TRIALS - 1];
    let padding = ((upper - lower) * 1e-9).max(last.close * 1e-10);
    let lower = (lower - padding).max(f64::MIN_POSITIVE);
    let upper = upper + padding;
    let edges: Vec<_> = (0..=32)
        .map(|index| lower + (upper - lower) * index as f64 / 32.0)
        .collect();
    let mut counts = [0_usize; 32];
    for value in &terminal {
        let index = (((value - lower) / (upper - lower) * 32.0).floor() as usize).min(31);
        counts[index] += 1;
    }
    let density:Vec<_>=(0..32).map(|index|json!({"lower_price":edges[index],"upper_price":edges[index+1],"sample_count":counts[index],"probability_mass":counts[index] as f64/TRIALS as f64,"density":counts[index] as f64/TRIALS as f64/(edges[index+1]-edges[index])})).collect();
    let mut curves = [Vec::new(), Vec::new(), Vec::new()];
    for offset in 0..=horizon {
        let mut values: Vec<_> = paths.iter().map(|path| path[offset]).collect();
        values.sort_by(f64::total_cmp);
        for (curve, probability) in curves.iter_mut().zip([0.75, 0.50, 0.25]) {
            curve.push(point(offset, quantile(&values, probability), &times));
        }
    }
    let scenarios:Vec<_>=curves.into_iter().zip([("bull","Upper quartile","75th"),("base","Median path","50th"),("bear","Lower quartile","25th")]).map(|(points,(kind,label,percentile))|json!({"id":format!("scenario-{kind}"),"kind":kind,"label":label,"interpretation":format!("{percentile} percentile at each session across uncalibrated historical bootstrap trials. These pointwise quantiles need not form one realized trial; they are not forecasts."),"is_forecast":false,"points":points,"evidence_refs":["simulation-distribution"]})).collect();
    Ok((
        json!({
            "as_of":last.observed_at,"horizon_sessions":horizon,"trial_count":TRIALS,"input_sha256":input_hash,"seed_sha256":seed,"model":"historical_block_bootstrap","calibration_status":"uncalibrated","sample_window_sessions":bars.len(),"block_length_sessions":BLOCK,"return_basis":"log_close_to_close","path_sampling_method":"deterministic_stratified","sampled_paths":sampled_paths,"terminal_particles":particles,"terminal_density":density,
            "terminal_quantiles":{"p01":quantile(&terminal,0.01),"p05":quantile(&terminal,0.05),"p25":quantile(&terminal,0.25),"p50":quantile(&terminal,0.50),"p75":quantile(&terminal,0.75),"p95":quantile(&terminal,0.95),"p99":quantile(&terminal,0.99)},
            "assumptions":[format!("Resample overlapping {BLOCK}-session blocks with replacement from {} observed log returns; preserve within-block ordering.",returns.len()),"Historical return distribution is assumed locally reusable; structural breaks and unseen jumps are not modeled.","No volatility scaling from option IV, option valuation, transaction costs, dividends during projection, or directional probability calibration.","SplitMix64 deterministic seed; displayed paths and particles are stratified by terminal rank and retain their originating trial IDs.","Projection dates are supplied by the caller's exchange calendar; pointwise quantile curves are illustrative conditional scenarios."],
            "evidence_refs":["bars-window"],"interpretation":"uncalibrated_simulation_not_forecast"
        }),
        Value::Array(scenarios),
    ))
}

fn observed_volume_profile(input: &MarketMapInput) -> Result<Value> {
    let min = input
        .trades
        .iter()
        .map(|trade| trade.price)
        .fold(f64::INFINITY, f64::min);
    let max = input
        .trades
        .iter()
        .map(|trade| trade.price)
        .fold(f64::NEG_INFINITY, f64::max);
    let padding = ((max - min) * 1e-9).max(min * 1e-8);
    let min = (min - padding).max(f64::MIN_POSITIVE);
    let max = max + padding;
    let edges: Vec<_> = (0..=24)
        .map(|index| min + (max - min) * index as f64 / 24.0)
        .collect();
    let mut volumes = [0.0_f64; 24];
    let mut recent = [0.0_f64; 24];
    let recent_start =
        timestamp(&input.bars[input.bars.len() - 5].observed_at)? - Duration::days(1);
    for trade in &input.trades {
        let index = (((trade.price - min) / (max - min) * 24.0).floor() as usize).min(23);
        volumes[index] += trade.volume;
        if timestamp(&trade.observed_at)? >= recent_start {
            recent[index] += trade.volume;
        }
    }
    let last = input.bars[input.bars.len() - 1].close;
    let poc = (0..24)
        .max_by(|a, b| volumes[*a].total_cmp(&volumes[*b]))
        .context("profile has no bins")?;
    let bins:Vec<_>=(0..24).map(|index|json!({"lower_price":edges[index],"upper_price":edges[index+1],"volume":volumes[index],"recent_volume":recent[index],"side":if edges[index]>last {"supply"} else if edges[index+1]<last {"demand"} else {"at_last"}})).collect();
    Ok(
        json!({"method":"observed_trade_volume","source_id":input.trades_source_id,"bins":bins,"point_of_control_price":(edges[poc]+edges[poc+1])/2.0}),
    )
}

struct PriceLevels {
    support: f64,
    resistance: f64,
    stretch: f64,
    down: f64,
    state: &'static str,
    serialized: Vec<Value>,
}

fn price_levels(bars: &[Bar], f: &Features, zigzag: &Value) -> Result<PriceLevels> {
    let last = &bars[bars.len() - 1];
    let pivot_prices: Vec<_> = zigzag["confirmed_pivots"]
        .as_array()
        .context("missing pivots")?
        .iter()
        .filter_map(|pivot| pivot["price"].as_f64())
        .collect();
    let support = pivot_prices
        .iter()
        .copied()
        .filter(|price| *price < last.close)
        .max_by(f64::total_cmp)
        .unwrap_or_else(|| {
            bars[bars.len() - 20..]
                .iter()
                .map(|bar| bar.low)
                .fold(last.close, f64::min)
        });
    let resistance = pivot_prices
        .iter()
        .copied()
        .filter(|price| *price > last.close)
        .min_by(f64::total_cmp)
        .unwrap_or_else(|| {
            bars[bars.len() - 20..]
                .iter()
                .map(|bar| bar.high)
                .fold(last.close, f64::max)
        });
    let stretch = f.upper.max(resistance + f.atr);
    let down = f.lower.min((support - f.atr).max(last.close * 0.001));
    let state = if last.close > f.sma && f.rsi > 55.0 {
        "bull"
    } else if last.close < f.sma && f.rsi < 45.0 {
        "bear"
    } else {
        "neutral"
    };
    let levels:Vec<_>=[("stretch","STRETCH",stretch,"Maximum of upper Bollinger band and resistance plus Wilder ATR14"), ("resistance","RESISTANCE",resistance,"Nearest confirmed close pivot above last; otherwise trailing 20-session high"),("last","LAST",last.close,"Latest completed daily close"),("sma20","SMA 20",f.sma,"Arithmetic mean of the latest 20 completed closes"),("support","SUPPORT",support,"Nearest confirmed close pivot below last; otherwise trailing 20-session low"),("down","DOWN",down,"Minimum of lower Bollinger band and support minus ATR14, with positive-price floor")].into_iter().map(|(role,label,price,method)|json!({"id":format!("level-{role}"),"role":role,"label":label,"price":price,"distance_from_last_percent":(price/last.close-1.0)*100.0,"method":method,"evidence_refs":["bars-window","indicator-bands","indicator-atr"]})).collect();
    Ok(PriceLevels {
        support,
        resistance,
        stretch,
        down,
        state,
        serialized: levels,
    })
}

fn volume_panel(bars: &[Bar]) -> Result<(Value, f64)> {
    let last = &bars[bars.len() - 1];
    let avg_volume = bars[bars.len() - 20..]
        .iter()
        .map(|bar| bar.volume)
        .sum::<f64>()
        / 20.0;
    ensure!(avg_volume > 0.0, "insufficient nonzero volume observations");
    let relative_volume = last.volume / avg_volume;
    let volume = json!({"latest_volume":last.volume,"average_volume":avg_volume,"average_window_sessions":20,"relative_volume":relative_volume,"series":bars[bars.len().saturating_sub(252)..].iter().map(|bar|json!({"observed_at":bar.observed_at,"volume":bar.volume})).collect::<Vec<_>>(),"evidence_refs":["observed-volume"]});
    Ok((volume, relative_volume))
}

/// Build a fully populated strict `market-map-snapshot-v1` artifact. There is no
/// fallback path: missing IV, stale observations, or incomplete inputs return Err.
pub fn build_snapshot(input: &MarketMapInput) -> Result<Value> {
    validate(input)?;
    let input_hash = digest(&serde_json::to_vec(input)?);
    let bars = &input.bars;
    let last = &bars[bars.len() - 1];
    let f = features(bars)?;
    let zigzag = zigzag(bars);
    let (simulation, scenarios) = simulation(input, &input_hash)?;
    let PriceLevels {
        support,
        resistance,
        stretch,
        down,
        state,
        serialized: levels,
    } = price_levels(bars, &f, &zigzag)?;
    let (mut volume, relative_volume) = volume_panel(bars)?;
    if !input.trades.is_empty() {
        volume["volume_at_price"] = observed_volume_profile(input)?;
    }
    let iv = &input.options_iv;
    let iv_last = &iv.series[iv.series.len() - 1];
    let iv_change = iv_last.percent - iv.series[iv.series.len() - 6].percent;
    let sector = &input.sector;
    let sector_last = &sector.series[sector.series.len() - 1];
    let sector_return =
        (sector_last.value / sector.series[sector.series.len() - 6].value - 1.0) * 100.0;
    let asset_return = (last.close / bars[bars.len() - 6].close - 1.0) * 100.0;
    let relative_return = asset_return - sector_return;
    let sector_state = if sector_return < -0.5 {
        "defensive"
    } else if sector_return > 0.5 {
        "offensive"
    } else {
        "neutral"
    };
    let mut evidence = Vec::new();
    for (id, kind, label, path, source) in [
        (
            "bars-window",
            "bar",
            "Completed adjusted OHLCV window",
            "bars",
            &input.ohlcv_source_id,
        ),
        (
            "indicator-sma",
            "indicator",
            "20-session simple moving average",
            "technical_indicators.sma20",
            &input.ohlcv_source_id,
        ),
        (
            "indicator-bands",
            "indicator",
            "20-session population-standard-deviation Bollinger bands",
            "technical_indicators.bollinger20",
            &input.ohlcv_source_id,
        ),
        (
            "indicator-rsi",
            "indicator",
            "Wilder RSI14",
            "technical_indicators.rsi14",
            &input.ohlcv_source_id,
        ),
        (
            "indicator-atr",
            "indicator",
            "Wilder ATR14",
            "technical_indicators.atr14",
            &input.ohlcv_source_id,
        ),
        (
            "indicator-momentum",
            "indicator",
            "Five-session rate of change; daily log-return velocity",
            "technical_indicators.momentum",
            &input.ohlcv_source_id,
        ),
        (
            "confirmed-pivots",
            "pivot",
            "Causally confirmed close-price reversal pivots",
            "zigzag.confirmed_pivots",
            &input.ohlcv_source_id,
        ),
        (
            "price-levels",
            "level",
            "Mechanical research reference levels",
            "levels",
            &input.ohlcv_source_id,
        ),
        (
            "simulation-distribution",
            "simulation",
            "Uncalibrated historical block-bootstrap distribution",
            "monte_carlo",
            &input.ohlcv_source_id,
        ),
        (
            "observed-volume",
            "volume",
            "Observed daily volume and trailing 20-session average",
            "panels.volume",
            &input.ohlcv_source_id,
        ),
        (
            "observed-atm-iv",
            "options",
            "Same-tenor historical ATM implied volatility",
            "panels.implied_volatility",
            &iv.source_id,
        ),
        (
            "sector-benchmark",
            "sector",
            "Observed five-session benchmark comparison",
            "panels.sector",
            &sector.source_id,
        ),
    ] {
        evidence.push(json!({"id":id,"kind":kind,"label":label,"source_id":source,"observed_at":if kind == "options" { &iv_last.observed_at } else { &last.observed_at },"field_path":path}));
    }
    let mut caveats=vec![
        "Research conditions are impersonal observations, not personalized advice, executable arbitrage, or a finding of fair value.".to_string(),
        "Monte Carlo trials and pointwise quantile curves are uncalibrated conditional simulations, not forecasts or validated event probabilities.".to_string(),
        "The last price is a completed daily close. Daily/EOD research freshness is independent of screen animation or browser refresh.".to_string(),
        "KNIFE/SPIKE are custom five-session momentum states: |ROC| > 3%, same-direction daily velocity > 0.5%, and same-direction acceleration. Other rising/falling states use ±0.5% ROC.".to_string(),
        "ZigZag uses a 3% close-price reversal. A pivot is available only at confirmed_at; the final leg remains provisional.".to_string(),
        "Sector defensive/offensive labels mean benchmark five-session return below −0.5% or above +0.5%; they do not infer institutional flow.".to_string(),
    ];
    if input.trades.is_empty() {
        caveats.push("No observed trade-level volume profile is available. The map shows actual daily volume; Monte Carlo terminal density is a separate simulated quantity.".to_string());
    }
    let trend_position = if last.close >= f.sma {
        "above"
    } else {
        "below"
    };
    let read_title = match (state, f.momentum_state) {
        ("bear", "knife") => "Price is below trend, and downside momentum is accelerating",
        ("bear", _) => "Price is below trend; the lower reference range matters",
        ("bull", "spike") => "Price is above trend, and upside momentum is accelerating",
        ("bull", _) => "Price is above trend; watch the upper reference range",
        (_, "falling" | "knife") => "The trend is mixed, with momentum pointing lower",
        (_, "rising" | "spike") => "The trend is mixed, with momentum pointing higher",
        _ => "Price and momentum are near their recent balance",
    };
    let momentum_description = if f.velocity < 0.0 && f.acceleration < 0.0 {
        "The latest session's decline accelerated"
    } else if f.velocity < 0.0 {
        "The latest session declined, with downside momentum easing"
    } else if f.velocity > 0.0 && f.acceleration > 0.0 {
        "The latest session's advance accelerated"
    } else if f.velocity > 0.0 {
        "The latest session advanced, with upside momentum easing"
    } else {
        "The latest close was unchanged"
    };
    let read_items = vec![
        json!({"id":"read-range","kind":"range","text":format!("The close is {:.2}, between support {:.2} and resistance {:.2}. A future completed close above {:.2} would leave this range on the upside; below {:.2} would leave it on the downside. The outer stretch/down references are {:.2} and {:.2}.",last.close,support,resistance,resistance,support,stretch,down),"evidence_refs":["price-levels","indicator-bands","indicator-atr"]}),
        json!({"id":"read-trend","kind":"trend","text":format!("Price is {:.2}% {trend_position} its 20-session average ({:.2}). RSI14 is {:.1}, {}.",((last.close/f.sma-1.0)*100.0).abs(),f.sma,f.rsi,if f.rsi < 30.0 { "below the commonly watched 30 threshold" } else if f.rsi > 70.0 { "above the commonly watched 70 threshold" } else if f.rsi < 50.0 { "with recent losses outweighing gains" } else { "with recent gains at least matching losses" }),"evidence_refs":["indicator-sma","indicator-rsi"]}),
        json!({"id":"read-momentum","kind":"momentum","text":format!("{momentum_description}. Daily log-return velocity is {:+.2}%, changing {:+.2} percentage points from the prior session. The five-session momentum state is {}.",f.velocity,f.acceleration,f.momentum_state.to_uppercase()),"evidence_refs":["indicator-momentum","confirmed-pivots"]}),
        json!({"id":"read-volatility","kind":"volatility","text":format!("{}-day ATM implied volatility is {:.2}%, {} {:.2} percentage points over five sessions. Compare this change with the observed price move and volume.",iv.tenor_days,iv_last.percent,if iv_change >= 0.0 {"up"} else {"down"},iv_change.abs()),"evidence_refs":["observed-atm-iv","bars-window","observed-volume"]}),
        json!({"id":"read-volume","kind":"volume","text":format!("Latest volume is {:.2} times its 20-session average: activity is {} the recent baseline.",relative_volume,if relative_volume >= 1.0 {"at or above"} else {"below"}),"evidence_refs":["observed-volume"]}),
        json!({"id":"read-sector","kind":"sector","text":format!("{} ({}) returned {:+.2}% over five sessions; {} returned {:+.2}%, a difference of {:+.2} percentage points. Benchmark state: {sector_state}.",sector.sector_name,sector.benchmark_symbol,sector_return,input.asset.symbol,asset_return,relative_return),"evidence_refs":["sector-benchmark","bars-window"]}),
        json!({"id":"read-simulation","kind":"simulation","text":format!("Across {TRIALS} trials built from historical {BLOCK}-session return blocks, the median terminal price is {:.2}. The middle half of simulated endpoints lies between {:.2} and {:.2}; the particle cloud shows their distribution.",simulation["terminal_quantiles"]["p50"].as_f64().unwrap_or(last.close),simulation["terminal_quantiles"]["p25"].as_f64().unwrap_or(last.close),simulation["terminal_quantiles"]["p75"].as_f64().unwrap_or(last.close)),"evidence_refs":["simulation-distribution"]}),
        json!({"id":"read-limitation","kind":"limitation","text":"The reference paths reuse historical return blocks. They are independent of whether price later crosses support or resistance, and current option IV does not change these paths. Investigating a pricing discrepancy next requires an instrument-specific valuation and execution-cost comparison.","evidence_refs":["price-levels","observed-atm-iv","simulation-distribution"]}),
    ];
    let available = input
        .sources
        .iter()
        .map(|source| timestamp(&source.available_at))
        .collect::<Result<Vec<_>>>()?
        .into_iter()
        .max()
        .context("missing availability")?;
    let cutoff = timestamp(&last.observed_at)?;
    let required: Vec<_> = [
        "ohlcv",
        "corporate_actions",
        "options_iv",
        "sector_benchmark",
        "simulation_artifact",
    ]
    .into_iter()
    .map(|name| json!({"name":name,"state":"available","observed_at":if name == "options_iv" { &iv_last.observed_at } else { &last.observed_at }}))
    .collect();
    // Stable UUID generated from the complete input content rather than wall time.
    let mut id_bytes: [u8; 16] = Sha256::digest(input_hash.as_bytes())[..16].try_into()?;
    id_bytes[6] = (id_bytes[6] & 0x0f) | 0x40;
    id_bytes[8] = (id_bytes[8] & 0x3f) | 0x80;
    Ok(json!({
        "snapshot_id":uuid::Uuid::from_bytes(id_bytes).to_string(),"asset":input.asset,"horizon":input.horizon,"timeframe":"1d","state":state,"last_price":last.close,"bars":bars,
        "technical_indicators":f.serialized,"zigzag":zigzag,"levels":levels,"scenarios":scenarios,"monte_carlo":simulation,
        "panels":{"volume":volume,"implied_volatility":{"source_observed_at":iv_last.observed_at,"tenor_days":iv.tenor_days,"moneyness":"atm","current_percent":iv_last.percent,"change_5d_percentage_points":iv_change,"series":iv.series,"evidence_refs":["observed-atm-iv"]},"sector":{"sector_id":sector.sector_id,"sector_name":sector.sector_name,"benchmark_symbol":sector.benchmark_symbol,"return_5d_percent":sector_return,"asset_relative_5d_percent":relative_return,"state":sector_state,"series":sector.series,"evidence_refs":["sector-benchmark"]}},
        "evidence":evidence,"read":{"as_of":last.observed_at,"language":"en","title":read_title,"summary":format!("The latest close sits {trend_position} the 20-session average, with {} five-session momentum. The nearby price levels, volatility, volume and sector comparison put this move in context.",f.momentum_state),"items":read_items,"disclosure":"Impersonal market research only. Daily observations and historical simulation are not investment advice, forecasts, fair-value estimates, or evidence of risk-free arbitrage. Every statement is linked to this snapshot's observed inputs or deterministic engine outputs."},
        "provenance":{"sources":input.sources,"observation_cutoff":last.observed_at,"available_at":available.to_rfc3339(),"generated_at":input.generated_at,"freshness":{"state":"fresh","max_age_seconds":input.max_age_seconds,"expires_at":(cutoff+Duration::seconds(input.max_age_seconds)).to_rfc3339()},"coverage":{"state":"complete","completeness_ratio":1.0,"start_at":bars[0].observed_at,"end_at":last.observed_at,"expected_sessions":input.expected_sessions,"observed_sessions":bars.len(),"required_inputs":required,"regular_session_only":true,"corporate_actions_adjusted":input.corporate_actions_adjusted},"rights":{"entitlement":"member_research","display_authorized":input.display_authorized,"redistribution_authorized":false},"versions":{"schema":"market-map-snapshot-v1","market_data":"caller-attested-adjusted-daily-v1","features":VERSION,"monte_carlo_model":"historical-block-bootstrap-5x5000-v1","methodology":"daily-technical-research-v1"},"caveats":caveats}
    }))
}

fn validate_public(input: &PublicMarketMapInput) -> Result<()> {
    ensure!(
        input.mode == "public_market",
        "explicit public_market mode required"
    );
    ensure!(
        matches!(input.calendar.as_str(), "continuous" | "exchange"),
        "unsupported public market calendar"
    );
    ensure!(
        matches!(
            input.price_adjustment.as_str(),
            "unadjusted"
                | "split_adjusted"
                | "split_dividend_adjusted"
                | "source_adjusted_unverified"
        ),
        "explicit price adjustment method required"
    );
    ensure!(
        matches!(
            input.asset.asset_type.as_str(),
            "crypto" | "equity" | "etf" | "market_index"
        ),
        "unsupported public asset type"
    );
    ensure!(
        uuid::Uuid::parse_str(&input.asset.asset_id).is_ok(),
        "invalid public asset UUID"
    );
    ensure!(
        !input.asset.symbol.is_empty()
            && input.asset.symbol != "DEMO"
            && input.asset.symbol.len() <= 32
            && input
                .asset
                .symbol
                .bytes()
                .all(|b| b.is_ascii_uppercase() || b.is_ascii_digit() || b".^/-".contains(&b)),
        "invalid public asset symbol"
    );
    ensure!(
        !input.asset.name.is_empty()
            && input.asset.name.len() <= 160
            && !input.asset.exchange.is_empty(),
        "real asset identity required"
    );
    ensure!(
        input.asset.currency.len() == 3
            && input.asset.currency.bytes().all(|b| b.is_ascii_uppercase()),
        "invalid public currency"
    );
    let zone: chrono_tz::Tz = input
        .asset
        .market_timezone
        .parse()
        .context("invalid public market timezone")?;
    if input.calendar == "continuous" {
        ensure!(
            input.asset.market_timezone == "UTC",
            "continuous daily candles must declare UTC"
        );
    }
    ensure!(
        (60..=756).contains(&input.bars.len()) && input.expected_sessions == input.bars.len(),
        "public OHLCV coverage must contain all expected sessions (60–756)"
    );
    ensure!(
        (1..=604_800).contains(&input.max_age_seconds),
        "invalid public freshness budget"
    );
    let now = timestamp(&input.generated_at)?;
    let cutoff = timestamp(&input.bars[input.bars.len() - 1].observed_at)?;
    ensure!(
        cutoff <= now && now.signed_duration_since(cutoff).num_seconds() < input.max_age_seconds,
        "public observation is future-dated or stale"
    );
    let mut previous: Option<DateTime<Utc>> = None;
    let mut dates = HashSet::new();
    for bar in &input.bars {
        let time = timestamp(&bar.observed_at)?;
        ensure!(
            previous.is_none_or(|prev| time > prev)
                && dates.insert(time.with_timezone(&zone).date_naive()),
            "duplicate or unordered public sessions"
        );
        if input.calendar == "continuous" {
            ensure!(
                bar.session == "continuous"
                    && time.time() == chrono::NaiveTime::MIN
                    && previous.is_none_or(|prev| time - prev == Duration::days(1)),
                "continuous bars must cover consecutive completed UTC days"
            );
        } else {
            ensure!(
                matches!(bar.session.as_str(), "regular" | "exchange_daily")
                    && time.with_timezone(&zone).weekday().number_from_monday() <= 5,
                "invalid exchange daily session"
            );
        }
        ensure!(
            [bar.open, bar.high, bar.low, bar.close]
                .into_iter()
                .all(positive)
                && bar.low <= bar.open
                && bar.open <= bar.high
                && bar.low <= bar.close
                && bar.close <= bar.high,
            "invalid public OHLC geometry"
        );
        ensure!(
            bar.volume.is_finite() && (0.0..=1e18).contains(&bar.volume),
            "invalid public observed volume"
        );
        previous = Some(time);
    }
    ensure!(
        (2..=20).contains(&input.sources.len()),
        "identified OHLCV and benchmark sources required"
    );
    let mut ids = HashSet::new();
    for source in &input.sources {
        ensure!(
            valid_id(&source.id) && ids.insert(source.id.as_str()),
            "invalid public source identity"
        );
        ensure!(
            !source.provider.is_empty()
                && !source.dataset.is_empty()
                && !format!("{} {}", source.provider, source.dataset)
                    .to_lowercase()
                    .contains("synthetic"),
            "synthetic sources cannot enter public market mode"
        );
        let observed = timestamp(&source.observed_at)?;
        let available = timestamp(&source.available_at)?;
        let retrieved = timestamp(&source.retrieved_at)?;
        ensure!(
            observed <= cutoff
                && observed <= available
                && available <= retrieved
                && retrieved <= now
                && now.signed_duration_since(observed).num_seconds() < input.max_age_seconds,
            "stale or non-causal public source"
        );
    }
    ensure!(
        ids.contains(input.ohlcv_source_id.as_str())
            && ids.contains(input.benchmark.source_id.as_str()),
        "unresolved public data sources"
    );
    for source_id in [&input.ohlcv_source_id, &input.benchmark.source_id] {
        ensure!(
            input.sources.iter().any(|source| &source.id == source_id
                && timestamp(&source.observed_at).ok() == Some(cutoff)),
            "public source cutoff must match the latest complete session"
        );
    }
    ensure!(
        (6..=252).contains(&input.benchmark.series.len())
            && !input.benchmark.name.is_empty()
            && !input.benchmark.benchmark_symbol.is_empty(),
        "observed named benchmark history required"
    );
    let bar_times: HashSet<_> = input
        .bars
        .iter()
        .map(|bar| bar.observed_at.as_str())
        .collect();
    let mut previous = None;
    for point in &input.benchmark.series {
        let time = timestamp(&point.observed_at)?;
        ensure!(
            positive(point.value)
                && bar_times.contains(point.observed_at.as_str())
                && previous.is_none_or(|prev| time > prev),
            "benchmark sessions must align with completed asset sessions"
        );
        previous = Some(time);
    }
    ensure!(
        input.benchmark.series[input.benchmark.series.len() - 6..]
            .iter()
            .zip(&input.bars[input.bars.len() - 6..])
            .all(|(point, bar)| point.observed_at == bar.observed_at),
        "benchmark must cover the latest six asset sessions"
    );
    ensure!(
        input.projected_sessions.len() == horizon_sessions(&input.horizon)?,
        "projection calendar does not cover the horizon"
    );
    let mut previous = cutoff;
    for value in &input.projected_sessions {
        let time = timestamp(value)?;
        ensure!(
            time > previous,
            "projection sessions must be future and ordered"
        );
        if input.calendar == "continuous" {
            ensure!(
                time - previous == Duration::days(1),
                "continuous projection calendar has a missing UTC day"
            );
        } else {
            ensure!(
                time.with_timezone(&zone).weekday().number_from_monday() <= 5,
                "projection includes a non-weekday exchange session"
            );
        }
        previous = time;
    }
    ensure!(
        matches!(
            input.rights.access.as_str(),
            "government_open_data" | "unauthenticated_public_api" | "public_market_data"
        ) && input.rights.terms_url.starts_with("https://")
            && input.rights.terms_url.len() <= 1000
            && !input.rights.usage_note.is_empty(),
        "public source access and actual usage terms must be declared"
    );
    Ok(())
}

/// A genuine observed-data view whose optional panels can be unavailable. This
/// contract cannot be substituted for the separately gated member-equity map.
pub fn build_public_snapshot(input: &PublicMarketMapInput) -> Result<Value> {
    validate_public(input)?;
    let hash = digest(&serde_json::to_vec(input)?);
    let bars = &input.bars;
    let last = &bars[bars.len() - 1];
    let f = features(bars)?;
    let pivots = zigzag(bars);
    let levels = price_levels(bars, &f, &pivots)?;
    let (simulation, scenarios) = simulate(
        bars,
        &input.horizon,
        &input.projected_sessions,
        input.seed.as_deref(),
        &hash,
    )?;
    let (volume, relative_volume) = volume_panel(bars)?;
    let benchmark = &input.benchmark;
    let benchmark_return = (benchmark.series[benchmark.series.len() - 1].value
        / benchmark.series[benchmark.series.len() - 6].value
        - 1.0)
        * 100.0;
    let asset_return = (last.close / bars[bars.len() - 6].close - 1.0) * 100.0;
    let relative_return = asset_return - benchmark_return;
    let benchmark_state = if benchmark_return > 0.5 {
        "offensive"
    } else if benchmark_return < -0.5 {
        "defensive"
    } else {
        "neutral"
    };
    let mut evidence = Vec::new();
    for (id, kind, label, path, source) in [
        (
            "bars-window",
            "bar",
            "Observed completed daily OHLCV",
            "bars",
            &input.ohlcv_source_id,
        ),
        (
            "indicator-sma",
            "indicator",
            "20-session simple moving average",
            "technical_indicators.sma20",
            &input.ohlcv_source_id,
        ),
        (
            "indicator-bands",
            "indicator",
            "Bollinger20 population standard deviation bands",
            "technical_indicators.bollinger20",
            &input.ohlcv_source_id,
        ),
        (
            "indicator-rsi",
            "indicator",
            "Wilder RSI14",
            "technical_indicators.rsi14",
            &input.ohlcv_source_id,
        ),
        (
            "indicator-atr",
            "indicator",
            "Wilder ATR14",
            "technical_indicators.atr14",
            &input.ohlcv_source_id,
        ),
        (
            "indicator-momentum",
            "indicator",
            "Five-session momentum and daily velocity",
            "technical_indicators.momentum",
            &input.ohlcv_source_id,
        ),
        (
            "confirmed-pivots",
            "pivot",
            "Confirmed closing-price reversals",
            "zigzag.confirmed_pivots",
            &input.ohlcv_source_id,
        ),
        (
            "price-levels",
            "level",
            "Observed-price reference levels",
            "levels",
            &input.ohlcv_source_id,
        ),
        (
            "simulation-distribution",
            "simulation",
            "Historical return block bootstrap",
            "monte_carlo",
            &input.ohlcv_source_id,
        ),
        (
            "observed-volume",
            "volume",
            "Actual daily observed volume",
            "panels.volume",
            &input.ohlcv_source_id,
        ),
        (
            "sector-benchmark",
            "sector",
            "Named asset benchmark comparison; not a sector classification",
            "panels.sector",
            &benchmark.source_id,
        ),
    ] {
        evidence.push(json!({"id":id,"kind":kind,"label":label,"source_id":source,"observed_at":last.observed_at,"field_path":path}));
    }
    let position = if last.close >= f.sma {
        "above"
    } else {
        "below"
    };
    let title = if levels.state == "bear" {
        "Price is below trend; watch the lower reference range"
    } else if levels.state == "bull" {
        "Price is above trend; watch the upper reference range"
    } else {
        "Trend and momentum give a mixed picture"
    };
    let adjustment_note = match input.price_adjustment.as_str() {
        "unadjusted" => {
            "Prices are the source's unadjusted observations. Splits, distributions and other corporate actions can create mechanical price changes; price-return indicators and simulations retain those changes."
        }
        "split_dividend_adjusted" => {
            "Prices are declared split- and dividend-adjusted by the source. Indicators and historical return blocks use that supplied adjusted price series; the engine does not independently reconstruct corporate actions or assert a dividend-reinvestment total-return methodology."
        }
        "source_adjusted_unverified" => {
            "The source supplies prices with adjustment processing, but its complete adjustment method and dividend treatment have not been independently verified. This series must not be treated as raw unadjusted prices or as verified fully corporate-action-adjusted prices. Indicators and simulations use the supplied values with that limitation."
        }
        _ => {
            "Prices are declared split-adjusted by the source. These are price-return calculations and do not assume dividend reinvestment."
        }
    };
    let ohlcv_description = input
        .sources
        .iter()
        .find(|source| source.id == input.ohlcv_source_id)
        .map(|source| {
            format!(
                "{} {} {}",
                source.provider, source.dataset, input.rights.usage_note
            )
            .to_ascii_lowercase()
        })
        .unwrap_or_default();
    let volume_coverage_note = if ohlcv_description.contains("iex") {
        "The source describes IEX-only trading activity. These volumes cover that venue, not consolidated SIP volume across U.S. exchanges."
    } else {
        "Volume reflects the coverage of the identified source; it is not assumed to include every trading venue."
    };
    let calendar_note = if input.calendar == "continuous" {
        "Bars are completed UTC days in a continuous market, including weekends. Projection offsets count calendar days."
    } else {
        "Bars are published exchange daily statistics in the asset's stated timezone, with session coverage described by the source. Projection dates come from the supplied exchange calendar."
    };
    let items = vec![
        json!({"id":"read-range","kind":"range","text":format!("The latest source-reported daily close is {:.2}. Support is {:.2} and resistance {:.2}. A future completed close above resistance would move beyond the upper reference range; below support would move beyond the lower range.",last.close,levels.support,levels.resistance),"evidence_refs":["bars-window","price-levels"]}),
        json!({"id":"read-trend","kind":"trend","text":format!("Price is {:.2}% {position} its 20-session average ({:.2}); RSI14 is {:.1}. Five-session momentum is {}.",((last.close/f.sma-1.0)*100.0).abs(),f.sma,f.rsi,f.momentum_state),"evidence_refs":["indicator-sma","indicator-rsi","indicator-momentum"]}),
        json!({"id":"read-momentum","kind":"momentum","text":format!("Latest daily log-return velocity is {:+.2}%; it changed {:+.2} percentage points from the prior session. Confirmed pivots are separated from the unfinished swing.",f.velocity,f.acceleration),"evidence_refs":["indicator-momentum","confirmed-pivots"]}),
        json!({"id":"read-volume","kind":"volume","text":format!("Source-observed daily volume is {:.2} times its 20-session average. {volume_coverage_note} Trade-level volume by price is unavailable from these daily inputs.",relative_volume),"evidence_refs":["observed-volume"]}),
        json!({"id":"read-benchmark","kind":"sector","text":format!("{} ({}) changed {:+.2}% over five completed sessions; {} changed {:+.2}%, a difference of {:+.2} percentage points. This is a named benchmark comparison, not a sector-flow estimate.",benchmark.name,benchmark.benchmark_symbol,benchmark_return,input.asset.symbol,asset_return,relative_return),"evidence_refs":["sector-benchmark","bars-window"]}),
        json!({"id":"read-simulation","kind":"simulation","text":format!("The Rust engine resampled historical five-session return blocks into {TRIALS} seeded trials. The median terminal price is {:.2}; the middle half of simulated endpoints spans {:.2}–{:.2}. These paths do not change when a reference level is crossed.",simulation["terminal_quantiles"]["p50"].as_f64().unwrap_or(last.close),simulation["terminal_quantiles"]["p25"].as_f64().unwrap_or(last.close),simulation["terminal_quantiles"]["p75"].as_f64().unwrap_or(last.close)),"evidence_refs":["simulation-distribution","price-levels"]}),
        json!({"id":"read-missing-data","kind":"limitation","text":"Options ATM implied volatility and observed trade-level volume profiles are unavailable in this public data source. The IV panel remains empty; historical price volatility is not substituted for option IV.","evidence_refs":["bars-window","observed-volume"]}),
        json!({"id":"read-price-basis","kind":"limitation","text":adjustment_note,"evidence_refs":["bars-window","simulation-distribution"]}),
    ];
    let cutoff = timestamp(&last.observed_at)?;
    let available = input
        .sources
        .iter()
        .map(|source| timestamp(&source.available_at))
        .collect::<Result<Vec<_>>>()?
        .into_iter()
        .max()
        .context("missing public source availability")?;
    let mut uuid_bytes: [u8; 16] = Sha256::digest(hash.as_bytes())[..16].try_into()?;
    uuid_bytes[6] = (uuid_bytes[6] & 0x0f) | 0x40;
    uuid_bytes[8] = (uuid_bytes[8] & 0x3f) | 0x80;
    let required: Vec<_> = ["ohlcv", "benchmark", "simulation_artifact"]
        .into_iter()
        .map(|name| json!({"name":name,"state":"available","observed_at":last.observed_at}))
        .collect();
    Ok(json!({
        "mode":"public_market","calendar":input.calendar,"price_adjustment":input.price_adjustment,
        "snapshot_id":uuid::Uuid::from_bytes(uuid_bytes).to_string(),"asset":input.asset,"horizon":input.horizon,"timeframe":"1d","state":levels.state,"last_price":last.close,"bars":bars,
        "technical_indicators":f.serialized,"zigzag":pivots,"levels":levels.serialized,"scenarios":scenarios,"monte_carlo":simulation,
        "panels":{"volume":volume,"implied_volatility":null,"sector":{"sector_id":"asset-benchmark","sector_name":benchmark.name,"benchmark_symbol":benchmark.benchmark_symbol,"return_5d_percent":benchmark_return,"asset_relative_5d_percent":relative_return,"state":benchmark_state,"series":benchmark.series,"evidence_refs":["sector-benchmark"]}},
        "evidence":evidence,"read":{"as_of":last.observed_at,"language":"en","title":title,"summary":format!("{} closed {position} its 20-session average. This research map uses source-observed daily prices and volumes with {} as its benchmark; option IV is unavailable.",input.asset.name,benchmark.name),"items":items,"disclosure":"Impersonal research from observed public market data. Historical bootstrap outcomes are uncalibrated simulations, not forecasts, fair-value estimates, individualized advice or proof of a pricing discrepancy. Optional data gaps and the price-adjustment basis are stated explicitly."},
        "provenance":{"sources":input.sources,"observation_cutoff":last.observed_at,"available_at":available.to_rfc3339(),"generated_at":input.generated_at,"freshness":{"state":"fresh","max_age_seconds":input.max_age_seconds,"expires_at":(cutoff+Duration::seconds(input.max_age_seconds)).to_rfc3339()},"coverage":{"state":"complete","completeness_ratio":1.0,"start_at":bars[0].observed_at,"end_at":last.observed_at,"expected_sessions":input.expected_sessions,"observed_sessions":bars.len(),"required_inputs":required,"missing_inputs":["options_iv","trade_volume_profile"],"regular_session_only":bars.iter().all(|bar|bar.session=="regular"),"corporate_actions_adjusted":matches!(input.price_adjustment.as_str(),"split_adjusted"|"split_dividend_adjusted")},"rights":input.rights,"versions":{"schema":"market-map-public-snapshot-v1","market_data":"public-observed-daily-v1","features":VERSION,"monte_carlo_model":"historical-block-bootstrap-5x5000-v1","methodology":"public-daily-research-v1"},"caveats":[adjustment_note,calendar_note,volume_coverage_note,"ATM option IV and trade-level volume profiles are missing. No values are synthesized for unavailable observations.","Benchmark labels refer to the named comparison asset and five-session price change; they do not establish sector flows or dealer positioning.","Bootstrap paths reuse observed historical return blocks without fitting option IV, pricing costs or a validated future event probability."]}
    }))
}

/// This isolated input is ONLY for visual review and unit tests. The CLI wraps
/// the result in `mode: illustrative_review_only`; it is never a live fallback.
pub fn illustrative_review() -> Result<Value> {
    illustrative_review_for_horizon("20d")
}

pub fn illustrative_review_for_horizon(horizon: &str) -> Result<Value> {
    let mut input = illustrative_input()?;
    let count = horizon_sessions(horizon)?;
    input.horizon = horizon.into();
    input.projected_sessions.truncate(count);
    let snapshot = build_snapshot(&input)?;
    Ok(
        json!({"mode":"illustrative_review_only","notice":"SYNTHETIC VISUAL REVIEW — all prices, IV, volumes and benchmark observations are invented demonstration inputs. This is not current market data or a market assessment.","snapshot":snapshot}),
    )
}

fn illustrative_input() -> Result<MarketMapInput> {
    let mut day = timestamp("2024-01-02T21:00:00Z")?;
    let mut bars = Vec::new();
    let mut iv = Vec::new();
    let mut sector = Vec::new();
    let mut previous = 92.0;
    for index in 0..126 {
        while day.weekday().number_from_monday() > 5 {
            day += Duration::days(1);
        }
        let t = index as f64;
        let close = 92.0 + t * 0.135 + (t / 8.0).sin() * 4.3 + (t / 2.7).sin() * 1.0
            - (t - 107.0).max(0.0) * 0.54;
        let observed = day.to_rfc3339();
        bars.push(Bar {
            observed_at: observed.clone(),
            open: previous,
            high: previous.max(close) + 0.7 + (t / 3.1).sin().abs() * 0.5,
            low: previous.min(close) - 0.65,
            close,
            volume: 1_200_000.0 * (1.1 + (t / 5.1).sin() * 0.3 + (t - 110.0).max(0.0) / 24.0),
            session: "regular".into(),
        });
        iv.push(IvPoint {
            observed_at: observed.clone(),
            percent: 26.0 + (t / 14.0).sin() * 3.0 + (t - 109.0).max(0.0) * 0.38,
        });
        sector.push(ValuePoint {
            observed_at: observed,
            value: 100.0 + t * 0.10 + (t / 9.0).sin() * 1.8,
        });
        previous = close;
        day += Duration::days(1);
    }
    let observed = bars[bars.len() - 1].observed_at.clone();
    let generated = (timestamp(&observed)? + Duration::minutes(30)).to_rfc3339();
    let sources: Vec<_> = [
        (
            "demo-bars",
            "Synthetic adjusted daily bars and corporate actions",
        ),
        ("demo-iv", "Synthetic 30-day ATM IV history"),
        ("demo-sector", "Synthetic sector benchmark closes"),
    ]
    .into_iter()
    .map(|(id, dataset)| Source {
        id: id.into(),
        provider: "ILLUSTRATIVE REVIEW ONLY".into(),
        dataset: dataset.into(),
        observed_at: observed.clone(),
        available_at: generated.clone(),
        retrieved_at: generated.clone(),
        delay_minutes: 30,
    })
    .collect();
    let mut future = Vec::new();
    while future.len() < 60 {
        if day.weekday().number_from_monday() <= 5 {
            future.push(day.to_rfc3339());
        }
        day += Duration::days(1);
    }
    let trades: Vec<_> = bars
        .iter()
        .flat_map(|bar| {
            (0..12).map(move |index| Trade {
                observed_at: bar.observed_at.clone(),
                price: bar.low + (bar.high - bar.low) * (index as f64 + 0.5) / 12.0,
                volume: bar.volume / 12.0,
            })
        })
        .collect();
    Ok(MarketMapInput {
        asset: Asset {
            asset_id: "d6955158-125d-45eb-8cd5-842b3f78342e".into(),
            symbol: "DEMO".into(),
            name: "Illustrative Research Company".into(),
            asset_type: "equity".into(),
            exchange: "ILLUSTRATIVE".into(),
            currency: "USD".into(),
            market_timezone: "America/New_York".into(),
        },
        horizon: "60d".into(),
        expected_sessions: bars.len(),
        bars,
        sources,
        ohlcv_source_id: "demo-bars".into(),
        corporate_actions_source_id: "demo-bars".into(),
        options_iv: IvInput {
            source_id: "demo-iv".into(),
            tenor_days: 30,
            series: iv,
        },
        sector: SectorInput {
            source_id: "demo-sector".into(),
            sector_id: "illustrative-sector".into(),
            sector_name: "Illustrative sector".into(),
            benchmark_symbol: "DEMO.B".into(),
            series: sector,
        },
        corporate_actions_adjusted: true,
        display_authorized: true,
        generated_at: generated,
        max_age_seconds: 345_600,
        projected_sessions: future,
        seed: Some("visual-review-never-market-observation".into()),
        trades,
        trades_source_id: Some("demo-bars".into()),
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn public_input(calendar: &str) -> Result<PublicMarketMapInput> {
        let fixture = illustrative_input()?;
        let mut bars = fixture.bars;
        let mut benchmark = fixture.sector.series;
        let origin = timestamp("2024-01-01T00:00:00Z")?;
        for (index, bar) in bars.iter_mut().enumerate() {
            let time = if calendar == "continuous" {
                origin + Duration::days(index as i64)
            } else {
                timestamp(&bar.observed_at)?
                    .date_naive()
                    .and_hms_opt(9, 0, 0)
                    .unwrap()
                    .and_utc()
            };
            bar.observed_at = time.to_rfc3339();
            bar.session = if calendar == "continuous" {
                "continuous"
            } else {
                "exchange_daily"
            }
            .into();
            benchmark[index].observed_at = bar.observed_at.clone();
        }
        let last = timestamp(&bars[bars.len() - 1].observed_at)?;
        let generated = (last + Duration::minutes(30)).to_rfc3339();
        let sources: Vec<_> = ["test-bars", "test-benchmark"]
            .into_iter()
            .map(|id| Source {
                id: id.into(),
                provider: "Unit test exchange".into(),
                dataset: "Test-only observed-input contract".into(),
                observed_at: last.to_rfc3339(),
                available_at: generated.clone(),
                retrieved_at: generated.clone(),
                delay_minutes: 30,
            })
            .collect();
        let mut future = Vec::new();
        let mut day = last + Duration::days(1);
        while future.len() < 20 {
            if calendar == "continuous" || day.weekday().number_from_monday() <= 5 {
                future.push(day.to_rfc3339());
            }
            day += Duration::days(1);
        }
        Ok(PublicMarketMapInput {
            mode: "public_market".into(),
            asset: Asset {
                asset_id: fixture.asset.asset_id,
                symbol: if calendar == "continuous" {
                    "BTCUSD"
                } else {
                    "2330"
                }
                .into(),
                name: "Unit test observed asset".into(),
                asset_type: if calendar == "continuous" {
                    "crypto"
                } else {
                    "equity"
                }
                .into(),
                exchange: if calendar == "continuous" {
                    "TEST-24H"
                } else {
                    "TWSE"
                }
                .into(),
                currency: if calendar == "continuous" {
                    "USD"
                } else {
                    "TWD"
                }
                .into(),
                market_timezone: if calendar == "continuous" {
                    "UTC"
                } else {
                    "Asia/Taipei"
                }
                .into(),
            },
            calendar: calendar.into(),
            price_adjustment: "unadjusted".into(),
            horizon: "20d".into(),
            expected_sessions: bars.len(),
            bars,
            sources,
            ohlcv_source_id: "test-bars".into(),
            benchmark: PublicBenchmark {
                source_id: "test-benchmark".into(),
                benchmark_symbol: "0050".into(),
                name: "Unit test benchmark".into(),
                series: benchmark,
            },
            rights: PublicDataRights {
                access: "government_open_data".into(),
                terms_url: "https://example.invalid/test-only-license".into(),
                usage_note: "Only a unit-test input; never published market data".into(),
            },
            generated_at: generated,
            max_age_seconds: 345600,
            projected_sessions: future,
            seed: Some("public-contract-unit-test".into()),
        })
    }

    #[test]
    fn public_raw_equity_keeps_missing_iv_explicit_and_member_contract_strict() -> Result<()> {
        let input = public_input("exchange")?;
        let snapshot = build_public_snapshot(&input)?;
        assert!(snapshot["panels"]["implied_volatility"].is_null());
        assert_eq!(
            snapshot["provenance"]["coverage"]["regular_session_only"],
            false
        );
        assert_eq!(snapshot["bars"][0]["session"], "exchange_daily");
        assert_eq!(
            snapshot["provenance"]["coverage"]["corporate_actions_adjusted"],
            false
        );
        assert_eq!(
            snapshot["provenance"]["coverage"]["required_inputs"]
                .as_array()
                .unwrap()
                .len(),
            3
        );
        assert_eq!(
            snapshot["provenance"]["versions"]["schema"],
            "market-map-public-snapshot-v1"
        );
        assert!(
            snapshot["provenance"]["rights"]
                .get("entitlement")
                .is_none()
        );
        assert!(
            !snapshot["evidence"]
                .as_array()
                .unwrap()
                .iter()
                .any(|item| item["kind"] == "options")
        );
        assert!(serde_json::from_value::<MarketMapInput>(serde_json::to_value(input)?).is_err());
        let mut strict = serde_json::to_value(illustrative_input()?)?;
        strict["options_iv"] = Value::Null;
        assert!(serde_json::from_value::<MarketMapInput>(strict).is_err());
        Ok(())
    }

    #[test]
    fn public_adjustment_basis_and_iex_volume_scope_are_explicit() -> Result<()> {
        let mut input = public_input("exchange")?;
        input.sources[0].provider = "HF Data Library".into();
        input.sources[0].dataset = "IEX-only clean daily observations".into();
        let mut original_features = None;
        for adjustment in [
            "unadjusted",
            "split_adjusted",
            "split_dividend_adjusted",
            "source_adjusted_unverified",
        ] {
            input.price_adjustment = adjustment.into();
            let snapshot = build_public_snapshot(&input)?;
            assert_eq!(snapshot["price_adjustment"], adjustment);
            assert_eq!(
                snapshot["provenance"]["coverage"]["corporate_actions_adjusted"],
                matches!(adjustment, "split_adjusted" | "split_dividend_adjusted")
            );
            let items = snapshot["read"]["items"].as_array().unwrap();
            let note = items
                .iter()
                .find(|item| item["id"] == "read-volume")
                .unwrap()["text"]
                .as_str()
                .unwrap();
            assert!(note.contains("IEX-only") && note.contains("not consolidated SIP volume"));
            assert!(snapshot["panels"]["implied_volatility"].is_null());
            if adjustment == "split_dividend_adjusted" {
                let basis = items
                    .iter()
                    .find(|item| item["id"] == "read-price-basis")
                    .unwrap()["text"]
                    .as_str()
                    .unwrap();
                assert!(
                    basis.contains("split- and dividend-adjusted")
                        && basis.contains("does not independently reconstruct")
                );
            }
            if let Some(features) = &original_features {
                assert_eq!(&snapshot["technical_indicators"], features);
            } else {
                original_features = Some(snapshot["technical_indicators"].clone());
            }
            if adjustment == "source_adjusted_unverified" {
                let basis = items
                    .iter()
                    .find(|item| item["id"] == "read-price-basis")
                    .unwrap()["text"]
                    .as_str()
                    .unwrap();
                assert!(
                    basis.contains("not been independently verified")
                        && basis.contains("must not be treated as raw unadjusted")
                );
                assert!(basis.contains("dividend treatment"));
            }
        }
        input.price_adjustment = "total_return_assumed".into();
        assert!(build_public_snapshot(&input).is_err());
        Ok(())
    }

    #[test]
    fn public_continuous_calendar_accepts_weekends_and_rejects_missing_days() -> Result<()> {
        let mut input = public_input("continuous")?;
        let snapshot = build_public_snapshot(&input)?;
        assert_eq!(
            snapshot["provenance"]["coverage"]["regular_session_only"],
            false
        );
        assert_eq!(snapshot["bars"][0]["session"], "continuous");
        input.bars.remove(20);
        input.expected_sessions -= 1;
        assert!(build_public_snapshot(&input).is_err());
        Ok(())
    }

    #[test]
    fn public_sources_cannot_be_stale_synthetic_or_non_causal() -> Result<()> {
        let input = public_input("exchange")?;
        let mut changed = input.clone();
        changed.sources[0].dataset = "synthetic review".into();
        assert!(build_public_snapshot(&changed).is_err());
        let mut changed = input.clone();
        changed.sources[0].retrieved_at = "2040-01-01T00:00:00Z".into();
        assert!(build_public_snapshot(&changed).is_err());
        let mut changed = input;
        changed.generated_at = (timestamp(&changed.generated_at)? + Duration::days(8)).to_rfc3339();
        assert!(build_public_snapshot(&changed).is_err());
        Ok(())
    }

    #[test]
    fn wilder_rsi_and_sma_have_known_values() -> Result<()> {
        let mut input = illustrative_input()?;
        for (index, bar) in input.bars.iter_mut().enumerate() {
            bar.open = 100.0 + index as f64;
            bar.close = bar.open;
            bar.low = bar.close - 1.0;
            bar.high = bar.close + 1.0;
        }
        let result = features(&input.bars)?;
        assert_eq!(result.rsi, 100.0);
        assert_eq!(result.sma, 215.5);
        assert!((result.atr - 2.0).abs() < 1e-12);
        for bar in &mut input.bars {
            bar.open = 100.0;
            bar.close = 100.0;
            bar.low = 100.0;
            bar.high = 100.0;
        }
        let flat = features(&input.bars)?;
        assert_eq!(flat.rsi, 50.0);
        assert_eq!(flat.atr, 0.0);
        Ok(())
    }

    #[test]
    fn indicators_and_confirmed_pivots_are_causal() -> Result<()> {
        let input = illustrative_input()?;
        let early = features(&input.bars[..80])?;
        let full = features(&input.bars)?;
        for name in ["sma20", "bollinger20", "rsi14", "atr14", "momentum"] {
            let before = early.serialized[name]["points"].as_array().unwrap();
            let after = full.serialized[name]["points"].as_array().unwrap();
            assert_eq!(before.as_slice(), &after[..before.len()]);
        }
        let early = zigzag(&input.bars[..80]);
        let full = zigzag(&input.bars);
        let before = early["confirmed_pivots"].as_array().unwrap();
        let after = full["confirmed_pivots"].as_array().unwrap();
        assert_eq!(before.as_slice(), &after[..before.len()]);
        for pivot in after {
            assert!(
                timestamp(pivot["confirmed_at"].as_str().unwrap())?
                    >= timestamp(pivot["observed_at"].as_str().unwrap())?
            );
        }
        Ok(())
    }

    #[test]
    fn malformed_missing_stale_and_future_inputs_fail_closed() -> Result<()> {
        let baseline = illustrative_input()?;
        let mut input = baseline.clone();
        input.display_authorized = false;
        assert!(build_snapshot(&input).is_err());
        let mut input = baseline.clone();
        input.corporate_actions_adjusted = false;
        assert!(build_snapshot(&input).is_err());
        let mut input = baseline.clone();
        input.options_iv.series.truncate(5);
        assert!(build_snapshot(&input).is_err());
        let mut input = baseline.clone();
        input
            .options_iv
            .series
            .remove(input.options_iv.series.len() - 3);
        assert!(build_snapshot(&input).is_err());
        let mut input = baseline.clone();
        input.expected_sessions += 1;
        assert!(build_snapshot(&input).is_err());
        let mut input = baseline.clone();
        input.bars[0].close = input.bars[0].high + 1.0;
        assert!(build_snapshot(&input).is_err());
        let mut input = baseline.clone();
        input.sources[0].available_at = "2040-01-01T00:00:00Z".into();
        assert!(build_snapshot(&input).is_err());
        let mut input = baseline.clone();
        input.generated_at = (timestamp(&input.generated_at)? + Duration::days(8)).to_rfc3339();
        assert!(build_snapshot(&input).is_err());
        let mut input = baseline;
        input.projected_sessions[0] = input.bars[0].observed_at.clone();
        assert!(build_snapshot(&input).is_err());
        Ok(())
    }

    #[test]
    fn same_session_iv_keeps_actual_sampling_time_and_rejects_future_data() -> Result<()> {
        let mut input = illustrative_input()?;
        for point in &mut input.options_iv.series {
            point.observed_at =
                (timestamp(&point.observed_at)? - Duration::minutes(15)).to_rfc3339();
        }
        let observed = input.options_iv.series.last().unwrap().observed_at.clone();
        input
            .sources
            .iter_mut()
            .find(|source| source.id == input.options_iv.source_id)
            .unwrap()
            .observed_at = observed.clone();
        let snapshot = build_snapshot(&input)?;
        assert_eq!(
            snapshot["panels"]["implied_volatility"]["source_observed_at"],
            observed
        );
        assert_eq!(
            snapshot["evidence"]
                .as_array()
                .unwrap()
                .iter()
                .find(|item| item["kind"] == "options")
                .unwrap()["observed_at"],
            observed
        );
        input.options_iv.series[0].observed_at =
            (timestamp(&input.bars[0].observed_at)? + Duration::minutes(1)).to_rfc3339();
        assert!(build_snapshot(&input).is_err());
        Ok(())
    }

    #[test]
    fn bootstrap_is_reproducible_conserves_trials_and_has_genuine_paths() -> Result<()> {
        let input = illustrative_input()?;
        let a = build_snapshot(&input)?;
        let b = build_snapshot(&input)?;
        assert_eq!(a, b);
        let sim = &a["monte_carlo"];
        let bins = sim["terminal_density"].as_array().unwrap();
        assert_eq!(
            bins.iter()
                .map(|bin| bin["sample_count"].as_u64().unwrap())
                .sum::<u64>(),
            TRIALS as u64
        );
        assert!(
            (bins
                .iter()
                .map(|bin| bin["probability_mass"].as_f64().unwrap())
                .sum::<f64>()
                - 1.0)
                .abs()
                < 1e-12
        );
        let observed_returns: Vec<_> = input
            .bars
            .windows(2)
            .map(|pair| (pair[1].close / pair[0].close).ln())
            .collect();
        for path in sim["sampled_paths"].as_array().unwrap() {
            let points = path["points"].as_array().unwrap();
            assert_eq!(points.len(), 61);
            assert_eq!(points[0]["price"], a["last_price"]);
            for pair in points.windows(2) {
                let change =
                    (pair[1]["price"].as_f64().unwrap() / pair[0]["price"].as_f64().unwrap()).ln();
                assert!(
                    observed_returns
                        .iter()
                        .any(|actual| (actual - change).abs() < 1e-12)
                );
            }
        }
        let mut changed = input;
        changed.seed = Some("different".into());
        assert_ne!(
            a["monte_carlo"]["terminal_particles"],
            build_snapshot(&changed)?["monte_carlo"]["terminal_particles"]
        );
        Ok(())
    }

    #[test]
    fn serialized_contract_resolves_evidence_and_review_is_explicit() -> Result<()> {
        let review = illustrative_review()?;
        assert_eq!(review["mode"], "illustrative_review_only");
        let snapshot = &review["snapshot"];
        assert_eq!(snapshot["levels"].as_array().unwrap().len(), 6);
        assert_eq!(snapshot["scenarios"].as_array().unwrap().len(), 3);
        for evidence in snapshot["evidence"].as_array().unwrap() {
            let path = evidence["field_path"].as_str().unwrap();
            let mut node = snapshot;
            for part in path.split('.') {
                node = &node[part];
            }
            assert!(!node.is_null(), "unresolved evidence {path}");
        }
        let encoded = serde_json::to_string(&review)?;
        let decoded: Value = serde_json::from_str(&encoded)?;
        assert_eq!(decoded["mode"], review["mode"]);
        assert_eq!(decoded["snapshot"]["snapshot_id"], snapshot["snapshot_id"]);
        let price = decoded["snapshot"]["last_price"].as_f64().unwrap();
        assert!((price - snapshot["last_price"].as_f64().unwrap()).abs() < 1e-10);
        assert_eq!(decoded["snapshot"]["evidence"], snapshot["evidence"]);
        Ok(())
    }
}
