CREATE OR REPLACE FUNCTION public.srk_admin_review_worker_payout(
 p_payout_id uuid,p_approve boolean,p_approved_amount numeric DEFAULT NULL::numeric,p_note text DEFAULT NULL::text
) RETURNS public.srk_worker_payout_requests
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth'
AS $function$
declare
 v_payout public.srk_worker_payout_requests%rowtype;
 v_worker public.srk_worker_profiles%rowtype;
 v_available numeric(12,2);
 v_reserved numeric(12,2);
 v_amount numeric(12,2);
begin
 if auth.uid() is null or not public.srk_has_admin_permission('payouts.manage') then
  raise exception 'Payout management permission required' using errcode='42501';
 end if;
 if p_approve is null then raise exception 'Approval decision is required' using errcode='22023'; end if;
 if p_approved_amount is not null and
  (p_approved_amount<=0 or p_approved_amount<>round(p_approved_amount,2)) then
  raise exception 'Approved amount must be positive and limited to two decimal places' using errcode='22023';
 end if;

 select * into v_payout from public.srk_worker_payout_requests
 where id=p_payout_id for update;
 if not found or v_payout.status not in ('requested','under_review') then
  raise exception 'Payout request not reviewable';
 end if;

 select * into v_worker from public.srk_worker_profiles
 where id=v_payout.worker_id for update;
 if not found then raise exception 'Worker profile not found'; end if;

 if exists(select 1 from public.srk_worker_earnings
  where worker_id=v_payout.worker_id and settlement_status='held') then
  raise exception 'Worker payout is held due to refund/dispute review';
 end if;

 if not p_approve then
  update public.srk_worker_payout_requests
  set status='rejected',reviewed_at=clock_timestamp(),reviewed_by=auth.uid(),admin_note=p_note
  where id=p_payout_id returning * into v_payout;
  return v_payout;
 end if;

 if v_worker.payout_details_change_status<>'approved'
    or v_worker.payout_details_reviewed_by is null
    or v_worker.payout_details_reviewed_at is null
    or (nullif(btrim(v_worker.upi_id),'') is null
        and nullif(btrim(v_worker.bank_account_last4),'') is null) then
  raise exception 'Worker must submit payout details and receive Main Admin verification before payout approval';
 end if;

 v_amount:=coalesce(p_approved_amount,v_payout.requested_amount);
 select coalesce(sum(balance_effect),0) into v_available
 from public.srk_worker_wallet_ledger where worker_id=v_payout.worker_id;
 select coalesce(sum(coalesce(approved_amount,requested_amount)),0) into v_reserved
 from public.srk_worker_payout_requests
 where worker_id=v_payout.worker_id and id<>p_payout_id
  and status in ('requested','under_review','approved');
 if v_amount<=0 or v_amount>v_payout.requested_amount or v_amount>v_available-v_reserved then
  raise exception 'Approved amount exceeds unreserved available balance';
 end if;

 update public.srk_worker_payout_requests
 set status='approved',approved_amount=v_amount,reviewed_at=clock_timestamp(),
     reviewed_by=auth.uid(),admin_note=p_note
 where id=p_payout_id returning * into v_payout;
 return v_payout;
end
$function$;