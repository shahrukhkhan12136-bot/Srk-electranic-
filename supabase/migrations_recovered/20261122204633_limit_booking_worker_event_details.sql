
create or replace function public.srk_log_booking_worker_event()
returns trigger language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v_event text; v_reason text;
begin
  if tg_op='INSERT' then v_event:=new.assignment_status;
  elsif new.assignment_status is distinct from old.assignment_status then v_event:=new.assignment_status;
  else return new;
  end if;
  v_reason:=coalesce(new.admin_note,'');
  insert into public.srk_booking_worker_events(booking_worker_id,booking_id,worker_id,event_type,actor_user_id,reason,details)
  values(new.id,new.booking_id,new.worker_id,v_event,auth.uid(),v_reason,jsonb_build_object('role',new.worker_role));
  return new;
end $$;
revoke all on function public.srk_log_booking_worker_event() from public,anon,authenticated;
