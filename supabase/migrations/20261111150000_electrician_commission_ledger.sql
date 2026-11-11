-- SRK ELECTRONIC: 15% platform commission on labour only.
-- Commission is recorded once when a timer booking becomes paid.
-- Materials and cancellation fees are explicitly excluded. Collection/remittance
-- is tracked separately; this migration does not move money or enable Razorpay Route.
begin;

create table if not exists public.srk_electrician_commissions (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references public.service_bookings(id) on delete restrict,
  payable_snapshot_id uuid not null unique references public.srk_booking_payable_snapshots(id) on delete restrict,
  electrician_profile_id uuid not null references public.electrician_profiles(id) on delete restrict,
  labour_amount numeric(20,10) not null check (labour_amount >= 0),
  commission_rate numeric(5,2) not null default 15.00 check (commission_rate = 15.00),
  commission_amount numeric(12,2) not null check (commission_amount >= 0),
  electrician_net_labour numeric(12,2) not null check (electrician_net_labour >= 0),
  materials_amount_excluded numeric(12,2) not null default 0 check (materials_amount_excluded >= 0),
  payment_method text not null check (payment_method in ('Cash','Online','Razorpay','cash','online')),
  collection_status text not null default 'pending'
    check (collection_status in ('pending','collected','adjusted','waived')),
  collected_amount numeric(12,2) not null default 0 check (collected_amount >= 0),
  collected_at timestamptz,
  collection_reference text,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  constraint srk_commission_amount_math_check
    check (commission_amount = round(labour_amount * 0.15, 2)),
  constraint srk_commission_net_labour_math_check
    check (electrician_net_labour = round(labour_amount, 2) - commission_amount),
  constraint srk_commission_collected_shape_check
    check (
      (collection_status = 'pending' and collected_amount = 0 and collected_at is null)
      or (collection_status = 'collected' and collected_amount = commission_amount and collected_at is not null)
      or (collection_status in ('adjusted','waived') and collected_at is not null)
    )
);

create index if not exists srk_electrician_commissions_profile_status_idx
  on public.srk_electrician_commissions(electrician_profile_id, collection_status, created_at desc);

alter table public.srk_electrician_commissions enable row level security;
revoke all on public.srk_electrician_commissions from public, anon, authenticated;
grant all on public.srk_electrician_commissions to service_role;

create or replace function public.srk_record_paid_booking_commission()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_snapshot public.srk_booking_payable_snapshots%rowtype;
  v_commission numeric(12,2);
  v_labour_rounded numeric(12,2);
  v_method text;
begin
  -- Legacy bookings outside the timer/payable-snapshot flow are not commissioned here.
  if new.service_category_code is null then
    return new;
  end if;

  if new.payment_status is distinct from 'paid'
     or old.payment_status is not distinct from 'paid' then
    return new;
  end if;

  if new.assigned_electrician_id is null then
    raise exception 'COMMISSION_ELECTRICIAN_NOT_ASSIGNED' using errcode='55000';
  end if;

  select ps.* into v_snapshot
  from public.srk_booking_payable_snapshots ps
  where ps.booking_id = new.id
    and ps.bill_id = new.final_bill_id
  order by ps.created_at desc
  limit 1;

  if not found then
    raise exception 'COMMISSION_PAYABLE_SNAPSHOT_REQUIRED' using errcode='55000';
  end if;

  v_commission := round(v_snapshot.labour_amount * 0.15, 2);
  v_labour_rounded := round(v_snapshot.labour_amount, 2);
  v_method := coalesce(new.payment_method, 'Online');

  if v_method not in ('Cash','Online','Razorpay','cash','online') then
    v_method := 'Online';
  end if;

  insert into public.srk_electrician_commissions(
    booking_id, payable_snapshot_id, electrician_profile_id,
    labour_amount, commission_rate, commission_amount,
    electrician_net_labour, materials_amount_excluded, payment_method
  ) values (
    new.id, v_snapshot.id, new.assigned_electrician_id,
    v_snapshot.labour_amount, 15.00, v_commission,
    v_labour_rounded - v_commission, v_snapshot.materials_amount, v_method
  )
  on conflict (booking_id) do nothing;

  return new;
end
$function$;

drop trigger if exists srk_record_paid_booking_commission_trigger on public.service_bookings;
create trigger srk_record_paid_booking_commission_trigger
after update of payment_status on public.service_bookings
for each row
when (new.payment_status = 'paid' and old.payment_status is distinct from 'paid')
execute function public.srk_record_paid_booking_commission();

create or replace function public.srk_admin_list_electrician_commissions()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_result jsonb;
begin
  if auth.uid() is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode='28000';
  end if;
  if not coalesce(public.is_srk_admin(), false) then
    raise exception 'ADMIN_ONLY' using errcode='42501';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'commission_id', c.id,
    'booking_id', c.booking_id,
    'electrician_profile_id', c.electrician_profile_id,
    'labour_amount', c.labour_amount,
    'commission_rate', c.commission_rate,
    'commission_amount', c.commission_amount,
    'electrician_net_labour', c.electrician_net_labour,
    'materials_amount_excluded', c.materials_amount_excluded,
    'payment_method', c.payment_method,
    'collection_status', c.collection_status,
    'collected_amount', c.collected_amount,
    'collected_at', c.collected_at,
    'collection_reference', c.collection_reference,
    'created_at', c.created_at
  ) order by c.created_at desc), '[]'::jsonb)
  into v_result
  from public.srk_electrician_commissions c;
  return v_result;
end
$function$;

revoke all on function public.srk_admin_list_electrician_commissions() from public, anon;
grant execute on function public.srk_admin_list_electrician_commissions() to authenticated;

commit;
