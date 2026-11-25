
create or replace function public.srk_admin_list_emergency_evidence(p_alert_id uuid)
returns setof public.srk_emergency_evidence
language plpgsql
stable
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
begin
 if auth.uid() is null or not public.srk_has_admin_permission('support.manage') then
   raise exception 'Emergency support permission required' using errcode='42501';
 end if;
 if p_alert_id is null then raise exception 'Alert ID is required'; end if;
 return query select e.* from public.srk_emergency_evidence e
 where e.alert_id=p_alert_id order by e.created_at;
end
$function$;
revoke all on function public.srk_admin_list_emergency_evidence(uuid) from public,anon;
grant execute on function public.srk_admin_list_emergency_evidence(uuid) to authenticated;

create or replace function public.srk_admin_list_emergency_legal_holds(p_alert_id uuid default null)
returns setof public.srk_emergency_legal_holds
language plpgsql
stable
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
begin
 if auth.uid() is null or not public.srk_has_admin_permission('support.manage') then
   raise exception 'Emergency support permission required' using errcode='42501';
 end if;
 return query select h.* from public.srk_emergency_legal_holds h
 where p_alert_id is null or h.alert_id=p_alert_id
 order by h.placed_at desc;
end
$function$;
revoke all on function public.srk_admin_list_emergency_legal_holds(uuid) from public,anon;
grant execute on function public.srk_admin_list_emergency_legal_holds(uuid) to authenticated;
