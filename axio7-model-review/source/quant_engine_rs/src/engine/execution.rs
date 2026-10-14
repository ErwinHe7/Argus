use chrono::{DateTime, Utc};

use crate::{
    config::ResearchConfig,
    domain::{OptionFill, OptionQuote, TransactionCostBreakdown},
};

fn quote_rejection(quote: &OptionQuote, config: &ResearchConfig) -> Option<&'static str> {
    if [quote.bid, quote.ask, quote.strike, quote.underlying_price]
        .iter()
        .any(|v| !v.is_finite())
    {
        return Some("nonfinite_quote");
    }
    if quote.bid <= 0.0 || quote.strike <= 0.0 || quote.underlying_price <= 0.0 {
        return Some("nonpositive_quote");
    }
    if quote.ask <= quote.bid {
        return Some("crossed_or_locked_market");
    }
    if quote.bid_size == 0 || quote.ask_size == 0 {
        return Some("no_displayed_liquidity");
    }
    if quote.spread_pct() > config.option_max_spread_pct {
        return Some("spread_too_wide");
    }
    if quote.timestamp.date_naive() > quote.expiry {
        return Some("expired_contract");
    }
    None
}

fn empty_fill(entry: &OptionQuote, requested_contracts: u32, reason: &str) -> OptionFill {
    OptionFill {
        option_symbol: entry.option_symbol.clone(),
        entry_fill: 0.0,
        exit_fill: 0.0,
        gross_pnl_per_contract: 0.0,
        mid_gross_pnl_per_contract: None,
        net_pnl_per_contract: None,
        net_pnl_total: None,
        cost_breakdown: None,
        requested_contracts,
        filled_contracts: 0,
        exit_filled_contracts: 0,
        unliquidated_contracts: 0,
        fill_status: "NO_FILL".to_string(),
        rejected_reason: Some(reason.to_string()),
    }
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
        return empty_fill(entry, requested_contracts, "zero_requested_quantity");
    }
    if config.validate_execution_costs().is_err() {
        return empty_fill(entry, requested_contracts, "invalid_execution_cost_config");
    }
    let costs = &config.execution_costs;
    let entry_delay = (entry.timestamp - signal_time).num_milliseconds();
    let rejected = if entry_delay <= 0 {
        Some("entry_not_after_signal")
    } else if entry_delay < costs.latency_ms {
        Some("entry_before_latency")
    } else if entry_delay > config.option_max_staleness_seconds.saturating_mul(1000) {
        Some("no_fresh_entry_quote")
    } else if planned_exit_time <= entry.timestamp {
        Some("planned_exit_not_after_entry")
    } else {
        quote_rejection(entry, config)
    };
    if let Some(reason) = rejected {
        return empty_fill(entry, requested_contracts, reason);
    }

    // Entry size must never depend on the future exit quote.
    let entry_capacity =
        (f64::from(entry.ask_size) * costs.option_max_participation_rate).floor() as u32;
    let filled_contracts = requested_contracts.min(entry_capacity);
    if filled_contracts == 0 {
        return empty_fill(entry, requested_contracts, "insufficient_visible_size");
    }
    let entry_impact = costs.option_impact_at_full_participation * f64::from(filled_contracts)
        / f64::from(entry.ask_size);
    let entry_fill = entry.ask + config.option_slippage + entry_impact;
    if !entry_fill.is_finite() {
        return empty_fill(entry, requested_contracts, "nonfinite_execution_arithmetic");
    }

    let mut fill = empty_fill(entry, requested_contracts, "unliquidated_position");
    fill.entry_fill = entry_fill;
    fill.filled_contracts = filled_contracts;
    fill.unliquidated_contracts = filled_contracts;
    fill.fill_status = "UNLIQUIDATED".to_string();
    let exit_delay = (exit.timestamp - planned_exit_time).num_milliseconds();
    let rejected = if entry.option_symbol != exit.option_symbol
        || entry.underlying != exit.underlying
        || entry.expiry != exit.expiry
        || entry.strike != exit.strike
        || entry.call_put != exit.call_put
    {
        Some("contract_mismatch")
    } else if exit.timestamp <= entry.timestamp || exit_delay < 0 {
        Some("exit_quote_before_planned_exit")
    } else if exit_delay < costs.latency_ms {
        Some("exit_before_latency")
    } else if exit_delay > config.option_max_staleness_seconds.saturating_mul(1000) {
        Some("no_fresh_exit_quote")
    } else {
        quote_rejection(exit, config)
    };
    if let Some(reason) = rejected {
        fill.rejected_reason = Some(reason.to_string());
        return fill;
    }

    let exit_capacity =
        (f64::from(exit.bid_size) * costs.option_max_participation_rate).floor() as u32;
    let exit_filled_contracts = filled_contracts.min(exit_capacity);
    if exit_filled_contracts == 0 {
        fill.rejected_reason = Some("insufficient_exit_visible_size".to_string());
        return fill;
    }
    let exit_impact = costs.option_impact_at_full_participation * f64::from(exit_filled_contracts)
        / f64::from(exit.bid_size);
    let exit_fill = exit.bid - config.option_slippage - exit_impact;
    if !exit_fill.is_finite() || exit_fill <= 0.0 {
        fill.rejected_reason = Some("nonpositive_or_nonfinite_exit_fill".to_string());
        return fill;
    }
    fill.exit_fill = exit_fill;
    fill.exit_filled_contracts = exit_filled_contracts;
    fill.unliquidated_contracts = filled_contracts - exit_filled_contracts;
    if fill.unliquidated_contracts > 0 {
        fill.rejected_reason = Some("insufficient_exit_visible_size".to_string());
        return fill;
    }
    let spread_cost = ((entry.ask - entry.bid) + (exit.ask - exit.bid)) * 50.0;
    let slippage_cost = 2.0 * config.option_slippage * 100.0;
    let market_impact_cost = (entry_impact + exit_impact) * 100.0;
    let commission_cost = 2.0 * costs.option_commission_per_contract_per_side;
    let total_cost = spread_cost + slippage_cost + market_impact_cost + commission_cost;
    let mid_gross = (exit.mid() - entry.mid()) * 100.0;
    let execution_pnl = (exit_fill - entry_fill) * 100.0;
    let net = mid_gross - total_cost;
    let net_total = net * f64::from(filled_contracts);
    if [total_cost, mid_gross, execution_pnl, net, net_total]
        .iter()
        .any(|v| !v.is_finite())
    {
        fill.rejected_reason = Some("nonfinite_execution_arithmetic".to_string());
        fill.fill_status = "INVALID_ECONOMICS".to_string();
        return fill;
    }
    fill.gross_pnl_per_contract = execution_pnl;
    fill.mid_gross_pnl_per_contract = Some(mid_gross);
    fill.net_pnl_per_contract = Some(net);
    fill.net_pnl_total = Some(net_total);
    fill.cost_breakdown = Some(TransactionCostBreakdown {
        spread_cost,
        slippage_cost,
        market_impact_cost,
        commission_cost,
        total_cost,
    });
    fill.fill_status = if filled_contracts < requested_contracts {
        "PARTIAL_FILL"
    } else {
        "FILLED"
    }
    .to_string();
    fill.rejected_reason = None;
    fill
}
