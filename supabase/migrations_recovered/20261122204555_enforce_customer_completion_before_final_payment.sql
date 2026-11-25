
create or replace function public.srk_customer_respond_multi_worker_completion(
 p_booking_id uuid,p_response text,p_note text default null
) returns jsonb
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v_booking public.service_bookings%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_response not in ('approved','rejected','disputed') then raise exception 'Invalid completion response'; end if;
  select * into v_booking from public.service_bookings where id=p_booking_id and customer_user_id=auth.uid() for update;
  if not found then raise exception 'Customer booking not found'; end if;
  if not exists(select 1 from public.srk_booking_workers where booking_id=p_booking_id) then raise exception 'Not a multi-worker booking'; end if;
  if v_booking.completion_approval_status<>'pending' or v_booking.completion_requested_at is null then
    raise exception 'No completion request waiting for response';
  end if;
  if not exists(select 1 from public.srk_booking_final_bills where booking_id=p_booking_id and status='issued') then
    raise exception 'Final bill must be issued before completion approval';
  end if;

  if p_response='approved' then
    update public.service_bookings set status='completed',completion_approval_status='approved',
      customer_completed_at=clock_timestamp(),work_timer_running=false
    where id=p_booking_id;
  elsif p_response='rejected' then
    update public.service_bookings set completion_approval_status='rejected',completion_requested_at=null
    where id=p_booking_id;
    insert into public.srk_support_cases(booking_id,raised_by,raised_by_role,category,subject,description,priority)
    values(p_booking_id,auth.uid(),'customer','completion','Customer rejected completion',
      coalesce(p_note,'Customer requested review of completed work.'),'high');
  else
    if length(coalesce(p_note,''))<20 then raise exception 'Dispute reason must be at least 20 characters'; end if;
    update public.service_bookings set completion_approval_status='disputed',work_timer_running=false
    where id=p_booking_id;
    insert into public.srk_support_cases(booking_id,raised_by,raised_by_role,category,subject,description,priority)
    values(p_booking_id,auth.uid(),'customer','completion','Completion dispute',p_note,'high');
  end if;
  return jsonb_build_object('success',true,'response',p_response);
end $$;

create or replace function public.srk_customer_choose_payment_method(p_booking_id uuid,p_method text)
returns public.service_bookings
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v_booking public.service_bookings%rowtype; v_forced_online boolean;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if lower(p_method) not in ('cash','online','upi','card') then raise exception 'Choose Cash, Online, UPI or Card'; end if;
  select * into v_booking from public.service_bookings where id=p_booking_id and customer_user_id=auth.uid() for update;
  if not found then raise exception 'Customer booking not found'; end if;
  if v_booking.status<>'completed' then raise exception 'Payment can be selected after customer confirms completed work'; end if;
  if v_booking.payment_status='paid' then raise exception 'Payment is already completed'; end if;
  if not exists(select 1 from public.srk_booking_final_bills where booking_id=p_booking_id and status in ('issued','approved')) then
    raise exception 'Final bill is not available';
  end if;
  select exists(select 1 from public.srk_booking_workers bw
    join public.srk_technician_booking_cycle c on c.technician_id=bw.worker_id
    where bw.booking_id=p_booking_id and bw.worker_role='technician' and (c.completed_booking_count+1) in (3,6))
  into v_forced_online;
  if v_forced_online and lower(p_method)='cash' then raise exception 'This technician booking requires online payment'; end if;
  update public.service_bookings set payment_method=initcap(lower(p_method)) where id=p_booking_id returning * into v_booking;
  return v_booking;
end $$;

