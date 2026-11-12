-- Customer-selected initial duration and server-calculated immutable labour estimate.
-- Feature branch only. Do not apply to TEST or Production without explicit approval.
begin;

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
  case v_category
    when 'helper' then v_label := 'Helper'; v_rate := 112.375;
    when 'ordinary' then v_label := 'Ordinary'; v_rate := 149.875;
    when 'skilled' then v_label := 'Skilled'; v_rate := 199.875;
    when 'master' then v_label := 'Master'; v_rate := 249.875;
    else raise exception 'INVALID_SERVICE_CATEGORY' using errcode='22023';
  end case;

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
    duration_hours,estimated_labour_amount_snapshot
  ) values (
    btrim(p_booking->>'customer_name'),v_phone_digits,btrim(p_booking->>'state'),btrim(p_booking->>'district'),p_booking->>'pincode',btrim(p_booking->>'address'),btrim(p_booking->>'service_type'),
    (p_booking->>'preferred_date')::date,nullif(p_booking->>'preferred_time','')::time,
    nullif(btrim(coalesce(p_booking->>'work_details','')),''),
    v_lat,v_lng,v_uid,v_category,v_label,v_rate,v_duration,v_estimated
  ) returning id into v_booking_id;

  insert into public.srk_booking_creation_requests(customer_user_id,idempotency_key,booking_id)
  values (v_uid,p_idempotency_key,v_booking_id);

  return jsonb_build_object('success',true,'booking_id',v_booking_id,'replayed',false,
    'service_category_code',v_category,'service_category_label',v_label,
    'hourly_rate_snapshot',v_rate,'duration_hours',v_duration,
    'estimated_labour_amount_snapshot',v_estimated);
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
     or new.estimated_labour_amount_snapshot is distinct from old.estimated_labour_amount_snapshot then
    raise exception 'BOOKING_RATE_SNAPSHOT_IMMUTABLE' using errcode='55000';
  end if;
  return new;
end
$function$;

drop trigger if exists z_srk_guard_booking_rate_snapshot on public.service_bookings;
create trigger z_srk_guard_booking_rate_snapshot
before update of service_category_code,service_category_label,hourly_rate_snapshot,
  duration_hours,estimated_labour_amount_snapshot
on public.service_bookings
for each row execute function public.srk_guard_booking_rate_snapshot();

revoke all on function public.srk_guard_booking_rate_snapshot() from public, anon, authenticated;
revoke all on function public.srk_create_customer_booking(jsonb,uuid) from public, anon;
grant execute on function public.srk_create_customer_booking(jsonb,uuid) to authenticated;

commit;
