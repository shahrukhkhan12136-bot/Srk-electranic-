
create or replace function public.srk_on_booking_payment_completed()
returns trigger language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v_bw record; v_count bigint; v_next bigint; v_method text; v_normalized_method text;
begin
  if new.status='completed'
     and lower(coalesce(new.payment_status,'')) in ('paid','completed')
     and not (old.status='completed' and lower(coalesce(old.payment_status,'')) in ('paid','completed')) then
    v_method:=lower(coalesce(new.payment_method,''));
    v_normalized_method:=case when v_method in ('upi','card') then 'online' else v_method end;
    for v_bw in
      select bw.worker_id
      from public.srk_booking_workers bw
      join public.srk_worker_profiles wp on wp.id=bw.worker_id
      where bw.booking_id=new.id and bw.worker_role='technician'
        and wp.worker_type='technician' and bw.assignment_status in ('completed','released')
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
      values(v_bw.worker_id,new.id,v_next,v_normalized_method)
      on conflict(technician_id,booking_id) do nothing;
    end loop;

    update public.srk_worker_earnings set payment_method=v_normalized_method,updated_at=clock_timestamp()
    where booking_id=new.id;
    perform public.srk_post_one_worker_earning(e.id)
      from public.srk_worker_earnings e where e.booking_id=new.id;
  end if;
  return new;
end $$;
