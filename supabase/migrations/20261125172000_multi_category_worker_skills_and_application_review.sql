-- Multi-category worker skills, per-skill review, application KYC review and eligibility.
create table if not exists public.srk_worker_application_skills(
 id uuid primary key default gen_random_uuid(),
 application_id uuid not null references public.srk_worker_applications(id) on delete cascade,
 skill_id uuid not null references public.srk_service_skills(id) on delete restrict,
 skill_level_id uuid references public.srk_skill_levels(id) on delete restrict,
 years_experience integer check(years_experience is null or years_experience between 0 and 60),
 evidence_document_id uuid references public.srk_worker_documents(id) on delete set null,
 status text not null default 'pending' check(status in ('pending','approved','rejected','more_info')),
 reviewed_by uuid references auth.users(id) on delete set null,
 reviewed_at timestamptz,
 admin_note text,
 created_at timestamptz not null default clock_timestamp(),
 updated_at timestamptz not null default clock_timestamp(),
 constraint srk_worker_application_skill_unique unique(application_id,skill_id),
 constraint srk_worker_application_skill_review_consistency check(
  (status='pending' and reviewed_at is null) or (status<>'pending' and reviewed_at is not null)
 ),
 constraint srk_approved_application_skill_requires_level check(status<>'approved' or skill_level_id is not null)
);
alter table public.srk_worker_application_skills enable row level security;
create index if not exists srk_worker_application_skills_application_status_idx
 on public.srk_worker_application_skills(application_id,status);
create index if not exists srk_worker_application_skills_skill_status_idx
 on public.srk_worker_application_skills(skill_id,status);
alter table public.srk_worker_skills add column if not exists years_experience integer
 check(years_experience is null or years_experience between 0 and 60);
alter table public.srk_worker_skills drop constraint if exists srk_approved_worker_skill_requires_level;
alter table public.srk_worker_application_skills drop constraint if exists srk_approved_application_skill_requires_level;
alter table public.srk_worker_skills drop constraint if exists srk_worker_skill_status_valid;
alter table public.srk_worker_skills add constraint srk_worker_skill_status_valid
 check(verification_status=any(array['pending','approved','rejected','more_info']::text[]));

alter table public.srk_worker_skills drop constraint if exists srk_worker_skill_review_consistency;
alter table public.srk_worker_skills add constraint srk_worker_skill_review_consistency check(
 (verification_status='pending' and reviewed_at is null) or (verification_status<>'pending' and reviewed_at is not null)
);

create or replace function srk_private.validate_worker_skill_category()
returns trigger language plpgsql set search_path=pg_catalog,public
as $function$
declare v_category_id uuid;v_level_count integer;
begin
 select st.category_id into v_category_id from public.srk_service_skills sk join public.srk_service_types st on st.id=sk.service_type_id
 where sk.id=new.skill_id and sk.is_active and st.is_active;
 if v_category_id is null then raise exception 'Skill or service category is inactive'; end if;
 select count(*) into v_level_count from public.srk_skill_levels where category_id=v_category_id and is_active;
 if new.skill_level_id is not null and not exists(select 1 from public.srk_skill_levels l where l.id=new.skill_level_id and l.category_id=v_category_id and l.is_active) then
  raise exception 'Skill level must belong to the skill category';
 end if;
 if new.verification_status='approved' and v_level_count>0 and new.skill_level_id is null then
  raise exception 'Approved skill requires a category-matched qualification level';
 end if;
 return new;
end;
$function$;

drop trigger if exists srk_worker_skills_validate_category on public.srk_worker_skills;
create trigger srk_worker_skills_validate_category before insert or update of skill_id,skill_level_id,verification_status
on public.srk_worker_skills for each row execute function srk_private.validate_worker_skill_category();

create or replace function srk_private.validate_worker_application_skill()
returns trigger language plpgsql set search_path=pg_catalog,public
as $function$
declare v_category_id uuid;v_level_count integer;
begin
 select st.category_id into v_category_id from public.srk_service_skills sk join public.srk_service_types st on st.id=sk.service_type_id
 where sk.id=new.skill_id and sk.is_active and st.is_active;
 if v_category_id is null then raise exception 'Skill or service category is inactive'; end if;
 select count(*) into v_level_count from public.srk_skill_levels where category_id=v_category_id and is_active;
 if new.skill_level_id is not null and not exists(select 1 from public.srk_skill_levels l where l.id=new.skill_level_id and l.category_id=v_category_id and l.is_active) then
  raise exception 'Skill level must belong to the selected skill category';
 end if;
 if new.status='approved' and v_level_count>0 and new.skill_level_id is null then raise exception 'Approved application skill requires a qualification level'; end if;
 if new.evidence_document_id is not null and not exists(select 1 from public.srk_worker_documents d where d.id=new.evidence_document_id and d.application_id=new.application_id) then
  raise exception 'Evidence document must belong to this application';
 end if;
 new.updated_at:=clock_timestamp();return new;
end;
$function$;

drop trigger if exists srk_worker_application_skills_validate on public.srk_worker_application_skills;
create trigger srk_worker_application_skills_validate before insert or update of skill_id,skill_level_id,status,evidence_document_id
on public.srk_worker_application_skills for each row execute function srk_private.validate_worker_application_skill();

create or replace function public.srk_worker_submit_application_skill(
 p_application_id uuid,p_skill_id uuid,p_skill_level_id uuid,p_years_experience integer default null,p_evidence_document_id uuid default null
) returns public.srk_worker_application_skills
language plpgsql security definer set search_path=pg_catalog,public,auth
as $function$
declare v_app public.srk_worker_applications%rowtype;v_skill public.srk_service_skills%rowtype;v_category_id uuid;v_level_count integer;v_result public.srk_worker_application_skills%rowtype;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='28000'; end if;
 select * into v_app from public.srk_worker_applications where id=p_application_id and user_id=auth.uid() for update;
 if not found then raise exception 'Application not found'; end if;
 if v_app.status not in ('pending','more_info') then raise exception 'Skills can only be changed while the application is pending or more information is requested'; end if;
 if p_years_experience is not null and p_years_experience not between 0 and 60 then raise exception 'Years of experience must be between 0 and 60'; end if;
 select * into v_skill from public.srk_service_skills where id=p_skill_id and is_active;
 if not found then raise exception 'Active skill not found'; end if;
 select st.category_id into v_category_id from public.srk_service_types st join public.srk_service_categories c on c.id=st.category_id
 where st.id=v_skill.service_type_id and st.is_active and c.is_active;
 if v_category_id is null then raise exception 'Skill service category is inactive'; end if;
 select count(*) into v_level_count from public.srk_skill_levels where category_id=v_category_id and is_active;
 if v_level_count>0 then
  if p_skill_level_id is null then raise exception 'This category requires a qualification level'; end if;
  if not exists(select 1 from public.srk_skill_levels where id=p_skill_level_id and category_id=v_category_id and is_active) then raise exception 'Skill level does not match the selected skill category'; end if;
 elsif p_skill_level_id is not null and not exists(select 1 from public.srk_skill_levels where id=p_skill_level_id and category_id=v_category_id and is_active) then
  raise exception 'Skill level does not match the selected skill category';
 end if;
 if p_evidence_document_id is not null and not exists(select 1 from public.srk_worker_documents where id=p_evidence_document_id and application_id=p_application_id) then raise exception 'Evidence document must belong to this application'; end if;
 insert into public.srk_worker_application_skills(application_id,skill_id,skill_level_id,years_experience,evidence_document_id,status)
 values(p_application_id,p_skill_id,p_skill_level_id,p_years_experience,p_evidence_document_id,'pending')
 on conflict(application_id,skill_id) do update set skill_level_id=excluded.skill_level_id,years_experience=excluded.years_experience,
  evidence_document_id=excluded.evidence_document_id,status='pending',reviewed_by=null,reviewed_at=null,admin_note=null,updated_at=clock_timestamp()
 returning * into v_result;
 return v_result;
end;
$function$;


create or replace function public.srk_admin_list_application_skills(p_application_id uuid)
returns table(
 application_skill_id uuid,skill_id uuid,skill_name text,service_type_id uuid,service_name text,
 category_id uuid,category_name text,skill_level_id uuid,skill_level_name text,
 years_experience integer,evidence_document_id uuid,status text,admin_note text,reviewed_at timestamptz
)
language plpgsql stable security definer
set search_path=pg_catalog,public,auth
as $function$
begin
 if auth.uid() is null or not public.srk_has_admin_permission('workers.verify') then
  raise exception 'Worker verification permission required' using errcode='42501';
 end if;
 if not exists(select 1 from public.srk_worker_applications where id=p_application_id) then raise exception 'Application not found'; end if;
 return query
 select aps.id,sk.id,sk.skill_name,st.id,st.service_name,c.id,c.category_name,l.id,l.level_name,
  aps.years_experience,aps.evidence_document_id,aps.status,aps.admin_note,aps.reviewed_at
 from public.srk_worker_application_skills aps
 join public.srk_service_skills sk on sk.id=aps.skill_id
 join public.srk_service_types st on st.id=sk.service_type_id
 join public.srk_service_categories c on c.id=st.category_id
 left join public.srk_skill_levels l on l.id=aps.skill_level_id
 where aps.application_id=p_application_id
 order by c.sort_order,st.sort_order,sk.sort_order,sk.skill_name;
end;
$function$;

create or replace function public.srk_admin_review_application_skill(p_application_skill_id uuid,p_decision text,p_skill_level_id uuid,p_note text default null)
returns public.srk_worker_application_skills language plpgsql security definer
set search_path=pg_catalog,public,auth
as $function$
declare v_aps public.srk_worker_application_skills%rowtype;v_app public.srk_worker_applications%rowtype;v_category_id uuid;v_level_count integer;
begin
 if auth.uid() is null or not public.srk_has_admin_permission('workers.verify') then raise exception 'Worker verification permission required' using errcode='42501'; end if;
 if p_decision not in ('approved','rejected','pending','more_info') then raise exception 'Invalid application skill decision' using errcode='22023'; end if;
 select * into v_aps from public.srk_worker_application_skills where id=p_application_skill_id for update;
 if not found then raise exception 'Application skill not found'; end if;
 select * into v_app from public.srk_worker_applications where id=v_aps.application_id for update;
 if v_app.status='approved' then raise exception 'Application is already approved; use the worker skill review workflow'; end if;
 select st.category_id into v_category_id from public.srk_service_skills sk join public.srk_service_types st on st.id=sk.service_type_id
 where sk.id=v_aps.skill_id and sk.is_active and st.is_active;
 if v_category_id is null then raise exception 'Skill is not active'; end if;
 select count(*) into v_level_count from public.srk_skill_levels where category_id=v_category_id and is_active;
 if p_decision='approved' and v_level_count>0 and p_skill_level_id is null then raise exception 'Approved skill requires a qualification level'; end if;
 if p_skill_level_id is not null and not exists(select 1 from public.srk_skill_levels where id=p_skill_level_id and category_id=v_category_id and is_active) then raise exception 'Skill level does not match selected skill category'; end if;
 update public.srk_worker_application_skills set status=p_decision,skill_level_id=coalesce(p_skill_level_id,skill_level_id),
  reviewed_by=case when p_decision='pending' then null else auth.uid() end,
  reviewed_at=case when p_decision='pending' then null else clock_timestamp() end,
  admin_note=p_note,updated_at=clock_timestamp()
 where id=p_application_skill_id returning * into v_aps;
 return v_aps;
end;
$function$;


create or replace function public.srk_worker_request_skill(p_skill_id uuid,p_skill_level_id uuid,p_years_experience integer)
returns public.srk_worker_skills language plpgsql security definer
set search_path=pg_catalog,public,auth
as $function$
declare v_worker public.srk_worker_profiles%rowtype;v_skill public.srk_service_skills%rowtype;v_category_id uuid;v_level_count integer;v_result public.srk_worker_skills%rowtype;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='28000'; end if;
 select * into v_worker from public.srk_worker_profiles where user_id=auth.uid() for update;
 if not found or v_worker.verification_status<>'approved' or not v_worker.is_active then raise exception 'Only an approved active worker can request an additional skill' using errcode='42501'; end if;
 if p_years_experience is not null and p_years_experience not between 0 and 60 then raise exception 'Years of experience must be between 0 and 60' using errcode='22023'; end if;
 select * into v_skill from public.srk_service_skills where id=p_skill_id and is_active;
 if not found then raise exception 'Active skill not found'; end if;
 select st.category_id into v_category_id from public.srk_service_types st join public.srk_service_categories c on c.id=st.category_id
 where st.id=v_skill.service_type_id and st.is_active and c.is_active;
 if v_category_id is null then raise exception 'Skill category is not active'; end if;
 select count(*) into v_level_count from public.srk_skill_levels where category_id=v_category_id and is_active;
 if v_level_count>0 then
  if p_skill_level_id is null then raise exception 'This category requires a qualification level'; end if;
  if not exists(select 1 from public.srk_skill_levels where id=p_skill_level_id and category_id=v_category_id and is_active) then raise exception 'Skill level does not match the selected skill category'; end if;
 elsif p_skill_level_id is not null and not exists(select 1 from public.srk_skill_levels where id=p_skill_level_id and category_id=v_category_id and is_active) then
  raise exception 'Skill level does not match the selected skill category';
 end if;
 insert into public.srk_worker_skills(worker_id,skill_id,skill_level_id,verification_status,years_experience)
 values(v_worker.id,p_skill_id,p_skill_level_id,'pending',p_years_experience)
 on conflict(worker_id,skill_id) do update set skill_level_id=excluded.skill_level_id,years_experience=excluded.years_experience,
  verification_status='pending',reviewed_by=null,reviewed_at=null,admin_note=null,updated_at=clock_timestamp()
 returning * into v_result;
 return v_result;
end;
$function$;


create or replace function public.srk_worker_request_skill(p_skill_id uuid,p_skill_level_id uuid)
returns public.srk_worker_skills
language sql security definer
set search_path=pg_catalog,public,auth
as $function$
 select public.srk_worker_request_skill(p_skill_id,p_skill_level_id,null::integer);
$function$;
create or replace function public.srk_admin_review_worker_skill(p_worker_skill_id uuid,p_decision text,p_skill_level_id uuid,p_note text default null)
returns public.srk_worker_skills language plpgsql security definer
set search_path=pg_catalog,public,auth
as $function$
declare v_skill public.srk_worker_skills%rowtype;v_category_id uuid;v_level_count integer;
begin
 if auth.uid() is null or not public.srk_has_admin_permission('workers.verify') then raise exception 'Worker verification permission required' using errcode='42501'; end if;
 if p_decision not in ('approved','rejected','pending','more_info') then raise exception 'Invalid skill decision' using errcode='22023'; end if;
 select * into v_skill from public.srk_worker_skills where id=p_worker_skill_id for update;
 if not found then raise exception 'Worker skill not found'; end if;
 select st.category_id into v_category_id from public.srk_service_skills sk join public.srk_service_types st on st.id=sk.service_type_id
 where sk.id=v_skill.skill_id and sk.is_active and st.is_active;
 if v_category_id is null then raise exception 'Skill is not active'; end if;
 select count(*) into v_level_count from public.srk_skill_levels where category_id=v_category_id and is_active;
 if p_decision='approved' and v_level_count>0 and p_skill_level_id is null then raise exception 'Approved skill requires a qualification level'; end if;
 if p_skill_level_id is not null and not exists(select 1 from public.srk_skill_levels where id=p_skill_level_id and category_id=v_category_id and is_active) then
  raise exception 'Skill level does not match the selected skill category';
 end if;
 update public.srk_worker_skills set verification_status=p_decision,skill_level_id=coalesce(p_skill_level_id,skill_level_id),
  reviewed_by=case when p_decision='pending' then null else auth.uid() end,
  reviewed_at=case when p_decision='pending' then null else clock_timestamp() end,
  admin_note=p_note,updated_at=clock_timestamp()
 where id=p_worker_skill_id returning * into v_skill;
 return v_skill;
end;
$function$;

CREATE OR REPLACE FUNCTION public.srk_find_eligible_workers(p_booking_id uuid, p_worker_type text)
 RETURNS TABLE(worker_id uuid, worker_code text, worker_type text, distance_km numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare
  v_booking public.service_bookings%rowtype;
  v_search_radius numeric;
  v_attempts integer;
  v_initial_radius numeric;
  v_expansion_step numeric;
  v_max_radius numeric;
begin
  if p_worker_type not in ('technician','helper') then
    raise exception 'Invalid worker type';
  end if;
  select * into v_booking from public.service_bookings where id=p_booking_id;
  if not found then raise exception 'Booking not found'; end if;

  select coalesce(q.attempts,0) into v_attempts
  from public.srk_booking_matching_queue q where q.booking_id=p_booking_id;

  select
    coalesce((v_booking.operational_settings_snapshot->>'initial_matching_radius_km')::numeric,
      (select (setting_value #>> '{}')::numeric from public.srk_system_settings where setting_key='initial_matching_radius_km'),30),
    coalesce((v_booking.operational_settings_snapshot->>'matching_radius_expansion_step_km')::numeric,
      (select (setting_value #>> '{}')::numeric from public.srk_system_settings where setting_key='matching_radius_expansion_step_km'),30),
    coalesce((v_booking.operational_settings_snapshot->>'maximum_matching_radius_km')::numeric,
      (select (setting_value #>> '{}')::numeric from public.srk_system_settings where setting_key='maximum_matching_radius_km'),200)
  into v_initial_radius,v_expansion_step,v_max_radius;

  v_search_radius:=least(v_max_radius,v_initial_radius+coalesce(v_attempts,0)*v_expansion_step);

  return query
  select w.id,w.worker_code,w.worker_type,
    case when v_booking.booking_latitude is null then null::numeric else
      round((6371*acos(least(1,greatest(-1,
        cos(radians(v_booking.booking_latitude))*cos(radians(w.location_lat))*cos(radians(w.location_lng)-radians(v_booking.booking_longitude))+
        sin(radians(v_booking.booking_latitude))*sin(radians(w.location_lat))
      ))))::numeric,2)
    end
  from public.srk_worker_profiles w
  where w.worker_type=p_worker_type
    and w.verification_status='approved' and w.is_active and w.is_online
    and (v_booking.booking_latitude is null or (w.location_lat is not null and w.location_lng is not null))
    and exists(
      select 1 from public.srk_worker_skills ws
      where ws.worker_id=w.id and ws.skill_id=v_booking.selected_skill_id
        and ws.verification_status='approved'
        and (coalesce(v_booking.higher_skill_consent_level_id,v_booking.requested_skill_level_id) is null
          or ws.skill_level_id=coalesce(v_booking.higher_skill_consent_level_id,v_booking.requested_skill_level_id))
    )
    and (
      (v_booking.booking_latitude is not null and
        (6371*acos(least(1,greatest(-1,
          cos(radians(v_booking.booking_latitude))*cos(radians(w.location_lat))*cos(radians(w.location_lng)-radians(v_booking.booking_longitude))+
          sin(radians(v_booking.booking_latitude))*sin(radians(w.location_lat))
        ))))<=least(v_search_radius,w.service_radius_km))
      or (v_booking.booking_latitude is null and
        (w.pincode=v_booking.pincode or
          (lower(trim(w.state))=lower(trim(v_booking.state)) and lower(trim(w.district))=lower(trim(v_booking.district)))))
    )
    and not exists(
      select 1 from public.srk_worker_work_sessions s
      where s.worker_id=w.id and s.session_status in ('running','paused')
    )
    and not exists(
      select 1 from public.srk_booking_workers bw
      where bw.worker_id=w.id and bw.assignment_status in ('working','paused')
    )
    -- Do not send new offers to a worker who has an accepted assignment
    -- that has not yet been given a customer-confirmed schedule.
    and not exists(
      select 1 from public.srk_booking_workers bw
      where bw.worker_id=w.id
        and bw.assignment_status in ('accepted','assigned')
        and not exists(
          select 1 from public.srk_worker_schedule_blocks sb
          where sb.booking_worker_id=bw.id
            and sb.block_status in ('reserved','confirmed','in_progress')
        )
    )
    and not exists(
      select 1 from public.srk_worker_schedule_blocks sb
      where sb.worker_id=w.id and sb.block_status in ('reserved','confirmed','in_progress')
        and sb.starts_at<=clock_timestamp()+make_interval(hours=>coalesce(v_booking.requested_duration_hours,1))
        and sb.ends_at>clock_timestamp()
    )
  order by
    case when v_booking.booking_latitude is null and w.pincode=v_booking.pincode then 0 else 1 end,
    4 nulls last,w.created_at;
end
$function$

CREATE OR REPLACE FUNCTION public.srk_admin_review_worker_application(p_application_id uuid, p_decision text, p_note text DEFAULT NULL::text)
 RETURNS srk_worker_profiles
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare v_app public.srk_worker_applications%rowtype; v_profile public.srk_worker_profiles%rowtype; v_approved_skill_count bigint;
begin
  if not public.srk_has_admin_permission('workers.verify') then raise exception 'Worker verification permission required'; end if;
  if p_decision not in ('approved','rejected','under_review','more_info') then raise exception 'Invalid application decision'; end if;
  select * into v_app from public.srk_worker_applications where id=p_application_id for update;
  if not found then raise exception 'Application not found'; end if;
  if v_app.status not in ('pending','under_review','more_info') then raise exception 'Application is not awaiting review'; end if;
  if p_decision in ('rejected','more_info','under_review') and length(btrim(coalesce(p_note,'')))<5 then raise exception 'A review note is required for this decision'; end if;
  if p_decision='approved' then
    if nullif(btrim(coalesce(v_app.photo_path,'')),'') is null then raise exception 'Applicant photo is required before approval'; end if;
    if not exists(select 1 from public.srk_worker_documents d where d.application_id=p_application_id and d.document_type='identity_proof' and d.review_status='approved') then raise exception 'An approved identity proof is required before approval'; end if;
    if exists(select 1 from public.srk_worker_documents d where d.application_id=p_application_id and d.review_status<>'approved') then raise exception 'Every submitted application document must be approved before application approval'; end if;
    select count(*) into v_approved_skill_count from public.srk_worker_application_skills aps where aps.application_id=p_application_id and aps.status='approved';
    if v_approved_skill_count=0 then raise exception 'At least one skill must be individually approved before worker approval'; end if;
  end if;
  select * into v_profile from public.srk_worker_profiles where user_id=v_app.user_id for update;
  if found and v_profile.worker_code is not null and (v_profile.category_id is distinct from v_app.category_id or v_profile.worker_type is distinct from v_app.worker_type) then raise exception 'Approved worker category/type cannot be changed because the permanent Worker ID is category-bound'; end if;
  update public.srk_worker_applications set status=p_decision,reviewed_by=auth.uid(),reviewed_at=clock_timestamp(),
    admin_note=p_note,updated_at=clock_timestamp() where id=p_application_id;
  if p_decision<>'approved' then return null; end if;

  insert into public.srk_worker_profiles(
    user_id,worker_type,full_name,phone,category_id,verification_status,is_active,
    father_name,date_of_birth,photo_path,address,state,district,pincode,experience_years
  ) values(
    v_app.user_id,v_app.worker_type,v_app.full_name,v_app.phone,v_app.category_id,'approved',true,
    v_app.father_name,v_app.date_of_birth,v_app.photo_path,v_app.address,v_app.state,v_app.district,
    v_app.pincode,v_app.experience_years
  )
  on conflict(user_id) do update set
    worker_type=excluded.worker_type,full_name=excluded.full_name,phone=excluded.phone,
    category_id=excluded.category_id,verification_status='approved',is_active=true,
    father_name=excluded.father_name,date_of_birth=excluded.date_of_birth,
    photo_path=excluded.photo_path,address=excluded.address,state=excluded.state,
    district=excluded.district,pincode=excluded.pincode,experience_years=excluded.experience_years,
    updated_at=clock_timestamp()
  returning * into v_profile;
  update public.srk_worker_documents set worker_id=v_profile.id where application_id=p_application_id and worker_id is null;
  insert into public.srk_worker_skills(worker_id,skill_id,skill_level_id,verification_status,reviewed_by,reviewed_at,admin_note,years_experience)
  select v_profile.id,aps.skill_id,aps.skill_level_id,'approved',auth.uid(),clock_timestamp(),aps.admin_note,aps.years_experience
  from public.srk_worker_application_skills aps where aps.application_id=p_application_id and aps.status='approved'
  on conflict(worker_id,skill_id) do update set skill_level_id=excluded.skill_level_id,verification_status='approved',
   reviewed_by=auth.uid(),reviewed_at=clock_timestamp(),admin_note=excluded.admin_note,years_experience=excluded.years_experience,updated_at=clock_timestamp();
  return v_profile;
end $function$
;
drop function if exists public.srk_admin_get_category_workforce_overview();
drop function if exists srk_private.get_admin_category_workforce_overview();
create or replace function srk_private.get_admin_category_workforce_overview()
returns table(
 category_id uuid,category_name text,worker_type text,
 total_applications bigint,pending_applications bigint,under_review_applications bigint,
 more_info_applications bigint,approved_applications bigint,rejected_applications bigint,withdrawn_applications bigint,
 application_skill_count bigint,application_skill_applicants bigint,pending_application_skill_applicants bigint,approved_application_skill_applicants bigint,
 total_skill_holders bigint,pending_skill_holders bigint,approved_skill_holders bigint,
 active_skill_holders bigint,inactive_skill_holders bigint,currently_working bigint,
 offers_sent bigint,offers_pending bigint,offers_accepted bigint,offers_rejected bigint,offers_expired bigint
)
language plpgsql stable security definer
set search_path=pg_catalog,public,auth,srk_private
as $function$
begin
 if auth.uid() is null or not public.is_srk_admin() then raise exception 'Main Admin permission required' using errcode='42501'; end if;
 return query
 with roles as (select 'technician'::text worker_type union all select 'helper'::text),
 apps as (
  select a.category_id,a.worker_type,count(*)::bigint total_applications,
   count(*) filter(where a.status='pending')::bigint pending_applications,
   count(*) filter(where a.status='under_review')::bigint under_review_applications,
   count(*) filter(where a.status='more_info')::bigint more_info_applications,
   count(*) filter(where a.status='approved')::bigint approved_applications,
   count(*) filter(where a.status='rejected')::bigint rejected_applications,
   count(*) filter(where a.status='withdrawn')::bigint withdrawn_applications
  from public.srk_worker_applications a group by a.category_id,a.worker_type
 ), application_skills as (
  select st.category_id,a.worker_type,count(*)::bigint application_skill_count,
   count(distinct a.id)::bigint application_skill_applicants,
   count(distinct a.id) filter(where aps.status in ('pending','more_info'))::bigint pending_application_skill_applicants,
   count(distinct a.id) filter(where aps.status='approved')::bigint approved_application_skill_applicants
  from public.srk_worker_application_skills aps
  join public.srk_worker_applications a on a.id=aps.application_id
  join public.srk_service_skills sk on sk.id=aps.skill_id and sk.is_active
  join public.srk_service_types st on st.id=sk.service_type_id and st.is_active
  group by st.category_id,a.worker_type
 ), skills as (
  select st.category_id,w.worker_type,count(distinct w.id)::bigint total_skill_holders,
   count(distinct w.id) filter(where ws.verification_status in ('pending','more_info'))::bigint pending_skill_holders,
   count(distinct w.id) filter(where ws.verification_status='approved')::bigint approved_skill_holders,
   count(distinct w.id) filter(where ws.verification_status='approved' and w.is_active)::bigint active_skill_holders,
   count(distinct w.id) filter(where ws.verification_status='approved' and not w.is_active)::bigint inactive_skill_holders
  from public.srk_worker_skills ws
  join public.srk_service_skills sk on sk.id=ws.skill_id and sk.is_active
  join public.srk_service_types st on st.id=sk.service_type_id and st.is_active
  join public.srk_worker_profiles w on w.id=ws.worker_id and w.worker_type in ('technician','helper')
  group by st.category_id,w.worker_type
 ), offers as (
  select b.category_id,w.worker_type,count(*)::bigint offers_sent,
   count(*) filter(where bw.assignment_status='offered' and (bw.offer_expires_at is null or bw.offer_expires_at>=statement_timestamp()))::bigint offers_pending,
   count(*) filter(where bw.accepted_at is not null or bw.assignment_status in ('accepted','assigned','working','paused','completed'))::bigint offers_accepted,
   count(*) filter(where bw.rejected_at is not null or bw.assignment_status='rejected')::bigint offers_rejected,
   count(*) filter(where bw.assignment_status='offered' and bw.offer_expires_at<statement_timestamp())::bigint offers_expired,
   count(distinct w.id) filter(where bw.assignment_status in ('working','paused'))::bigint currently_working
  from public.srk_booking_workers bw join public.service_bookings b on b.id=bw.booking_id join public.srk_worker_profiles w on w.id=bw.worker_id
  group by b.category_id,w.worker_type
 )
 select c.id,c.category_name,r.worker_type,
  coalesce(a.total_applications,0),coalesce(a.pending_applications,0),coalesce(a.under_review_applications,0),
  coalesce(a.more_info_applications,0),coalesce(a.approved_applications,0),coalesce(a.rejected_applications,0),coalesce(a.withdrawn_applications,0),
  coalesce(asg.application_skill_count,0),coalesce(asg.application_skill_applicants,0),coalesce(asg.pending_application_skill_applicants,0),coalesce(asg.approved_application_skill_applicants,0),
  coalesce(s.total_skill_holders,0),coalesce(s.pending_skill_holders,0),coalesce(s.approved_skill_holders,0),
  coalesce(s.active_skill_holders,0),coalesce(s.inactive_skill_holders,0),coalesce(o.currently_working,0),
  coalesce(o.offers_sent,0),coalesce(o.offers_pending,0),coalesce(o.offers_accepted,0),coalesce(o.offers_rejected,0),coalesce(o.offers_expired,0)
 from public.srk_service_categories c cross join roles r
 left join apps a on a.category_id=c.id and a.worker_type=r.worker_type
 left join application_skills asg on asg.category_id=c.id and asg.worker_type=r.worker_type
 left join skills s on s.category_id=c.id and s.worker_type=r.worker_type
 left join offers o on o.category_id=c.id and o.worker_type=r.worker_type
 where c.is_active order by c.sort_order,c.category_name,r.worker_type;
end;
$function$;
create or replace function public.srk_admin_get_category_workforce_overview()
returns table(
 category_id uuid,category_name text,worker_type text,
 total_applications bigint,pending_applications bigint,under_review_applications bigint,
 more_info_applications bigint,approved_applications bigint,rejected_applications bigint,withdrawn_applications bigint,
 application_skill_count bigint,application_skill_applicants bigint,pending_application_skill_applicants bigint,approved_application_skill_applicants bigint,
 total_skill_holders bigint,pending_skill_holders bigint,approved_skill_holders bigint,
 active_skill_holders bigint,inactive_skill_holders bigint,currently_working bigint,
 offers_sent bigint,offers_pending bigint,offers_accepted bigint,offers_rejected bigint,offers_expired bigint
)
language sql stable security invoker set search_path=pg_catalog,public,auth,srk_private
as $function$ select * from srk_private.get_admin_category_workforce_overview(); $function$;

drop function if exists public.srk_admin_list_category_applications(uuid,text,text,integer);
drop function if exists srk_private.list_admin_category_applications(uuid,text,text,integer);
create or replace function srk_private.list_admin_category_applications(
 p_category_id uuid,p_worker_type text,p_status text default 'pending',p_limit integer default 200
)
returns table(
 application_id uuid,user_id uuid,worker_type text,full_name text,phone text,state text,district text,pincode text,
 experience_years integer,about text,status text,created_at timestamptz,reviewed_at timestamptz,admin_note text,
 document_count bigint,document_review_statuses text[],skill_count bigint,skill_summary jsonb
)
language plpgsql stable security definer set search_path=pg_catalog,public,auth,srk_private
as $function$
begin
 if auth.uid() is null or not public.is_srk_admin() then raise exception 'Main Admin permission required' using errcode='42501'; end if;
 if p_category_id is null or p_worker_type is null or p_worker_type not in ('technician','helper') then raise exception 'Category and valid worker type are required' using errcode='22023'; end if;
 if p_status is null or p_status not in ('all','pending','under_review','more_info','approved','rejected','withdrawn') then raise exception 'Unsupported application status filter' using errcode='22023'; end if;
 return query
 select a.id,a.user_id,a.worker_type,a.full_name,a.phone,a.state,a.district,a.pincode,a.experience_years,a.about,a.status,a.created_at,a.reviewed_at,a.admin_note,
  coalesce(d.document_count,0),coalesce(d.review_statuses,array[]::text[]),
  coalesce(s.skill_count,0),coalesce(s.skill_summary,'[]'::jsonb)
 from public.srk_worker_applications a
 left join lateral(
  select count(*)::bigint document_count,array_agg(distinct wd.review_status order by wd.review_status) review_statuses
  from public.srk_worker_documents wd where wd.application_id=a.id
 ) d on true
 left join lateral(
  select count(*)::bigint skill_count,
   coalesce(jsonb_agg(jsonb_build_object('application_skill_id',aps.id,'skill_id',sk.id,'skill_name',sk.skill_name,
    'service_name',st.service_name,'category_name',c.category_name,'skill_level_name',sl.level_name,
    'years_experience',aps.years_experience,'status',aps.status,'admin_note',aps.admin_note)
    order by c.sort_order,st.sort_order,sk.sort_order),'[]'::jsonb) skill_summary
  from public.srk_worker_application_skills aps
  join public.srk_service_skills sk on sk.id=aps.skill_id
  join public.srk_service_types st on st.id=sk.service_type_id
  join public.srk_service_categories c on c.id=st.category_id
  left join public.srk_skill_levels sl on sl.id=aps.skill_level_id
  where aps.application_id=a.id
 ) s on true
 where a.category_id=p_category_id and a.worker_type=p_worker_type
  and (p_status='all' or (p_status='pending' and a.status in ('pending','under_review','more_info')) or (p_status not in ('all','pending') and a.status=p_status))
 order by a.created_at desc limit least(greatest(coalesce(p_limit,200),1),500);
end;
$function$;
create or replace function public.srk_admin_list_category_applications(
 p_category_id uuid,p_worker_type text,p_status text default 'pending',p_limit integer default 200
)
returns table(
 application_id uuid,user_id uuid,worker_type text,full_name text,phone text,state text,district text,pincode text,
 experience_years integer,about text,status text,created_at timestamptz,reviewed_at timestamptz,admin_note text,
 document_count bigint,document_review_statuses text[],skill_count bigint,skill_summary jsonb
)
language sql stable security invoker set search_path=pg_catalog,public,auth,srk_private
as $function$ select * from srk_private.list_admin_category_applications(p_category_id,p_worker_type,p_status,p_limit); $function$;

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
 if auth.uid() is null or not public.is_srk_admin() then raise exception 'Main Admin permission required' using errcode='42501'; end if;
 if p_category_id is null or p_worker_type is null or p_worker_type not in ('technician','helper')
    or p_status is null or p_status not in ('all','pending','approved','active','inactive','working') then
  raise exception 'Category, role and status filter are required' using errcode='22023';
 end if;
 if not exists(select 1 from public.srk_service_categories where id=p_category_id and is_active) then raise exception 'Active service category not found'; end if;
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
 join public.srk_service_categories c on c.id=st.category_id and c.id=p_category_id and c.is_active
 left join public.srk_skill_levels sl on sl.id=ws.skill_level_id
 where w.worker_type=p_worker_type
  and case p_status
   when 'pending' then ws.verification_status in ('pending','more_info')
   when 'approved' then ws.verification_status='approved'
   when 'active' then ws.verification_status='approved' and w.is_active
   when 'inactive' then ws.verification_status='approved' and not w.is_active
   when 'working' then exists(select 1 from public.srk_booking_workers bw
     where bw.worker_id=w.id and bw.assignment_status in ('working','paused'))
   else true
  end
 group by w.id,w.worker_code,w.full_name,w.worker_type,w.phone,w.state,w.district,w.pincode,
  w.verification_status,w.is_active,w.is_online,w.experience_years
 order by w.full_name limit greatest(1,least(coalesce(p_limit,500),1000));
end;
$function$;
create or replace function public.srk_admin_list_category_skill_workers(
 p_category_id uuid,p_worker_type text,p_status text default 'all',p_limit integer default 500
) returns table(
 worker_id uuid,worker_code text,full_name text,worker_type text,phone text,
 state text,district text,pincode text,profile_status text,is_active boolean,is_online boolean,
 experience_years integer,service_names text[],skill_names text[],skill_levels text[],skill_statuses text[]
)
language sql stable security invoker set search_path=pg_catalog,public,auth,srk_private
as $function$ select * from srk_private.list_admin_category_skill_workers(p_category_id,p_worker_type,p_status,p_limit); $function$;

drop trigger if exists srk_worker_application_skills_audit on public.srk_worker_application_skills;
create trigger srk_worker_application_skills_audit after insert or update or delete on public.srk_worker_application_skills
for each row execute function public.srk_log_admin_entity_change('worker_application_skill');

revoke all on function public.srk_worker_submit_application_skill(uuid,uuid,uuid,integer,uuid) from public,anon;
grant execute on function public.srk_worker_submit_application_skill(uuid,uuid,uuid,integer,uuid) to authenticated;
revoke all on function public.srk_admin_list_application_skills(uuid) from public,anon;
grant execute on function public.srk_admin_list_application_skills(uuid) to authenticated;
revoke all on function public.srk_worker_request_skill(uuid,uuid,integer) from public,anon;
grant execute on function public.srk_worker_request_skill(uuid,uuid,integer) to authenticated;

revoke all on function public.srk_worker_request_skill(uuid,uuid,integer) from public,anon;
grant execute on function public.srk_worker_request_skill(uuid,uuid,integer) to authenticated;
revoke all on function srk_private.get_admin_category_workforce_overview() from public,anon,authenticated;
grant execute on function srk_private.get_admin_category_workforce_overview() to authenticated;
revoke all on function public.srk_admin_get_category_workforce_overview() from public,anon;
grant execute on function public.srk_admin_get_category_workforce_overview() to authenticated;
revoke all on function srk_private.list_admin_category_applications(uuid,text,text,integer) from public,anon,authenticated;
grant execute on function srk_private.list_admin_category_applications(uuid,text,text,integer) to authenticated;
revoke all on function public.srk_admin_list_category_applications(uuid,text,text,integer) from public,anon;
grant execute on function public.srk_admin_list_category_applications(uuid,text,text,integer) to authenticated;
do $verify_multi$
begin
 if not exists(select 1 from information_schema.columns where table_schema='public' and table_name='srk_worker_skills' and column_name='years_experience') then
  raise exception 'Worker skill experience column missing';
 end if;
 if not exists(select 1 from information_schema.tables where table_schema='public' and table_name='srk_worker_application_skills') then
  raise exception 'Application skills table missing';
 end if;
 if exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'
  and p.proname='srk_find_eligible_workers' and pg_get_functiondef(p.oid) ilike '%w.category_id=v_booking.category_id%') then
  raise exception 'Primary-category restriction remains in worker eligibility';
 end if;
end;
$verify_multi$;
