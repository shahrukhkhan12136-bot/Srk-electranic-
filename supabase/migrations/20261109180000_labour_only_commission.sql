-- SRK ELECTRONIC: commission applies to electrician labour only.
-- Material and miscellaneous charges are excluded from the 15% commission base.
-- Additive schema change; no existing booking rows or payment statuses are modified.

alter table public.service_bookings
  add column if not exists labor_amount numeric(12,2),
  add column if not exists material_amount numeric(12,2),
  add column if not exists other_amount numeric(12,2);

alter table public.service_bookings
  drop constraint if exists service_bookings_quote_components_nonnegative_check;
alter table public.service_bookings
  add constraint service_bookings_quote_components_nonnegative_check
  check (
    (labor_amount is null or labor_amount >= 0)
    and (material_amount is null or material_amount >= 0)
    and (other_amount is null or other_amount >= 0)
  );

comment on column public.service_bookings.labor_amount is
  'Itemized electrician labour/service fee. Only this amount is commissionable.';
comment on column public.service_bookings.material_amount is
  'Itemized materials/parts cost. Never commissionable.';
comment on column public.service_bookings.other_amount is
  'Itemized miscellaneous charges. Not commissionable unless a future explicit policy says otherwise.';

-- Electrician remittance validation: calculate commission only from labour.
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
declare
  v_uid uuid:=auth.uid(); v_profile_id uuid; v_id uuid; v_profile_count integer; v_due numeric; v_verified numeric; v_submitted numeric;
begin
  if v_uid is null then raise exception 'Authentication required' using errcode='42501'; end if;
  if p_amount is null or p_amount<=0 or p_amount>10000000 then raise exception 'Invalid remittance amount'; end if;
  if length(trim(coalesce(p_payment_reference,''))) not between 4 and 120 then raise exception 'Valid payment reference required'; end if;
  select count(*) into v_profile_count from public.electrician_profiles
  where (auth_user_id=v_uid or user_id=v_uid) and verification_status='approved';
  if v_profile_count <> 1 then raise exception 'Exactly one approved electrician profile must be linked to this account' using errcode='42501'; end if;
  select id into v_profile_id from public.electrician_profiles
  where (auth_user_id=v_uid or user_id=v_uid) and verification_status='approved' for update;
  select coalesce(sum(round(coalesce(labor_amount,0)*coalesce(commission_rate,15)/100,2)),0)
    into v_due from public.service_bookings
    where assigned_electrician_id=v_profile_id and status='completed' and payment_status='paid';
  select coalesce(sum(amount),0) into v_verified from public.srk_commission_remittances
    where electrician_profile_id=v_profile_id and status='verified';
  select coalesce(sum(amount),0) into v_submitted from public.srk_commission_remittances
    where electrician_profile_id=v_profile_id and status='submitted';
  if round(p_amount,2) > greatest(0,round(v_due-v_verified-v_submitted,2)) then
    raise exception 'Remittance exceeds the currently outstanding labour commission balance';
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
declare v_uid uuid:=auth.uid(); v_profile_id uuid; v_profile_count integer; v_due numeric; v_verified numeric; v_submitted numeric;
begin
  if v_uid is null then raise exception 'Authentication required' using errcode='42501'; end if;
  select count(*) into v_profile_count from public.electrician_profiles
  where (auth_user_id=v_uid or user_id=v_uid) and verification_status='approved';
  if v_profile_count <> 1 then
    raise exception 'Exactly one approved electrician profile must be linked to this account' using errcode='42501';
  end if;
  select id into v_profile_id from public.electrician_profiles
  where (auth_user_id=v_uid or user_id=v_uid) and verification_status='approved';
  select coalesce(sum(round(coalesce(labor_amount,0)*coalesce(commission_rate,15)/100,2)),0)
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

create or replace function public.srk_admin_direct_upi_commission_overview()
returns table (
  electrician_profile_id uuid,
  electrician_name text,
  commission_due numeric,
  verified_remitted numeric,
  pending_review numeric,
  outstanding numeric
)
language plpgsql
stable
security definer
set search_path to 'pg_catalog','public','auth','pg_temp'
as $function$
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'Admin access required' using errcode='42501';
  end if;
  return query
  with due as (
    select b.assigned_electrician_id as profile_id,
      round(coalesce(sum(round(coalesce(b.labor_amount,0)*coalesce(b.commission_rate,15)/100,2)),0),2) as total_due
    from public.service_bookings b
    where b.status='completed' and b.payment_status='paid'
      and b.assigned_electrician_id is not null
    group by b.assigned_electrician_id
  ), remitted as (
    select r.electrician_profile_id as profile_id,
      round(coalesce(sum(r.amount) filter (where r.status='verified'),0),2) as verified,
      round(coalesce(sum(r.amount) filter (where r.status='submitted'),0),2) as pending
    from public.srk_commission_remittances r
    group by r.electrician_profile_id
  )
  select ep.id, ep.display_name,
    coalesce(d.total_due,0), coalesce(r.verified,0), coalesce(r.pending,0),
    greatest(0,round(coalesce(d.total_due,0)-coalesce(r.verified,0)-coalesce(r.pending,0),2))
  from public.electrician_profiles ep
  left join due d on d.profile_id=ep.id
  left join remitted r on r.profile_id=ep.id
  where coalesce(d.total_due,0)>0 or coalesce(r.verified,0)>0 or coalesce(r.pending,0)>0
  order by ep.display_name;
end;
$function$;

create or replace function public.srk_get_my_earnings()
returns table (
  booking_id uuid,
  service_type text,
  booking_created_at timestamptz,
  booking_status text,
  payment_status text,
  amount_received numeric,
  commission_amount numeric,
  electrician_earning numeric
)
language sql
stable
security definer
set search_path to 'pg_catalog','public','auth','pg_temp'
as $function$
  select b.id,
         b.service_type,
         b.created_at,
         b.status,
         b.payment_status,
         coalesce(b.amount_paid,0)::numeric,
         round(coalesce(b.labor_amount,0)*coalesce(b.commission_rate,15)/100,2)::numeric,
         case when b.status='completed' and b.payment_status='paid'
              then greatest(coalesce(b.amount_paid,0) -
                round(coalesce(b.labor_amount,0)*coalesce(b.commission_rate,15)/100,2),0)
              else 0 end::numeric
  from public.electrician_profiles p
  join public.service_bookings b on b.assigned_electrician_id=p.id
  where (p.user_id=auth.uid() or p.auth_user_id=auth.uid())
    and p.verification_status='approved'
  order by b.created_at desc
  limit 200;
$function$;

create or replace function public.srk_admin_commission_report()
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth','pg_temp'
as $function$
declare
  v_result jsonb;
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'Admin access required' using errcode='42501';
  end if;

  with paid_completed as (
    select assigned_electrician_id,
           coalesce(amount_paid,0)::numeric as gross,
           round(coalesce(labor_amount,0)*coalesce(commission_rate,15)/100,2)::numeric as commission
    from public.service_bookings
    where status='completed' and payment_status='paid'
  ),
  totals as (
    select coalesce(sum(gross),0)::numeric as collected,
           coalesce(sum(commission),0)::numeric as commission,
           coalesce(sum(gross-commission),0)::numeric as payable
    from paid_completed
  ),
  partners as (
    select p.id as electrician_id,
           p.display_name,
           count(pc.*)::integer as paid_completed_jobs,
           coalesce(sum(pc.gross),0)::numeric as gross_received,
           coalesce(sum(pc.commission),0)::numeric as company_commission,
           coalesce(sum(pc.gross-pc.commission),0)::numeric as electrician_earning
    from public.electrician_profiles p
    left join paid_completed pc on pc.assigned_electrician_id=p.id
    group by p.id,p.display_name
    order by p.display_name
  )
  select jsonb_build_object(
    'total_collected',t.collected,
    'total_commission',t.commission,
    'total_electrician_payable',t.payable,
    'partners',coalesce((select jsonb_agg(to_jsonb(partners)) from partners),'[]'::jsonb)
  ) into v_result
  from totals t;
  return v_result;
end;
$function$;

revoke all on function public.srk_submit_my_commission_remittance(numeric,text,date) from public,anon;
revoke all on function public.srk_get_my_commission_balance() from public,anon;
revoke all on function public.srk_admin_direct_upi_commission_overview() from public,anon;
revoke all on function public.srk_get_my_earnings() from public,anon;
revoke all on function public.srk_admin_commission_report() from public,anon;
grant execute on function public.srk_submit_my_commission_remittance(numeric,text,date) to authenticated;
grant execute on function public.srk_get_my_commission_balance() to authenticated;
grant execute on function public.srk_admin_direct_upi_commission_overview() to authenticated;
grant execute on function public.srk_get_my_earnings() to authenticated;
grant execute on function public.srk_admin_commission_report() to authenticated;
