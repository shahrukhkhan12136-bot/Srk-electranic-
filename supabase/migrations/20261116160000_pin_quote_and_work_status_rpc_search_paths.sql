-- Pin only the active customer-approved work timer RPCs to an empty search_path.
-- Legacy quotation and direct work-status RPCs are retired and must not be recreated.
alter function public.srk_electrician_request_work_start(uuid) set search_path = '';
alter function public.srk_customer_respond_work_start(uuid,text) set search_path = '';
alter function public.srk_electrician_request_work_completion(uuid) set search_path = '';
alter function public.srk_customer_respond_work_completion(uuid,text,text) set search_path = '';
