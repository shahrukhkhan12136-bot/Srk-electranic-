create or replace function private.srk_cleanup_worker_schedule_after_assignment_terminal()
returns trigger
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare
 v_actor uuid:=auth.uid();
 v_proposal_id uuid;
 v_session record;
 v_note text;
 v_source text;
begin
 if tg_op='UPDATE'
    and new.assignment_status is distinct from old.assignment_status
    and new.assignment_status in ('completed','cancelled','released','rejected') then

  v_note:='Automatically closed because worker assignment status changed to '||new.assignment_status||'.';
  v_source:=case when v_actor is null then 'system' else 'user' end;

  -- Preserve billable seconds but close any daily session that never started
  -- or was paused when the assignment became terminal.
  for v_session in
   update public.srk_worker_work_sessions
   set session_status='cancelled',
       ended_at=coalesce(ended_at,clock_timestamp()),
       last_resumed_at=null,pause_minimum_until=null,
       completion_note=coalesce(completion_note,v_note),
       updated_at=clock_timestamp()
   where booking_worker_id=new.id and session_status in ('not_started','paused')
   returning id,pause_reason
  loop
   insert into public.srk_worker_session_events(
    session_id,event_type,event_at,actor_user_id,pause_reason,note,source
   ) values(
    v_session.id,'cancelled',clock_timestamp(),v_actor,v_session.pause_reason,v_note,v_source
   );
  end loop;

  update public.srk_worker_schedule_blocks
  set block_status=case when ends_at<=clock_timestamp() then 'completed' else 'cancelled' end,
      updated_at=clock_timestamp()
  where booking_worker_id=new.id
    and block_status in ('reserved','confirmed','in_progress');

  for v_proposal_id in
    update public.srk_booking_schedule_proposals
    set status='cancelled',customer_response_note=v_note,responded_at=clock_timestamp()
    where booking_worker_id=new.id and status in ('proposed','accepted')
    returning id
  loop
    insert into public.srk_booking_schedule_events(
      proposal_id,actor_user_id,action,note,actor_type
    ) values(
      v_proposal_id,v_actor,'cancelled',v_note,
      case when v_actor is null then 'system' else 'user' end
    );
  end loop;
 end if;
 return new;
end
$function$;

revoke all on function private.srk_cleanup_worker_schedule_after_assignment_terminal() from public,anon,authenticated;