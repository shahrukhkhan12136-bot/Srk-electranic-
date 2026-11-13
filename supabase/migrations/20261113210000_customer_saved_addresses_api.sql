-- Customer saved addresses: independent address book; never rewrites historical bookings.
-- PIN syntax is validated only. No authoritative PIN directory is currently present in public schema,
-- so district/state are retained as customer-entered values and must not be described as verified.

create table if not exists public.srk_customer_saved_addresses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  label text not null check (label in ('home','work','other')),
  recipient_name text not null check (length(btrim(recipient_name)) between 2 and 120),
  address_line text not null check (length(btrim(address_line)) between 5 and 500),
  landmark text check (landmark is null or length(landmark) <= 160),
  pincode text not null check (pincode ~ '^[0-9]{6}$'),
  district text not null check (length(btrim(district)) between 2 and 100),
  state text not null check (length(btrim(state)) between 2 and 100),
  location_lat double precision,
  location_lng double precision,
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint srk_customer_address_lat_range check (location_lat is null or location_lat between -90 and 90),
  constraint srk_customer_address_lng_range check (location_lng is null or location_lng between -180 and 180),
  constraint srk_customer_address_coordinates_pair check (
    (location_lat is null and location_lng is null) or
    (location_lat is not null and location_lng is not null)
  )
);

create index if not exists srk_customer_saved_addresses_owner_idx
  on public.srk_customer_saved_addresses(user_id, created_at desc);
create unique index if not exists srk_customer_saved_addresses_one_default_idx
  on public.srk_customer_saved_addresses(user_id) where is_default;

alter table public.srk_customer_saved_addresses enable row level security;
revoke all on public.srk_customer_saved_addresses from anon, authenticated;
grant select, insert, update, delete on public.srk_customer_saved_addresses to authenticated;

create policy "customers read own saved addresses"
on public.srk_customer_saved_addresses for select to authenticated
using ((select auth.uid()) = user_id);
create policy "customers insert own saved addresses"
on public.srk_customer_saved_addresses for insert to authenticated
with check ((select auth.uid()) = user_id);
create policy "customers update own saved addresses"
on public.srk_customer_saved_addresses for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);
create policy "customers delete own saved addresses"
on public.srk_customer_saved_addresses for delete to authenticated
using ((select auth.uid()) = user_id);

create or replace function public.srk_customer_list_my_saved_addresses()
returns table (
  id uuid, label text, recipient_name text, address_line text, landmark text,
  pincode text, district text, state text, location_lat double precision,
  location_lng double precision, is_default boolean, created_at timestamptz, updated_at timestamptz
)
language plpgsql stable security definer set search_path = ''
as $function$
declare v_user_id uuid := auth.uid();
begin
  if v_user_id is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='28000'; end if;
  return query
    select a.id,a.label,a.recipient_name,a.address_line,a.landmark,a.pincode,a.district,a.state,
           a.location_lat,a.location_lng,a.is_default,a.created_at,a.updated_at
    from public.srk_customer_saved_addresses a
    where a.user_id=v_user_id
    order by a.is_default desc,a.updated_at desc,a.id;
end;
$function$;

create or replace function public.srk_customer_save_my_address(
  p_id uuid,
  p_label text,
  p_recipient_name text,
  p_address_line text,
  p_landmark text,
  p_pincode text,
  p_district text,
  p_state text,
  p_location_lat double precision default null,
  p_location_lng double precision default null,
  p_is_default boolean default false
)
returns uuid
language plpgsql security definer set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_id uuid := p_id;
  v_count integer;
begin
  if v_user_id is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='28000'; end if;
  if p_label not in ('home','work','other')
     or length(btrim(coalesce(p_recipient_name,''))) not between 2 and 120
     or length(btrim(coalesce(p_address_line,''))) not between 5 and 500
     or (p_landmark is not null and length(p_landmark)>160)
     or coalesce(p_pincode,'') !~ '^[0-9]{6}$'
     or length(btrim(coalesce(p_district,''))) not between 2 and 100
     or length(btrim(coalesce(p_state,''))) not between 2 and 100
     or ((p_location_lat is null) <> (p_location_lng is null))
     or (p_location_lat is not null and p_location_lat not between -90 and 90)
     or (p_location_lng is not null and p_location_lng not between -180 and 180) then
    raise exception 'INVALID_ADDRESS_FIELDS' using errcode='22023';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text, 0));
  select count(*) into v_count from public.srk_customer_saved_addresses a where a.user_id=v_user_id;
  if p_id is null and v_count >= 10 then
    raise exception 'ADDRESS_LIMIT_REACHED' using errcode='22023';
  end if;

  if p_id is not null and not exists (
    select 1 from public.srk_customer_saved_addresses a where a.id=p_id and a.user_id=v_user_id
  ) then raise exception 'ADDRESS_NOT_FOUND' using errcode='P0002'; end if;

  if coalesce(p_is_default,false) then
    update public.srk_customer_saved_addresses set is_default=false,updated_at=now()
    where user_id=v_user_id and is_default=true and (p_id is null or id<>p_id);
  end if;

  if p_id is null then
    insert into public.srk_customer_saved_addresses(
      user_id,label,recipient_name,address_line,landmark,pincode,district,state,
      location_lat,location_lng,is_default
    ) values (
      v_user_id,p_label,btrim(p_recipient_name),btrim(p_address_line),nullif(btrim(p_landmark),''),
      p_pincode,btrim(p_district),btrim(p_state),p_location_lat,p_location_lng,coalesce(p_is_default,false)
    ) returning id into v_id;
  else
    update public.srk_customer_saved_addresses set
      label=p_label,recipient_name=btrim(p_recipient_name),address_line=btrim(p_address_line),
      landmark=nullif(btrim(p_landmark),''),pincode=p_pincode,district=btrim(p_district),
      state=btrim(p_state),location_lat=p_location_lat,location_lng=p_location_lng,
      is_default=coalesce(p_is_default,is_default),updated_at=now()
    where id=p_id and user_id=v_user_id;
  end if;
  return v_id;
end;
$function$;

create or replace function public.srk_customer_delete_my_saved_address(p_id uuid)
returns boolean
language plpgsql security definer set search_path = ''
as $function$
declare v_user_id uuid := auth.uid(); v_deleted integer;
begin
  if v_user_id is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='28000'; end if;
  delete from public.srk_customer_saved_addresses where id=p_id and user_id=v_user_id;
  get diagnostics v_deleted = row_count;
  return v_deleted=1;
end;
$function$;

revoke all on function public.srk_customer_list_my_saved_addresses() from public,anon;
grant execute on function public.srk_customer_list_my_saved_addresses() to authenticated;
revoke all on function public.srk_customer_save_my_address(uuid,text,text,text,text,text,text,text,double precision,double precision,boolean) from public,anon;
grant execute on function public.srk_customer_save_my_address(uuid,text,text,text,text,text,text,text,double precision,double precision,boolean) to authenticated;
revoke all on function public.srk_customer_delete_my_saved_address(uuid) from public,anon;
grant execute on function public.srk_customer_delete_my_saved_address(uuid) to authenticated;
