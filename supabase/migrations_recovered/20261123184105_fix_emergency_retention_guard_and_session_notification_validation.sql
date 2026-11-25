
do $migration$
declare v_def text; v_old text; v_new text;
begin
 v_def:=pg_get_functiondef('public.srk_guard_emergency_retention_delete()'::regprocedure);
 v_old:='if tg_table_name=''srk_emergency_alerts'' then
   v_alert_id:=old.id;
 else
   v_alert_id:=old.alert_id;
 end if;';
 v_new:='if tg_table_name=''srk_emergency_alerts'' then
   v_alert_id:=(to_jsonb(old)->>''id'')::uuid;
 else
   v_alert_id:=(to_jsonb(old)->>''alert_id'')::uuid;
 end if;';
 if position(v_old in v_def)=0 then raise exception 'Emergency delete guard row selection not found'; end if;
 v_def:=replace(v_def,v_old,v_new);
 execute v_def;

 v_def:=pg_get_functiondef('public.srk_notify_worker_session_event()'::regprocedure);
 v_old:='  v_worker_user_id uuid;';
 if position(v_old in v_def)=0 then raise exception 'Session notification variable not found'; end if;
 v_def:=replace(v_def,v_old,'');
 v_old:='select bw.booking_id,b.customer_user_id,wp.user_id
    into v_booking_id,v_customer_user_id,v_worker_user_id';
 v_new:='select bw.booking_id,b.customer_user_id
    into v_booking_id,v_customer_user_id';
 if position(v_old in v_def)=0 then raise exception 'Session notification lookup not found'; end if;
 v_def:=replace(v_def,v_old,v_new);
 execute v_def;
end
$migration$;
