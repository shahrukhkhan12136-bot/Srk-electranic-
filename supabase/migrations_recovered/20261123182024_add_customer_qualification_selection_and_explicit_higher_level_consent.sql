
alter table public.service_bookings
  add column if not exists requested_skill_level_id uuid references public.srk_skill_levels(id) on delete restrict,
  add column if not exists higher_skill_consent_level_id uuid references public.srk_skill_levels(id) on delete restrict,
  add column if not exists higher_skill_consent_at timestamptz,
  add column if not exists higher_skill_consent_by uuid;

create table if not exists public.srk_booking_skill_level_events (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.service_bookings(id) on delete restrict,
  actor_user_id uuid not null,
  event_type text not null check (event_type in ('requested_level_selected','higher_level_offered','higher_level_consented','higher_level_consent_revoked')),
  from_skill_level_id uuid references public.srk_skill_levels(id) on delete restrict,
  to_skill_level_id uuid references public.srk_skill_levels(id) on delete restrict,
  reason text,
  created_at timestamptz not null default now()
);
create index if not exists srk_booking_skill_level_events_booking_idx
  on public.srk_booking_skill_level_events(booking_id,created_at desc);
alter table public.srk_booking_skill_level_events enable row level security;

do $migration$
declare v_def text; v_old text; v_new text;
begin
  v_def:=pg_get_functiondef('public.srk_customer_create_booking(uuid,uuid,uuid,integer,integer,integer,text,text,text,text,double precision,double precision,double precision,double precision,numeric)'::regprocedure);
  v_old:='p_motor_hp numeric)';
  v_new:='p_motor_hp numeric, p_skill_level_id uuid)';
  if position(v_old in v_def)=0 then raise exception 'Booking function signature not found'; end if;
  v_def:=replace(v_def,v_old,v_new);

  v_old:=' v_location_source text;
begin';
  v_new:=' v_location_source text;
 v_requested_level public.srk_skill_levels%rowtype;
begin';
  if position(v_old in v_def)=0 then raise exception 'Booking function declarations not found'; end if;
  v_def:=replace(v_def,v_old,v_new);

  v_old:=' if not exists(select 1 from public.srk_service_skills where id=p_skill_id and service_type_id=p_service_type_id and is_active) then
   raise exception ''Work/skill does not belong to selected service'';
 end if;';
  v_new:=v_old||'
 if p_skill_level_id is not null then
   select * into v_requested_level from public.srk_skill_levels
   where id=p_skill_level_id and category_id=p_category_id and is_active;
   if not found then raise exception ''Selected qualification level is not active for this category''; end if;
 end if;';
  if position(v_old in v_def)=0 then raise exception 'Booking skill validation not found'; end if;
  v_def:=replace(v_def,v_old,v_new);

  v_old:='requested_technician_count,requested_helper_count,requested_duration_hours,booking_latitude,booking_longitude,';
  v_new:='requested_technician_count,requested_helper_count,requested_duration_hours,booking_latitude,booking_longitude,requested_skill_level_id,';
  if position(v_old in v_def)=0 then raise exception 'Booking insert columns not found'; end if;
  v_def:=replace(v_def,v_old,v_new);

  v_old:='p_technician_count,p_helper_count,p_duration_hours,p_booking_latitude,p_booking_longitude,';
  v_new:='p_technician_count,p_helper_count,p_duration_hours,p_booking_latitude,p_booking_longitude,p_skill_level_id,';
  if position(v_old in v_def)=0 then raise exception 'Booking insert values not found'; end if;
  v_def:=replace(v_def,v_old,v_new);
  execute v_def;
end
$migration$;

create or replace function public.srk_customer_create_booking(
 p_category_id uuid,p_service_type_id uuid,p_skill_id uuid,
 p_technician_count integer,p_helper_count integer,p_duration_hours integer,
 p_state text,p_district text,p_pincode text,p_address text,
 p_booking_latitude double precision,p_booking_longitude double precision,
 p_current_gps_latitude double precision,p_current_gps_longitude double precision,
 p_motor_hp numeric
)
returns public.service_bookings
language sql
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
 select public.srk_customer_create_booking(
  p_category_id,p_service_type_id,p_skill_id,p_technician_count,p_helper_count,
  p_duration_hours,p_state,p_district,p_pincode,p_address,p_booking_latitude,
  p_booking_longitude,p_current_gps_latitude,p_current_gps_longitude,p_motor_hp,null::uuid
 );
$function$;

create or replace function public.srk_customer_consent_higher_skill_level(
 p_booking_id uuid,p_higher_skill_level_id uuid
)
returns public.service_bookings
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare
 v_booking public.service_bookings%rowtype;
 v_requested public.srk_skill_levels%rowtype;
 v_higher public.srk_skill_levels%rowtype;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 select * into v_booking from public.service_bookings
 where id=p_booking_id and customer_user_id=auth.uid() for update;
 if not found then raise exception 'Customer booking not found' using errcode='42501'; end if;
 if v_booking.status not in ('new','confirmed') then raise exception 'Higher-level consent is only available before work starts'; end if;
 if v_booking.requested_skill_level_id is null then raise exception 'No requested qualification level is recorded'; end if;
 select * into v_requested from public.srk_skill_levels where id=v_booking.requested_skill_level_id;
 select * into v_higher from public.srk_skill_levels
 where id=p_higher_skill_level_id and category_id=v_booking.category_id and is_active;
 if not found or v_higher.sort_order<=v_requested.sort_order then
   raise exception 'The selected alternative must be a higher active qualification level';
 end if;
 update public.service_bookings
 set higher_skill_consent_level_id=v_higher.id,higher_skill_consent_at=clock_timestamp(),
     higher_skill_consent_by=auth.uid()
 where id=p_booking_id returning * into v_booking;
 insert into public.srk_booking_skill_level_events(
   booking_id,actor_user_id,event_type,from_skill_level_id,to_skill_level_id,reason
 ) values(p_booking_id,auth.uid(),'higher_level_consented',v_requested.id,v_higher.id,
   'Customer explicitly consented to higher qualification and its published rate');
 update public.srk_booking_matching_queue
 set queue_status='pending',next_attempt_at=clock_timestamp(),updated_at=clock_timestamp()
 where booking_id=p_booking_id and queue_status not in ('fulfilled','cancelled');
 return v_booking;
end
$function$;
revoke all on function public.srk_customer_consent_higher_skill_level(uuid,uuid) from public,anon;
grant execute on function public.srk_customer_consent_higher_skill_level(uuid,uuid) to authenticated;

do $migration$
declare v_def text; v_old text; v_new text;
begin
 v_def:=pg_get_functiondef('public.srk_find_eligible_workers(uuid,text)'::regprocedure);
 v_old:='and exists(select 1 from public.srk_worker_skills ws where ws.worker_id=w.id and ws.skill_id=v_booking.selected_skill_id and ws.verification_status=''approved'')';
 v_new:='and exists(select 1 from public.srk_worker_skills ws where ws.worker_id=w.id and ws.skill_id=v_booking.selected_skill_id and ws.verification_status=''approved'' and (coalesce(v_booking.higher_skill_consent_level_id,v_booking.requested_skill_level_id) is null or ws.skill_level_id=coalesce(v_booking.higher_skill_consent_level_id,v_booking.requested_skill_level_id)))';
 if position(v_old in v_def)=0 then raise exception 'Worker skill qualification filter not found'; end if;
 v_def:=replace(v_def,v_old,v_new);
 execute v_def;
end
$migration$;
