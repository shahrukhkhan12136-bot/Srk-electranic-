-- Exercise the webhook ledger's database constraints and conditional processing lease.
begin;

do $$
declare v_rls boolean;
begin
  select c.relrowsecurity into v_rls
  from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relname='srk_razorpay_webhook_event_ledger';
  if v_rls is distinct from true then raise exception 'Webhook event ledger must enforce RLS'; end if;
  if not has_table_privilege('service_role','public.srk_razorpay_webhook_event_ledger','select,insert,update') then
    raise exception 'service_role must have webhook ledger access';
  end if;
  if has_table_privilege('anon','public.srk_razorpay_webhook_event_ledger','select') or
     has_table_privilege('authenticated','public.srk_razorpay_webhook_event_ledger','select') then
    raise exception 'client roles must not read webhook event ledger';
  end if;
end $$;

insert into public.srk_razorpay_webhook_event_ledger
(provider,provider_event_id,payload_sha256,event_type,provider_payment_id,processing_status)
values ('razorpay','evt_ledger_contract_001',repeat('a',64),'payment.captured','pay_LEDGER001','received');

do $$
declare v_count integer; v_old_lease timestamptz; v_new_lease timestamptz;
begin
  -- First conditional claim wins.
  update public.srk_razorpay_webhook_event_ledger
  set processing_status='processing',processing_started_at=clock_timestamp()
  where provider='razorpay' and provider_event_id='evt_ledger_contract_001'
    and processing_status='received';
  get diagnostics v_count = row_count;
  if v_count<>1 then raise exception 'Initial webhook lease was not acquired'; end if;

  -- An active lease cannot be reclaimed by a concurrent delivery.
  update public.srk_razorpay_webhook_event_ledger
  set processing_started_at=clock_timestamp()
  where provider='razorpay' and provider_event_id='evt_ledger_contract_001'
    and processing_status='processing'
    and processing_started_at < clock_timestamp()-interval '5 minutes';
  get diagnostics v_count = row_count;
  if v_count<>0 then raise exception 'Active webhook lease was incorrectly reclaimed'; end if;

  -- Simulate a crashed worker; only the expired lease may be reclaimed.
  update public.srk_razorpay_webhook_event_ledger
  set processing_started_at=clock_timestamp()-interval '6 minutes'
  where provider='razorpay' and provider_event_id='evt_ledger_contract_001';
  select processing_started_at into v_old_lease from public.srk_razorpay_webhook_event_ledger
  where provider='razorpay' and provider_event_id='evt_ledger_contract_001';

  update public.srk_razorpay_webhook_event_ledger
  set processing_started_at=clock_timestamp()
  where provider='razorpay' and provider_event_id='evt_ledger_contract_001'
    and processing_status='processing'
    and processing_started_at < clock_timestamp()-interval '5 minutes';
  get diagnostics v_count = row_count;
  if v_count<>1 then raise exception 'Expired webhook lease was not recoverable'; end if;

  select processing_started_at into v_new_lease from public.srk_razorpay_webhook_event_ledger
  where provider='razorpay' and provider_event_id='evt_ledger_contract_001';

  -- A stale worker cannot complete after another worker has reclaimed its lease.
  update public.srk_razorpay_webhook_event_ledger
  set processing_status='processed',processing_started_at=null
  where provider='razorpay' and provider_event_id='evt_ledger_contract_001'
    and processing_status='processing' and processing_started_at=v_old_lease;
  get diagnostics v_count = row_count;
  if v_count<>0 then raise exception 'Stale worker incorrectly completed a reclaimed lease'; end if;

  update public.srk_razorpay_webhook_event_ledger
  set processing_status='processed',processing_started_at=null,processed_at=clock_timestamp()
  where provider='razorpay' and provider_event_id='evt_ledger_contract_001'
    and processing_status='processing' and processing_started_at=v_new_lease;
  get diagnostics v_count = row_count;
  if v_count<>1 then raise exception 'Current lease owner could not complete webhook'; end if;
end $$;

do $$
begin
  begin
    insert into public.srk_razorpay_webhook_event_ledger
    (provider,provider_event_id,payload_sha256,event_type)
    values ('razorpay','evt_ledger_contract_001',repeat('b',64),'payment.captured');
    raise exception 'Duplicate provider event ID was accepted';
  exception when unique_violation then
    null;
  end;
end $$;

rollback;
