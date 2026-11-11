-- Verify that an existing completed-but-unpaid legacy booking survives the
-- timer/cancellation/commission migrations without being converted or settled.
-- Runs only against the disposable CI PostgreSQL database.

do $test$
declare
  v_booking public.service_bookings%rowtype;
  v_id uuid := '11000000-0000-4000-8000-000000000001';
begin
  select * into v_booking
  from public.service_bookings
  where id=v_id;

  if not found then
    raise exception 'legacy booking fixture was deleted';
  end if;

  if v_booking.status <> 'completed'
     or v_booking.payment_status <> 'unpaid'
     or v_booking.payment_method <> 'Razorpay ऑनलाइन भुगतान'
     or v_booking.service_charge <> 10
     or v_booking.materials_amount <> 10
     or v_booking.quoted_amount <> 20
     or v_booking.amount_paid is not null
     or v_booking.razorpay_order_id is not null
     or v_booking.razorpay_payment_id is not null
     or v_booking.payment_verified_at is not null
     or v_booking.commission_rate <> 15
     or v_booking.commission_amount is not null then
    raise exception 'legacy booking financial/status fields changed unexpectedly';
  end if;

  if v_booking.timer_state <> 'not_requested'
     or v_booking.timer_started_at is not null
     or v_booking.timer_stopped_at is not null
     or v_booking.timer_elapsed_seconds is not null
     or v_booking.timer_billable_minutes is not null
     or v_booking.final_bill_id is not null then
    raise exception 'legacy booking was incorrectly converted to timer billing';
  end if;

  if exists (select 1 from public.srk_final_bills where booking_id=v_id)
     or exists (select 1 from public.srk_booking_payable_snapshots where booking_id=v_id)
     or exists (select 1 from public.srk_booking_timer_decisions where booking_id=v_id)
     or exists (select 1 from public.srk_booking_cancellation_requests where booking_id=v_id)
     or exists (select 1 from public.srk_electrician_payouts where booking_id=v_id) then
    raise exception 'legacy booking unexpectedly gained timer, cancellation, snapshot, or payout records';
  end if;

  if not exists (
    select 1 from public.job_offers
    where booking_id=v_id
      and electrician_id='21000000-0000-4000-8000-000000000001'
      and status='accepted'
  ) then
    raise exception 'legacy accepted electrician offer was not preserved';
  end if;
end
$test$;
