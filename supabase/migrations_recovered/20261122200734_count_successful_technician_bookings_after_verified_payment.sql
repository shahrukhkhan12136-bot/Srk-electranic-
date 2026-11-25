
drop trigger if exists srk_technician_payment_cycle_trigger on public.srk_booking_workers;

create or replace function public.srk_post_one_worker_earning(p_earning_id uuid)
returns void
language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare v public.srk_worker_earnings%rowtype; v_paid text;
begin
  select e.* into v from public.srk_worker_earnings e where e.id=p_earning_id;
  if not found then return; end if;
  select payment_status into v_paid from public.service_bookings where id=v.booking_id;
  if lower(coalesce(v_paid,'')) not in ('paid','completed') then return; end if;

  if v.payment_method in ('online','upi','card') then
    insert into public.srk_worker_wallet_ledger
      (worker_id,booking_id,earning_id,entry_type,amount,balance_effect,description,idempotency_key)
    values(v.worker_id,v.booking_id,v.id,'earning',v.net_earning,v.net_earning,
      'Paid online booking net earning after 15% commission','earning:'||v.id::text)
    on conflict(idempotency_key) do nothing;
    update public.srk_worker_earnings set settlement_status='available' where id=v.id and settlement_status<>'available';
  elsif v.payment_method='cash' and v.worker_role='technician' then
    insert into public.srk_worker_wallet_ledger
      (worker_id,booking_id,earning_id,entry_type,amount,balance_effect,description,idempotency_key)
    values(v.worker_id,v.booking_id,v.id,'cash_commission_due',v.company_commission,-v.company_commission,
      'Cash booking company commission due from technician','cash-commission:'||v.id::text)
    on conflict(idempotency_key) do nothing;
    update public.srk_worker_earnings set settlement_status='cash_commission_due' where id=v.id and settlement_status<>'cash_commission_due';
  elsif v.payment_method='cash' and v.worker_role='helper' then
    update public.srk_worker_earnings set settlement_status='cash_split_pending' where id=v.id and settlement_status<>'cash_split_pending';
  end if;
end $$;

create or replace function public.srk_post_worker_earning_to_ledger()
returns trigger
language plpgsql security definer
set search_path=pg_catalog,public
as $$
begin
  perform public.srk_post_one_worker_earning(new.id);
  return new;
end $$;

create or replace function public.srk_on_booking_payment_completed()
returns trigger
language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare v_bw record; v_count bigint; v_next bigint; v_method text;
begin
  if lower(coalesce(new.payment_status,'')) in ('paid','completed')
     and lower(coalesce(old.payment_status,'')) not in ('paid','completed') then
    v_method:=lower(coalesce(new.payment_method,''));
    for v_bw in
      select bw.worker_id
      from public.srk_booking_workers bw
      join public.srk_worker_profiles wp on wp.id=bw.worker_id
      where bw.booking_id=new.id and bw.worker_role='technician'
        and wp.worker_type='technician' and bw.assignment_status='completed'
      order by bw.worker_id
    loop
      insert into public.srk_technician_booking_cycle(technician_id)
        values(v_bw.worker_id) on conflict(technician_id) do nothing;
      select completed_booking_count into v_count
        from public.srk_technician_booking_cycle where technician_id=v_bw.worker_id for update;
      v_next:=v_count+1;
      if v_next in (3,6) and v_method not in ('online','upi','card') then
        raise exception 'Technician completed booking number % must be paid online',v_next;
      end if;
      update public.srk_technician_booking_cycle
        set completed_booking_count=v_next,last_completed_at=clock_timestamp(),updated_at=clock_timestamp()
        where technician_id=v_bw.worker_id;
      insert into public.srk_technician_booking_sequence(technician_id,booking_id,sequence_number,payment_method)
      values(v_bw.worker_id,new.id,v_next,
        case when v_method in ('upi','card') then 'online' when v_method in ('cash','online') then v_method else null end)
      on conflict(technician_id,booking_id) do nothing;
    end loop;

    perform public.srk_post_one_worker_earning(e.id)
      from public.srk_worker_earnings e where e.booking_id=new.id;
  end if;
  return new;
end $$;

drop trigger if exists srk_booking_payment_completed_trigger on public.service_bookings;
create trigger srk_booking_payment_completed_trigger
after update of payment_status on public.service_bookings
for each row execute function public.srk_on_booking_payment_completed();

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
  v_next integer;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select customer_user_id into v_customer from public.service_bookings where id=p_booking_id for update;
  if not found then raise exception 'Booking not found'; end if;
  if v_customer=auth.uid() then v_role:='customer';
  else
    select exists(
      select 1 from public.srk_booking_workers bw join public.srk_worker_profiles wp on wp.id=bw.worker_id
      where bw.booking_id=p_booking_id and wp.user_id=auth.uid()
        and bw.assignment_status in ('assigned','working','paused','completed')
    ) into v_worker;
    if not v_worker then raise exception 'Only booking customer or assigned worker can confirm cash'; end if;
    v_role:='technician';
  end if;

  select total_amount into v_bill from public.srk_booking_final_bills
  where booking_id=p_booking_id and status in ('issued','approved');
  if v_bill is null then raise exception 'Final bill is not issued'; end if;
  if p_amount is null or p_amount<>v_bill then raise exception 'Cash confirmation must match final bill'; end if;

  if v_role='customer' then
    select count(*) into v_next
    from public.srk_booking_workers bw
    join public.srk_worker_profiles wp on wp.id=bw.worker_id
    join public.srk_technician_booking_cycle c on c.technician_id=wp.id
    where bw.booking_id=p_booking_id and bw.worker_role='technician'
      and (c.completed_booking_count+1) in (3,6);
    if v_next>0 then raise exception 'This technician booking is online-payment-only'; end if;
  end if;

  insert into public.srk_booking_payment_evidence
    (booking_id,submitted_by,payer_role,payment_method,amount,verification_status,note)
  values(p_booking_id,auth.uid(),v_role,'cash',p_amount,'verified',p_note);

  select exists(select 1 from public.srk_booking_payment_evidence where booking_id=p_booking_id and payer_role='customer' and payment_method='cash' and amount=v_bill and verification_status='verified'),
         exists(select 1 from public.srk_booking_payment_evidence where booking_id=p_booking_id and payer_role='technician' and payment_method='cash' and amount=v_bill and verification_status='verified')
  into v_customer_confirmed,v_worker_confirmed;

  if v_customer_confirmed and v_worker_confirmed then
    update public.service_bookings set payment_status='paid',amount_paid=v_bill,payment_verified_at=clock_timestamp()
    where id=p_booking_id;
    return true;
  end if;
  return false;
end $$;

revoke all on function public.srk_post_one_worker_earning(uuid) from public,anon,authenticated;
