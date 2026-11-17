begin;
select plan(14);

select ok(exists(select 1 from information_schema.columns where table_schema='public' and table_name='srk_razorpay_webhook_events' and column_name='event_payload' and data_type='jsonb'),
  'webhook inbox stores the minimal validated event payload for asynchronous processing');
select ok(position('queued' in pg_get_constraintdef((select oid from pg_constraint where conrelid='public.srk_razorpay_webhook_events'::regclass and conname='srk_razorpay_webhook_events_state_check')))>0,
  'webhook inbox state constraint allows queued events');
select ok(position('octet_length(p_event_payload::text) > 32768' in pg_get_functiondef('public.srk_service_enqueue_razorpay_webhook_event(text,text,text,jsonb)'::regprocedure))>0,
  'enqueue RPC bounds persisted event payload size');
select ok(position('auth.jwt()' in pg_get_functiondef('public.srk_service_enqueue_razorpay_webhook_event(text,text,text,jsonb)'::regprocedure))>0
  and position('service_role' in pg_get_functiondef('public.srk_service_enqueue_razorpay_webhook_event(text,text,text,jsonb)'::regprocedure))>0,
  'durable enqueue RPC requires service-role JWT');
select ok(not has_function_privilege('anon','public.srk_service_enqueue_razorpay_webhook_event(text,text,text,jsonb)','execute')
  and not has_function_privilege('authenticated','public.srk_service_enqueue_razorpay_webhook_event(text,text,text,jsonb)','execute')
  and has_function_privilege('service_role','public.srk_service_enqueue_razorpay_webhook_event(text,text,text,jsonb)','execute'),
  'only service role can enqueue Razorpay webhook events');
select ok(position('for update skip locked' in lower(pg_get_functiondef('public.srk_service_claim_razorpay_webhook_event_for_worker(text)'::regprocedure)))>0,
  'worker claim uses row locking with skip-locked concurrency safety');
select ok(position('gen_random_uuid()' in pg_get_functiondef('public.srk_service_claim_razorpay_webhook_event_for_worker(text)'::regprocedure))>0
  and position('claim_token=v_token' in pg_get_functiondef('public.srk_service_claim_razorpay_webhook_event_for_worker(text)'::regprocedure))>0,
  'each background worker claim rotates its fencing token');
select ok(position('interval ''2 minutes''' in pg_get_functiondef('public.srk_service_claim_razorpay_webhook_event_for_worker(text)'::regprocedure))>0,
  'worker claim lease is bounded to two minutes for crash recovery');
select ok(position('event_payload is not null' in lower(pg_get_functiondef('public.srk_service_claim_razorpay_webhook_event_for_worker(text)'::regprocedure)))>0,
  'worker cannot claim legacy inbox rows without a persisted payload');
select ok(position('state in ('||quote_literal('queued')||','||quote_literal('retryable')||')' in
  lower(pg_get_functiondef('public.srk_service_list_due_razorpay_webhook_events(integer)'::regprocedure)))>0
  and position('lease_expires_at<=clock_timestamp()' in pg_get_functiondef('public.srk_service_list_due_razorpay_webhook_events(integer)'::regprocedure))>0,
  'sweeper discovers queued, retryable, and expired processing events');
select ok(not has_function_privilege('anon','public.srk_service_claim_razorpay_webhook_event_for_worker(text)','execute')
  and not has_function_privilege('authenticated','public.srk_service_claim_razorpay_webhook_event_for_worker(text)','execute')
  and has_function_privilege('service_role','public.srk_service_claim_razorpay_webhook_event_for_worker(text)','execute'),
  'worker claim RPC is service-role-only');
select ok(not has_function_privilege('anon','public.srk_service_list_due_razorpay_webhook_events(integer)','execute')
  and not has_function_privilege('authenticated','public.srk_service_list_due_razorpay_webhook_events(integer)','execute')
  and has_function_privilege('service_role','public.srk_service_list_due_razorpay_webhook_events(integer)','execute'),
  'sweeper discovery RPC is service-role-only');
select ok(position('p_event_payload' in pg_get_functiondef('public.srk_service_enqueue_razorpay_webhook_event(text,text,text,jsonb)'::regprocedure))>0
  and position('queued' in pg_get_functiondef('public.srk_service_enqueue_razorpay_webhook_event(text,text,text,jsonb)'::regprocedure))>0,
  'replayed legacy inbox row without payload is safely re-queued with signed projection');

select * from finish();
rollback;

select ok(position('event_payload=case' in lower(pg_get_functiondef('public.srk_service_complete_razorpay_webhook_event(text,uuid,text,text)'::regprocedure)))>0
  and position('p_outcome in ('||quote_literal('processed')||','||quote_literal('ignored')||')' in
    lower(pg_get_functiondef('public.srk_service_complete_razorpay_webhook_event(text,uuid,text,text)'::regprocedure)))>0,
  'terminal completion purges the minimal event payload while retryable events retain it');
