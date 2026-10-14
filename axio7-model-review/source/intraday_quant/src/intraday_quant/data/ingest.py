from __future__ import annotations

import json

import pandas as pd

from intraday_quant.calendar import filter_regular_session, market_schedule
from intraday_quant.config import AppConfig
from intraday_quant.data.adapters import build_adapter
from intraday_quant.data.clean import clean_bars
from intraday_quant.data.integrity import (
    DataIntegrityError,
    enforce_complete_panel_sessions,
)


def ingest(config: AppConfig) -> tuple[pd.DataFrame, dict[str, int]]:
    raw = build_adapter(config).load()
    cleaned, stats = clean_bars(raw, config.timezone, config.data.price_ffill_limit)
    before_session_filter = len(cleaned)
    schedule = market_schedule(config.start_date, config.end_date, config.timezone)
    cleaned = filter_regular_session(cleaned, schedule).reset_index(drop=True)
    stats["outside_session_removed"] = before_session_filter - len(cleaned)
    integrity = enforce_complete_panel_sessions(
        cleaned,
        schedule,
        config.symbols,
        frequency="1min",
    )
    cleaned = integrity.bars
    stats.update(integrity.stats)
    stats["output_rows"] = len(cleaned)
    cleaned_dir = config.output_dir / "cleaned"
    cleaned_dir.mkdir(parents=True, exist_ok=True)
    integrity.session_audit.to_csv(
        cleaned_dir / "session_integrity.csv",
        index=False,
    )
    (cleaned_dir / "ingest_integrity.json").write_text(
        json.dumps(stats, indent=2, sort_keys=True),
        encoding="utf-8",
    )
    if cleaned.empty:
        raise DataIntegrityError(
            "no complete panel session remains after exact timestamp and "
            "required-symbol coverage checks"
        )
    path = cleaned_dir / "bars.parquet"
    cleaned.to_parquet(path, index=False)
    try:
        import duckdb

        db = config.output_dir / "market.duckdb"
        with duckdb.connect(str(db)) as conn:
            parquet = str(path.resolve()).replace("'", "''")
            conn.execute(f"CREATE OR REPLACE VIEW bars AS SELECT * FROM read_parquet('{parquet}')")
    except ImportError:
        pass
    return cleaned, stats


def load_cleaned(config: AppConfig) -> pd.DataFrame:
    return pd.read_parquet(config.output_dir / "cleaned" / "bars.parquet")
