
do $migration$
declare v_def text; v_old text; v_new text;
begin
 v_def:=pg_get_functiondef('public.srk_customer_report_worker_no_show(uuid,text)'::regprocedure);
 v_old:=' if v_assignment.arrived_at is not null then raise exception ''Worker is already marked arrived''; end if;';
 v_new:=v_old||'
 if exists(select 1 from public.srk_worker_work_sessions s where s.booking_worker_id=p_booking_worker_id
   and (s.session_status in (''running'',''paused'') or s.billable_seconds>0)) then
   raise exception ''Work timer has started; use Help/Report instead of no-show cancellation'';
 end if;';
 if position(v_old in v_def)=0 then raise exception 'No-show arrival check not found'; end if;
 v_def:=replace(v_def,v_old,v_new);
 execute v_def;
end
$migration$;
