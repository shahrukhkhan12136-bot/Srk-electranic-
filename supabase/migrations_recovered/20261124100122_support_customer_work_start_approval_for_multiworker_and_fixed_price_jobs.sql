CREATE OR REPLACE FUNCTION public.srk_customer_respond_work_start(
 p_booking_id uuid,p_response text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth'
AS $function$
declare
 v_booking public.service_bookings%rowtype;
 v_multi_worker boolean;
 v_timer_enabled boolean;
 v_next_status text;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 if p_response is null or p_response not in ('approved','rejected') then
  raise exception 'Invalid response';
 end if;
 select * into v_booking from public.service_bookings
 where id=p_booking_id and customer_user_id=auth.uid() for update;
 if not found then raise exception 'Customer booking not found' using errcode='42501'; end if;
 if v_booking.status<>'awaiting_work_start_approval'
  or v_booking.work_start_approval_status<>'pending' then
  raise exception 'No work-start request is waiting for approval';
 end if;
 select exists(select 1 from public.srk_booking_workers where booking_id=p_booking_id)
 into v_multi_worker;
 v_timer_enabled:=v_booking.pricing_unit_snapshot not in ('per_item','motor_hp');
 v_next_status:=case when p_response='approved' then 'in_progress'
  when v_multi_worker then 'confirmed' else 'quote_approved' end;

 if p_response='approved' then
  insert into srk_private.work_transition_authorizations(transaction_id,booking_id,target_status)
  values(pg_catalog.txid_current(),p_booking_id,'in_progress');
 end if;

 update public.service_bookings set
  work_start_approval_status=p_response,
  status=v_next_status,
  work_started_at=case when p_response='approved' then pg_catalog.now() else null end,
  work_timer_running=(p_response='approved' and v_timer_enabled),
  work_timer_seconds=case when p_response='approved' and v_timer_enabled then 0 else work_timer_seconds end
 where id=p_booking_id;

 if p_response='approved' then
  delete from srk_private.work_transition_authorizations
  where transaction_id=pg_catalog.txid_current() and booking_id=p_booking_id
   and target_status='in_progress';
 end if;

 insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
 select wp.user_id,'work_start_response',
  case when p_response='approved' then 'Customer approved work start' else 'Customer rejected work start' end,
  case when p_response='approved' then 'Customer approved the work start. You may begin the job.'
   else 'Customer rejected the work-start request. Contact the customer and arrange another start time.' end,
  p_booking_id
 from public.srk_booking_workers bw
 join public.srk_worker_profiles wp on wp.id=bw.worker_id
 where bw.booking_id=p_booking_id and bw.assignment_status in ('accepted','assigned');

 return pg_catalog.jsonb_build_object(
  'success',true,'response',p_response,'status',v_next_status,
  'timer_enabled',v_timer_enabled
 );
end
$function$;