-- Customer-reported direct UPI payment; never trust a report as proof.
create table if not exists public.srk_customer_upi_payment_reports (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.service_bookings(id) on delete restrict,
  customer_user_id uuid not null references auth.users(id) on delete restrict,
  amount numeric(12,2) not null check (amount > 0 and amount <= 10000000),
  payment_reference text not null check (length(trim(payment_reference)) between 4 and 120),
  payment_date date not null default current_date,
  status text not null default 'submitted' check (status in ('submitted','verified','rejected')),
  admin_note text,
  reviewed_by uuid references auth.users(id) on delete restrict,
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists srk_customer_upi_reports_booking_status_idx
  on public.srk_customer_upi_payment_reports(booking_id,status,created_at desc);
create unique index if not exists srk_customer_upi_one_pending_per_booking_idx
  on public.srk_customer_upi_payment_reports(booking_id) where status='submitted';
alter table public.srk_customer_upi_payment_reports enable row level security;
revoke all on public.srk_customer_upi_payment_reports from anon,authenticated;
grant select on public.srk_customer_upi_payment_reports to authenticated;
drop policy if exists srk_customer_upi_reports_owner_admin_read on public.srk_customer_upi_payment_reports;
create policy srk_customer_upi_reports_owner_admin_read
  on public.srk_customer_upi_payment_reports for select to authenticated
  using (customer_user_id=(select auth.uid()) or (select public.is_srk_admin()));

create or replace function public.srk_submit_my_customer_upi_payment_report(
  p_booking_id uuid, p_amount numeric, p_payment_reference text, p_payment_date date default current_date
) returns uuid
language plpgsql security definer
set search_path to 'pg_catalog','public','auth','pg_temp'
as $function$
declare v_uid uuid:=auth.uid(); v_report_id uuid;
begin
  if v_uid is null then raise exception 'Authentication required' using errcode='42501'; end if;
  if p_amount is null or p_amount<=0 or p_amount>10000000 then raise exception 'Invalid payment amount'; end if;
  if length(trim(coalesce(p_payment_reference,''))) not between 4 and 120 then raise exception 'Valid UTR/reference required'; end if;
  perform 1 from public.service_bookings b
    join public.electrician_profiles ep on ep.id=b.assigned_electrician_id
    where b.id=p_booking_id and b.customer_user_id=v_uid
      and b.assigned_electrician_id is not null
      and b.payment_status <> 'paid'
      and b.quoted_amount is not null
      and round(p_amount,2)=round(b.quoted_amount,2)
      and ep.payout_upi_status='verified' and ep.payout_upi_id is not null
    for update of b;
  if not found then raise exception 'Booking unavailable, already paid, or electrician UPI is not verified'; end if;
  insert into public.srk_customer_upi_payment_reports
    (booking_id,customer_user_id,amount,payment_reference,payment_date)
  values (p_booking_id,v_uid,round(p_amount,2),trim(p_payment_reference),coalesce(p_payment_date,current_date))
  returning id into v_report_id;
  return v_report_id;
end;
$function$;

create or replace function public.srk_admin_review_customer_upi_payment_report(
  p_report_id uuid, p_decision text, p_note text default null
) returns jsonb
language plpgsql security definer
set search_path to 'pg_catalog','public','auth','pg_temp'
as $function$
declare v_booking_id uuid; v_amount numeric; v_status text;
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'Admin access required' using errcode='42501';
  end if;
  if p_decision not in ('verified','rejected') then raise exception 'Invalid decision'; end if;
  select booking_id into v_booking_id from public.srk_customer_upi_payment_reports
    where id=p_report_id and status='submitted';
  if v_booking_id is null then raise exception 'Pending report not found'; end if;
  perform 1 from public.service_bookings where id=v_booking_id for update;
  select amount,status into v_amount,v_status from public.srk_customer_upi_payment_reports
    where id=p_report_id and status='submitted' for update;
  if not found then raise exception 'Pending report not found'; end if;
  if p_decision='verified' then
    update public.service_bookings
      set amount_paid=v_amount,payment_status='paid'
      where id=v_booking_id and payment_status <> 'paid';
    if not found then raise exception 'Booking already marked paid; reconcile manually'; end if;
  end if;
  update public.srk_customer_upi_payment_reports
    set status=p_decision,admin_note=nullif(left(trim(coalesce(p_note,'')),500),''),
        reviewed_by=auth.uid(),reviewed_at=now()
    where id=p_report_id and status='submitted';
  return jsonb_build_object('success',true,'status',p_decision,
    'booking_id',v_booking_id,'amount',v_amount);
end;
$function$;
revoke all on function public.srk_submit_my_customer_upi_payment_report(uuid,numeric,text,date) from public,anon;
revoke all on function public.srk_admin_review_customer_upi_payment_report(uuid,text,text) from public,anon;
grant execute on function public.srk_submit_my_customer_upi_payment_report(uuid,numeric,text,date) to authenticated;
grant execute on function public.srk_admin_review_customer_upi_payment_report(uuid,text,text) to authenticated;
