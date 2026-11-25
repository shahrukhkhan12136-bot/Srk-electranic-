
create or replace function public.srk_admin_record_manual_refund(
  p_booking_id uuid,
  p_reference text,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth','pg_temp'
as $function$
declare
  v_booking public.service_bookings%rowtype;
  v_payment public.srk_manual_payment_entries%rowtype;
  v_refund_request public.srk_booking_refund_requests%rowtype;
  v_reference text;
  v_paid_payout boolean;
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'Admin access required' using errcode='42501';
  end if;
  if p_booking_id is null then raise exception 'Booking ID is required'; end if;
  v_reference := trim(coalesce(p_reference,''));
  if length(v_reference) < 4 or length(v_reference) > 120 then
    raise exception 'A valid refund UTR / provider reference is required';
  end if;
  if p_note is not null and length(p_note) > 250 then
    raise exception 'Refund note is too long';
  end if;

  select * into v_refund_request
  from public.srk_booking_refund_requests
  where booking_id=p_booking_id and status='approved'
  for update;
  if not found then
    raise exception 'APPROVED_REFUND_REQUEST_REQUIRED';
  end if;

  select * into v_booking from public.service_bookings
  where id=p_booking_id for update;
  if not found then raise exception 'Booking not found'; end if;
  if v_booking.payment_status <> 'paid' or v_booking.payment_verified_at is null then
    raise exception 'Only verified paid bookings can be refunded';
  end if;
  if v_booking.razorpay_order_id is not null or v_booking.razorpay_payment_id is not null then
    raise exception 'Razorpay-linked refunds must be completed and reconciled through Razorpay';
  end if;

  select * into v_payment from public.srk_manual_payment_entries
  where booking_id = p_booking_id for update;
  if not found then raise exception 'Manual payment audit record not found'; end if;
  if round(coalesce(v_booking.amount_paid,0),2) <> v_payment.amount then
    raise exception 'Recorded payment amount does not match booking amount';
  end if;
  if exists (select 1 from public.srk_manual_refund_entries r where r.booking_id = p_booking_id) then
    raise exception 'A refund has already been recorded for this booking';
  end if;

  select exists(
    select 1 from public.srk_electrician_payouts p
    where p.booking_id=p_booking_id and p.payout_status='paid'
  ) or exists(
    select 1
    from public.srk_worker_earnings e
    join public.srk_worker_payout_requests p on p.worker_id=e.worker_id
    where e.booking_id=p_booking_id and p.status='paid'
      and exists(
        select 1 from public.srk_worker_wallet_ledger l
        where l.worker_id=p.worker_id
          and l.entry_type='payout_paid'
          and l.idempotency_key='payout-paid:'||p.id::text
      )
  ) into v_paid_payout;

  if v_paid_payout then
    raise exception 'Worker payout is already paid; refund requires separate recovery and reconciliation';
  end if;

  insert into public.srk_manual_refund_entries
    (booking_id,payment_entry_id,amount,refund_reference,note,recorded_by)
  values
    (p_booking_id,v_payment.id,v_payment.amount,v_reference,
     nullif(trim(coalesce(p_note,'')),''),auth.uid());

  update public.service_bookings
  set payment_status = 'refunded'
  where id = p_booking_id;

  return jsonb_build_object('success',true,'booking_id',p_booking_id,
    'amount',v_payment.amount,'refund_reference',v_reference,
    'refund_request_id',v_refund_request.id);
end
$function$;
