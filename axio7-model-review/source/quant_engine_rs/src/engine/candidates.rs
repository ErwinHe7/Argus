use std::collections::BTreeMap;

use uuid::Uuid;

use crate::{
    domain::{Candidate, MarketState, SetupType},
    engine::closing_short_cover::is_positive_ramp_confirmation,
};

pub fn generate_candidates(states: &[MarketState]) -> Vec<Candidate> {
    let mut raw = Vec::<(Candidate, f64)>::new();
    for (idx, state) in states.iter().enumerate() {
        let mut push = |setup_type, direction, reasons: Vec<&str>, heuristic_score: f64| {
            raw.push((
                Candidate {
                    candidate_id: Uuid::new_v4().to_string(),
                    timestamp: state.timestamp,
                    session_date: state.session_date,
                    state_index: idx,
                    setup_type,
                    direction,
                    entry_reference: state.close,
                    reason_codes: reasons.into_iter().map(str::to_string).collect(),
                },
                heuristic_score,
            ));
        };
        if (15..=90).contains(&state.minutes_from_open)
            && state.ret_5m.abs() > 0.0008
            && state.volume_zscore > 0.5
            && state.market_confirmation_score >= 0.0
        {
            push(
                SetupType::OpeningRangeBreakout,
                state.ret_5m.signum() as i8,
                vec!["opening_window", "price_impulse", "volume_confirmation"],
                state.ret_5m.abs() * 10_000.0
                    + state.volume_zscore.max(0.0)
                    + state.market_confirmation_score,
            );
        }
        if (5..=45).contains(&state.minutes_from_open)
            && (state.consecutive_up_bars >= 3 || state.consecutive_down_bars >= 3)
            && state.ret_5m.abs() >= 0.0010
            && state.rvol_same_minute >= 1.15
            && state.market_confirmation_score > 0.0
        {
            push(
                SetupType::OpeningDriveContinuation,
                state.ret_5m.signum() as i8,
                vec![
                    "opening_drive",
                    "three_bar_persistence",
                    "relative_volume",
                    "breadth_aligned",
                ],
                state.ret_5m.abs() * 10_000.0 + state.rvol_same_minute,
            );
        }
        if state.failed_opening_breakout != 0.0
            && state.minutes_from_open >= 15
            && state.minutes_to_close > 30
            && state.volume_zscore >= 0.25
        {
            push(
                SetupType::FailedBreakout,
                state.failed_opening_breakout.signum() as i8,
                vec![
                    "opening_range_sweep",
                    "close_back_inside",
                    "trapped_breakout_traders",
                ],
                state.volume_zscore + state.normalized_range * 10_000.0,
            );
        }
        let lower_sweep = state.session_range_position <= 0.20
            && state.lower_wick_ratio >= 0.50
            && state.close_location_value > 0.25;
        let upper_sweep = state.session_range_position >= 0.80
            && state.upper_wick_ratio >= 0.50
            && state.close_location_value < -0.25;
        if state.minutes_from_open >= 20
            && state.minutes_to_close >= 15
            && state.volume_zscore >= 0.75
            && (lower_sweep || upper_sweep)
        {
            push(
                SetupType::LiquiditySweepReclaim,
                if lower_sweep { 1 } else { -1 },
                vec![
                    "session_extreme_sweep",
                    "wick_rejection",
                    "volume_shock",
                    "behavioral_stop_run",
                ],
                state.volume_zscore + state.normalized_range * 10_000.0,
            );
        }
        if state.minutes_from_open >= 45
            && state.minutes_to_close > 45
            && state.dist_session_open.abs() > 0.0015
            && state.dist_vwap.abs() < 0.0008
            && state.ret_5m.signum() == state.dist_session_open.signum()
            && state.slope_15m.signum() == state.dist_session_open.signum()
            && state.rvol_same_minute >= 0.90
            && state.market_confirmation_score >= 0.0
        {
            push(
                SetupType::VwapPullback,
                state.dist_session_open.signum() as i8,
                vec![
                    "established_trend",
                    "vwap_retest",
                    "cross_asset_not_opposed",
                ],
                state.dist_session_open.abs() * 10_000.0 - state.dist_vwap.abs() * 2_000.0
                    + state.market_confirmation_score,
            );
        }
        let vwap_rejection_direction = if state.dist_vwap > 0.0
            && state.lower_wick_ratio >= 0.40
            && state.close_location_value > 0.20
        {
            1
        } else if state.dist_vwap < 0.0
            && state.upper_wick_ratio >= 0.40
            && state.close_location_value < -0.20
        {
            -1
        } else {
            0
        };
        if vwap_rejection_direction != 0
            && state.minutes_from_open >= 30
            && state.minutes_to_close >= 30
            && state.dist_vwap.abs() <= 0.0010
            && state.volume_zscore >= 0.25
        {
            push(
                SetupType::VwapRejection,
                vwap_rejection_direction,
                vec!["vwap_test", "wick_rejection", "close_location_confirmation"],
                state.volume_zscore + state.normalized_range * 10_000.0,
            );
        }
        if state.minutes_from_open >= 30
            && state.minutes_to_close > 30
            && state.ret_15m.abs() > 0.003
            && state.dist_vwap.abs() > 0.0025
            && state.volume_acceleration < 0.25
        {
            push(
                SetupType::MeanReversion,
                -(state.ret_15m.signum() as i8),
                vec![
                    "return_extreme",
                    "vwap_extension",
                    "volume_impulse_decelerating",
                ],
                state.ret_15m.abs() * 10_000.0 + state.dist_vwap.abs() * 5_000.0
                    - state.volume_acceleration.max(0.0),
            );
        }
        if is_positive_ramp_confirmation(state) {
            push(
                SetupType::ClosingShortCover,
                1,
                vec![
                    "closing_window",
                    "positive_ramp_confirmation_only",
                    "not_a_pre_event_forecast",
                    "separate_hazard_model_required",
                ],
                state.closing_short_cover_score,
            );
        }
        // The bar is observable only on its final minute. The model and past-only
        // analog layer decide whether this recurring clock-time effect is real.
        if state.minute_in_5m_bucket == 4
            && state.minutes_from_open >= 14
            && state.minutes_to_close >= 15
            && state.active_5m_return.abs() >= 0.0012
            && state.dist_vwap.abs() >= 0.0010
        {
            push(
                SetupType::TimeBucketReversal,
                -(state.active_5m_return.signum() as i8),
                vec![
                    "completed_5m_bucket",
                    "time_bucket_effect_requires_validation",
                    "extended_from_vwap",
                ],
                state.active_5m_return.abs() * 10_000.0 + state.dist_vwap.abs() * 5_000.0,
            );
        }
    }
    // Rule layer produces possible events; only the strongest, temporally distinct
    // ten per session reach expensive models. This cap is independent of outcomes.
    let mut by_day = BTreeMap::new();
    for row in raw {
        by_day
            .entry(row.0.session_date)
            .or_insert_with(Vec::new)
            .push(row);
    }
    let mut output = Vec::new();
    for (_, mut rows) in by_day {
        rows.sort_by(|a, b| b.1.total_cmp(&a.1));
        let mut kept = Vec::<Candidate>::new();
        for (candidate, _) in rows {
            if kept.len() >= 10 {
                break;
            }
            if kept.iter().any(|prior| {
                (prior.timestamp - candidate.timestamp).num_minutes().abs() < 5
                    && prior.direction == candidate.direction
            }) {
                continue;
            }
            kept.push(candidate);
        }
        output.extend(kept);
    }
    output.sort_by_key(|candidate| candidate.timestamp);
    output
}
