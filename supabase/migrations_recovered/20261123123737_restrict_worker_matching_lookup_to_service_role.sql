begin;
revoke all on function public.srk_find_eligible_workers(uuid,text) from public, anon, authenticated;
grant execute on function public.srk_find_eligible_workers(uuid,text) to service_role;
commit;