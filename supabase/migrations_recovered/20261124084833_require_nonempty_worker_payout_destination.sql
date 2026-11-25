CREATE OR REPLACE FUNCTION public.srk_worker_update_payout_details(p_upi_id text,p_bank_account_last4 text)
RETURNS public.srk_worker_profiles
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth'
AS $function$
declare v public.srk_worker_profiles%rowtype;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if p_upi_id is null and p_bank_account_last4 is null then
  raise exception 'Provide a UPI ID or bank account details';
 end if;
 if p_upi_id is not null and p_upi_id !~ '^[A-Za-z0-9._-]{2,100}@[A-Za-z0-9.-]{2,50}$' then
  raise exception 'Invalid UPI ID format';
 end if;
 if p_bank_account_last4 is not null and p_bank_account_last4 !~ '^[0-9]{4}$' then
  raise exception 'Bank account last four digits must be four numbers';
 end if;
 update public.srk_worker_profiles
 set pending_upi_id=p_upi_id,pending_bank_account_last4=p_bank_account_last4,
     payout_details_change_status='pending',
     payout_details_change_requested_at=clock_timestamp(),
     payout_details_reviewed_by=null,payout_details_reviewed_at=null,payout_details_review_reason=null,
     updated_at=clock_timestamp()
 where user_id=auth.uid() returning * into v;
 if not found then raise exception 'Worker profile not found'; end if;
 return v;
end
$function$;