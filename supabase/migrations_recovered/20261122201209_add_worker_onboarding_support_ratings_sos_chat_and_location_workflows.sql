
create or replace function public.srk_submit_worker_application(
  p_worker_type text,p_category_id uuid,p_full_name text,p_phone text,p_father_name text,
  p_date_of_birth date,p_photo_path text,p_address text,p_state text,p_district text,
  p_pincode text,p_experience_years integer,p_about text
) returns public.srk_worker_applications
language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare v_app public.srk_worker_applications%rowtype;
begin
  if auth.uid() is null then raise exception 'OTP login required'; end if;
  if p_worker_type not in ('technician','helper') then raise exception 'Invalid worker type'; end if;
  if not exists(select 1 from public.srk_service_categories where id=p_category_id and is_active) then raise exception 'Active category required'; end if;
  if length(btrim(coalesce(p_full_name,'')))<2 or p_phone !~ '^[0-9]{10}$' or p_pincode !~ '^[0-9]{6}$' then
    raise exception 'Valid name, 10-digit mobile and 6-digit PIN code required';
  end if;
  insert into public.srk_worker_applications(
    user_id,worker_type,category_id,full_name,phone,father_name,date_of_birth,photo_path,
    address,state,district,pincode,experience_years,about,status
  ) values(
    auth.uid(),p_worker_type,p_category_id,btrim(p_full_name),p_phone,p_father_name,p_date_of_birth,
    p_photo_path,btrim(p_address),btrim(p_state),btrim(p_district),p_pincode,p_experience_years,p_about,'pending'
  )
  on conflict(user_id,category_id,worker_type) do update set
    full_name=excluded.full_name,phone=excluded.phone,father_name=excluded.father_name,
    date_of_birth=excluded.date_of_birth,photo_path=excluded.photo_path,address=excluded.address,
    state=excluded.state,district=excluded.district,pincode=excluded.pincode,
    experience_years=excluded.experience_years,about=excluded.about,status='pending',updated_at=clock_timestamp()
  returning * into v_app;
  return v_app;
end $$;

create or replace function public.srk_admin_review_worker_application(
  p_application_id uuid,p_decision text,p_note text default null
) returns public.srk_worker_profiles
language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare v_app public.srk_worker_applications%rowtype; v_profile public.srk_worker_profiles%rowtype;
begin
  if not public.srk_has_admin_permission('workers.verify') then raise exception 'Worker verification permission required'; end if;
  if p_decision not in ('approved','rejected','under_review','more_info') then raise exception 'Invalid application decision'; end if;
  select * into v_app from public.srk_worker_applications where id=p_application_id for update;
  if not found then raise exception 'Application not found'; end if;
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
  return v_profile;
end $$;

create or replace function public.srk_submit_worker_document(
  p_document_type text,p_storage_path text,p_file_name text,p_mime_type text,p_file_size_bytes bigint,
  p_application_id uuid default null
) returns public.srk_worker_documents
language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare v_worker uuid; v_doc public.srk_worker_documents%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select id into v_worker from public.srk_worker_profiles where user_id=auth.uid();
  if p_application_id is not null and not exists(select 1 from public.srk_worker_applications where id=p_application_id and user_id=auth.uid()) then
    raise exception 'Application does not belong to you';
  end if;
  if v_worker is null and p_application_id is null then raise exception 'Worker application or profile required'; end if;
  if p_storage_path like '/%' or p_storage_path like '%..%' then raise exception 'Invalid private storage path'; end if;
  insert into public.srk_worker_documents(worker_id,application_id,document_type,storage_path,file_name,mime_type,file_size_bytes)
  values(v_worker,p_application_id,p_document_type,p_storage_path,p_file_name,p_mime_type,p_file_size_bytes)
  returning * into v_doc;
  return v_doc;
end $$;

create or replace function public.srk_create_support_case(
  p_booking_id uuid,p_category text,p_subject text,p_description text,p_priority text default 'normal'
) returns public.srk_support_cases
language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare v_role text; v_case public.srk_support_cases%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if exists(select 1 from public.service_bookings where id=p_booking_id and customer_user_id=auth.uid()) then v_role:='customer';
  elsif exists(select 1 from public.srk_booking_workers bw join public.srk_worker_profiles w on w.id=bw.worker_id
    where bw.booking_id=p_booking_id and w.user_id=auth.uid()) then
    select worker_type into v_role from public.srk_worker_profiles where user_id=auth.uid();
  else raise exception 'You are not a participant in this booking'; end if;

  insert into public.srk_support_cases(booking_id,raised_by,raised_by_role,category,subject,description,priority)
  values(p_booking_id,auth.uid(),v_role,p_category,p_subject,p_description,p_priority)
  returning * into v_case;
  insert into public.srk_support_case_events(case_id,actor_user_id,action,new_status,note)
  values(v_case.id,auth.uid(),'case_created','open',p_description);
  return v_case;
end $$;

create or replace function public.srk_raise_emergency_alert(
  p_booking_id uuid,p_alert_type text,p_message text,p_latitude double precision,p_longitude double precision
) returns public.srk_emergency_alerts
language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare v_role text; v_alert public.srk_emergency_alerts%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if exists(select 1 from public.service_bookings where id=p_booking_id and customer_user_id=auth.uid()) then v_role:='customer';
  else
    select worker_type into v_role from public.srk_booking_workers bw join public.srk_worker_profiles w on w.id=bw.worker_id
      where bw.booking_id=p_booking_id and w.user_id=auth.uid() limit 1;
    if v_role is null then raise exception 'Only booking participants can raise emergency alerts'; end if;
  end if;
  insert into public.srk_emergency_alerts(booking_id,raised_by,raised_by_role,alert_type,message,latitude,longitude,priority)
  values(p_booking_id,auth.uid(),v_role,p_alert_type,p_message,p_latitude,p_longitude,'emergency')
  returning * into v_alert;
  return v_alert;
end $$;

create or replace function public.srk_submit_booking_rating(
  p_booking_id uuid,p_rating integer,p_comment text default null,p_target_worker_id uuid default null
) returns public.srk_booking_ratings
language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare v_booking public.service_bookings%rowtype; v_role text; v_target_user uuid; v_rating public.srk_booking_ratings%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into v_booking from public.service_bookings where id=p_booking_id;
  if not found or v_booking.status<>'completed' then raise exception 'Only completed bookings can be rated'; end if;
  if v_booking.customer_user_id=auth.uid() then
    v_role:='customer';
    if p_target_worker_id is null or not exists(select 1 from public.srk_booking_workers bw where bw.booking_id=p_booking_id and bw.worker_id=p_target_worker_id and bw.assignment_status='completed') then
      raise exception 'Select a worker assigned to this completed booking';
    end if;
  else
    select w.worker_type into v_role from public.srk_booking_workers bw join public.srk_worker_profiles w on w.id=bw.worker_id
      where bw.booking_id=p_booking_id and w.user_id=auth.uid() and bw.assignment_status='completed' limit 1;
    if v_role is null then raise exception 'Only completed booking workers can rate the customer'; end if;
    p_target_worker_id:=null;
  end if;

  insert into public.srk_booking_ratings(booking_id,rater_user_id,rater_role,target_worker_id,target_user_id,rating,comment,moderation_status)
  values(p_booking_id,auth.uid(),v_role,p_target_worker_id,
    case when v_role<>'customer' then v_booking.customer_user_id else null end,p_rating,p_comment,'pending')
  returning * into v_rating;
  return v_rating;
end $$;

create or replace function public.srk_send_booking_chat_message(p_room_id uuid,p_message text,p_attachment_path text default null)
returns public.srk_booking_chat_messages
language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare v_msg public.srk_booking_chat_messages%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not exists(select 1 from public.srk_booking_chat_members m join public.srk_booking_chat_rooms r on r.id=m.room_id
    where m.room_id=p_room_id and m.user_id=auth.uid() and m.left_at is null and r.is_active) then
    raise exception 'You are not an active member of this booking chat';
  end if;
  insert into public.srk_booking_chat_messages(room_id,sender_user_id,message,attachment_path)
  values(p_room_id,auth.uid(),p_message,p_attachment_path) returning * into v_msg;
  return v_msg;
end $$;

create or replace function public.srk_start_booking_location_share(p_booking_id uuid)
returns public.srk_booking_location_shares
language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare v_share public.srk_booking_location_shares%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not (
    exists(select 1 from public.service_bookings b where b.id=p_booking_id and b.customer_user_id=auth.uid() and b.status in ('assigned','in_progress'))
    or exists(select 1 from public.srk_booking_workers bw join public.srk_worker_profiles w on w.id=bw.worker_id
      where bw.booking_id=p_booking_id and w.user_id=auth.uid() and bw.assignment_status in ('accepted','assigned','working','paused'))
  ) then raise exception 'Only active booking participants can share live location'; end if;
  insert into public.srk_booking_location_shares(booking_id,started_by) values(p_booking_id,auth.uid())
  returning * into v_share;
  return v_share;
end $$;

create or replace function public.srk_record_booking_live_location(
  p_share_id uuid,p_latitude double precision,p_longitude double precision,p_accuracy_m numeric default null
) returns uuid
language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare v_booking uuid; v_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select sh.booking_id into v_booking from public.srk_booking_location_shares sh
  where sh.id=p_share_id and sh.ended_at is null;
  if not found then raise exception 'Location sharing is not active'; end if;
  if not (
    exists(select 1 from public.service_bookings b where b.id=v_booking and b.customer_user_id=auth.uid() and b.status in ('assigned','in_progress'))
    or exists(select 1 from public.srk_booking_workers bw join public.srk_worker_profiles w on w.id=bw.worker_id
      where bw.booking_id=v_booking and w.user_id=auth.uid() and bw.assignment_status in ('accepted','assigned','working','paused'))
  ) then raise exception 'Not authorized to share this booking location'; end if;
  insert into public.srk_booking_live_locations(share_id,user_id,latitude,longitude,accuracy_m)
  values(p_share_id,auth.uid(),p_latitude,p_longitude,p_accuracy_m) returning id into v_id;
  return v_id;
end $$;

create or replace function public.srk_stop_booking_location_share(p_share_id uuid)
returns boolean
language plpgsql security definer
set search_path=pg_catalog,public
as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  update public.srk_booking_location_shares sh set ended_at=clock_timestamp()
  where sh.id=p_share_id and sh.ended_at is null and (
    sh.started_by=auth.uid() or public.is_srk_admin()
    or exists(select 1 from public.service_bookings b where b.id=sh.booking_id and b.customer_user_id=auth.uid())
    or exists(select 1 from public.srk_booking_workers bw join public.srk_worker_profiles w on w.id=bw.worker_id
      where bw.booking_id=sh.booking_id and w.user_id=auth.uid())
  );
  return found;
end $$;

revoke all on function public.srk_submit_worker_application(text,uuid,text,text,text,date,text,text,text,text,text,integer,text) from public,anon;
revoke all on function public.srk_admin_review_worker_application(uuid,text,text) from public,anon;
revoke all on function public.srk_submit_worker_document(text,text,text,text,bigint,uuid) from public,anon;
revoke all on function public.srk_create_support_case(uuid,text,text,text,text) from public,anon;
revoke all on function public.srk_raise_emergency_alert(uuid,text,text,double precision,double precision) from public,anon;
revoke all on function public.srk_submit_booking_rating(uuid,integer,text,uuid) from public,anon;
revoke all on function public.srk_send_booking_chat_message(uuid,text,text) from public,anon;
revoke all on function public.srk_start_booking_location_share(uuid) from public,anon;
revoke all on function public.srk_record_booking_live_location(uuid,double precision,double precision,numeric) from public,anon;
revoke all on function public.srk_stop_booking_location_share(uuid) from public,anon;
grant execute on function public.srk_submit_worker_application(text,uuid,text,text,text,date,text,text,text,text,text,integer,text) to authenticated;
grant execute on function public.srk_admin_review_worker_application(uuid,text,text) to authenticated,service_role;
grant execute on function public.srk_submit_worker_document(text,text,text,text,bigint,uuid) to authenticated;
grant execute on function public.srk_create_support_case(uuid,text,text,text,text) to authenticated;
grant execute on function public.srk_raise_emergency_alert(uuid,text,text,double precision,double precision) to authenticated;
grant execute on function public.srk_submit_booking_rating(uuid,integer,text,uuid) to authenticated;
grant execute on function public.srk_send_booking_chat_message(uuid,text,text) to authenticated;
grant execute on function public.srk_start_booking_location_share(uuid) to authenticated;
grant execute on function public.srk_record_booking_live_location(uuid,double precision,double precision,numeric) to authenticated;
grant execute on function public.srk_stop_booking_location_share(uuid) to authenticated;

-- Correct chat message policy correlation.
drop policy if exists srk_chat_messages_participant on public.srk_booking_chat_messages;
create policy srk_chat_messages_participant on public.srk_booking_chat_messages
for select to authenticated using(
  exists(select 1 from public.srk_booking_chat_members m where m.room_id=srk_booking_chat_messages.room_id and m.user_id=auth.uid() and m.left_at is null)
  or public.is_srk_admin()
);
