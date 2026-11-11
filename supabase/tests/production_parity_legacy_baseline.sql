-- Production-shaped legacy baseline overlay for disposable PostgreSQL CI only.
-- Captured from Main Production catalog on 2026-11-11. No production data is copied.
-- Run after timer_billing_foundation_harness.sql and before any Feature Branch migration.

-- Match the Main Production electrician_profiles column contract.
alter table public.electrician_profiles
  add column if not exists application_id uuid,
  add column if not exists display_name text,
  add column if not exists phone text,
  add column if not exists state text,
  add column if not exists district text,
  add column if not exists pincode text,
  add column if not exists skills text[] not null default '{}'::text[],
  add column if not exists location_lat double precision,
  add column if not exists location_lng double precision;

-- Match the real application table shape (not the earlier incorrect user_id/status fixture).
create table public.electrician_applications (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz,
  full_name text not null,
  phone text not null,
  state text not null,
  district text not null,
  pincode text not null,
  skills text not null,
  experience_years integer not null default 0,
  about text,
  verification_status text not null default 'pending',
  active boolean not null default false,
  location_lat double precision,
  location_lng double precision
);

-- Main Production legacy manual-payment evidence table.
create table public.srk_manual_payment_entries (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.service_bookings(id),
  payment_method text not null,
  amount numeric not null,
  payment_reference text not null,
  note text,
  recorded_by uuid not null references auth.users(id),
  recorded_at timestamptz not null default now()
);

-- Exact legacy payout columns and constraints observed in Main Production.
create table public.srk_electrician_payouts (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references public.service_bookings(id) on delete restrict,
  electrician_profile_id uuid not null references public.electrician_profiles(id) on delete restrict,
  razorpay_payment_id text,
  gross_service_amount numeric not null check (gross_service_amount >= 0),
  materials_amount numeric not null check (materials_amount >= 0),
  platform_commission numeric not null check (platform_commission >= 0),
  electrician_payable numeric not null check (electrician_payable >= 0),
  payout_status text not null default 'pending'
    check (payout_status in ('pending','paid','blocked','refunded')),
  payout_method text check (payout_method in ('upi','bank')),
  payout_reference text,
  payout_note text,
  paid_by uuid references auth.users(id),
  paid_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint srk_payout_paid_fields_check check (
    payout_status <> 'paid' or
    (payout_method is not null and payout_reference is not null
     and length(btrim(payout_reference)) >= 4 and paid_at is not null and paid_by is not null)
  )
);
create index srk_electrician_payouts_electrician_profile_id_idx
  on public.srk_electrician_payouts(electrician_profile_id);
create index srk_electrician_payouts_paid_at_idx
  on public.srk_electrician_payouts(paid_at desc)
  where payout_status='paid' and paid_at is not null;
create index srk_electrician_payouts_paid_by_idx
  on public.srk_electrician_payouts(paid_by);
create index srk_electrician_payouts_status_idx
  on public.srk_electrician_payouts(payout_status,created_at desc);

-- Minimal audit-event storage plus the existing trigger shape. This test trigger
-- records changes so payout migration behavior can be checked without copying
-- customer/audit data from Production.
create table public.srk_admin_audit_events (
  id uuid primary key default gen_random_uuid(),
  entity_type text not null,
  entity_id uuid not null,
  booking_id uuid,
  action text not null,
  actor_user_id uuid,
  actor_role text not null,
  changed_fields text[] not null default array[]::text[],
  before_data jsonb not null default '{}'::jsonb,
  after_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create or replace function public.test_capture_admin_audit_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_old jsonb := case when tg_op='INSERT' then '{}'::jsonb else to_jsonb(old) end;
  v_new jsonb := case when tg_op='DELETE' then '{}'::jsonb else to_jsonb(new) end;
  v_id uuid;
  v_booking uuid;
begin
  v_id := coalesce(nullif(v_new->>'id','')::uuid,nullif(v_old->>'id','')::uuid);
  v_booking := case when tg_table_name='service_bookings' then v_id
    else coalesce(nullif(v_new->>'booking_id','')::uuid,nullif(v_old->>'booking_id','')::uuid) end;
  insert into public.srk_admin_audit_events(
    entity_type,entity_id,booking_id,action,actor_user_id,actor_role,
    changed_fields,before_data,after_data
  ) values (
    case tg_table_name when 'service_bookings' then 'booking' else 'electrician_payout' end,
    v_id,v_booking,lower(tg_op),auth.uid(),
    case when auth.uid() is null then 'system' else 'user' end,
    array['fixture_audit'],v_old,v_new
  );
  if tg_op='DELETE' then return old; else return new; end if;
end
$function$;

create trigger srk_audit_service_bookings
after insert or update or delete on public.service_bookings
for each row execute function public.test_capture_admin_audit_event();
create trigger srk_audit_electrician_payouts
after insert or update or delete on public.srk_electrician_payouts
for each row execute function public.test_capture_admin_audit_event();

-- Main Production legacy commission function and payout trigger, which the
-- timer integration migration must replace without breaking legacy quote jobs.
create or replace function public.srk_calculate_booking_commission()
returns trigger
language plpgsql
set search_path = 'pg_catalog','public','pg_temp'
as $function$
begin
  if new.amount_paid is not null and new.amount_paid < 0 then
    raise exception 'amount_paid cannot be negative';
  end if;
  if new.commission_rate is null or new.commission_rate < 0 or new.commission_rate > 100 then
    raise exception 'commission_rate must be between 0 and 100';
  end if;
  if new.service_charge is not null and new.service_charge < 0 then
    raise exception 'service_charge cannot be negative';
  end if;
  if new.status='completed' and new.payment_status='paid'
     and new.amount_paid is not null and new.service_charge is not null then
    new.commission_amount := round(new.service_charge*new.commission_rate/100,2);
  else
    new.commission_amount := null;
  end if;
  return new;
end
$function$;

create or replace function public.srk_create_electrician_payable()
returns trigger
language plpgsql
security definer
set search_path = 'pg_catalog','public','pg_temp'
as $function$
declare
  v_service numeric(12,2);
  v_materials numeric(12,2);
  v_total numeric(12,2);
  v_rate numeric(7,2);
  v_commission numeric(12,2);
begin
  if new.payment_status='paid' and new.status='completed'
     and new.quote_status='approved' and new.assigned_electrician_id is not null
     and new.payment_verified_at is not null
     and (new.razorpay_payment_id is not null or exists (
       select 1 from public.srk_manual_payment_entries e
       where e.booking_id=new.id and e.amount=round(coalesce(new.amount_paid,0),2)
     )) then
    v_service:=round(coalesce(new.service_charge,0),2);
    v_materials:=round(coalesce(new.materials_amount,0),2);
    v_total:=round(v_service+v_materials,2);
    v_rate:=new.commission_rate;
    if v_rate is null or v_rate<0 or v_rate>100 then
      raise exception 'Commission rate must be between 0 and 100; payout ledger not created';
    end if;
    if round(coalesce(new.amount_paid,0),2)<>v_total then
      raise exception 'Verified payment amount does not match approved quote total; payout ledger not created';
    end if;
    v_commission:=round(v_service*v_rate/100,2);
    insert into public.srk_electrician_payouts(
      booking_id,electrician_profile_id,razorpay_payment_id,
      gross_service_amount,materials_amount,platform_commission,
      electrician_payable,payout_status
    ) values (
      new.id,new.assigned_electrician_id,new.razorpay_payment_id,
      v_service,v_materials,v_commission,
      round(v_service+v_materials-v_commission,2),'pending'
    )
    on conflict(booking_id) do update set
      electrician_profile_id=excluded.electrician_profile_id,
      razorpay_payment_id=excluded.razorpay_payment_id,
      gross_service_amount=excluded.gross_service_amount,
      materials_amount=excluded.materials_amount,
      platform_commission=excluded.platform_commission,
      electrician_payable=excluded.electrician_payable,
      updated_at=now()
    where public.srk_electrician_payouts.payout_status='pending';
  elsif new.payment_status='refunded' then
    update public.srk_electrician_payouts
      set payout_status='refunded',updated_at=now()
    where booking_id=new.id and payout_status='pending';
  end if;
  return new;
end
$function$;

create trigger srk_calculate_booking_commission
before insert or update of status,payment_status,amount_paid,commission_rate
on public.service_bookings for each row
execute function public.srk_calculate_booking_commission();
create trigger trg_srk_create_electrician_payable
after insert or update of payment_status,status,quote_status,service_charge,materials_amount,
  assigned_electrician_id,payment_verified_at,razorpay_payment_id,amount_paid
on public.service_bookings for each row
execute function public.srk_create_electrician_payable();

-- Representative paid legacy quote booking and payout, created through the
-- same insert-then-assign/status transition used by Production.
insert into auth.users(id,phone)
values ('31000000-0000-4000-8000-000000000001','9000000003')
on conflict(id) do nothing;
insert into public.electrician_profiles(
  id,user_id,auth_user_id,active,verification_status,display_name,
  phone,state,district,pincode,skills
) values (
  '21000000-0000-4000-8000-000000000002',
  '31000000-0000-4000-8000-000000000001',
  '31000000-0000-4000-8000-000000000001',
  true,'approved','Legacy Fixture Electrician',
  '9000000003','Uttar Pradesh','Balrampur','271861',array['electrical']
);

insert into public.service_bookings(
  id,customer_name,phone,state,district,pincode,address,service_type,
  payment_method,customer_user_id
) values (
  '11000000-0000-4000-8000-000000000002',
  'Paid legacy fixture','9000000004','Uttar Pradesh','Balrampur','271861',
  'Fixture address','Electrical repair','Cash','31000000-0000-4000-8000-000000000001'
);
update public.service_bookings
set assigned_electrician_id='21000000-0000-4000-8000-000000000002',
    status='completed',quote_status='approved',service_charge=100,
    materials_amount=20,amount_paid=120,payment_status='paid',
    payment_method='Online',razorpay_payment_id='pay_legacy_fixture',
    payment_verified_at=clock_timestamp()
where id='11000000-0000-4000-8000-000000000002';

do $assert$
begin
  if not exists (
    select 1 from public.srk_electrician_payouts
    where booking_id='11000000-0000-4000-8000-000000000002'
      and gross_service_amount=100 and materials_amount=20
      and platform_commission=15 and electrician_payable=105
      and payout_status='pending'
  ) then
    raise exception 'Production legacy payout fixture was not created as expected';
  end if;
end
$assert$;
