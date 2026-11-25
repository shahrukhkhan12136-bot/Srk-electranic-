
-- Correct appeal reviewer gate to existing Main Admin authority; no undefined permission code.
create or replace function public.srk_admin_review_emergency_decision_appeal(
 p_appeal_id uuid,p_decision text,p_note text
) returns public.srk_emergency_decision_appeals
language plpgsql security definer set search_path=''
as $$
declare v public.srk_emergency_decision_appeals%rowtype;
begin
 if auth.uid() is null or not public.is_srk_admin() then
  raise exception 'MAIN_ADMIN_REQUIRED' using errcode='42501';
 end if;
 if p_appeal_id is null or p_decision not in ('under_review','accepted','rejected','closed')
   or length(btrim(coalesce(p_note,'')))<10 or length(p_note)>2000 then
  raise exception 'VALID_APPEAL_DECISION_AND_NOTE_REQUIRED' using errcode='22023';
 end if;
 select * into v from public.srk_emergency_decision_appeals where id=p_appeal_id for update;
 if not found then raise exception 'APPEAL_NOT_FOUND'; end if;
 if v.status in ('accepted','rejected','closed') then raise exception 'APPEAL_ALREADY_FINALIZED'; end if;
 update public.srk_emergency_decision_appeals
 set status=p_decision,reviewed_by=case when p_decision='under_review' then null else auth.uid() end,
     reviewed_at=case when p_decision='under_review' then null else clock_timestamp() end,
     review_note=btrim(p_note),updated_at=clock_timestamp()
 where id=p_appeal_id returning * into v;
 insert into public.srk_emergency_decision_appeal_events(appeal_id,actor_user_id,action,note)
 values(v.id,auth.uid(),case p_decision when 'under_review' then 'review_started' else p_decision end,btrim(p_note));
 insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
 select v.appealed_by,'emergency_appeal_'||p_decision,'Emergency appeal update',
  'Your emergency appeal status is now: '||p_decision||'. '||btrim(p_note),a.booking_id
 from public.srk_emergency_alerts a where a.id=v.alert_id;
 return v;
end $$;
revoke all on function public.srk_admin_review_emergency_decision_appeal(uuid,text,text) from public,anon;
grant execute on function public.srk_admin_review_emergency_decision_appeal(uuid,text,text) to authenticated;

-- Add a distinct terminal payment state for partial refunds.
alter table public.service_bookings drop constraint if exists service_bookings_payment_status_check;
alter table public.service_bookings add constraint service_bookings_payment_status_check
 check (payment_status = any (array['unpaid','pending','paid','partially_refunded','refunded','failed']::text[]));

-- Manual refunds retain paid state only when fully refunded.
do $$
declare v_def text; v_old text; v_new text;
begin
 v_def:=pg_get_functiondef('public.srk_admin_record_manual_refund(uuid,text,text)'::regprocedure);
 v_old:='update public.service_bookings set payment_status=''refunded'' where id=p_booking_id;';
 v_new:='update public.service_bookings set payment_status=case when round(v_refund_request.amount,2)>=round(v_payment.amount,2) then ''refunded'' else ''partially_refunded'' end where id=p_booking_id;';
 if position(v_old in v_def)=0 then raise exception 'Manual refund payment-state patch target missing'; end if;
 v_def:=replace(v_def,v_old,v_new);
 v_old:='''amount'',v_payment.amount';
 v_new:='''amount'',v_refund_request.amount';
 if position(v_old in v_def)=0 then raise exception 'Manual refund response amount patch target missing'; end if;
 execute replace(v_def,v_old,v_new);
end $$;

-- Razorpay refund reconciliation records partial vs full refund correctly.
do $$
declare v_def text; v_old text; v_new text;
begin
 v_def:=pg_get_functiondef('public.srk_service_reconcile_booking_refund(uuid,text,text,bigint,text,text)'::regprocedure);
 v_old:='UPDATE public.service_bookings' || E'\n    SET payment_status=''refunded''' || E'\n    WHERE id=v_refund.booking_id AND payment_status=''paid'';';
 v_new:='UPDATE public.service_bookings' || E'\n    SET payment_status=case when v_refund.amount_paise>=round((select b.amount_paid*100 from public.service_bookings b where b.id=v_refund.booking_id))::bigint then ''refunded'' else ''partially_refunded'' end' || E'\n    WHERE id=v_refund.booking_id AND payment_status=''paid'';';
 if position(v_old in v_def)=0 then raise exception 'Razorpay refund payment-state patch target missing'; end if;
 execute replace(v_def,v_old,v_new);
end $$;

-- Prevent any new payment attempt after a partial refund.
do $$
declare r record; v_def text; v_old text; v_new text;
begin
 for r in
  select p.oid,p.proname,pg_get_function_identity_arguments(p.oid) args
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname in (
   'srk_service_start_razorpay_payment_order','srk_service_reserve_razorpay_qr',
   'srk_service_reserve_razorpay_qr_for_technician','srk_service_record_verified_razorpay_qr_webhook',
   'srk_admin_record_manual_payment','srk_confirm_cash_payment','srk_electrician_confirm_cash_payment'
  )
 loop
  v_def:=pg_get_functiondef(r.oid);
  v_old:='in (''paid'',''completed'',''refunded'')';
  v_new:='in (''paid'',''completed'',''partially_refunded'',''refunded'')';
  v_def:=replace(v_def,v_old,v_new);
  v_old:='payment_status = ''refunded''';
  v_new:='payment_status in (''partially_refunded'',''refunded'')';
  v_def:=replace(v_def,v_old,v_new);
  v_old:='payment_status=''refunded''';
  v_new:='payment_status in (''partially_refunded'',''refunded'')';
  v_def:=replace(v_def,v_old,v_new);
  execute v_def;
 end loop;
end $$;

-- Admin and participant retrieval RPCs for the new review/history records.
create or replace function public.srk_admin_list_worker_cancellation_reviews(p_status text default null,p_limit integer default 100)
returns setof public.srk_worker_cancellation_reviews
language plpgsql stable security definer set search_path=''
as $$
begin
 if auth.uid() is null or not public.is_srk_admin() then raise exception 'MAIN_ADMIN_REQUIRED' using errcode='42501'; end if;
 if p_limit not between 1 and 500 or (p_status is not null and p_status not in ('pending','justified','unjustified')) then
  raise exception 'INVALID_REVIEW_FILTER';
 end if;
 return query select * from public.srk_worker_cancellation_reviews
  where p_status is null or review_status=p_status order by created_at desc limit p_limit;
end $$;
revoke all on function public.srk_admin_list_worker_cancellation_reviews(text,integer) from public,anon;
grant execute on function public.srk_admin_list_worker_cancellation_reviews(text,integer) to authenticated;

create or replace function public.srk_admin_list_emergency_decision_appeals(p_status text default null,p_limit integer default 100)
returns setof public.srk_emergency_decision_appeals
language plpgsql stable security definer set search_path=''
as $$
begin
 if auth.uid() is null or not public.is_srk_admin() then raise exception 'MAIN_ADMIN_REQUIRED' using errcode='42501'; end if;
 if p_limit not between 1 and 500 or (p_status is not null and p_status not in ('submitted','under_review','accepted','rejected','closed')) then
  raise exception 'INVALID_APPEAL_FILTER';
 end if;
 return query select * from public.srk_emergency_decision_appeals
  where p_status is null or status=p_status order by created_at desc limit p_limit;
end $$;
revoke all on function public.srk_admin_list_emergency_decision_appeals(text,integer) from public,anon;
grant execute on function public.srk_admin_list_emergency_decision_appeals(text,integer) to authenticated;

create or replace function public.srk_list_my_emergency_decision_appeals(p_limit integer default 100)
returns setof public.srk_emergency_decision_appeals
language plpgsql stable security definer set search_path=''
as $$
begin
 if auth.uid() is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='28000'; end if;
 if p_limit not between 1 and 200 then raise exception 'INVALID_APPEAL_LIMIT'; end if;
 return query select * from public.srk_emergency_decision_appeals
  where appealed_by=auth.uid() order by created_at desc limit p_limit;
end $$;
revoke all on function public.srk_list_my_emergency_decision_appeals(integer) from public,anon;
grant execute on function public.srk_list_my_emergency_decision_appeals(integer) to authenticated;
