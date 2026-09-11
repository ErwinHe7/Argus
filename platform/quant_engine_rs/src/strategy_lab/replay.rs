use super::*;
use anyhow::{Result, ensure};
use chrono::{DateTime, NaiveDate, Utc};
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CashFlow {
    pub session_date: NaiveDate,
    pub amount: Decimal,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ReplayRequest {
    pub symbol: String,
    pub strategy: Strategy,
    pub bars: Vec<DailyBar>,
    pub evidence: Evidence,
    pub starting_capital: Decimal,
    pub commission_per_order: Decimal,
    pub slippage_bps: u32,
    #[serde(default)]
    pub cash_flows: Vec<CashFlow>,
    pub code_revision: String,
    pub dependency_versions: BTreeMap<String, String>,
    #[serde(default)]
    pub research_parameters: Option<ResearchParameters>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct JournalEvent {
    pub event_id: String,
    pub timestamp: DateTime<Utc>,
    pub kind: String,
    pub cash_delta: Decimal,
    pub quantity_delta: i64,
    pub price: Option<Decimal>,
    pub fee: Decimal,
    pub decision_id: Option<String>,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct EquityPoint {
    pub session_date: NaiveDate,
    pub cash: Decimal,
    pub quantity: u64,
    pub market_value: Decimal,
    pub equity: Decimal,
    pub external_flow: Decimal,
    pub net_return: f64,
    pub cumulative_time_weighted_return: f64,
    pub drawdown: f64,
    pub entries_paused: bool,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct CompletedTrade {
    pub entry_session: NaiveDate,
    pub exit_session: NaiveDate,
    pub quantity: u64,
    pub entry_price: Decimal,
    pub exit_price: Decimal,
    pub net_pnl: Decimal,
    pub fees: Decimal,
    pub reason: String,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ReplayMetrics {
    pub evaluation_sessions: usize,
    pub completed_trades: usize,
    pub net_time_weighted_return: f64,
    pub max_drawdown: f64,
    pub realized_pnl: Decimal,
    pub unrealized_pnl: Decimal,
    pub fees: Decimal,
    pub time_in_market_fraction: f64,
    pub largest_winner_share_of_positive_pnl: Option<f64>,
    pub top_five_winners_share_of_positive_pnl: Option<f64>,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ReplayResult {
    pub schema_version: String,
    pub run_id: String,
    pub symbol: String,
    pub strategy: Strategy,
    pub input_manifest: ReplayRequest,
    pub fill_model: String,
    pub quote_window_experiment_available: bool,
    pub evidence_status: String,
    pub execution_authorized: bool,
    pub promotion_eligible: bool,
    pub caveats: Vec<String>,
    pub decisions: Vec<Decision>,
    pub journal: Vec<JournalEvent>,
    pub equity: Vec<EquityPoint>,
    pub trades: Vec<CompletedTrade>,
    pub open_position: Option<Position>,
    pub metrics: ReplayMetrics,
}

struct ReplayState {
    cash: Decimal,
    position: Option<Position>,
    entry_fee: Decimal,
    journal: Vec<JournalEvent>,
    trades: Vec<CompletedTrade>,
    fees: Decimal,
}
impl ReplayState {
    fn equity(&self, price: Decimal) -> Result<Decimal> {
        self.cash
            .checked_add(price.quantity(self.position.as_ref().map_or(0, |p| p.quantity))?)
    }
    // One complete posting's economic fields stay explicit at this single boundary.
    #[allow(clippy::too_many_arguments)]
    fn post(
        &mut self,
        run: &str,
        at: DateTime<Utc>,
        kind: &str,
        cash_delta: Decimal,
        quantity_delta: i64,
        price: Option<Decimal>,
        fee: Decimal,
        decision_id: Option<String>,
    ) -> Result<()> {
        self.cash = self.cash.checked_add(cash_delta)?;
        ensure!(self.cash >= Decimal::ZERO, "replay cannot borrow cash");
        self.fees = self.fees.checked_add(fee)?;
        self.journal.push(JournalEvent {
            event_id: sha256(&(
                run,
                self.journal.len(),
                at,
                kind,
                cash_delta,
                quantity_delta,
            ))?,
            timestamp: at,
            kind: kind.into(),
            cash_delta,
            quantity_delta,
            price,
            fee,
            decision_id,
        });
        Ok(())
    }
    fn exit(
        &mut self,
        request: &ReplayRequest,
        run: &str,
        bar: &DailyBar,
        raw_price: Decimal,
        reason: &str,
        decision_id: Option<String>,
    ) -> Result<()> {
        let Some(position) = self.position.take() else {
            return Ok(());
        };
        let price = raw_price.checked_sub(raw_price.bps(request.slippage_bps, true)?)?;
        ensure!(price > Decimal::ZERO, "invalid simulated exit price");
        let gross = price.quantity(position.quantity)?;
        let fees = self.entry_fee.checked_add(request.commission_per_order)?;
        self.trades.push(CompletedTrade {
            entry_session: position.entry_session,
            exit_session: bar.session_date,
            quantity: position.quantity,
            entry_price: position.first_fill_price,
            exit_price: price,
            net_pnl: gross
                .checked_sub(position.first_fill_price.quantity(position.quantity)?)?
                .checked_sub(fees)?,
            fees,
            reason: reason.into(),
        });
        // Daily bars identify only the session interval for an intraday stop.
        // close_at is a reporting boundary, not a fabricated fill timestamp.
        let timestamp = if reason == "bar_stop_interval" {
            bar.close_at
        } else {
            bar.open_at
        };
        self.post(
            run,
            timestamp,
            reason,
            gross.checked_sub(request.commission_per_order)?,
            -i64::try_from(position.quantity)?,
            Some(price),
            request.commission_per_order,
            decision_id,
        )
    }
}

pub fn replay(request: &ReplayRequest) -> Result<ReplayResult> {
    ensure!(
        !request.symbol.is_empty()
            && request.symbol.len() <= 16
            && request
                .symbol
                .bytes()
                .all(|b| b.is_ascii_uppercase() || b == b'.' || b == b'-'),
        "invalid symbol"
    );
    ensure!(
        request.starting_capital > Decimal::ZERO
            && request.commission_per_order >= Decimal::ZERO
            && request.slippage_bps <= 1_000,
        "invalid simulation capital or costs"
    );
    ensure!(
        !request.code_revision.trim().is_empty() && !request.dependency_versions.is_empty(),
        "code revision and dependency receipt required"
    );
    let final_time = request
        .bars
        .last()
        .map(|b| b.available_at)
        .ok_or_else(|| anyhow::anyhow!("missing daily bars"))?;
    validate_bars(&request.bars, &request.evidence, final_time)?;
    let run_id = sha256(request)?;
    let mut flows = BTreeMap::new();
    for flow in &request.cash_flows {
        ensure!(
            request
                .bars
                .iter()
                .any(|b| b.session_date == flow.session_date),
            "cash flow outside supplied sessions"
        );
        ensure!(
            flows.insert(flow.session_date, flow.amount).is_none(),
            "combine same-session cash flows explicitly"
        );
    }
    let mut state = ReplayState {
        cash: request.starting_capital,
        position: None,
        entry_fee: Decimal::ZERO,
        journal: Vec::new(),
        trades: Vec::new(),
        fees: Decimal::ZERO,
    };
    let mut points = Vec::new();
    let mut decisions = Vec::new();
    let mut pending: Option<Decision> = None;
    let mut previous_equity = request.starting_capital;
    let mut nav = 1.0_f64;
    let mut peak_nav = 1.0_f64;
    let mut max_drawdown = 0.0_f64;
    let mut paused = false;
    let mut exposed_sessions = 0_usize;
    for (index, bar) in request.bars.iter().enumerate() {
        let flow = flows.get(&bar.session_date).copied().unwrap_or_default();
        let before_flow = state.equity(bar.open)?;
        ensure!(
            before_flow > Decimal::ZERO && previous_equity > Decimal::ZERO,
            "nonpositive account valuation"
        );
        if flow != Decimal::ZERO {
            state.post(
                &run_id,
                bar.open_at,
                "external_cash_flow",
                flow,
                0,
                None,
                Decimal::ZERO,
                None,
            )?;
        }
        let after_flow = before_flow.checked_add(flow)?;
        ensure!(
            after_flow > Decimal::ZERO,
            "cash flow exhausts simulated account"
        );
        let daily_start = previous_equity.checked_add(flow)?;
        ensure!(
            daily_start > Decimal::ZERO,
            "nonpositive cash-flow-adjusted session start"
        );
        let open_nav = nav * before_flow.as_f64() / previous_equity.as_f64();
        peak_nav = peak_nav.max(open_nav);
        if after_flow <= daily_start.checked_sub(daily_start.bps(100, false)?)?
            || open_nav / peak_nav <= 0.95
        {
            paused = true;
        }
        let mut was_exposed = state.position.is_some();
        let mut exited_today = false;
        if state
            .position
            .as_ref()
            .is_some_and(|p| bar.open <= p.current_stop)
        {
            state.exit(request, &run_id, bar, bar.open, "gap_through_stop", None)?;
            exited_today = true;
        }
        if let Some(intent) = pending.take() {
            ensure!(
                intent.eligible_after < bar.open_at,
                "signal unavailable before simulated entry"
            );
            if intent.action == Action::ExitLong && state.position.is_some() {
                state.exit(
                    request,
                    &run_id,
                    bar,
                    bar.open,
                    "scheduled_exit",
                    Some(intent.decision_id),
                )?;
                exited_today = true;
            } else if intent.action == Action::EnterLong
                && state.position.is_none()
                && !exited_today
                && !paused
            {
                let fill = bar
                    .open
                    .checked_add(bar.open.bps(request.slippage_bps, true)?)?;
                let equity = state.equity(bar.open)?;
                let peak_equity = Decimal::positive_ceil(equity.as_f64() * peak_nav / open_nav)?;
                let size = size_entry(&SizeRequest {
                    strategy: request.strategy,
                    equity,
                    cash: state.cash,
                    gross_exposure: Decimal::ZERO,
                    pending_commitment: Decimal::ZERO,
                    entry_price: fill,
                    signal_atr: request
                        .research_parameters
                        .as_ref()
                        .map_or(Ok(intent.signal_atr.unwrap()), |p| {
                            p.adjusted_atr(request.strategy, intent.signal_atr.unwrap())
                        })?,
                    daily_start_equity: daily_start,
                    peak_equity: peak_equity.max(equity),
                    paused,
                    commission_per_order: request.commission_per_order,
                    slippage_bps: request.slippage_bps,
                })?;
                if size.eligible {
                    state.entry_fee = request.commission_per_order;
                    let debit = fill
                        .quantity(size.quantity)?
                        .checked_add(request.commission_per_order)?;
                    state.post(
                        &run_id,
                        bar.open_at,
                        "entry_fill",
                        Decimal::ZERO.checked_sub(debit)?,
                        i64::try_from(size.quantity)?,
                        Some(fill),
                        request.commission_per_order,
                        Some(intent.decision_id),
                    )?;
                    state.position = Some(Position {
                        quantity: size.quantity,
                        first_fill_price: fill,
                        initial_stop: size.initial_stop.unwrap(),
                        current_stop: size.initial_stop.unwrap(),
                        entry_session: bar.session_date,
                        highest_close: Decimal::ZERO,
                        held_sessions: 0,
                    });
                    was_exposed = true;
                }
            }
        }
        if let Some(stop) = state
            .position
            .as_ref()
            .filter(|p| bar.low <= p.current_stop)
            .map(|p| p.current_stop)
        {
            state.exit(request, &run_id, bar, stop, "bar_stop_interval", None)?;
            exited_today = true;
        }
        if let Some(position) = &mut state.position {
            position.held_sessions += 1;
            position.highest_close = position.highest_close.max(bar.close);
        }
        let equity = state.equity(bar.close)?;
        ensure!(equity > Decimal::ZERO, "account insolvent");
        let growth =
            before_flow.as_f64() / previous_equity.as_f64() * equity.as_f64() / after_flow.as_f64();
        nav *= growth;
        ensure!(
            growth.is_finite() && nav.is_finite(),
            "nonfinite time-weighted return"
        );
        peak_nav = peak_nav.max(nav);
        let drawdown = nav / peak_nav - 1.0;
        max_drawdown = max_drawdown.min(drawdown);
        if equity <= daily_start.checked_sub(daily_start.bps(100, false)?)? || drawdown <= -0.05 {
            paused = true;
        }
        if was_exposed {
            exposed_sessions += 1;
        }
        let evaluation = EvaluateRequest {
            strategy: request.strategy,
            as_of: bar.available_at,
            bars: request.bars[..=index].to_vec(),
            evidence: request.evidence.clone(),
            position: state.position.clone(),
            pending_entry: false,
            history_mode: HistoryMode::PointInTime,
        };
        let mut decision = evaluate_research(&evaluation, request.research_parameters.as_ref())?;
        if decision.action == Action::EnterLong && (paused || exited_today) {
            decision.action = Action::Hold;
            decision.reason = if paused {
                "risk_pause_latched"
            } else {
                "same_session_reentry_blocked"
            }
            .into();
        }
        if let Some(position) = &mut state.position
            && let Some(stop) = decision.stop_price
        {
            position.current_stop = stop;
        }
        if decision.action != Action::Hold {
            pending = Some(decision.clone());
        }
        decisions.push(decision);
        let quantity = state.position.as_ref().map_or(0, |p| p.quantity);
        points.push(EquityPoint {
            session_date: bar.session_date,
            cash: state.cash,
            quantity,
            market_value: bar.close.quantity(quantity)?,
            equity,
            external_flow: flow,
            net_return: growth - 1.0,
            cumulative_time_weighted_return: nav - 1.0,
            drawdown,
            entries_paused: paused,
        });
        previous_equity = equity;
    }
    let realized = state
        .trades
        .iter()
        .try_fold(Decimal::ZERO, |sum, t| sum.checked_add(t.net_pnl))?;
    let unrealized = if let Some(position) = &state.position {
        request
            .bars
            .last()
            .unwrap()
            .close
            .checked_sub(position.first_fill_price)?
            .quantity(position.quantity)?
            .checked_sub(state.entry_fee)?
    } else {
        Decimal::ZERO
    };
    let mut winners: Vec<f64> = state
        .trades
        .iter()
        .filter(|t| t.net_pnl > Decimal::ZERO)
        .map(|t| t.net_pnl.as_f64())
        .collect();
    winners.sort_by(|a, b| b.total_cmp(a));
    let positive_pnl: f64 = winners.iter().sum();
    let evaluation_sessions = request.bars.len().saturating_sub(WARMUP);
    let metrics = ReplayMetrics {
        evaluation_sessions,
        completed_trades: state.trades.len(),
        net_time_weighted_return: nav - 1.0,
        max_drawdown,
        realized_pnl: realized,
        unrealized_pnl: unrealized,
        fees: state.fees,
        time_in_market_fraction: if evaluation_sessions == 0 {
            0.0
        } else {
            exposed_sessions as f64 / evaluation_sessions as f64
        },
        largest_winner_share_of_positive_pnl: (positive_pnl > 0.0)
            .then(|| winners[0] / positive_pnl),
        top_five_winners_share_of_positive_pnl: (positive_pnl > 0.0)
            .then(|| winners.iter().take(5).sum::<f64>() / positive_pnl),
    };
    Ok(ReplayResult { schema_version: VERSION.into(), run_id, symbol: request.symbol.clone(), strategy: request.strategy, input_manifest: request.clone(),
        fill_model: "DAILY_OPEN_PROXY_WITH_BAR_STOP_AND_ADVERSE_GAPS".into(), quote_window_experiment_available: false,
        evidence_status: if request.evidence.classification == DataClass::SyntheticFixture { "SYNTHETIC_ENGINEERING_FIXTURE_NOT_PERFORMANCE" } else { "EXPLORATORY_NOT_PROMOTED" }.into(),
        execution_authorized: false, promotion_eligible: false,
        caveats: vec![
            "Daily-open proxy differs from the 09:35-09:40 quote-window experiment; no intraday quote precision is claimed.".into(),
            "Intraday stop event timestamps are session reporting boundaries. No partial-fill, queue, market-impact or halted-market model is available from daily bars.".into(),
            "Cash settlement is idealized immediate settled simulation cash; broker buying-power and settlement must gate paper execution separately.".into(),
            "Split-adjusted price-return research only; cash dividends are not modeled. External cash_flows must never be used for dividends. No total-return comparison is claimed.".into(),
            "Pauses latch through the run; stops and scheduled exits continue. Final open holdings are marked at the last observed close, not forcibly liquidated.".into(),
            "Source attestations and hashes identify the supplied inputs; they are not vendor entitlement verification or untouched-holdout proof.".into(),
        ], decisions, journal: state.journal, equity: points, trades: state.trades, open_position: state.position, metrics,
    })
}
