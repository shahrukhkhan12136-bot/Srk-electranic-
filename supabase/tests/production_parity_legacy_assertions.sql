-- Assertions after all timer/cancellation/commission migrations on the
-- Production-shaped disposable baseline. Never run against a hosted project.
do $assert$
declare
  v_payout public.srk_electrician_payouts%rowtype;
  v_booking public.service_bookings%rowtype;
begin
  select * into v_payout from public.srk_electrician_payouts
  where booking_id='11000000-0000-4000-8000-000000000002';
  if not found then raise exception 'Paid legacy payout row was lost during timer migrations'; end if;

  if v_payout.electrician_profile_id<>'21000000-0000-4000-8000-000000000002'
     or v_payout.razorpay_payment_id<>'pay_legacy_fixture'
     or v_payout.gross_service_amount<>100
     or v_payout.materials_amount<>20
     or v_payout.platform_commission<>15
     or v_payout.electrician_payable<>105
     or v_payout.payout_status<>'pending'
     or v_payout.payout_method is not null
     or v_payout.payout_reference is not null
     or v_payout.paid_at is not null
     or v_payout.settlement_mode is not null
     or v_payout.commission_collection_status<>'not_applicable' then
    raise exception 'Existing paid legacy payout values changed unexpectedly: %',row_to_json(v_payout);
  end if;

  select * into v_booking from public.service_bookings
  where id='11000000-0000-4000-8000-000000000002';
  if not found or v_booking.status<>'completed' or v_booking.payment_status<>'paid'
     or v_booking.amount_paid<>120 or v_booking.commission_amount<>15
     or v_booking.service_charge<>100 or v_booking.materials_amount<>20
     or v_booking.service_category_code is not null
     or v_booking.timer_state<>'not_requested' then
    raise exception 'Paid legacy booking was converted or financially changed: %',row_to_json(v_booking);
  end if;

  if (select count(*) from public.srk_electrician_payouts
      where booking_id='11000000-0000-4000-8000-000000000002')<>1 then
    raise exception 'Legacy payout ledger duplicated during migration replay';
  end if;

  if not exists (
    select 1 from pg_trigger
    where tgrelid='public.srk_electrician_payouts'::regclass
      and tgname='srk_audit_electrician_payouts' and not tgisinternal
  ) then raise exception 'Production payout audit trigger was not retained'; end if;

  if not exists (
    select 1 from pg_trigger
    where tgrelid='public.service_bookings'::regclass
      and tgname='a_guard_booking' and not tgisinternal
  ) then raise exception 'Production booking insert guard was not retained'; end if;

  if not exists (
    select 1 from pg_trigger
    where tgrelid='public.service_bookings'::regclass
      and tgname='srk_log_service_booking_status' and not tgisinternal
  ) then raise exception 'Production booking status history trigger was not retained'; end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='electrician_applications'
      and column_name='verification_status'
  ) or exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='electrician_applications'
      and column_name='user_id'
  ) then
    raise exception 'Electrician application fixture does not match observed Production schema';
  end if;
end
$assert$;
