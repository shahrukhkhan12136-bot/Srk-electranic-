create or replace function srk_private.get_admin_category_skill_counts_v2()
returns table(
  category_id uuid,category_name text,worker_type text,
  total_skill_holders bigint,pending_skill_holders bigint,
  approved_skill_holders bigint,active_skill_holders bigint,
  inactive_skill_holders bigint,currently_working bigint
)
language plpgsql stable security definer
set search_path=pg_catalog,public,auth,srk_private
as $function$
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'Main Admin permission required' using errcode='42501';
  end if;
  return query
  select c.id,c.category_name,roles.worker_type,
    count(distinct w.id)::bigint,
    (count(distinct w.id) filter(where ws.verification_status in ('pending','submitted','under_review')))::bigint,
    (count(distinct w.id) filter(where ws.verification_status in ('approved','verified')))::bigint,
    (count(distinct w.id) filter(where ws.verification_status in ('approved','verified') and w.is_active))::bigint,
    (count(distinct w.id) filter(where ws.verification_status in ('approved','verified') and not w.is_active))::bigint,
    (count(distinct w.id) filter(where exists(
      select 1 from public.srk_booking_workers bw
      join public.service_bookings b on b.id=bw.booking_id
      where bw.worker_id=w.id
        and bw.assignment_status in ('accepted','assigned','working','paused')
        and b.status not in ('completed','cancelled','rejected')
    )))::bigint
  from public.srk_service_categories c
  cross join (values('technician'::text),('helper'::text)) roles(worker_type)
  left join public.srk_service_types st on st.category_id=c.id and st.is_active
  left join public.srk_service_skills sk on sk.service_type_id=st.id and sk.is_active
  left join public.srk_worker_skills ws on ws.skill_id=sk.id
  left join public.srk_worker_profiles w on w.id=ws.worker_id and w.worker_type=roles.worker_type
  where c.is_active
  group by c.id,c.category_name,c.sort_order,roles.worker_type
  order by c.sort_order,roles.worker_type;
end;
$function$;

create or replace function srk_private.list_admin_category_skill_workers(
  p_category_id uuid,p_worker_type text,p_status text default 'all',p_limit integer default 500
) returns table(
  worker_id uuid,worker_code text,full_name text,worker_type text,phone text,
  state text,district text,pincode text,profile_status text,is_active boolean,is_online boolean,
  experience_years integer,service_names text[],skill_names text[],skill_levels text[],skill_statuses text[]
)
language plpgsql stable security definer
set search_path=pg_catalog,public,auth,srk_private
as $function$
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'Main Admin permission required' using errcode='42501';
  end if;
  if p_category_id is null or p_worker_type not in ('technician','helper')
     or p_status not in ('all','pending','approved','active','inactive','working') then
    raise exception 'Category, role and status filter are required' using errcode='22023';
  end if;
  if not exists(select 1 from public.srk_service_categories where id=p_category_id and is_active) then
    raise exception 'Active service category not found';
  end if;

  return query
  select w.id,w.worker_code,w.full_name,w.worker_type,w.phone,w.state,w.district,w.pincode,
    w.verification_status,w.is_active,w.is_online,w.experience_years,
    coalesce(array_agg(distinct st.service_name) filter(where st.service_name is not null),array[]::text[]),
    coalesce(array_agg(distinct sk.skill_name) filter(where sk.skill_name is not null),array[]::text[]),
    coalesce(array_agg(distinct sl.level_name) filter(where sl.level_name is not null),array[]::text[]),
    coalesce(array_agg(distinct ws.verification_status) filter(where ws.verification_status is not null),array[]::text[])
  from public.srk_worker_profiles w
  join public.srk_worker_skills ws on ws.worker_id=w.id
  join public.srk_service_skills sk on sk.id=ws.skill_id and sk.is_active
  join public.srk_service_types st on st.id=sk.service_type_id and st.is_active
  join public.srk_service_categories c on c.id=st.category_id and c.id=p_category_id
  left join public.srk_skill_levels sl on sl.id=ws.skill_level_id
  where w.worker_type=p_worker_type
    and case p_status
      when 'pending' then ws.verification_status in ('pending','submitted','under_review')
      when 'approved' then ws.verification_status in ('approved','verified')
      when 'active' then ws.verification_status in ('approved','verified') and w.is_active
      when 'inactive' then ws.verification_status in ('approved','verified') and not w.is_active
      when 'working' then exists(
        select 1 from public.srk_booking_workers bw
        join public.service_bookings b on b.id=bw.booking_id
        where bw.worker_id=w.id and bw.assignment_status in ('accepted','assigned','working','paused')
          and b.status not in ('completed','cancelled','rejected')
      )
      else true
    end
  group by w.id,w.worker_code,w.full_name,w.worker_type,w.phone,w.state,w.district,w.pincode,
    w.verification_status,w.is_active,w.is_online,w.experience_years
  order by w.full_name
  limit greatest(1,least(coalesce(p_limit,500),1000));
end;
$function$;

revoke all on function srk_private.get_admin_category_skill_counts_v2() from public,anon;
revoke all on function srk_private.list_admin_category_skill_workers(uuid,text,text,integer) from public,anon;
grant execute on function srk_private.get_admin_category_skill_counts_v2() to authenticated;
grant execute on function srk_private.list_admin_category_skill_workers(uuid,text,text,integer) to authenticated;

create or replace function public.srk_admin_get_category_skill_counts_v2()
returns table(
  category_id uuid,category_name text,worker_type text,
  total_skill_holders bigint,pending_skill_holders bigint,
  approved_skill_holders bigint,active_skill_holders bigint,
  inactive_skill_holders bigint,currently_working bigint
)
language sql stable security invoker set search_path=pg_catalog,public
as $function$ select * from srk_private.get_admin_category_skill_counts_v2(); $function$;

create or replace function public.srk_admin_list_category_skill_workers(
  p_category_id uuid,p_worker_type text,p_status text default 'all',p_limit integer default 500
) returns table(
  worker_id uuid,worker_code text,full_name text,worker_type text,phone text,
  state text,district text,pincode text,profile_status text,is_active boolean,is_online boolean,
  experience_years integer,service_names text[],skill_names text[],skill_levels text[],skill_statuses text[]
)
language sql stable security invoker set search_path=pg_catalog,public
as $function$ select * from srk_private.list_admin_category_skill_workers(p_category_id,p_worker_type,p_status,p_limit); $function$;

revoke all on function public.srk_admin_get_category_skill_counts_v2() from public,anon;
revoke all on function public.srk_admin_list_category_skill_workers(uuid,text,text,integer) from public,anon;
grant execute on function public.srk_admin_get_category_skill_counts_v2() to authenticated;
grant execute on function public.srk_admin_list_category_skill_workers(uuid,text,text,integer) to authenticated;
