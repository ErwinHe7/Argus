use std::collections::{BTreeSet, HashMap};

use serde::{Deserialize, Serialize};

use crate::domain::{MarketState, Outcome};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct TimeBucketEffect {
    pub bucket_5m: i32,
    pub clock_label_et: String,
    pub observed_bar_direction: String,
    pub train_samples: usize,
    pub validation_samples: usize,
    pub test_samples: usize,
    pub train_reversal_rate: f64,
    pub validation_reversal_rate: f64,
    pub test_reversal_rate: f64,
    #[serde(default)]
    pub validation_strong_reversal_rate: f64,
    #[serde(default)]
    pub test_strong_reversal_rate: f64,
    pub validation_mean_reversal_return: f64,
    pub test_mean_reversal_return: f64,
    pub validation_p_value: f64,
    pub validation_q_value: f64,
    pub selected_on_validation: bool,
}

#[derive(Default, Clone)]
struct Stats {
    n: usize,
    reversals: usize,
    strong_reversals: usize,
    directional_sum: f64,
}

impl Stats {
    fn push(&mut self, directional: f64, strong_reversal: bool) {
        self.n += 1;
        self.reversals += usize::from(directional > 0.0);
        self.strong_reversals += usize::from(strong_reversal);
        self.directional_sum += directional;
    }
    fn rate(&self) -> f64 {
        if self.n == 0 {
            0.0
        } else {
            self.reversals as f64 / self.n as f64
        }
    }
    fn mean(&self) -> f64 {
        if self.n == 0 {
            0.0
        } else {
            self.directional_sum / self.n as f64
        }
    }
    fn strong_rate(&self) -> f64 {
        if self.n == 0 {
            0.0
        } else {
            self.strong_reversals as f64 / self.n as f64
        }
    }
}

fn normal_cdf(x: f64) -> f64 {
    // Abramowitz-Stegun approximation, sufficient for a diagnostic p-value.
    let z = x.abs();
    let t = 1.0 / (1.0 + 0.231_641_9 * z);
    let density = 0.398_942_280_4 * (-0.5 * z * z).exp();
    let polynomial = t
        * (0.319_381_530
            + t * (-0.356_563_782
                + t * (1.781_477_937 + t * (-1.821_255_978 + t * 1.330_274_429))));
    let positive = 1.0 - density * polynomial;
    if x >= 0.0 { positive } else { 1.0 - positive }
}

fn binomial_p_value(stats: &Stats) -> f64 {
    if stats.n == 0 {
        return 1.0;
    }
    let standard_error = (0.25 / stats.n as f64).sqrt();
    let z = (stats.rate() - 0.5) / standard_error;
    (2.0 * (1.0 - normal_cdf(z.abs()))).clamp(0.0, 1.0)
}

fn clock_label(bucket: i32) -> String {
    let minutes = 9 * 60 + 30 + bucket * 5;
    format!(
        "{:02}:{:02}-{:02}:{:02}",
        minutes / 60,
        minutes % 60,
        (minutes + 5) / 60,
        (minutes + 5) % 60
    )
}

/// Audits completed five-minute bars only. Dates are split chronologically
/// 60/20/20; selection uses train+validation and never inspects test metrics.
pub fn audit_time_bucket_reversals(
    states: &[MarketState],
    outcomes: &[Outcome],
) -> Vec<TimeBucketEffect> {
    let dates: Vec<_> = states
        .iter()
        .map(|s| s.session_date)
        .collect::<BTreeSet<_>>()
        .into_iter()
        .collect();
    if dates.len() < 10 {
        return Vec::new();
    }
    let train_end = (dates.len() * 60 / 100).max(1);
    let validation_end = (dates.len() * 80 / 100)
        .max(train_end + 1)
        .min(dates.len() - 1);
    let date_partition: HashMap<_, usize> = dates
        .iter()
        .enumerate()
        .map(|(idx, date)| {
            (
                *date,
                if idx < train_end {
                    0
                } else if idx < validation_end {
                    1
                } else {
                    2
                },
            )
        })
        .collect();
    let outcome_map: HashMap<usize, &Outcome> =
        outcomes.iter().map(|o| (o.state_index, o)).collect();
    let mut grouped = HashMap::<(i32, i8), [Stats; 3]>::new();
    for (idx, state) in states.iter().enumerate() {
        if state.minute_in_5m_bucket != 4 || state.active_5m_return.abs() < 0.0002 {
            continue;
        }
        let Some(outcome) = outcome_map.get(&idx) else {
            continue;
        };
        let observed_direction = state.active_5m_return.signum() as i8;
        let reversal_direction = -(observed_direction as f64);
        // Strong reversal label: at least 40 bps favorable excursion during the
        // next 30 minutes and no more than 20 bps continuation against reversal.
        let strong_reversal = if observed_direction > 0 {
            outcome.mae >= 0.004 && outcome.mfe <= 0.002
        } else {
            outcome.mfe >= 0.004 && outcome.mae <= 0.002
        };
        let partition = date_partition[&state.session_date];
        grouped
            .entry((state.bucket_5m, observed_direction))
            .or_default()[partition]
            .push(
                reversal_direction * outcome.directional_return,
                strong_reversal,
            );
    }
    let mut effects: Vec<_> = grouped
        .into_iter()
        .map(|((bucket, direction), stats)| {
            let p = binomial_p_value(&stats[1]);
            TimeBucketEffect {
                bucket_5m: bucket,
                clock_label_et: clock_label(bucket),
                observed_bar_direction: if direction > 0 {
                    "up".into()
                } else {
                    "down".into()
                },
                train_samples: stats[0].n,
                validation_samples: stats[1].n,
                test_samples: stats[2].n,
                train_reversal_rate: stats[0].rate(),
                validation_reversal_rate: stats[1].rate(),
                test_reversal_rate: stats[2].rate(),
                validation_strong_reversal_rate: stats[1].strong_rate(),
                test_strong_reversal_rate: stats[2].strong_rate(),
                validation_mean_reversal_return: stats[1].mean(),
                test_mean_reversal_return: stats[2].mean(),
                validation_p_value: p,
                validation_q_value: 1.0,
                selected_on_validation: false,
            }
        })
        .collect();
    // Benjamini-Hochberg FDR correction across every bucket/direction searched.
    let mut order: Vec<usize> = (0..effects.len()).collect();
    order.sort_by(|a, b| {
        effects[*a]
            .validation_p_value
            .total_cmp(&effects[*b].validation_p_value)
    });
    let m = order.len().max(1) as f64;
    let mut running_q: f64 = 1.0;
    for rank_from_end in (0..order.len()).rev() {
        let idx = order[rank_from_end];
        let rank = rank_from_end + 1;
        running_q = running_q.min(effects[idx].validation_p_value * m / rank as f64);
        effects[idx].validation_q_value = running_q.clamp(0.0, 1.0);
    }
    for effect in &mut effects {
        effect.selected_on_validation = effect.train_samples >= 20
            && effect.validation_samples >= 8
            && effect.train_reversal_rate > 0.5
            && effect.validation_mean_reversal_return > 0.0
            && effect.validation_q_value <= 0.10;
    }
    effects.sort_by(|a, b| {
        (a.bucket_5m, &a.observed_bar_direction).cmp(&(b.bucket_5m, &b.observed_bar_direction))
    });
    effects
}
