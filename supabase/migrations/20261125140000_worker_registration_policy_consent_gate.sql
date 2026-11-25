create or replace function public.srk_get_registration_policy_documents(
  p_worker_type text,
  p_language_code text default 'hi'
)
returns table (
  id uuid,
  policy_type text,
  audience_role text,
  language_code text,
  version text,
  title text,
  body text,
  effective_at timestamptz
)
language plpgsql
stable
security definer
set search_path = pg_catalog, public, auth
as $function$
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode='42501';
  end if;
  if p_worker_type not in ('technician','helper') then
    raise exception 'Invalid worker role' using errcode='22023';
  end if;

  return query
  select d.id,d.policy_type,d.audience_role,d.language_code,d.version,d.title,d.body,d.effective_at
  from (
    select distinct on (pd.policy_type)
      pd.id,pd.policy_type,pd.audience_role,pd.language_code,pd.version,pd.title,pd.body,pd.effective_at
    from public.srk_policy_documents pd
    where pd.audience_role=p_worker_type
      and pd.status='published'
      and pd.effective_at<=statement_timestamp()
      and pd.language_code in (coalesce(nullif(p_language_code,''),'hi'),'hi')
    order by pd.policy_type,
      case when pd.language_code=coalesce(nullif(p_language_code,''),'hi') then 0 else 1 end,
      pd.effective_at desc,pd.version desc
  ) d
  order by d.policy_type;
end
$function$;

create or replace function public.srk_record_registration_policy_consent(
  p_worker_type text,
  p_policy_document_id uuid,
  p_user_agent text default null
)
returns public.srk_policy_consents
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $function$
declare
  v_doc public.srk_policy_documents%rowtype;
  v_consent public.srk_policy_consents%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode='42501';
  end if;
  if p_worker_type not in ('technician','helper') then
    raise exception 'Invalid worker role' using errcode='22023';
  end if;

  select * into v_doc
  from public.srk_policy_documents
  where id=p_policy_document_id
    and audience_role=p_worker_type
    and status='published'
    and effective_at<=clock_timestamp();
  if not found then
    raise exception 'Published effective policy version not found' using errcode='22023';
  end if;

  insert into public.srk_policy_consents(
    user_id,audience_role,policy_document_id,accepted,policy_version,user_agent
  ) values (
    auth.uid(),p_worker_type,v_doc.id,true,v_doc.version,left(p_user_agent,500)
  )
  on conflict(user_id,audience_role,policy_document_id)
  do update set accepted=true,accepted_at=clock_timestamp(),
    policy_version=excluded.policy_version,user_agent=excluded.user_agent
  returning * into v_consent;

  return v_consent;
end
$function$;

create or replace function public.srk_require_worker_registration_policy_consent()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $function$
declare
  v_policy record;
  v_required_count integer:=0;
begin
  if new.user_id is null or new.worker_type not in ('technician','helper') then
    raise exception 'Authenticated Technician or Helper application required' using errcode='22023';
  end if;

  for v_policy in
    select distinct on (policy_type) id,policy_type
    from public.srk_policy_documents
    where audience_role=new.worker_type
      and status='published'
      and effective_at<=clock_timestamp()
      and language_code='hi'
    order by policy_type,effective_at desc,version desc
  loop
    v_required_count:=v_required_count+1;
    if not exists(
      select 1 from public.srk_policy_consents c
      where c.user_id=new.user_id
        and c.audience_role=new.worker_type
        and c.policy_document_id=v_policy.id
        and c.accepted=true
    ) then
      raise exception 'Please read and accept the current Hindi Terms and Privacy Policy before submitting your application'
        using errcode='42501';
    end if;
  end loop;

  if v_required_count<>2 then
    raise exception 'Main Admin must publish both Hindi Terms and Privacy Policy for this worker role before registration'
      using errcode='55000';
  end if;

  return new;
end
$function$;

drop trigger if exists srk_worker_application_policy_consent_guard on public.srk_worker_applications;
create trigger srk_worker_application_policy_consent_guard
before insert or update of user_id,worker_type
on public.srk_worker_applications
for each row execute function public.srk_require_worker_registration_policy_consent();

revoke all on function public.srk_get_registration_policy_documents(text,text) from public,anon;
revoke all on function public.srk_record_registration_policy_consent(text,uuid,text) from public,anon;
revoke all on function public.srk_require_worker_registration_policy_consent() from public,anon,authenticated;
grant execute on function public.srk_get_registration_policy_documents(text,text) to authenticated;
grant execute on function public.srk_record_registration_policy_consent(text,uuid,text) to authenticated;
