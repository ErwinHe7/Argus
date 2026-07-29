-- Preserve abandoned Paddle transactions while allowing the same user to make
-- a new, explicit plan selection after closing an unpaid checkout overlay.

ALTER TABLE public.paddle_checkout_attempts
  DROP CONSTRAINT IF EXISTS paddle_checkout_attempts_state_check;
ALTER TABLE public.paddle_checkout_attempts
  ADD CONSTRAINT paddle_checkout_attempts_state_check
  CHECK (state IN ('creating', 'ready', 'completed', 'abandoned'));

ALTER TABLE public.paddle_checkout_attempts
  DROP CONSTRAINT IF EXISTS paddle_checkout_attempts_state_transaction_check;
ALTER TABLE public.paddle_checkout_attempts
  ADD CONSTRAINT paddle_checkout_attempts_state_transaction_check
  CHECK (
    (state = 'creating' AND transaction_id IS NULL)
    OR (state IN ('ready', 'completed', 'abandoned') AND transaction_id IS NOT NULL)
  );

CREATE OR REPLACE FUNCTION public.claim_paddle_checkout_attempt(
  p_environment text,
  p_test_mode boolean,
  p_user_id text,
  p_attempt_token text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  inserted boolean := false;
  existing public.paddle_checkout_attempts%ROWTYPE;
BEGIN
  IF p_environment NOT IN ('sandbox', 'live')
     OR p_test_mode IS DISTINCT FROM (p_environment = 'sandbox')
     OR NULLIF(btrim(p_user_id), '') IS NULL
     OR length(p_attempt_token) NOT BETWEEN 16 AND 128 THEN
    RAISE EXCEPTION 'Invalid Paddle checkout claim';
  END IF;

  INSERT INTO public.paddle_checkout_attempts (
    environment, test_mode, user_id, attempt_token, state, claimed_at, updated_at
  ) VALUES (
    p_environment, p_test_mode, p_user_id, p_attempt_token, 'creating', now(), now()
  )
  ON CONFLICT (environment, user_id) DO NOTHING
  RETURNING true INTO inserted;

  IF COALESCE(inserted, false) THEN
    RETURN jsonb_build_object('state', 'claimed', 'attempt_token', p_attempt_token);
  END IF;

  SELECT * INTO existing
  FROM public.paddle_checkout_attempts
  WHERE environment = p_environment AND user_id = p_user_id;

  IF existing.state = 'ready' AND existing.transaction_id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'state', 'ready',
      'attempt_token', existing.attempt_token,
      'transaction_id', existing.transaction_id
    );
  END IF;
  IF existing.state IN ('completed', 'abandoned') THEN
    UPDATE public.paddle_checkout_attempts
    SET
      attempt_token = p_attempt_token,
      transaction_id = NULL,
      state = 'creating',
      claimed_at = now(),
      completed_at = NULL,
      updated_at = now()
    WHERE environment = p_environment
      AND user_id = p_user_id
      AND state = existing.state
      AND attempt_token = existing.attempt_token
    RETURNING * INTO existing;
    IF existing.state = 'creating' AND existing.attempt_token = p_attempt_token THEN
      RETURN jsonb_build_object('state', 'claimed', 'attempt_token', p_attempt_token);
    END IF;
    RETURN jsonb_build_object('state', 'busy', 'attempt_token', p_attempt_token);
  END IF;
  IF existing.state = 'creating' AND existing.claimed_at < now() - interval '2 minutes' THEN
    RETURN jsonb_build_object('state', 'recover', 'attempt_token', existing.attempt_token);
  END IF;
  RETURN jsonb_build_object('state', 'busy', 'attempt_token', existing.attempt_token);
END;
$$;

CREATE OR REPLACE FUNCTION public.abandon_paddle_checkout_attempt(
  p_environment text,
  p_user_id text,
  p_attempt_token text,
  p_transaction_id text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  abandoned boolean := false;
BEGIN
  IF p_environment NOT IN ('sandbox', 'live')
     OR NULLIF(btrim(p_user_id), '') IS NULL
     OR p_attempt_token IS NULL
     OR length(p_attempt_token) NOT BETWEEN 16 AND 128
     OR p_transaction_id IS NULL
     OR p_transaction_id NOT LIKE 'txn\_%' ESCAPE '\' THEN
    RAISE EXCEPTION 'Invalid Paddle checkout abandonment';
  END IF;

  UPDATE public.paddle_checkout_attempts
  SET state = 'abandoned', updated_at = now()
  WHERE environment = p_environment
    AND user_id = p_user_id
    AND state = 'ready'
    AND attempt_token = p_attempt_token
    AND transaction_id = p_transaction_id
  RETURNING true INTO abandoned;

  IF COALESCE(abandoned, false) THEN
    RETURN true;
  END IF;

  -- Idempotent replay: a browser may emit CHECKOUT_CLOSED more than once.
  RETURN EXISTS (
    SELECT 1
    FROM public.paddle_checkout_attempts
    WHERE environment = p_environment
      AND user_id = p_user_id
      AND state = 'abandoned'
      AND attempt_token = p_attempt_token
      AND transaction_id = p_transaction_id
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.paddle_billing_storage_ready()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    to_regclass('public.billing_provider_accounts') IS NOT NULL
    AND to_regclass('public.payment_webhook_events') IS NOT NULL
    AND to_regclass('public.paddle_customers') IS NOT NULL
    AND to_regclass('public.paddle_subscriptions') IS NOT NULL
    AND to_regclass('public.paddle_transactions') IS NOT NULL
    AND to_regclass('public.paddle_webhook_events') IS NOT NULL
    AND to_regclass('public.paddle_checkout_attempts') IS NOT NULL
    AND to_regprocedure('public.claim_paddle_checkout_attempt(text,boolean,text,text)') IS NOT NULL
    AND to_regprocedure('public.reset_paddle_checkout_attempt(text,text,text,text)') IS NOT NULL
    AND to_regprocedure('public.rotate_paddle_ready_checkout_attempt(text,text,text,text,text)') IS NOT NULL
    AND to_regprocedure('public.finalize_paddle_checkout_attempt(text,text,text,text)') IS NOT NULL
    AND to_regprocedure('public.complete_paddle_checkout_attempt(text,text,text)') IS NOT NULL
    AND to_regprocedure('public.abandon_paddle_checkout_attempt(text,text,text,text)') IS NOT NULL
    AND to_regprocedure('public.claim_paddle_webhook_event(text,boolean,text,text,text,text,timestamptz)') IS NOT NULL
    AND to_regprocedure('public.complete_paddle_webhook_event(text,text,text)') IS NOT NULL
    AND to_regprocedure('public.fail_paddle_webhook_event(text,text,text,text)') IS NOT NULL
    AND to_regprocedure('public.apply_paddle_customer(text,boolean,text,text,text,text,text,timestamptz,timestamptz,timestamptz)') IS NOT NULL
    AND to_regprocedure('public.apply_paddle_subscription(text,boolean,text,text,text,text,text,text,text,timestamptz,text,timestamptz,timestamptz,timestamptz,timestamptz)') IS NOT NULL
    AND to_regprocedure('public.apply_paddle_transaction(text,boolean,text,text,text,text,text,text,text,text,text,timestamptz,timestamptz,timestamptz)') IS NOT NULL
    AND to_regprocedure('public.apply_paddle_billing_account(text,boolean,text,text,text,text,text,timestamptz,boolean,timestamptz,timestamptz)') IS NOT NULL;
$$;

REVOKE ALL ON FUNCTION public.claim_paddle_checkout_attempt(text, boolean, text, text)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.abandon_paddle_checkout_attempt(text, text, text, text)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.paddle_billing_storage_ready()
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_paddle_checkout_attempt(text, boolean, text, text)
  TO service_role;
GRANT EXECUTE ON FUNCTION public.abandon_paddle_checkout_attempt(text, text, text, text)
  TO service_role;
GRANT EXECUTE ON FUNCTION public.paddle_billing_storage_ready()
  TO service_role;

COMMENT ON FUNCTION public.abandon_paddle_checkout_attempt(text, text, text, text) IS
  'Marks one verified, provider-canceled unpaid checkout as abandoned without deleting its transaction history.';

NOTIFY pgrst, 'reload schema';
