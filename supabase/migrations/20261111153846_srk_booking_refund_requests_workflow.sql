-- SRK ELECTRONIC: customer refund request and Admin refund processing.
-- Main Production migration applied as 20261111153846.
begin;
create table if not exists public.srk_booking_refund_requests (
 id uuid primary key default gen_random_uuid(),
 booking_id uuid not null unique references public.service_bookings(id) on delete restrict,
 customer_user_id uuid not null references auth.users(id) on delete restrict,
 amount numeric(12,2) not null check(amount>0 and amount<=10000000),
 reason text not null check(length(btrim(reason)) between 20 and 1000),
 status text not null default 'requested' check(status in ('requested','in_review','approved','rejected','processing','unknown','processed')),
 admin_note text check(admin_note is null or length(admin_note)<=2000),
 refund_record_id uuid unique references public.srk_razorpay_refunds(id) on delete restrict,
 decided_by uuid references auth.users(id) on delete restrict,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 processed_at timestamptz
);
create index if not exists srk_booking_refund_requests_status_created_idx on public.srk_booking_refund_requests(status,created_at desc);
alter table public.srk_booking_refund_requests enable row level security;
revoke all on public.srk_booking_refund_requests from public,anon,authenticated;
grant select,insert,update,delete on public.srk_booking_refund_requests to service_role;

create or replace function public.srk_customer_create_booking_refund_request(p_booking_id uuid,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $function$
declare v_uid uuid:=auth.uid(); v_booking public.service_bookings%rowtype; v_request public.srk_booking_refund_requests%rowtype;
begin
 if v_uid is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='28000'; end if;
 if p_booking_id is null or p_reason is null or length(btrim(p_reason)) not between 20 and 1000 then raise exception 'REFUND_REASON_MUST_BE_20_TO_1000_CHARACTERS' using errcode='22023'; end if;
 select * into v_booking from public.service_bookings where id=p_booking_id and customer_user_id=v_uid for update;
 if not found then raise exception 'BOOKING_NOT_FOUND_OR_NOT_OWNED' using errcode='42501'; end if;
 if v_booking.payment_status<>'paid' or v_booking.payment_verified_at is null or coalesce(v_booking.amount_paid,0)<=0 then raise exception 'ONLY_VERIFIED_PAID_BOOKINGS_CAN_REQUEST_REFUND' using errcode='55000'; end if;
 if exists(select 1 from public.srk_razorpay_refunds r where r.booking_id=p_booking_id and r.status in ('requested','processing','unknown','processed')) then raise exception 'REFUND_ALREADY_EXISTS_FOR_BOOKING' using errcode='23505'; end if;
 if exists(select 1 from public.srk_manual_refund_entries r where r.booking_id=p_booking_id) then raise exception 'REFUND_ALREADY_RECORDED_FOR_BOOKING' using errcode='23505'; end if;
 select * into v_request from public.srk_booking_refund_requests where booking_id=p_booking_id for update;
 if found then
  if v_request.status='rejected' then
   update public.srk_booking_refund_requests set customer_user_id=v_uid,amount=round(v_booking.amount_paid,2),reason=btrim(p_reason),status='requested',admin_note=null,refund_record_id=null,decided_by=null,processed_at=null,updated_at=clock_timestamp() where id=v_request.id returning * into v_request;
  else raise exception 'REFUND_REQUEST_ALREADY_SUBMITTED' using errcode='23505'; end if;
 else
  insert into public.srk_booking_refund_requests(booking_id,customer_user_id,amount,reason) values(p_booking_id,v_uid,round(v_booking.amount_paid,2),btrim(p_reason)) returning * into v_request;
 end if;
 return jsonb_build_object('success',true,'request_id',v_request.id,'amount',v_request.amount,'status',v_request.status);
end $function$;

create or replace function public.srk_customer_list_booking_refund_requests()
returns table(id uuid,booking_id uuid,amount numeric,reason text,status text,admin_note text,created_at timestamptz,updated_at timestamptz,processed_at timestamptz)
language plpgsql stable security definer set search_path='' as $function$
begin
 if auth.uid() is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='28000'; end if;
 return query select r.id,r.booking_id,r.amount,r.reason,r.status,r.admin_note,r.created_at,r.updated_at,r.processed_at from public.srk_booking_refund_requests r where r.customer_user_id=auth.uid() order by r.created_at desc;
end $function$;

create or replace function public.srk_admin_list_booking_refund_requests(p_limit integer default 200)
returns table(id uuid,booking_id uuid,customer_user_id uuid,customer_name text,customer_phone text,amount numeric,reason text,status text,admin_note text,created_at timestamptz,updated_at timestamptz,payment_status text,payment_method text,razorpay_payment_id text,has_manual_payment boolean,refund_record_id uuid,refund_id text,provider_status text)
language plpgsql stable security definer set search_path='' as $function$
begin
 if auth.uid() is null or not public.is_srk_admin() then raise exception 'ADMIN_ACCESS_REQUIRED' using errcode='42501'; end if;
 return query select r.id,r.booking_id,r.customer_user_id,b.customer_name,b.phone,r.amount,r.reason,r.status,r.admin_note,r.created_at,r.updated_at,b.payment_status,b.payment_method,b.razorpay_payment_id,exists(select 1 from public.srk_manual_payment_entries m where m.booking_id=b.id),r.refund_record_id,rr.refund_id,rr.provider_status from public.srk_booking_refund_requests r join public.service_bookings b on b.id=r.booking_id left join public.srk_razorpay_refunds rr on rr.id=r.refund_record_id order by r.created_at desc limit greatest(1,least(coalesce(p_limit,200),300));
end $function$;

create or replace function public.srk_admin_decide_booking_refund_request(p_request_id uuid,p_status text,p_admin_note text default null)
returns jsonb language plpgsql security definer set search_path='' as $function$
declare v_request public.srk_booking_refund_requests%rowtype;
begin
 if auth.uid() is null or not public.is_srk_admin() then raise exception 'ADMIN_ACCESS_REQUIRED' using errcode='42501'; end if;
 if p_request_id is null or p_status not in ('in_review','approved','rejected') or (p_admin_note is not null and length(p_admin_note)>2000) then raise exception 'INVALID_REFUND_REQUEST_DECISION' using errcode='22023'; end if;
 select * into v_request from public.srk_booking_refund_requests where id=p_request_id for update;
 if not found then raise exception 'REFUND_REQUEST_NOT_FOUND'; end if;
 if v_request.status in ('processing','unknown','processed') then raise exception 'REFUND_ALREADY_BEING_PROCESSED_OR_COMPLETED' using errcode='55000'; end if;
 if v_request.status='rejected' and p_status<>'in_review' then raise exception 'REJECTED_REQUEST_MUST_BE_REOPENED_FOR_REVIEW_FIRST' using errcode='55000'; end if;
 update public.srk_booking_refund_requests set status=p_status,admin_note=nullif(btrim(coalesce(p_admin_note,'')),''),decided_by=auth.uid(),updated_at=clock_timestamp() where id=p_request_id returning * into v_request;
 return jsonb_build_object('success',true,'request_id',v_request.id,'status',v_request.status);
end $function$;

create or replace function public.srk_admin_prepare_booking_refund(p_request_id uuid)
returns table(refund_record_id uuid,booking_id uuid,payment_id text,amount_paise bigint,idempotency_key text,status text)
language plpgsql security definer set search_path='' as $function$
declare v_request public.srk_booking_refund_requests%rowtype; v_booking public.service_bookings%rowtype; v_refund public.srk_razorpay_refunds%rowtype; v_payout public.srk_electrician_payouts%rowtype; v_amount numeric(12,2);
begin
 if auth.uid() is null or not public.is_srk_admin() then raise exception 'ADMIN_ACCESS_REQUIRED' using errcode='42501'; end if;
 select * into v_request from public.srk_booking_refund_requests where id=p_request_id for update;
 if not found then raise exception 'REFUND_REQUEST_NOT_FOUND'; end if;
 if v_request.status not in ('approved','processing','unknown') then raise exception 'REFUND_REQUEST_MUST_BE_APPROVED_FIRST' using errcode='55000'; end if;
 select * into v_booking from public.service_bookings where id=v_request.booking_id for update;
 if not found then raise exception 'BOOKING_NOT_FOUND'; end if;
 if v_booking.payment_status<>'paid' or v_booking.payment_verified_at is null or v_booking.razorpay_payment_id is null or v_booking.razorpay_payment_id !~ '^pay_[A-Za-z0-9]+$' or coalesce(v_booking.amount_paid,0)<=0 then raise exception 'VERIFIED_RAZORPAY_PAYMENT_REQUIRED' using errcode='55000'; end if;
 v_amount:=round(v_booking.amount_paid,2);
 if v_amount<>v_request.amount then raise exception 'REFUND_AMOUNT_CHANGED_SINCE_REQUEST' using errcode='55000'; end if;
 if v_booking.quote_status<>'approved' then raise exception 'TIMER_OR_NON_QUOTE_REFUND_REQUIRES_SEPARATE_PAYMENT_RECONCILIATION' using errcode='55000'; end if;
 if v_booking.quoted_amount is null or v_booking.service_charge is null or v_booking.materials_amount is null or v_amount<>round(v_booking.quoted_amount,2) or v_amount<>round(v_booking.service_charge+v_booking.materials_amount,2) then raise exception 'PAID_AMOUNT_DOES_NOT_MATCH_APPROVED_QUOTE' using errcode='55000'; end if;
 select * into v_refund from public.srk_razorpay_refunds where booking_id=v_booking.id for update;
 if found then
  if v_refund.status='failed' then raise exception 'PREVIOUS_REFUND_FAILED_RECONCILE_FIRST'; end if;
  update public.srk_booking_refund_requests set status=case when v_refund.status='processed' then 'processed' else 'processing' end,refund_record_id=v_refund.id,updated_at=clock_timestamp(),processed_at=case when v_refund.status='processed' then coalesce(v_refund.processed_at,clock_timestamp()) else null end where id=v_request.id;
  return query select v_refund.id,v_refund.booking_id,v_refund.payment_id,v_refund.amount_paise,v_refund.idempotency_key,v_refund.status; return;
 end if;
 select * into v_payout from public.srk_electrician_payouts where booking_id=v_booking.id for update;
 if found then
  if v_payout.payout_status='paid' then raise exception 'ELECTRICIAN_PAYOUT_ALREADY_PAID_RECONCILIATION_REQUIRED'; end if;
  if v_payout.payout_status not in ('pending','blocked') then raise exception 'ELECTRICIAN_PAYOUT_STATE_REQUIRES_RECONCILIATION'; end if;
  update public.srk_electrician_payouts set payout_status='blocked',payout_note='Customer refund in progress',updated_at=clock_timestamp() where id=v_payout.id;
 end if;
 insert into public.srk_razorpay_refunds(booking_id,payment_id,amount,amount_paise,idempotency_key,status,reason,admin_user_id,previous_payout_note)
 values(v_booking.id,v_booking.razorpay_payment_id,v_amount,round(v_amount*100)::bigint,replace(gen_random_uuid()::text,'-',''),'requested',left('Customer refund request: '||v_request.reason,250),auth.uid(),case when found then v_payout.payout_note else null end) returning * into v_refund;
 update public.srk_booking_refund_requests set status='processing',refund_record_id=v_refund.id,decided_by=auth.uid(),updated_at=clock_timestamp() where id=v_request.id;
 return query select v_refund.id,v_refund.booking_id,v_refund.payment_id,v_refund.amount_paise,v_refund.idempotency_key,v_refund.status;
end $function$;

create or replace function public.srk_service_reconcile_booking_refund(p_refund_record_id uuid,p_provider_refund_id text,p_provider_status text,p_error text default null)
returns jsonb language plpgsql security definer set search_path='' as $function$
declare v_refund public.srk_razorpay_refunds%rowtype; v_status text;
begin
 if auth.role()<>'service_role' then raise exception 'SERVICE_ROLE_REQUIRED' using errcode='42501'; end if;
 if p_refund_record_id is null or p_provider_status not in ('pending','processed','failed') or (p_provider_refund_id is not null and p_provider_refund_id !~ '^rfnd_[A-Za-z0-9]+$') then raise exception 'INVALID_PROVIDER_REFUND_RESULT' using errcode='22023'; end if;
 select * into v_refund from public.srk_razorpay_refunds where id=p_refund_record_id for update;
 if not found then raise exception 'REFUND_RECORD_NOT_FOUND'; end if;
 if v_refund.status='processed' then return jsonb_build_object('success',true,'status','processed','replayed',true); end if;
 v_status:=case p_provider_status when 'pending' then 'processing' when 'processed' then 'processed' else 'failed' end;
 update public.srk_razorpay_refunds set refund_id=coalesce(p_provider_refund_id,refund_id),provider_status=p_provider_status,status=v_status,last_error=case when p_provider_status='failed' then left(coalesce(p_error,'Refund failed'),500) else null end,processed_at=case when p_provider_status='processed' then clock_timestamp() else null end,updated_at=clock_timestamp() where id=p_refund_record_id;
 update public.srk_booking_refund_requests set status=case when p_provider_status='processed' then 'processed' when p_provider_status='failed' then 'unknown' else 'processing' end,updated_at=clock_timestamp(),processed_at=case when p_provider_status='processed' then clock_timestamp() else null end where refund_record_id=p_refund_record_id;
 if p_provider_status='processed' then update public.service_bookings set payment_status='refunded' where id=v_refund.booking_id and payment_status='paid'; end if;
 return jsonb_build_object('success',true,'status',v_status,'booking_id',v_refund.booking_id);
end $function$;

create or replace function public.srk_admin_finalize_manual_booking_refund(p_request_id uuid,p_reference text,p_note text default null)
returns jsonb language plpgsql security definer set search_path='' as $function$
declare v_request public.srk_booking_refund_requests%rowtype; v_result jsonb;
begin
 if auth.uid() is null or not public.is_srk_admin() then raise exception 'ADMIN_ACCESS_REQUIRED' using errcode='42501'; end if;
 select * into v_request from public.srk_booking_refund_requests where id=p_request_id for update;
 if not found then raise exception 'REFUND_REQUEST_NOT_FOUND'; end if;
 if v_request.status<>'approved' then raise exception 'REFUND_REQUEST_MUST_BE_APPROVED_FIRST'; end if;
 v_result:=public.srk_admin_record_manual_refund(v_request.booking_id,p_reference,p_note);
 update public.srk_booking_refund_requests set status='processed',admin_note=coalesce(nullif(btrim(coalesce(p_note,'')),''),admin_note),decided_by=auth.uid(),processed_at=clock_timestamp(),updated_at=clock_timestamp() where id=p_request_id;
 return v_result||jsonb_build_object('request_id',p_request_id,'status','processed');
end $function$;

revoke all on function public.srk_customer_create_booking_refund_request(uuid,text) from public,anon;
revoke all on function public.srk_customer_list_booking_refund_requests() from public,anon;
revoke all on function public.srk_admin_list_booking_refund_requests(integer) from public,anon;
revoke all on function public.srk_admin_decide_booking_refund_request(uuid,text,text) from public,anon;
revoke all on function public.srk_admin_prepare_booking_refund(uuid) from public,anon;
revoke all on function public.srk_service_reconcile_booking_refund(uuid,text,text,text) from public,anon,authenticated;
revoke all on function public.srk_admin_finalize_manual_booking_refund(uuid,text,text) from public,anon;
grant execute on function public.srk_customer_create_booking_refund_request(uuid,text) to authenticated;
grant execute on function public.srk_customer_list_booking_refund_requests() to authenticated;
grant execute on function public.srk_admin_list_booking_refund_requests(integer) to authenticated;
grant execute on function public.srk_admin_decide_booking_refund_request(uuid,text,text) to authenticated;
grant execute on function public.srk_admin_prepare_booking_refund(uuid) to authenticated;
grant execute on function public.srk_admin_finalize_manual_booking_refund(uuid,text,text) to authenticated;
grant execute on function public.srk_service_reconcile_booking_refund(uuid,text,text,text) to service_role;
commit;
