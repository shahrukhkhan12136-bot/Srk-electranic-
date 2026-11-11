-- Rollback-only structural/security assertions for snapshot cash payment.
begin;

do $assert$
declare
  v_function record;
begin
  if to_regclass('public.srk_cash_payment_intents') is null then
    raise exception 'cash payment intent table missing';
  end if;
  if not exists (
    select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relname='srk_cash_payment_intents' and c.relrowsecurity
  ) then raise exception 'cash payment intent RLS is not enabled'; end if;

  if has_table_privilege('anon','public.srk_cash_payment_intents','SELECT')
     or has_table_privilege('authenticated','public.srk_cash_payment_intents','SELECT')
     or has_table_privilege('anon','public.srk_cash_payment_intents','INSERT')
     or has_table_privilege('authenticated','public.srk_cash_payment_intents','INSERT') then
    raise exception 'cash payment intent table is directly exposed to browser roles';
  end if;

  if not has_function_privilege('authenticated','public.srk_customer_select_cash_payment(uuid)','EXECUTE')
     or has_function_privilege('anon','public.srk_customer_select_cash_payment(uuid)','EXECUTE') then
    raise exception 'customer cash selection RPC grants are incorrect';
  end if;
  if not has_function_privilege('authenticated','public.srk_electrician_confirm_snapshot_cash_payment(uuid,text)','EXECUTE')
     or has_function_privilege('anon','public.srk_electrician_confirm_snapshot_cash_payment(uuid,text)','EXECUTE') then
    raise exception 'electrician cash confirmation RPC grants are incorrect';
  end if;

  select p.prosecdef into v_function
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='srk_customer_select_cash_payment';
  if not coalesce(v_function.prosecdef,false) then raise exception 'customer cash RPC must be SECURITY DEFINER'; end if;

  select p.prosecdef into v_function
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='srk_electrician_confirm_snapshot_cash_payment';
  if not coalesce(v_function.prosecdef,false) then raise exception 'electrician cash RPC must be SECURITY DEFINER'; end if;

  if not exists (
    select 1 from pg_trigger t
    join pg_class c on c.oid=t.tgrelid
    join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relname='srk_razorpay_orders'
      and t.tgname='srk_razorpay_order_cash_exclusivity_trigger' and not t.tgisinternal
  ) then raise exception 'cash/Razorpay exclusivity trigger missing'; end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid='public.srk_cash_payment_intents'::regclass
      and conname='srk_cash_intent_state_shape_check'
  ) then raise exception 'cash intent state shape constraint missing'; end if;

  if not exists (
    select 1 from pg_indexes
    where schemaname='public' and indexname='srk_cash_payment_intents_booking_unique'
  ) then raise exception 'one-cash-intent-per-booking unique index missing'; end if;

  if position('cash_payment_intent' in pg_get_functiondef('public.srk_get_booking_timer_bill_details(uuid)'::regprocedure))=0 then
    raise exception 'scoped booking detail RPC does not expose cash intent status';
  end if;
end
$assert$;

rollback;
