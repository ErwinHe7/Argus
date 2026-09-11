use super::*;

struct State {
    cash: Decimal,
    fees: Decimal,
    cycle_pnl: Decimal,
    exit_pnl: Decimal,
    peak: Decimal,
    max_drawdown: f64,
    loss_latched: bool,
    slots: Vec<GridSlot>,
    journal: Vec<GridEvent>,
    configuration_hash: String,
}

impl State {
    fn quantity(&self) -> u64 {
        self.slots.iter().map(|s| s.held_quantity).sum()
    }
    fn marked(&self, price: Decimal) -> Result<Decimal> {
        self.cash.checked_add(price.quantity(self.quantity())?)
    }
    fn unrealized(&self, price: Decimal) -> Result<Decimal> {
        self.slots.iter().try_fold(Decimal::ZERO, |total, slot| {
            let Some(entry) = slot.entry_price else {
                return Ok(total);
            };
            total.checked_add(
                price
                    .checked_sub(entry)?
                    .quantity(slot.held_quantity)?
                    .checked_sub(slot.entry_fee)?,
            )
        })
    }
    #[allow(clippy::too_many_arguments)]
    fn event(
        &mut self,
        bar: &GridBar,
        at: DateTime<Utc>,
        slot: Option<usize>,
        kind: &str,
        reason: &str,
        quantity: i64,
        price: Option<Decimal>,
        cash_delta: Decimal,
        fee: Decimal,
    ) -> Result<()> {
        ensure!(
            self.journal.len() < 100_000,
            "grid event limit exceeded; use a shorter research window"
        );
        self.cash = self.cash.checked_add(cash_delta)?;
        ensure!(self.cash >= Decimal::ZERO, "grid ledger cannot borrow cash");
        self.fees = self.fees.checked_add(fee)?;
        let event_id = hash(&(
            &self.configuration_hash,
            self.journal.len(),
            at,
            slot,
            kind,
            quantity,
            price,
            cash_delta,
        ))?;
        self.journal.push(GridEvent {
            event_id,
            at,
            session_date: bar.session_date,
            slot_id: slot,
            kind: kind.into(),
            reason: reason.into(),
            quantity_delta: quantity,
            price,
            cash_delta,
            fee,
        });
        Ok(())
    }
    fn notice(
        &mut self,
        bar: &GridBar,
        at: DateTime<Utc>,
        slot: Option<usize>,
        kind: &str,
        reason: &str,
    ) -> Result<()> {
        self.event(
            bar,
            at,
            slot,
            kind,
            reason,
            0,
            None,
            Decimal::ZERO,
            Decimal::ZERO,
        )
    }
    fn sell(
        &mut self,
        request: &GridReplayRequest,
        bar: &GridBar,
        slot_id: usize,
        price: Decimal,
        liquidating: bool,
    ) -> Result<()> {
        let slot = &self.slots[slot_id];
        let quantity = slot.held_quantity;
        let basis = slot
            .entry_price
            .ok_or_else(|| anyhow::anyhow!("missing owned lot basis"))?
            .quantity(quantity)?
            .checked_add(slot.entry_fee)?;
        let proceeds = price
            .quantity(quantity)?
            .checked_sub(request.commission_per_order)?;
        let pnl = proceeds.checked_sub(basis)?;
        if liquidating {
            self.exit_pnl = self.exit_pnl.checked_add(pnl)?;
        } else {
            self.cycle_pnl = self.cycle_pnl.checked_add(pnl)?;
        }
        self.event(
            bar,
            bar.open_at,
            Some(slot_id),
            if liquidating {
                "loss_exit_fill"
            } else {
                "sell_fill"
            },
            if liquidating {
                "latched_portfolio_loss_next_observed_open"
            } else {
                "prior_close_sell_limit_eligible_at_open"
            },
            -i64::try_from(quantity)?,
            Some(price),
            proceeds,
            request.commission_per_order,
        )?;
        let slot = &mut self.slots[slot_id];
        slot.held_quantity = 0;
        slot.entry_price = None;
        slot.entry_fee = Decimal::ZERO;
        slot.pending = None;
        if !liquidating {
            slot.completed_cycles += 1;
        }
        Ok(())
    }
}

fn adverse(price: Decimal, bps: u32, buy: bool) -> Result<Decimal> {
    let cost = price.bps(bps, true)?;
    let result = if buy {
        price.checked_add(cost)?
    } else {
        price.checked_sub(cost)?
    };
    ensure!(
        result > Decimal::ZERO,
        "cost assumption produces a nonpositive fill price"
    );
    Ok(result)
}

fn benchmark(request: &GridReplayRequest) -> Result<GridBenchmarks> {
    // The first close is the common configuration/observation boundary.
    // Buy-and-hold first becomes investable at the second bar's open.
    let price = adverse(request.bars[1].open, request.slippage_bps, true)?;
    let available = request
        .starting_capital
        .checked_sub(request.commission_per_order)?;
    let quantity = if available > Decimal::ZERO {
        u64::try_from(available.0 / price.0)?
    } else {
        0
    };
    let mut cash = request.starting_capital;
    if quantity > 0 {
        cash = cash
            .checked_sub(price.quantity(quantity)?)?
            .checked_sub(request.commission_per_order)?;
    }
    let equity = cash.checked_add(request.bars.last().unwrap().close.quantity(quantity)?)?;
    Ok(GridBenchmarks {
        cash_ending_equity: request.starting_capital,
        cash_total_return: 0.0,
        buy_and_hold_ending_equity: equity,
        buy_and_hold_total_return: equity.checked_sub(request.starting_capital)?.as_f64()
            / request.starting_capital.as_f64(),
    })
}

pub fn replay(request: &GridReplayRequest) -> Result<GridReplayResult> {
    validate(request)?;
    let levels = levels(request)?;
    let budget = Decimal(request.starting_capital.0 / i64::try_from(request.intervals)?);
    let round_trip_fees = request.commission_per_order.quantity(2)?;
    ensure!(
        budget > round_trip_fees,
        "slot allocation cannot reserve round-trip fees"
    );
    let spendable = budget.checked_sub(round_trip_fees)?;
    let slots = (0..request.intervals)
        .map(|i| -> Result<GridSlot> {
            let quantity = u64::try_from(spendable.0 / levels[i].0)?;
            ensure!(
                quantity > 0,
                "capital insufficient for one whole share per grid slot plus fees"
            );
            Ok(GridSlot {
                slot_id: i,
                buy_level: levels[i],
                sell_level: levels[i + 1],
                budget,
                quantity_per_cycle: quantity,
                held_quantity: 0,
                entry_price: None,
                entry_fee: Decimal::ZERO,
                completed_cycles: 0,
                pending: None,
            })
        })
        .collect::<Result<Vec<_>>>()?;
    let mut configuration = serde_json::to_value(request)?;
    configuration.as_object_mut().unwrap().remove("bars");
    // Dataset/as-of changes must not alter preceding decisions or event IDs.
    let mut frozen_rules = configuration.clone();
    frozen_rules.as_object_mut().unwrap().remove("as_of");
    frozen_rules
        .as_object_mut()
        .unwrap()
        .remove("source_evidence");
    let configuration_hash = hash(&frozen_rules)?;
    let mut state = State {
        cash: request.starting_capital,
        fees: Decimal::ZERO,
        cycle_pnl: Decimal::ZERO,
        exit_pnl: Decimal::ZERO,
        peak: request.starting_capital,
        max_drawdown: 0.0,
        loss_latched: false,
        slots,
        journal: vec![],
        configuration_hash: configuration_hash.clone(),
    };
    let loss_threshold = request.starting_capital.checked_sub(
        request
            .starting_capital
            .bps(request.portfolio_loss_limit_bps, true)?,
    )?;
    let mut equity = Vec::with_capacity(request.bars.len());
    let mut range_breaches = 0;
    for (index, bar) in request.bars.iter().enumerate() {
        // All proposals here were created by an earlier completed close.
        // Liquidation has priority and consumes the original lots only.
        if state.loss_latched && state.quantity() > 0 {
            let price = adverse(bar.open, request.slippage_bps, false)?;
            for slot in 0..state.slots.len() {
                if state.slots[slot].held_quantity > 0 {
                    state.sell(request, bar, slot, price, true)?;
                }
            }
        } else if index > 0 && !state.loss_latched {
            // Prior sell proposals release cash before independent buy proposals.
            for slot in 0..state.slots.len() {
                if state.slots[slot].pending == Some(Pending::Sell) {
                    state.slots[slot].pending = None;
                    let price = adverse(bar.open, request.slippage_bps, false)?;
                    if price >= state.slots[slot].sell_level {
                        state.sell(request, bar, slot, price, false)?;
                    } else {
                        state.notice(
                            bar,
                            bar.open_at,
                            Some(slot),
                            "sell_expired",
                            "next_open_below_sell_limit",
                        )?;
                    }
                }
            }
            for slot in 0..state.slots.len() {
                if state.slots[slot].pending != Some(Pending::Buy) {
                    continue;
                }
                state.slots[slot].pending = None;
                let price = adverse(bar.open, request.slippage_bps, true)?;
                let quantity = state.slots[slot].quantity_per_cycle;
                let debit = price
                    .quantity(quantity)?
                    .checked_add(request.commission_per_order)?;
                let reserve = request.commission_per_order.quantity(
                    state.slots.iter().filter(|s| s.held_quantity > 0).count() as u64 + 1,
                )?;
                if bar.open < request.lower || bar.open > request.upper {
                    state.notice(
                        bar,
                        bar.open_at,
                        Some(slot),
                        "buy_expired",
                        "opening_price_outside_frozen_range",
                    )?;
                } else if price > state.slots[slot].buy_level {
                    state.notice(
                        bar,
                        bar.open_at,
                        Some(slot),
                        "buy_expired",
                        "adverse_open_above_buy_limit",
                    )?;
                } else if debit.checked_add(reserve)? > state.cash {
                    state.notice(
                        bar,
                        bar.open_at,
                        Some(slot),
                        "buy_expired",
                        "cash_or_exit_fee_reserve_insufficient",
                    )?;
                } else {
                    state.event(
                        bar,
                        bar.open_at,
                        Some(slot),
                        "buy_fill",
                        "prior_downward_close_crossing_next_open_limit",
                        i64::try_from(quantity)?,
                        Some(price),
                        Decimal::ZERO.checked_sub(debit)?,
                        request.commission_per_order,
                    )?;
                    state.slots[slot].held_quantity = quantity;
                    state.slots[slot].entry_price = Some(price);
                    state.slots[slot].entry_fee = request.commission_per_order;
                }
            }
        }
        let marked = state.marked(bar.close)?;
        if !state.loss_latched && marked <= loss_threshold {
            state.loss_latched = true;
            for slot in &mut state.slots {
                slot.pending = None;
            }
            state.notice(
                bar,
                bar.available_at,
                None,
                "loss_latched",
                "marked_equity_reached_fixed_starting_capital_loss_limit; exit_next_observed_open",
            )?;
        }
        let out_of_range = bar.close < request.lower || bar.close > request.upper;
        if out_of_range {
            range_breaches += 1;
        }
        if !state.loss_latched && index > 0 {
            for slot in 0..state.slots.len() {
                if state.slots[slot].held_quantity > 0 && bar.close >= state.slots[slot].sell_level
                {
                    state.slots[slot].pending = Some(Pending::Sell);
                    state.notice(
                        bar,
                        bar.available_at,
                        Some(slot),
                        "sell_proposed",
                        "completed_close_at_or_above_upper_slot_level",
                    )?;
                } else if state.slots[slot].held_quantity == 0
                    && !out_of_range
                    && request.bars[index - 1].close > state.slots[slot].buy_level
                    && bar.close <= state.slots[slot].buy_level
                {
                    state.slots[slot].pending = Some(Pending::Buy);
                    state.notice(
                        bar,
                        bar.available_at,
                        Some(slot),
                        "buy_proposed",
                        "completed_close_crossed_down_through_lower_slot_level",
                    )?;
                }
            }
        }
        if marked > state.peak {
            state.peak = marked;
        }
        let drawdown = state.peak.checked_sub(marked)?.as_f64() / state.peak.as_f64();
        state.max_drawdown = state.max_drawdown.max(drawdown);
        let pnl = marked.checked_sub(request.starting_capital)?;
        let unrealized = state.unrealized(bar.close)?;
        ensure!(
            state
                .cycle_pnl
                .checked_add(state.exit_pnl)?
                .checked_add(unrealized)?
                == pnl,
            "grid P&L decomposition failed"
        );
        equity.push(GridEquity {
            session_date: bar.session_date,
            at: bar.available_at,
            cash: state.cash,
            quantity: state.quantity(),
            market_value: bar.close.quantity(state.quantity())?,
            equity: marked,
            total_pnl: pnl,
            total_return: pnl.as_f64() / request.starting_capital.as_f64(),
            drawdown,
            realized_cycle_pnl: state.cycle_pnl,
            realized_exit_pnl: state.exit_pnl,
            unrealized_pnl: unrealized,
            fees: state.fees,
            loss_latched: state.loss_latched,
            out_of_range,
        });
    }
    let final_point = equity.last().unwrap();
    let benchmarks = benchmark(request)?;
    let metrics = GridMetrics {
        sessions: equity.len(),
        completed_cycles: state.slots.iter().map(|s| s.completed_cycles).sum(),
        open_slots: state.slots.iter().filter(|s| s.held_quantity > 0).count(),
        ending_cash: state.cash,
        ending_quantity: state.quantity(),
        ending_equity: final_point.equity,
        total_pnl: final_point.total_pnl,
        total_return: final_point.total_return,
        max_drawdown: state.max_drawdown,
        realized_cycle_pnl: state.cycle_pnl,
        realized_exit_pnl: state.exit_pnl,
        unrealized_pnl: final_point.unrealized_pnl,
        fees: state.fees,
        loss_latched: state.loss_latched,
        pending_liquidation: state.loss_latched && state.quantity() > 0,
        range_breach_sessions: range_breaches,
        return_bps: final_point.total_return * 10_000.0,
        buy_hold_return_bps: benchmarks.buy_and_hold_total_return * 10_000.0,
        realized_loss_exit_pnl: state.exit_pnl,
        cash: state.cash,
        marked_inventory: final_point.market_value,
        equity: final_point.equity,
        max_drawdown_bps: state.max_drawdown * 10_000.0,
        range_breaches,
    };
    Ok(GridReplayResult { schema_version: "leo-grid-result.v1".into(), strategy: "GRID-R1".into(), run_id: hash(request)?, configuration_hash, canonical_bars_sha256: hash(&request.bars)?, configuration, fill_model: "DAILY_CLOSE_SIGNAL_NEXT_OPEN_LIMIT_APPROXIMATION".into(), evidence_status: match request.source_evidence.classification { Classification::Observed => "USER_SUPPLIED_OBSERVED_NOT_INDEPENDENTLY_VERIFIED", Classification::SyntheticFixture => "SYNTHETIC_DEMONSTRATION" }.into(), execution_authorized: false, paper_execution_available: false, promotion_eligible: false, limitations: vec![
        "Daily closes signal next-observed-open limits; intraday high/low paths and repeated intraday grid cycles are never inferred.".into(),
        "Opening prices plus modeled slippage approximate full fills; quotes, queue priority, partial fills and broker operation are not validated.".into(),
        "Source, adjustment, completeness, calendar and point-in-time availability are supplied declarations, not independently verified provenance; the declared dataset hash is not treated as authentication.".into(),
        "Whole shares, cash-start inventory and fixed slot quantities; no leverage, martingale, automatic range changes or reinvestment sizing.".into(),
        "A loss threshold is observed only at completed closes and liquidated at the next supplied open; gaps can exceed the threshold. A final pending liquidation remains marked exposure.".into(),
        "The ledger excludes deposits, withdrawals, dividends, taxes, interest and corporate-action cash flows. Split-adjusted prices are a research convention, not historical executable prices.".into(),
        "Total P&L includes open inventory; completed-cycle profit alone does not measure performance. Buy-and-hold buys at the second observed open with the same modeled entry costs and marks its remaining inventory.".into(),
        "No out-of-sample promotion, profitability conclusion or grid broker execution is established by this replay.".into(),
    ], levels, slots: state.slots, journal: state.journal, equity, metrics, benchmarks })
}
