//! Fixed six-decimal monetary arithmetic. Wire values are decimal strings.
use anyhow::{Result, bail, ensure};
use serde::{Deserialize, Deserializer, Serialize, Serializer, de::Error};
use std::{fmt, str::FromStr};

pub const SCALE: i64 = 1_000_000;

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, PartialOrd, Ord)]
pub struct Decimal(pub i64);

impl Decimal {
    pub const ZERO: Self = Self(0);
    pub fn checked_add(self, other: Self) -> Result<Self> {
        Ok(Self(
            self.0
                .checked_add(other.0)
                .ok_or_else(|| anyhow::anyhow!("decimal overflow"))?,
        ))
    }
    pub fn checked_sub(self, other: Self) -> Result<Self> {
        Ok(Self(
            self.0
                .checked_sub(other.0)
                .ok_or_else(|| anyhow::anyhow!("decimal overflow"))?,
        ))
    }
    pub fn quantity(self, quantity: u64) -> Result<Self> {
        Ok(Self(i64::try_from(
            i128::from(self.0) * i128::from(quantity),
        )?))
    }
    /// Positive amounts round down for a budget, up for a cost.
    pub fn bps(self, bps: u32, round_up: bool) -> Result<Self> {
        ensure!(self.0 >= 0, "negative basis for basis-point amount");
        let product = i128::from(self.0) * i128::from(bps);
        Ok(Self(i64::try_from(
            (product + if round_up { 9_999 } else { 0 }) / 10_000,
        )?))
    }
    pub fn as_f64(self) -> f64 {
        self.0 as f64 / SCALE as f64
    }
    pub fn positive_ceil(value: f64) -> Result<Self> {
        ensure!(
            value.is_finite() && value >= 0.0 && value < i64::MAX as f64 / SCALE as f64,
            "invalid derived decimal"
        );
        Ok(Self((value * SCALE as f64).ceil() as i64))
    }
}

impl FromStr for Decimal {
    type Err = anyhow::Error;
    fn from_str(value: &str) -> Result<Self> {
        ensure!(
            !value.is_empty() && value.len() <= 32 && value.trim() == value,
            "invalid decimal string"
        );
        let (negative, value) = value
            .strip_prefix('-')
            .map_or((false, value), |s| (true, s));
        let mut parts = value.split('.');
        let whole = parts.next().unwrap_or_default();
        let fraction = parts.next().unwrap_or_default();
        ensure!(
            !whole.is_empty() && whole.bytes().all(|b| b.is_ascii_digit()),
            "invalid decimal whole part"
        );
        ensure!(
            fraction.len() <= 6
                && fraction.bytes().all(|b| b.is_ascii_digit())
                && parts.next().is_none(),
            "decimal precision must be at most six"
        );
        if value.ends_with('.') {
            bail!("decimal fraction is empty");
        }
        let units = whole.parse::<i128>()? * i128::from(SCALE)
            + if fraction.is_empty() {
                0
            } else {
                fraction.parse::<i128>()? * 10_i128.pow(6 - fraction.len() as u32)
            };
        Ok(Self(i64::try_from(if negative { -units } else { units })?))
    }
}
impl fmt::Display for Decimal {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let amount = i128::from(self.0).abs();
        write!(
            f,
            "{}{}.{:06}",
            if self.0 < 0 { "-" } else { "" },
            amount / i128::from(SCALE),
            amount % i128::from(SCALE)
        )
    }
}
impl Serialize for Decimal {
    fn serialize<S: Serializer>(&self, serializer: S) -> Result<S::Ok, S::Error> {
        serializer.serialize_str(&self.to_string())
    }
}
impl<'de> Deserialize<'de> for Decimal {
    fn deserialize<D: Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
        String::deserialize(deserializer)?
            .parse()
            .map_err(D::Error::custom)
    }
}
