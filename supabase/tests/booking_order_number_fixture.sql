-- Disposable PostgreSQL fixture for booking order-number migration and electrician offer RPC.
\set ON_ERROR_STOP on
do $roles$
begin
  if not exists(select 1 from pg_roles where rolname='anon') then create role anon nologin; end if;
  if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated nologin; end if;
end
$roles$;
create schema if not exists auth;
create or replace function auth.uid() returns uuid
language sql stable
as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
create or replace function auth.jwt() returns jsonb
language sql stable
as $$ select jsonb_build_object('sub',current_setting('request.jwt.claim.sub',true),'phone',current_setting('request.jwt.claim.phone',true)) $$;
create table public.service_bookings(
 id uuid primary key default gen_random_uuid(),
 service_type text, state text, district text, pincode text,
 preferred_date date, preferred_time time, work_details text,
 quoted_amount numeric, order_number text, status text not null default 'new',
 customer_name text, phone text, address text,
 location_lat double precision, location_lng double precision,
 service_charge numeric, materials_amount numeric, quote_status text, quote_note text,
 assigned_electrician_id uuid,
 created_at timestamptz not null default now(),
 customer_user_id uuid,
 service_category_code text,
 service_category_label text,
 hourly_rate_snapshot numeric(12,6)
);
create table public.electrician_profiles(
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null unique,
 verification_status text not null,
 active boolean not null default false
);
create table public.job_offers(
 id uuid primary key default gen_random_uuid(),
 status text not null,
 match_level text,
 created_at timestamptz not null default now(),
 electrician_id uuid not null references public.electrician_profiles(id),
 booking_id uuid not null references public.service_bookings(id)
);
insert into public.service_bookings(id,service_type,state,district,pincode,preferred_date,preferred_time,work_details,quoted_amount,status,customer_name,phone,address,location_lat,location_lng,service_charge,materials_amount,quote_status,quote_note,created_at)
values
 ('10000000-0000-0000-0000-000000000001','Wiring','UP','Balrampur','271861',current_date,'10:00','Old booking',100,'new','Test Customer','9000000001','Test Address',26.8,82.1,100,0,'pending','note',now());
insert into public.electrician_profiles(id,user_id,verification_status,active)
values
 ('20000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','approved',true),
 ('20000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000002','approved',true),
 ('20000000-0000-0000-0000-000000000003','30000000-0000-0000-0000-000000000003','pending',false);
insert into public.service_bookings(id,service_type,state,district,pincode,preferred_date,preferred_time,work_details,quoted_amount,status,customer_name,phone,address,location_lat,location_lng,service_charge,materials_amount,quote_status,quote_note,assigned_electrician_id)
values
 ('10000000-0000-0000-0000-000000000002','Repair','UP','Balrampur','271861',current_date,'11:00','Assigned booking',200,'assigned','Assigned Customer','9000000002','Assigned Address',26.9,82.2,200,0,'approved','approved note','20000000-0000-0000-0000-000000000001'),
 ('10000000-0000-0000-0000-000000000003','Repair','UP','Balrampur','271861',current_date,'12:00','Unassigned offer',200,'new','Private Customer','9000000003','Private Address',27,82.3,200,0,'pending','private note',null);
-- Simulate a previously-numbered booking whose suffix is ahead of the fresh sequence.
update public.service_bookings set order_number='SRK-ORD-000010'
where id='10000000-0000-0000-0000-000000000003';
insert into public.job_offers(id,status,match_level,electrician_id,booking_id)
values
 ('40000000-0000-0000-0000-000000000001','sent','same_pincode','20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002'),
 ('40000000-0000-0000-0000-000000000002','sent','same_pincode','20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000003'),
 ('40000000-0000-0000-0000-000000000003','sent','same_pincode','20000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000002');

grant select on public.service_bookings to authenticated;
create table public.srk_booking_creation_requests(
 customer_user_id uuid not null,
 idempotency_key uuid not null,
 booking_id uuid not null references public.service_bookings(id),
 created_at timestamptz not null default now(),
 primary key(customer_user_id,idempotency_key)
);
