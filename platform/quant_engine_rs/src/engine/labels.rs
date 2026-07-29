use crate::domain::{MarketState, Outcome};

pub fn forward_outcomes(states: &[MarketState], horizon: usize) -> Vec<Outcome> {
    let mut output = Vec::new();
    for idx in 0..states.len().saturating_sub(1) {
        let entry_idx = idx + 1;
        // A H-minute label contains exactly H executable one-minute bars:
        // t+1 .. t+H. Using entry_idx + horizon would silently include H+1.
        let end_idx = (entry_idx + horizon.saturating_sub(1)).min(states.len() - 1);
        if states[entry_idx].session_date != states[idx].session_date
            || states[end_idx].session_date != states[idx].session_date
        {
            continue;
        }
        let entry = states[entry_idx].open;
        let window = &states[entry_idx..=end_idx];
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
