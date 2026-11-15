-- Older feature-branch history may already have retired these legacy quotation RPCs.
-- IF EXISTS keeps fresh replay safe while still hardening any installation where they remain.
-- pg_catalog remains implicitly searched for built-in functions and operators.
alter function if exists public.srk_submit_booking_quote(uuid, numeric, numeric, text)
  set search_path = '';
alter function if exists public.srk_customer_respond_booking_quote(uuid, text)
  set search_path = '';
alter function if exists public.srk_update_booking_work_status(uuid, text)
  set search_path = '';
