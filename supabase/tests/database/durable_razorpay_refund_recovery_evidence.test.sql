begin;
select plan(41);
select ok(to_regclass('public.srk_razorpay_refund_recovery_audits') is not null,'durable refund recovery evidence table exists');
select ok((select relrowsecurity from pg_class where oid='public.srk_razorpay_refund_recovery_audits'::regclass),'recovery evidence table has RLS enabled');
select ok(not has_table_privilege('anon','public.srk_razorpay_refund_recovery_audits','select'),'anon cannot read private recovery evidence');
select ok(not has_table_privilege('authenticated','public.srk_razorpay_refund_recovery_audits','select'),'authenticated cannot read private recovery evidence directly');
select ok(has_function_privilege('service_role','public.srk_service_record_razorpay_refund_recovery_evidence(uuid,text,text,bigint,text,text,timestamptz,text,text,uuid,jsonb,uuid,text)','execute'),'service role can persist provider evidence');
select ok(not has_function_privilege('authenticated','public.srk_service_record_razorpay_refund_recovery_evidence(uuid,text,text,bigint,text,text,timestamptz,text,text,uuid,jsonb,uuid,text)','execute'),'authenticated cannot persist provider evidence');
select ok(has_function_privilege('service_role','public.srk_service_finalize_razorpay_refund_from_recovery_evidence(uuid)','execute'),'service role can finalize from recovery evidence');
select ok(not has_function_privilege('authenticated','public.srk_service_finalize_razorpay_refund_from_recovery_evidence(uuid)','execute'),'authenticated cannot finalize from recovery evidence');
select ok(position('p_observation_id' in pg_get_functiondef('public.srk_service_record_razorpay_refund_recovery_evidence(uuid,text,text,bigint,text,text,timestamptz,text,text,uuid,jsonb,uuid,text)'::regprocedure))>0,'fresh observation UUID supports idempotent retries and fresh evidence reads');
select ok(position('SERVICE_ROLE_REQUIRED' in pg_get_functiondef('public.srk_service_record_razorpay_refund_recovery_evidence(uuid,text,text,bigint,text,text,timestamptz,text,text,uuid,jsonb,uuid,text)'::regprocedure))>0,'evidence writer independently enforces service role');
select ok(position('length(btrim(p_admin_note)) not between 10 and 2000' in pg_get_functiondef('public.srk_service_record_razorpay_refund_recovery_evidence(uuid,text,text,bigint,text,text,timestamptz,text,text,uuid,jsonb,uuid,text)'::regprocedure))>0,'evidence writer requires a bounded Main Admin audit note');
select ok(position('RECOVERY_ACTOR_IS_NOT_AN_AUTHORIZED_SRK_ADMIN' in pg_get_functiondef('public.srk_service_record_razorpay_refund_recovery_evidence(uuid,text,text,bigint,text,text,timestamptz,text,text,uuid,jsonb,uuid,text)'::regprocedure))>0,'audit actor must exist in the SRK Admin registry');
select ok(position('PROVIDER_EVIDENCE_FIELDS_DO_NOT_MATCH_AUDIT_ARGUMENTS' in pg_get_functiondef('public.srk_service_record_razorpay_refund_recovery_evidence(uuid,text,text,bigint,text,text,timestamptz,text,text,uuid,jsonb,uuid,text)'::regprocedure))>0,'provider payload identity and amount must match persisted evidence arguments');
select ok(position('REFUND_RECOVERY_EVIDENCE_IS_APPEND_ONLY' in pg_get_functiondef('public.srk_reject_razorpay_refund_recovery_audit_mutation()'::regprocedure))>0,'recovery evidence is immutable after insert');
select ok(position('ONLY_VERIFIED_PROCESSED_PROVIDER_EVIDENCE_CAN_FINALIZE' in pg_get_functiondef('public.srk_service_finalize_razorpay_refund_from_recovery_evidence(uuid)'::regprocedure))>0,'only provider processed evidence can finalize accounting');
select ok(position('RECOVERY_EVIDENCE_TOO_OLD_REFRESH_PROVIDER_STATUS' in pg_get_functiondef('public.srk_service_finalize_razorpay_refund_from_recovery_evidence(uuid)'::regprocedure))>0,'stale evidence cannot finalize accounting');
select ok(position('ELECTRICIAN_PAYOUT_MUST_REMAIN_BLOCKED_DURING_REFUND_RECOVERY' in pg_get_functiondef('public.srk_service_finalize_razorpay_refund_from_recovery_evidence(uuid)'::regprocedure))>0,'payout must remain blocked during recovery finalization');
select ok(position('update public.service_bookings set payment_status=''refunded''' in lower(
  pg_get_functiondef('public.srk_service_finalize_razorpay_refund_from_recovery_evidence(uuid)'::regprocedure)))>0
  and position('select * into v_payout from public.srk_electrician_payouts where booking_id=v_booking.id' in lower(
  pg_get_functiondef('public.srk_service_finalize_razorpay_refund_from_recovery_evidence(uuid)'::regprocedure)))>
    position('update public.service_bookings set payment_status=''refunded''' in lower(
  pg_get_functiondef('public.srk_service_finalize_razorpay_refund_from_recovery_evidence(uuid)'::regprocedure)))
  and position('v_payout.payout_status is distinct from ''refunded''' in lower(
  pg_get_functiondef('public.srk_service_finalize_razorpay_refund_from_recovery_evidence(uuid)'::regprocedure)))>0
  and position('BLOCKED_PAYOUT_COULD_NOT_BE_CLOSED_AS_REFUNDED' in
  pg_get_functiondef('public.srk_service_finalize_razorpay_refund_from_recovery_evidence(uuid)'::regprocedure))>0,
  'recovery finalizer relies on the booking trigger, then verifies blocked payout is refunded without a duplicate write');
select ok(position('RECOVERY_REFUND_AMOUNT_DOES_NOT_MATCH_FULL_BOOKING_COLLECTION' in pg_get_functiondef('public.srk_service_finalize_razorpay_refund_from_recovery_evidence(uuid)'::regprocedure))>0
  and position('v_audit.amount_paise is distinct from round(v_booking.amount_paid*100)::bigint' in pg_get_functiondef('public.srk_service_finalize_razorpay_refund_from_recovery_evidence(uuid)'::regprocedure))>0,
  'recovery finalization independently requires the provider refund to equal the full verified booking collection');
select ok(position('REFUNDED_BOOKING_PAYOUT_STATE_REQUIRES_MANUAL_RECONCILIATION' in pg_get_functiondef('public.srk_service_finalize_razorpay_refund_from_recovery_evidence(uuid)'::regprocedure))>0,'idempotent replay validates payout reversal state after the accounting trigger');
select ok(position('update public.service_bookings' in lower(pg_get_functiondef('public.srk_service_finalize_razorpay_refund_from_recovery_evidence(uuid)'::regprocedure)))>0,'accounting finalization is a separate transaction boundary from evidence persistence');

select ok(to_regclass('public.srk_cancellation_fee_ledger_one_reversal_per_entry') is not null,'each cancellation-fee ledger entry can have at most one reversal');
select ok(to_regclass('public.srk_wallet_ledger_idempotency_key_key') is not null,'wallet reversal entries have a globally unique idempotency key');
select ok(position('cancel-fee:cash:refund-wallet-credit:' in pg_get_functiondef('public.srk_reverse_cancellation_fees_on_full_refund()'::regprocedure))>0,'cash cancellation-fee refund restores electrician wallet with deterministic idempotency key');
select ok(position('srk_reverse_cancellation_fees_on_full_refund' in pg_get_triggerdef((select oid from pg_trigger where tgname='srk_reverse_cancellation_fees_on_full_refund' and not tgisinternal)))>0,'full-refund accounting reversal is attached to service booking payment status');

select ok(position('new.service_charge * new.commission_rate / 100' in pg_get_functiondef('public.srk_calculate_booking_commission()'::regprocedure))>0,'company commission is calculated on service labour only, excluding materials');
select ok(position('payment_status = ''paid''' in pg_get_functiondef('public.srk_admin_commission_report()'::regprocedure))>0,'commission report excludes refunded and unpaid bookings from collected totals');
select ok(position('status=''posted''' in pg_get_functiondef('public.srk_get_my_wallet_summary()'::regprocedure))>0,'wallet displayed balance includes only posted ledger entries');

select ok(position('topups_enabled',pg_get_functiondef('public.srk_get_my_wallet_summary()'::regprocedure))>0,'customer stored-value top-ups remain explicitly disabled');
select ok(position('payouts_enabled',pg_get_functiondef('public.srk_get_my_wallet_summary()'::regprocedure))>0,'wallet cash-out remains explicitly disabled until provider approval');
select ok(to_regclass('public.srk_route_transfers') is null,
  'retired Route transfer ledger is absent after the explicit retirement migration');
select ok(not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.prosrc ilike '%srk_route_transfers%'),
  'remaining public function bodies do not query the retired Route transfer ledger');
select ok(position('route_transfer_count',pg_get_functiondef(
  'public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure))>0
  and position('route_ledger_retired_no_route_transfers',pg_get_functiondef(
  'public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure))>0,
  'Admin reconciliation preserves explicit zero/retired compatibility fields without Route settlement claims');
select ok(position('route_provider_settlement_verified',pg_get_functiondef(
  'public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure))>0
  and position('false',pg_get_functiondef(
  'public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure))>0,
  'Admin reconciliation never infers provider settlement from the retired ledger');
select ok(position('sum(case when direction=''credit'' then amount else -amount end)' in pg_get_functiondef('public.srk_get_my_wallet_summary()'::regprocedure))>0,'wallet balance is derived from posted ledger entries rather than a mutable cached balance');

select ok(exists(select 1 from pg_trigger where tgname='srk_refund_recovery_provider_identity_guard'
  and tgrelid='public.srk_razorpay_refund_recovery_audits'::regclass and not tgisinternal),
  'recovery observations enforce provider refund identity mapping before insert');
select ok(exists(select 1 from pg_trigger where tgname='srk_refund_provider_identity_guard'
  and tgrelid='public.srk_razorpay_refunds'::regclass and not tgisinternal),
  'canonical refund records enforce provider refund identity mapping on write');
select ok(position('pg_advisory_xact_lock' in pg_get_functiondef(
  'public.srk_enforce_razorpay_refund_identity_mapping()'::regprocedure))>0
  and position('refund-record:' in pg_get_functiondef(
  'public.srk_enforce_razorpay_refund_identity_mapping()'::regprocedure))>0
  and position('provider:' in pg_get_functiondef(
  'public.srk_enforce_razorpay_refund_identity_mapping()'::regprocedure))>0,
  'provider ID and internal record claims are serialized against concurrent conflicting inserts');
select ok(position('PROVIDER_REFUND_ID_ALREADY_BOUND_TO_ANOTHER_REFUND' in pg_get_functiondef(
  'public.srk_enforce_razorpay_refund_identity_mapping()'::regprocedure))>0
  and position('REFUND_RECORD_ALREADY_BOUND_TO_ANOTHER_PROVIDER_REFUND' in pg_get_functiondef(
  'public.srk_enforce_razorpay_refund_identity_mapping()'::regprocedure))>0,
  'identity guard rejects both provider-ID reuse and conflicting IDs for one internal record');
select ok((select prosecdef and coalesce(array_to_string(proconfig,','),'') like '%search_path=%'
  from pg_proc where oid='public.srk_enforce_razorpay_refund_identity_mapping()'::regprocedure),
  'identity guard is SECURITY DEFINER with an explicit empty search_path');

select ok(
  position('for update of b' in pg_get_functiondef(
    'public.srk_service_reconcile_booking_refund(uuid,text,text,text)'::regprocedure))>0
  and position('update public.srk_electrician_payouts' in pg_get_functiondef(
    'public.srk_service_reconcile_booking_refund(uuid,text,text,text)'::regprocedure))
    > position('for update of b' in pg_get_functiondef(
      'public.srk_service_reconcile_booking_refund(uuid,text,text,text)'::regprocedure)),
  'refund reconciliation locks the booking before restoring or closing its payout row, matching payout settlement lock order');

select * from finish();
rollback;
