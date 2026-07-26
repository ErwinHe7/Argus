use chrono::{DateTime, Utc};

use crate::{
    config::ResearchConfig,
    domain::{OptionFill, OptionQuote},
};

fn quote_rejection(
    quote: &OptionQuote,
    now: DateTime<Utc>,
    config: &ResearchConfig,
) -> Option<String> {
    if quote.bid <= 0.0 {
        return Some("nonpositive_bid".to_string());
    }
    if quote.ask <= quote.bid {
        return Some("crossed_or_locked_market".to_string());
    }
    if quote.bid_size == 0 || quote.ask_size == 0 {
        return Some("no_displayed_liquidity".to_string());
    }
    if quote.spread_pct() > config.option_max_spread_pct {
        return Some("spread_too_wide".to_string());
    }
    if (now - quote.timestamp).num_seconds().abs() > config.option_max_staleness_seconds {
        return Some("stale_quote".to_string());
    }
    None
}

pub fn simulate_long_option(
    signal_time: DateTime<Utc>,
    planned_exit_time: DateTime<Utc>,
    entry: &OptionQuote,
    exit: &OptionQuote,
    config: &ResearchConfig,
) -> OptionFill {
    simulate_long_option_size(signal_time, planned_exit_time, entry, exit, 1, config)
}

pub fn simulate_long_option_size(
    signal_time: DateTime<Utc>,
    planned_exit_time: DateTime<Utc>,
    entry: &OptionQuote,
    exit: &OptionQuote,
    requested_contracts: u32,
    config: &ResearchConfig,
) -> OptionFill {
    if requested_contracts == 0 {
        return OptionFill {
            option_symbol: entry.option_symbol.clone(),
            entry_fill: 0.0,
            exit_fill: 0.0,
            gross_pnl_per_contract: 0.0,
            requested_contracts,
            filled_contracts: 0,
            fill_status: "NO_FILL".to_string(),
            rejected_reason: Some("zero_requested_quantity".to_string()),
        };
    }
    let rejected = if entry.timestamp <= signal_time {
        Some("entry_not_after_signal".to_string())
    } else if (entry.timestamp - signal_time).num_seconds() > config.option_max_staleness_seconds {
        Some("no_fresh_entry_quote".to_string())
    } else if entry.option_symbol != exit.option_symbol {
        Some("contract_mismatch".to_string())
    } else if exit.timestamp < planned_exit_time || exit.timestamp <= entry.timestamp {
        Some("exit_quote_before_planned_exit".to_string())
    } else if (exit.timestamp - planned_exit_time).num_seconds()
        > config.option_max_staleness_seconds
    {
        Some("no_fresh_exit_quote".to_string())
    } else {
        quote_rejection(entry, entry.timestamp, config)
            .or_else(|| quote_rejection(exit, exit.timestamp, config))
    };
    if let Some(reason) = rejected {
        return OptionFill {
            option_symbol: entry.option_symbol.clone(),
            entry_fill: 0.0,
            exit_fill: 0.0,
            gross_pnl_per_contract: 0.0,
            requested_contracts,
            filled_contracts: 0,
            fill_status: "NO_FILL".to_string(),
            rejected_reason: Some(reason),
        };
    }
    let filled_contracts = requested_contracts.min(entry.ask_size).min(exit.bid_size);
    if filled_contracts == 0 {
        return OptionFill {
            option_symbol: entry.option_symbol.clone(),
            entry_fill: 0.0,
            exit_fill: 0.0,
            gross_pnl_per_contract: 0.0,
            requested_contracts,
            filled_contracts: 0,
            fill_status: "NO_FILL".to_string(),
            rejected_reason: Some("insufficient_visible_size".to_string()),
        };
    }
    let entry_fill = entry.ask + config.option_slippage;
    let exit_fill = (exit.bid - config.option_slippage).max(0.0);
    OptionFill {
        option_symbol: entry.option_symbol.clone(),
        entry_fill,
        exit_fill,
        gross_pnl_per_contract: (exit_fill - entry_fill) * 100.0,
        requested_contracts,
        filled_contracts,
        fill_status: if filled_contracts < requested_contracts {
            "PARTIAL_FILL".to_string()
        } else {
            "FILLED".to_string()
        },
        rejected_reason: None,
    }
}
