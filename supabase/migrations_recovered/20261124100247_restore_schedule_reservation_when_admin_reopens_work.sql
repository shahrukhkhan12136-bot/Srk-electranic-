CREATE OR REPLACE FUNCTION public.srk_admin_reopen_booking_work(
 p_booking_id uuid,p_booking_worker_id uuid,p_reason text
) RETURNS public.srk_booking_workers
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth'
AS $function$
declare
 v_booking public.service_bookings%rowtype;
 v_assignment public.srk_booking_workers%rowtype;
begin
 if auth.uid() is null or not public.srk_has_admin_permission('bookings.manage') then
  raise exception 'Booking management permission required';
 end if;
 if length(btrim(coalesce(p_reason,'')))<10 then
  raise exception 'Reopen reason must be at least 10 characters';
 end if;
 select * into v_booking from public.service_bookings where id=p_booking_id for update;
 if not found then raise exception 'Booking not found'; end if;
 if v_booking.payment_status='paid' then
  raise exception 'Paid booking cannot be reopened; use refund/dispute workflow';
 end if;
 if v_booking.completion_approval_status not in ('rejected','disputed') then
  raise exception 'Only rejected or disputed completion can be reopened';
 end if;
 select * into v_assignment from public.srk_booking_workers
 where id=p_booking_worker_id and booking_id=p_booking_id and assignment_status='completed'
 for update;
 if not found then raise exception 'Completed worker assignment not found'; end if;

 update public.srk_booking_final_bills
 set status='void',updated_at=clock_timestamp()
 where booking_id=p_booking_id and status in ('issued','disputed');
 update public.srk_worker_earnings
 set payout_status='held',settlement_status='held',updated_at=clock_timestamp()
 where booking_id=p_booking_id;

 update public.srk_booking_workers
 set assignment_status='assigned',released_at=null,
  worker_completed_at=null,worker_completion_note=null,
  admin_note=p_reason,updated_at=clock_timestamp()
 where id=p_booking_worker_id returning * into v_assignment;

 update public.srk_worker_schedule_blocks
 set block_status='in_progress',updated_at=clock_timestamp()
 where booking_worker_id=p_booking_worker_id and block_status='completed';

 update public.service_bookings
 set status='in_progress',completion_approval_status='reopened',
  completion_requested_at=null,work_timer_running=false,admin_change_reason=p_reason
 where id=p_booking_id;

 insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
 select w.user_id,'work_reopened','Work reopened by Admin',
  'Admin reopened your work assignment. Reason: '||p_reason,p_booking_id
 from public.srk_worker_profiles w where w.id=v_assignment.worker_id;
 insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
 values(v_booking.customer_user_id,'work_reopened','Work reopened',
  'Admin reopened the work after the completion dispute. Reason: '||p_reason,p_booking_id);
 return v_assignment;
end
$function$;