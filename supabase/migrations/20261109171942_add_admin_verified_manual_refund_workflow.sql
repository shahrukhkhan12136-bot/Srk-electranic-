-- Manual refund audit and admin-only recording. Razorpay refunds remain provider-reconciled.
create table if not exists public.srk_manual_refund_entries (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references public.service_bookings(id) on delete restrict,
  payment_entry_id uuid not null unique references public.srk_manual_payment_entries(id) on delete restrict,
  amount numeric(12,2) not null check (amount > 0 and amount <= 10000000),
  refund_reference text not null check (length(trim(refund_reference)) between 4 and 120),
  note text check (note is null or length(note) <= 250),
  recorded_by uuid not null references auth.users(id) on delete restrict,
  recorded_at timestamptz not null default now()
);
alter table public.srk_manual_refund_entries enable row level security;
revoke all on table public.srk_manual_refund_entries from public, anon, authenticated;

create or replace function public.srk_admin_record_manual_refund(
  p_booking_id uuid,
  p_reference text,
  p_note text default null
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth, pg_temp
as $function$
declare
  v_booking public.service_bookings%rowtype;
  v_payment public.srk_manual_payment_entries%rowtype;
  v_reference text;
  v_paid_payout boolean;
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'Admin access required' using errcode = '42501';
  end if;
  if p_booking_id is null then raise exception 'Booking ID is required'; end if;
  v_reference := trim(coalesce(p_reference,''));
  if length(v_reference) < 4 or length(v_reference) > 120 then
    raise exception 'A valid refund UTR / provider reference is required';
  end if;
  if p_note is not null and length(p_note) > 250 then
    raise exception 'Refund note is too long';
  end if;
  select * into v_booking from public.service_bookings where id = p_booking_id for update;
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
  select exists(select 1 from public.srk_electrician_payouts p
                where p.booking_id = p_booking_id and p.payout_status = 'paid')
    into v_paid_payout;
  if v_paid_payout then
    raise exception 'Electrician payout is already paid; refund requires separate recovery and reconciliation';
  end if;
  insert into public.srk_manual_refund_entries
    (booking_id,payment_entry_id,amount,refund_reference,note,recorded_by)
  values (p_booking_id,v_payment.id,v_payment.amount,v_reference,
    nullif(trim(coalesce(p_note,'')),''),auth.uid());
  update public.service_bookings set payment_status = 'refunded' where id = p_booking_id;
  return jsonb_build_object('success',true,'booking_id',p_booking_id,
    'amount',v_payment.amount,'refund_reference',v_reference);
end;
$function$;
revoke all on function public.srk_admin_record_manual_refund(uuid,text,text) from public, anon;
grant execute on function public.srk_admin_record_manual_refund(uuid,text,text) to authenticated;
