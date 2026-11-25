CREATE OR REPLACE FUNCTION public.srk_on_booking_payment_completed()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth'
AS $function$
declare
 v_bw record;
 v_count bigint;
 v_next bigint;
 v_method text;
 v_normalized_method text;
 v_payment_done boolean;
begin
 v_payment_done:=new.status='completed'
  and lower(coalesce(new.payment_status,'')) in ('paid','completed');
 v_method:=lower(coalesce(new.payment_method,''));
 v_normalized_method:=case when v_method in ('upi','card','online') then 'online'
  when v_method='cash' then 'cash' else null end;

 if new.status='completed' and old.status is distinct from 'completed' then
  for v_bw in
   select bw.worker_id
   from public.srk_booking_workers bw
   join public.srk_worker_profiles wp on wp.id=bw.worker_id
   where bw.booking_id=new.id and bw.worker_role='technician'
    and wp.worker_type='technician'
    and (
     bw.assignment_status='completed'
     or (bw.assignment_status='released' and exists(
       select 1 from public.srk_worker_work_sessions s
       where s.booking_worker_id=bw.id and s.billable_seconds>0
     ))
    )
   order by bw.worker_id
  loop
   if exists(select 1 from public.srk_technician_booking_sequence s
    where s.technician_id=v_bw.worker_id and s.booking_id=new.id) then
    continue;
   end if;
   insert into public.srk_technician_booking_cycle(technician_id)
   values(v_bw.worker_id) on conflict(technician_id) do nothing;
   select completed_booking_count into v_count
   from public.srk_technician_booking_cycle
   where technician_id=v_bw.worker_id for update;
   v_next:=v_count+1;
   if mod(v_next,3)=0 and v_payment_done and v_normalized_method<>'online' then
    raise exception 'Technician completed booking number % must be paid online',v_next;
   end if;
   update public.srk_technician_booking_cycle
   set completed_booking_count=v_next,last_completed_at=clock_timestamp(),updated_at=clock_timestamp()
   where technician_id=v_bw.worker_id;
   insert into public.srk_technician_booking_sequence(technician_id,booking_id,sequence_number,payment_method)
   values(v_bw.worker_id,new.id,v_next,case when v_payment_done then v_normalized_method else null end);
  end loop;

  -- Helpers have their own independent 1-6 payment sequence.
  for v_bw in
   select bw.worker_id
   from public.srk_booking_workers bw
   join public.srk_worker_profiles wp on wp.id=bw.worker_id
   where bw.booking_id=new.id and bw.worker_role='helper'
    and wp.worker_type='helper'
    and (
     bw.assignment_status='completed'
     or (bw.assignment_status='released' and exists(
       select 1 from public.srk_worker_work_sessions s
       where s.booking_worker_id=bw.id and s.billable_seconds>0
     ))
    )
   order by bw.worker_id
  loop
   if exists(select 1 from public.srk_helper_booking_sequence s
    where s.helper_id=v_bw.worker_id and s.booking_id=new.id) then
    continue;
   end if;
   insert into public.srk_helper_booking_cycle(helper_id)
   values(v_bw.worker_id) on conflict(helper_id) do nothing;
   select completed_booking_count into v_count
   from public.srk_helper_booking_cycle
   where helper_id=v_bw.worker_id for update;
   v_next:=v_count+1;
   if mod(v_next,3)=0 and v_payment_done and v_normalized_method<>'online' then
    raise exception 'Helper completed booking number % must be paid online',v_next;
   end if;
   update public.srk_helper_booking_cycle
   set completed_booking_count=v_next,last_completed_at=clock_timestamp(),updated_at=clock_timestamp()
   where helper_id=v_bw.worker_id;
   insert into public.srk_helper_booking_sequence(helper_id,booking_id,sequence_number,payment_method)
   values(v_bw.worker_id,new.id,v_next,case when v_payment_done then v_normalized_method else null end);
  end loop;
 end if;

 if v_payment_done
    and not (old.status='completed' and lower(coalesce(old.payment_status,'')) in ('paid','completed')) then
  if v_normalized_method is null then
   raise exception 'A valid payment method is required before marking payment completed';
  end if;
  if exists(select 1 from public.srk_technician_booking_sequence s
   where s.booking_id=new.id and mod(s.sequence_number,3)=0 and v_normalized_method<>'online') then
   raise exception 'Technician booking number 3 or 6 must be paid online';
  end if;
  if exists(select 1 from public.srk_helper_booking_sequence s
   where s.booking_id=new.id and mod(s.sequence_number,3)=0 and v_normalized_method<>'online') then
   raise exception 'Helper booking number 3 or 6 must be paid online';
  end if;

  update public.srk_technician_booking_sequence set payment_method=v_normalized_method where booking_id=new.id;
  update public.srk_helper_booking_sequence set payment_method=v_normalized_method where booking_id=new.id;
  update public.srk_worker_earnings set payment_method=v_normalized_method,updated_at=clock_timestamp()
  where booking_id=new.id;
  perform public.srk_post_one_worker_earning(e.id)
  from public.srk_worker_earnings e where e.booking_id=new.id;
 end if;

 if v_payment_done then
  update public.srk_booking_cancellation_fees
  set status='paid',paid_at=clock_timestamp()
  where next_booking_id=new.id and status='added_to_next_booking';
 end if;
 return new;
end
$function$;