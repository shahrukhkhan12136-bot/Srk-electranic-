
create or replace function public.srk_on_emergency_notification()
returns trigger language plpgsql security definer
set search_path=pg_catalog,public
as $$
begin
  insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
  select user_id,'admin_action_required','Emergency Alert','An emergency alert requires immediate Admin attention.',new.booking_id
  from public.srk_admin_users
  union
  select sm.user_id,'admin_action_required','Emergency Alert','An emergency alert requires immediate Admin attention.',new.booking_id
  from public.srk_admin_staff_members sm
  join public.srk_admin_roles r on r.id=sm.role_id and r.is_active
  join public.srk_admin_role_permissions rp on rp.role_id=r.id and rp.permission_code='support.manage'
  where sm.is_active;
  return new;
end $$;

create or replace function public.srk_create_support_case(
 p_booking_id uuid,p_category text,p_subject text,p_description text,p_priority text default 'normal'
) returns public.srk_support_cases
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v_role text; v_case public.srk_support_cases%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_booking_id is not null then
    if exists(select 1 from public.service_bookings where id=p_booking_id and customer_user_id=auth.uid()) then v_role:='customer';
    else
      select w.worker_type into v_role from public.srk_booking_workers bw join public.srk_worker_profiles w on w.id=bw.worker_id
      where bw.booking_id=p_booking_id and w.user_id=auth.uid() limit 1;
    end if;
  else
    if exists(select 1 from public.srk_customer_profiles where user_id=auth.uid()) then v_role:='customer';
    else select worker_type into v_role from public.srk_worker_profiles where user_id=auth.uid(); end if;
  end if;
  if v_role is null then raise exception 'Customer or worker profile required'; end if;
  insert into public.srk_support_cases(booking_id,raised_by,raised_by_role,category,subject,description,priority)
  values(p_booking_id,auth.uid(),v_role,p_category,p_subject,p_description,p_priority) returning * into v_case;
  insert into public.srk_support_case_events(case_id,actor_user_id,action,new_status,note)
  values(v_case.id,auth.uid(),'case_created','open',p_description);
  return v_case;
end $$;

create or replace function public.srk_raise_payment_dispute(p_booking_id uuid,p_dispute_type text,p_description text)
returns public.srk_booking_payment_disputes
language plpgsql security definer
set search_path=pg_catalog,public,auth
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
  return v;
end $$;
