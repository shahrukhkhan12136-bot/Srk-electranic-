
create or replace function public.srk_get_current_policy_documents(p_language_code text default 'hi')
returns table(
 id uuid,policy_type text,audience_role text,language_code text,version text,title text,body text,effective_at timestamptz
)
language plpgsql
stable
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare v_role text;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 if exists(select 1 from public.srk_customer_profiles where user_id=auth.uid()) then
   v_role:='customer';
 else
   select worker_type into v_role from public.srk_worker_profiles where user_id=auth.uid() limit 1;
 end if;
 if v_role is null then raise exception 'Account role not found'; end if;
 return query
 select d.id,d.policy_type,d.audience_role,d.language_code,d.version,d.title,d.body,d.effective_at
 from public.srk_policy_documents d
 where d.audience_role=v_role and d.status='published'
   and d.effective_at<=clock_timestamp()
   and d.language_code in (p_language_code,'hi')
 order by case when d.language_code=p_language_code then 0 else 1 end,d.policy_type;
end
$function$;
revoke all on function public.srk_get_current_policy_documents(text) from public,anon;
grant execute on function public.srk_get_current_policy_documents(text) to authenticated;
