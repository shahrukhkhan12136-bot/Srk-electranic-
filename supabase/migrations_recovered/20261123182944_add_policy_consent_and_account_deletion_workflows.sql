
create or replace function public.srk_record_policy_consent(
 p_policy_document_id uuid,p_accepted boolean,p_user_agent text default null
)
returns public.srk_policy_consents
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare
 v_doc public.srk_policy_documents%rowtype;
 v_role text;
 v_consent public.srk_policy_consents%rowtype;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 if p_policy_document_id is null or p_accepted is distinct from true then
   raise exception 'Policy acceptance is required' using errcode='22023';
 end if;
 select * into v_doc from public.srk_policy_documents
 where id=p_policy_document_id and status='published' and effective_at<=clock_timestamp();
 if not found then raise exception 'Published effective policy version not found'; end if;

 if exists(select 1 from public.srk_customer_profiles where user_id=auth.uid()) then
   v_role:='customer';
 else
   select worker_type into v_role from public.srk_worker_profiles where user_id=auth.uid() limit 1;
 end if;
 if v_role is null or v_role<>v_doc.audience_role then
   raise exception 'Policy audience does not match this account role' using errcode='42501';
 end if;

 insert into public.srk_policy_consents(
   user_id,audience_role,policy_document_id,accepted,policy_version,user_agent
 ) values(
   auth.uid(),v_role,v_doc.id,true,v_doc.version,left(p_user_agent,500)
 )
 on conflict(user_id,audience_role,policy_document_id)
 do update set accepted=true,accepted_at=clock_timestamp(),policy_version=excluded.policy_version,
   user_agent=excluded.user_agent
 returning * into v_consent;
 return v_consent;
end
$function$;
revoke all on function public.srk_record_policy_consent(uuid,boolean,text) from public,anon;
grant execute on function public.srk_record_policy_consent(uuid,boolean,text) to authenticated;

create or replace function public.srk_request_account_deletion(p_reason text default null)
returns public.srk_account_deletion_requests
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare v_role text; v_request public.srk_account_deletion_requests%rowtype;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 if exists(select 1 from public.srk_customer_profiles where user_id=auth.uid()) then
   v_role:='customer';
 else
   select worker_type into v_role from public.srk_worker_profiles where user_id=auth.uid() limit 1;
 end if;
 if v_role is null then raise exception 'Customer or worker account not found'; end if;
 if exists(select 1 from public.srk_account_deletion_requests
   where user_id=auth.uid() and status in ('requested','under_review','approved','processing','on_hold')) then
   raise exception 'An active account deletion request already exists';
 end if;
 insert into public.srk_account_deletion_requests(user_id,account_role,request_reason)
 values(auth.uid(),v_role,left(nullif(btrim(coalesce(p_reason,'')),''),2000))
 returning * into v_request;
 return v_request;
end
$function$;
revoke all on function public.srk_request_account_deletion(text) from public,anon;
grant execute on function public.srk_request_account_deletion(text) to authenticated;

create or replace function public.srk_admin_review_account_deletion(
 p_request_id uuid,p_status text,p_reason text,p_retention_explanation text default null
)
returns public.srk_account_deletion_requests
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare v_request public.srk_account_deletion_requests%rowtype;
begin
 if auth.uid() is null or not public.is_srk_admin() then
   raise exception 'Main Admin permission required' using errcode='42501';
 end if;
 if p_request_id is null or p_status not in ('under_review','approved','rejected','processing','on_hold','completed')
    or length(btrim(coalesce(p_reason,'')))<10 then
   raise exception 'Valid deletion status and reason are required' using errcode='22023';
 end if;
 select * into v_request from public.srk_account_deletion_requests where id=p_request_id for update;
 if not found then raise exception 'Deletion request not found'; end if;
 if p_status='completed' and (v_request.legal_hold or exists(
   select 1 from public.srk_booking_complaints c where c.reported_by_user_id=v_request.user_id and c.status in ('new','in_review')
 )) then
   raise exception 'Deletion cannot complete while legal hold or active complaint exists';
 end if;
 update public.srk_account_deletion_requests
 set status=p_status,reviewed_by=auth.uid(),reviewed_at=clock_timestamp(),
     review_reason=btrim(p_reason),retention_explanation=left(p_retention_explanation,2000),
     completed_at=case when p_status='completed' then clock_timestamp() else completed_at end
 where id=p_request_id returning * into v_request;
 return v_request;
end
$function$;
revoke all on function public.srk_admin_review_account_deletion(uuid,text,text,text) from public,anon;
grant execute on function public.srk_admin_review_account_deletion(uuid,text,text,text) to authenticated;
