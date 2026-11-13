-- Trigger-only helper must not be callable through the PostgREST RPC surface.
REVOKE ALL ON FUNCTION public.srk_guard_work_approval_transitions() FROM PUBLIC,anon,authenticated;
