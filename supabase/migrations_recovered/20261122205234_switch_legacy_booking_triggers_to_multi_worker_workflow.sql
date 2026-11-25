
drop trigger if exists broadcast_new_booking on public.service_bookings;
drop trigger if exists trg_srk_create_electrician_payable on public.service_bookings;
drop trigger if exists srk_audit_service_bookings on public.service_bookings;

create or replace function public.srk_guard_work_approval_transitions()
returns trigger language plpgsql security definer
set search_path=pg_catalog,public,srk_private,pg_temp
as $$
declare v_authorized boolean; v_multi_worker boolean; v_running boolean; v_bill_issued boolean;
begin
  select exists(select 1 from public.srk_booking_workers bw where bw.booking_id=new.id)
    into v_multi_worker;

  if v_multi_worker then
    select exists(select 1 from public.srk_worker_work_sessions s
      join public.srk_booking_workers bw on bw.id=s.booking_worker_id
      where bw.booking_id=new.id and s.session_status='running') into v_running;
    select exists(select 1 from public.srk_booking_final_bills f
      where f.booking_id=new.id and f.status in ('issued','approved')) into v_bill_issued;

    if new.status='in_progress' and new.status is distinct from old.status
       and (v_running or new.completion_approval_status='reopened') then
      return new;
    end if;
    if new.status='completed' and new.status is distinct from old.status
       and new.completion_approval_status='approved' and v_bill_issued then
      return new;
    end if;
  end if;

  if new.status is distinct from old.status and new.status in ('in_progress','completed') then
    select exists(
      select 1 from srk_private.work_transition_authorizations a
      where a.transaction_id=pg_catalog.txid_current()
        and a.booking_id=new.id and a.target_status=new.status
    ) into v_authorized;
    if not v_authorized then
      raise exception 'Authorized work approval workflow is required'
        using errcode='42501';
    end if;
  end if;
  if new.status='completed' and new.status is distinct from old.status
     and new.completion_approval_status not in ('approved','admin_approved') then
    raise exception 'Customer or Admin completion approval is required';
  end if;
  if new.status='in_progress' and new.status is distinct from old.status
     and new.work_start_approval_status<>'approved'
     and new.completion_approval_status<>'reopened' then
    raise exception 'Customer work-start approval is required';
  end if;
  return new;
end $$;

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
  update public.service_bookings set status='in_progress',completion_approval_status='reopened',
    completion_requested_at=null,work_timer_running=false,admin_change_reason=p_reason
    where id=p_booking_id;
  insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
  select w.user_id,'work_reopened','Work reopened by Admin','Admin reopened your work assignment. Reason: '||p_reason,p_booking_id
    from public.srk_worker_profiles w where w.id=v_assignment.worker_id;
  return v_assignment;
end $$;
