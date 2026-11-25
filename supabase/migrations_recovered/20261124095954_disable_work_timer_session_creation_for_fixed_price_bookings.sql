CREATE OR REPLACE FUNCTION public.srk_worker_open_work_session(
 p_booking_worker_id uuid,p_work_date date DEFAULT ((now() AT TIME ZONE 'Asia/Kolkata'))::date
) RETURNS public.srk_worker_work_sessions
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth'
AS $function$
declare
 v_session public.srk_worker_work_sessions%rowtype;
 v_pricing_unit text;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if p_work_date<>(now() at time zone 'Asia/Kolkata')::date then
  raise exception 'Live timer session must use current India date; use offline sync for past events';
 end if;
 select b.pricing_unit_snapshot into v_pricing_unit
 from public.srk_booking_workers bw
 join public.srk_worker_profiles wp on wp.id=bw.worker_id
 join public.service_bookings b on b.id=bw.booking_id
 where bw.id=p_booking_worker_id and wp.user_id=auth.uid()
  and bw.assignment_status in ('accepted','assigned','working','paused');
 if not found then raise exception 'You do not have an accepted assignment'; end if;
 if v_pricing_unit in ('per_item','motor_hp') then
  raise exception 'This fixed-price booking has no work timer; use fixed-price completion';
 end if;
 select * into v_session from public.srk_worker_work_sessions
 where booking_worker_id=p_booking_worker_id and work_date=p_work_date
  and session_status in ('not_started','running','paused')
 order by created_at desc limit 1;
 if found then return v_session; end if;
 insert into public.srk_worker_work_sessions(booking_worker_id,work_date)
 values(p_booking_worker_id,p_work_date) returning * into v_session;
 return v_session;
end
$function$;