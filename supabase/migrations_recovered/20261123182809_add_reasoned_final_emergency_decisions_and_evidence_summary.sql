
create or replace function public.srk_admin_decide_emergency_alert(
 p_alert_id uuid,p_decision text,p_reason text
)
returns public.srk_emergency_alerts
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare v_alert public.srk_emergency_alerts%rowtype;
begin
 if auth.uid() is null or not public.srk_has_admin_permission('support.manage') then
   raise exception 'Emergency support permission required' using errcode='42501';
 end if;
 if p_alert_id is null or p_decision not in ('genuine','false','insufficient_evidence')
    or length(btrim(coalesce(p_reason,'')))<10 then
   raise exception 'Valid emergency decision and a reason of at least 10 characters are required' using errcode='22023';
 end if;
 update public.srk_emergency_alerts
 set decision_status=p_decision,decision_reason=btrim(p_reason),
     decided_by=auth.uid(),decided_at=clock_timestamp(),
     status=case when p_decision='false' then 'false_alarm' else 'resolved' end,
     resolved_at=clock_timestamp(),response_due_at=null,
     assigned_staff=coalesce(assigned_staff,auth.uid()),
     admin_note=left(concat_ws(E'\n',admin_note,'FINAL DECISION: '||p_decision||' — '||btrim(p_reason)),2000)
 where id=p_alert_id and status not in ('resolved','false_alarm')
 returning * into v_alert;
 if not found then raise exception 'Open emergency alert not found or already decided'; end if;

 insert into public.srk_emergency_decision_events(
   alert_id,decision_status,decision_reason,decided_by,evidence_summary
 ) values(p_alert_id,p_decision,btrim(p_reason),auth.uid(),
   (select coalesce(string_agg(e.evidence_type||': '||coalesce(e.original_file_name,e.storage_path),'; '),'No evidence attached')
    from public.srk_emergency_evidence e where e.alert_id=p_alert_id));

 insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id,deep_link)
 values(v_alert.raised_by,'emergency_decision','Emergency case decision',
   'Admin decision: '||p_decision||'. Reason: '||btrim(p_reason),
   v_alert.booking_id,'/emergency/'||p_alert_id::text);
 return v_alert;
end
$function$;
revoke all on function public.srk_admin_decide_emergency_alert(uuid,text,text) from public,anon;
grant execute on function public.srk_admin_decide_emergency_alert(uuid,text,text) to authenticated;
