do $migration$
declare
  v_definition text;
  v_old_select text := $old$select * into v_session from public.srk_worker_work_sessions
 where booking_worker_id=p_booking_worker_id and work_date=p_work_date
  and session_status in ('not_started','running','paused')
 order by created_at desc limit 1;$old$;
  v_new_select text := $new$select * into v_session from public.srk_worker_work_sessions
 where booking_worker_id=p_booking_worker_id and work_date=p_work_date
 order by created_at desc limit 1 for update;$new$;
  v_old_insert text := $old$insert into public.srk_worker_work_sessions(booking_worker_id,work_date)
 values(p_booking_worker_id,p_work_date) returning * into v_session;
 return v_session;$old$;
  v_new_insert text := $new$insert into public.srk_worker_work_sessions(booking_worker_id,work_date)
 values(p_booking_worker_id,p_work_date)
 on conflict (booking_worker_id,work_date) do nothing
 returning * into v_session;
 if not found then
  select * into v_session from public.srk_worker_work_sessions
  where booking_worker_id=p_booking_worker_id and work_date=p_work_date
  order by created_at desc limit 1 for update;
 end if;
 return v_session;$new$;
begin
  v_definition:=pg_get_functiondef('public.srk_worker_open_work_session(uuid,date)'::regprocedure);
  if position(v_old_select in v_definition)=0 or position(v_old_insert in v_definition)=0 then
    raise exception 'Worker session function differs from reviewed source; stop and review';
  end if;
  v_definition:=replace(v_definition,v_old_select,v_new_select);
  v_definition:=replace(v_definition,v_old_insert,v_new_insert);
  execute v_definition;
end
$migration$;
