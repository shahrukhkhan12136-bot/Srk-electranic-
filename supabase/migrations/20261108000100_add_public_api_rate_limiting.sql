create schema if not exists private;

create table if not exists private.srk_public_api_rate_limits (
  endpoint text not null check (endpoint in ('booking', 'application')),
  ip_hash text not null check (ip_hash ~ '^[a-f0-9]{64}$'),
  window_start timestamptz not null,
  request_count integer not null default 0 check (request_count >= 0),
  primary key (endpoint, ip_hash, window_start)
);

revoke all on table private.srk_public_api_rate_limits from public, anon, authenticated;
grant all on table private.srk_public_api_rate_limits to service_role;

create or replace function public.srk_check_public_rate_limit(
  p_endpoint text,
  p_ip_hash text,
  p_limit integer
)
returns boolean
language plpgsql
security definer
set search_path = pg_catalog, private, pg_temp
as $$
declare
  v_count integer;
  v_window timestamptz := date_trunc('hour', statement_timestamp());
begin
  if p_endpoint not in ('booking', 'application')
     or p_ip_hash !~ '^[a-f0-9]{64}$'
     or p_limit < 1 or p_limit > 20 then
    raise exception 'Invalid rate limit parameters';
  end if;

  insert into private.srk_public_api_rate_limits(endpoint, ip_hash, window_start, request_count)
  values (p_endpoint, p_ip_hash, v_window, 1)
  on conflict (endpoint, ip_hash, window_start)
  do update set request_count = private.srk_public_api_rate_limits.request_count + 1
  returning request_count into v_count;

  delete from private.srk_public_api_rate_limits
  where window_start < statement_timestamp() - interval '7 days';

  return v_count <= p_limit;
end;
$$;

revoke all on function public.srk_check_public_rate_limit(text, text, integer) from public, anon, authenticated;
grant execute on function public.srk_check_public_rate_limit(text, text, integer) to service_role;
