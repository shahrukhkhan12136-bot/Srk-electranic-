
create or replace function public.srk_process_emergency_escalations()
returns integer
language plpgsql
security definer
set search_path to 'pg_catalog','public'
as $function$
declare
 v_alert public.srk_emergency_alerts%rowtype;
 v_level integer;
 v_next_level integer;
 v_minutes integer;
 v_schedule jsonb;
 v_due timestamptz;
 v_processed integer:=0;
begin
 select setting_value into v_schedule
 from public.srk_system_settings where setting_key='emergency_escalation_minutes';
 if jsonb_typeof(v_schedule)<>'array' then v_schedule:='[1,2,5]'::jsonb; end if;

 for v_alert in
   select * from public.srk_emergency_alerts
   where status in ('open','acknowledged','responding')
     and acknowledged_at is null
     and response_due_at is not null
     and response_due_at<=clock_timestamp()
   order by response_due_at
   for update skip locked
   limit 100
 loop
   v_level:=greatest(v_alert.escalation_level,1);
   update public.srk_emergency_escalations
   set delivery_status='sent',triggered_at=coalesce(triggered_at,clock_timestamp())
   where alert_id=v_alert.id and escalation_level=v_level;

   insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id,deep_link)
   select au.user_id,'emergency_escalation','SRK ELECTRONIC SOS: तत्काल कार्रवाई',
     'SOS Alert '||v_alert.id::text||' पर अभी तक Admin acknowledgement नहीं मिला है। कृपया तुरंत कार्रवाई करें।',
     v_alert.booking_id,'/admin/emergency/'||v_alert.id::text
   from public.srk_admin_users au;

   v_next_level:=v_level+1;
   if v_next_level<=jsonb_array_length(v_schedule) then
     v_minutes:=greatest(1,least(60,(v_schedule->>(v_next_level-1))::integer));
     v_due:=v_alert.created_at+make_interval(mins=>v_minutes);
   else
     v_minutes:=greatest(1,least(60,(v_schedule->>(jsonb_array_length(v_schedule)-1))::integer));
     v_due:=clock_timestamp()+make_interval(mins=>v_minutes);
   end if;

   update public.srk_emergency_alerts
   set escalation_level=v_next_level,response_due_at=v_due
   where id=v_alert.id;

   insert into public.srk_emergency_escalations(
     alert_id,escalation_level,triggered_at,response_due_at,notified_role,delivery_channel,delivery_status
   ) values(v_alert.id,v_next_level,clock_timestamp(),v_due,'admin','in_app','queued')
   on conflict(alert_id,escalation_level) do update
     set response_due_at=excluded.response_due_at,delivery_status='queued';
   v_processed:=v_processed+1;
 end loop;
 return v_processed;
end
$function$;
revoke all on function public.srk_process_emergency_escalations() from public,anon,authenticated;

create or replace function public.srk_admin_acknowledge_emergency_alert(
 p_alert_id uuid,p_note text
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
 if p_alert_id is null or length(btrim(coalesce(p_note,'')))<5 then
   raise exception 'Alert and acknowledgement note are required' using errcode='22023';
 end if;
 update public.srk_emergency_alerts
 set acknowledged_by=auth.uid(),acknowledged_at=clock_timestamp(),
     response_due_at=null,status=case when status='open' then 'acknowledged' else status end,
     assigned_staff=coalesce(assigned_staff,auth.uid()),
     admin_note=left(concat_ws(E'\n',admin_note,'ACKNOWLEDGED: '||btrim(p_note)),2000)
 where id=p_alert_id and status not in ('resolved','false_alarm')
 returning * into v_alert;
 if not found then raise exception 'Open emergency alert not found'; end if;
 update public.srk_emergency_escalations
 set acknowledged_at=clock_timestamp(),delivery_status='acknowledged'
 where alert_id=p_alert_id and acknowledged_at is null;
 insert into public.srk_emergency_decision_events(alert_id,decision_status,decision_reason,decided_by,evidence_summary)
 values(p_alert_id,'insufficient_evidence','Acknowledgement only; no final emergency decision has been made. '||btrim(p_note),auth.uid(),'Admin acknowledged response; final classification pending.');
 return v_alert;
end
$function$;
revoke all on function public.srk_admin_acknowledge_emergency_alert(uuid,text) from public,anon;
grant execute on function public.srk_admin_acknowledge_emergency_alert(uuid,text) to authenticated;

create or replace function public.srk_guard_emergency_retention_delete()
returns trigger
language plpgsql
set search_path to 'pg_catalog','public'
as $function$
declare v_alert_id uuid;
begin
 if tg_table_name='srk_emergency_alerts' then
   v_alert_id:=old.id;
 else
   v_alert_id:=old.alert_id;
 end if;
 if exists(select 1 from public.srk_emergency_legal_holds h where h.alert_id=v_alert_id and h.released_at is null)
    or exists(select 1 from public.srk_emergency_alerts a where a.id=v_alert_id and
      (a.legal_hold or (a.retention_until is not null and a.retention_until>clock_timestamp())))
    or (tg_table_name='srk_emergency_evidence' and old.legal_hold)
    or (tg_table_name='srk_emergency_evidence' and old.retention_until is not null and old.retention_until>clock_timestamp()) then
   raise exception 'Emergency evidence is under legal hold or within mandatory retention; deletion blocked';
 end if;
 return old;
end
$function$;
drop trigger if exists srk_emergency_alert_retention_delete_guard on public.srk_emergency_alerts;
create trigger srk_emergency_alert_retention_delete_guard
before delete on public.srk_emergency_alerts
for each row execute function public.srk_guard_emergency_retention_delete();
drop trigger if exists srk_emergency_evidence_retention_delete_guard on public.srk_emergency_evidence;
create trigger srk_emergency_evidence_retention_delete_guard
before delete on public.srk_emergency_evidence
for each row execute function public.srk_guard_emergency_retention_delete();
revoke all on function public.srk_guard_emergency_retention_delete() from public,anon,authenticated;

select cron.schedule(
 'srk-emergency-escalation-every-minute',
 '* * * * *',
 'select public.srk_process_emergency_escalations();'
);
