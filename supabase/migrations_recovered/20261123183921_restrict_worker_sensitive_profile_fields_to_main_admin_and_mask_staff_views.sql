
drop policy if exists srk_worker_profile_self_read on public.srk_worker_profiles;
create policy srk_worker_profile_self_read
on public.srk_worker_profiles for select to authenticated
using (user_id=auth.uid());

create or replace function public.srk_admin_list_workers_masked(p_limit integer default 100)
returns table(
 worker_id uuid,worker_code text,worker_type text,full_name text,masked_phone text,
 category_id uuid,verification_status text,is_active boolean,is_online boolean,
 state text,district text,pincode text,service_radius_km numeric,experience_years integer,
 has_helper boolean,masked_upi_id text,bank_account_last4 text,
 payout_details_change_status text,created_at timestamptz
)
language plpgsql
stable
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
begin
 if auth.uid() is null or not (
   public.srk_has_admin_permission('workers.verify') or public.srk_has_admin_permission('workers.manage')
 ) then raise exception 'Worker verification/management permission required' using errcode='42501'; end if;
 return query
 select w.id,w.worker_code,w.worker_type,w.full_name,
   case when w.phone is null then null else '******'||right(w.phone,4) end,
   w.category_id,w.verification_status,w.is_active,w.is_online,
   w.state,w.district,w.pincode,w.service_radius_km,w.experience_years,w.has_helper,
   case when w.upi_id is null then null
     else left(split_part(w.upi_id,'@',1),2)||'***@'||split_part(w.upi_id,'@',2) end,
   w.bank_account_last4,w.payout_details_change_status,w.created_at
 from public.srk_worker_profiles w
 order by w.created_at desc limit greatest(1,least(coalesce(p_limit,100),500));
end
$function$;
revoke all on function public.srk_admin_list_workers_masked(integer) from public,anon;
grant execute on function public.srk_admin_list_workers_masked(integer) to authenticated;

create or replace function public.srk_admin_get_worker_full_profile(p_worker_id uuid)
returns public.srk_worker_profiles
language plpgsql
stable
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare v public.srk_worker_profiles%rowtype;
begin
 if auth.uid() is null or not public.is_srk_admin() then
   raise exception 'Main Admin permission required' using errcode='42501';
 end if;
 select * into v from public.srk_worker_profiles where id=p_worker_id;
 if not found then raise exception 'Worker profile not found'; end if;
 return v;
end
$function$;
revoke all on function public.srk_admin_get_worker_full_profile(uuid) from public,anon;
grant execute on function public.srk_admin_get_worker_full_profile(uuid) to authenticated;
