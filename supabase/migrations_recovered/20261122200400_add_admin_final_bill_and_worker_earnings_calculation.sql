
create sequence if not exists public.srk_bill_number_seq start 1;

alter table public.srk_worker_skills
  add column if not exists skill_level_id uuid references public.srk_skill_levels(id) on delete restrict;

alter table public.srk_worker_skills
  add constraint srk_approved_worker_skill_requires_level
  check(verification_status<>'approved' or skill_level_id is not null);

create or replace function public.srk_admin_finalize_booking_bill(p_booking_id uuid)
returns public.srk_booking_final_bills
language plpgsql
security definer
set search_path=pg_catalog,public
as $$
declare
  v_booking public.service_bookings%rowtype;
  v_bill public.srk_booking_final_bills%rowtype;
  v_labour numeric(12,2);
  v_material numeric(12,2);
  v_worker record;
  v_rate numeric(10,2);
  v_worker_gross numeric(12,2);
  v_seconds bigint;
begin
  if not coalesce(public.is_srk_admin(),false) then
    raise exception 'Admin permission required';
  end if;

  select * into v_booking from public.service_bookings
  where id=p_booking_id for update;
  if not found then raise exception 'Booking not found'; end if;

  if exists (
    select 1 from public.srk_booking_workers bw
    where bw.booking_id=p_booking_id and bw.assignment_status not in ('completed','released','cancelled','rejected')
  ) then
    raise exception 'All assigned workers must complete or be released before final billing';
  end if;

  if exists (
    select 1 from public.srk_worker_work_sessions s
    join public.srk_booking_workers bw on bw.id=s.booking_worker_id
    where bw.booking_id=p_booking_id and s.session_status not in ('completed','cancelled')
  ) then
    raise exception 'Every work session must be completed or cancelled before final billing';
  end if;

  if exists(select 1 from public.srk_booking_final_bills where booking_id=p_booking_id and status in ('issued','approved')) then
    raise exception 'Final bill already issued';
  end if;

  v_labour := 0;
  for v_worker in
    select bw.id as booking_worker_id,bw.worker_id,bw.worker_role,wp.category_id,
           coalesce(sum(s.billable_seconds),0)::bigint as seconds,
           ws.skill_level_id
    from public.srk_booking_workers bw
    join public.srk_worker_profiles wp on wp.id=bw.worker_id
    left join public.srk_worker_work_sessions s on s.booking_worker_id=bw.id
    left join public.srk_worker_skills ws
      on ws.worker_id=bw.worker_id and ws.verification_status='approved'
     and (v_booking.selected_skill_id is null or ws.skill_id=v_booking.selected_skill_id)
    where bw.booking_id=p_booking_id and bw.assignment_status='completed'
    group by bw.id,bw.worker_id,bw.worker_role,wp.category_id,ws.skill_level_id
  loop
    if v_worker.skill_level_id is null then
      raise exception 'Worker % has no approved skill level for this booking',v_worker.worker_id;
    end if;

    select case when v_worker.worker_role='technician' then r.technician_hourly_rate else r.helper_hourly_rate end
      into v_rate
    from public.srk_service_rates r
    where r.category_id=v_worker.category_id
      and r.skill_level_id=v_worker.skill_level_id
      and (r.service_type_id is null or r.service_type_id=v_booking.service_type_id)
      and r.rate_status='approved'
      and r.effective_from<=clock_timestamp()
      and (r.effective_to is null or r.effective_to>clock_timestamp())
    order by (r.service_type_id is not null) desc,r.effective_from desc
    limit 1;

    if v_rate is null then
      raise exception 'Approved hourly rate is missing for worker %',v_worker.worker_id;
    end if;

    v_worker_gross := round((v_worker.seconds::numeric/3600)*v_rate,2);
    v_labour := v_labour + v_worker_gross;
  end loop;

  v_material := coalesce(v_booking.materials_amount,0);

  insert into public.srk_booking_final_bills
    (booking_id,bill_number,service_amount,materials_amount,status,prepared_at)
  values
    (p_booking_id,'SRK-BILL-'||lpad(nextval('public.srk_bill_number_seq')::text,6,'0'),
     v_labour,v_material,'issued',clock_timestamp())
  returning * into v_bill;

  insert into public.srk_booking_final_bill_items(bill_id,item_type,description,quantity,unit,unit_price)
  values(v_bill.id,'labour','Actual worker timer-based labour charges',1,'booking',v_labour);
  if v_material>0 then
    insert into public.srk_booking_final_bill_items(bill_id,item_type,description,quantity,unit,unit_price)
    values(v_bill.id,'material','Materials supplied (separate from commission)',1,'booking',v_material);
  end if;

  for v_worker in
    select bw.id as booking_worker_id,bw.worker_id,bw.worker_role,wp.category_id,
           coalesce(sum(s.billable_seconds),0)::bigint as seconds,
           ws.skill_level_id
    from public.srk_booking_workers bw
    join public.srk_worker_profiles wp on wp.id=bw.worker_id
    left join public.srk_worker_work_sessions s on s.booking_worker_id=bw.id
    left join public.srk_worker_skills ws
      on ws.worker_id=bw.worker_id and ws.verification_status='approved'
     and (v_booking.selected_skill_id is null or ws.skill_id=v_booking.selected_skill_id)
    where bw.booking_id=p_booking_id and bw.assignment_status='completed'
    group by bw.id,bw.worker_id,bw.worker_role,wp.category_id,ws.skill_level_id
  loop
    select case when v_worker.worker_role='technician' then r.technician_hourly_rate else r.helper_hourly_rate end
      into v_rate
    from public.srk_service_rates r
    where r.category_id=v_worker.category_id
      and r.skill_level_id=v_worker.skill_level_id
      and (r.service_type_id is null or r.service_type_id=v_booking.service_type_id)
      and r.rate_status='approved'
      and r.effective_from<=clock_timestamp()
      and (r.effective_to is null or r.effective_to>clock_timestamp())
    order by (r.service_type_id is not null) desc,r.effective_from desc
    limit 1;

    v_worker_gross := round((v_worker.seconds::numeric/3600)*v_rate,2);

    insert into public.srk_worker_earnings
      (booking_id,booking_worker_id,worker_id,worker_role,bill_id,billable_seconds,
       gross_service_earning,company_commission_rate,company_commission,net_earning,payment_method)
    values
      (p_booking_id,v_worker.booking_worker_id,v_worker.worker_id,v_worker.worker_role,
       v_bill.id,v_worker.seconds,v_worker_gross,15.00,
       round(v_worker_gross*0.15,2),v_worker_gross-round(v_worker_gross*0.15,2),
       case when lower(v_booking.payment_method) in ('upi','card') then 'online' else lower(v_booking.payment_method) end);
  end loop;

  return v_bill;
end;
$$;

revoke all on function public.srk_admin_finalize_booking_bill(uuid) from public,anon;
grant execute on function public.srk_admin_finalize_booking_bill(uuid) to authenticated,service_role;
