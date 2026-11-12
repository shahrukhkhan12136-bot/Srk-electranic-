-- Contract checks after Timer + date-only/duration + refund release migrations.
do $assert$
declare
 v_result text;
 v_def text;
begin
 if to_regclass('public.srk_timer_cash_refund_entries') is null then
   raise exception 'TIMER_CASH_REFUND_LEDGER_MISSING';
 end if;
 if to_regclass('public.srk_cash_receipts') is null
    or to_regclass('public.srk_booking_payable_snapshots') is null
    or to_regclass('public.srk_razorpay_payments') is null then
   raise exception 'TIMER_PAYMENT_FOUNDATION_MISSING';
 end if;
 if to_regprocedure('public.srk_admin_finalize_timer_cash_refund(uuid,text,text)') is null then
   raise exception 'TIMER_CASH_REFUND_RPC_MISSING';
 end if;
 if to_regprocedure('public.srk_admin_prepare_booking_refund(uuid)') is null then
   raise exception 'ADMIN_REFUND_PREPARE_RPC_MISSING';
 end if;
 select pg_get_function_result('public.srk_admin_list_booking_refund_requests(integer)'::regprocedure)
 into v_result;
 if v_result not like '%is_timer_booking boolean%' then
   raise exception 'ADMIN_REFUND_LIST_TIMER_FLAG_MISSING: %',v_result;
 end if;
 select pg_get_functiondef('public.srk_admin_list_booking_refund_requests(integer)'::regprocedure)
 into v_def;
 if position('srk_cash_receipts' in v_def)=0 then
   raise exception 'ADMIN_REFUND_LIST_DOES_NOT_DETECT_TIMER_CASH_RECEIPTS';
 end if;
 if not exists (
   select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
   where n.nspname='public' and c.relname='srk_timer_cash_refund_entries' and c.relrowsecurity
 ) then raise exception 'TIMER_CASH_REFUND_RLS_NOT_ENABLED'; end if;
 if has_table_privilege('authenticated','public.srk_timer_cash_refund_entries','SELECT')
    or has_table_privilege('anon','public.srk_timer_cash_refund_entries','SELECT') then
   raise exception 'TIMER_CASH_REFUND_LEDGER_EXPOSED_TO_CLIENT_ROLE';
 end if;

 if not exists (
   select 1 from information_schema.columns
   where table_schema='public' and table_name='service_bookings' and column_name='duration_hours'
 ) then raise exception 'BOOKING_DURATION_COLUMN_MISSING'; end if;
 if not exists (
   select 1 from pg_constraint
   where conrelid='public.service_bookings'::regclass
     and conname='service_bookings_duration_hours_check'
 ) then raise exception 'BOOKING_DURATION_CONSTRAINT_MISSING'; end if;
 select pg_get_functiondef('public.srk_create_customer_booking(jsonb,uuid)'::regprocedure)
 into v_def;
 if position('preferred_time' in v_def)=0
    or position('duration_hours' in v_def)=0
    or position('v_duration := 8' in v_def)=0 then
   raise exception 'FINAL_BOOKING_RPC_DATE_ONLY_OR_DURATION_COMPATIBILITY_MISSING';
 end if;
 -- The Timer payment webhook receipt ledger and Razorpay refund event lease ledger
 -- are separate contracts and must never share the same relation name.
 if not exists (
   select 1 from information_schema.columns
   where table_schema='public' and table_name='srk_payment_webhook_events'
     and column_name='received_at'
 ) then raise exception 'TIMER_PAYMENT_WEBHOOK_RECEIPT_LEDGER_MISSING'; end if;
 if not exists (
   select 1 from information_schema.columns
   where table_schema='public' and table_name='srk_razorpay_webhook_event_ledger'
     and column_name='processing_started_at'
 ) then raise exception 'RAZORPAY_REFUND_WEBHOOK_LEASE_LEDGER_MISSING'; end if;
 if exists (
   select 1 from information_schema.columns
   where table_schema='public' and table_name='srk_payment_webhook_events'
     and column_name='processing_started_at'
 ) then raise exception 'TIMER_PAYMENT_WEBHOOK_LEDGER_WAS_OVERWRITTEN'; end if;

end
$assert$;
