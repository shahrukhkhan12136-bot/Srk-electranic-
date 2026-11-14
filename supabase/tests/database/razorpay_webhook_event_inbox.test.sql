begin;
select plan(15);

select ok(to_regclass('public.srk_razorpay_webhook_events') is not null,
  'durable Razorpay webhook event inbox table exists');
select ok((select relrowsecurity from pg_class where oid='public.srk_razorpay_webhook_events'::regclass),
  'webhook event inbox has RLS enabled');
select ok(not has_table_privilege('anon','public.srk_razorpay_webhook_events','select')
  and not has_table_privilege('authenticated','public.srk_razorpay_webhook_events','select'),
  'browser roles cannot directly read webhook inbox');
select ok(not has_table_privilege('anon','public.srk_razorpay_webhook_events','insert')
  and not has_table_privilege('authenticated','public.srk_razorpay_webhook_events','insert'),
  'browser roles cannot directly write webhook inbox');
select ok(exists(
  select 1 from pg_constraint c
  join pg_attribute a on a.attrelid=c.conrelid and a.attnum=any(c.conkey)
  where c.conrelid='public.srk_razorpay_webhook_events'::regclass
    and c.contype='p' and a.attname='event_id'
) and exists(
  select 1 from pg_constraint
  where conrelid='public.srk_razorpay_webhook_events'::regclass
    and conname='srk_razorpay_webhook_payload_hash_unique' and contype='u'
), 'provider event ID and signed payload hash are unique');

select ok(position('payload_sha256 ~ '||quote_literal('^[a-f0-9]{64}$') in
  pg_get_constraintdef((select oid from pg_constraint where conrelid='public.srk_razorpay_webhook_events'::regclass and conname='srk_razorpay_webhook_payload_hash')))>0,
  'payload hash format is constrained');
select ok(position('auth.jwt()' in
  pg_get_functiondef('public.srk_service_claim_razorpay_webhook_event(text,text,text)'::regprocedure))>0
  and position('service_role' in
  pg_get_functiondef('public.srk_service_claim_razorpay_webhook_event(text,text,text)'::regprocedure))>0,
  'claim RPC requires service-role JWT');
select ok(position('for update' in lower(
  pg_get_functiondef('public.srk_service_claim_razorpay_webhook_event(text,text,text)'::regprocedure)))>0,
  'claim RPC locks an existing event row before deciding duplicate or retry');
select ok(position('lease_expires_at>clock_timestamp()' in
  pg_get_functiondef('public.srk_service_claim_razorpay_webhook_event(text,text,text)'::regprocedure))>0,
  'active processing lease prevents concurrent duplicate processing');
select ok(position('v_event.state in ('||quote_literal('processed')||','||quote_literal('ignored')||')' in
  pg_get_functiondef('public.srk_service_claim_razorpay_webhook_event(text,text,text)'::regprocedure))>0,
  'terminal webhook events are acknowledged as duplicates');
select ok(position('v_event.event_type<>p_event_type' in
  pg_get_functiondef('public.srk_service_claim_razorpay_webhook_event(text,text,text)'::regprocedure))>0
  and position('v_event.payload_sha256<>p_payload_sha256' in
  pg_get_functiondef('public.srk_service_claim_razorpay_webhook_event(text,text,text)'::regprocedure))>0,
  'reused event ID with changed signed payload is detected');
select ok(position('gen_random_uuid()' in
  pg_get_functiondef('public.srk_service_claim_razorpay_webhook_event(text,text,text)'::regprocedure))>0,
  'each claim receives a fresh fencing token');
select ok(position('v_event.claim_token is distinct from p_claim_token' in
  pg_get_functiondef('public.srk_service_complete_razorpay_webhook_event(text,uuid,text,text)'::regprocedure))>0,
  'completion requires the current claim token');
select ok(position('p_outcome not in ('||quote_literal('processed')||','||quote_literal('ignored')||','||quote_literal('retryable')||')' in
  pg_get_functiondef('public.srk_service_complete_razorpay_webhook_event(text,uuid,text,text)'::regprocedure))>0,
  'completion outcome is allow-listed');
select ok(not has_function_privilege('anon','public.srk_service_claim_razorpay_webhook_event(text,text,text)','execute')
  and not has_function_privilege('authenticated','public.srk_service_claim_razorpay_webhook_event(text,text,text)','execute')
  and has_function_privilege('service_role','public.srk_service_claim_razorpay_webhook_event(text,text,text)','execute')
  and not has_function_privilege('authenticated','public.srk_service_complete_razorpay_webhook_event(text,uuid,text,text)','execute')
  and has_function_privilege('service_role','public.srk_service_complete_razorpay_webhook_event(text,uuid,text,text)','execute'),
  'claim and completion RPCs are service-role-only');

select * from finish();
rollback;
