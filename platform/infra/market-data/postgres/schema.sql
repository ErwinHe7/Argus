CREATE SCHEMA IF NOT EXISTS market_data;

CREATE OR REPLACE FUNCTION market_data.reject_mutation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION '% is append-only; % is not allowed', TG_TABLE_NAME, TG_OP;
END;
$$;

CREATE OR REPLACE FUNCTION market_data.is_finite(value double precision)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
AS $$
    SELECT value NOT IN (
        'NaN'::double precision,
        'Infinity'::double precision,
        '-Infinity'::double precision
    )
$$;

CREATE TABLE IF NOT EXISTS market_data.batches (
    batch_id text PRIMARY KEY,
    provider text NOT NULL,
    dataset text NOT NULL,
    source_file_sha256 text NOT NULL CHECK (source_file_sha256 ~ '^[0-9a-f]{64}$'),
    source_path text NOT NULL,
    captured_at timestamptz NOT NULL,
    availability_policy text NOT NULL,
    availability_delay_seconds integer NOT NULL CHECK (availability_delay_seconds >= 0),
    license_scope text NOT NULL CHECK (
        license_scope IN ('RESEARCH_ONLY', 'INTERNAL_USE', 'PUBLIC_DISPLAY', 'REDISTRIBUTION')
    ),
    license_reference text NOT NULL,
    input_rows bigint NOT NULL CHECK (input_rows >= 0),
    accepted_rows bigint NOT NULL CHECK (accepted_rows >= 0),
    duplicate_rows bigint NOT NULL CHECK (duplicate_rows >= 0),
    rejected_rows bigint NOT NULL CHECK (rejected_rows >= 0),
    inserted_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE TABLE IF NOT EXISTS market_data.equity_minute_bars (
    batch_id text NOT NULL REFERENCES market_data.batches(batch_id),
    symbol text NOT NULL CHECK (symbol = upper(symbol)),
    event_at timestamptz NOT NULL,
    available_at timestamptz NOT NULL,
    recorded_at timestamptz NOT NULL,
    open double precision NOT NULL CHECK (market_data.is_finite(open) AND open > 0),
    high double precision NOT NULL CHECK (market_data.is_finite(high) AND high > 0),
    low double precision NOT NULL CHECK (market_data.is_finite(low) AND low > 0),
    close double precision NOT NULL CHECK (market_data.is_finite(close) AND close > 0),
    volume double precision NOT NULL CHECK (market_data.is_finite(volume) AND volume >= 0),
    vwap double precision CHECK (
        vwap IS NULL OR (market_data.is_finite(vwap) AND vwap > 0)
    ),
    bid double precision CHECK (
        bid IS NULL OR (market_data.is_finite(bid) AND bid >= 0)
    ),
    ask double precision CHECK (
        ask IS NULL OR (market_data.is_finite(ask) AND ask >= 0)
    ),
    trade_count bigint CHECK (trade_count IS NULL OR trade_count >= 0),
    source text NOT NULL,
    data_quality text NOT NULL,
    PRIMARY KEY (batch_id, symbol, event_at),
    CHECK (high >= greatest(open, low, close)),
    CHECK (low <= least(open, high, close)),
    CHECK (available_at >= event_at),
    CHECK (recorded_at >= available_at)
) PARTITION BY RANGE (event_at);

CREATE TABLE IF NOT EXISTS market_data.live_equity_minute_bars (
    provider text NOT NULL,
    dataset text NOT NULL,
    schema_name text NOT NULL,
    symbol text NOT NULL CHECK (symbol = upper(symbol)),
    event_at timestamptz NOT NULL,
    available_at timestamptz NOT NULL,
    recorded_at timestamptz NOT NULL,
    finalized_at timestamptz NOT NULL,
    open double precision NOT NULL CHECK (market_data.is_finite(open) AND open > 0),
    high double precision NOT NULL CHECK (market_data.is_finite(high) AND high > 0),
    low double precision NOT NULL CHECK (market_data.is_finite(low) AND low > 0),
    close double precision NOT NULL CHECK (market_data.is_finite(close) AND close > 0),
    volume double precision NOT NULL CHECK (market_data.is_finite(volume) AND volume >= 0),
    vwap double precision CHECK (
        vwap IS NULL OR (market_data.is_finite(vwap) AND vwap > 0)
    ),
    trade_count bigint CHECK (trade_count IS NULL OR trade_count >= 0),
    source text NOT NULL,
    data_quality text NOT NULL,
    entitlement text NOT NULL,
    license_scope text NOT NULL CHECK (
        license_scope IN ('RESEARCH_ONLY', 'INTERNAL_USE', 'PUBLIC_DISPLAY', 'REDISTRIBUTION')
    ),
    license_reference_sha256 text NOT NULL CHECK (license_reference_sha256 ~ '^[0-9a-f]{64}$'),
    symbol_mapping_verified boolean NOT NULL CHECK (symbol_mapping_verified),
    PRIMARY KEY (provider, dataset, schema_name, symbol, event_at),
    CHECK (high >= greatest(open, low, close)),
    CHECK (low <= least(open, high, close)),
    CHECK (available_at >= event_at + interval '1 minute'),
    CHECK (recorded_at >= available_at),
    CHECK (finalized_at = available_at)
) PARTITION BY RANGE (event_at);

CREATE TABLE IF NOT EXISTS market_data.equity_nbbo_quotes (
    batch_id text NOT NULL REFERENCES market_data.batches(batch_id),
    symbol text NOT NULL CHECK (symbol = upper(symbol)),
    event_at timestamptz NOT NULL,
    available_at timestamptz NOT NULL,
    recorded_at timestamptz NOT NULL,
    bid double precision NOT NULL CHECK (market_data.is_finite(bid) AND bid >= 0),
    ask double precision NOT NULL CHECK (market_data.is_finite(ask) AND ask >= bid),
    bid_size bigint CHECK (bid_size IS NULL OR bid_size >= 0),
    ask_size bigint CHECK (ask_size IS NULL OR ask_size >= 0),
    bid_exchange text,
    ask_exchange text,
    sequence_number bigint,
    source text NOT NULL,
    data_quality text NOT NULL,
    PRIMARY KEY (batch_id, symbol, event_at),
    CHECK (available_at >= event_at),
    CHECK (recorded_at >= available_at)
) PARTITION BY RANGE (event_at);

CREATE TABLE IF NOT EXISTS market_data.option_contracts (
    option_symbol text PRIMARY KEY,
    underlying_symbol text NOT NULL CHECK (underlying_symbol = upper(underlying_symbol)),
    expiration_date date NOT NULL,
    strike double precision NOT NULL CHECK (
        market_data.is_finite(strike) AND strike > 0
    ),
    option_right char(1) NOT NULL CHECK (option_right IN ('C', 'P')),
    multiplier integer NOT NULL DEFAULT 100 CHECK (multiplier > 0),
    exercise_style text,
    settlement_style text,
    listing_exchange text,
    first_seen_at timestamptz NOT NULL,
    last_seen_at timestamptz NOT NULL,
    CHECK (last_seen_at >= first_seen_at)
);

CREATE TABLE IF NOT EXISTS market_data.option_quotes (
    batch_id text NOT NULL REFERENCES market_data.batches(batch_id),
    option_symbol text NOT NULL REFERENCES market_data.option_contracts(option_symbol),
    event_at timestamptz NOT NULL,
    available_at timestamptz NOT NULL,
    recorded_at timestamptz NOT NULL,
    bid double precision NOT NULL CHECK (market_data.is_finite(bid) AND bid >= 0),
    ask double precision NOT NULL CHECK (market_data.is_finite(ask) AND ask >= bid),
    bid_size bigint CHECK (bid_size IS NULL OR bid_size >= 0),
    ask_size bigint CHECK (ask_size IS NULL OR ask_size >= 0),
    bid_exchange text,
    ask_exchange text,
    sequence_number bigint,
    source text NOT NULL,
    data_quality text NOT NULL,
    PRIMARY KEY (batch_id, option_symbol, event_at),
    CHECK (available_at >= event_at),
    CHECK (recorded_at >= available_at)
) PARTITION BY RANGE (event_at);

CREATE TABLE IF NOT EXISTS market_data.option_trades (
    batch_id text NOT NULL REFERENCES market_data.batches(batch_id),
    option_symbol text NOT NULL REFERENCES market_data.option_contracts(option_symbol),
    event_at timestamptz NOT NULL,
    available_at timestamptz NOT NULL,
    recorded_at timestamptz NOT NULL,
    price double precision NOT NULL CHECK (
        market_data.is_finite(price) AND price >= 0
    ),
    size bigint NOT NULL CHECK (size > 0),
    exchange text,
    conditions text[],
    sequence_number bigint NOT NULL,
    source text NOT NULL,
    data_quality text NOT NULL,
    PRIMARY KEY (batch_id, option_symbol, event_at, sequence_number),
    CHECK (available_at >= event_at),
    CHECK (recorded_at >= available_at)
) PARTITION BY RANGE (event_at);

CREATE TABLE IF NOT EXISTS market_data.option_minute_bars (
    batch_id text NOT NULL REFERENCES market_data.batches(batch_id),
    option_symbol text NOT NULL REFERENCES market_data.option_contracts(option_symbol),
    event_at timestamptz NOT NULL,
    available_at timestamptz NOT NULL,
    recorded_at timestamptz NOT NULL,
    open double precision NOT NULL CHECK (
        market_data.is_finite(open) AND open >= 0
    ),
    high double precision NOT NULL CHECK (
        market_data.is_finite(high) AND high >= 0
    ),
    low double precision NOT NULL CHECK (
        market_data.is_finite(low) AND low >= 0
    ),
    close double precision NOT NULL CHECK (
        market_data.is_finite(close) AND close >= 0
    ),
    volume bigint NOT NULL CHECK (volume >= 0),
    transaction_count bigint CHECK (transaction_count IS NULL OR transaction_count >= 0),
    source text NOT NULL,
    data_quality text NOT NULL,
    PRIMARY KEY (batch_id, option_symbol, event_at),
    CHECK (high >= greatest(open, low, close)),
    CHECK (low <= least(open, high, close)),
    CHECK (available_at >= event_at),
    CHECK (recorded_at >= available_at)
) PARTITION BY RANGE (event_at);

CREATE TABLE IF NOT EXISTS market_data.option_open_interest (
    batch_id text NOT NULL REFERENCES market_data.batches(batch_id),
    option_symbol text NOT NULL REFERENCES market_data.option_contracts(option_symbol),
    observation_date date NOT NULL,
    published_at timestamptz NOT NULL,
    available_at timestamptz NOT NULL,
    recorded_at timestamptz NOT NULL,
    open_interest bigint NOT NULL CHECK (open_interest >= 0),
    source text NOT NULL,
    data_quality text NOT NULL,
    PRIMARY KEY (batch_id, option_symbol, observation_date),
    CHECK (available_at >= published_at),
    CHECK (recorded_at >= available_at)
);

CREATE TABLE IF NOT EXISTS market_data.occ_daily_open_interest_totals (
    batch_id text NOT NULL REFERENCES market_data.batches(batch_id),
    observation_date date NOT NULL,
    available_at timestamptz NOT NULL,
    recorded_at timestamptz NOT NULL,
    equity_calls bigint NOT NULL CHECK (equity_calls >= 0),
    equity_puts bigint NOT NULL CHECK (equity_puts >= 0),
    equity_total bigint NOT NULL CHECK (equity_total = equity_calls + equity_puts),
    index_other_calls bigint NOT NULL CHECK (index_other_calls >= 0),
    index_other_puts bigint NOT NULL CHECK (index_other_puts >= 0),
    index_other_total bigint NOT NULL CHECK (
        index_other_total = index_other_calls + index_other_puts
    ),
    debt_calls bigint NOT NULL CHECK (debt_calls >= 0),
    debt_puts bigint NOT NULL CHECK (debt_puts >= 0),
    debt_total bigint NOT NULL CHECK (debt_total = debt_calls + debt_puts),
    futures_total bigint NOT NULL CHECK (futures_total >= 0),
    occ_total bigint NOT NULL CHECK (occ_total >= 0),
    source text NOT NULL,
    data_quality text NOT NULL,
    PRIMARY KEY (batch_id, observation_date),
    CHECK (recorded_at >= available_at)
);

CREATE TABLE IF NOT EXISTS market_data.readiness_receipts (
    receipt_id text PRIMARY KEY,
    observed_at timestamptz NOT NULL,
    provider text NOT NULL,
    dataset text NOT NULL,
    symbols text[] NOT NULL,
    entitlement_status text NOT NULL,
    freshness_status text NOT NULL,
    coverage_status text NOT NULL,
    license_scope text NOT NULL,
    details jsonb NOT NULL,
    inserted_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE TABLE IF NOT EXISTS market_data.coverage_receipts (
    batch_id text NOT NULL REFERENCES market_data.batches(batch_id),
    dataset text NOT NULL,
    symbol text NOT NULL CHECK (symbol = upper(symbol)),
    minimum_event_at timestamptz,
    maximum_event_at timestamptz,
    row_count bigint NOT NULL CHECK (row_count >= 0),
    vwap_row_count bigint NOT NULL CHECK (vwap_row_count >= 0),
    bid_row_count bigint NOT NULL CHECK (bid_row_count >= 0),
    ask_row_count bigint NOT NULL CHECK (ask_row_count >= 0),
    trade_count_row_count bigint NOT NULL CHECK (trade_count_row_count >= 0),
    generated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    PRIMARY KEY (batch_id, dataset, symbol),
    CHECK (
        (row_count = 0 AND minimum_event_at IS NULL AND maximum_event_at IS NULL)
        OR
        (row_count > 0 AND minimum_event_at IS NOT NULL AND maximum_event_at >= minimum_event_at)
    ),
    CHECK (vwap_row_count <= row_count),
    CHECK (bid_row_count <= row_count),
    CHECK (ask_row_count <= row_count),
    CHECK (trade_count_row_count <= row_count)
);

CREATE TABLE IF NOT EXISTS market_data.live_archive_receipts (
    receipt_id text PRIMARY KEY CHECK (receipt_id ~ '^[0-9a-f]{64}$'),
    source_id text NOT NULL,
    decision_cutoff timestamptz NOT NULL,
    first_recorded_at timestamptz,
    last_recorded_at timestamptz,
    first_event_at timestamptz,
    last_event_at timestamptz,
    attempted_rows bigint NOT NULL CHECK (attempted_rows >= 0),
    inserted_rows bigint NOT NULL CHECK (inserted_rows >= 0),
    duplicate_rows bigint NOT NULL CHECK (duplicate_rows >= 0),
    content_sha256 text NOT NULL CHECK (content_sha256 ~ '^[0-9a-f]{64}$'),
    license_scope text NOT NULL CHECK (
        license_scope IN ('RESEARCH_ONLY', 'INTERNAL_USE', 'PUBLIC_DISPLAY', 'REDISTRIBUTION')
    ),
    license_reference_sha256 text NOT NULL CHECK (license_reference_sha256 ~ '^[0-9a-f]{64}$'),
    completed_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    CHECK (attempted_rows = inserted_rows + duplicate_rows),
    CHECK (
        (attempted_rows = 0 AND first_recorded_at IS NULL AND last_recorded_at IS NULL
            AND first_event_at IS NULL AND last_event_at IS NULL)
        OR
        (attempted_rows > 0 AND last_recorded_at >= first_recorded_at
            AND last_event_at >= first_event_at)
    )
);

CREATE INDEX IF NOT EXISTS batches_provider_dataset_idx
    ON market_data.batches(provider, dataset, captured_at DESC);
CREATE INDEX IF NOT EXISTS option_contracts_underlying_expiration_idx
    ON market_data.option_contracts(underlying_symbol, expiration_date, strike, option_right);
CREATE INDEX IF NOT EXISTS option_oi_symbol_available_idx
    ON market_data.option_open_interest(option_symbol, available_at DESC);
CREATE INDEX IF NOT EXISTS option_minute_bars_symbol_event_idx
    ON market_data.option_minute_bars(option_symbol, event_at DESC, available_at DESC);
CREATE INDEX IF NOT EXISTS readiness_provider_dataset_idx
    ON market_data.readiness_receipts(provider, dataset, observed_at DESC);
CREATE INDEX IF NOT EXISTS coverage_dataset_symbol_idx
    ON market_data.coverage_receipts(dataset, symbol, maximum_event_at DESC);
CREATE INDEX IF NOT EXISTS live_archive_receipts_cutoff_idx
    ON market_data.live_archive_receipts(source_id, decision_cutoff DESC);

DROP TRIGGER IF EXISTS batches_reject_update_delete ON market_data.batches;
CREATE TRIGGER batches_reject_update_delete
BEFORE UPDATE OR DELETE ON market_data.batches
FOR EACH ROW EXECUTE FUNCTION market_data.reject_mutation();

DROP TRIGGER IF EXISTS equity_minute_bars_reject_update_delete ON market_data.equity_minute_bars;
CREATE TRIGGER equity_minute_bars_reject_update_delete
BEFORE UPDATE OR DELETE ON market_data.equity_minute_bars
FOR EACH ROW EXECUTE FUNCTION market_data.reject_mutation();

DROP TRIGGER IF EXISTS live_equity_minute_bars_reject_update_delete
    ON market_data.live_equity_minute_bars;
CREATE TRIGGER live_equity_minute_bars_reject_update_delete
BEFORE UPDATE OR DELETE ON market_data.live_equity_minute_bars
FOR EACH ROW EXECUTE FUNCTION market_data.reject_mutation();

DROP TRIGGER IF EXISTS equity_nbbo_quotes_reject_update_delete ON market_data.equity_nbbo_quotes;
CREATE TRIGGER equity_nbbo_quotes_reject_update_delete
BEFORE UPDATE OR DELETE ON market_data.equity_nbbo_quotes
FOR EACH ROW EXECUTE FUNCTION market_data.reject_mutation();

DROP TRIGGER IF EXISTS option_contracts_reject_update_delete ON market_data.option_contracts;
CREATE TRIGGER option_contracts_reject_update_delete
BEFORE UPDATE OR DELETE ON market_data.option_contracts
FOR EACH ROW EXECUTE FUNCTION market_data.reject_mutation();

DROP TRIGGER IF EXISTS option_quotes_reject_update_delete ON market_data.option_quotes;
CREATE TRIGGER option_quotes_reject_update_delete
BEFORE UPDATE OR DELETE ON market_data.option_quotes
FOR EACH ROW EXECUTE FUNCTION market_data.reject_mutation();

DROP TRIGGER IF EXISTS option_trades_reject_update_delete ON market_data.option_trades;
CREATE TRIGGER option_trades_reject_update_delete
BEFORE UPDATE OR DELETE ON market_data.option_trades
FOR EACH ROW EXECUTE FUNCTION market_data.reject_mutation();

DROP TRIGGER IF EXISTS option_minute_bars_reject_update_delete ON market_data.option_minute_bars;
CREATE TRIGGER option_minute_bars_reject_update_delete
BEFORE UPDATE OR DELETE ON market_data.option_minute_bars
FOR EACH ROW EXECUTE FUNCTION market_data.reject_mutation();

DROP TRIGGER IF EXISTS option_open_interest_reject_update_delete ON market_data.option_open_interest;
CREATE TRIGGER option_open_interest_reject_update_delete
BEFORE UPDATE OR DELETE ON market_data.option_open_interest
FOR EACH ROW EXECUTE FUNCTION market_data.reject_mutation();

DROP TRIGGER IF EXISTS occ_daily_open_interest_totals_reject_update_delete
    ON market_data.occ_daily_open_interest_totals;
CREATE TRIGGER occ_daily_open_interest_totals_reject_update_delete
BEFORE UPDATE OR DELETE ON market_data.occ_daily_open_interest_totals
FOR EACH ROW EXECUTE FUNCTION market_data.reject_mutation();

DROP TRIGGER IF EXISTS readiness_receipts_reject_update_delete ON market_data.readiness_receipts;
CREATE TRIGGER readiness_receipts_reject_update_delete
BEFORE UPDATE OR DELETE ON market_data.readiness_receipts
FOR EACH ROW EXECUTE FUNCTION market_data.reject_mutation();

DROP TRIGGER IF EXISTS coverage_receipts_reject_update_delete ON market_data.coverage_receipts;
CREATE TRIGGER coverage_receipts_reject_update_delete
BEFORE UPDATE OR DELETE ON market_data.coverage_receipts
FOR EACH ROW EXECUTE FUNCTION market_data.reject_mutation();

DROP TRIGGER IF EXISTS live_archive_receipts_reject_update_delete
    ON market_data.live_archive_receipts;
CREATE TRIGGER live_archive_receipts_reject_update_delete
BEFORE UPDATE OR DELETE ON market_data.live_archive_receipts
FOR EACH ROW EXECUTE FUNCTION market_data.reject_mutation();

CREATE OR REPLACE FUNCTION market_data.equity_minute_bars_asof(
    requested_symbols text[],
    event_start timestamptz,
    event_end timestamptz,
    decision_cutoff timestamptz
)
RETURNS TABLE (
    symbol text,
    event_at timestamptz,
    available_at timestamptz,
    open double precision,
    high double precision,
    low double precision,
    close double precision,
    volume double precision,
    vwap double precision,
    bid double precision,
    ask double precision,
    trade_count bigint,
    source text,
    batch_id text
)
LANGUAGE sql
STABLE
AS $$
    SELECT DISTINCT ON (b.symbol, b.event_at)
        b.symbol,
        b.event_at,
        b.available_at,
        b.open,
        b.high,
        b.low,
        b.close,
        b.volume,
        b.vwap,
        b.bid,
        b.ask,
        b.trade_count,
        b.source,
        b.batch_id
    FROM market_data.equity_minute_bars AS b
    WHERE b.symbol = ANY(requested_symbols)
      AND b.event_at >= event_start
      AND b.event_at < event_end
      AND b.available_at <= decision_cutoff
      AND b.recorded_at <= decision_cutoff
    ORDER BY b.symbol, b.event_at, b.available_at DESC, b.recorded_at DESC, b.batch_id
$$;

CREATE OR REPLACE FUNCTION market_data.equity_minute_bars_unified_asof(
    requested_symbols text[],
    event_start timestamptz,
    event_end timestamptz,
    decision_cutoff timestamptz
)
RETURNS TABLE (
    provider text,
    dataset text,
    schema_name text,
    symbol text,
    event_at timestamptz,
    available_at timestamptz,
    recorded_at timestamptz,
    finalized_at timestamptz,
    open double precision,
    high double precision,
    low double precision,
    close double precision,
    volume double precision,
    vwap double precision,
    trade_count bigint,
    source text,
    data_quality text,
    entitlement text,
    license_scope text,
    license_reference text,
    provenance_id text
)
LANGUAGE sql
STABLE
AS $$
    WITH eligible AS (
        SELECT
            batches.provider,
            batches.dataset,
            'EQUITY_MINUTE_BARS'::text AS schema_name,
            bars.symbol,
            bars.event_at,
            bars.available_at,
            bars.recorded_at,
            bars.available_at AS finalized_at,
            bars.open,
            bars.high,
            bars.low,
            bars.close,
            bars.volume,
            bars.vwap,
            bars.trade_count,
            bars.source,
            bars.data_quality,
            'HISTORICAL_BATCH'::text AS entitlement,
            batches.license_scope,
            batches.license_reference,
            bars.batch_id AS provenance_id
        FROM market_data.equity_minute_bars AS bars
        JOIN market_data.batches AS batches USING (batch_id)
        WHERE bars.symbol = ANY(requested_symbols)
          AND bars.event_at >= event_start
          AND bars.event_at < event_end
          AND bars.available_at <= decision_cutoff
          AND bars.recorded_at <= decision_cutoff
        UNION ALL
        SELECT
            live.provider,
            live.dataset,
            live.schema_name,
            live.symbol,
            live.event_at,
            live.available_at,
            live.recorded_at,
            live.finalized_at,
            live.open,
            live.high,
            live.low,
            live.close,
            live.volume,
            live.vwap,
            live.trade_count,
            live.source,
            live.data_quality,
            live.entitlement,
            live.license_scope,
            live.license_reference_sha256 AS license_reference,
            concat_ws('|', live.provider, live.dataset, live.schema_name) AS provenance_id
        FROM market_data.live_equity_minute_bars AS live
        WHERE live.symbol = ANY(requested_symbols)
          AND live.event_at >= event_start
          AND live.event_at < event_end
          AND live.available_at <= decision_cutoff
          AND live.recorded_at <= decision_cutoff
    )
    SELECT DISTINCT ON (eligible.symbol, eligible.event_at)
        eligible.provider,
        eligible.dataset,
        eligible.schema_name,
        eligible.symbol,
        eligible.event_at,
        eligible.available_at,
        eligible.recorded_at,
        eligible.finalized_at,
        eligible.open,
        eligible.high,
        eligible.low,
        eligible.close,
        eligible.volume,
        eligible.vwap,
        eligible.trade_count,
        eligible.source,
        eligible.data_quality,
        eligible.entitlement,
        eligible.license_scope,
        eligible.license_reference,
        eligible.provenance_id
    FROM eligible
    ORDER BY
        eligible.symbol,
        eligible.event_at,
        eligible.recorded_at DESC,
        eligible.available_at DESC,
        eligible.provenance_id
$$;

CREATE OR REPLACE FUNCTION market_data.option_minute_bars_asof(
    requested_contracts text[],
    event_start timestamptz,
    event_end timestamptz,
    decision_cutoff timestamptz
)
RETURNS TABLE (
    option_symbol text,
    event_at timestamptz,
    available_at timestamptz,
    open double precision,
    high double precision,
    low double precision,
    close double precision,
    volume bigint,
    transaction_count bigint,
    source text,
    batch_id text
)
LANGUAGE sql
STABLE
AS $$
    SELECT DISTINCT ON (b.option_symbol, b.event_at)
        b.option_symbol,
        b.event_at,
        b.available_at,
        b.open,
        b.high,
        b.low,
        b.close,
        b.volume,
        b.transaction_count,
        b.source,
        b.batch_id
    FROM market_data.option_minute_bars AS b
    WHERE b.option_symbol = ANY(requested_contracts)
      AND b.event_at >= event_start
      AND b.event_at < event_end
      AND b.available_at <= decision_cutoff
    ORDER BY
        b.option_symbol,
        b.event_at,
        b.available_at DESC,
        b.recorded_at DESC,
        b.batch_id
$$;
