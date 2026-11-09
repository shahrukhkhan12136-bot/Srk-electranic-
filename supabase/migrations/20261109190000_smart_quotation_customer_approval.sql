-- SRK ELECTRONIC: auditable itemized electrician quotations with customer approval.
-- Labour alone is commissionable; materials and other charges are excluded.
create table if not exists public.srk_booking_quotes (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.service_bookings(id) on delete restrict,
  electrician_profile_id uuid not null references public.electrician_profiles(id) on delete restrict,
  quote_version integer not null check (quote_version > 0),
  labor_amount numeric(12,2) not null check (labor_amount >= 0),
  material_amount numeric(12,2) not null default 0 check (material_amount >= 0),
  other_amount numeric(12,2) not null default 0 check (other_amount >= 0),
  total_amount numeric(12,2) not null check (total_amount >= 0),
  work_notes text,
  estimated_duration text,
  status text not null default 'pending_customer'
    check (status in ('pending_customer','accepted','rejected','superseded')),
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references auth.users(id) on delete restrict,
  unique (booking_id, quote_version),
  check (total_amount = labor_amount + material_amount + other_amount)
);
create index if not exists srk_booking_quotes_booking_version_idx
  on public.srk_booking_quotes(booking_id, quote_version desc);
create unique index if not exists srk_booking_quotes_one_pending_idx
  on public.srk_booking_quotes(booking_id) where status='pending_customer';
alter table public.srk_booking_quotes enable row level security;
revoke all on public.srk_booking_quotes from anon, authenticated;
grant select on public.srk_booking_quotes to authenticated;
drop policy if exists srk_booking_quotes_participant_read on public.srk_booking_quotes;
create policy srk_booking_quotes_participant_read on public.srk_booking_quotes
for select to authenticated using (
  exists (
    select 1 from public.service_bookings b
    where b.id=booking_id
      and (b.customer_user_id=auth.uid()
        or exists(select 1 from public.electrician_profiles ep
          where ep.id=b.assigned_electrician_id
            and (ep.user_id=auth.uid() or ep.auth_user_id=auth.uid()))
        or public.is_srk_admin())
  )
);

create or replace function public.srk_submit_booking_quote(
  p_booking_id uuid,
  p_labor_amount numeric,
  p_material_amount numeric default 0,
  p_other_amount numeric default 0,
  p_work_notes text default null,
  p_estimated_duration text default null
) returns jsonb
language plpgsql security definer
set search_path to 'pg_catalog','public','auth','pg_temp'
as $function$
declare
  v_uid uuid:=auth.uid();
  v_profile_id uuid;
  v_booking public.service_bookings%rowtype;
  v_version integer;
  v_total numeric(12,2);
  v_quote_id uuid;
begin
  if v_uid is null then raise exception 'Authentication required' using errcode='42501'; end if;
  if p_labor_amount is null or p_material_amount is null or p_other_amount is null
     or p_labor_amount<0 or p_material_amount<0 or p_other_amount<0
     or p_labor_amount>10000000 or p_material_amount>10000000 or p_other_amount>10000000 then
    raise exception 'Quote amounts must be valid non-negative amounts';
  end if;
  v_total:=round(p_labor_amount,2)+round(p_material_amount,2)+round(p_other_amount,2);
  if v_total>10000000 then raise exception 'Quote total is too high'; end if;

  select id into v_profile_id from public.electrician_profiles
  where (user_id=v_uid or auth_user_id=v_uid) and verification_status='approved' and active=true;
  if v_profile_id is null then raise exception 'Approved active electrician profile required' using errcode='42501'; end if;

  select * into v_booking from public.service_bookings where id=p_booking_id for update;
  if not found or v_booking.assigned_electrician_id is distinct from v_profile_id then
    raise exception 'This booking is not assigned to your electrician account' using errcode='42501';
  end if;
  if v_booking.status not in ('assigned','in_progress') then
    raise exception 'Quote can only be submitted for an assigned or in-progress booking';
  end if;
  if exists(select 1 from public.srk_booking_quotes where booking_id=p_booking_id and status='pending_customer') then
    raise exception 'A quote is already waiting for customer approval';
  end if;
  select coalesce(max(quote_version),0)+1 into v_version
    from public.srk_booking_quotes where booking_id=p_booking_id;
  insert into public.srk_booking_quotes(
    booking_id,electrician_profile_id,quote_version,labor_amount,material_amount,
    other_amount,total_amount,work_notes,estimated_duration
  ) values (
    p_booking_id,v_profile_id,v_version,round(p_labor_amount,2),
    round(p_material_amount,2),round(p_other_amount,2),v_total,
    nullif(left(trim(coalesce(p_work_notes,'')),1500),''),
    nullif(left(trim(coalesce(p_estimated_duration,'')),100),'')
  ) returning id into v_quote_id;
  return jsonb_build_object('success',true,'quote_id',v_quote_id,'quote_version',v_version,'total_amount',v_total,'status','pending_customer');
end;
$function$;

create or replace function public.srk_customer_review_booking_quote(
  p_quote_id uuid,
  p_decision text
) returns jsonb
language plpgsql security definer
set search_path to 'pg_catalog','public','auth','pg_temp'
as $function$
declare
  v_uid uuid:=auth.uid();
  v_quote public.srk_booking_quotes%rowtype;
  v_booking public.service_bookings%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required' using errcode='42501'; end if;
  if p_decision not in ('accepted','rejected') then raise exception 'Decision must be accepted or rejected'; end if;
  select * into v_quote from public.srk_booking_quotes where id=p_quote_id;
  if not found then raise exception 'Quote not found'; end if;
  select * into v_booking from public.service_bookings where id=v_quote.booking_id for update;
  if v_booking.customer_user_id is distinct from v_uid then
    raise exception 'Only the booking customer can review this quote' using errcode='42501';
  end if;
  select * into v_quote from public.srk_booking_quotes where id=p_quote_id and status='pending_customer' for update;
  if not found then raise exception 'This quote is no longer awaiting approval'; end if;
  if p_decision='accepted' then
    update public.service_bookings
      set quoted_amount=v_quote.total_amount,
          labor_amount=v_quote.labor_amount,
          material_amount=v_quote.material_amount,
          other_amount=v_quote.other_amount
      where id=v_quote.booking_id;
  end if;
  update public.srk_booking_quotes
    set status=p_decision,reviewed_at=now(),reviewed_by=v_uid
    where id=p_quote_id and status='pending_customer';
  return jsonb_build_object('success',true,'status',p_decision,'total_amount',v_quote.total_amount);
end;
$function$;

create or replace function public.srk_get_my_booking_quotes(p_booking_id uuid)
returns table (
  quote_id uuid, quote_version integer, labor_amount numeric, material_amount numeric,
  other_amount numeric, total_amount numeric, work_notes text, estimated_duration text,
  quote_status text, submitted_at timestamptz, reviewed_at timestamptz
)
language plpgsql stable security definer
set search_path to 'pg_catalog','public','auth','pg_temp'
as $function$
declare v_uid uuid:=auth.uid();
begin
  if v_uid is null then raise exception 'Authentication required' using errcode='42501'; end if;
  if not exists (
    select 1 from public.service_bookings b
    where b.id=p_booking_id and (
      b.customer_user_id=v_uid
      or exists(select 1 from public.electrician_profiles ep
        where ep.id=b.assigned_electrician_id and (ep.user_id=v_uid or ep.auth_user_id=v_uid))
      or public.is_srk_admin()
    )
  ) then raise exception 'Booking access denied' using errcode='42501'; end if;
  return query
  select q.id,q.quote_version,q.labor_amount,q.material_amount,q.other_amount,
    q.total_amount,q.work_notes,q.estimated_duration,q.status,q.submitted_at,q.reviewed_at
  from public.srk_booking_quotes q
  where q.booking_id=p_booking_id
  order by q.quote_version desc;
end;
$function$;

revoke all on function public.srk_submit_booking_quote(uuid,numeric,numeric,numeric,text,text) from public,anon;
revoke all on function public.srk_customer_review_booking_quote(uuid,text) from public,anon;
revoke all on function public.srk_get_my_booking_quotes(uuid) from public,anon;
grant execute on function public.srk_submit_booking_quote(uuid,numeric,numeric,numeric,text,text) to authenticated;
grant execute on function public.srk_customer_review_booking_quote(uuid,text) to authenticated;
grant execute on function public.srk_get_my_booking_quotes(uuid) to authenticated;
