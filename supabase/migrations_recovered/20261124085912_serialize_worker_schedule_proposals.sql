CREATE OR REPLACE FUNCTION public.srk_worker_propose_next_schedule(
 p_booking_worker_id uuid,p_start_at timestamptz,p_end_at timestamptz
) RETURNS public.srk_booking_schedule_proposals
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth'
AS $function$
declare
 v_proposal public.srk_booking_schedule_proposals%rowtype;
 v_booking_id uuid;
 v_assignment public.srk_booking_workers%rowtype;
 v_booking public.service_bookings%rowtype;
 v_old_proposal_id uuid;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if p_booking_worker_id is null or p_start_at<=clock_timestamp() or p_end_at<=p_start_at then
  raise exception 'Future valid schedule range required';
 end if;

 select booking_id into v_booking_id
 from public.srk_booking_workers bw
 join public.srk_worker_profiles w on w.id=bw.worker_id
 where bw.id=p_booking_worker_id and w.user_id=auth.uid();
 if not found then raise exception 'Only assigned worker can propose the next work schedule'; end if;

 select * into v_booking from public.service_bookings
 where id=v_booking_id for update;
 if not found or v_booking.status='cancelled' or v_booking.status='completed' then
  raise exception 'Booking is no longer available for schedule proposals';
 end if;

 select * into v_assignment from public.srk_booking_workers
 where id=p_booking_worker_id for update;
 if not found or v_assignment.assignment_status not in ('accepted','assigned','working','paused') then
  raise exception 'Only an active assigned worker can propose the next work schedule';
 end if;

 -- Keep only one pending proposal per assignment. A newer proposal supersedes
 -- any unanswered proposal, while already accepted schedule blocks stay intact.
 for v_old_proposal_id in
  update public.srk_booking_schedule_proposals
  set status='cancelled',
      customer_response_note='Superseded by a newer worker schedule proposal.',
      responded_at=clock_timestamp()
  where booking_worker_id=p_booking_worker_id and status='proposed'
  returning id
 loop
  insert into public.srk_booking_schedule_events(proposal_id,actor_user_id,action,note,actor_type)
  values(v_old_proposal_id,auth.uid(),'cancelled','Superseded by a newer worker schedule proposal.','user');
 end loop;

 insert into public.srk_booking_schedule_proposals(
  booking_worker_id,proposed_by,proposed_start_at,proposed_end_at
 ) values(p_booking_worker_id,auth.uid(),p_start_at,p_end_at)
 returning * into v_proposal;

 insert into public.srk_booking_schedule_events(proposal_id,actor_user_id,action)
 values(v_proposal.id,auth.uid(),'proposed');
 return v_proposal;
end
$function$;