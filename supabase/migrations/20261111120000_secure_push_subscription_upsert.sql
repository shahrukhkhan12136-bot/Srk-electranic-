-- Securely move a browser endpoint to the currently authenticated account.
-- Push endpoints are unguessable bearer-like identifiers; only the signed-in owner
-- can register the endpoint currently held by that browser.
create or replace function public.srk_save_push_subscription(
  p_endpoint text,
  p_p256dh text,
  p_auth text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if p_endpoint is null or length(p_endpoint) < 1 or length(p_endpoint) > 2048
     or left(p_endpoint, 8) <> 'https://'
     or p_p256dh is null or length(p_p256dh) < 1 or length(p_p256dh) > 256
     or p_auth is null or length(p_auth) < 1 or length(p_auth) > 256 then
    raise exception 'Invalid push subscription';
  end if;

  insert into public.srk_push_subscriptions(user_id, endpoint, p256dh, auth, updated_at)
  values (v_user_id, p_endpoint, p_p256dh, p_auth, now())
  on conflict (endpoint) do update
    set user_id = excluded.user_id,
        p256dh = excluded.p256dh,
        auth = excluded.auth,
        updated_at = now();
end;
$$;

revoke all on function public.srk_save_push_subscription(text, text, text) from public, anon;
grant execute on function public.srk_save_push_subscription(text, text, text) to authenticated;
