
create or replace function public.srk_admin_place_emergency_legal_hold(p_alert_id uuid,p_reason text)
returns public.srk_emergency_legal_holds
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare v_hold public.srk_emergency_legal_holds%rowtype;
begin
 if auth.uid() is null or not public.srk_has_admin_permission('support.manage') then
   raise exception 'Emergency support permission required' using errcode='42501';
 end if;
 if p_alert_id is null or length(btrim(coalesce(p_reason,'')))<10 then
   raise exception 'Legal hold reason must be at least 10 characters';
 end if;
 perform 1 from public.srk_emergency_alerts where id=p_alert_id for update;
 if not found then raise exception 'Emergency alert not found'; end if;
 insert into public.srk_emergency_legal_holds(alert_id,hold_reason,placed_by)
 values(p_alert_id,btrim(p_reason),auth.uid()) returning * into v_hold;
 update public.srk_emergency_alerts set legal_hold=true,legal_hold_reason=btrim(p_reason) where id=p_alert_id;
 update public.srk_emergency_evidence set legal_hold=true where alert_id=p_alert_id;
 return v_hold;
end
$function$;
revoke all on function public.srk_admin_place_emergency_legal_hold(uuid,text) from public,anon;
grant execute on function public.srk_admin_place_emergency_legal_hold(uuid,text) to authenticated;

create or replace function public.srk_admin_release_emergency_legal_hold(p_hold_id uuid,p_reason text)
returns public.srk_emergency_legal_holds
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare v_hold public.srk_emergency_legal_holds%rowtype;
begin
 if auth.uid() is null or not public.is_srk_admin() then
   raise exception 'Main Admin permission required' using errcode='42501';
 end if;
 if p_hold_id is null or length(btrim(coalesce(p_reason,'')))<10 then
   raise exception 'Legal hold release reason must be at least 10 characters';
 end if;
 select * into v_hold from public.srk_emergency_legal_holds where id=p_hold_id and released_at is null for update;
 if not found then raise exception 'Active legal hold not found'; end if;
 if not exists(select 1 from public.srk_emergency_alerts where id=v_hold.alert_id and status in ('resolved','false_alarm')) then
   raise exception 'Legal hold cannot be released until the emergency case is fully closed';
 end if;
 update public.srk_emergency_legal_holds
 set released_by=auth.uid(),released_at=clock_timestamp(),release_reason=btrim(p_reason)
 where id=p_hold_id returning * into v_hold;
 if not exists(select 1 from public.srk_emergency_legal_holds where alert_id=v_hold.alert_id and released_at is null) then
   update public.srk_emergency_alerts set legal_hold=false,legal_hold_reason=null where id=v_hold.alert_id;
   update public.srk_emergency_evidence set legal_hold=false where alert_id=v_hold.alert_id;
 end if;
 return v_hold;
end
$function$;
revoke all on function public.srk_admin_release_emergency_legal_hold(uuid,text) from public,anon;
grant execute on function public.srk_admin_release_emergency_legal_hold(uuid,text) to authenticated;
