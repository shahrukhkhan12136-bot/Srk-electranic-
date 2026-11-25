
alter table public.srk_worker_profiles
  add column if not exists pending_upi_id text,
  add column if not exists pending_bank_account_last4 text,
  add column if not exists payout_details_change_status text not null default 'approved',
  add column if not exists payout_details_change_requested_at timestamptz,
  add column if not exists payout_details_reviewed_by uuid,
  add column if not exists payout_details_reviewed_at timestamptz,
  add column if not exists payout_details_review_reason text;
alter table public.srk_worker_profiles
  drop constraint if exists srk_worker_profiles_payout_change_status_check;
alter table public.srk_worker_profiles
  add constraint srk_worker_profiles_payout_change_status_check
  check (payout_details_change_status in ('approved','pending','rejected'));

create or replace function public.srk_worker_update_payout_details(p_upi_id text,p_bank_account_last4 text)
returns public.srk_worker_profiles
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare v public.srk_worker_profiles%rowtype;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
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

create or replace function public.srk_admin_review_worker_payout_details(
 p_worker_id uuid,p_approve boolean,p_reason text
)
returns public.srk_worker_profiles
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare v public.srk_worker_profiles%rowtype;
begin
 if auth.uid() is null or not public.is_srk_admin() then
   raise exception 'Main Admin permission required' using errcode='42501';
 end if;
 if p_worker_id is null or p_approve is null or length(btrim(coalesce(p_reason,'')))<10 then
   raise exception 'Worker, decision and reason are required';
 end if;
 update public.srk_worker_profiles
 set upi_id=case when p_approve then pending_upi_id else upi_id end,
     bank_account_last4=case when p_approve then pending_bank_account_last4 else bank_account_last4 end,
     pending_upi_id=null,pending_bank_account_last4=null,
     payout_details_change_status=case when p_approve then 'approved' else 'rejected' end,
     payout_details_reviewed_by=auth.uid(),payout_details_reviewed_at=clock_timestamp(),
     payout_details_review_reason=btrim(p_reason),updated_at=clock_timestamp()
 where id=p_worker_id and payout_details_change_status='pending'
 returning * into v;
 if not found then raise exception 'Pending payout detail change not found'; end if;
 insert into public.srk_admin_audit_events(
   entity_type,entity_id,action,actor_user_id,actor_role,changed_fields,before_data,after_data
 ) values(
   'worker_payout_details',p_worker_id,
   case when p_approve then 'approved' else 'rejected' end,
   auth.uid(),'admin',array['upi_id','bank_account_last4','payout_details_change_status'],
   jsonb_build_object('status','pending'),
   jsonb_build_object('status',v.payout_details_change_status,'review_reason',v.payout_details_review_reason)
 );
 return v;
end
$function$;
revoke all on function public.srk_admin_review_worker_payout_details(uuid,boolean,text) from public,anon;
grant execute on function public.srk_admin_review_worker_payout_details(uuid,boolean,text) to authenticated;
