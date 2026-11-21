-- The offer-details RPC schema-qualifies every application/auth object.
-- An empty search_path prevents object-shadowing while preserving pg_catalog built-ins.
alter function public.srk_get_my_offer_details()
  set search_path = '';
