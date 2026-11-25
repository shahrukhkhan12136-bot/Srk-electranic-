
create table if not exists public.srk_booking_no_show_reports (
 id uuid primary key default gen_random_uuid(),
 booking_id uuid not null references public.service_bookings(id) on delete restrict,
 booking_worker_id uuid not null references public.srk_booking_workers(id) on delete restrict,
 reported_by uuid not null,
 reported_at timestamptz not null default now(),
 reason text,
 status text not null default 'waiting'
   check (status in ('waiting','resolved','cancelled','admin_review')),
 review_due_at timestamptz not null,
 admin_notified_at timestamptz,
 resolved_at timestamptz,
 resolution_note text,
 created_at timestamptz not null default now()
);
create index if not exists srk_booking_no_show_due_idx
 on public.srk_booking_no_show_reports(review_due_at) where status='waiting';
alter table public.srk_booking_no_show_reports enable row level security;
revoke all privileges on table public.srk_booking_no_show_reports from anon,authenticated;

create or replace function public.srk_customer_report_worker_no_show(
 p_booking_worker_id uuid,p_reason text
)
returns public.srk_booking_no_show_reports
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare v_assignment public.srk_booking_workers%rowtype; v_report public.srk_booking_no_show_reports%rowtype;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 if length(btrim(coalesce(p_reason,'')))<5 then raise exception 'No-show reason is required'; end if;
 select bw.* into v_assignment
 from public.srk_booking_workers bw
 join public.service_bookings b on b.id=bw.booking_id
 where bw.id=p_booking_worker_id and b.customer_user_id=auth.uid()
 for update of bw;
 if not found or v_assignment.assignment_status not in ('accepted','assigned','working') then
   raise exception 'Active worker assignment not found' using errcode='42501';
 end if;
 if v_assignment.arrived_at is not null then raise exception 'Worker is already marked arrived'; end if;
 if exists(select 1 from public.srk_booking_no_show_reports
   where booking_worker_id=p_booking_worker_id and status='waiting') then
   raise exception 'A no-show waiting period is already active';
 end if;
 insert into public.srk_booking_no_show_reports(
   booking_id,booking_worker_id,reported_by,reason,review_due_at
 ) values(
   v_assignment.booking_id,p_booking_worker_id,auth.uid(),btrim(p_reason),
   clock_timestamp()+make_interval(mins=>coalesce((select (setting_value #>> '{}')::integer from public.srk_system_settings where setting_key='no_show_wait_minutes'),10))
 ) returning * into v_report;
 insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
 select au.user_id,'worker_no_show_report','Customer reported a no-show',
   'Booking '||v_assignment.booking_id::text||' has a no-show report. A 10-minute verification window has started.',
   v_assignment.booking_id from public.srk_admin_users au;
 return v_report;
end
$function$;
revoke all on function public.srk_customer_report_worker_no_show(uuid,text) from public,anon;
grant execute on function public.srk_customer_report_worker_no_show(uuid,text) to authenticated;

create or replace function public.srk_process_no_show_reports()
returns integer
language plpgsql
security definer
set search_path to 'pg_catalog','public'
as $function$
declare v_report public.srk_booking_no_show_reports%rowtype; v_customer uuid; v_count integer:=0;
begin
 for v_report in
   select r.* from public.srk_booking_no_show_reports r
   where r.status='waiting' and r.review_due_at<=clock_timestamp()
   order by r.review_due_at for update skip locked limit 100
 loop
   if exists(select 1 from public.srk_booking_workers bw
     where bw.id=v_report.booking_worker_id and bw.arrived_at is not null) then
     update public.srk_booking_no_show_reports
     set status='resolved',resolved_at=clock_timestamp(),resolution_note='Worker arrived during the 10-minute waiting window'
     where id=v_report.id;
   else
     update public.srk_booking_no_show_reports
     set status='cancelled',admin_notified_at=clock_timestamp(),resolved_at=clock_timestamp(),
         resolution_note='No-show confirmed after the 10-minute wait; cancelled without fee'
     where id=v_report.id;

     update public.service_bookings set status='cancelled',
       admin_change_reason='No-show auto-cancellation after 10-minute wait; no cancellation fee'
     where id=v_report.booking_id and status not in ('completed','cancelled');

     update public.srk_booking_matching_queue set queue_status='cancelled',updated_at=clock_timestamp()
     where booking_id=v_report.booking_id;

     update public.srk_booking_workers set assignment_status='cancelled',
       admin_note='No-show auto-cancellation after 10-minute wait',updated_at=clock_timestamp()
     where booking_id=v_report.booking_id and assignment_status in ('offered','accepted','assigned','working','paused');

     update public.srk_worker_schedule_blocks set block_status='cancelled',updated_at=clock_timestamp()
     where booking_worker_id in(select id from public.srk_booking_workers where booking_id=v_report.booking_id)
       and block_status in ('reserved','confirmed','in_progress');

     update public.srk_booking_location_shares set ended_at=clock_timestamp()
     where booking_id=v_report.booking_id and ended_at is null;

     update public.srk_booking_cancellation_fees
     set status='pending',next_booking_id=null,added_to_next_booking_at=null
     where next_booking_id=v_report.booking_id and status='added_to_next_booking';
     update public.service_bookings set pending_cancellation_fee_amount=0 where id=v_report.booking_id;

     select customer_user_id into v_customer from public.service_bookings where id=v_report.booking_id;
     if v_customer is not null then
       insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
       values(v_customer,'booking_no_show_cancelled','Booking cancelled due to no-show',
         '10-minute waiting period ended. Booking cancelled without any cancellation fee.',v_report.booking_id);
     end if;
     insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
     select au.user_id,'booking_no_show_cancelled','No-show booking auto-cancelled',
       'Booking '||v_report.booking_id::text||' cancelled after 10-minute wait. No fee charged.',v_report.booking_id
     from public.srk_admin_users au;
   end if;
   v_count:=v_count+1;
 end loop;
 return v_count;
end
$function$;
revoke all on function public.srk_process_no_show_reports() from public,anon,authenticated;

select cron.schedule(
 'srk-booking-no-show-every-minute',
 '* * * * *',
 'select public.srk_process_no_show_reports();'
);
