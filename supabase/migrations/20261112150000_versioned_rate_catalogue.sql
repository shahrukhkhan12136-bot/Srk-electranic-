-- Append-only, effective-dated category rate catalogue. Feature branch only.
begin;

create table if not exists public.srk_rate_catalogue (
  id uuid primary key default gen_random_uuid(),
  category_code text not null check (category_code in ('helper','ordinary','skilled','master')),
  category_label text not null check (category_label in ('Helper','Ordinary','Skilled','Master')),
  version integer not null check (version >= 1),
  hourly_rate numeric(12,6) not null check (hourly_rate > 0),
  effective_from date not null,
  created_at timestamptz not null default now(),
  created_by uuid,
  constraint srk_rate_catalogue_category_version_key unique(category_code,version)
);

alter table public.srk_rate_catalogue drop constraint if exists srk_rate_catalogue_category_effective_key;
alter table public.srk_rate_catalogue enable row level security;
revoke all on table public.srk_rate_catalogue from public, anon, authenticated;

create or replace function public.srk_rate_catalogue_append_only()
returns trigger language plpgsql set search_path=''
as $guard$
begin
  raise exception 'RATE_CATALOGUE_ROWS_ARE_APPEND_ONLY' using errcode='55000';
end
$guard$;
revoke all on function public.srk_rate_catalogue_append_only() from public,anon,authenticated;
drop trigger if exists srk_rate_catalogue_no_mutation on public.srk_rate_catalogue;
create trigger srk_rate_catalogue_no_mutation
before update or delete on public.srk_rate_catalogue
for each row execute function public.srk_rate_catalogue_append_only();

insert into public.srk_rate_catalogue(category_code,category_label,version,hourly_rate,effective_from)
values
 ('helper','Helper',1,112.375,date '2026-11-12'),
 ('ordinary','Ordinary',1,149.875,date '2026-11-12'),
 ('skilled','Skilled',1,199.875,date '2026-11-12'),
 ('master','Master',1,249.875,date '2026-11-12')
on conflict (category_code,version) do nothing;

alter table public.service_bookings
  add column if not exists rate_catalogue_id uuid references public.srk_rate_catalogue(id),
  add column if not exists rate_version_snapshot integer;

do $constraints$
begin
 if not exists(select 1 from pg_constraint where conrelid='public.service_bookings'::regclass and conname='service_bookings_rate_catalogue_snapshot_pair_check') then
  alter table public.service_bookings add constraint service_bookings_rate_catalogue_snapshot_pair_check
   check ((rate_catalogue_id is null and rate_version_snapshot is null) or
          (rate_catalogue_id is not null and rate_version_snapshot is not null and rate_version_snapshot >= 1));
 end if;
end $constraints$;

alter table public.service_bookings
  add column if not exists duration_hours smallint,
  add column if not exists estimated_labour_amount_snapshot numeric(12,2);

do $constraints$
begin
  if not exists (select 1 from pg_constraint where conrelid='public.service_bookings'::regclass and conname='service_bookings_duration_hours_check') then
    alter table public.service_bookings add constraint service_bookings_duration_hours_check
      check (duration_hours is null or duration_hours between 1 and 8);
  end if;
  if not exists (select 1 from pg_constraint where conrelid='public.service_bookings'::regclass and conname='service_bookings_estimated_labour_snapshot_check') then
    alter table public.service_bookings add constraint service_bookings_estimated_labour_snapshot_check
      check (estimated_labour_amount_snapshot is null or estimated_labour_amount_snapshot >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conrelid='public.service_bookings'::regclass and conname='service_bookings_duration_estimate_pair_check') then
    alter table public.service_bookings add constraint service_bookings_duration_estimate_pair_check
      check (
        (duration_hours is null and estimated_labour_amount_snapshot is null)
        or
        (duration_hours between 1 and 8
          and estimated_labour_amount_snapshot is not null
          and hourly_rate_snapshot is not null
          and estimated_labour_amount_snapshot = round(hourly_rate_snapshot * duration_hours, 2))
      );
  end if;
end
$constraints$;

create or replace function public.srk_create_customer_booking(
  p_booking jsonb,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_phone_claim text;
  v_phone text;
  v_phone_digits text;
  v_category text;
  v_label text;
  v_rate numeric(12,6);
  v_rate_catalogue_id uuid;
  v_rate_version integer;
  v_duration smallint;
  v_estimated numeric(12,2);
  v_booking_id uuid;
  v_existing uuid;
  v_lat double precision;
  v_lng double precision;
begin
  if v_uid is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode='28000';
  end if;
  if p_idempotency_key is null then
    raise exception 'IDEMPOTENCY_KEY_REQUIRED' using errcode='22023';
  end if;
  if p_booking is null or jsonb_typeof(p_booking)<>'object' then
    raise exception 'INVALID_BOOKING_PAYLOAD' using errcode='22023';
  end if;

  if exists (
    select 1 from jsonb_object_keys(p_booking) as keys(key)
    where key not in ('customer_name','phone','state','district','pincode','address',
      'service_type','preferred_date','preferred_time','work_details',
      'location_lat','location_lng','service_category_code','duration_hours')
  ) then
    raise exception 'UNSUPPORTED_BOOKING_FIELD' using errcode='22023';
  end if;

  v_phone := regexp_replace(coalesce(p_booking->>'phone',''), '[^0-9]', '', 'g');
  v_phone_digits := v_phone;
  v_phone_claim := regexp_replace(coalesce(auth.jwt()->>'phone',''), '[^0-9]', '', 'g');
  if length(v_phone)=10 then v_phone := '91'||v_phone; end if;
  if length(v_phone_claim)=10 then v_phone_claim := '91'||v_phone_claim; end if;
  if length(v_phone_digits)<>10 or v_phone='' or v_phone_claim='' or v_phone<>v_phone_claim then
    raise exception 'VERIFIED_PHONE_MISMATCH' using errcode='42501';
  end if;

  v_category := p_booking->>'service_category_code';
  if v_category not in ('helper','ordinary','skilled','master') then
    raise exception 'INVALID_SERVICE_CATEGORY' using errcode='22023';
  end if;
  select c.id,c.version,c.hourly_rate,c.category_label
    into v_rate_catalogue_id,v_rate_version,v_rate,v_label
  from public.srk_rate_catalogue c
  where c.category_code=v_category and c.effective_from <= current_date
  order by c.effective_from desc,c.version desc
  limit 1;
  if v_rate_catalogue_id is null then
    raise exception 'RATE_NOT_CONFIGURED_FOR_DATE' using errcode='55000';
  end if;

  -- Legacy callers without duration remain compatible at the original 8-hour rate.
  if p_booking ? 'duration_hours' then
    if coalesce(p_booking->>'duration_hours','') !~ '^[1-8]$' then
      raise exception 'INVALID_DURATION_HOURS' using errcode='22023';
    end if;
    v_duration := (p_booking->>'duration_hours')::smallint;
  else
    v_duration := 8;
  end if;
  v_estimated := round(v_rate * v_duration, 2);

  if length(btrim(coalesce(p_booking->>'customer_name','')))=0
     or length(btrim(coalesce(p_booking->>'state','')))=0
     or length(btrim(coalesce(p_booking->>'district','')))=0
     or coalesce(p_booking->>'pincode','') !~ '^[0-9]{6}$'
     or length(btrim(coalesce(p_booking->>'address','')))=0
     or length(btrim(coalesce(p_booking->>'service_type','')))=0
     or coalesce(p_booking->>'preferred_date','') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
    raise exception 'REQUIRED_BOOKING_FIELDS_MISSING' using errcode='22023';
  end if;
  if nullif(p_booking->>'preferred_time','') is not null
     and p_booking->>'preferred_time' !~ '^[0-9]{2}:[0-9]{2}(:[0-9]{2})?$' then
    raise exception 'INVALID_OPTIONAL_PREFERRED_TIME' using errcode='22023';
  end if;

  if (p_booking->'location_lat' is null or p_booking->'location_lat'='null'::jsonb)
     <> (p_booking->'location_lng' is null or p_booking->'location_lng'='null'::jsonb) then
    raise exception 'LOCATION_COORDINATES_MUST_BE_PAIRED' using errcode='22023';
  end if;
  if p_booking->'location_lat' is not null and p_booking->'location_lat'<>'null'::jsonb then
    v_lat := (p_booking->>'location_lat')::double precision;
    v_lng := (p_booking->>'location_lng')::double precision;
    if v_lat < -90 or v_lat > 90 or v_lng < -180 or v_lng > 180 then
      raise exception 'INVALID_LOCATION_COORDINATES' using errcode='22023';
    end if;
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_uid::text||':'||p_idempotency_key::text,0)
  );
  select r.booking_id into v_existing
  from public.srk_booking_creation_requests r
  where r.customer_user_id=v_uid and r.idempotency_key=p_idempotency_key;
  if found then
    return jsonb_build_object('success',true,'booking_id',v_existing,'replayed',true);
  end if;

  insert into public.service_bookings(
    customer_name,phone,state,district,pincode,address,service_type,
    preferred_date,preferred_time,work_details,location_lat,location_lng,
    customer_user_id,service_category_code,service_category_label,hourly_rate_snapshot,
    duration_hours,estimated_labour_amount_snapshot,rate_catalogue_id,rate_version_snapshot
  ) values (
    btrim(p_booking->>'customer_name'),v_phone_digits,btrim(p_booking->>'state'),btrim(p_booking->>'district'),p_booking->>'pincode',btrim(p_booking->>'address'),btrim(p_booking->>'service_type'),
    (p_booking->>'preferred_date')::date,nullif(p_booking->>'preferred_time','')::time,
    nullif(btrim(coalesce(p_booking->>'work_details','')),''),
    v_lat,v_lng,v_uid,v_category,v_label,v_rate,v_duration,v_estimated,v_rate_catalogue_id,v_rate_version
  ) returning id into v_booking_id;

  insert into public.srk_booking_creation_requests(customer_user_id,idempotency_key,booking_id)
  values (v_uid,p_idempotency_key,v_booking_id);

  return jsonb_build_object('success',true,'booking_id',v_booking_id,'replayed',false,
    'service_category_code',v_category,'service_category_label',v_label,
    'hourly_rate_snapshot',v_rate,'duration_hours',v_duration,
    'estimated_labour_amount_snapshot',v_estimated,'rate_catalogue_id',v_rate_catalogue_id,
    'rate_version',v_rate_version);
end
$function$;

create or replace function public.srk_guard_booking_rate_snapshot()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  if new.service_category_code is distinct from old.service_category_code
     or new.service_category_label is distinct from old.service_category_label
     or new.hourly_rate_snapshot is distinct from old.hourly_rate_snapshot
     or new.duration_hours is distinct from old.duration_hours
     or new.estimated_labour_amount_snapshot is distinct from old.estimated_labour_amount_snapshot
     or new.rate_catalogue_id is distinct from old.rate_catalogue_id
     or new.rate_version_snapshot is distinct from old.rate_version_snapshot then
    raise exception 'BOOKING_RATE_SNAPSHOT_IMMUTABLE' using errcode='55000';
  end if;
  return new;
end
$function$;

drop trigger if exists z_srk_guard_booking_rate_snapshot on public.service_bookings;
create trigger z_srk_guard_booking_rate_snapshot
before update of service_category_code,service_category_label,hourly_rate_snapshot,
  duration_hours,estimated_labour_amount_snapshot,rate_catalogue_id,rate_version_snapshot
on public.service_bookings
for each row execute function public.srk_guard_booking_rate_snapshot();

revoke all on function public.srk_guard_booking_rate_snapshot() from public, anon, authenticated;
revoke all on function public.srk_create_customer_booking(jsonb,uuid) from public, anon;
grant execute on function public.srk_create_customer_booking(jsonb,uuid) to authenticated;


commit;
