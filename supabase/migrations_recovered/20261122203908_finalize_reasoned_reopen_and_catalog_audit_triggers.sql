
create or replace function public.srk_admin_reopen_booking_work(p_booking_id uuid,p_booking_worker_id uuid,p_reason text)
returns public.srk_booking_workers
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v_booking public.service_bookings%rowtype; v_assignment public.srk_booking_workers%rowtype;
begin
  if not public.srk_has_admin_permission('bookings.manage') then raise exception 'Booking management permission required'; end if;
  if length(coalesce(p_reason,''))<10 then raise exception 'Reopen reason must be at least 10 characters'; end if;
  select * into v_booking from public.service_bookings where id=p_booking_id for update;
  if not found then raise exception 'Booking not found'; end if;
  if v_booking.payment_status='paid' then raise exception 'Paid booking cannot be reopened; use refund/dispute workflow'; end if;
  if v_booking.completion_approval_status not in ('rejected','disputed') then raise exception 'Only rejected or disputed completion can be reopened'; end if;
  select * into v_assignment from public.srk_booking_workers
  where id=p_booking_worker_id and booking_id=p_booking_id and assignment_status='completed' for update;
  if not found then raise exception 'Completed worker assignment not found'; end if;

  update public.srk_booking_final_bills set status='void',updated_at=clock_timestamp()
  where booking_id=p_booking_id and status in ('issued','disputed');
  update public.srk_worker_earnings set payout_status='held',settlement_status='held',updated_at=clock_timestamp()
  where booking_id=p_booking_id;

  update public.srk_booking_workers set assignment_status='assigned',released_at=null,
    admin_note=p_reason,updated_at=clock_timestamp()
  where id=p_booking_worker_id returning * into v_assignment;

  update public.service_bookings set status='in_progress',completion_approval_status='rejected',
    completion_requested_at=null,work_timer_running=false,admin_change_reason=p_reason
  where id=p_booking_id;

  insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
  select w.user_id,'work_reopened','Work reopened by Admin','Admin reopened your work assignment. Reason: '||p_reason,p_booking_id
  from public.srk_worker_profiles w where w.id=v_assignment.worker_id;
  return v_assignment;
end $$;

create or replace function public.srk_log_admin_entity_change()
returns trigger language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v_old jsonb; v_new jsonb; v_id uuid; v_booking uuid; v_changed text[];
  v_actor_role text; v_reason text;
begin
  if auth.uid() is null then if tg_op='DELETE' then return old; else return new; end if; end if;
  if not exists(select 1 from public.srk_admin_users where user_id=auth.uid())
     and not exists(select 1 from public.srk_admin_staff_members where user_id=auth.uid() and is_active) then
    if tg_op='DELETE' then return old; else return new; end if;
  end if;
  v_old:=case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) else '{}'::jsonb end;
  v_new:=case when tg_op in ('INSERT','UPDATE') then to_jsonb(new) else '{}'::jsonb end;
  v_id:=coalesce(nullif(v_new->>'id','')::uuid,nullif(v_old->>'id','')::uuid);
  v_booking:=coalesce(nullif(v_new->>'booking_id','')::uuid,nullif(v_old->>'booking_id','')::uuid);
  v_actor_role:=case when exists(select 1 from public.srk_admin_users where user_id=auth.uid()) then 'super_admin' else 'staff' end;
  v_reason:=coalesce(v_new->>'admin_note',v_new->>'change_reason',v_new->>'admin_change_reason',
    v_new->>'moderation_note',v_new->>'reason','Admin panel change');
  select coalesce(array_agg(k),array[]::text[]) into v_changed
  from (select key k from jsonb_object_keys(v_new) key union select key k from jsonb_object_keys(v_old) key) keys
  where v_old->k is distinct from v_new->k;
  insert into public.srk_admin_audit_events(entity_type,entity_id,booking_id,action,actor_user_id,actor_role,changed_fields,before_data,after_data)
  values(tg_argv[0],v_id,v_booking,tg_op,auth.uid(),v_actor_role,v_changed,v_old,
    jsonb_set(v_new,'{admin_action_reason}',to_jsonb(v_reason),true));
  if v_booking is not null then
    insert into public.srk_booking_admin_changes(booking_id,admin_user_id,entity_type,entity_id,action,reason,old_values,new_values)
    values(v_booking,auth.uid(),tg_argv[0],v_id,tg_op,v_reason,v_old,v_new);
  end if;
  if tg_op='DELETE' then return old; else return new; end if;
end $$;

drop trigger if exists srk_audit_service_type_admin on public.srk_service_types;
create trigger srk_audit_service_type_admin after insert or update or delete on public.srk_service_types
for each row execute function public.srk_log_admin_entity_change('service_type');

drop trigger if exists srk_audit_service_skill_admin on public.srk_service_skills;
create trigger srk_audit_service_skill_admin after insert or update or delete on public.srk_service_skills
for each row execute function public.srk_log_admin_entity_change('service_skill');

drop trigger if exists srk_audit_booking_receipt_admin on public.srk_booking_receipts;
create trigger srk_audit_booking_receipt_admin after insert or update or delete on public.srk_booking_receipts
for each row execute function public.srk_log_admin_entity_change('booking_receipt');
