
create or replace function public.srk_worker_request_payout(p_amount numeric)
returns public.srk_worker_payout_requests
language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare
  v_worker uuid;
  v_available numeric(12,2);
  v_payout public.srk_worker_payout_requests%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select id into v_worker from public.srk_worker_profiles where user_id=auth.uid() for update;
  if not found then raise exception 'Worker profile not found'; end if;
  if p_amount is null or p_amount<=0 then raise exception 'Payout amount must be positive'; end if;

  select coalesce(sum(balance_effect),0) into v_available
  from public.srk_worker_wallet_ledger where worker_id=v_worker;

  if p_amount>v_available then raise exception 'Payout exceeds available wallet balance'; end if;

  insert into public.srk_worker_payout_requests(worker_id,requested_amount,status)
  values(v_worker,p_amount,'requested') returning * into v_payout;
  return v_payout;
end;
$$;

create or replace function public.srk_admin_review_worker_payout(
  p_payout_id uuid,
  p_approve boolean,
  p_approved_amount numeric default null,
  p_note text default null
) returns public.srk_worker_payout_requests
language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare
  v_payout public.srk_worker_payout_requests%rowtype;
  v_available numeric(12,2);
  v_amount numeric(12,2);
begin
  if not coalesce(public.is_srk_admin(),false) then raise exception 'Admin permission required'; end if;
  select * into v_payout from public.srk_worker_payout_requests where id=p_payout_id for update;
  if not found or v_payout.status not in ('requested','under_review') then raise exception 'Payout request is not reviewable'; end if;

  if not p_approve then
    update public.srk_worker_payout_requests
      set status='rejected',reviewed_at=clock_timestamp(),reviewed_by=auth.uid(),admin_note=p_note
      where id=p_payout_id returning * into v_payout;
    return v_payout;
  end if;

  v_amount:=coalesce(p_approved_amount,v_payout.requested_amount);
  select coalesce(sum(balance_effect),0) into v_available
  from public.srk_worker_wallet_ledger where worker_id=v_payout.worker_id;
  if v_amount<=0 or v_amount>v_payout.requested_amount or v_amount>v_available then
    raise exception 'Approved amount exceeds request or available balance';
  end if;

  update public.srk_worker_payout_requests
    set status='approved',approved_amount=v_amount,reviewed_at=clock_timestamp(),
        reviewed_by=auth.uid(),admin_note=p_note
    where id=p_payout_id returning * into v_payout;
  return v_payout;
end;
$$;

create or replace function public.srk_admin_mark_worker_payout_paid(
  p_payout_id uuid,
  p_payment_method text,
  p_payment_reference text,
  p_note text default null
) returns public.srk_worker_payout_requests
language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare
  v_payout public.srk_worker_payout_requests%rowtype;
  v_available numeric(12,2);
begin
  if not coalesce(public.is_srk_admin(),false) then raise exception 'Admin permission required'; end if;
  if nullif(btrim(p_payment_reference),'') is null then raise exception 'UTR/transaction reference is required'; end if;

  select * into v_payout from public.srk_worker_payout_requests where id=p_payout_id for update;
  if not found or v_payout.status<>'approved' then raise exception 'Only approved payouts can be marked paid'; end if;

  perform 1 from public.srk_worker_profiles where id=v_payout.worker_id for update;
  select coalesce(sum(balance_effect),0) into v_available
  from public.srk_worker_wallet_ledger where worker_id=v_payout.worker_id;
  if v_payout.approved_amount>v_available then raise exception 'Wallet balance changed; payout cannot be paid'; end if;

  insert into public.srk_worker_wallet_ledger
    (worker_id,entry_type,amount,balance_effect,description,reference_id,idempotency_key)
  values
    (v_payout.worker_id,'payout_paid',v_payout.approved_amount,-v_payout.approved_amount,
     'Admin verified payout',p_payment_reference,'payout-paid:'||v_payout.id::text);

  update public.srk_worker_payout_requests
    set status='paid',payment_method=p_payment_method,payment_reference=p_payment_reference,
        admin_note=coalesce(p_note,admin_note),paid_at=clock_timestamp()
    where id=p_payout_id returning * into v_payout;
  return v_payout;
end;
$$;

create or replace function public.srk_worker_wallet_balance()
returns table(available_balance numeric(12,2),total_credits numeric(12,2),total_debits numeric(12,2))
language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare v_worker uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select id into v_worker from public.srk_worker_profiles where user_id=auth.uid();
  if not found then raise exception 'Worker profile not found'; end if;
  return query
    select coalesce(sum(balance_effect),0)::numeric(12,2),
           coalesce(sum(balance_effect) filter(where balance_effect>0),0)::numeric(12,2),
           coalesce(-sum(balance_effect) filter(where balance_effect<0),0)::numeric(12,2)
    from public.srk_worker_wallet_ledger where worker_id=v_worker;
end;
$$;

create or replace function public.srk_confirm_cash_payment(p_booking_id uuid,p_amount numeric,p_note text default null)
returns boolean
language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare
  v_role text;
  v_bill numeric(12,2);
  v_customer uuid;
  v_worker boolean;
  v_customer_confirmed boolean;
  v_worker_confirmed boolean;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select customer_user_id into v_customer from public.service_bookings where id=p_booking_id for update;
  if not found then raise exception 'Booking not found'; end if;

  if v_customer=auth.uid() then
    v_role:='customer';
  else
    select exists(
      select 1 from public.srk_booking_workers bw
      join public.srk_worker_profiles wp on wp.id=bw.worker_id
      where bw.booking_id=p_booking_id and wp.user_id=auth.uid()
        and bw.assignment_status in ('assigned','working','paused','completed')
    ) into v_worker;
    if not v_worker then raise exception 'Only the booking customer or assigned worker can confirm cash'; end if;
    v_role:='technician';
  end if;

  select total_amount into v_bill from public.srk_booking_final_bills
  where booking_id=p_booking_id and status in ('issued','approved');
  if v_bill is null then raise exception 'Final bill is not issued'; end if;
  if p_amount is null or p_amount<>v_bill then raise exception 'Cash confirmation must match the final bill amount'; end if;

  insert into public.srk_booking_payment_evidence
    (booking_id,submitted_by,payer_role,payment_method,amount,verification_status,note)
  values(p_booking_id,auth.uid(),v_role,'cash',p_amount,'verified',p_note);

  select exists(select 1 from public.srk_booking_payment_evidence where booking_id=p_booking_id and payer_role='customer' and payment_method='cash' and amount=v_bill and verification_status='verified'),
         exists(select 1 from public.srk_booking_payment_evidence where booking_id=p_booking_id and payer_role='technician' and payment_method='cash' and amount=v_bill and verification_status='verified')
    into v_customer_confirmed,v_worker_confirmed;

  if v_customer_confirmed and v_worker_confirmed then
    update public.service_bookings
      set payment_status='paid',amount_paid=v_bill,payment_verified_at=clock_timestamp()
      where id=p_booking_id;
    return true;
  end if;
  return false;
end;
$$;

revoke all on function public.srk_worker_request_payout(numeric) from public,anon;
revoke all on function public.srk_admin_review_worker_payout(uuid,boolean,numeric,text) from public,anon;
revoke all on function public.srk_admin_mark_worker_payout_paid(uuid,text,text,text) from public,anon;
revoke all on function public.srk_worker_wallet_balance() from public,anon;
revoke all on function public.srk_confirm_cash_payment(uuid,numeric,text) from public,anon;
grant execute on function public.srk_worker_request_payout(numeric) to authenticated;
grant execute on function public.srk_admin_review_worker_payout(uuid,boolean,numeric,text) to authenticated,service_role;
grant execute on function public.srk_admin_mark_worker_payout_paid(uuid,text,text,text) to authenticated,service_role;
grant execute on function public.srk_worker_wallet_balance() to authenticated;
grant execute on function public.srk_confirm_cash_payment(uuid,numeric,text) to authenticated;
