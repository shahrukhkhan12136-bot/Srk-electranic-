-- Keep Razorpay provider refund identity one-to-one with the internal refund record.
-- Repeated observations for the same internal refund/provider ID remain append-only and valid.
-- Feature branch source only; this migration has NOT been applied to any database.

create or replace function public.srk_enforce_razorpay_refund_identity_mapping()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare
  v_refund_record_id uuid;
  v_provider_refund_id text;
begin
  if tg_table_name='srk_razorpay_refund_recovery_audits' then
    v_refund_record_id:=new.refund_record_id;
    v_provider_refund_id:=new.provider_refund_id;
  elsif tg_table_name='srk_razorpay_refunds' then
    v_refund_record_id:=new.id;
    v_provider_refund_id:=new.refund_id;

    if tg_op='UPDATE' and old.refund_id is not null
       and new.refund_id is distinct from old.refund_id then
      raise exception 'PROVIDER_REFUND_ID_IS_IMMUTABLE' using errcode='55000';
    end if;
  else
    raise exception 'UNSUPPORTED_REFUND_IDENTITY_TABLE';
  end if;

  if v_refund_record_id is null or v_provider_refund_id is null then
    return new;
  end if;

  -- Serialize claims for the same provider ID across both write paths.
  perform pg_advisory_xact_lock(hashtextextended(v_provider_refund_id, 731942));

  -- One provider refund ID cannot identify two internal refund records.
  if exists (
    select 1 from public.srk_razorpay_refund_recovery_audits a
    where a.provider_refund_id=v_provider_refund_id
      and a.refund_record_id is distinct from v_refund_record_id
  ) or exists (
    select 1 from public.srk_razorpay_refunds r
    where r.refund_id=v_provider_refund_id
      and r.id is distinct from v_refund_record_id
  ) then
    raise exception 'PROVIDER_REFUND_ID_ALREADY_BOUND_TO_ANOTHER_REFUND'
      using errcode='23505';
  end if;

  -- One internal refund record cannot accumulate conflicting provider IDs.
  if exists (
    select 1 from public.srk_razorpay_refund_recovery_audits a
    where a.refund_record_id=v_refund_record_id
      and a.provider_refund_id is distinct from v_provider_refund_id
  ) or exists (
    select 1 from public.srk_razorpay_refunds r
    where r.id=v_refund_record_id
      and r.refund_id is not null
      and r.refund_id is distinct from v_provider_refund_id
  ) then
    raise exception 'REFUND_RECORD_ALREADY_BOUND_TO_ANOTHER_PROVIDER_REFUND'
      using errcode='23505';
  end if;

  return new;
end;
$$;

revoke all on function public.srk_enforce_razorpay_refund_identity_mapping()
  from public,anon,authenticated,service_role;

drop trigger if exists srk_refund_recovery_provider_identity_guard
  on public.srk_razorpay_refund_recovery_audits;
create trigger srk_refund_recovery_provider_identity_guard
before insert on public.srk_razorpay_refund_recovery_audits
for each row execute function public.srk_enforce_razorpay_refund_identity_mapping();

drop trigger if exists srk_refund_provider_identity_guard
  on public.srk_razorpay_refunds;
create trigger srk_refund_provider_identity_guard
before insert or update of refund_id on public.srk_razorpay_refunds
for each row execute function public.srk_enforce_razorpay_refund_identity_mapping();

comment on function public.srk_enforce_razorpay_refund_identity_mapping() is
  'Serializes and enforces one-to-one mapping between Razorpay refund IDs and internal refund records while allowing repeated evidence observations for the same mapping.';
