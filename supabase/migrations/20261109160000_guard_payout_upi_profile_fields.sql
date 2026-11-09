-- Protect electrician payout identity and admin review fields from direct client updates.
-- Existing authenticated UPDATE grants on electrician_profiles are retained for the app's other profile fields.
-- Only SECURITY DEFINER RPCs owned by postgres (or service_role maintenance) may change these fields.

create or replace function public.srk_guard_electrician_payout_upi_fields()
returns trigger
language plpgsql
set search_path to 'pg_catalog','public','pg_temp'
as $function$
begin
  if current_user not in ('postgres','service_role') and (
    new.payout_upi_id is distinct from old.payout_upi_id
    or new.payout_upi_status is distinct from old.payout_upi_status
    or new.payout_upi_submitted_at is distinct from old.payout_upi_submitted_at
    or new.payout_upi_reviewed_at is distinct from old.payout_upi_reviewed_at
    or new.payout_upi_reviewed_by is distinct from old.payout_upi_reviewed_by
    or new.payout_upi_review_note is distinct from old.payout_upi_review_note
  ) then
    raise exception 'Payout UPI details can only be changed through the approved SRK workflow'
      using errcode='42501';
  end if;
  return new;
end;
$function$;

drop trigger if exists srk_guard_electrician_payout_upi_fields on public.electrician_profiles;
create trigger srk_guard_electrician_payout_upi_fields
before update on public.electrician_profiles
for each row execute function public.srk_guard_electrician_payout_upi_fields();

revoke all on function public.srk_guard_electrician_payout_upi_fields() from public,anon,authenticated;
