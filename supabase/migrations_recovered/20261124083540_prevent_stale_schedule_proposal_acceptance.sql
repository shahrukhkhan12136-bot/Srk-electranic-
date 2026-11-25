CREATE OR REPLACE FUNCTION public.srk_customer_respond_schedule_proposal(
 p_proposal_id uuid,p_accept boolean,p_note text DEFAULT NULL::text
)
RETURNS public.srk_booking_schedule_proposals
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth'
AS $function$
declare
 v_proposal public.srk_booking_schedule_proposals%rowtype;
 v_assignment public.srk_booking_workers%rowtype;
 v_booking public.service_bookings%rowtype;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if p_proposal_id is null or (p_note is not null and length(p_note)>1000) then
  raise exception 'Valid schedule proposal response is required' using errcode='22023';
 end if;

 -- Lock in booking -> assignment -> proposal order, matching cancellation paths.
 select bw.booking_id into v_assignment.booking_id
 from public.srk_booking_schedule_proposals p
 join public.srk_booking_workers bw on bw.id=p.booking_worker_id
 join public.service_bookings b on b.id=bw.booking_id
 where p.id=p_proposal_id and b.customer_user_id=auth.uid();
 if not found then raise exception 'Proposal not found for this customer'; end if;

 select * into v_booking from public.service_bookings
 where id=v_assignment.booking_id and customer_user_id=auth.uid()
 for update;
 if not found then raise exception 'Customer booking not found'; end if;

 select * into v_assignment from public.srk_booking_workers
 where id=(select booking_worker_id from public.srk_booking_schedule_proposals where id=p_proposal_id)
 for update;
 if not found then raise exception 'Booking assignment not found'; end if;

 select * into v_proposal from public.srk_booking_schedule_proposals
 where id=p_proposal_id for update;
 if not found or v_proposal.status<>'proposed' then
  raise exception 'Proposal not found or no longer pending';
 end if;

 if v_booking.status='cancelled'
    or v_assignment.assignment_status not in ('accepted','assigned','working','paused') then
  update public.srk_booking_schedule_proposals
  set status='cancelled',
      customer_response_note=coalesce(nullif(btrim(p_note),''),'Automatically cancelled because the booking assignment is no longer active.'),
      responded_at=clock_timestamp()
  where id=p_proposal_id returning * into v_proposal;
  insert into public.srk_booking_schedule_events(proposal_id,actor_user_id,action,note)
  values(p_proposal_id,auth.uid(),'cancelled','Booking or worker assignment is no longer active.');
  insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
  select w.user_id,'schedule_response','Schedule proposal cancelled',
    'The proposed schedule is no longer available because the booking assignment is no longer active.',
    v_booking.id
  from public.srk_worker_profiles w where w.id=v_assignment.worker_id;
  return v_proposal;
 end if;

 if v_proposal.proposed_start_at<=clock_timestamp() then
  update public.srk_booking_schedule_proposals
  set status='expired',
      customer_response_note=coalesce(nullif(btrim(p_note),''),'Proposal expired before the customer response.'),
      responded_at=clock_timestamp()
  where id=p_proposal_id returning * into v_proposal;
  insert into public.srk_booking_schedule_events(proposal_id,actor_user_id,action,note)
  values(p_proposal_id,auth.uid(),'expired','Proposal start time passed before customer response.');
  insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
  select w.user_id,'schedule_response','Schedule proposal expired',
    'The customer response arrived after the proposed start time. Please propose a new schedule.',
    v_booking.id
  from public.srk_worker_profiles w where w.id=v_assignment.worker_id;
  return v_proposal;
 end if;

 if p_accept then
  insert into public.srk_worker_schedule_blocks(worker_id,booking_worker_id,starts_at,ends_at,block_status)
  values(v_assignment.worker_id,v_assignment.id,v_proposal.proposed_start_at,v_proposal.proposed_end_at,'confirmed');
 end if;

 update public.srk_booking_schedule_proposals
 set status=case when p_accept then 'accepted' else 'declined' end,
     customer_response_note=p_note,responded_at=clock_timestamp()
 where id=p_proposal_id returning * into v_proposal;

 insert into public.srk_booking_schedule_events(proposal_id,actor_user_id,action,note)
 values(p_proposal_id,auth.uid(),case when p_accept then 'accepted' else 'declined' end,p_note);

 insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
 select w.user_id,'schedule_response',
   case when p_accept then 'Schedule accepted' else 'Schedule declined' end,
   case when p_accept then 'Customer accepted the proposed work schedule.' else 'Customer declined the proposed work schedule. Please propose another time.' end,
   v_booking.id
 from public.srk_worker_profiles w where w.id=v_assignment.worker_id;
 return v_proposal;
end
$function$;