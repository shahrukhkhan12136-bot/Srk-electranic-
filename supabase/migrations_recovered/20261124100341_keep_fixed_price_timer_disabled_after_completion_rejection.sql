CREATE OR REPLACE FUNCTION public.srk_customer_respond_work_completion(
 p_booking_id uuid,p_response text,p_note text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
declare
 v_booking public.service_bookings%rowtype;
 v_note text:=nullif(pg_catalog.btrim(p_note),'');
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 if p_response is null or p_response not in ('approved','rejected','disputed')
  or (p_note is not null and pg_catalog.length(p_note)>1000) then
  raise exception 'Invalid completion response';
 end if;
 if p_response='disputed' and (v_note is null or pg_catalog.length(v_note)<20) then
  raise exception 'विवाद का कारण कम से कम 20 अक्षरों में लिखें';
 end if;
 select * into v_booking from public.service_bookings
 where id=p_booking_id and customer_user_id=auth.uid() for update;
 if not found then raise exception 'Customer booking not found' using errcode='42501'; end if;
 if v_booking.status<>'in_progress' or v_booking.completion_approval_status<>'pending'
  or v_booking.completion_requested_at is null then
  raise exception 'No completion request is waiting for your response';
 end if;
 if p_response='approved' then
  insert into srk_private.work_transition_authorizations(transaction_id,booking_id,target_status)
  values(pg_catalog.txid_current(),p_booking_id,'completed');
  update public.service_bookings set status='completed',
   completion_approval_status='approved',customer_completed_at=pg_catalog.now(),
   work_timer_running=false
  where id=p_booking_id;
 elsif p_response='rejected' then
  update public.service_bookings set completion_approval_status='rejected',
   completion_requested_at=null,work_started_at=pg_catalog.now(),
   work_timer_running=coalesce(v_booking.pricing_unit_snapshot,'hour') not in ('per_item','motor_hp')
  where id=p_booking_id;
 else
  insert into public.srk_booking_complaints(booking_id,customer_user_id,category,description)
  values(p_booking_id,auth.uid(),'service_quality','काम पूरा होने पर विवाद: '||v_note);
  update public.service_bookings set completion_approval_status='disputed',
   work_timer_running=false
  where id=p_booking_id;
 end if;
 if p_response='approved' then
  delete from srk_private.work_transition_authorizations
  where transaction_id=pg_catalog.txid_current() and booking_id=p_booking_id
   and target_status='completed';
 end if;
 return pg_catalog.jsonb_build_object('success',true,'response',p_response);
end
$function$;