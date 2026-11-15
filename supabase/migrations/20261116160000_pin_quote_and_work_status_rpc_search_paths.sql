-- These SECURITY DEFINER RPCs schema-qualify all application/auth objects.
-- pg_catalog remains implicitly searched for built-in functions and operators.
alter function public.srk_submit_booking_quote(uuid, numeric, numeric, text)
  set search_path = '';
alter function public.srk_customer_respond_booking_quote(uuid, text)
  set search_path = '';
alter function public.srk_update_booking_work_status(uuid, text)
  set search_path = '';
