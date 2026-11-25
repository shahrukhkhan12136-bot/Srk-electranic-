-- Complete category workforce counts and pending-application drilldown.
create or replace function srk_private.get_admin_category_workforce_overview()
returns table(
 category_id uuid,category_name text,worker_type text,
 total_applications bigint,pending_applications bigint,under_review_applications bigint,
 more_info_applications bigint,approved_applications bigint,rejected_applications bigint,withdrawn_applications bigint,
 total_skill_holders bigint,pending_skill_holders bigint,approved_skill_holders bigint,
 active_skill_holders bigint,inactive_skill_holders bigint,currently_working bigint,
 offers_sent bigint,offers_pending bigint,offers_accepted bigint,offers_rejected bigint,offers_expired bigint
)
language plpgsql
stable
security definer
set search_path=pg_catalog,public,auth,srk_private
as $function$
begin
 if auth.uid() is null or not public.is_srk_admin() then
  raise exception 'Main Admin permission required' using errcode='42501';
 end if;
 return query
 with roles as (
  select 'technician'::text as worker_type union all select 'helper'::text
 ), apps as (
  select a.category_id,a.worker_type,
   count(*)::bigint total_applications,
   count(*) filter(where a.status='pending')::bigint pending_applications,
   count(*) filter(where a.status='under_review')::bigint under_review_applications,
   count(*) filter(where a.status='more_info')::bigint more_info_applications,
   count(*) filter(where a.status='approved')::bigint approved_applications,
   count(*) filter(where a.status='rejected')::bigint rejected_applications,
   count(*) filter(where a.status='withdrawn')::bigint withdrawn_applications
  from public.srk_worker_applications a
  group by a.category_id,a.worker_type
 ), skills as (
  select st.category_id,w.worker_type,
   count(distinct w.id)::bigint total_skill_holders,
   count(distinct w.id) filter(where ws.verification_status='pending')::bigint pending_skill_holders,
   count(distinct w.id) filter(where ws.verification_status='approved')::bigint approved_skill_holders,
   count(distinct w.id) filter(where ws.verification_status='approved' and w.is_active)::bigint active_skill_holders,
   count(distinct w.id) filter(where ws.verification_status='approved' and not w.is_active)::bigint inactive_skill_holders
  from public.srk_worker_skills ws
  join public.srk_service_skills sk on sk.id=ws.skill_id and sk.is_active
  join public.srk_service_types st on st.id=sk.service_type_id and st.is_active
  join public.srk_worker_profiles w on w.id=ws.worker_id and w.worker_type in ('technician','helper')
  where ws.is_active
  group by st.category_id,w.worker_type
 ), offers as (
  select b.category_id,w.worker_type,
   count(*)::bigint offers_sent,
   count(*) filter(where bw.assignment_status='offered' and (bw.offer_expires_at is null or bw.offer_expires_at>=statement_timestamp()))::bigint offers_pending,
   count(*) filter(where bw.accepted_at is not null or bw.assignment_status in ('accepted','assigned','working','paused','completed'))::bigint offers_accepted,
   count(*) filter(where bw.rejected_at is not null or bw.assignment_status='rejected')::bigint offers_rejected,
   count(*) filter(where bw.assignment_status='offered' and bw.offer_expires_at<statement_timestamp())::bigint offers_expired,
   count(distinct w.id) filter(where bw.assignment_status in ('working','paused'))::bigint currently_working
  from public.srk_booking_workers bw
  join public.service_bookings b on b.id=bw.booking_id
  join public.srk_worker_profiles w on w.id=bw.worker_id
  group by b.category_id,w.worker_type
 )
 select c.id,c.category_name,r.worker_type,
  coalesce(a.total_applications,0),coalesce(a.pending_applications,0),coalesce(a.under_review_applications,0),
  coalesce(a.more_info_applications,0),coalesce(a.approved_applications,0),coalesce(a.rejected_applications,0),coalesce(a.withdrawn_applications,0),
  coalesce(s.total_skill_holders,0),coalesce(s.pending_skill_holders,0),coalesce(s.approved_skill_holders,0),
  coalesce(s.active_skill_holders,0),coalesce(s.inactive_skill_holders,0),coalesce(o.currently_working,0),
  coalesce(o.offers_sent,0),coalesce(o.offers_pending,0),coalesce(o.offers_accepted,0),coalesce(o.offers_rejected,0),coalesce(o.offers_expired,0)
 from public.srk_service_categories c
 cross join roles r
 left join apps a on a.category_id=c.id and a.worker_type=r.worker_type
 left join skills s on s.category_id=c.id and s.worker_type=r.worker_type
 left join offers o on o.category_id=c.id and o.worker_type=r.worker_type
 where c.is_active
 order by c.sort_order,c.category_name,r.worker_type;
end;
$function$;

create or replace function public.srk_admin_get_category_workforce_overview()
returns table(
 category_id uuid,category_name text,worker_type text,
 total_applications bigint,pending_applications bigint,under_review_applications bigint,
 more_info_applications bigint,approved_applications bigint,rejected_applications bigint,withdrawn_applications bigint,
 total_skill_holders bigint,pending_skill_holders bigint,approved_skill_holders bigint,
 active_skill_holders bigint,inactive_skill_holders bigint,currently_working bigint,
 offers_sent bigint,offers_pending bigint,offers_accepted bigint,offers_rejected bigint,offers_expired bigint
)
language sql
stable
security invoker
set search_path=pg_catalog,public,auth,srk_private
as $function$
 select * from srk_private.get_admin_category_workforce_overview();
$function$;

create or replace function srk_private.list_admin_category_applications(
 p_category_id uuid,p_worker_type text,p_status text default 'pending',p_limit integer default 200
)
returns table(
 application_id uuid,user_id uuid,worker_type text,full_name text,phone text,
 state text,district text,pincode text,experience_years integer,about text,status text,
 created_at timestamptz,reviewed_at timestamptz,admin_note text,
 document_count bigint,document_review_statuses text[]
)
language plpgsql
stable
security definer
set search_path=pg_catalog,public,auth,srk_private
as $function$
begin
 if auth.uid() is null or not public.is_srk_admin() then
  raise exception 'Main Admin permission required' using errcode='42501';
 end if;
 if p_category_id is null or p_worker_type not in ('technician','helper') then
  raise exception 'Category and valid worker type are required' using errcode='22023';
 end if;
 if p_status not in ('all','pending','under_review','more_info','approved','rejected','withdrawn') then
  raise exception 'Unsupported application status filter' using errcode='22023';
 end if;
 return query
 select a.id,a.user_id,a.worker_type,a.full_name,a.phone,a.state,a.district,a.pincode,
  a.experience_years,a.about,a.status,a.created_at,a.reviewed_at,a.admin_note,
  coalesce(d.document_count,0),coalesce(d.review_statuses,array[]::text[])
 from public.srk_worker_applications a
 left join lateral (
  select count(*)::bigint document_count,array_agg(distinct wd.review_status order by wd.review_status) review_statuses
  from public.srk_worker_documents wd where wd.application_id=a.id
 ) d on true
 where a.category_id=p_category_id and a.worker_type=p_worker_type
  and (p_status='all'
    or (p_status='pending' and a.status in ('pending','under_review','more_info'))
    or (p_status not in ('all','pending') and a.status=p_status))
 order by a.created_at desc
 limit least(greatest(coalesce(p_limit,200),1),500);
end;
$function$;

create or replace function public.srk_admin_list_category_applications(
 p_category_id uuid,p_worker_type text,p_status text default 'pending',p_limit integer default 200
)
returns table(
 application_id uuid,user_id uuid,worker_type text,full_name text,phone text,
 state text,district text,pincode text,experience_years integer,about text,status text,
 created_at timestamptz,reviewed_at timestamptz,admin_note text,
 document_count bigint,document_review_statuses text[]
)
language sql
stable
security invoker
set search_path=pg_catalog,public,auth,srk_private
as $function$
 select * from srk_private.list_admin_category_applications(p_category_id,p_worker_type,p_status,p_limit);
$function$;

revoke all on function srk_private.get_admin_category_workforce_overview() from public,anon,authenticated;
grant execute on function srk_private.get_admin_category_workforce_overview() to authenticated;
revoke all on function public.srk_admin_get_category_workforce_overview() from public,anon;
grant execute on function public.srk_admin_get_category_workforce_overview() to authenticated;
revoke all on function srk_private.list_admin_category_applications(uuid,text,text,integer) from public,anon,authenticated;
grant execute on function srk_private.list_admin_category_applications(uuid,text,text,integer) to authenticated;
revoke all on function public.srk_admin_list_category_applications(uuid,text,text,integer) from public,anon;
grant execute on function public.srk_admin_list_category_applications(uuid,text,text,integer) to authenticated;
