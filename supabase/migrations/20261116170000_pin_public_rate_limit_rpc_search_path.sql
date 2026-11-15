-- The rate-limit RPC is service-role-only and references its private table explicitly.
-- An empty path prevents any caller-controlled schema from shadowing trusted names.
alter function public.srk_check_public_rate_limit(text,text,integer)
  set search_path = '';
