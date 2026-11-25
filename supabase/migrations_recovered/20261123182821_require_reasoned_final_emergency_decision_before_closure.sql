
create or replace function public.srk_admin_resolve_emergency_alert(
 p_alert_id uuid,p_status text,p_note text default null
)
returns public.srk_emergency_alerts
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare v public.srk_emergency_alerts%rowtype;
begin
 if auth.uid() is null or not public.srk_has_admin_permission('support.manage') then
   raise exception 'Support permission required' using errcode='42501';
 end if;
 if p_status not in ('acknowledged','responding') then
   raise exception 'Use the reasoned final emergency decision action for resolved/false-alarm classification';
 end if;
 if p_alert_id is null or length(btrim(coalesce(p_note,'')))<5 then
   raise exception 'Alert and response note are required';
 end if;
 update public.srk_emergency_alerts
 set status=p_status,assigned_staff=coalesce(assigned_staff,auth.uid()),
     acknowledged_by=case when p_status='acknowledged' then auth.uid() else acknowledged_by end,
     acknowledged_at=case when p_status='acknowledged' then coalesce(acknowledged_at,clock_timestamp()) else acknowledged_at end,
     response_due_at=case when p_status='acknowledged' then null else response_due_at end,
     admin_note=left(concat_ws(E'\n',admin_note,btrim(p_note)),2000)
 where id=p_alert_id and status not in ('resolved','false_alarm')
 returning * into v;
 if not found then raise exception 'Emergency alert not found'; end if;
 if p_status='acknowledged' then
   update public.srk_emergency_escalations set acknowledged_at=clock_timestamp(),delivery_status='acknowledged'
   where alert_id=p_alert_id and acknowledged_at is null;
 end if;
 insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
 values(v.raised_by,'emergency_update','Emergency response update',btrim(p_note),v.booking_id);
 return v;
end
$function$;
