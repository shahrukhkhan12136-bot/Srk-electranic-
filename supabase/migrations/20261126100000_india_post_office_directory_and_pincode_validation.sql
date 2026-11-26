-- Official India Post / OGD PIN directory import and server-side location validation.
-- Data source: Department of Posts, "All India Pincode Directory (Through WebService)"
-- OGD resource: https://data.gov.in/resource/all-india-pincode-directory-till-last-month
-- The directory is NOT seeded here: the OGD API page currently reports that an API
-- endpoint does not exist. Admin must import a complete, dated official CSV snapshot.
-- Validation remains inactive until a complete 36-State/UT snapshot is finalized.

create table if not exists public.srk_india_post_offices (
  id bigint generated always as identity primary key,
  pincode text not null,
  office_name text not null,
  office_type text not null default '',
  delivery_status text not null default '',
  district_name text not null,
  state_name text not null,
  circle_name text,
  region_name text,
  division_name text,
  source_date text not null,
  source_name text not null,
  is_active boolean not null default true,
  imported_at timestamptz not null default clock_timestamp(),
  constraint srk_india_post_offices_pincode_format check (pincode ~ '^[0-9]{6}$'),
  constraint srk_india_post_offices_required_names check (
    length(btrim(office_name)) > 0
    and length(btrim(district_name)) > 0
    and length(btrim(state_name)) > 0
  ),
  constraint srk_india_post_offices_unique_office unique
    (pincode, office_name, office_type, district_name, state_name)
);
create index if not exists srk_india_post_offices_location_idx
  on public.srk_india_post_offices(pincode, state_name, district_name)
  where is_active;
alter table public.srk_india_post_offices enable row level security;
revoke all on public.srk_india_post_offices from public, anon, authenticated;

create table if not exists srk_private.india_post_office_import_batches (
  id uuid primary key default gen_random_uuid(),
  source_date text not null,
  source_name text not null,
  expected_rows integer not null check (expected_rows > 0),
  imported_rows integer not null default 0,
  status text not null default 'importing'
    check (status in ('importing','finalized','failed')),
  created_by uuid not null,
  created_at timestamptz not null default clock_timestamp(),
  finalized_at timestamptz
);
alter table srk_private.india_post_office_import_batches enable row level security;
revoke all on srk_private.india_post_office_import_batches from public, anon, authenticated;

create table if not exists srk_private.india_post_office_import_staging (
  batch_id uuid not null references srk_private.india_post_office_import_batches(id) on delete cascade,
  pincode text not null,
  office_name text not null,
  office_type text not null default '',
  delivery_status text not null default '',
  district_name text not null,
  state_name text not null,
  circle_name text,
  region_name text,
  division_name text,
  primary key (batch_id,pincode,office_name,office_type,district_name,state_name),
  constraint srk_india_post_office_staging_pin_format check (pincode ~ '^[0-9]{6}$')
);
alter table srk_private.india_post_office_import_staging enable row level security;
revoke all on srk_private.india_post_office_import_staging from public, anon, authenticated;

create table if not exists srk_private.india_post_office_directory_status (
  singleton boolean primary key default true check (singleton),
  is_ready boolean not null default false,
  source_date text,
  source_name text,
  active_rows integer not null default 0,
  activated_at timestamptz,
  updated_at timestamptz not null default clock_timestamp()
);
alter table srk_private.india_post_office_directory_status enable row level security;
revoke all on srk_private.india_post_office_directory_status from public, anon, authenticated;
insert into srk_private.india_post_office_directory_status(singleton,is_ready)
values (true,false)
on conflict (singleton) do nothing;

create or replace function srk_private.admin_begin_post_office_import(
  p_source_date text,
  p_expected_rows integer,
  p_source_name text default 'Department of Posts — All India Pincode Directory (OGD Platform India)'
) returns uuid
language plpgsql volatile security definer
set search_path=pg_catalog,public,auth,srk_private
as $function$
declare v_id uuid;
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'Main Admin permission required' using errcode='42501';
  end if;
  if nullif(btrim(p_source_date),'') is null or p_expected_rows < 5000
     or nullif(btrim(p_source_name),'') is null then
    raise exception 'A dated all-India postal directory snapshot and its expected row count are required';
  end if;
  insert into srk_private.india_post_office_import_batches(source_date,source_name,expected_rows,created_by)
  values (btrim(p_source_date),btrim(p_source_name),p_expected_rows,auth.uid())
  returning id into v_id;
  return v_id;
end;
$function$;

create or replace function srk_private.admin_import_post_office_chunk(
  p_batch_id uuid,
  p_rows jsonb
) returns integer
language plpgsql volatile security definer
set search_path=pg_catalog,public,auth,srk_private
as $function$
declare v_batch srk_private.india_post_office_import_batches%rowtype; v_count integer;
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'Main Admin permission required' using errcode='42501';
  end if;
  select * into v_batch from srk_private.india_post_office_import_batches
  where id=p_batch_id for update;
  if not found or v_batch.status <> 'importing' then
    raise exception 'Postal directory import batch is not open';
  end if;
  if jsonb_typeof(p_rows) <> 'array' or jsonb_array_length(p_rows) < 1
     or jsonb_array_length(p_rows) > 500 then
    raise exception 'Import each postal directory chunk with 1 to 500 rows';
  end if;
  if exists (
    select 1
    from jsonb_to_recordset(p_rows) as x(
      pincode text, office_name text, office_type text, delivery_status text,
      district_name text, state_name text, circle_name text, region_name text, division_name text
    )
    where coalesce(pincode,'') !~ '^[0-9]{6}$'
       or nullif(btrim(office_name),'') is null
       or nullif(btrim(district_name),'') is null
       or nullif(btrim(state_name),'') is null
  ) then
    raise exception 'Postal directory chunk has an invalid PIN, office, district, or state';
  end if;
  insert into srk_private.india_post_office_import_staging(
    batch_id,pincode,office_name,office_type,delivery_status,district_name,state_name,
    circle_name,region_name,division_name
  )
  select p_batch_id,btrim(x.pincode),btrim(x.office_name),coalesce(btrim(x.office_type),''),
    coalesce(btrim(x.delivery_status),''),btrim(x.district_name),btrim(x.state_name),
    nullif(btrim(x.circle_name),''),nullif(btrim(x.region_name),''),nullif(btrim(x.division_name),'')
  from jsonb_to_recordset(p_rows) as x(
    pincode text, office_name text, office_type text, delivery_status text,
    district_name text, state_name text, circle_name text, region_name text, division_name text
  )
  on conflict (batch_id,pincode,office_name,office_type,district_name,state_name)
  do update set delivery_status=excluded.delivery_status,
    circle_name=excluded.circle_name,region_name=excluded.region_name,division_name=excluded.division_name;
  get diagnostics v_count = row_count;
  return v_count;
end;
$function$;

create or replace function srk_private.admin_finalize_post_office_import(p_batch_id uuid)
returns integer
language plpgsql volatile security definer
set search_path=pg_catalog,public,auth,srk_private
as $function$
declare
  v_batch srk_private.india_post_office_import_batches%rowtype;
  v_rows integer;
  v_states integer;
  v_districts integer;
  v_pincodes integer;
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'Main Admin permission required' using errcode='42501';
  end if;
  select * into v_batch from srk_private.india_post_office_import_batches
  where id=p_batch_id for update;
  if not found or v_batch.status <> 'importing' then
    raise exception 'Postal directory import batch is not open';
  end if;
  select count(*)::integer,count(distinct lower(btrim(state_name)))::integer,
    count(distinct lower(btrim(state_name))||'|'||lower(btrim(district_name)))::integer,
    count(distinct pincode)::integer
  into v_rows,v_states,v_districts,v_pincodes
  from srk_private.india_post_office_import_staging where batch_id=p_batch_id;

  if v_rows <> v_batch.expected_rows then
    raise exception 'Postal directory row count mismatch: expected %, imported %',v_batch.expected_rows,v_rows;
  end if;
  if v_states <> 36 or v_districts < 500 or v_pincodes < 5000 then
    raise exception 'Postal directory completeness check failed: states %, districts %, PINs %',
      v_states,v_districts,v_pincodes;
  end if;

  -- Keep the old live snapshot until this complete replacement commits.
  delete from public.srk_india_post_offices;
  insert into public.srk_india_post_offices(
    pincode,office_name,office_type,delivery_status,district_name,state_name,
    circle_name,region_name,division_name,source_date,source_name,is_active
  )
  select pincode,office_name,office_type,delivery_status,district_name,state_name,
    circle_name,region_name,division_name,v_batch.source_date,v_batch.source_name,true
  from srk_private.india_post_office_import_staging where batch_id=p_batch_id;

  update srk_private.india_post_office_directory_status
  set is_ready=true,source_date=v_batch.source_date,source_name=v_batch.source_name,
    active_rows=v_rows,activated_at=clock_timestamp(),updated_at=clock_timestamp()
  where singleton=true;
  update srk_private.india_post_office_import_batches
  set imported_rows=v_rows,status='finalized',finalized_at=clock_timestamp()
  where id=p_batch_id;
  delete from srk_private.india_post_office_import_staging where batch_id=p_batch_id;
  return v_rows;
end;
$function$;

-- Public RPC wrappers are the only PostgREST entry points for Admin import.
create or replace function public.srk_admin_begin_india_post_office_import(
  p_source_date text,p_expected_rows integer,
  p_source_name text default 'Department of Posts — All India Pincode Directory (OGD Platform India)'
) returns uuid
language sql volatile security definer
set search_path=pg_catalog,public,auth,srk_private
as $function$
  select srk_private.admin_begin_post_office_import(p_source_date,p_expected_rows,p_source_name);
$function$;

create or replace function public.srk_admin_import_india_post_office_chunk(
  p_batch_id uuid,p_rows jsonb
) returns integer
language sql volatile security definer
set search_path=pg_catalog,public,auth,srk_private
as $function$
  select srk_private.admin_import_post_office_chunk(p_batch_id,p_rows);
$function$;

create or replace function public.srk_admin_finalize_india_post_office_import(
  p_batch_id uuid
) returns integer
language sql volatile security definer
set search_path=pg_catalog,public,auth,srk_private
as $function$
  select srk_private.admin_finalize_post_office_import(p_batch_id);
$function$;

create or replace function public.srk_admin_get_india_post_office_import_status(
  p_batch_id uuid
) returns table(batch_id uuid,source_date text,expected_rows integer,imported_rows integer,status text)
language plpgsql stable security definer
set search_path=pg_catalog,public,auth,srk_private
as $function$
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'Main Admin permission required' using errcode='42501';
  end if;
  return query
  select b.id,b.source_date,b.expected_rows,
    case when b.status='finalized' then b.imported_rows
      else (select count(*)::integer from srk_private.india_post_office_import_staging s where s.batch_id=b.id) end,
    b.status
  from srk_private.india_post_office_import_batches b
  where b.id=p_batch_id;
end;
$function$;

create or replace function srk_private.assert_india_postal_location(
  p_state text,p_district text,p_pincode text
) returns boolean
language plpgsql stable security definer
set search_path=pg_catalog,public,srk_private
as $function$
begin
  if p_pincode is null or p_pincode !~ '^[0-9]{6}$' then
    raise exception 'कृपया 6 अंकों का सही पिन कोड भरें।';
  end if;
  if not exists (
    select 1 from srk_private.india_post_office_directory_status
    where singleton=true and is_ready=true and active_rows>0
  ) then
    raise exception 'भारत की आधिकारिक PIN Directory अभी Admin द्वारा सक्रिय नहीं की गई है।';
  end if;
  if not exists (
    select 1 from public.srk_india_post_offices o
    where o.is_active and o.pincode=p_pincode
      and lower(regexp_replace(btrim(o.state_name),'[^[:alnum:]]','','g')) =
          lower(regexp_replace(btrim(coalesce(p_state,'')),'[^[:alnum:]]','','g'))
      and lower(regexp_replace(btrim(o.district_name),'[^[:alnum:]]','','g')) =
          lower(regexp_replace(btrim(coalesce(p_district,'')),'[^[:alnum:]]','','g'))
  ) then
    raise exception 'यह पिन कोड चुने गए राज्य और जिले से मेल नहीं खाता। कृपया सही लोकेशन चुनें।';
  end if;
  return true;
end;
$function$;

create or replace function public.srk_customer_validate_india_location_v1(
  p_state text,p_district text,p_pincode text
) returns boolean
language plpgsql stable security definer
set search_path=pg_catalog,public,auth,srk_private
as $function$
begin
  if auth.uid() is null then
    raise exception 'OTP login required' using errcode='42501';
  end if;
  return srk_private.assert_india_postal_location(p_state,p_district,p_pincode);
end;
$function$;

create or replace function srk_private.validate_service_booking_postal_location()
returns trigger
language plpgsql volatile security definer
set search_path=pg_catalog,public,srk_private
as $function$
begin
  if exists (
    select 1 from srk_private.india_post_office_directory_status
    where singleton=true and is_ready=true and active_rows>0
  ) then
    perform srk_private.assert_india_postal_location(new.state,new.district,new.pincode);
  end if;
  return new;
end;
$function$;

drop trigger if exists trg_srk_validate_postal_location on public.service_bookings;
create trigger trg_srk_validate_postal_location
before insert or update of state,district,pincode on public.service_bookings
for each row execute function srk_private.validate_service_booking_postal_location();

revoke all on function public.srk_admin_begin_india_post_office_import(text,integer,text) from public,anon;
revoke all on function public.srk_admin_import_india_post_office_chunk(uuid,jsonb) from public,anon;
revoke all on function public.srk_admin_finalize_india_post_office_import(uuid) from public,anon;
revoke all on function public.srk_admin_get_india_post_office_import_status(uuid) from public,anon;
grant execute on function public.srk_admin_begin_india_post_office_import(text,integer,text) to authenticated;
grant execute on function public.srk_admin_import_india_post_office_chunk(uuid,jsonb) to authenticated;
grant execute on function public.srk_admin_finalize_india_post_office_import(uuid) to authenticated;
grant execute on function public.srk_admin_get_india_post_office_import_status(uuid) to authenticated;

revoke all on function srk_private.admin_begin_post_office_import(text,integer,text) from public,anon,authenticated;
revoke all on function srk_private.admin_import_post_office_chunk(uuid,jsonb) from public,anon,authenticated;
revoke all on function srk_private.admin_finalize_post_office_import(uuid) from public,anon,authenticated;
revoke all on function srk_private.assert_india_postal_location(text,text,text) from public,anon,authenticated;
revoke all on function srk_private.validate_service_booking_postal_location() from public,anon,authenticated;
revoke all on function public.srk_customer_validate_india_location_v1(text,text,text) from public,anon;
grant execute on function public.srk_customer_validate_india_location_v1(text,text,text) to authenticated;
