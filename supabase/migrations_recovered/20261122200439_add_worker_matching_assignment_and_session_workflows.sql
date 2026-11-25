
create or replace function public.srk_admin_offer_worker_to_booking(
  p_booking_id uuid,
  p_worker_id uuid,
  p_worker_role text
) returns public.srk_booking_workers
language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare
  v_booking public.service_bookings%rowtype;
  v_worker public.srk_worker_profiles%rowtype;
  v_existing integer;
  v_limit integer;
  v_assignment public.srk_booking_workers%rowtype;
begin
  if not coalesce(public.is_srk_admin(),false) then raise exception 'Admin permission required'; end if;
  if p_worker_role not in ('technician','helper') then raise exception 'Invalid worker role'; end if;

  select * into v_booking from public.service_bookings where id=p_booking_id for update;
  if not found then raise exception 'Booking not found'; end if;

  select * into v_worker from public.srk_worker_profiles where id=p_worker_id for update;
  if not found then raise exception 'Worker not found'; end if;

  if v_worker.worker_type<>p_worker_role or v_worker.category_id is distinct from v_booking.category_id then
    raise exception 'Worker category or role does not match booking';
  end if;
  if v_worker.verification_status<>'approved' or not v_worker.is_active or not v_worker.is_online then
    raise exception 'Worker must be approved, active and online';
  end if;
  if v_booking.selected_skill_id is null or not exists (
    select 1 from public.srk_worker_skills ws
    where ws.worker_id=p_worker_id and ws.skill_id=v_booking.selected_skill_id and ws.verification_status='approved'
  ) then
    raise exception 'Worker does not have the required Admin-approved skill';
  end if;
  if exists (
    select 1 from public.srk_worker_work_sessions s
    join public.srk_booking_workers bw on bw.id=s.booking_worker_id
    where bw.worker_id=p_worker_id and s.session_status='running'
  ) then raise exception 'Worker is already working at another booking'; end if;

  v_limit := case when p_worker_role='technician' then v_booking.requested_technician_count else v_booking.requested_helper_count end;
  select count(*) into v_existing from public.srk_booking_workers
  where booking_id=p_booking_id and worker_role=p_worker_role
    and assignment_status not in ('rejected','cancelled','released');
  if v_existing>=v_limit then raise exception 'Requested worker count already fulfilled'; end if;

  insert into public.srk_booking_workers(booking_id,worker_id,worker_role,assignment_status,offered_by)
  values(p_booking_id,p_worker_id,p_worker_role,'offered',auth.uid())
  returning * into v_assignment;
  return v_assignment;
end;
$$;

create or replace function public.srk_worker_respond_assignment(
  p_assignment_id uuid,
  p_accept boolean
) returns public.srk_booking_workers
language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare
  v_assignment public.srk_booking_workers%rowtype;
  v_user uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select bw.* into v_assignment
  from public.srk_booking_workers bw
  join public.srk_worker_profiles wp on wp.id=bw.worker_id
  where bw.id=p_assignment_id and wp.user_id=auth.uid()
  for update of bw;
  if not found then raise exception 'Assignment not found or not yours'; end if;
  if v_assignment.assignment_status<>'offered' then raise exception 'Offer is no longer pending'; end if;

  update public.srk_booking_workers
  set assignment_status=case when p_accept then 'accepted' else 'rejected' end,
      accepted_at=case when p_accept then clock_timestamp() else null end,
      rejected_at=case when p_accept then null else clock_timestamp() end,
      updated_at=clock_timestamp()
  where id=p_assignment_id returning * into v_assignment;

  return v_assignment;
end;
$$;

create or replace function public.srk_worker_open_work_session(
  p_booking_worker_id uuid,
  p_work_date date default (now() at time zone 'Asia/Kolkata')::date
) returns public.srk_worker_work_sessions
language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare
  v_session public.srk_worker_work_sessions%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not exists(
    select 1 from public.srk_booking_workers bw
    join public.srk_worker_profiles wp on wp.id=bw.worker_id
    where bw.id=p_booking_worker_id and wp.user_id=auth.uid()
      and bw.assignment_status in ('accepted','assigned','working','paused')
  ) then raise exception 'You do not have an accepted assignment'; end if;

  insert into public.srk_worker_work_sessions(booking_worker_id,work_date)
  values(p_booking_worker_id,p_work_date)
  on conflict(booking_worker_id,work_date) do update set updated_at=clock_timestamp()
  returning * into v_session;

  return v_session;
end;
$$;

create or replace function public.srk_worker_complete_assignment(
  p_booking_worker_id uuid,
  p_note text default null
) returns public.srk_booking_workers
language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare
  v_assignment public.srk_booking_workers%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select bw.* into v_assignment
  from public.srk_booking_workers bw
  join public.srk_worker_profiles wp on wp.id=bw.worker_id
  where bw.id=p_booking_worker_id and wp.user_id=auth.uid()
  for update of bw;
  if not found then raise exception 'Assignment not found or not yours'; end if;

  if not exists(select 1 from public.srk_worker_work_sessions where booking_worker_id=p_booking_worker_id) then
    raise exception 'At least one work session is required';
  end if;
  if exists(select 1 from public.srk_worker_work_sessions where booking_worker_id=p_booking_worker_id and session_status not in ('completed','cancelled')) then
    raise exception 'Complete or cancel every daily work session first';
  end if;

  update public.srk_booking_workers
  set assignment_status='completed',released_at=clock_timestamp(),updated_at=clock_timestamp(),admin_note=coalesce(p_note,admin_note)
  where id=p_booking_worker_id and assignment_status<>'completed'
  returning * into v_assignment;

  return v_assignment;
end;
$$;

revoke all on function public.srk_admin_offer_worker_to_booking(uuid,uuid,text) from public,anon;
revoke all on function public.srk_worker_respond_assignment(uuid,boolean) from public,anon;
revoke all on function public.srk_worker_open_work_session(uuid,date) from public,anon;
revoke all on function public.srk_worker_complete_assignment(uuid,text) from public,anon;
grant execute on function public.srk_admin_offer_worker_to_booking(uuid,uuid,text) to authenticated,service_role;
grant execute on function public.srk_worker_respond_assignment(uuid,boolean) to authenticated;
grant execute on function public.srk_worker_open_work_session(uuid,date) to authenticated;
grant execute on function public.srk_worker_complete_assignment(uuid,text) to authenticated;
