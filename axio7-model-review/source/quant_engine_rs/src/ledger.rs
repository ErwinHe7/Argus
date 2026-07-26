use std::{fs, path::Path, sync::Arc};

use anyhow::{Context, Result, bail};
use parking_lot::Mutex;
use rusqlite::{Connection, TransactionBehavior, params};
use sha2::{Digest, Sha256};

use crate::os_domain::{Fill, stable_id};

const SCHEMA: &str = include_str!("../../ledger/schema.sql");
const BALANCE_TOLERANCE: f64 = 1.0e-6;

#[derive(Debug, Clone, PartialEq)]
pub struct LedgerEntryInput {
    pub account: String,
    pub debit: f64,
    pub credit: f64,
    pub currency: String,
    pub memo: String,
}

impl LedgerEntryInput {
    pub fn debit(account: &str, amount: f64, memo: &str) -> Self {
        Self {
            account: account.to_string(),
            debit: amount,
            credit: 0.0,
            currency: "USD".to_string(),
            memo: memo.to_string(),
        }
    }

    pub fn credit(account: &str, amount: f64, memo: &str) -> Self {
        Self {
            account: account.to_string(),
            debit: 0.0,
            credit: amount,
            currency: "USD".to_string(),
            memo: memo.to_string(),
        }
    }
}

pub struct Ledger {
    connection: Mutex<Connection>,
}

impl Ledger {
    pub fn open(path: &Path) -> Result<Arc<Self>> {
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent)?;
        }
        let connection = Connection::open(path)
            .with_context(|| format!("cannot open ledger {}", path.display()))?;
        connection.execute_batch(SCHEMA)?;
        Ok(Arc::new(Self {
            connection: Mutex::new(connection),
        }))
    }

    /// Posts a fill to the append-only double-entry ledger. `side` is the
    /// economic position direction and must be LONG or SHORT. Quantity and
    /// price remain in instrument units; option contract multipliers must be
    /// applied by the caller from licensed reference data.
    pub fn post_fill(&self, fill: &Fill, side: &str) -> Result<String> {
        if fill.quantity <= 0.0 || fill.price <= 0.0 || fill.fee < 0.0 {
            bail!("fill has invalid quantity, price, or fee");
        }
        let gross = fill.quantity * fill.price;
        let memo = format!("{} {} @ {}", fill.meta.symbol, fill.quantity, fill.price);
        let mut entries = match side {
            "LONG" => vec![
                LedgerEntryInput::debit("Position", gross, &memo),
                LedgerEntryInput::credit("Cash", gross, &memo),
            ],
            "SHORT" => vec![
                LedgerEntryInput::debit("Cash", gross, &memo),
                LedgerEntryInput::credit("Position", gross, &memo),
            ],
            _ => bail!("fill side must be LONG or SHORT"),
        };
        if fill.fee > 0.0 {
            entries.push(LedgerEntryInput::debit("Fees", fill.fee, &memo));
            entries.push(LedgerEntryInput::credit("Cash", fill.fee, &memo));
        }
        self.post_transaction(
            "FILL",
            &fill.fill_id,
            fill.meta.event_time.timestamp_micros(),
            None,
            &entries,
        )
    }

    pub fn post_transaction(
        &self,
        event_type: &str,
        source_id: &str,
        event_time_micros: i64,
        correction_of: Option<&str>,
        entries: &[LedgerEntryInput],
    ) -> Result<String> {
        if event_type.is_empty() || source_id.is_empty() || entries.len() < 2 {
            bail!("ledger transaction identity and at least two entries are required");
        }
        let debits = entries.iter().map(|entry| entry.debit).sum::<f64>();
        let credits = entries.iter().map(|entry| entry.credit).sum::<f64>();
        if !debits.is_finite()
            || !credits.is_finite()
            || debits <= 0.0
            || (debits - credits).abs() > BALANCE_TOLERANCE
        {
            bail!("ledger transaction is not balanced");
        }
        for entry in entries {
            let one_sided = (entry.debit > 0.0 && entry.credit == 0.0)
                || (entry.credit > 0.0 && entry.debit == 0.0);
            if !one_sided
                || !entry.debit.is_finite()
                || !entry.credit.is_finite()
                || entry.currency.is_empty()
            {
                bail!("ledger entry is invalid");
            }
        }
        let transaction_id = stable_id(&[
            "ledger_transaction",
            event_type,
            source_id,
            &event_time_micros.to_string(),
        ]);
        let mut hasher = Sha256::new();
        for part in [event_type, source_id, &event_time_micros.to_string()] {
            hasher.update(part.as_bytes());
            hasher.update([0]);
        }
        if let Some(original) = correction_of {
            hasher.update(original.as_bytes());
        }
        for entry in entries {
            hasher.update(entry.account.as_bytes());
            hasher.update(entry.debit.to_le_bytes());
            hasher.update(entry.credit.to_le_bytes());
            hasher.update(entry.currency.as_bytes());
            hasher.update(entry.memo.as_bytes());
        }
        let content_hash = format!("{:x}", hasher.finalize());
        let mut connection = self.connection.lock();
        let transaction = connection.transaction_with_behavior(TransactionBehavior::Immediate)?;
        transaction.execute(
            "INSERT INTO ledger_transactions
             (transaction_id, event_time, event_type, source_id, correction_of, content_hash)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
            params![
                transaction_id,
                event_time_micros,
                event_type,
                source_id,
                correction_of,
                content_hash
            ],
        )?;
        for (index, entry) in entries.iter().enumerate() {
            let entry_id = stable_id(&[
                "ledger_entry",
                &transaction_id,
                &index.to_string(),
                &entry.account,
            ]);
            transaction.execute(
                "INSERT INTO ledger_entries
                 (entry_id, transaction_id, account, debit, credit, currency, memo)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
                params![
                    entry_id,
                    transaction_id,
                    entry.account,
                    entry.debit,
                    entry.credit,
                    entry.currency,
                    entry.memo
                ],
            )?;
        }
        let imbalance: f64 = transaction.query_row(
            "SELECT COALESCE(SUM(debit-credit), 0.0) FROM ledger_entries
             WHERE transaction_id=?1",
            params![transaction_id],
            |row| row.get(0),
        )?;
        if imbalance.abs() > BALANCE_TOLERANCE {
            bail!("ledger database rejected an unbalanced transaction");
        }
        transaction.commit()?;
        Ok(transaction_id)
    }

    pub fn unbalanced_transaction_count(&self) -> Result<usize> {
        let count: i64 = self.connection.lock().query_row(
            "SELECT COUNT(*) FROM unbalanced_transactions",
            [],
            |row| row.get(0),
        )?;
        Ok(count as usize)
    }
}

#[cfg(test)]
mod tests {
    use chrono::{TimeZone, Utc};
    use tempfile::tempdir;

    use crate::os_domain::{EventMeta, Fill};

    use super::{Ledger, LedgerEntryInput};

    fn fill() -> Fill {
        let event_time = Utc.with_ymd_and_hms(2026, 7, 20, 14, 30, 0).unwrap();
        Fill {
            meta: EventMeta::deterministic("fill", "SPY", event_time, "paper", "order-1"),
            fill_id: "fill-1".to_string(),
            order_id: "order-1".to_string(),
            quantity: 2.0,
            price: 600.0,
            fee: 1.25,
            liquidity: "TAKER".to_string(),
        }
    }

    #[test]
    fn fill_is_balanced_idempotent_and_immutable() {
        let directory = tempdir().unwrap();
        let ledger = Ledger::open(&directory.path().join("ledger.db")).unwrap();
        let posted = fill();
        ledger.post_fill(&posted, "LONG").unwrap();
        assert_eq!(ledger.unbalanced_transaction_count().unwrap(), 0);
        assert!(ledger.post_fill(&posted, "LONG").is_err());

        let bad = [
            LedgerEntryInput::debit("Cash", 10.0, "bad"),
            LedgerEntryInput::credit("Position", 9.0, "bad"),
        ];
        assert!(
            ledger
                .post_transaction("BAD", "bad-1", 1, None, &bad)
                .is_err()
        );
    }
}
