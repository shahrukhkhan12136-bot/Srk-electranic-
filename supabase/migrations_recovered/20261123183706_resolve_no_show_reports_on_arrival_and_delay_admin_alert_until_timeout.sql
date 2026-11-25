
do $migration$
declare v_def text; v_old text; v_new text;
begin
 v_def:=pg_get_functiondef('public.srk_customer_report_worker_no_show(uuid,text)'::regprocedure);
 v_old:=' insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
 select au.user_id,''worker_no_show_report'',''Customer reported a no-show'',
   ''Booking ''||v_assignment.booking_id::text||'' has a no-show report. A 10-minute verification window has started.'',
   v_assignment.booking_id from public.srk_admin_users au;
 return v_report;';
 v_new:=' return v_report;';
 if position(v_old in v_def)=0 then raise exception 'Immediate no-show admin notification block not found'; end if;
 v_def:=replace(v_def,v_old,v_new);
 execute v_def;

 v_def:=pg_get_functiondef('public.srk_worker_update_arrival_status(uuid,text)'::regprocedure);
 v_old:=' select b.id,b.customer_user_id into v_booking_id,v_customer_user_id';
 v_new:=' if p_status=''arrived'' then
   update public.srk_booking_no_show_reports
   set status=''resolved'',resolved_at=clock_timestamp(),resolution_note=''Worker arrived during the 10-minute waiting window''
   where booking_worker_id=p_booking_worker_id and status=''waiting'';
 end if;
 select b.id,b.customer_user_id into v_booking_id,v_customer_user_id';
 if position(v_old in v_def)=0 then raise exception 'Worker arrival no-show resolution point not found'; end if;
 v_def:=replace(v_def,v_old,v_new);
 execute v_def;
end
$migration$;
