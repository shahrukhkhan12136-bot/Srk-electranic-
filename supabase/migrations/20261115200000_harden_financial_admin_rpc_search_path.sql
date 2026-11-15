-- Remove writable/public schemas from SECURITY DEFINER financial mutation RPC search paths.
-- All application objects in these functions are schema-qualified; pg_catalog remains implicitly available.
alter function public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text)
  set search_path = '';
alter function public.srk_admin_record_manual_refund(uuid,text,text)
  set search_path = '';

-- Trigger-side payout calculation also runs as SECURITY DEFINER; pin its path
-- so caller-controlled schemas cannot shadow built-ins or application objects.
alter function public.srk_create_electrician_payable()
  set search_path = '';
