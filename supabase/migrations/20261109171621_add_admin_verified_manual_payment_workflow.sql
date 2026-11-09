-- Admin-only, auditable manual payment recording (Cash / UPI / Bank Transfer).
-- Manual payments are separate from Razorpay verification and cannot overwrite Razorpay-linked bookings.

create table if not exists public.srk_manual_payment_entries (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references public.service_bookings(id) on delete restrict,
  payment_method text not null check (payment_method in ('cash','upi','bank_transfer')),
  amount numeric(12,2) not null check (amount > 0 and amount <= 10000000),
  payment_reference text not null check (length(trim(payment_reference)) between 4 and 120),
  note text check (note is null or length(note) <= 250),
  recorded_by uuid not null references auth.users(id) on delete restrict,
  recorded_at timestamptz not null default now()
);

alter table public.srk_manual_payment_entries enable row level security;
revoke all on table public.srk_manual_payment_entries from public, anon, authenticated;

create or replace function public.srk_admin_record_manual_payment(
  p_booking_id uuid,
  p_method text,
  p_reference text,
  p_note text default null
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth, pg_temp
as $function$
declare
  v_booking public.service_bookings%rowtype;
  v_total numeric(12,2);
  v_method text;
  v_reference text;
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'Admin access required' using errcode = '42501';
  end if;
  if p_booking_id is null then raise exception 'Booking ID is required'; end if;
  v_method := lower(trim(coalesce(p_method,'')));
  if v_method not in ('cash','upi','bank_transfer') then
    raise exception 'Payment method must be cash, upi, or bank_transfer';
  end if;
  v_reference := trim(coalesce(p_reference,''));
  if length(v_reference) < 4 or length(v_reference) > 120 then
    raise exception 'A valid receipt number or payment reference is required';
  end if;
  if p_note is not null and length(p_note) > 250 then
    raise exception 'Payment note is too long';
  end if;

  select * into v_booking from public.service_bookings
  where id = p_booking_id for update;
  if not found then raise exception 'Booking not found'; end if;
  if v_booking.status <> 'completed' or v_booking.quote_status <> 'approved' then
    raise exception 'Only completed bookings with an approved quote can be marked paid';
  end if;
  if v_booking.assigned_electrician_id is null then
    raise exception 'Booking has no assigned electrician';
  end if;
  if v_booking.payment_status in ('paid','refunded') then
    raise exception 'Booking already has a paid or refunded payment';
  end if;
  if v_booking.razorpay_order_id is not null or v_booking.razorpay_payment_id is not null then
    raise exception 'Razorpay-linked bookings must be paid only through verified Razorpay flow';
  end if;
  if exists (select 1 from public.srk_manual_payment_entries e where e.booking_id = p_booking_id) then
    raise exception 'A manual payment entry already exists for this booking';
  end if;
  if v_booking.service_charge is null or v_booking.service_charge < 0 or v_booking.materials_amount < 0 then
    raise exception 'Approved quote breakdown is invalid';
  end if;
  v_total := round(v_booking.service_charge + v_booking.materials_amount,2);
  if v_total < 1 or v_total > 10000000 or round(coalesce(v_booking.quoted_amount,-1),2) <> v_total then
    raise exception 'Approved quote total does not match the service and materials breakdown';
  end if;

  insert into public.srk_manual_payment_entries
    (booking_id,payment_method,amount,payment_reference,note,recorded_by)
  values
    (p_booking_id,v_method,v_total,v_reference,nullif(trim(coalesce(p_note,'')),''),auth.uid());

  update public.service_bookings
  set payment_method = case v_method when 'cash' then 'Cash' when 'upi' then 'UPI' else 'Bank Transfer' end,
      payment_status = 'paid',
      amount_paid = v_total,
      payment_verified_at = now()
  where id = p_booking_id;

  return jsonb_build_object('success',true,'booking_id',p_booking_id,
    'payment_method',v_method,'amount',v_total,'reference',v_reference);
end;
$function$;

revoke all on function public.srk_admin_record_manual_payment(uuid,text,text,text) from public, anon;
grant execute on function public.srk_admin_record_manual_payment(uuid,text,text,text) to authenticated;

create or replace function public.srk_create_electrician_payable()
returns trigger
language plpgsql
security definer
set search_path to 'pg_catalog','public','pg_temp'
as $function$
declare
  v_service numeric(12,2);
  v_materials numeric(12,2);
  v_total numeric(12,2);
  v_rate numeric(7,2);
  v_commission numeric(12,2);
begin
  if new.payment_status = 'paid'
     and new.status = 'completed'
     and new.quote_status = 'approved'
     and new.assigned_electrician_id is not null
     and new.payment_verified_at is not null
     and (new.razorpay_payment_id is not null
       or exists (select 1 from public.srk_manual_payment_entries e
                  where e.booking_id = new.id
                    and e.amount = round(coalesce(new.amount_paid,0),2))) then
    v_service := round(coalesce(new.service_charge,0),2);
    v_materials := round(coalesce(new.materials_amount,0),2);
    v_total := round(v_service + v_materials,2);
    v_rate := new.commission_rate;
    if v_rate is null or v_rate < 0 or v_rate > 100 then
      raise exception 'Commission rate must be between 0 and 100; payout ledger not created';
    end if;
    if round(coalesce(new.amount_paid,0),2) <> v_total then
      raise exception 'Verified payment amount does not match approved quote total; payout ledger not created';
    end if;
    v_commission := round(v_service * v_rate / 100,2);
    insert into public.srk_electrician_payouts (
      booking_id,electrician_profile_id,razorpay_payment_id,
      gross_service_amount,materials_amount,platform_commission,
      electrician_payable,payout_status
    ) values (
      new.id,new.assigned_electrician_id,new.razorpay_payment_id,
      v_service,v_materials,v_commission,
      round(v_service + v_materials - v_commission,2),'pending'
    )
    on conflict (booking_id) do update set
      electrician_profile_id = excluded.electrician_profile_id,
      razorpay_payment_id = excluded.razorpay_payment_id,
      gross_service_amount = excluded.gross_service_amount,
      materials_amount = excluded.materials_amount,
      platform_commission = excluded.platform_commission,
      electrician_payable = excluded.electrician_payable,
      updated_at = now()
    where public.srk_electrician_payouts.payout_status = 'pending';
  elsif new.payment_status = 'refunded' then
    update public.srk_electrician_payouts
    set payout_status = 'refunded',updated_at = now()
    where booking_id = new.id and payout_status = 'pending';
  end if;
  return new;
end;
$function$;
