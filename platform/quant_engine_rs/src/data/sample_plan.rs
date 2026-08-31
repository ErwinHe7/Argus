use std::{collections::BTreeMap, path::Path};

use anyhow::{Context, Result, bail};
use chrono::{DateTime, NaiveDate, Timelike, Utc};
use chrono_tz::America::New_York;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Default)]
struct DailySummary {
    first_timestamp: Option<DateTime<Utc>>,
    last_timestamp: Option<DateTime<Utc>>,
    open: f64,
    high: f64,
    low: f64,
    close: f64,
    volume: f64,
    bars: usize,
}

impl DailySummary {
    fn update(
        &mut self,
        timestamp: DateTime<Utc>,
        open: f64,
        high: f64,
        low: f64,
        close: f64,
        volume: f64,
    ) {
        if self
            .first_timestamp
            .is_none_or(|current| timestamp < current)
        {
            self.first_timestamp = Some(timestamp);
            self.open = open;
        }
        if self
            .last_timestamp
            .is_none_or(|current| timestamp > current)
        {
            self.last_timestamp = Some(timestamp);
            self.close = close;
        }
        self.high = self.high.max(high);
        self.low = if self.low == 0.0 {
            low
        } else {
            self.low.min(low)
        };
        self.volume += volume;
        self.bars += 1;
    }

    fn return_pct(&self) -> f64 {
        self.close / self.open - 1.0
    }

    fn range_pct(&self) -> f64 {
        self.high / self.low - 1.0
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SampleDay {
    pub date: NaiveDate,
    pub role: String,
    pub proxy_return: f64,
    pub proxy_range: f64,
    pub proxy_volume: f64,
    pub bars: usize,
    pub selection_note: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FiveDaySamplePlan {
    pub status: String,
    pub source: String,
    pub target_parent: String,
    pub requested_schemas: Vec<String>,
    pub requested_dte: Vec<usize>,
    pub strike_window_pct: f64,
    pub days: Vec<SampleDay>,
    pub event_calendar_status: String,
    pub warnings: Vec<String>,
}

#[derive(Debug, Deserialize)]
struct BarRow {
    timestamp: DateTime<Utc>,
    symbol: String,
    open: f64,
    high: f64,
    low: f64,
    close: f64,
    volume: f64,
}

fn is_rth(timestamp: DateTime<Utc>) -> bool {
    let local = timestamp.with_timezone(&New_York);
    let minute = local.hour() * 60 + local.minute();
    (9 * 60 + 30..16 * 60).contains(&minute)
}

pub fn build_five_day_plan(
    bars_path: &Path,
    event_date: Option<NaiveDate>,
    strike_window_pct: f64,
) -> Result<FiveDaySamplePlan> {
    if !(0.01..=0.20).contains(&strike_window_pct) {
        bail!("strike window must be between 1% and 20%");
    }
    let mut reader = csv::Reader::from_path(bars_path)
        .with_context(|| format!("cannot open proxy bars {}", bars_path.display()))?;
    let mut days = BTreeMap::<NaiveDate, DailySummary>::new();
    for row in reader.deserialize::<BarRow>() {
        let row = row?;
        if row.symbol != "SPY" || !is_rth(row.timestamp) {
            continue;
        }
        let date = row.timestamp.with_timezone(&New_York).date_naive();
        days.entry(date).or_default().update(
            row.timestamp,
            row.open,
            row.high,
            row.low,
            row.close,
            row.volume,
        );
    }
    let eligible = days
        .into_iter()
        .filter(|(_, summary)| summary.bars >= 300 && summary.open > 0.0 && summary.low > 0.0)
        .collect::<Vec<_>>();
    if eligible.len() < 20 {
        bail!("not enough complete SPY sessions to construct a sample plan");
    }
    let mut selected = Vec::<(NaiveDate, &'static str, String)>::new();
    let mut choose = |mut ranked: Vec<(NaiveDate, f64)>, role, descending: bool| {
        ranked.sort_by(|left, right| left.1.total_cmp(&right.1));
        if descending {
            ranked.reverse();
        }
        if let Some((date, _)) = ranked
            .into_iter()
            .find(|(date, _)| selected.iter().all(|row| row.0 != *date))
        {
            selected.push((
                date,
                role,
                "selected from complete SPY RTH proxy bars".to_string(),
            ));
        }
    };
    choose(
        eligible
            .iter()
            .map(|(date, summary)| (*date, summary.range_pct()))
            .collect(),
        "LOW_VOLATILITY",
        false,
    );
    choose(
        eligible
            .iter()
            .map(|(date, summary)| (*date, summary.range_pct()))
            .collect(),
        "HIGH_VOLATILITY",
        true,
    );
    choose(
        eligible
            .iter()
            .map(|(date, summary)| (*date, summary.return_pct()))
            .collect(),
        "LARGE_UP_DAY",
        true,
    );
    choose(
        eligible
            .iter()
            .map(|(date, summary)| (*date, summary.return_pct()))
            .collect(),
        "LARGE_DOWN_DAY",
        false,
    );
    let event_is_available = event_date.is_some_and(|date| {
        eligible.iter().any(|(candidate, _)| *candidate == date)
            && selected.iter().all(|row| row.0 != date)
    });
    if let Some(date) = event_date.filter(|_| event_is_available) {
        selected.push((
            date,
            "MACRO_EVENT_DAY",
            "event date explicitly supplied; calendar provenance must be attached before research use"
                .to_string(),
        ));
    } else {
        let mut median = eligible
            .iter()
            .map(|(date, summary)| (*date, summary.range_pct()))
            .collect::<Vec<_>>();
        median.sort_by(|left, right| left.1.total_cmp(&right.1));
        let middle = median.len() / 2;
        let date = median[middle..]
            .iter()
            .chain(median[..middle].iter().rev())
            .find(|(date, _)| selected.iter().all(|row| row.0 != *date))
            .map(|row| row.0)
            .context("cannot select distinct neutral sample day")?;
        selected.push((
            date,
            "NEUTRAL_DAY_EVENT_SLOT_UNVERIFIED",
            "no verified event calendar/date was supplied; this is not labeled as CPI/FOMC"
                .to_string(),
        ));
    }
    selected.sort_by_key(|row| row.0);
    let output_days = selected
        .into_iter()
        .map(|(date, role, note)| {
            let summary = eligible
                .iter()
                .find(|(candidate, _)| *candidate == date)
                .map(|(_, summary)| summary)
                .expect("selected date came from eligible set");
            SampleDay {
                date,
                role: role.to_string(),
                proxy_return: summary.return_pct(),
                proxy_range: summary.range_pct(),
                proxy_volume: summary.volume,
                bars: summary.bars,
                selection_note: note,
            }
        })
        .collect();
    Ok(FiveDaySamplePlan {
        status: "PLAN_ONLY_AWAITING_COST_ESTIMATE_AND_CONFIRMATION".to_string(),
        source: "MASSIVE_SPY_UNDERLYING_PROXY_ONLY".to_string(),
        target_parent: "SPXW".to_string(),
        requested_schemas: vec!["definition".to_string(), "cbbo-1m".to_string()],
        requested_dte: vec![0, 1],
        strike_window_pct,
        days: output_days,
        event_calendar_status: if event_is_available {
            "EXPLICIT_DATE_UNVERIFIED_PROVENANCE".to_string()
        } else {
            "NOT_CONFIGURED".to_string()
        },
        warnings: vec![
            "SPY only selects diverse QA dates; it is never stored or represented as SPX."
                .to_string(),
            "Full-day proxy statistics are used only to plan a data QA sample, never as live model features or strike-selection inputs."
                .to_string(),
            "No OPRA data is downloaded until account-specific cost estimates pass an explicit maximum-cost confirmation."
                .to_string(),
        ],
    })
}

#[cfg(test)]
mod tests {
    use super::is_rth;
    use chrono::{DateTime, Utc};

    #[test]
    fn regular_session_filter_is_dst_aware() {
        let summer = DateTime::parse_from_rfc3339("2026-07-20T13:30:00Z")
            .unwrap()
            .with_timezone(&Utc);
        let winter = DateTime::parse_from_rfc3339("2026-01-20T14:30:00Z")
            .unwrap()
            .with_timezone(&Utc);
        assert!(is_rth(summer));
        assert!(is_rth(winter));
    }
}
