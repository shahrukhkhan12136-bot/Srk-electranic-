CREATE OR REPLACE FUNCTION public.srk_submit_booking_quote(
 p_booking_id uuid,p_service_charge numeric,p_materials_amount numeric,p_quote_note text DEFAULT NULL::text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
declare
 v_profile_id uuid;
 v_booking public.service_bookings%rowtype;
 v_total numeric(12,2);
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if p_booking_id is null or p_service_charge is null or p_service_charge<=0
    or p_service_charge>10000000 then
  raise exception 'Invalid quote amounts';
 end if;
 if coalesce(p_materials_amount,0)<>0 then
  raise exception 'Materials are outside SRK billing and must not be included in the quote';
 end if;

 select id into v_profile_id
 from public.electrician_profiles
 where (user_id=auth.uid() or auth_user_id=auth.uid())
   and verification_status='approved' and active=true
 order by created_at desc limit 1;
 if v_profile_id is null then raise exception 'Approved active electrician required'; end if;

 select * into v_booking from public.service_bookings
 where id=p_booking_id and assigned_electrician_id=v_profile_id
 for update;
 if not found then raise exception 'Assigned booking not found'; end if;
 if v_booking.status not in ('assigned','inspection','quote_rejected') then
  raise exception 'Booking is not ready for a quote';
 end if;

 v_total:=round(p_service_charge,2);
 update public.service_bookings
 set service_charge=v_total,materials_amount=0,quoted_amount=v_total,
     quote_note=left(coalesce(p_quote_note,''),1000),quote_status='pending',
     quote_submitted_at=pg_catalog.now(),quote_responded_at=null,status='awaiting_quote_approval'
 where id=p_booking_id;
 return pg_catalog.jsonb_build_object('success',true,'total',v_total,'quote_status','pending');
end
$function$;

CREATE OR REPLACE FUNCTION public.srk_admin_review_worker_cancellation(
 p_request_id uuid,p_decision text,p_note text DEFAULT NULL::text
) RETURNS public.srk_worker_cancellation_approval_requests
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth'
AS $function$
declare v public.srk_worker_cancellation_approval_requests%rowtype;
begin
 if not public.srk_has_admin_permission('support.manage') then
  raise exception 'Support permission required';
 end if;
 if p_decision not in ('approved','rejected') then
  raise exception 'Decision must be approved or rejected';
 end if;
 select * into v from public.srk_worker_cancellation_approval_requests
 where id=p_request_id for update;
 if not found then raise exception 'Cancellation request not found'; end if;
 if v.request_status<>'pending' then raise exception 'Request is not pending'; end if;

 update public.srk_worker_cancellation_approval_requests
 set request_status=p_decision,reviewed_by=auth.uid(),reviewed_at=clock_timestamp(),admin_note=p_note
 where id=p_request_id returning * into v;
 update public.srk_booking_workers
 set cancellation_request_status=p_decision,updated_at=clock_timestamp()
 where id=v.booking_worker_id;
 update public.srk_support_cases
 set status=case when p_decision='approved' then 'resolved' else 'closed' end,
     resolution=case when p_decision='approved'
       then 'Approved. Worker must confirm cancellation by retrying the request.'
       else 'Rejected. '||coalesce(p_note,'') end,
     resolved_at=clock_timestamp(),updated_at=clock_timestamp(),admin_note=p_note
 where id=v.support_case_id;
 insert into public.srk_support_case_events(case_id,actor_user_id,action,old_status,new_status,note)
 select v.support_case_id,auth.uid(),'worker_cancellation_'||p_decision,'open',
   case when p_decision='approved' then 'resolved' else 'closed' end,p_note;
 insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
 values(v.worker_user_id,'worker_cancellation_'||p_decision,
   case when p_decision='approved' then 'Cancellation approved' else 'Cancellation request rejected' end,
   case when p_decision='approved'
     then 'Admin approved your cancellation. Please reopen the booking and confirm cancellation.'
     else 'Admin rejected your cancellation request. Please contact Support.' end,v.booking_id);
 return v;
end
$function$;