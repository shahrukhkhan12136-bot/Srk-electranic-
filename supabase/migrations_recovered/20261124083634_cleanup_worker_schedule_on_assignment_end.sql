alter table public.srk_booking_schedule_events
  alter column actor_user_id drop not null;
alter table public.srk_booking_schedule_events
  add column if not exists actor_type text not null default 'user';
alter table public.srk_booking_schedule_events
  add constraint srk_booking_schedule_event_actor_type_valid
  check (actor_type in ('user','system'));

create or replace function private.srk_cleanup_worker_schedule_after_assignment_terminal()
returns trigger
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare
 v_actor uuid:=auth.uid();
 v_proposal_id uuid;
 v_note text;
begin
 if tg_op='UPDATE'
    and new.assignment_status is distinct from old.assignment_status
    and new.assignment_status in ('completed','cancelled','released','rejected') then

  v_note:='Automatically closed because worker assignment status changed to '||new.assignment_status||'.';

  update public.srk_worker_schedule_blocks
  set block_status=case when ends_at<=clock_timestamp() then 'completed' else 'cancelled' end,
      updated_at=clock_timestamp()
  where booking_worker_id=new.id
    and block_status in ('reserved','confirmed','in_progress');

  for v_proposal_id in
    update public.srk_booking_schedule_proposals
    set status='cancelled',
        customer_response_note=v_note,
        responded_at=clock_timestamp()
    where booking_worker_id=new.id
      and status in ('proposed','accepted')
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

drop trigger if exists srk_cleanup_worker_schedule_on_assignment_terminal on public.srk_booking_workers;
create trigger srk_cleanup_worker_schedule_on_assignment_terminal
after update of assignment_status on public.srk_booking_workers
for each row
execute function private.srk_cleanup_worker_schedule_after_assignment_terminal();