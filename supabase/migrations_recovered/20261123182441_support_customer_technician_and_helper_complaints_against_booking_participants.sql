
alter table public.srk_booking_complaints
  add column if not exists reported_to_user_id uuid references auth.users(id) on delete restrict,
  add column if not exists reported_to_role text,
  add column if not exists reported_to_worker_id uuid references public.srk_worker_profiles(id) on delete restrict;
alter table public.srk_booking_complaints
  drop constraint if exists srk_booking_complaints_reporter_role_check;
alter table public.srk_booking_complaints
  add constraint srk_booking_complaints_reporter_role_check
  check (reporter_role in ('customer','technician','helper'));
alter table public.srk_booking_complaints
  drop constraint if exists srk_booking_complaints_reported_to_role_check;
alter table public.srk_booking_complaints
  add constraint srk_booking_complaints_reported_to_role_check
  check (reported_to_role is null or reported_to_role in ('customer','technician','helper'));
alter table public.srk_booking_complaint_events
  drop constraint if exists srk_booking_complaint_events_actor_role_check;
alter table public.srk_booking_complaint_events
  add constraint srk_booking_complaint_events_actor_role_check
  check (actor_role in ('customer','technician','helper','admin'));

create index if not exists srk_booking_complaints_target_user_idx
  on public.srk_booking_complaints(reported_to_user_id,created_at desc);

create or replace function public.srk_raise_booking_complaint(
 p_booking_id uuid,p_reported_to_user_id uuid,p_category text,p_description text
)
returns uuid
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare
 v_reporter_role text;
 v_target_role text;
 v_reporter_worker_id uuid;
 v_target_worker_id uuid;
 v_customer_id uuid;
 v_complaint_id uuid;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 if p_booking_id is null or p_reported_to_user_id is null
    or p_reported_to_user_id=auth.uid()
    or p_category not in ('service_quality','electrician_behavior','billing_payment','delay_no_show','safety','other')
    or p_description is null or length(btrim(p_description)) not between 20 and 2000 then
   raise exception 'Valid booking, target participant, category and 20-2000 character description are required' using errcode='22023';
 end if;

 select customer_user_id into v_customer_id
 from public.service_bookings where id=p_booking_id;
 if not found then raise exception 'Booking not found'; end if;

 if v_customer_id=auth.uid() then
   v_reporter_role:='customer';
 else
   select wp.id,wp.worker_type into v_reporter_worker_id,v_reporter_role
   from public.srk_booking_workers bw
   join public.srk_worker_profiles wp on wp.id=bw.worker_id
   where bw.booking_id=p_booking_id and wp.user_id=auth.uid()
     and bw.assignment_status in ('accepted','assigned','working','paused','completed','released')
   limit 1;
 end if;
 if v_reporter_role is null then raise exception 'Only booking participants can raise a complaint' using errcode='42501'; end if;

 if p_reported_to_user_id=v_customer_id then
   v_target_role:='customer';
 else
   select wp.id,wp.worker_type into v_target_worker_id,v_target_role
   from public.srk_booking_workers bw
   join public.srk_worker_profiles wp on wp.id=bw.worker_id
   where bw.booking_id=p_booking_id and wp.user_id=p_reported_to_user_id
     and bw.assignment_status in ('accepted','assigned','working','paused','completed','released')
   limit 1;
 end if;
 if v_target_role is null then raise exception 'Reported person is not a participant in this booking' using errcode='42501'; end if;

 if (select count(*) from public.srk_booking_complaints c
     where c.reported_by_user_id=auth.uid() and c.created_at>=clock_timestamp()-interval '24 hours')>=10 then
   raise exception 'Daily complaint limit reached';
 end if;

 insert into public.srk_booking_complaints(
   booking_id,customer_user_id,reporter_role,reported_by_user_id,
   reported_to_user_id,reported_to_role,reported_to_worker_id,category,description
 ) values(
   p_booking_id,case when v_reporter_role='customer' then auth.uid() else null end,
   v_reporter_role,auth.uid(),p_reported_to_user_id,v_target_role,v_target_worker_id,
   p_category,btrim(p_description)
 ) returning id into v_complaint_id;

 insert into public.srk_booking_complaint_events(
   complaint_id,actor_user_id,actor_role,from_status,to_status,note
 ) values(v_complaint_id,auth.uid(),v_reporter_role,null,'new','Complaint filed against booking participant');
 return v_complaint_id;
end
$function$;
revoke all on function public.srk_raise_booking_complaint(uuid,uuid,text,text) from public,anon;
grant execute on function public.srk_raise_booking_complaint(uuid,uuid,text,text) to authenticated;
