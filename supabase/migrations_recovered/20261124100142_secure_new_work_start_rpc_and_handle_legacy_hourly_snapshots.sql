ALTER FUNCTION public.srk_worker_request_work_start_approval(uuid) SECURITY DEFINER;
REVOKE ALL ON FUNCTION public.srk_worker_request_work_start_approval(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_worker_request_work_start_approval(uuid) TO authenticated;