create or replace function public.srk_request_account_deletion(p_reason text default null)
returns public.srk_account_deletion_requests
language plpgsql security definer
set search_path = pg_catalog, public, auth
as $function$
declare v_role text; v_request public.srk_account_deletion_requests%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
  if exists(select 1 from public.srk_customer_profiles where user_id=auth.uid()) then
    v_role:='customer';
  else
    select worker_type into v_role from public.srk_worker_profiles where user_id=auth.uid() limit 1;
    if v_role is null then
      select worker_type into v_role from public.srk_worker_applications
      where user_id=auth.uid() order by created_at desc limit 1;
    end if;
  end if;
  if v_role is null then raise exception 'Customer or worker account/application not found' using errcode='P0002'; end if;
  if exists(select 1 from public.srk_account_deletion_requests where user_id=auth.uid()
    and status in ('requested','under_review','approved','processing','on_hold')) then
    raise exception 'An active account deletion request already exists' using errcode='23505';
  end if;
  insert into public.srk_account_deletion_requests(user_id,account_role,request_reason)
  values(auth.uid(),v_role,left(nullif(btrim(coalesce(p_reason,'')),''),2000))
  returning * into v_request;
  return v_request;
end
$function$;
