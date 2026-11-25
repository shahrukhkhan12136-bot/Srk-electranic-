
create or replace function public.srk_worker_respond_assignment(p_assignment_id uuid,p_accept boolean)
returns public.srk_booking_workers
language plpgsql security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare
 v_assignment public.srk_booking_workers%rowtype;
 v_worker public.srk_worker_profiles%rowtype;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 select bw.* into v_assignment
 from public.srk_booking_workers bw
 join public.srk_worker_profiles wp on wp.id=bw.worker_id
 where bw.id=p_assignment_id and wp.user_id=auth.uid()
 for update of bw;
 if not found or v_assignment.assignment_status<>'offered' then
  raise exception 'Offer not found or no longer pending';
 end if;
 select * into v_worker from public.srk_worker_profiles where id=v_assignment.worker_id;
 if p_accept and (v_worker.verification_status<>'approved' or not v_worker.is_active) then
  raise exception 'Worker is not currently approved and active';
 end if;
 update public.srk_booking_workers
 set assignment_status=case when p_accept then 'accepted' else 'rejected' end,
  accepted_at=case when p_accept then clock_timestamp() else null end,
  rejected_at=case when p_accept then null else clock_timestamp() end,
  offer_expires_at=null,updated_at=clock_timestamp()
 where id=p_assignment_id returning * into v_assignment;
 -- Queue processor alone confirms a booking after all requested technicians AND helpers accept.
 update public.srk_booking_matching_queue
 set queue_status='pending',next_attempt_at=clock_timestamp(),updated_at=clock_timestamp()
 where booking_id=v_assignment.booking_id and queue_status not in ('fulfilled','cancelled');
 return v_assignment;
end
$function$;
revoke all on function public.srk_worker_respond_assignment(uuid,boolean) from public,anon;
grant execute on function public.srk_worker_respond_assignment(uuid,boolean) to authenticated;
