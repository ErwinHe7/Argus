use crate::{
    core::money,
    protocol::{BrokerOrder, Deployment, Event, OrderIntent, Snapshot},
};
use anyhow::{Result, ensure};
use chrono::{DateTime, Utc};
use rusqlite::{Connection, OptionalExtension, params};
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use std::{collections::BTreeMap, path::Path};
use uuid::Uuid;

pub struct Store {
    db: Connection,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ManagedPosition {
    pub deployment_id: String,
    pub account_id: String,
    pub symbol: String,
    pub strategy: String,
    pub quantity: String,
    pub first_fill_price: String,
    pub initial_stop: Option<String>,
    pub current_stop: Option<String>,
    pub signal_atr: String,
    pub entry_session: String,
    pub highest_close: String,
    pub held_sessions: u64,
    pub stop_latched: bool,
    pub configuration_hash: String,
    pub mandate_version: u64,
}

impl Store {
    pub fn open(path: &Path) -> Result<Self> {
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent)?;
        }
        let db = Connection::open(path)?;
        db.busy_timeout(std::time::Duration::from_secs(2))?;
        db.execute_batch("PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL;
          CREATE TABLE IF NOT EXISTS metadata(key TEXT PRIMARY KEY,value TEXT NOT NULL);
          CREATE TABLE IF NOT EXISTS deployments(id TEXT PRIMARY KEY,payload TEXT NOT NULL,paused INTEGER NOT NULL DEFAULT 1,reason TEXT NOT NULL DEFAULT 'startup_reconciliation_required');
          CREATE TABLE IF NOT EXISTS intents(client_id TEXT PRIMARY KEY,deployment_id TEXT NOT NULL,account_id TEXT NOT NULL,decision_id TEXT NOT NULL,payload TEXT NOT NULL,state TEXT NOT NULL,broker_id TEXT,filled TEXT NOT NULL DEFAULT '0',value TEXT NOT NULL DEFAULT '0',created_at TEXT NOT NULL,UNIQUE(deployment_id,decision_id));
          CREATE TABLE IF NOT EXISTS managed(deployment_id TEXT NOT NULL,symbol TEXT NOT NULL,payload TEXT NOT NULL,PRIMARY KEY(deployment_id,symbol));
          CREATE TABLE IF NOT EXISTS baseline(account_id TEXT PRIMARY KEY,payload TEXT NOT NULL);
          CREATE TABLE IF NOT EXISTS events(sequence INTEGER PRIMARY KEY AUTOINCREMENT,id TEXT UNIQUE NOT NULL,payload TEXT NOT NULL,uploaded INTEGER NOT NULL DEFAULT 0);
          CREATE TABLE IF NOT EXISTS acks(control_id TEXT PRIMARY KEY,payload TEXT NOT NULL);
          CREATE TABLE IF NOT EXISTS observations(id INTEGER PRIMARY KEY AUTOINCREMENT,client_id TEXT NOT NULL,payload TEXT NOT NULL,observed_at TEXT NOT NULL);
          CREATE TABLE IF NOT EXISTS decisions(id TEXT PRIMARY KEY,payload TEXT NOT NULL);")?;
        // Recovery must reauthorize entry permission, while preserving protection.
        db.execute(
            "UPDATE deployments SET paused=1,reason='connector_restarted'",
            [],
        )?;
        Ok(Self { db })
    }

    pub fn meta(&self, key: &str) -> Result<Option<String>> {
        Ok(self
            .db
            .query_row("SELECT value FROM metadata WHERE key=?", [key], |r| {
                r.get(0)
            })
            .optional()?)
    }
    pub fn set_meta(&self, key: &str, value: &str) -> Result<()> {
        self.db.execute(
            "INSERT INTO metadata VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value",
            params![key, value],
        )?;
        Ok(())
    }
    pub fn next_poll(&self) -> Result<u64> {
        let value = self
            .meta("poll_sequence")?
            .unwrap_or_else(|| "0".into())
            .parse::<u64>()?
            + 1;
        self.set_meta("poll_sequence", &value.to_string())?;
        Ok(value)
    }

    pub fn deployment(&self, d: &Deployment) -> Result<()> {
        d.validate()?;
        if let Some(old) = self
            .db
            .query_row("SELECT payload FROM deployments WHERE id=?", [&d.id], |r| {
                r.get::<_, String>(0)
            })
            .optional()?
        {
            let old: Deployment = serde_json::from_str(&old)?;
            ensure!(
                old.configuration_hash == d.configuration_hash
                    && old.account_id == d.account_id
                    && old.mode == d.mode,
                "active_mandate_identity_changed"
            );
        }
        self.db.execute("INSERT INTO deployments(id,payload) VALUES(?,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload",params![d.id,serde_json::to_string(d)?])?;
        if d.state != "running" {
            self.pause(&d.id, "server_paused")?;
        }
        Ok(())
    }
    pub fn paused(&self, id: &str) -> Result<bool> {
        Ok(self
            .db
            .query_row("SELECT paused FROM deployments WHERE id=?", [id], |r| {
                r.get::<_, bool>(0)
            })
            .optional()?
            .unwrap_or(true))
    }
    pub fn pause(&self, id: &str, reason: &str) -> Result<()> {
        self.db.execute(
            "UPDATE deployments SET paused=1,reason=? WHERE id=?",
            params![reason, id],
        )?;
        Ok(())
    }
    pub fn pause_account(&self, account: &str, reason: &str) -> Result<()> {
        for d in self.deployments()? {
            if d.account_id == account {
                self.pause(&d.id, reason)?;
            }
        }
        Ok(())
    }
    pub fn resume(&self, id: &str) -> Result<()> {
        self.db
            .execute("UPDATE deployments SET paused=0,reason='' WHERE id=?", [id])?;
        Ok(())
    }
    pub fn deployments(&self) -> Result<Vec<Deployment>> {
        let mut q = self.db.prepare("SELECT payload FROM deployments")?;
        let items = q
            .query_map([], |r| r.get::<_, String>(0))?
            .collect::<rusqlite::Result<Vec<_>>>()?;
        items
            .into_iter()
            .map(|v| Ok(serde_json::from_str(&v)?))
            .collect()
    }
    pub fn save_ack(&self, ack: &crate::protocol::Ack) -> Result<()> {
        self.db.execute(
            "INSERT OR IGNORE INTO acks VALUES(?,?)",
            params![ack.control_id, serde_json::to_string(ack)?],
        )?;
        Ok(())
    }
    pub fn acks(&self) -> Result<Vec<crate::protocol::Ack>> {
        let mut q = self.db.prepare("SELECT payload FROM acks LIMIT 50")?;
        let rows = q
            .query_map([], |r| r.get::<_, String>(0))?
            .collect::<rusqlite::Result<Vec<_>>>()?;
        rows.into_iter()
            .map(|s| Ok(serde_json::from_str(&s)?))
            .collect()
    }
    pub fn ack_sent(&self, acks: &[crate::protocol::Ack]) -> Result<()> {
        for ack in acks {
            self.db
                .execute("DELETE FROM acks WHERE control_id=?", [&ack.control_id])?;
        }
        Ok(())
    }
    pub fn has_ack(&self, id: &str) -> Result<bool> {
        Ok(self
            .db
            .query_row("SELECT 1 FROM acks WHERE control_id=?", [id], |r| {
                r.get::<_, i32>(0)
            })
            .optional()?
            .is_some())
    }

    pub fn emit(&self, deployment: &str, kind: &str, payload: Value) -> Result<()> {
        let event = Event {
            schema_version: "leo.evidence-event.v1".into(),
            id: Uuid::new_v4().to_string(),
            deployment_id: deployment.into(),
            kind: kind.into(),
            occurred_at: Utc::now(),
            sequence: 0,
            payload,
        };
        self.db.execute(
            "INSERT INTO events(id,payload) VALUES(?,?)",
            params![event.id, serde_json::to_string(&event)?],
        )?;
        Ok(())
    }
    pub fn pending_events(&self) -> Result<Vec<Event>> {
        if let Some(batch) = self.meta("pending_event_batch")? {
            let events: Vec<Event> = serde_json::from_str(&batch)?;
            // Preserve the exact retry envelope. Legacy envelopes above the API's
            // hard body limit could never be accepted and may be safely rebuilt.
            let payloads_accepted = events
                .iter()
                .map(|event| {
                    serde_json::to_string(&event.payload)
                        .map(|payload| payload.encode_utf16().count() <= 16_384)
                })
                .collect::<std::result::Result<Vec<_>, _>>()?
                .into_iter()
                .all(|accepted| accepted);
            if payloads_accepted && serde_json::to_vec(&json!({"events":events}))?.len() <= 65_536 {
                return Ok(events);
            }
        }
        let mut q = self.db.prepare(
            "SELECT sequence,payload FROM events WHERE uploaded=0 ORDER BY sequence LIMIT 50",
        )?;
        let items = q
            .query_map([], |r| Ok((r.get::<_, i64>(0)?, r.get::<_, String>(1)?)))?
            .collect::<rusqlite::Result<Vec<_>>>()?;
        let mut events = Vec::new();
        for (seq, raw) in items {
            let mut event: Event = serde_json::from_str(&raw)?;
            event.sequence = seq.try_into()?;
            let payload = serde_json::to_vec(&event.payload)?;
            // A conservative UTF-8 byte cap fits the API's 16,384 UTF-16-unit
            // payload check, including multibyte observations and JSON overhead.
            if payload.len() > 16_000 {
                event.payload = json!({"transportSummary":true,"code":"oversize_payload_retained_in_local_journal","fullPayloadSha256":format!("{:x}",Sha256::digest(&payload)),"originalPayloadBytes":payload.len(),"originalEventId":event.id,"localEvidencePreserved":true});
            }
            events.push(event);
            if serde_json::to_vec(&json!({"events":events}))?.len() > 60_000 {
                events.pop();
                break;
            }
        }
        if !events.is_empty() {
            self.set_meta("pending_event_batch", &serde_json::to_string(&events)?)?;
        }
        Ok(events)
    }
    pub fn events_sent(&self, events: &[Event]) -> Result<()> {
        for event in events {
            self.db
                .execute("UPDATE events SET uploaded=1 WHERE id=?", [&event.id])?;
        }
        self.db
            .execute("DELETE FROM metadata WHERE key='pending_event_batch'", [])?;
        Ok(())
    }

    pub fn claim(&mut self, intent: &OrderIntent, lease_active: bool) -> Result<bool> {
        ensure!(
            matches!(intent.side.as_str(), "BUY" | "SELL"),
            "invalid_side"
        );
        ensure!(money(&intent.quantity)? > Decimal::ZERO, "invalid_quantity");
        let tx = self
            .db
            .transaction_with_behavior(rusqlite::TransactionBehavior::Immediate)?;
        if tx
            .query_row(
                "SELECT 1 FROM intents WHERE deployment_id=? AND decision_id=?",
                params![intent.deployment_id, intent.decision_id],
                |r| r.get::<_, i32>(0),
            )
            .optional()?
            .is_some()
        {
            return Ok(false);
        }
        if intent.side == "BUY" {
            ensure!(lease_active, "entry_lease_expired");
            let paused = tx
                .query_row(
                    "SELECT paused FROM deployments WHERE id=?",
                    [&intent.deployment_id],
                    |r| r.get::<_, bool>(0),
                )
                .optional()?
                .unwrap_or(true);
            ensure!(!paused, "entry_paused");
        }
        let blocked = tx
            .query_row(
                "SELECT 1 FROM intents WHERE account_id=? AND state='unknown' LIMIT 1",
                [&intent.account_id],
                |r| r.get::<_, i32>(0),
            )
            .optional()?
            .is_some();
        ensure!(!blocked, "unknown_submission_blocks_account");
        tx.execute("INSERT INTO intents(client_id,deployment_id,account_id,decision_id,payload,state,created_at) VALUES(?,?,?,?,?,'unknown',?)",params![intent.client_id,intent.deployment_id,intent.account_id,intent.decision_id,serde_json::to_string(intent)?,intent.created_at.to_rfc3339()])?;
        tx.commit()?;
        Ok(true)
    }
    pub fn unresolved(&self, account: &str) -> Result<Vec<OrderIntent>> {
        let mut q=self.db.prepare("SELECT payload FROM intents WHERE account_id=? AND state NOT IN ('filled','cancelled','rejected','expired')")?;
        let rows = q
            .query_map([account], |r| r.get::<_, String>(0))?
            .collect::<rusqlite::Result<Vec<_>>>()?;
        rows.into_iter()
            .map(|s| Ok(serde_json::from_str(&s)?))
            .collect()
    }
    pub fn pending_for(&self, deployment: &str, symbol: &str, side: &str) -> Result<bool> {
        for d in self.deployments()? {
            if d.id == deployment {
                return Ok(self.unresolved(&d.account_id)?.iter().any(|o| {
                    o.deployment_id == deployment && o.symbol == symbol && o.side == side
                }));
            }
        }
        Ok(false)
    }
    pub fn has_unknown(&self, account: &str) -> Result<bool> {
        Ok(self
            .db
            .query_row(
                "SELECT 1 FROM intents WHERE account_id=? AND state='unknown' LIMIT 1",
                [account],
                |r| r.get::<_, i32>(0),
            )
            .optional()?
            .is_some())
    }
    pub fn reject_before_submission(&self, client_id: &str) -> Result<()> {
        self.db.execute("UPDATE intents SET state='rejected' WHERE client_id=? AND state='unknown' AND broker_id IS NULL AND filled='0'",[client_id])?;
        Ok(())
    }
    pub fn pending_commitment(&self, account: &str) -> Result<Decimal> {
        let mut total = Decimal::ZERO;
        for o in self.unresolved(account)? {
            if o.side == "BUY" {
                total += money(&o.quantity)? * money(o.limit_price.as_deref().unwrap_or("0"))?;
            }
        }
        Ok(total)
    }
    pub fn submission_count(&self, deployment: &str, side: &str) -> Result<u64> {
        let mut q = self
            .db
            .prepare("SELECT payload FROM intents WHERE deployment_id=?")?;
        let rows = q
            .query_map([deployment], |r| r.get::<_, String>(0))?
            .collect::<rusqlite::Result<Vec<_>>>()?;
        let mut count = 0;
        for row in rows {
            if serde_json::from_str::<OrderIntent>(&row)?.side == side {
                count += 1;
            }
        }
        Ok(count)
    }
    pub fn entry_count_on(&self, account: &str, day: chrono::NaiveDate) -> Result<usize> {
        let mut q = self
            .db
            .prepare("SELECT payload FROM intents WHERE account_id=?")?;
        let rows = q
            .query_map([account], |r| r.get::<_, String>(0))?
            .collect::<rusqlite::Result<Vec<_>>>()?;
        let mut count = 0;
        for row in rows {
            let intent: OrderIntent = serde_json::from_str(&row)?;
            if intent.side == "BUY"
                && intent
                    .created_at
                    .with_timezone(&chrono_tz::America::New_York)
                    .date_naive()
                    == day
            {
                count += 1;
            }
        }
        Ok(count)
    }
    pub fn position(&self, deployment: &str, symbol: &str) -> Result<Option<ManagedPosition>> {
        let s = self
            .db
            .query_row(
                "SELECT payload FROM managed WHERE deployment_id=? AND symbol=?",
                params![deployment, symbol],
                |r| r.get::<_, String>(0),
            )
            .optional()?;
        s.map(|v| Ok(serde_json::from_str(&v)?)).transpose()
    }
    pub fn save_position(&self, p: &ManagedPosition) -> Result<()> {
        self.db.execute("INSERT INTO managed VALUES(?,?,?) ON CONFLICT(deployment_id,symbol) DO UPDATE SET payload=excluded.payload",params![p.deployment_id,p.symbol,serde_json::to_string(p)?])?;
        Ok(())
    }
    pub fn positions(&self) -> Result<Vec<ManagedPosition>> {
        let mut q = self.db.prepare("SELECT payload FROM managed")?;
        let rows = q
            .query_map([], |r| r.get::<_, String>(0))?
            .collect::<rusqlite::Result<Vec<_>>>()?;
        rows.into_iter()
            .map(|s| Ok(serde_json::from_str(&s)?))
            .collect()
    }

    pub fn observe(&mut self, order: &BrokerOrder, now: DateTime<Utc>) -> Result<()> {
        let row = self
            .db
            .query_row(
                "SELECT payload,filled,value FROM intents WHERE client_id=?",
                [&order.client_id],
                |r| {
                    Ok((
                        r.get::<_, String>(0)?,
                        r.get::<_, String>(1)?,
                        r.get::<_, String>(2)?,
                    ))
                },
            )
            .optional()?;
        let Some((raw, old_filled, old_value)) = row else {
            return Ok(());
        };
        let intent: OrderIntent = serde_json::from_str(&raw)?;
        ensure!(
            order.symbol == intent.symbol
                && order.side == intent.side
                && money(&order.quantity)? == money(&intent.quantity)?,
            "broker_order_identity_mismatch"
        );
        let filled = money(&order.filled_quantity)?;
        ensure!(
            filled >= Decimal::ZERO && filled <= money(&intent.quantity)?,
            "invalid_cumulative_fill"
        );
        let value = if filled > Decimal::ZERO {
            let price = money(
                order
                    .average_fill_price
                    .as_deref()
                    .ok_or_else(|| anyhow::anyhow!("missing_fill_price"))?,
            )?;
            ensure!(price > Decimal::ZERO, "invalid_fill_price");
            price * filled
        } else {
            Decimal::ZERO
        };
        let delta = filled - money(&old_filled)?;
        let cash_delta = value - money(&old_value)?;
        let state = if order.terminal {
            match order.status.as_str() {
                "FILLED_ALL" => "filled",
                "CANCELLED_ALL" | "CANCELLED_PART" => "cancelled",
                "FAILED" | "SUBMIT_FAILED" => "rejected",
                "DELETED" => "expired",
                _ => "unknown",
            }
        } else {
            "acknowledged"
        };
        let mut position = self.position(&intent.deployment_id, &intent.symbol)?;
        if delta != Decimal::ZERO {
            if intent.side == "BUY" {
                if position
                    .as_ref()
                    .is_none_or(|p| money(&p.quantity).is_ok_and(|q| q == Decimal::ZERO))
                    && delta > Decimal::ZERO
                {
                    position = Some(ManagedPosition {
                        deployment_id: intent.deployment_id.clone(),
                        account_id: intent.account_id.clone(),
                        symbol: intent.symbol.clone(),
                        strategy: intent.strategy.clone(),
                        quantity: "0".into(),
                        first_fill_price: order.average_fill_price.clone().unwrap(),
                        initial_stop: None,
                        current_stop: None,
                        signal_atr: intent
                            .signal_atr
                            .clone()
                            .ok_or_else(|| anyhow::anyhow!("missing_signal_atr"))?,
                        entry_session: now
                            .with_timezone(&chrono_tz::America::New_York)
                            .date_naive()
                            .to_string(),
                        highest_close: order.average_fill_price.clone().unwrap(),
                        held_sessions: 0,
                        stop_latched: false,
                        configuration_hash: intent.configuration_hash.clone(),
                        mandate_version: intent.mandate_version,
                    });
                }
                if let Some(p) = &mut position {
                    p.quantity = (money(&p.quantity)? + delta).to_string();
                }
            } else if let Some(p) = &mut position {
                p.quantity = (money(&p.quantity)? - delta).to_string();
            } else {
                anyhow::bail!("exit_without_owned_position");
            }
        }
        if let Some(p) = &position {
            ensure!(
                money(&p.quantity)? >= Decimal::ZERO,
                "unexpected_position_reversal"
            );
        }
        let cash_key = format!("fill_cash:{}", intent.account_id);
        let net_cash = money(&self.meta(&cash_key)?.unwrap_or_else(|| "0".into()))?
            + if intent.side == "BUY" {
                -cash_delta
            } else {
                cash_delta
            };
        let tx = self
            .db
            .transaction_with_behavior(rusqlite::TransactionBehavior::Immediate)?;
        tx.execute(
            "UPDATE intents SET state=?,broker_id=?,filled=?,value=? WHERE client_id=?",
            params![
                state,
                order.id,
                filled.to_string(),
                value.to_string(),
                order.client_id
            ],
        )?;
        tx.execute(
            "INSERT INTO observations(client_id,payload,observed_at) VALUES(?,?,?)",
            params![
                order.client_id,
                serde_json::to_string(order)?,
                now.to_rfc3339()
            ],
        )?;
        if let Some(p) = &position {
            tx.execute("INSERT INTO managed VALUES(?,?,?) ON CONFLICT(deployment_id,symbol) DO UPDATE SET payload=excluded.payload",params![p.deployment_id,p.symbol,serde_json::to_string(p)?])?;
        }
        tx.execute(
            "INSERT INTO metadata VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value",
            params![cash_key, net_cash.to_string()],
        )?;
        if delta != Decimal::ZERO || cash_delta != Decimal::ZERO {
            let event = Event {
                schema_version: "leo.evidence-event.v1".into(),
                id: Uuid::new_v4().to_string(),
                deployment_id: intent.deployment_id.clone(),
                kind: "fill".into(),
                occurred_at: now,
                sequence: 0,
                payload: json!({"source":"broker_order_cumulative_observation","clientId":order.client_id,"brokerOrderId":order.id,"quantityDelta":delta.to_string(),"cumulativeQuantity":filled.to_string(),"cumulativeValue":value.to_string(),"valueDelta":cash_delta.to_string(),"correction":delta<Decimal::ZERO || (delta==Decimal::ZERO && cash_delta!=Decimal::ZERO),"individualDealIdsAvailable":false,"stopBasis":"first_observed_cumulative_fill"}),
            };
            tx.execute(
                "INSERT INTO events(id,payload) VALUES(?,?)",
                params![event.id, serde_json::to_string(&event)?],
            )?;
        }
        tx.commit()?;
        if delta < Decimal::ZERO {
            self.pause_account(&intent.account_id, "broker_fill_correction_requires_review")?;
            self.emit(
                &intent.deployment_id,
                "incident",
                json!({"code":"broker_fill_correction_requires_review","newEntriesPaused":true}),
            )?;
        }
        Ok(())
    }

    pub fn reconcile(&mut self, snapshot: &Snapshot) -> Result<bool> {
        for o in &snapshot.orders {
            self.observe(o, snapshot.observed_at)?;
        }
        let mut actual = BTreeMap::<String, Decimal>::new();
        for p in &snapshot.positions {
            *actual.entry(p.symbol.clone()).or_default() += money(&p.quantity)?;
        }
        let raw = self
            .db
            .query_row(
                "SELECT payload FROM baseline WHERE account_id=?",
                [&snapshot.account_id],
                |r| r.get::<_, String>(0),
            )
            .optional()?;
        let initial = raw.is_none();
        let mut expected: BTreeMap<String, Decimal> = if let Some(raw) = raw {
            serde_json::from_str::<BTreeMap<String, String>>(&raw)?
                .into_iter()
                .map(|(k, v)| Ok((k, money(&v)?)))
                .collect::<Result<_>>()?
        } else {
            actual.clone()
        };
        let positions = self.positions()?;
        if initial {
            for p in &positions {
                if p.account_id == snapshot.account_id {
                    *expected.entry(p.symbol.clone()).or_default() -= money(&p.quantity)?;
                }
            }
            let baseline: BTreeMap<_, _> = expected
                .iter()
                .map(|(k, v)| (k.clone(), v.to_string()))
                .collect();
            self.db.execute(
                "INSERT INTO baseline VALUES(?,?)",
                params![snapshot.account_id, serde_json::to_string(&baseline)?],
            )?;
        }
        for p in positions {
            if p.account_id == snapshot.account_id {
                *expected.entry(p.symbol.clone()).or_default() += money(&p.quantity)?;
            }
        }
        actual.retain(|_, v| *v != Decimal::ZERO);
        expected.retain(|_, v| *v != Decimal::ZERO);
        let cash_key = format!("baseline_cash:{}", snapshot.account_id);
        let net_cash = money(
            &self
                .meta(&format!("fill_cash:{}", snapshot.account_id))?
                .unwrap_or_else(|| "0".into()),
        )?;
        let baseline_cash = match self.meta(&cash_key)? {
            Some(raw) => money(&raw)?,
            None => {
                let amount = money(&snapshot.cash)? - net_cash;
                self.set_meta(&cash_key, &amount.to_string())?;
                amount
            }
        };
        // Paper has no fee feed. Two cents covers rounding only; larger unexplained
        // movements (including fees/reset/deposit/dividend) pause pending review.
        let tolerance = Decimal::new(2, 2);
        let cash_matches = (money(&snapshot.cash)? - baseline_cash - net_cash).abs() <= tolerance;
        let market_value = snapshot
            .positions
            .iter()
            .try_fold(Decimal::ZERO, |sum, p| {
                Ok::<_, anyhow::Error>(sum + money(&p.market_value)?)
            })?;
        let equity_matches =
            (money(&snapshot.equity)? - money(&snapshot.cash)? - market_value).abs() <= tolerance;
        let baseline_exposure = if let Some(raw) = self
            .db
            .query_row(
                "SELECT payload FROM baseline WHERE account_id=?",
                [&snapshot.account_id],
                |r| r.get::<_, String>(0),
            )
            .optional()?
        {
            serde_json::from_str::<BTreeMap<String, String>>(&raw)?
                .values()
                .any(|q| money(q).is_ok_and(|q| q != Decimal::ZERO))
        } else {
            false
        };
        let unmanaged_working = snapshot.orders.iter().any(|o| {
            !o.terminal
                && self
                    .db
                    .query_row(
                        "SELECT 1 FROM intents WHERE client_id=?",
                        [&o.client_id],
                        |r| r.get::<_, i32>(0),
                    )
                    .optional()
                    .ok()
                    .flatten()
                    .is_none()
        });
        let matched = actual == expected
            && cash_matches
            && equity_matches
            && !baseline_exposure
            && !unmanaged_working
            && !self.has_unknown(&snapshot.account_id)?;
        if !matched {
            self.pause_account(&snapshot.account_id, "reconciliation_mismatch")?;
        }
        Ok(matched)
    }
    pub fn record_decision(&self, id: &str, deployment: &str, result: &Value) -> Result<bool> {
        let added = self.db.execute(
            "INSERT OR IGNORE INTO decisions VALUES(?,?)",
            params![format!("{deployment}:{id}"), serde_json::to_string(result)?],
        )? > 0;
        if added {
            self.emit(deployment, "decision", result.clone())?;
        }
        Ok(added)
    }

    pub fn resolve_verified_flat(&mut self, snapshot: &Snapshot) -> Result<()> {
        ensure!(
            snapshot
                .positions
                .iter()
                .all(|p| money(&p.quantity).is_ok_and(|q| q == Decimal::ZERO)),
            "account_must_be_flat"
        );
        ensure!(
            snapshot.orders.iter().all(|o| o.terminal),
            "working_orders_must_be_resolved"
        );
        ensure!(
            !self.has_unknown(&snapshot.account_id)?
                && self.unresolved(&snapshot.account_id)?.is_empty(),
            "uncertain_orders_require_broker_evidence"
        );
        let net_cash = money(
            &self
                .meta(&format!("fill_cash:{}", snapshot.account_id))?
                .unwrap_or_else(|| "0".into()),
        )?;
        self.db.execute("INSERT INTO baseline VALUES(?,'{}') ON CONFLICT(account_id) DO UPDATE SET payload='{}'",[&snapshot.account_id])?;
        self.set_meta(
            &format!("baseline_cash:{}", snapshot.account_id),
            &(money(&snapshot.cash)? - net_cash).to_string(),
        )?;
        let day = snapshot
            .observed_at
            .with_timezone(&chrono_tz::America::New_York)
            .date_naive();
        self.set_meta(
            &format!("daily_equity:{}:{day}", snapshot.account_id),
            &snapshot.equity,
        )?;
        self.set_meta(
            &format!("peak_equity:{}", snapshot.account_id),
            &snapshot.equity,
        )?;
        for mut p in self
            .positions()?
            .into_iter()
            .filter(|p| p.account_id == snapshot.account_id)
        {
            p.quantity = "0".into();
            self.save_position(&p)?;
        }
        for d in self
            .deployments()?
            .into_iter()
            .filter(|d| d.account_id == snapshot.account_id)
        {
            self.pause(&d.id, "manual_flat_resolution_resume_required")?;
            self.emit(&d.id,"incident",json!({"code":"user_confirmed_flat_account_resolution","cashBaseline":snapshot.cash,"equityBaseline":snapshot.equity,"fillLedgerPreserved":true,"reconciliationAdjustmentIsNotATrade":true,"newEntriesPaused":true}))?;
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn intent() -> OrderIntent {
        OrderIntent {
            client_id: "leo-test".into(),
            deployment_id: "dep".into(),
            decision_id: "day1".into(),
            account_id: "123".into(),
            symbol: "SPY".into(),
            side: "BUY".into(),
            quantity: "2".into(),
            limit_price: Some("100".into()),
            order_type: "NORMAL".into(),
            strategy: "MR-v1".into(),
            signal_atr: Some("2".into()),
            configuration_hash: "a".repeat(64),
            mandate_version: 1,
            reason: "signal".into(),
            created_at: Utc::now(),
        }
    }
    fn ready(s: &Store) {
        let d:Deployment=serde_json::from_value(json!({"id":"dep","mandateVersion":1,"configurationHash":"a".repeat(64),"strategyVersion":{"strategyId":"MR-v1","symbol":"SPY"},"accountId":"123","mode":"paper","state":"running","leaseExpiresAt":null})).unwrap();
        s.deployment(&d).unwrap();
        s.resume("dep").unwrap();
    }
    #[test]
    fn claim_is_durable_and_unknown_cannot_be_retried() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("test.db");
        let mut s = Store::open(&path).unwrap();
        ready(&s);
        assert!(s.claim(&intent(), true).unwrap());
        assert!(!s.claim(&intent(), true).unwrap());
        drop(s);
        let mut s = Store::open(&path).unwrap();
        assert!(!s.claim(&intent(), true).unwrap());
        let mut other = intent();
        other.client_id = "other".into();
        other.decision_id = "day2".into();
        assert!(s.claim(&other, true).is_err());
        assert!(s.paused("dep").unwrap());
    }
    #[test]
    fn paused_and_expired_lease_never_create_intent() {
        let mut s = Store::open(Path::new(":memory:")).unwrap();
        ready(&s);
        assert!(s.claim(&intent(), false).is_err());
        s.pause("dep", "test").unwrap();
        assert!(s.claim(&intent(), true).is_err());
        assert_eq!(
            s.db.query_row("SELECT count(*) FROM intents", [], |r| r.get::<_, u32>(0))
                .unwrap(),
            0
        );
    }
    #[test]
    fn cumulative_average_corrections_do_not_duplicate_shares() {
        let mut s = Store::open(Path::new(":memory:")).unwrap();
        ready(&s);
        s.claim(&intent(), true).unwrap();
        let mut o = BrokerOrder {
            id: "b1".into(),
            client_id: "leo-test".into(),
            symbol: "SPY".into(),
            side: "BUY".into(),
            quantity: "2".into(),
            filled_quantity: "1".into(),
            average_fill_price: Some("99".into()),
            status: "FILLED_PART".into(),
            terminal: false,
        };
        s.observe(&o, Utc::now()).unwrap();
        s.observe(&o, Utc::now()).unwrap();
        o.average_fill_price = Some("98".into());
        s.observe(&o, Utc::now()).unwrap();
        let p = s.position("dep", "SPY").unwrap().unwrap();
        assert_eq!(p.quantity, "1");
        assert_eq!(p.first_fill_price, "99");
        o.filled_quantity = "2".into();
        o.average_fill_price = Some("99".into());
        o.status = "FILLED_ALL".into();
        o.terminal = true;
        s.observe(&o, Utc::now()).unwrap();
        assert_eq!(s.position("dep", "SPY").unwrap().unwrap().quantity, "2");
        let events = s.pending_events().unwrap();
        assert_eq!(events.len(), 3);
        assert_eq!(events[1].payload["quantityDelta"], "0");
        assert_eq!(events[1].payload["valueDelta"], "-1");
    }
    fn snapshot() -> Snapshot {
        Snapshot {
            account_id: "123".into(),
            environment: "SIMULATE".into(),
            observed_at: Utc::now(),
            cash: "10000".into(),
            equity: "10000".into(),
            positions: vec![],
            orders: vec![],
            history_complete: false,
        }
    }
    #[test]
    fn unexplained_cash_change_pauses_and_never_silently_rebases() {
        let mut s = Store::open(Path::new(":memory:")).unwrap();
        ready(&s);
        let mut snap = snapshot();
        assert!(s.reconcile(&snap).unwrap());
        snap.cash = "10001".into();
        snap.equity = "10001".into();
        assert!(!s.reconcile(&snap).unwrap());
        assert!(s.paused("dep").unwrap());
        assert!(!s.reconcile(&snap).unwrap());
    }
    #[test]
    fn owned_fills_reconcile_cash_but_manual_holdings_block_initial_adoption() {
        let mut s = Store::open(Path::new(":memory:")).unwrap();
        ready(&s);
        let mut snap = snapshot();
        assert!(s.reconcile(&snap).unwrap());
        s.claim(&intent(), true).unwrap();
        snap.orders.push(BrokerOrder {
            id: "b1".into(),
            client_id: "leo-test".into(),
            symbol: "SPY".into(),
            side: "BUY".into(),
            quantity: "2".into(),
            filled_quantity: "2".into(),
            average_fill_price: Some("100".into()),
            status: "FILLED_ALL".into(),
            terminal: true,
        });
        snap.cash = "9800".into();
        snap.positions.push(crate::protocol::Position {
            symbol: "SPY".into(),
            quantity: "2".into(),
            available_quantity: "2".into(),
            market_value: "200".into(),
        });
        assert!(s.reconcile(&snap).unwrap());
        let mut other = Store::open(Path::new(":memory:")).unwrap();
        ready(&other);
        assert!(!other.reconcile(&snap).unwrap());
    }
    #[test]
    fn event_batch_is_stable_across_new_events_and_restart() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("test.db");
        let s = Store::open(&path).unwrap();
        s.emit("dep", "incident", json!({"n":1})).unwrap();
        let batch = s.pending_events().unwrap();
        s.emit("dep", "incident", json!({"n":2})).unwrap();
        drop(s);
        let s = Store::open(&path).unwrap();
        assert_eq!(
            serde_json::to_value(s.pending_events().unwrap()).unwrap(),
            serde_json::to_value(&batch).unwrap()
        );
        s.events_sent(&batch).unwrap();
        assert_eq!(s.pending_events().unwrap()[0].payload["n"], 2);
    }

    #[test]
    fn explicit_flat_resolution_keeps_evidence_and_pause_but_cannot_erase_unknown() {
        let mut s = Store::open(Path::new(":memory:")).unwrap();
        ready(&s);
        let mut snap = snapshot();
        s.reconcile(&snap).unwrap();
        snap.cash = "20000".into();
        snap.equity = "20000".into();
        assert!(!s.reconcile(&snap).unwrap());
        s.resolve_verified_flat(&snap).unwrap();
        assert!(s.reconcile(&snap).unwrap());
        assert!(s.paused("dep").unwrap());
        assert!(
            s.pending_events()
                .unwrap()
                .iter()
                .any(|e| e.payload["code"] == "user_confirmed_flat_account_resolution")
        );
        s.resume("dep").unwrap();
        s.claim(&intent(), true).unwrap();
        assert!(s.resolve_verified_flat(&snap).is_err());
        assert!(s.has_unknown("123").unwrap());
    }

    #[test]
    fn outage_backlog_is_byte_bounded_with_stable_retries_and_full_local_payload() {
        let s = Store::open(Path::new(":memory:")).unwrap();
        for n in 0..30 {
            s.emit(
                "dep",
                "heartbeat",
                json!({"sequenceExample":n,"positions": "📈".repeat(1000)}),
            )
            .unwrap();
        }
        let first = s.pending_events().unwrap();
        assert!(first.len() < 30);
        assert_eq!(
            serde_json::to_value(s.pending_events().unwrap()).unwrap(),
            serde_json::to_value(&first).unwrap()
        );
        let mut count = 0;
        loop {
            let batch = s.pending_events().unwrap();
            if batch.is_empty() {
                break;
            }
            assert!(serde_json::to_vec(&json!({"events":batch})).unwrap().len() <= 60_000);
            count += batch.len();
            s.events_sent(&batch).unwrap();
        }
        assert_eq!(count, 30);
        s.emit("dep", "incident", json!({"large": "x".repeat(100_000)}))
            .unwrap();
        let batch = s.pending_events().unwrap();
        assert_eq!(batch.len(), 1);
        assert_eq!(batch[0].payload["transportSummary"], true);
        let raw: String =
            s.db.query_row(
                "SELECT payload FROM events WHERE id=?",
                [&batch[0].id],
                |r| r.get(0),
            )
            .unwrap();
        assert!(raw.len() > 100_000);
        assert!(serde_json::to_vec(&json!({"events":batch})).unwrap().len() < 60_000);
    }

    #[test]
    fn twenty_kib_payload_and_never_acceptable_saved_batch_are_summarized() {
        let s = Store::open(Path::new(":memory:")).unwrap();
        s.emit("dep", "heartbeat", json!({"positions":"x".repeat(20_000)}))
            .unwrap();
        let (seq, raw): (i64, String) =
            s.db.query_row("SELECT sequence,payload FROM events", [], |r| {
                Ok((r.get(0)?, r.get(1)?))
            })
            .unwrap();
        let mut original: Event = serde_json::from_str(&raw).unwrap();
        original.sequence = seq as u64;
        let legacy = vec![original];
        assert!(serde_json::to_vec(&json!({"events":legacy})).unwrap().len() < 65_536);
        s.set_meta(
            "pending_event_batch",
            &serde_json::to_string(&legacy).unwrap(),
        )
        .unwrap();
        let batch = s.pending_events().unwrap();
        assert_eq!(batch[0].payload["transportSummary"], true);
        assert!(serde_json::to_vec(&batch[0].payload).unwrap().len() <= 16_000);
        assert_eq!(batch[0].id, legacy[0].id);
        assert_eq!(
            serde_json::to_value(s.pending_events().unwrap()).unwrap(),
            serde_json::to_value(&batch).unwrap()
        );
        let retained: String =
            s.db.query_row(
                "SELECT payload FROM events WHERE id=?",
                [&batch[0].id],
                |r| r.get(0),
            )
            .unwrap();
        assert_eq!(retained, raw);
    }
}
