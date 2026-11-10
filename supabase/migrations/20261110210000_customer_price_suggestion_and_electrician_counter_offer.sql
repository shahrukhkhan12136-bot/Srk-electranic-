-- SRK ELECTRONIC: customer price suggestion and electrician counter-offer metadata.
-- Draft migration for the feature/flutter-mobile-apps branch only.
-- Do not apply to the production Supabase project without a separate approval.

alter table public.service_bookings
  add column if not exists customer_suggested_amount numeric(12,2),
  add column if not exists customer_suggested_at timestamptz,
  add column if not exists electrician_quote_kind text not null default 'electrician_quote';

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.service_bookings'::regclass
      and conname = 'service_bookings_customer_suggested_amount_check'
  ) then
    alter table public.service_bookings
      add constraint service_bookings_customer_suggested_amount_check
      check (
        customer_suggested_amount is null
        or (customer_suggested_amount > 0 and customer_suggested_amount <= 10000000)
      );
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.service_bookings'::regclass
      and conname = 'service_bookings_electrician_quote_kind_check'
  ) then
    alter table public.service_bookings
      add constraint service_bookings_electrician_quote_kind_check
      check (electrician_quote_kind in ('electrician_quote', 'matches_suggestion', 'counter_offer'));
  end if;
end
$$;

comment on column public.service_bookings.customer_suggested_amount is
  'Optional initial total price suggested by the customer; never used as the final payable amount.';
comment on column public.service_bookings.customer_suggested_at is
  'Server timestamp when the customer suggestion was recorded.';
comment on column public.service_bookings.electrician_quote_kind is
  'Classifies the electrician quote against the customer suggestion; service_charge and materials_amount remain the authoritative split.';

-- Customers may set their initial suggestion only on their own unassigned booking,
-- and only once. The server-side create-booking endpoint may also populate the
-- same columns after it has verified the customer's OTP session.
create or replace function public.srk_customer_set_booking_suggested_amount(
  p_booking_id uuid,
  p_amount numeric
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth, pg_temp
as $function$
declare
  v_booking public.service_bookings%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if p_booking_id is null or p_amount is null
     or p_amount <= 0 or p_amount > 10000000 then
    raise exception 'Invalid suggested amount';
  end if;

  select * into v_booking
    from public.service_bookings
   where id = p_booking_id
     and customer_user_id = auth.uid()
   for update;

  if not found then
    raise exception 'Customer booking not found';
  end if;
  if v_booking.status not in ('new', 'confirmed')
     or v_booking.assigned_electrician_id is not null then
    raise exception 'Price suggestion can no longer be changed';
  end if;
  if v_booking.customer_suggested_amount is not null then
    raise exception 'Customer price suggestion already recorded';
  end if;

  update public.service_bookings
     set customer_suggested_amount = round(p_amount, 2),
         customer_suggested_at = pg_catalog.now()
   where id = p_booking_id;

  return pg_catalog.jsonb_build_object(
    'success', true,
    'customer_suggested_amount', round(p_amount, 2)
  );
end;
$function$;

revoke all on function public.srk_customer_set_booking_suggested_amount(uuid, numeric) from public, anon;
grant execute on function public.srk_customer_set_booking_suggested_amount(uuid, numeric) to authenticated;

-- Safe electrician-side view of the suggested price and quote metadata.
-- Deliberately excludes customer name, phone, address, and location.
create or replace function public.srk_get_my_offer_price_details()
returns table (
  offer_id uuid,
  booking_id uuid,
  offer_status text,
  customer_suggested_amount numeric,
  electrician_quote_kind text,
  service_charge numeric,
  materials_amount numeric,
  quote_status text,
  quote_note text
)
language sql
stable
security definer
set search_path = pg_catalog, public, auth, pg_temp
as $function$
  select
    o.id,
    b.id,
    o.status,
    b.customer_suggested_amount,
    b.electrician_quote_kind,
    case when b.assigned_electrician_id = p.id then b.service_charge else null end,
    case when b.assigned_electrician_id = p.id then b.materials_amount else null end,
    case when b.assigned_electrician_id = p.id then b.quote_status else null end,
    case when b.assigned_electrician_id = p.id then b.quote_note else null end
  from public.job_offers o
  join public.electrician_profiles p on p.id = o.electrician_id
  join public.service_bookings b on b.id = o.booking_id
  where auth.uid() is not null
    and (p.user_id = auth.uid() or p.auth_user_id = auth.uid())
    and p.verification_status = 'approved'
    and p.active = true
  order by o.created_at desc
  limit 100;
$function$;

revoke all on function public.srk_get_my_offer_price_details() from public, anon;
grant execute on function public.srk_get_my_offer_price_details() to authenticated;

-- Preserve the existing quote workflow and labour/material split. A quote
-- differing from the customer's initial suggestion is explicitly recorded
-- as a counter-offer. The customer's existing approve/reject RPC remains the
-- final authorization before work begins.
create or replace function public.srk_submit_booking_quote(
  p_booking_id uuid,
  p_service_charge numeric,
  p_materials_amount numeric,
  p_quote_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth, pg_temp
as $function$
declare
  v_profile_id uuid;
  v_booking public.service_bookings%rowtype;
  v_total numeric(12,2);
  v_quote_kind text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if p_booking_id is null or p_service_charge is null or p_service_charge <= 0
     or p_materials_amount is null or p_materials_amount < 0
     or p_service_charge > 10000000 or p_materials_amount > 10000000 then
    raise exception 'Invalid quote amounts';
  end if;

  v_total := round(p_service_charge + p_materials_amount, 2);

  select id into v_profile_id
    from public.electrician_profiles
   where (user_id = auth.uid() or auth_user_id = auth.uid())
     and verification_status = 'approved'
     and active = true
   limit 1;

  if v_profile_id is null then
    raise exception 'Approved active electrician required';
  end if;

  select * into v_booking
    from public.service_bookings
   where id = p_booking_id
     and assigned_electrician_id = v_profile_id
   for update;

  if not found then
    raise exception 'Assigned booking not found';
  end if;
  if v_booking.status not in ('assigned', 'inspection', 'quote_rejected') then
    raise exception 'Booking is not ready for a quote';
  end if;

  v_quote_kind := case
    when v_booking.customer_suggested_amount is null then 'electrician_quote'
    when v_total = round(v_booking.customer_suggested_amount, 2) then 'matches_suggestion'
    else 'counter_offer'
  end;

  update public.service_bookings
     set service_charge = round(p_service_charge, 2),
         materials_amount = round(p_materials_amount, 2),
         quoted_amount = v_total,
         quote_note = left(coalesce(p_quote_note, ''), 1000),
         electrician_quote_kind = v_quote_kind,
         quote_status = 'pending',
         quote_submitted_at = pg_catalog.now(),
         quote_responded_at = null,
         status = 'awaiting_quote_approval'
   where id = p_booking_id;

  return pg_catalog.jsonb_build_object(
    'success', true,
    'total', v_total,
    'quote_status', 'pending',
    'quote_kind', v_quote_kind
  );
end;
$function$;

revoke all on function public.srk_submit_booking_quote(uuid, numeric, numeric, text) from public, anon;
grant execute on function public.srk_submit_booking_quote(uuid, numeric, numeric, text) to authenticated;
