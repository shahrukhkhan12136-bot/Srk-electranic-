-- Main Admin-only customer refund review queue. Approval never sends money.
create or replace function public.srk_admin_list_booking_refund_requests()
returns table(
  request_id uuid,
  booking_id uuid,
  customer_user_id uuid,
  customer_name text,
  customer_phone text,
  booking_status text,
  payment_method text,
  payment_status text,
  amount_paid numeric,
  razorpay_payment_id text,
  request_amount numeric,
  request_reason text,
  request_status text,
  admin_note text,
  created_at timestamptz,
  updated_at timestamptz,
  processed_at timestamptz,
  labour_amount_paise bigint
)
language plpgsql
stable
security definer
set search_path=''
as $function$
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'ADMIN_ACCESS_REQUIRED' using errcode='42501';
  end if;
  return query
  select r.id,r.booking_id,r.customer_user_id,b.customer_name,b.phone,
         b.status,b.payment_method,b.payment_status,b.amount_paid,
         b.razorpay_payment_id,r.amount,r.reason,r.status,r.admin_note,
         r.created_at,r.updated_at,r.processed_at,
         bill.labour_amount_paise::bigint
  from public.srk_booking_refund_requests r
  join public.service_bookings b on b.id=r.booking_id
  left join public.srk_booking_labour_bills bill
    on bill.booking_id=b.id and bill.customer_user_id=r.customer_user_id
  order by case r.status when 'requested' then 0 when 'in_review' then 1 else 2 end,
           r.created_at desc,r.id desc;
end;
$function$;

create or replace function public.srk_admin_decide_booking_refund_request(
  p_request_id uuid,
  p_decision text,
  p_admin_note text
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $function$
declare
  v_request public.srk_booking_refund_requests%rowtype;
  v_note text:=btrim(coalesce(p_admin_note,''));
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'ADMIN_ACCESS_REQUIRED' using errcode='42501';
  end if;
  if p_request_id is null
     or p_decision is null
     or p_decision not in ('in_review','approved','rejected')
     or length(v_note) not between 10 and 2000 then
    raise exception 'INVALID_REFUND_REVIEW_DECISION_OR_AUDIT_NOTE' using errcode='22023';
  end if;

  select * into v_request
  from public.srk_booking_refund_requests r
  where r.id=p_request_id
  for update;
  if not found then raise exception 'REFUND_REQUEST_NOT_FOUND' using errcode='P0002'; end if;

  if not (
    (v_request.status='requested' and p_decision in ('in_review','approved','rejected'))
    or (v_request.status='in_review' and p_decision in ('approved','rejected'))
  ) then
    raise exception 'INVALID_REFUND_REQUEST_STATE_TRANSITION' using errcode='55000';
  end if;

  update public.srk_booking_refund_requests
  set status=p_decision,
      admin_note=v_note,
      decided_by=case when p_decision in ('approved','rejected') then auth.uid() else decided_by end,
      updated_at=clock_timestamp()
  where id=v_request.id
  returning * into v_request;

  return jsonb_build_object(
    'success',true,
    'request_id',v_request.id,
    'booking_id',v_request.booking_id,
    'status',v_request.status,
    'updated_at',v_request.updated_at
  );
end;
$function$;

revoke all on function public.srk_admin_list_booking_refund_requests() from public,anon;
grant execute on function public.srk_admin_list_booking_refund_requests() to authenticated;
revoke all on function public.srk_admin_decide_booking_refund_request(uuid,text,text) from public,anon;
grant execute on function public.srk_admin_decide_booking_refund_request(uuid,text,text) to authenticated;
