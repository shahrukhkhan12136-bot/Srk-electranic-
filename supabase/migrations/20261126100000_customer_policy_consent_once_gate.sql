-- Customer consent is checked once at profile entry/save, not on each booking.
-- This migration is source-only until separately approved for Main Supabase rollout.
create or replace function public.srk_customer_has_current_policy_consent()
returns boolean
language plpgsql
stable
security definer
set search_path = pg_catalog, public, auth
as $function$
declare
  v_required_count integer := 0;
  v_accepted_count integer := 0;
  v_policy record;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode='42501';
  end if;

  for v_policy in
    select distinct on (policy_type) id, policy_type
    from public.srk_policy_documents
    where audience_role='customer'
      and status='published'
      and effective_at<=statement_timestamp()
      and language_code='hi'
    order by policy_type,effective_at desc,version desc
  loop
    v_required_count := v_required_count + 1;
    if exists (
      select 1
      from public.srk_policy_consents c
      where c.user_id=auth.uid()
        and c.audience_role='customer'
        and c.policy_document_id=v_policy.id
        and c.accepted=true
    ) then
      v_accepted_count := v_accepted_count + 1;
    end if;
  end loop;

  return v_required_count=2 and v_accepted_count=2;
end
$function$;

revoke all on function public.srk_customer_has_current_policy_consent() from public,anon;
grant execute on function public.srk_customer_has_current_policy_consent() to authenticated;
