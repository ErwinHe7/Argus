BEGIN;

CREATE TABLE outbox_dispatch_failures (
  outbox_id uuid PRIMARY KEY REFERENCES outbox_events(id),
  topic text NOT NULL,
  failure_code text NOT NULL CHECK (failure_code = 'unknown_outbox_topic'),
  failed_at timestamptz NOT NULL DEFAULT now()
);

CREATE FUNCTION ritual_private.terminalize_unroutable_outbox(target_ids uuid[])
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE terminalized integer;
BEGIN
  INSERT INTO outbox_dispatch_failures(outbox_id,topic,failure_code)
  SELECT event.id,event.topic,'unknown_outbox_topic'
  FROM outbox_events event
  WHERE event.id=ANY(target_ids) AND event.published_at IS NULL
  ON CONFLICT (outbox_id) DO NOTHING;
  UPDATE outbox_events
     SET published_at=coalesce(published_at,now())
   WHERE id=ANY(target_ids) AND published_at IS NULL;
  GET DIAGNOSTICS terminalized=ROW_COUNT;
  RETURN terminalized;
END
$$;
ALTER FUNCTION ritual_private.terminalize_unroutable_outbox(uuid[]) OWNER TO ritual_function_owner;
REVOKE ALL ON FUNCTION ritual_private.terminalize_unroutable_outbox(uuid[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ritual_private.terminalize_unroutable_outbox(uuid[]) TO ritual_scheduler;

CREATE FUNCTION ritual_private.enqueue_due_recurring_plans(
  target_now timestamptz,
  target_limit integer
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE inserted_count integer;
BEGIN
  IF target_limit NOT BETWEEN 1 AND 500 THEN
    RAISE EXCEPTION 'invalid recurring schedule limit' USING ERRCODE='22023';
  END IF;
  WITH due AS (
    SELECT plan.id,plan.tenant_id,plan.version,plan.reset_generation,plan.next_run_at
      FROM recurring_plans plan
      JOIN tenants tenant ON tenant.id=plan.tenant_id AND tenant.status='active'
      JOIN tenant_demo_states state ON state.tenant_id=plan.tenant_id
        AND state.reset_generation=plan.reset_generation
     WHERE plan.status='active' AND plan.next_run_at<=target_now
     ORDER BY plan.next_run_at,plan.id
     LIMIT target_limit
     FOR UPDATE OF plan SKIP LOCKED
  )
  INSERT INTO outbox_events(
    topic,aggregate_kind,aggregate_id,aggregate_version,tenant_id,
    reset_generation,deletion_generation,dedupe_key,payload,schema_version,available_at
  )
  SELECT 'recurring.plan.due','recurring-plan',due.id,due.version,due.tenant_id,
    due.reset_generation,0,
    due.id::text || ':' || due.reset_generation::text || ':' || due.version::text || ':' || due.next_run_at::text,
    jsonb_build_object(
      'plan_id',due.id,
      'scheduled_for',due.next_run_at,
      'reset_generation',due.reset_generation
    ),1,target_now
  FROM due
  ON CONFLICT (topic,dedupe_key) DO NOTHING;
  GET DIAGNOSTICS inserted_count=ROW_COUNT;
  RETURN inserted_count;
END
$$;
ALTER FUNCTION ritual_private.enqueue_due_recurring_plans(timestamptz,integer) OWNER TO ritual_function_owner;
REVOKE ALL ON FUNCTION ritual_private.enqueue_due_recurring_plans(timestamptz,integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ritual_private.enqueue_due_recurring_plans(timestamptz,integer) TO ritual_scheduler;

CREATE FUNCTION ritual_private.enqueue_expired_privacy_exports(
  target_now timestamptz,
  target_limit integer
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE inserted_count integer;
BEGIN
  IF target_limit NOT BETWEEN 1 AND 500 THEN
    RAISE EXCEPTION 'invalid retention schedule limit' USING ERRCODE='22023';
  END IF;
  WITH expired AS (
    SELECT artifact.id,artifact.tenant_id,artifact.expires_at,
           coalesce(state.reset_generation,0) reset_generation
      FROM privacy_export_artifacts artifact
      JOIN tenants tenant ON tenant.id=artifact.tenant_id AND tenant.status='active'
      LEFT JOIN tenant_demo_states state ON state.tenant_id=artifact.tenant_id
     WHERE artifact.publication_state IN ('published','revoked')
       AND artifact.expires_at<=target_now
     ORDER BY artifact.expires_at,artifact.id
     LIMIT target_limit
     FOR UPDATE OF artifact SKIP LOCKED
  )
  INSERT INTO outbox_events(
    topic,aggregate_kind,aggregate_id,aggregate_version,tenant_id,
    reset_generation,deletion_generation,dedupe_key,payload,schema_version,available_at
  )
  SELECT 'privacy.export.retention.requested','privacy-export-artifact',expired.id,1,
    expired.tenant_id,expired.reset_generation,0,
    'retention:' || expired.id::text || ':' || expired.expires_at::text,
    jsonb_build_object('artifact_id',expired.id),1,target_now
  FROM expired
  ON CONFLICT (topic,dedupe_key) DO NOTHING;
  GET DIAGNOSTICS inserted_count=ROW_COUNT;
  RETURN inserted_count;
END
$$;
ALTER FUNCTION ritual_private.enqueue_expired_privacy_exports(timestamptz,integer) OWNER TO ritual_function_owner;
REVOKE ALL ON FUNCTION ritual_private.enqueue_expired_privacy_exports(timestamptz,integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ritual_private.enqueue_expired_privacy_exports(timestamptz,integer) TO ritual_scheduler;

CREATE FUNCTION ritual_private.finish_job_attempt(
  target_job_id uuid,
  target_lease_owner uuid,
  target_status text,
  target_failure_code text,
  target_delay_seconds integer
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE target_outbox_id uuid;
DECLARE event_topic text;
DECLARE event_tenant_id uuid;
DECLARE event_payload jsonb;
BEGIN
  IF target_status NOT IN ('retry','dead_letter') THEN
    RAISE EXCEPTION 'invalid terminal job status' USING ERRCODE='22023';
  END IF;
  UPDATE job_runs
     SET status=target_status,failure_code=target_failure_code,lease_until=null,
         next_attempt_at=CASE WHEN target_status='retry'
           THEN now()+make_interval(secs=>target_delay_seconds) END,
         completed_at=CASE WHEN target_status='dead_letter' THEN now() END
   WHERE id=target_job_id AND lease_owner=target_lease_owner AND status='leased'
   RETURNING outbox_id INTO target_outbox_id;
  IF target_outbox_id IS NULL THEN RETURN false; END IF;
  IF target_status='dead_letter' THEN
    SELECT topic,tenant_id,payload INTO event_topic,event_tenant_id,event_payload
      FROM outbox_events WHERE id=target_outbox_id;
    IF event_topic='privacy.export.requested' THEN
      UPDATE privacy_requests
         SET status='failed',failure_code=target_failure_code,completed_at=now()
       WHERE tenant_id=event_tenant_id
         AND id=(event_payload->>'request_id')::uuid
         AND status IN ('queued','processing');
    ELSIF event_topic='privacy.deletion.requested' THEN
      UPDATE privacy_requests
         SET status='failed',failure_code=target_failure_code,completed_at=now()
       WHERE tenant_id=event_tenant_id
         AND id=(event_payload->>'privacy_request_id')::uuid
         AND status IN ('queued','processing');
    END IF;
  END IF;
  RETURN true;
END
$$;
ALTER FUNCTION ritual_private.finish_job_attempt(uuid,uuid,text,text,integer) OWNER TO ritual_function_owner;
REVOKE ALL ON FUNCTION ritual_private.finish_job_attempt(uuid,uuid,text,text,integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ritual_private.finish_job_attempt(uuid,uuid,text,text,integer) TO ritual_scheduler;

-- The consumer receipt transaction calls this function once for a validated
-- recurring outbox event. Financial postings, the run marker, plan advancement,
-- and the receipt therefore commit or roll back as one unit.
CREATE FUNCTION ritual_private.apply_due_recurring_plan_event(target_outbox_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog, public
AS $$
#variable_conflict use_variable
DECLARE event outbox_events%ROWTYPE;
DECLARE plan recurring_plans%ROWTYPE;
DECLARE portfolio demo_portfolios%ROWTYPE;
DECLARE scheduled_for timestamptz;
DECLARE command_id uuid:=gen_random_uuid();
DECLARE idempotency_id uuid:=gen_random_uuid();
DECLARE transaction_id uuid:=gen_random_uuid();
DECLARE snapshot_id uuid:=gen_random_uuid();
DECLARE watermark bigint;
DECLARE snapshot_generation integer;
DECLARE cash_total bigint;
DECLARE market_total bigint;
DECLARE allocation record;
DECLARE allocation_count integer:=0;
DECLARE notional bigint;
DECLARE quantity numeric(30,12);
DECLARE cost_delta bigint;
BEGIN
  -- The receipt consumer already holds the per-outbox advisory lock and outbox
  -- identity is immutable, so no UPDATE privilege is needed on this row.
  SELECT * INTO event FROM outbox_events WHERE id=target_outbox_id;
  IF event.id IS NULL OR event.topic<>'recurring.plan.due' OR event.tenant_id IS NULL THEN
    RAISE EXCEPTION 'invalid_event_payload' USING ERRCODE='22023';
  END IF;
  scheduled_for:=(event.payload->>'scheduled_for')::timestamptz;
  IF (event.payload->>'plan_id')::uuid IS DISTINCT FROM event.aggregate_id
     OR (event.payload->>'reset_generation')::integer IS DISTINCT FROM event.reset_generation THEN
    RAISE EXCEPTION 'invalid_event_payload' USING ERRCODE='22023';
  END IF;
  IF EXISTS (
    SELECT 1 FROM recurring_plan_runs run
     WHERE run.tenant_id=event.tenant_id AND run.plan_id=event.aggregate_id
       AND run.reset_generation=event.reset_generation
       AND run.scheduled_for=scheduled_for
  ) THEN RETURN 'duplicate'; END IF;
  SELECT * INTO plan FROM recurring_plans candidate
   WHERE candidate.tenant_id=event.tenant_id AND candidate.id=event.aggregate_id
     AND candidate.reset_generation=event.reset_generation
     AND candidate.version=event.aggregate_version
     AND candidate.status='active' AND candidate.next_run_at=scheduled_for
   FOR UPDATE;
  IF plan.id IS NULL THEN RETURN 'stale'; END IF;
  SELECT * INTO portfolio FROM demo_portfolios candidate
   WHERE candidate.tenant_id=plan.tenant_id AND candidate.id=plan.portfolio_id
     AND candidate.reset_generation=plan.reset_generation AND candidate.status='active'
   FOR UPDATE;
  IF portfolio.id IS NULL OR NOT EXISTS (
    SELECT 1 FROM demo_funding_sources source
     WHERE source.tenant_id=plan.tenant_id AND source.id=plan.source_id
       AND source.reset_generation=plan.reset_generation AND source.status='active'
  ) THEN RAISE EXCEPTION 'recurring_plan_delivery_failed'; END IF;

  INSERT INTO idempotency_records(
    id,tenant_id,reset_generation,operation,idempotency_key,request_hash,state,
    claim_owner,lease_until,expires_at
  ) VALUES (
    idempotency_id,event.tenant_id,event.reset_generation,'recurring.delivery',
    'recurring:' || target_outbox_id::text,
    encode(digest(target_outbox_id::text,'sha256'),'hex'),'processing',
    'worker:' || target_outbox_id::text,now()+interval '60 seconds',now()+interval '30 days'
  );
  INSERT INTO simulation_commands(
    id,tenant_id,reset_generation,portfolio_id,idempotency_id,command_type,status,
    committed_at,portfolio_input_version
  ) VALUES (
    command_id,event.tenant_id,event.reset_generation,plan.portfolio_id,idempotency_id,
    CASE WHEN plan.plan_type='contribution' THEN 'contribution' ELSE 'recurring' END,
    'committed',now(),portfolio.version
  );
  INSERT INTO ledger_transactions(
    id,tenant_id,reset_generation,portfolio_id,command_id,entry_type,effective_at,description_code
  ) VALUES (
    transaction_id,event.tenant_id,event.reset_generation,plan.portfolio_id,command_id,
    CASE WHEN plan.plan_type='contribution' THEN 'contribution' ELSE 'recurring' END,
    scheduled_for,'demo_recurring'
  ) RETURNING ledger_sequence INTO watermark;
  INSERT INTO cash_ledger_entries(tenant_id,transaction_id,currency,amount_minor)
  VALUES(event.tenant_id,transaction_id,'USD',plan.amount_minor);

  IF plan.plan_type='allocation' THEN
    FOR allocation IN
      SELECT configured.asset_id,configured.weight_bps,metric.price_minor
        FROM recurring_plan_allocations configured
        JOIN assets asset ON asset.id=configured.asset_id AND asset.status='active' AND asset.is_demo
        JOIN LATERAL (
          SELECT sample.price_minor FROM asset_metric_snapshots sample
           WHERE sample.asset_id=configured.asset_id AND sample.is_demo
           ORDER BY sample.observed_at DESC,sample.id DESC LIMIT 1
        ) metric ON true
       WHERE configured.tenant_id=event.tenant_id AND configured.plan_id=plan.id
       ORDER BY configured.asset_id
    LOOP
      allocation_count:=allocation_count+1;
      notional:=(plan.amount_minor*allocation.weight_bps)/10000;
      quantity:=trunc((notional::numeric*1000000000000)/allocation.price_minor)/1000000000000;
      IF quantity<=0 THEN RAISE EXCEPTION 'recurring_plan_delivery_failed'; END IF;
      cost_delta:=trunc(quantity*allocation.price_minor)::bigint;
      INSERT INTO cash_ledger_entries(tenant_id,transaction_id,currency,amount_minor)
      VALUES(event.tenant_id,transaction_id,'USD',-cost_delta);
      INSERT INTO position_ledger_entries(
        tenant_id,transaction_id,asset_id,quantity,unit_price_minor,cost_basis_delta_minor
      ) VALUES(
        event.tenant_id,transaction_id,allocation.asset_id,quantity,
        allocation.price_minor,cost_delta
      );
      INSERT INTO portfolio_positions(
        tenant_id,portfolio_id,asset_id,quantity,cost_basis_minor,
        as_of_transaction_id,ledger_watermark
      ) VALUES(
        event.tenant_id,plan.portfolio_id,allocation.asset_id,quantity,cost_delta,
        transaction_id,watermark
      )
      ON CONFLICT (tenant_id,portfolio_id,asset_id) DO UPDATE
        SET quantity=portfolio_positions.quantity+excluded.quantity,
            cost_basis_minor=portfolio_positions.cost_basis_minor+excluded.cost_basis_minor,
            as_of_transaction_id=excluded.as_of_transaction_id,
            ledger_watermark=excluded.ledger_watermark
      WHERE portfolio_positions.ledger_watermark<excluded.ledger_watermark;
    END LOOP;
    IF allocation_count=0 THEN RAISE EXCEPTION 'recurring_plan_delivery_failed'; END IF;
  END IF;

  SELECT coalesce(sum(entry.amount_minor),0)::bigint INTO cash_total
    FROM ledger_transactions transaction
    JOIN cash_ledger_entries entry ON entry.tenant_id=transaction.tenant_id
      AND entry.transaction_id=transaction.id
   WHERE transaction.tenant_id=event.tenant_id
     AND transaction.portfolio_id=plan.portfolio_id
     AND transaction.reset_generation=event.reset_generation;
  SELECT coalesce(sum(position.quantity*coalesce(metric.price_minor,0)),0)::bigint
    INTO market_total
    FROM portfolio_positions position
    LEFT JOIN LATERAL (
      SELECT sample.price_minor FROM asset_metric_snapshots sample
       WHERE sample.asset_id=position.asset_id AND sample.is_demo
       ORDER BY sample.observed_at DESC,sample.id DESC LIMIT 1
    ) metric ON true
   WHERE position.tenant_id=event.tenant_id AND position.portfolio_id=plan.portfolio_id;
  SELECT coalesce(max(projection_generation),0)+1 INTO snapshot_generation
    FROM portfolio_balance_snapshots
   WHERE tenant_id=event.tenant_id AND portfolio_id=plan.portfolio_id;
  INSERT INTO portfolio_balance_snapshots(
    id,tenant_id,portfolio_id,as_of_transaction_id,ledger_watermark,reset_generation,
    projection_generation,as_of,cash_minor,market_value_minor,source_hash
  ) VALUES(
    snapshot_id,event.tenant_id,plan.portfolio_id,transaction_id,watermark,
    event.reset_generation,snapshot_generation,scheduled_for,cash_total,market_total,
    encode(digest(transaction_id::text || ':' || watermark::text,'sha256'),'hex')
  );
  UPDATE demo_portfolios
     SET version=version+1,current_snapshot_id=snapshot_id,current_ledger_watermark=watermark
   WHERE tenant_id=event.tenant_id AND id=plan.portfolio_id
     AND reset_generation=event.reset_generation AND version=portfolio.version
     AND current_ledger_watermark<watermark;
  IF NOT FOUND THEN RAISE EXCEPTION 'recurring_plan_delivery_failed'; END IF;
  INSERT INTO recurring_plan_runs(
    tenant_id,reset_generation,plan_id,scheduled_for,command_id,status,attempted_at
  ) VALUES(
    event.tenant_id,event.reset_generation,plan.id,scheduled_for,command_id,'completed',now()
  );
  UPDATE recurring_plans
     SET last_scheduled_for=scheduled_for,
         next_run_at=scheduled_for+CASE frequency
           WHEN 'weekly' THEN interval '7 days' ELSE interval '1 month' END,
         version=version+1
   WHERE tenant_id=event.tenant_id AND id=plan.id
     AND reset_generation=event.reset_generation AND next_run_at=scheduled_for;
  UPDATE idempotency_records
     SET state='completed',command_id=command_id,
         response_hash=encode(digest(command_id::text,'sha256'),'hex'),
         terminal_response=jsonb_build_object(
           'command_id',command_id,'status','committed','scheduled_for',scheduled_for
         ),lease_until=null
   WHERE id=idempotency_id AND tenant_id=event.tenant_id;
  RETURN 'completed';
END
$$;
REVOKE ALL ON FUNCTION ritual_private.apply_due_recurring_plan_event(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ritual_private.apply_due_recurring_plan_event(uuid) TO ritual_runtime;

GRANT SELECT,INSERT ON TABLE outbox_dispatch_failures TO ritual_function_owner;
GRANT SELECT,UPDATE ON TABLE outbox_events,job_runs,privacy_requests TO ritual_function_owner;
GRANT SELECT ON TABLE tenants,tenant_demo_states TO ritual_function_owner;
-- PostgreSQL requires UPDATE privilege for SELECT ... FOR UPDATE, even though
-- the scheduler functions only claim rows and append outbox work.
GRANT SELECT,UPDATE ON TABLE recurring_plans,privacy_export_artifacts TO ritual_function_owner;
GRANT INSERT ON TABLE outbox_events TO ritual_function_owner;
GRANT USAGE,SELECT ON SEQUENCE ledger_transactions_ledger_sequence_seq TO ritual_runtime;

COMMIT;
