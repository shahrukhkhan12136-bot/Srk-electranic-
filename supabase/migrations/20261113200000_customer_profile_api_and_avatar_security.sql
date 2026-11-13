-- Customer profile foundation: verified phone is read-only; editable fields are app-owned.
-- Source-only migration. No live project changes are made by committing this file.

create table if not exists public.srk_customer_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '' check (length(full_name) <= 120),
  avatar_path text,
  preferred_language text not null default 'hi' check (preferred_language in ('hi','en')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint srk_customer_avatar_path_safe check (
    avatar_path is null or (
      length(avatar_path) <= 500
      and left(avatar_path, length(user_id::text || '/')) = user_id::text || '/'
    )
  )
);

alter table public.srk_customer_profiles enable row level security;
revoke all on public.srk_customer_profiles from anon, authenticated;

create policy "customers read own profile"
on public.srk_customer_profiles for select to authenticated
using ((select auth.uid()) = user_id);

create policy "customers create own profile"
on public.srk_customer_profiles for insert to authenticated
with check ((select auth.uid()) = user_id);

create policy "customers update own profile"
on public.srk_customer_profiles for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create or replace function public.srk_customer_get_my_profile()
returns table (
  user_id uuid,
  full_name text,
  verified_phone text,
  phone_verified boolean,
  avatar_path text,
  preferred_language text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode = '28000';
  end if;
  return query
    select p.user_id, p.full_name, u.phone,
           (u.phone_confirmed_at is not null),
           p.avatar_path, p.preferred_language, p.created_at, p.updated_at
    from public.srk_customer_profiles p
    join auth.users u on u.id=p.user_id
    where p.user_id=v_user_id;
end;
$function$;

create or replace function public.srk_customer_update_my_profile(
  p_full_name text,
  p_preferred_language text default 'hi',
  p_avatar_path text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_name text := btrim(coalesce(p_full_name,''));
  v_lang text := coalesce(p_preferred_language,'hi');
begin
  if v_user_id is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode = '28000';
  end if;
  if length(v_name) < 2 or length(v_name) > 120
     or v_lang not in ('hi','en') then
    raise exception 'INVALID_PROFILE_FIELDS' using errcode = '22023';
  end if;
  if p_avatar_path is not null and (
    length(p_avatar_path)>500
    or left(p_avatar_path,length(v_user_id::text || '/')) <> v_user_id::text || '/'
  ) then
    raise exception 'INVALID_AVATAR_PATH' using errcode = '22023';
  end if;

  if p_avatar_path is not null and not exists (
    select 1 from storage.objects o
    where o.bucket_id='srk-customer-avatars'
      and o.name=p_avatar_path
      and (storage.foldername(o.name))[1]=v_user_id::text
  ) then
    raise exception 'AVATAR_NOT_FOUND' using errcode = '22023';
  end if;

  insert into public.srk_customer_profiles(user_id,full_name,preferred_language,avatar_path,updated_at)
  values(v_user_id,v_name,v_lang,p_avatar_path,now())
  on conflict(user_id) do update
    set full_name=excluded.full_name,
        preferred_language=excluded.preferred_language,
        avatar_path=coalesce(excluded.avatar_path,public.srk_customer_profiles.avatar_path),
        updated_at=now();

  return jsonb_build_object('success',true);
end;
$function$;

revoke all on function public.srk_customer_get_my_profile() from public, anon;
grant execute on function public.srk_customer_get_my_profile() to authenticated;
revoke all on function public.srk_customer_update_my_profile(text,text,text) from public, anon;
grant execute on function public.srk_customer_update_my_profile(text,text,text) to authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('srk-customer-avatars','srk-customer-avatars',false,5242880,
       array['image/jpeg','image/png','image/webp']::text[])
on conflict(id) do update set public=false,file_size_limit=5242880,
  allowed_mime_types=excluded.allowed_mime_types;

create policy "customers upload own avatar"
on storage.objects for insert to authenticated
with check (
  bucket_id='srk-customer-avatars'
  and (storage.foldername(name))[1]=(select auth.uid())::text
);

create policy "customers read own avatar"
on storage.objects for select to authenticated
using (
  bucket_id='srk-customer-avatars'
  and (storage.foldername(name))[1]=(select auth.uid())::text
);

create policy "customers update own avatar"
on storage.objects for update to authenticated
using (
  bucket_id='srk-customer-avatars'
  and (storage.foldername(name))[1]=(select auth.uid())::text
)
with check (
  bucket_id='srk-customer-avatars'
  and (storage.foldername(name))[1]=(select auth.uid())::text
);

create policy "customers delete own avatar"
on storage.objects for delete to authenticated
using (
  bucket_id='srk-customer-avatars'
  and (storage.foldername(name))[1]=(select auth.uid())::text
);
