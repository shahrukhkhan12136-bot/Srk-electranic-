-- Phase 1: append-only Admin evidence and independent review.
-- Deliberately does not mutate refund/request/booking/payout financial state.
begin;

create table if not exists public.srk_refund_reconciliation_cases (
 id uuid primary key default gen_random_uuid(),
 refund_record_id uuid not null unique references public.srk_razorpay_refunds(id) on delete restrict,
 action_id uuid not null unique,
 opened_by uuid not null references auth.users(id) on delete restrict,
 created_at timestamptz not null default clock_timestamp()
);
create index if not exists srk_refund_reconciliation_cases_created_idx
 on public.srk_refund_reconciliation_cases(created_at desc);

create table if not exists public.srk_refund_reconciliation_evidence (
 id uuid primary key default gen_random_uuid(),
 case_id uuid not null references public.srk_refund_reconciliation_cases(id) on delete restrict,
 action_id uuid not null unique,
 submitted_by uuid not null references auth.users(id) on delete restrict,
 provider_name text not null default 'razorpay' check(provider_name='razorpay'),
 provider_refund_id text check(provider_refund_id is null or provider_refund_id ~ '^rfnd_[A-Za-z0-9]+$'),
 provider_payment_id text not null check(provider_payment_id ~ '^pay_[A-Za-z0-9]+$'),
 amount_paise bigint not null check(amount_paise>0),
 currency text not null check(currency ~ '^[A-Z]{3}$'),
 provider_status text not null check(provider_status in ('pending','processed','failed')),
 provider_created_at timestamptz,
 provider_updated_at timestamptz,
 evidence_reference text not null check(length(btrim(evidence_reference)) between 3 and 500),
 submitted_at timestamptz not null default clock_timestamp()
);
create index if not exists srk_refund_reconciliation_evidence_case_idx
 on public.srk_refund_reconciliation_evidence(case_id,submitted_at);

create table if not exists public.srk_refund_reconciliation_reviews (
 id uuid primary key default gen_random_uuid(),
 case_id uuid not null references public.srk_refund_reconciliation_cases(id) on delete restrict,
 evidence_id uuid not null unique references public.srk_refund_reconciliation_evidence(id) on delete restrict,
 action_id uuid not null unique,
 reviewed_by uuid not null references auth.users(id) on delete restrict,
 decision text not null check(decision in ('verified_match','pending_confirmation','mismatch_blocked','escalate')),
 review_note text check(review_note is null or length(review_note)<=1000),
 reviewed_at timestamptz not null default clock_timestamp()
);
create index if not exists srk_refund_reconciliation_reviews_case_idx
 on public.srk_refund_reconciliation_reviews(case_id,reviewed_at);

create table if not exists public.srk_refund_reconciliation_audit (
 id uuid primary key default gen_random_uuid(),
 case_id uuid not null references public.srk_refund_reconciliation_cases(id) on delete restrict,
 actor_user_id uuid not null references auth.users(id) on delete restrict,
 event_type text not null check(event_type in ('case_opened','evidence_submitted','evidence_reviewed')),
 subject_id uuid not null,
 action_id uuid not null unique,
 details jsonb not null default '{}'::jsonb check(jsonb_typeof(details)='object'),
 created_at timestamptz not null default clock_timestamp()
);
create index if not exists srk_refund_reconciliation_audit_case_idx
 on public.srk_refund_reconciliation_audit(case_id,created_at);

alter table public.srk_refund_reconciliation_cases enable row level security;
alter table public.srk_refund_reconciliation_evidence enable row level security;
alter table public.srk_refund_reconciliation_reviews enable row level security;
alter table public.srk_refund_reconciliation_audit enable row level security;
revoke all on public.srk_refund_reconciliation_cases,public.srk_refund_reconciliation_evidence,
 public.srk_refund_reconciliation_reviews,public.srk_refund_reconciliation_audit from public,anon,authenticated,service_role;

create or replace function public.srk_refund_reconciliation_reject_mutation()
returns trigger language plpgsql set search_path='' as $function$
begin
 raise exception 'REFUND_RECONCILIATION_HISTORY_IS_APPEND_ONLY' using errcode='55000';
end
$function$;
drop trigger if exists srk_refund_reconciliation_evidence_immutable on public.srk_refund_reconciliation_evidence;
create trigger srk_refund_reconciliation_evidence_immutable before update or delete on public.srk_refund_reconciliation_evidence
 for each row execute function public.srk_refund_reconciliation_reject_mutation();
drop trigger if exists srk_refund_reconciliation_reviews_immutable on public.srk_refund_reconciliation_reviews;
create trigger srk_refund_reconciliation_reviews_immutable before update or delete on public.srk_refund_reconciliation_reviews
 for each row execute function public.srk_refund_reconciliation_reject_mutation();
drop trigger if exists srk_refund_reconciliation_audit_immutable on public.srk_refund_reconciliation_audit;
create trigger srk_refund_reconciliation_audit_immutable before update or delete on public.srk_refund_reconciliation_audit
 for each row execute function public.srk_refund_reconciliation_reject_mutation();

create or replace function public.srk_admin_open_refund_reconciliation_case(p_refund_record_id uuid,p_action_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $function$
declare v_uid uuid:=auth.uid(); v_refund public.srk_razorpay_refunds%rowtype;
 v_case public.srk_refund_reconciliation_cases%rowtype; v_rows integer;
begin
 if v_uid is null or not public.is_srk_admin() then raise exception 'ADMIN_ACCESS_REQUIRED' using errcode='42501'; end if;
 if p_refund_record_id is null or p_action_id is null then raise exception 'INVALID_RECONCILIATION_CASE' using errcode='22023'; end if;
 select * into v_refund from public.srk_razorpay_refunds where id=p_refund_record_id;
 if not found then raise exception 'REFUND_RECORD_NOT_FOUND'; end if;
 -- Preserve access to an existing case after the linked refund reaches a terminal state.
 -- Only creation of a new case is restricted to reviewable refund states.
 select * into v_case from public.srk_refund_reconciliation_cases where refund_record_id=p_refund_record_id;
 if found then
  return jsonb_build_object('success',true,'case_id',v_case.id,'created',false,'existing',true);
 end if;
 if v_refund.status not in ('requested','processing','failed','unknown') then
  raise exception 'REFUND_STATUS_NOT_ELIGIBLE_FOR_EVIDENCE_REVIEW' using errcode='55000';
 end if;
 insert into public.srk_refund_reconciliation_cases(refund_record_id,action_id,opened_by)
 values(p_refund_record_id,p_action_id,v_uid)
 on conflict(refund_record_id) do nothing;
 get diagnostics v_rows=row_count;
 select * into v_case from public.srk_refund_reconciliation_cases where refund_record_id=p_refund_record_id;
 if v_case.action_id=p_action_id and v_case.opened_by<>v_uid then
  raise exception 'RECONCILIATION_ACTION_ID_CONFLICT' using errcode='23505';
 end if;
 if v_rows=1 then
  insert into public.srk_refund_reconciliation_audit(case_id,actor_user_id,event_type,subject_id,action_id,details)
  values(v_case.id,v_uid,'case_opened',v_case.id,p_action_id,jsonb_build_object('refund_record_id',p_refund_record_id));
 end if;
 return jsonb_build_object('success',true,'case_id',v_case.id,'created',(v_rows=1));
end
$function$;

create or replace function public.srk_admin_submit_refund_reconciliation_evidence(
 p_case_id uuid,p_action_id uuid,p_provider_refund_id text,p_provider_payment_id text,
 p_amount_paise bigint,p_currency text,p_provider_status text,
 p_provider_created_at timestamptz,p_provider_updated_at timestamptz,p_evidence_reference text
)
returns jsonb language plpgsql security definer set search_path='' as $function$
declare v_uid uuid:=auth.uid(); v_case public.srk_refund_reconciliation_cases%rowtype;
 v_existing public.srk_refund_reconciliation_evidence%rowtype; v_evidence public.srk_refund_reconciliation_evidence%rowtype;
 v_rows integer;
begin
 if v_uid is null or not public.is_srk_admin() then raise exception 'ADMIN_ACCESS_REQUIRED' using errcode='42501'; end if;
 if p_case_id is null or p_action_id is null or p_provider_payment_id is null
    or p_amount_paise is null or p_amount_paise<=0 or p_currency !~ '^[A-Z]{3}$'
    or p_provider_status not in ('pending','processed','failed')
    or p_evidence_reference is null or length(btrim(p_evidence_reference)) not between 3 and 500
    or (p_provider_refund_id is not null and p_provider_refund_id !~ '^rfnd_[A-Za-z0-9]+$')
    or p_provider_payment_id !~ '^pay_[A-Za-z0-9]+$' then
  raise exception 'INVALID_REFUND_PROVIDER_EVIDENCE' using errcode='22023';
 end if;
 select * into v_case from public.srk_refund_reconciliation_cases where id=p_case_id for update;
 if not found then raise exception 'RECONCILIATION_CASE_NOT_FOUND'; end if;
 select * into v_existing from public.srk_refund_reconciliation_evidence where action_id=p_action_id;
 if found then
  if v_existing.case_id<>p_case_id or v_existing.submitted_by<>v_uid
     or v_existing.provider_refund_id is distinct from p_provider_refund_id
     or v_existing.provider_payment_id<>p_provider_payment_id
     or v_existing.amount_paise<>p_amount_paise or v_existing.currency<>p_currency
     or v_existing.provider_status<>p_provider_status
     or v_existing.provider_created_at is distinct from p_provider_created_at
     or v_existing.provider_updated_at is distinct from p_provider_updated_at
     or v_existing.evidence_reference<>btrim(p_evidence_reference) then
   raise exception 'RECONCILIATION_ACTION_ID_CONFLICT' using errcode='23505';
  end if;
  return jsonb_build_object('success',true,'evidence_id',v_existing.id,'replayed',true);
 end if;
 insert into public.srk_refund_reconciliation_evidence
 (case_id,action_id,submitted_by,provider_refund_id,provider_payment_id,amount_paise,currency,
  provider_status,provider_created_at,provider_updated_at,evidence_reference)
 values(p_case_id,p_action_id,v_uid,p_provider_refund_id,p_provider_payment_id,p_amount_paise,p_currency,
  p_provider_status,p_provider_created_at,p_provider_updated_at,btrim(p_evidence_reference))
 on conflict(action_id) do nothing;
 get diagnostics v_rows=row_count;
 if v_rows=0 then raise exception 'RECONCILIATION_ACTION_ID_CONFLICT' using errcode='23505'; end if;
 select * into v_evidence from public.srk_refund_reconciliation_evidence where action_id=p_action_id;
 insert into public.srk_refund_reconciliation_audit(case_id,actor_user_id,event_type,subject_id,action_id,details)
 values(p_case_id,v_uid,'evidence_submitted',v_evidence.id,p_action_id,
  jsonb_build_object('provider_status',p_provider_status,'provider_payment_id',p_provider_payment_id,
   'provider_refund_id',p_provider_refund_id,'amount_paise',p_amount_paise,'currency',p_currency));
 return jsonb_build_object('success',true,'evidence_id',v_evidence.id,'replayed',false);
end
$function$;

create or replace function public.srk_admin_review_refund_reconciliation_evidence(
 p_evidence_id uuid,p_action_id uuid,p_decision text,p_review_note text default null
)
returns jsonb language plpgsql security definer set search_path='' as $function$
declare v_uid uuid:=auth.uid(); v_evidence public.srk_refund_reconciliation_evidence%rowtype;
 v_case public.srk_refund_reconciliation_cases%rowtype; v_refund public.srk_razorpay_refunds%rowtype;
 v_review public.srk_refund_reconciliation_reviews%rowtype; v_rows integer; v_match boolean;
begin
 if v_uid is null or not public.is_srk_admin() then raise exception 'ADMIN_ACCESS_REQUIRED' using errcode='42501'; end if;
 if p_evidence_id is null or p_action_id is null
    or p_decision not in ('verified_match','pending_confirmation','mismatch_blocked','escalate')
    or (p_review_note is not null and length(p_review_note)>1000) then
  raise exception 'INVALID_RECONCILIATION_REVIEW' using errcode='22023';
 end if;
 select * into v_review from public.srk_refund_reconciliation_reviews where action_id=p_action_id;
 if found then
  if v_review.evidence_id<>p_evidence_id or v_review.reviewed_by<>v_uid
     or v_review.decision<>p_decision
     or v_review.review_note is distinct from nullif(btrim(coalesce(p_review_note,'')),'') then
   raise exception 'RECONCILIATION_ACTION_ID_CONFLICT' using errcode='23505';
  end if;
  return jsonb_build_object('success',true,'review_id',v_review.id,'decision',v_review.decision,'replayed',true);
 end if;
 select * into v_evidence from public.srk_refund_reconciliation_evidence where id=p_evidence_id;
 if not found then raise exception 'RECONCILIATION_EVIDENCE_NOT_FOUND'; end if;
 select * into v_case from public.srk_refund_reconciliation_cases where id=v_evidence.case_id for update;
 if not found then raise exception 'RECONCILIATION_CASE_NOT_FOUND'; end if;
 -- Recheck after the case lock so a concurrent duplicate click replays the committed result.
 select * into v_review from public.srk_refund_reconciliation_reviews where action_id=p_action_id;
 if found then
  if v_review.evidence_id<>p_evidence_id or v_review.reviewed_by<>v_uid
     or v_review.decision<>p_decision
     or v_review.review_note is distinct from nullif(btrim(coalesce(p_review_note,'')),'') then
   raise exception 'RECONCILIATION_ACTION_ID_CONFLICT' using errcode='23505';
  end if;
  return jsonb_build_object('success',true,'review_id',v_review.id,'decision',v_review.decision,'replayed',true);
 end if;
 if v_uid=v_evidence.submitted_by or v_uid=v_case.opened_by then
  raise exception 'INDEPENDENT_ADMIN_REVIEW_REQUIRED' using errcode='42501';
 end if;
 if exists(select 1 from public.srk_refund_reconciliation_reviews where evidence_id=p_evidence_id) then
  raise exception 'EVIDENCE_ALREADY_REVIEWED' using errcode='23505';
 end if;
 select * into v_refund from public.srk_razorpay_refunds where id=v_case.refund_record_id;
 if not found then raise exception 'REFUND_RECORD_NOT_FOUND'; end if;
 v_match:=v_evidence.provider_payment_id=v_refund.payment_id
  and v_evidence.amount_paise=v_refund.amount_paise
  and v_evidence.currency=v_refund.currency
  and (v_refund.refund_id is null or v_evidence.provider_refund_id=v_refund.refund_id)
  and v_evidence.provider_refund_id is not null;
 if p_decision='verified_match' and (not v_match or v_evidence.provider_status<>'processed') then
  raise exception 'PROVIDER_EVIDENCE_DOES_NOT_MATCH_REFUND_LEDGER' using errcode='55000';
 end if;
 if p_decision='pending_confirmation' and v_evidence.provider_status<>'pending' then
  raise exception 'PROVIDER_EVIDENCE_IS_NOT_PENDING' using errcode='55000';
 end if;
 insert into public.srk_refund_reconciliation_reviews(case_id,evidence_id,action_id,reviewed_by,decision,review_note)
 values(v_case.id,p_evidence_id,p_action_id,v_uid,p_decision,nullif(btrim(coalesce(p_review_note,'')),''))
 on conflict(evidence_id) do nothing;
 get diagnostics v_rows=row_count;
 if v_rows=0 then raise exception 'EVIDENCE_ALREADY_REVIEWED' using errcode='23505'; end if;
 select * into v_review from public.srk_refund_reconciliation_reviews where evidence_id=p_evidence_id;
 insert into public.srk_refund_reconciliation_audit(case_id,actor_user_id,event_type,subject_id,action_id,details)
 values(v_case.id,v_uid,'evidence_reviewed',p_evidence_id,p_action_id,
  jsonb_build_object('review_id',v_review.id,'decision',p_decision,'ledger_match',v_match));
 return jsonb_build_object('success',true,'review_id',v_review.id,'decision',p_decision,
  'ledger_match',v_match,'replayed',false,'financial_state_changed',false);
end
$function$;

create or replace function public.srk_admin_get_refund_reconciliation_case(p_case_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $function$
declare v_result jsonb;
begin
 if auth.uid() is null or not public.is_srk_admin() then raise exception 'ADMIN_ACCESS_REQUIRED' using errcode='42501'; end if;
 select jsonb_build_object(
  'case',to_jsonb(c),
  'refund',jsonb_build_object('id',r.id,'booking_id',r.booking_id,'payment_id',r.payment_id,
   'amount_paise',r.amount_paise,'currency',r.currency,'status',r.status,
   'provider_status',r.provider_status,'provider_refund_id',r.refund_id),
  'evidence',coalesce((select jsonb_agg(to_jsonb(e) order by e.submitted_at) from public.srk_refund_reconciliation_evidence e where e.case_id=c.id),'[]'::jsonb),
  'reviews',coalesce((select jsonb_agg(to_jsonb(rv) order by rv.reviewed_at) from public.srk_refund_reconciliation_reviews rv where rv.case_id=c.id),'[]'::jsonb),
  'audit',coalesce((select jsonb_agg(to_jsonb(a) order by a.created_at) from public.srk_refund_reconciliation_audit a where a.case_id=c.id),'[]'::jsonb)
 ) into v_result
 from public.srk_refund_reconciliation_cases c
 join public.srk_razorpay_refunds r on r.id=c.refund_record_id
 where c.id=p_case_id;
 if v_result is null then raise exception 'RECONCILIATION_CASE_NOT_FOUND'; end if;
 return v_result;
end
$function$;

revoke all on function public.srk_refund_reconciliation_reject_mutation() from public,anon,authenticated,service_role;
revoke all on function public.srk_admin_open_refund_reconciliation_case(uuid,uuid) from public,anon;
revoke all on function public.srk_admin_submit_refund_reconciliation_evidence(uuid,uuid,text,text,bigint,text,text,timestamptz,timestamptz,text) from public,anon;
revoke all on function public.srk_admin_review_refund_reconciliation_evidence(uuid,uuid,text,text) from public,anon;
revoke all on function public.srk_admin_get_refund_reconciliation_case(uuid) from public,anon;
grant execute on function public.srk_admin_open_refund_reconciliation_case(uuid,uuid) to authenticated;
grant execute on function public.srk_admin_submit_refund_reconciliation_evidence(uuid,uuid,text,text,bigint,text,text,timestamptz,timestamptz,text) to authenticated;
grant execute on function public.srk_admin_review_refund_reconciliation_evidence(uuid,uuid,text,text) to authenticated;
grant execute on function public.srk_admin_get_refund_reconciliation_case(uuid) to authenticated;

commit;
