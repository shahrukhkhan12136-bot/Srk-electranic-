
revoke all on function public.srk_admin_review_worker_profile(uuid,text,text) from public,anon,authenticated;
revoke all on function public.srk_admin_review_worker_application(uuid,text,text) from public,anon,authenticated;

create or replace function public.srk_admin_review_worker_profile_masked(
 p_worker_id uuid,p_decision text,p_note text
)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare v public.srk_worker_profiles%rowtype;
begin
 if auth.uid() is null or not public.srk_has_admin_permission('workers.verify') then
   raise exception 'Worker verification permission required' using errcode='42501';
 end if;
 v:=public.srk_admin_review_worker_profile(p_worker_id,p_decision,p_note);
 return jsonb_build_object(
   'worker_id',v.id,'worker_code',v.worker_code,'worker_type',v.worker_type,
   'full_name',v.full_name,'masked_phone',case when v.phone is null then null else '******'||right(v.phone,4) end,
   'verification_status',v.verification_status,'is_active',v.is_active
 );
end
$function$;
revoke all on function public.srk_admin_review_worker_profile_masked(uuid,text,text) from public,anon;
grant execute on function public.srk_admin_review_worker_profile_masked(uuid,text,text) to authenticated;

create or replace function public.srk_admin_review_worker_application_masked(
 p_application_id uuid,p_decision text,p_note text
)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare v public.srk_worker_profiles%rowtype;
begin
 if auth.uid() is null or not public.srk_has_admin_permission('workers.verify') then
   raise exception 'Worker verification permission required' using errcode='42501';
 end if;
 v:=public.srk_admin_review_worker_application(p_application_id,p_decision,p_note);
 if v.id is null then return jsonb_build_object('success',true,'decision',p_decision,'worker_profile_created',false); end if;
 return jsonb_build_object(
   'success',true,'worker_id',v.id,'worker_code',v.worker_code,'worker_type',v.worker_type,
   'full_name',v.full_name,'masked_phone',case when v.phone is null then null else '******'||right(v.phone,4) end,
   'verification_status',v.verification_status,'is_active',v.is_active
 );
end
$function$;
revoke all on function public.srk_admin_review_worker_application_masked(uuid,text,text) from public,anon;
grant execute on function public.srk_admin_review_worker_application_masked(uuid,text,text) to authenticated;
