-- SRK ELECTRONIC: customer-approved, immutable payable snapshot.
-- Feature Branch only. Do not apply to shared TEST/Production without approval.
begin;

-- Keep the unrounded labour calculation in the snapshot. Only total_amount
-- is rounded to paise after labour and approved materials are added.
alter table public.srk_booking_payable_snapshots
  alter column labour_amount type numeric(20,10)
  using labour_amount::numeric(20,10);

alter table public.srk_booking_payable_snapshots
  drop constraint if exists srk_booking_payable_snapshots_total_amount_check;

alter table public.srk_booking_payable_snapshots
  add constraint srk_booking_payable_snapshots_total_amount_check
  check (total_amount = round(labour_amount + materials_amount, 2));

create or replace function public.srk_customer_create_payable_snapshot(
  p_booking_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_booking public.service_bookings%rowtype;
  v_bill public.srk_final_bills%rowtype;
  v_revision_id uuid;
  v_materials numeric(12,2) := 0;
  v_labour numeric(20,10);
  v_total numeric(12,2);
  v_paise bigint;
  v_snapshot public.srk_booking_payable_snapshots%rowtype;
begin
  if v_uid is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode='28000';
  end if;
  if p_booking_id is null then
    raise exception 'BOOKING_ID_REQUIRED' using errcode='22023';
  end if;

  select b.* into v_booking
  from public.service_bookings b
  where b.id=p_booking_id and b.customer_user_id=v_uid
  for update;
  if not found then
    raise exception 'CUSTOMER_BOOKING_NOT_FOUND' using errcode='42501';
  end if;

  if v_booking.service_category_code is null
     or v_booking.timer_state <> 'stopped'
     or v_booking.final_bill_id is null then
    raise exception 'FINAL_TIMER_BILL_REQUIRED' using errcode='55000';
  end if;

  select ps.* into v_snapshot
  from public.srk_booking_payable_snapshots ps
  where ps.booking_id=p_booking_id
  order by ps.created_at desc
  limit 1;
  if found then
    return jsonb_build_object(
      'success',true,'snapshot_id',v_snapshot.id,'booking_id',p_booking_id,
      'bill_id',v_snapshot.bill_id,'material_revision_id',v_snapshot.material_revision_id,
      'labour_amount',v_snapshot.labour_amount,'materials_amount',v_snapshot.materials_amount,
      'total_amount',v_snapshot.total_amount,'amount_paise',v_snapshot.amount_paise,
      'currency',v_snapshot.currency,'replayed',true
    );
  end if;

  select fb.* into v_bill
  from public.srk_final_bills fb
  where fb.id=v_booking.final_bill_id and fb.booking_id=p_booking_id;
  if not found then
    raise exception 'FINAL_BILL_NOT_FOUND' using errcode='P0002';
  end if;

  if exists (
    select 1 from public.srk_bill_material_revisions r
    where r.bill_id=v_bill.id and r.status='pending'
  ) then
    raise exception 'MATERIAL_APPROVAL_PENDING' using errcode='55000';
  end if;

  -- A revision is a complete replacement proposal. The newest approved
  -- revision is the one charged; rejected revisions never become payable.
  select r.id into v_revision_id
  from public.srk_bill_material_revisions r
  join public.srk_bill_material_approvals a
    on a.revision_id=r.id
   and a.bill_id=r.bill_id
   and a.revision=r.revision
   and a.customer_user_id=v_uid
   and a.decision='approved'
  where r.bill_id=v_bill.id and r.status='approved'
  order by r.revision desc
  limit 1;

  if v_revision_id is not null then
    select coalesce(sum(i.line_total),0)::numeric(12,2)
      into v_materials
    from public.srk_bill_material_items i
    where i.bill_id=v_bill.id
      and i.revision_id=v_revision_id
      and i.supplied_by='electrician';
  end if;

  v_labour := v_bill.labour_amount;
  v_total := round(v_labour + v_materials,2);
  v_paise := (v_total*100)::bigint;

  if v_total < 0 or v_total > 99999999.99 or v_paise < 0 then
    raise exception 'PAYABLE_AMOUNT_OUT_OF_RANGE' using errcode='22003';
  end if;

  insert into public.srk_booking_payable_snapshots(
    booking_id,bill_id,material_revision_id,bill_version,
    labour_amount,materials_amount,total_amount,amount_paise,currency,
    calculation_version,created_by
  ) values (
    p_booking_id,v_bill.id,v_revision_id,v_bill.bill_version,
    v_labour,v_materials,v_total,v_paise,'INR',
    'timer-v1-material-revision-v1-final-paise-half-up',v_uid
  ) returning * into v_snapshot;

  insert into public.srk_booking_audit_events(
    booking_id,actor_user_id,actor_kind,action,entity_type,entity_id,metadata
  ) values (
    p_booking_id,v_uid,'customer','payable_snapshot_created',
    'payable_snapshot',v_snapshot.id,
    jsonb_build_object(
      'bill_id',v_bill.id,'bill_version',v_bill.bill_version,
      'material_revision_id',v_revision_id,
      'labour_amount_unrounded',v_labour,
      'materials_amount',v_materials,
      'total_amount',v_total,'amount_paise',v_paise
    )
  );

  return jsonb_build_object(
    'success',true,'snapshot_id',v_snapshot.id,'booking_id',p_booking_id,
    'bill_id',v_snapshot.bill_id,'material_revision_id',v_snapshot.material_revision_id,
    'labour_amount',v_snapshot.labour_amount,'materials_amount',v_snapshot.materials_amount,
    'total_amount',v_snapshot.total_amount,'amount_paise',v_snapshot.amount_paise,
    'currency',v_snapshot.currency,'replayed',false
  );
end
$function$;

revoke all on function public.srk_customer_create_payable_snapshot(uuid) from public,anon;
grant execute on function public.srk_customer_create_payable_snapshot(uuid) to authenticated;

commit;
