
create or replace function private.srk_save_push_subscription(
  p_endpoint text,p_p256dh text,p_auth text
)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_saved_id uuid;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode='42501';
  end if;

  if p_endpoint is null or length(p_endpoint)<12 or length(p_endpoint)>2048
     or p_endpoint !~ '^https://[^[:space:]]+$'
     or p_p256dh is null or length(p_p256dh)<20 or length(p_p256dh)>256
     or p_p256dh !~ '^[A-Za-z0-9_-]+$'
     or p_auth is null or length(p_auth)<12 or length(p_auth)>256
     or p_auth !~ '^[A-Za-z0-9_-]+$' then
    raise exception 'Invalid push subscription';
  end if;

  insert into public.srk_push_subscriptions(user_id,endpoint,p256dh,auth,updated_at)
  values(v_user_id,p_endpoint,p_p256dh,p_auth,pg_catalog.now())
  on conflict(endpoint) do update
    set p256dh=excluded.p256dh,
        auth=excluded.auth,
        updated_at=pg_catalog.now()
    where public.srk_push_subscriptions.user_id=excluded.user_id
  returning id into v_saved_id;

  if v_saved_id is null then
    raise exception 'This push endpoint is already registered to another account'
      using errcode='42501';
  end if;
end
$function$;

create or replace function public.srk_save_push_subscription(
  p_endpoint text,p_p256dh text,p_auth text
)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
begin
  perform private.srk_save_push_subscription(p_endpoint,p_p256dh,p_auth);
end
$function$;

revoke all on function private.srk_save_push_subscription(text,text,text) from public,anon,authenticated;
revoke all on function public.srk_save_push_subscription(text,text,text) from public,anon;
grant execute on function public.srk_save_push_subscription(text,text,text) to authenticated;

revoke insert,update on table public.srk_push_subscriptions from authenticated;
