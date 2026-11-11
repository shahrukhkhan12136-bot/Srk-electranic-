-- Permanent, server-issued readable electrician IDs.
-- Issuance requires an approved + active profile linked to an Auth account.
-- This migration is feature-branch work only; do not apply to Production until the
-- documented migration-parity/release gates are resolved and owner authorizes release.

create sequence if not exists public.electrician_display_id_seq
  as bigint
  start with 1
  increment by 1
  no minvalue
  no maxvalue
  no cycle;

alter table public.electrician_profiles
  add column if not exists electrician_display_id text;

create unique index if not exists electrician_profiles_display_id_uidx
  on public.electrician_profiles (electrician_display_id)
  where electrician_display_id is not null;

create or replace function public.srk_assign_electrician_display_id()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_next_id bigint;
begin
  -- Once issued, the readable ID is immutable even if profile status changes.
  if tg_op = 'UPDATE' and old.electrician_display_id is not null then
    if new.electrician_display_id is distinct from old.electrician_display_id then
      raise exception using
        errcode = '22000',
        message = 'Electrician display ID is permanent and cannot be changed';
    end if;
    new.electrician_display_id := old.electrician_display_id;
    return new;
  end if;

  -- Never accept an ID supplied by a browser, app, or external caller.
  if new.electrician_display_id is not null then
    raise exception using
      errcode = '22000',
      message = 'Electrician display ID is generated only by the server';
  end if;

  -- A single Auth identity must not be ambiguously linked to another profile
  -- through either legacy user_id or auth_user_id column.
  if exists (
    select 1
      from public.electrician_profiles p
     where p.id is distinct from new.id
       and (
         (new.user_id is not null and
           (p.user_id = new.user_id or p.auth_user_id = new.user_id))
         or
         (new.auth_user_id is not null and
           (p.user_id = new.auth_user_id or p.auth_user_id = new.auth_user_id))
       )
  ) then
    return new;
  end if;

  -- Do not issue an ID for pending, rejected, suspended, inactive, or unlinked profiles.
  if new.verification_status = 'approved'
     and new.active is true
     and (new.user_id is not null or new.auth_user_id is not null)
     and (new.user_id is null or new.auth_user_id is null or new.user_id = new.auth_user_id) then
    v_next_id := pg_catalog.nextval('public.electrician_display_id_seq'::pg_catalog.regclass);
    new.electrician_display_id :=
      'SRK-EL-' ||
      pg_catalog.lpad(
        v_next_id::text,
        greatest(6, pg_catalog.length(v_next_id::text)),
        '0'
      );
  end if;

  return new;
end;
$function$;

revoke all on function public.srk_assign_electrician_display_id() from public;
revoke all on function public.srk_assign_electrician_display_id() from anon;
revoke all on function public.srk_assign_electrician_display_id() from authenticated;
revoke all on sequence public.electrician_display_id_seq from public, anon, authenticated;

drop trigger if exists srk_assign_electrician_display_id_trigger on public.electrician_profiles;
create trigger srk_assign_electrician_display_id_trigger
before insert or update of verification_status, active, user_id, auth_user_id, electrician_display_id
on public.electrician_profiles
for each row
execute function public.srk_assign_electrician_display_id();

-- Backfill only profiles already approved, active, and linked unambiguously to an Auth account.
-- The same trigger applies the same issuance rule; inactive/unapproved rows remain blank.
update public.electrician_profiles
   set electrician_display_id = null
 where verification_status = 'approved'
   and active is true
   and (user_id is not null or auth_user_id is not null)
   and (user_id is null or auth_user_id is null or user_id = auth_user_id)
   and electrician_display_id is null;

comment on column public.electrician_profiles.electrician_display_id is
  'Permanent server-issued display ID (SRK-EL-000001 format); not an authentication credential.';
