-- Retire an orphaned legacy job-acceptance RPC from the main database.
-- Current Electrician Portal uses public.srk_respond_to_offer(uuid,text).
-- Verified before removal: no current Customer/Admin/Electrician page, Netlify
-- function, or deployed Supabase Edge Function calls this RPC; no dependent
-- database object was found; EXECUTE was restricted to postgres/service_role.
-- Intentionally omit CASCADE so any newly discovered dependency blocks removal.

drop function public.accept_electrician_job(uuid);
