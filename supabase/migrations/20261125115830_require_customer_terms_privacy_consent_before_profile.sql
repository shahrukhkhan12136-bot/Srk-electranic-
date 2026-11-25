create or replace function public.srk_get_registration_policy_documents(
  p_worker_type text,
  p_language_code text default 'hi'
)
returns table (id uuid,policy_type text,audience_role text,language_code text,version text,title text,body text,effective_at timestamptz)
language plpgsql stable security definer
set search_path = pg_catalog, public, auth
as $function$
begin
  if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
  if p_worker_type not in ('customer','technician','helper') then raise exception 'Invalid account role' using errcode='22023'; end if;
  return query
  select d.id,d.policy_type,d.audience_role,d.language_code,d.version,d.title,d.body,d.effective_at
  from (
    select distinct on (pd.policy_type) pd.id,pd.policy_type,pd.audience_role,pd.language_code,pd.version,pd.title,pd.body,pd.effective_at
    from public.srk_policy_documents pd
    where pd.audience_role=p_worker_type and pd.status='published'
      and pd.effective_at<=statement_timestamp()
      and pd.language_code in (coalesce(nullif(p_language_code,''),'hi'),'hi')
    order by pd.policy_type,
      case when pd.language_code=coalesce(nullif(p_language_code,''),'hi') then 0 else 1 end,
      pd.effective_at desc,pd.version desc
  ) d order by d.policy_type;
end
$function$;

create or replace function public.srk_record_registration_policy_consent(
  p_worker_type text,p_policy_document_id uuid,p_user_agent text default null
)
returns public.srk_policy_consents
language plpgsql security definer
set search_path = pg_catalog, public, auth
as $function$
declare v_doc public.srk_policy_documents%rowtype; v_consent public.srk_policy_consents%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
  if p_worker_type not in ('customer','technician','helper') then raise exception 'Invalid account role' using errcode='22023'; end if;
  select * into v_doc from public.srk_policy_documents
  where id=p_policy_document_id and audience_role=p_worker_type and status='published' and effective_at<=clock_timestamp();
  if not found then raise exception 'Published effective policy version not found' using errcode='22023'; end if;
  insert into public.srk_policy_consents(user_id,audience_role,policy_document_id,accepted,policy_version,user_agent)
  values(auth.uid(),p_worker_type,v_doc.id,true,v_doc.version,left(p_user_agent,500))
  on conflict(user_id,audience_role,policy_document_id)
  do update set accepted=true,accepted_at=clock_timestamp(),policy_version=excluded.policy_version,user_agent=excluded.user_agent
  returning * into v_consent;
  return v_consent;
end
$function$;

create or replace function public.srk_customer_upsert_profile(p_full_name text,p_phone text)
returns public.srk_customer_profiles
language plpgsql security definer
set search_path = pg_catalog, public, auth
as $function$
declare
  v_profile public.srk_customer_profiles%rowtype;
  v_auth_phone text;
  v_policy record;
  v_required_count integer:=0;
begin
  if auth.uid() is null then raise exception 'OTP login required' using errcode='42501'; end if;
  if length(btrim(coalesce(p_full_name,'')))<2 or p_phone !~ '^[0-9]{10}$' then
    raise exception 'Valid name and 10-digit mobile required' using errcode='22023';
  end if;
  v_auth_phone:=right(regexp_replace(coalesce(auth.jwt()->>'phone',''),'[^0-9]','','g'),10);
  if coalesce(v_auth_phone,'')='' or v_auth_phone<>p_phone then
    raise exception 'Mobile number does not match verified OTP login' using errcode='42501';
  end if;
  for v_policy in
    select distinct on (policy_type) id,policy_type
    from public.srk_policy_documents
    where audience_role='customer' and status='published' and effective_at<=clock_timestamp() and language_code='hi'
    order by policy_type,effective_at desc,version desc
  loop
    v_required_count:=v_required_count+1;
    if not exists(select 1 from public.srk_policy_consents c
      where c.user_id=auth.uid() and c.audience_role='customer'
        and c.policy_document_id=v_policy.id and c.accepted=true) then
      raise exception 'Please read and accept the current Hindi Terms and Privacy Policy before continuing' using errcode='42501';
    end if;
  end loop;
  if v_required_count<>2 then
    raise exception 'Main Admin must publish both Hindi Customer Terms and Privacy Policy before customer registration' using errcode='55000';
  end if;
  insert into public.srk_customer_profiles(user_id,full_name,phone)
  values(auth.uid(),btrim(p_full_name),p_phone)
  on conflict(user_id) do update set full_name=excluded.full_name,phone=excluded.phone,updated_at=clock_timestamp()
  returning * into v_profile;
  return v_profile;
end
$function$;

revoke all on function public.srk_get_registration_policy_documents(text,text) from public,anon;
revoke all on function public.srk_record_registration_policy_consent(text,uuid,text) from public,anon;
grant execute on function public.srk_get_registration_policy_documents(text,text) to authenticated;
grant execute on function public.srk_record_registration_policy_consent(text,uuid,text) to authenticated;
