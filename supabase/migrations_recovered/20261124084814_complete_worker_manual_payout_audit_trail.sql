alter table public.srk_worker_payout_requests
 add column if not exists paid_by uuid references auth.users(id) on delete restrict,
 add column if not exists recipient_snapshot jsonb;

alter table public.srk_worker_payout_requests
 add constraint srk_worker_payout_paid_audit_valid
 check (
  status<>'paid' or (
   paid_by is not null and paid_at is not null and
   payment_method is not null and payment_reference is not null and
   recipient_snapshot is not null and jsonb_typeof(recipient_snapshot)='object'
  )
 );

create table public.srk_worker_payout_evidence (
 id uuid primary key default gen_random_uuid(),
 payout_request_id uuid not null references public.srk_worker_payout_requests(id) on delete restrict,
 storage_path text not null unique,
 evidence_type text not null default 'transfer_receipt'
  check (evidence_type in ('transfer_receipt','bank_confirmation','other')),
 uploaded_by uuid not null references auth.users(id) on delete restrict,
 note text,
 created_at timestamptz not null default clock_timestamp()
);
create index srk_worker_payout_evidence_payout_idx
 on public.srk_worker_payout_evidence(payout_request_id,created_at desc);
alter table public.srk_worker_payout_evidence enable row level security;
revoke all on public.srk_worker_payout_evidence from anon,authenticated;
grant select on public.srk_worker_payout_evidence to authenticated;
create policy srk_worker_payout_evidence_admin_read
 on public.srk_worker_payout_evidence for select to authenticated
 using (public.srk_has_admin_permission('payouts.manage'));

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('srk-worker-payout-evidence','srk-worker-payout-evidence',false,10485760,
 array['application/pdf','image/jpeg','image/png'])
on conflict(id) do update set
 public=false,file_size_limit=10485760,
 allowed_mime_types=array['application/pdf','image/jpeg','image/png'];

create policy srk_worker_payout_evidence_storage_admin_read
 on storage.objects for select to authenticated
 using (bucket_id='srk-worker-payout-evidence' and public.srk_has_admin_permission('payouts.manage'));
create policy srk_worker_payout_evidence_storage_admin_upload
 on storage.objects for insert to authenticated
 with check (
  bucket_id='srk-worker-payout-evidence'
  and public.srk_has_admin_permission('payouts.manage')
  and (storage.foldername(name))[1] ~* '^[0-9a-f-]{36}$'
);

create or replace function public.srk_admin_attach_worker_payout_evidence(
 p_payout_id uuid,p_storage_path text,p_evidence_type text default 'transfer_receipt',p_note text default null
) returns public.srk_worker_payout_evidence
language plpgsql security definer
set search_path to 'pg_catalog','public','auth','storage'
as $function$
declare
 v_payout public.srk_worker_payout_requests%rowtype;
 v_evidence public.srk_worker_payout_evidence%rowtype;
begin
 if auth.uid() is null or not public.srk_has_admin_permission('payouts.manage') then
  raise exception 'Payout management permission required' using errcode='42501';
 end if;
 if p_payout_id is null or p_storage_path is null
    or p_storage_path !~ ('^'||p_payout_id::text||'/[^/]+$')
    or p_evidence_type not in ('transfer_receipt','bank_confirmation','other')
    or (p_note is not null and length(p_note)>1000) then
  raise exception 'Valid payout evidence details are required' using errcode='22023';
 end if;
 select * into v_payout from public.srk_worker_payout_requests
 where id=p_payout_id for update;
 if not found or v_payout.status<>'approved' then
  raise exception 'Evidence can be attached only to an approved payout';
 end if;
 if not exists(
  select 1 from storage.objects o
  where o.bucket_id='srk-worker-payout-evidence' and o.name=p_storage_path
 ) then
  raise exception 'Uploaded payout evidence file was not found in the private evidence bucket';
 end if;
 insert into public.srk_worker_payout_evidence(payout_request_id,storage_path,evidence_type,uploaded_by,note)
 values(p_payout_id,p_storage_path,p_evidence_type,auth.uid(),p_note)
 returning * into v_evidence;
 return v_evidence;
end
$function$;

revoke all on function public.srk_admin_attach_worker_payout_evidence(uuid,text,text,text) from public,anon;
grant execute on function public.srk_admin_attach_worker_payout_evidence(uuid,text,text,text) to authenticated,service_role;

create or replace function public.srk_admin_mark_worker_payout_paid(
 p_payout_id uuid,p_payment_method text,p_payment_reference text,p_note text default null
) returns public.srk_worker_payout_requests
language plpgsql security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare
 v_payout public.srk_worker_payout_requests%rowtype;
 v_worker public.srk_worker_profiles%rowtype;
 v_available numeric(14,2);
 v_reserved numeric(14,2);
 v_left numeric(14,2);
 v_earning record;
 v_alloc numeric(14,2);
 v_total_allocated numeric(14,2):=0;
 v_recipient_snapshot jsonb;
begin
 if auth.uid() is null or not public.srk_has_admin_permission('payouts.manage') then
  raise exception 'Payout management permission required' using errcode='42501';
 end if;
 if nullif(btrim(p_payment_reference),'') is null then
  raise exception 'UTR/transaction reference required';
 end if;
 if p_payment_method not in ('upi','bank_transfer','phonepe') then
  raise exception 'Payout must be made by the worker''s verified UPI or bank account';
 end if;

 select * into v_payout from public.srk_worker_payout_requests
 where id=p_payout_id for update;
 if not found or v_payout.status<>'approved' then
  raise exception 'Only approved payout can be marked paid';
 end if;

 select * into v_worker from public.srk_worker_profiles
 where id=v_payout.worker_id for update;
 if not found then raise exception 'Worker profile not found'; end if;
 if v_worker.payout_details_change_status<>'approved' then
  raise exception 'Worker payout details must be approved by Main Admin before payment';
 end if;
 if p_payment_method in ('upi','phonepe') and nullif(btrim(v_worker.upi_id),'') is null then
  raise exception 'Verified UPI ID is not available for this worker';
 end if;
 if p_payment_method='bank_transfer' and nullif(btrim(v_worker.bank_account_last4),'') is null then
  raise exception 'Verified bank account details are not available for this worker';
 end if;
 if not exists(select 1 from public.srk_worker_payout_evidence e where e.payout_request_id=p_payout_id) then
  raise exception 'Upload and attach bank/UPI transfer evidence before marking payout paid';
 end if;
 if exists(select 1 from public.srk_worker_earnings
           where worker_id=v_payout.worker_id and settlement_status='held') then
  raise exception 'Worker payout is held due to refund/dispute review';
 end if;

 v_recipient_snapshot:=jsonb_strip_nulls(jsonb_build_object(
  'worker_code',v_worker.worker_code,
  'worker_type',v_worker.worker_type,
  'payment_method',p_payment_method,
  'upi_id',case when p_payment_method in ('upi','phonepe') then v_worker.upi_id end,
  'bank_account_last4',case when p_payment_method='bank_transfer' then v_worker.bank_account_last4 end,
  'payout_details_reviewed_by',v_worker.payout_details_reviewed_by,
  'payout_details_reviewed_at',v_worker.payout_details_reviewed_at
 ));

 select coalesce(sum(balance_effect),0) into v_available
 from public.srk_worker_wallet_ledger where worker_id=v_payout.worker_id;
 select coalesce(sum(coalesce(approved_amount,requested_amount)),0) into v_reserved
 from public.srk_worker_payout_requests
 where worker_id=v_payout.worker_id and id<>p_payout_id
  and status in ('requested','under_review','approved');
 if v_payout.approved_amount>v_available-v_reserved then
  raise exception 'Wallet balance changed; payout cannot be paid';
 end if;

 v_left:=v_payout.approved_amount;
 for v_earning in
  select e.id,e.booking_id,e.worker_id,
   (
    case
     when lower(coalesce(e.payment_method,'')) in ('online','upi','card') then
      coalesce((select sum(l.balance_effect) from public.srk_worker_wallet_ledger l
       where l.earning_id=e.id and l.entry_type in ('earning','refund_adjustment')),0)
     when lower(coalesce(e.payment_method,''))='cash' then
      coalesce((select sum(l.balance_effect) from public.srk_worker_wallet_ledger l
       where l.earning_id=e.id and l.entry_type='cash_commission_refund_credit'),0)
     else 0
    end
    -coalesce((select sum(a.allocated_amount) from public.srk_worker_payout_earning_allocations a
      where a.earning_id=e.id),0)
   ) as remaining
  from public.srk_worker_earnings e
  where e.worker_id=v_payout.worker_id
  order by e.created_at,e.id
  for update
 loop
  exit when v_left<=0;
  if v_earning.remaining>0 then
   v_alloc:=least(v_left,v_earning.remaining);
   insert into public.srk_worker_payout_earning_allocations
    (payout_request_id,earning_id,booking_id,worker_id,allocated_amount)
   values(p_payout_id,v_earning.id,v_earning.booking_id,v_earning.worker_id,v_alloc);
   v_left:=v_left-v_alloc;
   v_total_allocated:=v_total_allocated+v_alloc;
  end if;
 end loop;
 if v_left>0 then
  raise exception 'Payout exceeds traceable online earnings or cash-commission refund credits; reconcile wallet before paying';
 end if;

 insert into public.srk_worker_wallet_ledger(
  worker_id,entry_type,amount,balance_effect,description,reference_id,idempotency_key
 ) values(
  v_payout.worker_id,'payout_paid',v_payout.approved_amount,-v_payout.approved_amount,
  'Admin verified payout with earning-level allocation',p_payment_reference,'payout-paid:'||v_payout.id::text
 ) on conflict(idempotency_key) do nothing;

 update public.srk_worker_payout_requests
 set status='paid',payment_method=p_payment_method,payment_reference=p_payment_reference,
     admin_note=coalesce(p_note,admin_note),paid_at=clock_timestamp(),paid_by=auth.uid(),
     recipient_snapshot=v_recipient_snapshot
 where id=p_payout_id returning * into v_payout;
 return v_payout;
end
$function$;

revoke all on function public.srk_admin_mark_worker_payout_paid(uuid,text,text,text) from public,anon;
grant execute on function public.srk_admin_mark_worker_payout_paid(uuid,text,text,text) to authenticated,service_role;