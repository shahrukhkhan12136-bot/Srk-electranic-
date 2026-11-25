
create or replace function public.srk_admin_set_fixed_price_worker_allocations(
  p_booking_id uuid,
  p_allocations jsonb,
  p_reason text
)
returns integer
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare
  v_booking public.service_bookings%rowtype;
  v_rule public.srk_service_pricing_rules%rowtype;
  v_expected numeric(12,2);
  v_total numeric(12,2);
  v_count integer;
  v_old jsonb;
  v_new jsonb;
  v_event_type text;
begin
  if auth.uid() is null or not public.srk_has_admin_permission('bookings.manage') then
    raise exception 'Booking management permission required' using errcode='42501';
  end if;
  if p_booking_id is null or p_allocations is null
     or jsonb_typeof(p_allocations) <> 'array'
     or jsonb_array_length(p_allocations) = 0
     or p_reason is null or length(btrim(p_reason)) not between 10 and 2000 then
    raise exception 'Booking, non-empty allocation array and reason (10-2000 characters) are required' using errcode='22023';
  end if;

  select * into v_booking from public.service_bookings where id=p_booking_id for update;
  if not found then raise exception 'Booking not found'; end if;

  if v_booking.status is distinct from 'in_progress'
     or v_booking.completion_approval_status is distinct from 'pending'
     or v_booking.completion_requested_at is null
     or coalesce(v_booking.work_timer_running,false) then
    raise exception 'Allocations are allowed only after work completion is submitted for Customer review';
  end if;

  if exists (
    select 1 from public.srk_booking_final_bills b
    where b.booking_id=p_booking_id and b.status in ('issued','approved','disputed')
  ) or exists (
    select 1 from public.srk_worker_earnings e
    where e.booking_id=p_booking_id
  ) then
    raise exception 'Worker allocations are locked after a bill or worker earning has been created';
  end if;

  if v_booking.pricing_unit_snapshot is distinct from 'per_item'
     or v_booking.pricing_rule_id is null
     or v_booking.pricing_quantity is null
     or v_booking.pricing_quantity <= 0 then
    raise exception 'This allocation RPC currently supports only valid per-item fixed-price bookings';
  end if;

  perform 1 from public.srk_booking_workers where booking_id=p_booking_id for update;

  select * into v_rule from public.srk_service_pricing_rules
  where id=v_booking.pricing_rule_id and pricing_unit='per_item' for share;
  if not found or v_rule.technician_rate is null or v_rule.technician_rate <= 0 then
    raise exception 'Booking per-item pricing snapshot is missing or invalid';
  end if;

  v_expected := round(v_rule.technician_rate * v_booking.pricing_quantity,2);
  if v_expected <= 0 then raise exception 'Expected fixed service amount must be positive'; end if;

  if exists (
    select 1 from jsonb_to_recordset(p_allocations) as x(booking_worker_id uuid,gross_amount numeric)
    where x.booking_worker_id is null or x.gross_amount is null
       or x.gross_amount < 0 or x.gross_amount <> round(x.gross_amount,2)
  ) then
    raise exception 'Each allocation requires a booking_worker_id and a non-negative two-decimal gross_amount';
  end if;

  select count(*),coalesce(sum(x.gross_amount),0) into v_count,v_total
  from jsonb_to_recordset(p_allocations) as x(booking_worker_id uuid,gross_amount numeric);

  if v_count <> jsonb_array_length(p_allocations)
     or (select count(distinct x.booking_worker_id)
         from jsonb_to_recordset(p_allocations) as x(booking_worker_id uuid,gross_amount numeric)) <> v_count then
    raise exception 'Duplicate or malformed worker allocation entries are not allowed';
  end if;

  if v_total <> v_expected then
    raise exception 'Worker allocation total (%) must exactly equal fixed service amount (%)',v_total,v_expected;
  end if;

  if exists (
    select 1 from public.srk_booking_workers bw
    where bw.booking_id=p_booking_id and bw.assignment_status in ('completed','released')
      and not exists (
        select 1 from jsonb_to_recordset(p_allocations) as x(booking_worker_id uuid,gross_amount numeric)
        where x.booking_worker_id=bw.id
      )
  ) or exists (
    select 1 from jsonb_to_recordset(p_allocations) as x(booking_worker_id uuid,gross_amount numeric)
    left join public.srk_booking_workers bw
      on bw.id=x.booking_worker_id and bw.booking_id=p_booking_id
     and bw.assignment_status in ('completed','released')
    where bw.id is null
  ) then
    raise exception 'Allocation must include every completed/released assigned worker and no other worker';
  end if;

  if not exists (
    select 1 from public.srk_booking_workers bw
    where bw.booking_id=p_booking_id and bw.assignment_status in ('completed','released')
  ) then
    raise exception 'At least one completed/released worker assignment is required';
  end if;

  select coalesce(jsonb_agg(to_jsonb(a) order by a.booking_worker_id),'[]'::jsonb)
    into v_old from public.srk_fixed_price_worker_allocations a where a.booking_id=p_booking_id;

  select case when count(*)=0 then 'created' else 'replaced' end into v_event_type
  from public.srk_fixed_price_worker_allocations where booking_id=p_booking_id;

  delete from public.srk_fixed_price_worker_allocations where booking_id=p_booking_id;

  insert into public.srk_fixed_price_worker_allocations(
    booking_id,booking_worker_id,worker_id,gross_service_earning,allocation_reason,allocated_by
  )
  select p_booking_id,bw.id,bw.worker_id,x.gross_amount,btrim(p_reason),auth.uid()
  from jsonb_to_recordset(p_allocations) as x(booking_worker_id uuid,gross_amount numeric)
  join public.srk_booking_workers bw on bw.id=x.booking_worker_id and bw.booking_id=p_booking_id;

  select coalesce(jsonb_agg(jsonb_build_object(
    'booking_worker_id',a.booking_worker_id,'worker_id',a.worker_id,
    'worker_role',bw.worker_role,'gross_service_earning',a.gross_service_earning
  ) order by a.booking_worker_id),'[]'::jsonb)
  into v_new
  from public.srk_fixed_price_worker_allocations a
  join public.srk_booking_workers bw on bw.id=a.booking_worker_id
  where a.booking_id=p_booking_id;

  insert into public.srk_fixed_price_worker_allocation_events(
    booking_id,event_type,previous_allocations,new_allocations,reason,actor_user_id
  ) values (p_booking_id,v_event_type,v_old,v_new,btrim(p_reason),auth.uid());

  return v_count;
end;
$function$;

create or replace function public.srk_admin_finalize_booking_bill(p_booking_id uuid)
returns public.srk_booking_final_bills
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare
  v_booking public.service_bookings%rowtype;
  v_bill public.srk_booking_final_bills%rowtype;
  v_rule public.srk_service_pricing_rules%rowtype;
  v_labour numeric(12,2):=0;
  v_material numeric(12,2);
  v_worker record;
  v_worker_gross numeric(12,2);
  v_worker_commission numeric(12,2);
  v_existing public.srk_booking_final_bills%rowtype;
  v_next_revision integer;
  v_tech_worked integer;
  v_helper_worked integer;
  v_is_fixed boolean:=false;
  v_expected_fixed_amount numeric(12,2);
begin
  if auth.uid() is null or not public.srk_has_admin_permission('bookings.manage') then
    raise exception 'Booking management permission required' using errcode='42501';
  end if;

  select * into v_booking from public.service_bookings where id=p_booking_id for update;
  if not found then raise exception 'Booking not found'; end if;

  if v_booking.status is distinct from 'in_progress'
     or v_booking.completion_approval_status is distinct from 'pending'
     or v_booking.completion_requested_at is null
     or coalesce(v_booking.work_timer_running,false) then
    raise exception 'Final bill requires completed worker sessions and a pending Customer completion review';
  end if;
  if v_booking.payment_status='paid' then raise exception 'Paid booking cannot be rebilled'; end if;
  if v_booking.commission_rate is null or v_booking.commission_rate<0 or v_booking.commission_rate>100 then
    raise exception 'Booking commission snapshot is invalid';
  end if;

  if v_booking.pricing_unit_snapshot='per_item' then
    v_is_fixed:=true;
    if v_booking.pricing_rule_id is null or v_booking.pricing_quantity is null or v_booking.pricing_quantity<=0 then
      raise exception 'Fixed-price booking pricing snapshot is incomplete';
    end if;
    select * into v_rule from public.srk_service_pricing_rules
    where id=v_booking.pricing_rule_id and pricing_unit='per_item' for share;
    if not found or v_rule.technician_rate is null or v_rule.technician_rate<=0 then
      raise exception 'Fixed-price booking rule snapshot is missing or invalid';
    end if;
    v_expected_fixed_amount:=round(v_rule.technician_rate*v_booking.pricing_quantity,2);
    v_labour:=v_expected_fixed_amount;

    select count(*) filter (where bw.worker_role='technician'),
           count(*) filter (where bw.worker_role='helper')
      into v_tech_worked,v_helper_worked
    from public.srk_booking_workers bw
    where bw.booking_id=p_booking_id and bw.assignment_status in ('completed','released');

    if v_tech_worked<v_booking.requested_technician_count
       or v_helper_worked<v_booking.requested_helper_count then
      raise exception 'Requested number of Technicians/Helpers has not completed the fixed-price work';
    end if;

    perform 1 from public.srk_booking_workers where booking_id=p_booking_id for update;
    perform 1 from public.srk_fixed_price_worker_allocations where booking_id=p_booking_id for update;

    if (select count(*) from public.srk_fixed_price_worker_allocations where booking_id=p_booking_id)
       <> (select count(*) from public.srk_booking_workers
           where booking_id=p_booking_id and assignment_status in ('completed','released')) then
      raise exception 'Every completed/released worker must have exactly one fixed-price allocation';
    end if;

    if exists (
      select 1 from public.srk_fixed_price_worker_allocations a
      left join public.srk_booking_workers bw
        on bw.id=a.booking_worker_id and bw.booking_id=p_booking_id
       and bw.assignment_status in ('completed','released')
      where a.booking_id=p_booking_id and bw.id is null
    ) then
      raise exception 'Fixed-price allocation references a worker who is not completed/released on this booking';
    end if;

    if (select coalesce(sum(gross_service_earning),0)
        from public.srk_fixed_price_worker_allocations where booking_id=p_booking_id)
       <> v_expected_fixed_amount then
      raise exception 'Fixed-price worker allocations must exactly equal the approved service price';
    end if;
  else
    if v_booking.pricing_unit_snapshot is not null
       and v_booking.pricing_unit_snapshot not in ('hour') then
      raise exception 'Unsupported pricing unit for final billing';
    end if;

    select count(*) into v_tech_worked
    from public.srk_booking_workers bw
    where bw.booking_id=p_booking_id and bw.worker_role='technician'
      and bw.assignment_status in ('completed','released')
      and exists (select 1 from public.srk_worker_work_sessions s
                  where s.booking_worker_id=bw.id and s.billable_seconds>0);

    select count(*) into v_helper_worked
    from public.srk_booking_workers bw
    where bw.booking_id=p_booking_id and bw.worker_role='helper'
      and bw.assignment_status in ('completed','released')
      and exists (select 1 from public.srk_worker_work_sessions s
                  where s.booking_worker_id=bw.id and s.billable_seconds>0);

    if v_tech_worked<v_booking.requested_technician_count
       or v_helper_worked<v_booking.requested_helper_count then
      raise exception 'Requested number of Technicians/Helpers has not completed billable work';
    end if;

    for v_worker in
      select bw.id booking_worker_id,bw.worker_id,bw.worker_role,bw.hourly_rate_snapshot,
        coalesce(sum(s.billable_seconds),0)::bigint seconds
      from public.srk_booking_workers bw
      left join public.srk_worker_work_sessions s on s.booking_worker_id=bw.id
      where bw.booking_id=p_booking_id and bw.assignment_status in ('completed','released')
      group by bw.id,bw.worker_id,bw.worker_role,bw.hourly_rate_snapshot
      having coalesce(sum(s.billable_seconds),0)>0
    loop
      if v_worker.hourly_rate_snapshot is null then raise exception 'Worker rate snapshot missing'; end if;
      if v_worker.seconds>coalesce(v_booking.requested_duration_hours,1440)*3600 then
        raise exception 'Worker actual billable time exceeds booked maximum duration';
      end if;
      v_worker_gross:=round((v_worker.seconds::numeric/3600)*v_worker.hourly_rate_snapshot,2);
      v_labour:=v_labour+v_worker_gross;
    end loop;
  end if;

  if exists (
    select 1 from public.srk_booking_workers
    where booking_id=p_booking_id
      and assignment_status not in ('completed','released','cancelled','rejected')
  ) then raise exception 'All assigned workers must complete or be released before final billing'; end if;

  if exists (
    select 1 from public.srk_worker_work_sessions s
    join public.srk_booking_workers bw on bw.id=s.booking_worker_id
    where bw.booking_id=p_booking_id and s.session_status not in ('completed','cancelled')
  ) then raise exception 'Every work session must be completed or cancelled before final billing'; end if;

  v_material:=coalesce(v_booking.materials_amount,0);

  select * into v_existing from public.srk_booking_final_bills
  where booking_id=p_booking_id for update;

  if found then
    if exists (
      select 1 from public.srk_worker_earnings e
      join public.srk_worker_wallet_ledger l on l.earning_id=e.id
      where e.booking_id=p_booking_id
    ) then raise exception 'Final bill cannot be reissued after worker earnings have entered the wallet ledger; use refund/reconciliation'; end if;
    if exists (select 1 from public.srk_booking_refund_requests r
               where r.booking_id=p_booking_id and r.status<>'rejected') then
      raise exception 'Final bill cannot be reissued while a refund request is active';
    end if;
    if v_existing.status in ('issued','approved','disputed') then
      raise exception 'An active final bill already exists';
    end if;

    v_next_revision:=v_existing.revision_no+1;
    insert into public.srk_booking_final_bill_revisions(
      bill_id,revision_no,previous_bill_data,previous_items,reason,archived_by
    ) values (
      v_existing.id,v_existing.revision_no,to_jsonb(v_existing),
      coalesce((select jsonb_agg(to_jsonb(i) order by i.created_at)
                from public.srk_booking_final_bill_items i where i.bill_id=v_existing.id),'[]'::jsonb),
      'Reissued after work reopening',auth.uid()
    );
    delete from public.srk_booking_final_bill_items where bill_id=v_existing.id;
    update public.srk_booking_final_bills
    set bill_number='SRK-BILL-'||lpad(nextval('public.srk_bill_number_seq')::text,6,'0'),
      revision_no=v_next_revision,service_amount=v_labour,materials_amount=v_material,
      discount_amount=0,tax_amount=0,status='issued',prepared_at=clock_timestamp(),updated_at=clock_timestamp()
    where id=v_existing.id returning * into v_bill;
  else
    insert into public.srk_booking_final_bills(
      booking_id,bill_number,revision_no,service_amount,materials_amount,status,prepared_at
    ) values (
      p_booking_id,'SRK-BILL-'||lpad(nextval('public.srk_bill_number_seq')::text,6,'0'),
      1,v_labour,v_material,'issued',clock_timestamp()
    ) returning * into v_bill;
  end if;

  insert into public.srk_booking_final_bill_items(
    bill_id,item_type,description,quantity,unit,unit_price
  ) values (
    v_bill.id,'labour',
    case when v_is_fixed then 'Approved fixed per-item service charge'
         else 'Actual worker timer-based labour charges' end,
    1,'booking',v_labour
  );

  if v_material>0 then
    insert into public.srk_booking_final_bill_items(
      bill_id,item_type,description,quantity,unit,unit_price
    ) values (
      v_bill.id,'material','Materials supplied (separate from commission)',1,'booking',v_material
    );
  end if;

  if v_is_fixed then
    for v_worker in
      select a.booking_worker_id,a.worker_id,bw.worker_role,
        a.gross_service_earning gross_amount
      from public.srk_fixed_price_worker_allocations a
      join public.srk_booking_workers bw on bw.id=a.booking_worker_id
      where a.booking_id=p_booking_id
      order by a.booking_worker_id
    loop
      v_worker_gross:=v_worker.gross_amount;
      v_worker_commission:=round(v_worker_gross*v_booking.commission_rate/100,2);

      insert into public.srk_worker_earnings(
        booking_id,booking_worker_id,worker_id,worker_role,bill_id,
        billable_seconds,gross_service_earning,company_commission_rate,
        company_commission,net_earning,payment_method,payout_status,settlement_status
      ) values (
        p_booking_id,v_worker.booking_worker_id,v_worker.worker_id,v_worker.worker_role,
        v_bill.id,0,v_worker_gross,v_booking.commission_rate,v_worker_commission,
        v_worker_gross-v_worker_commission,
        case when lower(v_booking.payment_method) in ('upi','card') then 'online'
             else lower(v_booking.payment_method) end,
        'pending','pending'
      )
      on conflict(booking_worker_id) do update set
        bill_id=excluded.bill_id,billable_seconds=0,
        gross_service_earning=excluded.gross_service_earning,
        company_commission_rate=excluded.company_commission_rate,
        company_commission=excluded.company_commission,net_earning=excluded.net_earning,
        payment_method=excluded.payment_method,payout_status='pending',
        settlement_status='pending',updated_at=clock_timestamp();
    end loop;
  else
    for v_worker in
      select bw.id booking_worker_id,bw.worker_id,bw.worker_role,bw.hourly_rate_snapshot,
        coalesce(sum(s.billable_seconds),0)::bigint seconds
      from public.srk_booking_workers bw
      left join public.srk_worker_work_sessions s on s.booking_worker_id=bw.id
      where bw.booking_id=p_booking_id and bw.assignment_status in ('completed','released')
      group by bw.id,bw.worker_id,bw.worker_role,bw.hourly_rate_snapshot
      having coalesce(sum(s.billable_seconds),0)>0
    loop
      v_worker_gross:=round((v_worker.seconds::numeric/3600)*v_worker.hourly_rate_snapshot,2);
      v_worker_commission:=round(v_worker_gross*v_booking.commission_rate/100,2);

      insert into public.srk_worker_earnings(
        booking_id,booking_worker_id,worker_id,worker_role,bill_id,
        billable_seconds,gross_service_earning,company_commission_rate,
        company_commission,net_earning,payment_method,payout_status,settlement_status
      ) values (
        p_booking_id,v_worker.booking_worker_id,v_worker.worker_id,v_worker.worker_role,
        v_bill.id,v_worker.seconds,v_worker_gross,v_booking.commission_rate,v_worker_commission,
        v_worker_gross-v_worker_commission,
        case when lower(v_booking.payment_method) in ('upi','card') then 'online'
             else lower(v_booking.payment_method) end,
        'pending','pending'
      )
      on conflict(booking_worker_id) do update set
        bill_id=excluded.bill_id,billable_seconds=excluded.billable_seconds,
        gross_service_earning=excluded.gross_service_earning,
        company_commission_rate=excluded.company_commission_rate,
        company_commission=excluded.company_commission,net_earning=excluded.net_earning,
        payment_method=excluded.payment_method,payout_status='pending',
        settlement_status='pending',updated_at=clock_timestamp();
    end loop;
  end if;

  return v_bill;
end;
$function$;

revoke all on function public.srk_admin_finalize_booking_bill(uuid) from public,anon;
grant execute on function public.srk_admin_finalize_booking_bill(uuid) to authenticated;
revoke all on function public.srk_admin_set_fixed_price_worker_allocations(uuid,jsonb,text) from public,anon;
grant execute on function public.srk_admin_set_fixed_price_worker_allocations(uuid,jsonb,text) to authenticated;
