
create or replace function public.srk_admin_publish_policy_document(
 p_policy_type text,p_audience_role text,p_language_code text,p_version text,
 p_title text,p_body text,p_effective_at timestamptz,p_reason text
)
returns public.srk_policy_documents
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare v_doc public.srk_policy_documents%rowtype;
begin
 if auth.uid() is null or not public.is_srk_admin() then
   raise exception 'Main Admin permission required' using errcode='42501';
 end if;
 if p_policy_type not in ('terms','privacy')
    or p_audience_role not in ('customer','technician','helper')
    or p_language_code is null or length(btrim(p_language_code)) not between 2 and 12
    or p_version is null or length(btrim(p_version)) not between 1 and 40
    or p_title is null or length(btrim(p_title))<3
    or p_body is null or length(btrim(p_body))<100
    or p_effective_at is null or p_effective_at<clock_timestamp()
    or length(btrim(coalesce(p_reason,'')))<10 then
   raise exception 'Valid policy content, version, audience, future effective date and reason are required' using errcode='22023';
 end if;

 update public.srk_policy_documents
 set status='retired'
 where policy_type=p_policy_type and audience_role=p_audience_role
   and language_code=p_language_code and status='published';

 insert into public.srk_policy_documents(
   policy_type,audience_role,language_code,version,title,body,status,effective_at,created_by
 ) values(
   p_policy_type,p_audience_role,p_language_code,btrim(p_version),btrim(p_title),p_body,'published',p_effective_at,auth.uid()
 ) returning * into v_doc;
 return v_doc;
end
$function$;
revoke all on function public.srk_admin_publish_policy_document(text,text,text,text,text,text,timestamptz,text) from public,anon;
grant execute on function public.srk_admin_publish_policy_document(text,text,text,text,text,text,timestamptz,text) to authenticated;
