
revoke all on function public.srk_admin_set_worker_status(uuid,text,text) from public,anon,authenticated;

create or replace function public.srk_admin_set_worker_status_masked(
 p_worker_id uuid,p_status text,p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare v public.srk_worker_profiles%rowtype;
begin
 if auth.uid() is null or not public.srk_has_admin_permission('workers.manage') then
   raise exception 'Worker management permission required' using errcode='42501';
 end if;
 v:=public.srk_admin_set_worker_status(p_worker_id,p_status,p_reason);
 return jsonb_build_object(
   'worker_id',v.id,'worker_code',v.worker_code,'worker_type',v.worker_type,
   'full_name',v.full_name,'masked_phone',case when v.phone is null then null else '******'||right(v.phone,4) end,
   'verification_status',v.verification_status,'is_active',v.is_active,'is_online',v.is_online
 );
end
$function$;
revoke all on function public.srk_admin_set_worker_status_masked(uuid,text,text) from public,anon;
grant execute on function public.srk_admin_set_worker_status_masked(uuid,text,text) to authenticated;
