-- Introduce the neutral, model-owned forecast query without breaking durable
-- v1 explicit-rule monitors during a rolling web/Rust deployment.

ALTER TABLE public.market_monitors
  DROP CONSTRAINT IF EXISTS market_monitors_query_version_check;

ALTER TABLE public.market_monitors
  ADD CONSTRAINT market_monitors_query_version_check
    CHECK (
      query ->> 'version' IN (
        'axio.market-query.v1',
        'axio.market-query.v2'
      )
    );

ALTER TABLE public.market_monitors
  DROP CONSTRAINT IF EXISTS market_monitors_setup_check;

ALTER TABLE public.market_monitors
  ADD CONSTRAINT market_monitors_setup_check
    CHECK (
      query ->> 'setup_type' IN (
        'model_forecast',
        'momentum',
        'gamma_squeeze',
        'vwap_reversal',
        'opening_turn',
        'closing_short_cover',
        'statistical_dislocation'
      )
      AND (
        query ->> 'setup_type' <> 'model_forecast'
        OR query ->> 'version' = 'axio.market-query.v2'
      )
    );
