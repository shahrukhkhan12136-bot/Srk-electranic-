-- SRK ELECTRONIC: verified electrician UPI + manual commission remittance foundation
-- Additive only. Apply to the primary Supabase project only after branch review and tests.
-- Direct UPI reports never set service_bookings.payment_status='paid'.

alter table public.electrician_profiles
  add column if not exists payout_upi_id text,
  add column if not exists payout_upi_status text not null default 'not_submitted',
  add column if not exists payout_upi_submitted_at timestamptz,
  add column if not exists payout_upi_reviewed_at timestamptz,
  add column if not exists payout_upi_reviewed_by uuid,
  add column if not exists payout_upi_review_note text;

alter table public.electrician_profiles
  drop constraint if exists electrician_profiles_payout_upi_status_check;
alter table public.electrician_profiles
  add constraint electrician_profiles_payout_upi_status_check
  check (payout_upi_status in ('not_submitted','pending','verified','rejected'));

alter table public.electrician_profiles
  drop constraint if exists electrician_profiles_payout_upi_format_check;
alter table public.electrician_profiles
  add constraint electrician_profiles_payout_upi_format_check
  check (payout_upi_id is null or payout_upi_id ~* '^[a-z0-9][a-z0-9._-]{1,255}@[a-z][a-z0-9]{1,63}$');

create table if not exists public.srk_commission_remittances (
  id uuid primary key default gen_random_uuid(),
  electrician_profile_id uuid not null references public.electrician_profiles(id) on delete restrict,
  submitted_by uuid not null references auth.users(id) on delete restrict,
  amount numeric(12,2) not null check (amount > 0),
  payment_reference text not null check (length(trim(payment_reference)) between 4 and 120),
  payment_date date not null default current_date,
  status text not null default 'submitted'
    check (status in ('submitted','verified','rejected')),
  admin_note text,
  reviewed_by uuid references auth.users(id) on delete restrict,
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists srk_commission_remittances_partner_status_idx
  on public.srk_commission_remittances(electrician_profile_id,status,created_at desc);

alter table public.srk_commission_remittances enable row level security;
revoke all on public.srk_commission_remittances from anon, authenticated;
grant select on public.srk_commission_remittances to authenticated;

drop policy if exists srk_commission_remittances_owner_or_admin_read
  on public.srk_commission_remittances;
create policy srk_commission_remittances_owner_or_admin_read
  on public.srk_commission_remittances
  for select to authenticated
  using (
    submitted_by = (select auth.uid())
    or (select public.is_srk_admin())
  );

create or replace function public.srk_submit_my_payout_upi(p_upi_id text)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth','pg_temp'
as $function$
declare
  v_uid uuid := auth.uid();
  v_profile_id uuid;
  v_profile_count integer;
  v_upi text := lower(trim(coalesce(p_upi_id,'')));
begin
  if v_uid is null then raise exception 'Authentication required' using errcode='42501'; end if;
  if v_upi !~ '^[a-z0-9][a-z0-9._-]{1,255}@[a-z][a-z0-9]{1,63}$' then
    raise exception 'Invalid UPI ID format';
  end if;
  select count(*) into v_profile_count
  from public.electrician_profiles
  where (auth_user_id=v_uid or user_id=v_uid)
    and verification_status='approved';
  if v_profile_count <> 1 then
    raise exception 'Exactly one approved electrician profile must be linked to this account' using errcode='42501';
  end if;
  select id into v_profile_id
  from public.electrician_profiles
  where (auth_user_id=v_uid or user_id=v_uid)
    and verification_status='approved'
  for update;
  update public.electrician_profiles
  set payout_upi_id=v_upi,
      payout_upi_status='pending',
      payout_upi_submitted_at=now(),
      payout_upi_reviewed_at=null,
      payout_upi_reviewed_by=null,
      payout_upi_review_note=null
  where id=v_profile_id;
  return jsonb_build_object('success',true,'status','pending');
end;
$function$;

create or replace function public.srk_admin_review_payout_upi(
  p_electrician_profile_id uuid,
  p_decision text,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth','pg_temp'
as $function$
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'Admin access required' using errcode='42501';
  end if;
  if p_decision not in ('verified','rejected') then raise exception 'Invalid decision'; end if;
  update public.electrician_profiles
  set payout_upi_status=p_decision,
      payout_upi_reviewed_at=now(),
      payout_upi_reviewed_by=auth.uid(),
      payout_upi_review_note=nullif(left(trim(coalesce(p_note,'')),500),'')
  where id=p_electrician_profile_id
    and payout_upi_status='pending'
    and payout_upi_id is not null;
  if not found then raise exception 'Pending UPI submission not found'; end if;
  return jsonb_build_object('success',true,'status',p_decision);
end;
$function$;

create or replace function public.srk_get_assigned_booking_verified_upi(p_booking_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'pg_catalog','public','auth','pg_temp'
as $function$
declare v_result jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
  select jsonb_build_object(
    'upi_id',ep.payout_upi_id,
    'electrician_name',ep.display_name,
    'upi_status','verified'
  ) into v_result
  from public.service_bookings b
  join public.electrician_profiles ep on ep.id=b.assigned_electrician_id
  where b.id=p_booking_id
    and b.customer_user_id=auth.uid()
    and b.assigned_electrician_id is not null
    and ep.payout_upi_status='verified'
    and ep.payout_upi_id is not null;
  return v_result;
end;
$function$;

create or replace function public.srk_submit_my_commission_remittance(
  p_amount numeric,
  p_payment_reference text,
  p_payment_date date default current_date
)
returns uuid
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth','pg_temp'
as $function$
declare v_uid uuid:=auth.uid(); v_profile_id uuid; v_id uuid; v_profile_count integer; v_due numeric; v_verified numeric; v_submitted numeric;
begin
  if v_uid is null then raise exception 'Authentication required' using errcode='42501'; end if;
  if p_amount is null or p_amount<=0 or p_amount>10000000 then raise exception 'Invalid remittance amount'; end if;
  if length(trim(coalesce(p_payment_reference,''))) not between 4 and 120 then raise exception 'Valid payment reference required'; end if;
  select count(*) into v_profile_count from public.electrician_profiles
  where (auth_user_id=v_uid or user_id=v_uid) and verification_status='approved';
  if v_profile_count <> 1 then raise exception 'Exactly one approved electrician profile must be linked to this account' using errcode='42501'; end if;
  select id into v_profile_id from public.electrician_profiles
  where (auth_user_id=v_uid or user_id=v_uid) and verification_status='approved' for update;
  select coalesce(sum(coalesce(commission_amount,round(amount_paid*commission_rate/100,2))),0)
    into v_due from public.service_bookings
    where assigned_electrician_id=v_profile_id and status='completed' and payment_status='paid';
  select coalesce(sum(amount),0) into v_verified from public.srk_commission_remittances
    where electrician_profile_id=v_profile_id and status='verified';
  select coalesce(sum(amount),0) into v_submitted from public.srk_commission_remittances
    where electrician_profile_id=v_profile_id and status='submitted';
  if round(p_amount,2) > greatest(0,round(v_due-v_verified-v_submitted,2)) then
    raise exception 'Remittance exceeds the currently outstanding commission balance';
  end if;
  insert into public.srk_commission_remittances(electrician_profile_id,submitted_by,amount,payment_reference,payment_date)
  values(v_profile_id,v_uid,round(p_amount,2),trim(p_payment_reference),coalesce(p_payment_date,current_date))
  returning id into v_id;
  return v_id;
end;
$function$;

create or replace function public.srk_get_my_commission_balance()
returns jsonb
language plpgsql
stable
security definer
set search_path to 'pg_catalog','public','auth','pg_temp'
as $function$
declare v_uid uuid:=auth.uid(); v_profile_id uuid; v_due numeric; v_verified numeric; v_submitted numeric;
begin
  if v_uid is null then raise exception 'Authentication required' using errcode='42501'; end if;
  select id into v_profile_id from public.electrician_profiles
  where (auth_user_id=v_uid or user_id=v_uid) and verification_status='approved'
  order by created_at desc limit 1;
  if v_profile_id is null then raise exception 'Approved electrician profile required' using errcode='42501'; end if;
  select coalesce(sum(coalesce(commission_amount,round(amount_paid*commission_rate/100,2))),0)
    into v_due from public.service_bookings
    where assigned_electrician_id=v_profile_id and status='completed' and payment_status='paid';
  select coalesce(sum(amount),0) into v_verified from public.srk_commission_remittances
    where electrician_profile_id=v_profile_id and status='verified';
  select coalesce(sum(amount),0) into v_submitted from public.srk_commission_remittances
    where electrician_profile_id=v_profile_id and status='submitted';
  return jsonb_build_object('commission_due',round(v_due,2),'verified_remitted',round(v_verified,2),
    'pending_review',round(v_submitted,2),'outstanding',greatest(0,round(v_due-v_verified-v_submitted,2)));
end;
$function$;

create or replace function public.srk_admin_review_commission_remittance(
  p_remittance_id uuid,
  p_decision text,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth','pg_temp'
as $function$
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'Admin access required' using errcode='42501';
  end if;
  if p_decision not in ('verified','rejected') then raise exception 'Invalid decision'; end if;
  update public.srk_commission_remittances
  set status=p_decision,admin_note=nullif(left(trim(coalesce(p_note,'')),500),''),
      reviewed_by=auth.uid(),reviewed_at=now()
  where id=p_remittance_id and status='submitted';
  if not found then raise exception 'Submitted remittance not found'; end if;
  return jsonb_build_object('success',true,'status',p_decision);
end;
$function$;

revoke all on function public.srk_submit_my_payout_upi(text) from public,anon;
revoke all on function public.srk_admin_review_payout_upi(uuid,text,text) from public,anon;
revoke all on function public.srk_get_assigned_booking_verified_upi(uuid) from public,anon;
revoke all on function public.srk_submit_my_commission_remittance(numeric,text,date) from public,anon;
revoke all on function public.srk_admin_review_commission_remittance(uuid,text,text) from public,anon;
revoke all on function public.srk_get_my_commission_balance() from public,anon;
grant execute on function public.srk_submit_my_payout_upi(text) to authenticated;
grant execute on function public.srk_admin_review_payout_upi(uuid,text,text) to authenticated;
grant execute on function public.srk_get_assigned_booking_verified_upi(uuid) to authenticated;
grant execute on function public.srk_submit_my_commission_remittance(numeric,text,date) to authenticated;
grant execute on function public.srk_admin_review_commission_remittance(uuid,text,text) to authenticated;
grant execute on function public.srk_get_my_commission_balance() to authenticated;
