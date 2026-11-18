-- Electrician financial visibility is derived only from persisted server-side
-- booking, Razorpay order, verified payment evidence and payout-ledger records.
-- Source-only migration. Do NOT apply to Production without explicit approval.
--
-- New-category 85/15 display split is calculated from the immutable labour bill.
-- Existing commission_rate/platform_commission and payout ledger are NOT changed
-- or deducted again by this migration. Payout remains a separate ledger/status.

drop function if exists public.srk_get_my_offer_details();

create function public.srk_get_my_offer_details()
returns table(
  offer_id uuid,
  offer_status text,
  match_level text,
  offer_created_at timestamptz,
  offer_expires_at timestamptz,
  booking_id uuid,
  service_type text,
  state text,
  district text,
  pincode text,
  work_details text,
  quoted_amount numeric,
  booking_status text,
  selected_category text,
  selected_rate_tier text,
  selected_duration_hours smallint,
  electrician_offer_paise bigint,
  work_start_approval_status text,
  completion_approval_status text,
  customer_name text,
  customer_phone text,
  address text,
  location_lat double precision,
  location_lng double precision,
  service_charge numeric,
  materials_amount numeric,
  quote_status text,
  quote_note text
)
language sql
stable
security definer
set search_path = ''
as $function$
  select
    o.id,
    o.status,
    o.match_level,
    o.created_at,
    o.expires_at,
    b.id,
    b.service_type,
    b.state,
    b.district,
    b.pincode,
    b.work_details,
    case
      when b.assigned_electrician_id=p.id
       and b.status in ('assigned','inspection','awaiting_quote_approval','quote_approved',
         'quote_rejected','awaiting_work_start_approval','in_progress','completed','cancelled')
       and ((b.razorpay_order_id is not null and b.payment_status='pending') or
         (b.payment_status='paid' and b.payment_verified_at is not null and
          (b.razorpay_payment_id is not null or exists(
            select 1 from public.srk_manual_payment_entries me
            where me.booking_id=b.id
              and round(me.amount,2)=round(coalesce(b.amount_paid,0),2)
          ))))
      then b.quoted_amount else null
    end,
    b.status,
    b.selected_category,
    b.selected_rate_tier,
    b.selected_duration_hours,
    case
      when b.selected_category is not null
       and b.estimated_labour_paise is not null
       and b.estimated_labour_paise>0
      then floor((b.estimated_labour_paise::numeric*85+50)/100)::bigint
      else null
    end,
    b.work_start_approval_status,
    b.completion_approval_status,
    case when b.assigned_electrician_id=p.id and b.status in (
      'assigned','inspection','awaiting_quote_approval','quote_approved','quote_rejected',
      'awaiting_work_start_approval','in_progress','completed','cancelled')
      then b.customer_name else null end,
    case when b.assigned_electrician_id=p.id and b.status in (
      'assigned','inspection','awaiting_quote_approval','quote_approved','quote_rejected',
      'awaiting_work_start_approval','in_progress','completed','cancelled')
      then b.phone else null end,
    case when b.assigned_electrician_id=p.id and b.status in (
      'assigned','inspection','awaiting_quote_approval','quote_approved','quote_rejected',
      'awaiting_work_start_approval','in_progress','completed','cancelled')
      then b.address else null end,
    case when b.assigned_electrician_id=p.id and b.status='completed'
      and ((b.razorpay_order_id is not null and b.payment_status='pending') or
        (b.payment_status='paid' and b.payment_verified_at is not null and
         (b.razorpay_payment_id is not null or exists(
           select 1 from public.srk_manual_payment_entries me
           where me.booking_id=b.id
             and round(me.amount,2)=round(coalesce(b.amount_paid,0),2)
         ))))
      then b.location_lat else
      case when b.assigned_electrician_id=p.id and b.status in (
        'assigned','inspection','awaiting_quote_approval','quote_approved','quote_rejected',
        'awaiting_work_start_approval','in_progress','completed','cancelled')
      then b.location_lat else null end end,
    case when b.assigned_electrician_id=p.id and b.status in (
      'assigned','inspection','awaiting_quote_approval','quote_approved','quote_rejected',
      'awaiting_work_start_approval','in_progress','completed','cancelled')
      then b.location_lng else null end,
    case when b.assigned_electrician_id=p.id and b.status='completed'
      and ((b.razorpay_order_id is not null and b.payment_status='pending') or
        (b.payment_status='paid' and b.payment_verified_at is not null and
         (b.razorpay_payment_id is not null or exists(
           select 1 from public.srk_manual_payment_entries me
           where me.booking_id=b.id
             and round(me.amount,2)=round(coalesce(b.amount_paid,0),2)
         ))))
      then b.service_charge else null end,
    case when b.assigned_electrician_id=p.id and b.status='completed'
      and ((b.razorpay_order_id is not null and b.payment_status='pending') or
        (b.payment_status='paid' and b.payment_verified_at is not null and
         (b.razorpay_payment_id is not null or exists(
           select 1 from public.srk_manual_payment_entries me
           where me.booking_id=b.id
             and round(me.amount,2)=round(coalesce(b.amount_paid,0),2)
         ))))
      then b.materials_amount else null end,
    case when b.assigned_electrician_id=p.id and b.status='completed'
      and ((b.razorpay_order_id is not null and b.payment_status='pending') or
        (b.payment_status='paid' and b.payment_verified_at is not null and
         (b.razorpay_payment_id is not null or exists(
           select 1 from public.srk_manual_payment_entries me
           where me.booking_id=b.id
             and round(me.amount,2)=round(coalesce(b.amount_paid,0),2)
         ))))
      then b.quote_status else null end,
    case when b.assigned_electrician_id=p.id and b.status='completed'
      and ((b.razorpay_order_id is not null and b.payment_status='pending') or
        (b.payment_status='paid' and b.payment_verified_at is not null and
         (b.razorpay_payment_id is not null or exists(
           select 1 from public.srk_manual_payment_entries me
           where me.booking_id=b.id
             and round(me.amount,2)=round(coalesce(b.amount_paid,0),2)
         ))))
      then b.quote_note else null end
  from public.job_offers o
  join public.electrician_profiles p on p.id=o.electrician_id
  join public.service_bookings b on b.id=o.booking_id
  where auth.uid() is not null
    and (p.user_id=auth.uid() or p.auth_user_id=auth.uid())
    and p.verification_status='approved'
    and p.active=true
  order by o.created_at desc
  limit 100;
$function$;

revoke all on function public.srk_get_my_offer_details() from public, anon;
grant execute on function public.srk_get_my_offer_details() to authenticated;

comment on function public.srk_get_my_offer_details() is
'Returns electrician 85% offer paise only; never returns estimated customer gross. Quote/service/material finance fields are gated until persisted checkout or verified payment.';

-- Change the RPC response contract so amount_received and company_share are NULL
-- until the trusted checkout/payment stage. The stage is derived exclusively
-- from persisted Razorpay order ID, payment_status, payment_verified_at and
-- provider/manual payment evidence; no client-supplied stage is accepted.
drop function if exists public.srk_get_my_earnings();

create function public.srk_get_my_earnings()
returns table(
  booking_id uuid,
  service_type text,
  booking_created_at timestamptz,
  booking_status text,
  payment_status text,
  payment_stage text,
  amount_received numeric,
  customer_labour_gross numeric,
  company_share numeric,
  electrician_earning numeric,
  payout_status text,
  payout_amount numeric
)
language sql
stable
security definer
set search_path = ''
as $function$
  select
    b.id,
    b.service_type,
    b.created_at,
    b.status,
    b.payment_status,
    case
      when b.status='completed' and b.payment_status='refunded' then 'refunded'
      when b.status='completed' and b.payment_status='paid'
       and b.payment_verified_at is not null
       and (b.razorpay_payment_id is not null or exists(
         select 1 from public.srk_manual_payment_entries me
         where me.booking_id=b.id
           and round(me.amount,2)=round(coalesce(b.amount_paid,0),2)
       )) then 'payment_verified'
      when b.status='completed' and b.razorpay_order_id is not null
       and b.payment_status='pending' then 'checkout_started'
      when b.status='completed' then 'completed_unpaid'
      else 'in_progress'
    end,
    case
      when b.status='completed' and b.payment_status='paid'
       and b.payment_verified_at is not null
       and (b.razorpay_payment_id is not null or exists(
         select 1 from public.srk_manual_payment_entries me
         where me.booking_id=b.id
           and round(me.amount,2)=round(coalesce(b.amount_paid,0),2)
       )) then coalesce(b.amount_paid,0)
      else null
    end,
    case
      when b.status='completed'
       and ((b.razorpay_order_id is not null and b.payment_status='pending') or
         (b.payment_status='paid' and b.payment_verified_at is not null and
          (b.razorpay_payment_id is not null or exists(
            select 1 from public.srk_manual_payment_entries me
            where me.booking_id=b.id
              and round(me.amount,2)=round(coalesce(b.amount_paid,0),2)
          ))))
       and bill.booking_id is not null
      then round(bill.labour_amount_paise/100,2)
      else null
    end,
    case
      when b.status='completed'
       and ((b.razorpay_order_id is not null and b.payment_status='pending') or
         (b.payment_status='paid' and b.payment_verified_at is not null and
          (b.razorpay_payment_id is not null or exists(
            select 1 from public.srk_manual_payment_entries me
            where me.booking_id=b.id
              and round(me.amount,2)=round(coalesce(b.amount_paid,0),2)
          ))))
       and bill.booking_id is not null
      then round((bill.labour_amount_paise -
        floor((bill.labour_amount_paise*85+50)/100))/100,2)
      else null
    end,
    case
      when b.status='completed' and bill.booking_id is not null
       and b.payment_status in ('pending','unpaid','paid')
      then round(floor((bill.labour_amount_paise*85+50)/100)/100,2)
      when b.status='completed' and b.payment_status='paid'
       and b.payment_verified_at is not null
       and b.selected_category is null
      then coalesce(payout.electrician_payable,0)
      else null
    end,
    case
      when b.status='completed' and b.payment_status='paid'
       and b.payment_verified_at is not null
       and (b.razorpay_payment_id is not null or exists(
         select 1 from public.srk_manual_payment_entries me
         where me.booking_id=b.id
           and round(me.amount,2)=round(coalesce(b.amount_paid,0),2)
       ))
      then coalesce(payout.payout_status,'not_recorded')
      else null
    end,
    case
      when b.status='completed' and b.payment_status='paid'
       and b.payment_verified_at is not null
       and (b.razorpay_payment_id is not null or exists(
         select 1 from public.srk_manual_payment_entries me
         where me.booking_id=b.id
           and round(me.amount,2)=round(coalesce(b.amount_paid,0),2)
       ))
      then payout.electrician_payable
      else null
    end
  from public.electrician_profiles ep
  join public.service_bookings b on b.assigned_electrician_id=ep.id
  left join public.srk_booking_labour_bills bill
    on bill.booking_id=b.id and bill.electrician_profile_id=ep.id
  left join public.srk_electrician_payouts payout on payout.booking_id=b.id
  where auth.uid() is not null
    and (ep.user_id=auth.uid() or ep.auth_user_id=auth.uid())
    and ep.verification_status='approved'
  order by b.created_at desc
  limit 200;
$function$;

revoke all on function public.srk_get_my_earnings() from public, anon;
grant execute on function public.srk_get_my_earnings() to authenticated;

comment on function public.srk_get_my_earnings() is
'Payment-stage gated electrician earnings. Checkout stage comes from persisted Razorpay order; verified stage requires persisted payment verification evidence. Payout amount/status are separately read from the payout ledger. New-category 85/15 display is derived from immutable labour bill and does not modify legacy commission_rate or payout calculations.';
