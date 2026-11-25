
create or replace function public.srk_admin_publish_service_rate(
  p_category_id uuid,p_service_type_id uuid,p_skill_level_id uuid,
  p_technician_hourly_rate numeric,p_helper_hourly_rate numeric
) returns public.srk_service_rates
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v_rate public.srk_service_rates%rowtype;
begin
  if not public.srk_has_admin_permission('catalog.manage') then raise exception 'Service catalog permission required'; end if;
  if p_technician_hourly_rate is null or p_technician_hourly_rate<0 or p_helper_hourly_rate is null or p_helper_hourly_rate<0 then
    raise exception 'Both hourly rates must be non-negative values';
  end if;
  if not exists(select 1 from public.srk_skill_levels l where l.id=p_skill_level_id and l.category_id=p_category_id) then
    raise exception 'Skill level does not belong to category';
  end if;
  if p_service_type_id is not null and not exists(select 1 from public.srk_service_types s where s.id=p_service_type_id and s.category_id=p_category_id) then
    raise exception 'Service type does not belong to category';
  end if;

  update public.srk_service_rates set effective_to=clock_timestamp(),rate_status='retired'
  where category_id=p_category_id and service_type_id is not distinct from p_service_type_id
    and skill_level_id=p_skill_level_id and rate_status='approved' and effective_to is null;

  insert into public.srk_service_rates(category_id,service_type_id,skill_level_id,
    technician_hourly_rate,helper_hourly_rate,rate_status,created_by)
  values(p_category_id,p_service_type_id,p_skill_level_id,p_technician_hourly_rate,p_helper_hourly_rate,'approved',auth.uid())
  returning * into v_rate;
  return v_rate;
end $$;

create or replace function public.srk_worker_request_skill(p_skill_id uuid,p_skill_level_id uuid)
returns public.srk_worker_skills
language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare v_worker public.srk_worker_profiles%rowtype; v_skill public.srk_service_skills%rowtype; v_level public.srk_skill_levels%rowtype; v_result public.srk_worker_skills%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into v_worker from public.srk_worker_profiles where user_id=auth.uid();
  if not found then raise exception 'Worker profile not found'; end if;
  select * into v_skill from public.srk_service_skills where id=p_skill_id and is_active;
  if not found then raise exception 'Active skill not found'; end if;
  select * into v_level from public.srk_skill_levels where id=p_skill_level_id and category_id=v_worker.category_id and is_active;
  if not found then raise exception 'Skill level does not match worker category'; end if;
  if not exists(select 1 from public.srk_service_types s where s.id=v_skill.service_type_id and s.category_id=v_worker.category_id) then
    raise exception 'Skill is outside worker category';
  end if;
  insert into public.srk_worker_skills(worker_id,skill_id,skill_level_id,verification_status)
  values(v_worker.id,p_skill_id,p_skill_level_id,'pending')
  on conflict(worker_id,skill_id) do update set skill_level_id=excluded.skill_level_id,
    verification_status='pending',reviewed_by=null,reviewed_at=null,updated_at=clock_timestamp()
  returning * into v_result;
  return v_result;
end $$;

create or replace function public.srk_admin_moderate_booking_rating(
  p_rating_id uuid,p_decision text
) returns public.srk_booking_ratings
language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare v public.srk_booking_ratings%rowtype;
begin
  if not public.srk_has_admin_permission('ratings.moderate') then raise exception 'Rating moderation permission required'; end if;
  if p_decision not in ('published','hidden','rejected') then raise exception 'Invalid moderation decision'; end if;
  update public.srk_booking_ratings set moderation_status=p_decision,moderated_by=auth.uid(),moderated_at=clock_timestamp()
  where id=p_rating_id returning * into v;
  if not found then raise exception 'Rating not found'; end if;
  return v;
end $$;

create or replace function public.srk_admin_update_support_case(
  p_case_id uuid,p_status text,p_priority text default null,p_assigned_staff uuid default null,p_resolution text default null,p_note text default null
) returns public.srk_support_cases
language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare v public.srk_support_cases%rowtype; v_old text;
begin
  if not public.srk_has_admin_permission('support.manage') then raise exception 'Support permission required'; end if;
  select status into v_old from public.srk_support_cases where id=p_case_id for update;
  if not found then raise exception 'Support case not found'; end if;
  update public.srk_support_cases set status=coalesce(p_status,status),priority=coalesce(p_priority,priority),
    assigned_staff=coalesce(p_assigned_staff,assigned_staff),resolution=coalesce(p_resolution,resolution),
    resolved_at=case when p_status in ('resolved','closed') then clock_timestamp() else resolved_at end,
    updated_at=clock_timestamp()
  where id=p_case_id returning * into v;
  insert into public.srk_support_case_events(case_id,actor_user_id,action,old_status,new_status,note)
  values(p_case_id,auth.uid(),'admin_update',v_old,v.status,p_note);
  insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
  values(v.raised_by,'support_update','Support case updated','Your support case status is now: '||v.status,v.booking_id);
  return v;
end $$;

create or replace function public.srk_admin_resolve_emergency_alert(
  p_alert_id uuid,p_status text,p_note text default null
) returns public.srk_emergency_alerts
language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare v public.srk_emergency_alerts%rowtype;
begin
  if not public.srk_has_admin_permission('support.manage') then raise exception 'Support permission required'; end if;
  if p_status not in ('acknowledged','responding','resolved','false_alarm') then raise exception 'Invalid emergency status'; end if;
  update public.srk_emergency_alerts set status=p_status,assigned_staff=coalesce(assigned_staff,auth.uid()),
    resolved_at=case when p_status in ('resolved','false_alarm') then clock_timestamp() else resolved_at end
  where id=p_alert_id returning * into v;
  if not found then raise exception 'Emergency alert not found'; end if;
  insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
  values(v.raised_by,'emergency_update','Emergency response update',coalesce(p_note,'Emergency alert status: '||p_status),v.booking_id);
  return v;
end $$;

create or replace function public.srk_raise_payment_dispute(
  p_booking_id uuid,p_dispute_type text,p_description text
) returns public.srk_booking_payment_disputes
language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare v_role text; v public.srk_booking_payment_disputes%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if exists(select 1 from public.service_bookings where id=p_booking_id and customer_user_id=auth.uid()) then v_role:='customer';
  else
    select w.worker_type into v_role from public.srk_booking_workers bw join public.srk_worker_profiles w on w.id=bw.worker_id
    where bw.booking_id=p_booking_id and w.user_id=auth.uid() limit 1;
    if v_role is null then raise exception 'Only booking customer or assigned worker can report payment dispute'; end if;
  end if;
  insert into public.srk_booking_payment_disputes(booking_id,raised_by,raised_by_role,dispute_type,description)
  values(p_booking_id,auth.uid(),v_role,p_dispute_type,p_description) returning * into v;
  insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
  select user_id,'payment_dispute','Payment dispute reported','A payment dispute needs Admin review.',p_booking_id
  from public.srk_admin_users;
  return v;
end $$;

create or replace function public.srk_mark_notification_read(p_notification_id uuid)
returns boolean language plpgsql security definer
set search_path=pg_catalog,public
as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  update public.srk_app_notifications set read_at=clock_timestamp()
  where id=p_notification_id and user_id=auth.uid();
  return found;
end $$;

-- Close all live location sharing immediately when a booking is completed or cancelled.
create or replace function public.srk_close_booking_location_share()
returns trigger language plpgsql security definer
set search_path=pg_catalog,public
as $$
begin
  if new.status in ('completed','cancelled') and new.status is distinct from old.status then
    update public.srk_booking_location_shares set ended_at=clock_timestamp()
    where booking_id=new.id and ended_at is null;
  end if;
  return new;
end $$;
drop trigger if exists srk_close_booking_location_share_trigger on public.service_bookings;
create trigger srk_close_booking_location_share_trigger after update of status on public.service_bookings
for each row execute function public.srk_close_booking_location_share();

-- Baseline language QA matrix; further dialects can be added by Admin.
insert into public.srk_ai_language_test_cases(language_code,language_name,test_prompt,expected_behavior)
values
 ('as','Assamese','Explain how to create a service booking.','Respond in Assamese; ask for clarification if uncertain.'),
 ('bn','Bengali','Explain how to create a service booking.','Respond in Bengali; ask for clarification if uncertain.'),
 ('brx','Bodo','Explain how to create a service booking.','Respond in Bodo where supported; graceful fallback if uncertain.'),
 ('doi','Dogri','Explain how to create a service booking.','Respond in Dogri where supported; graceful fallback if uncertain.'),
 ('gu','Gujarati','Explain how to create a service booking.','Respond in Gujarati; ask for clarification if uncertain.'),
 ('hi','Hindi','Explain how to create a service booking.','Respond in Hindi; ask for clarification if uncertain.'),
 ('kn','Kannada','Explain how to create a service booking.','Respond in Kannada; ask for clarification if uncertain.'),
 ('ks','Kashmiri','Explain how to create a service booking.','Respond in Kashmiri where supported; graceful fallback if uncertain.'),
 ('kok','Konkani','Explain how to create a service booking.','Respond in Konkani where supported; graceful fallback if uncertain.'),
 ('mai','Maithili','Explain how to create a service booking.','Respond in Maithili where supported; graceful fallback if uncertain.'),
 ('ml','Malayalam','Explain how to create a service booking.','Respond in Malayalam; ask for clarification if uncertain.'),
 ('mni','Manipuri/Meitei','Explain how to create a service booking.','Respond in Meitei where supported; graceful fallback if uncertain.'),
 ('mr','Marathi','Explain how to create a service booking.','Respond in Marathi; ask for clarification if uncertain.'),
 ('ne','Nepali','Explain how to create a service booking.','Respond in Nepali where supported; graceful fallback if uncertain.'),
 ('or','Odia','Explain how to create a service booking.','Respond in Odia; ask for clarification if uncertain.'),
 ('pa','Punjabi','Explain how to create a service booking.','Respond in Punjabi; ask for clarification if uncertain.'),
 ('sa','Sanskrit','Explain how to create a service booking.','Respond in Sanskrit where supported; graceful fallback if uncertain.'),
 ('sat','Santali','Explain how to create a service booking.','Respond in Santali where supported; graceful fallback if uncertain.'),
 ('sd','Sindhi','Explain how to create a service booking.','Respond in Sindhi where supported; graceful fallback if uncertain.'),
 ('ta','Tamil','Explain how to create a service booking.','Respond in Tamil; ask for clarification if uncertain.'),
 ('te','Telugu','Explain how to create a service booking.','Respond in Telugu; ask for clarification if uncertain.'),
 ('ur','Urdu','Explain how to create a service booking.','Respond in Urdu; ask for clarification if uncertain.')
on conflict do nothing;

revoke all on function public.srk_admin_publish_service_rate(uuid,uuid,uuid,numeric,numeric) from public,anon;
revoke all on function public.srk_worker_request_skill(uuid,uuid) from public,anon;
revoke all on function public.srk_admin_moderate_booking_rating(uuid,text) from public,anon;
revoke all on function public.srk_admin_update_support_case(uuid,text,text,uuid,text,text) from public,anon;
revoke all on function public.srk_admin_resolve_emergency_alert(uuid,text,text) from public,anon;
revoke all on function public.srk_raise_payment_dispute(uuid,text,text) from public,anon;
revoke all on function public.srk_mark_notification_read(uuid) from public,anon;
grant execute on function public.srk_admin_publish_service_rate(uuid,uuid,uuid,numeric,numeric) to authenticated,service_role;
grant execute on function public.srk_worker_request_skill(uuid,uuid) to authenticated;
grant execute on function public.srk_admin_moderate_booking_rating(uuid,text) to authenticated,service_role;
grant execute on function public.srk_admin_update_support_case(uuid,text,text,uuid,text,text) to authenticated,service_role;
grant execute on function public.srk_admin_resolve_emergency_alert(uuid,text,text) to authenticated,service_role;
grant execute on function public.srk_raise_payment_dispute(uuid,text,text) to authenticated;
grant execute on function public.srk_mark_notification_read(uuid) to authenticated;
