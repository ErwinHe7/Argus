use crate::domain::{MarketState, Outcome};

pub fn forward_outcomes(states: &[MarketState], horizon: usize) -> Vec<Outcome> {
    let mut output = Vec::new();
    if horizon == 0 {
        return output;
    }
    for idx in 0..states.len().saturating_sub(1) {
        let entry_idx = idx + 1;
        // A H-minute label contains exactly H executable one-minute bars:
        // t+1 .. t+H. Using entry_idx + horizon would silently include H+1.
        let Some(end_idx) = entry_idx
            .checked_add(horizon - 1)
            .filter(|end_idx| *end_idx < states.len())
        else {
            continue;
        };
        let window = &states[entry_idx..=end_idx];
        if window.iter().any(|state| {
            state.session_date != states[idx].session_date
                || state.symbol != states[idx].symbol
                || [state.open, state.high, state.low, state.close]
                    .iter()
                    .any(|price| !price.is_finite() || *price <= 0.0)
                || state.high < state.open.max(state.close)
                || state.low > state.open.min(state.close)
                || state.high < state.low
        }) || states[idx..=end_idx]
            .windows(2)
            .any(|pair| pair[1].timestamp - pair[0].timestamp != chrono::Duration::minutes(1))
        {
            continue;
        }
        let entry = states[entry_idx].open;
        let final_return = states[end_idx].close / entry - 1.0;
        let mfe = window
            .iter()
            .map(|s| s.high / entry - 1.0)
            .fold(f64::NEG_INFINITY, f64::max);
        let mae = -window
            .iter()
            .map(|s| s.low / entry - 1.0)
            .fold(f64::INFINITY, f64::min)
            .min(0.0);
        if [final_return, mfe, mae]
            .iter()
            .any(|value| !value.is_finite())
        {
            continue;
        }
        output.push(Outcome {
            state_index: idx,
            entry_timestamp: states[entry_idx].timestamp,
            horizon_minutes: horizon,
            directional_return: final_return,
            mfe,
            mae,
        });
    }
    output
}
