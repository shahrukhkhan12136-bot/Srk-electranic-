-- SRK ELECTRONIC: separately itemized material proposals and customer decisions.
-- Feature Branch only. No shared TEST/Production migration is performed here.
begin;

create or replace function public.srk_electrician_submit_material_revision(
  p_booking_id uuid,
  p_items jsonb,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_key text := public.srk_timer_validate_idempotency_key(p_idempotency_key);
  v_booking public.service_bookings%rowtype;
  v_profile_id uuid;
  v_bill public.srk_final_bills%rowtype;
  v_revision_id uuid;
  v_revision integer;
  v_item jsonb;
  v_line integer := 0;
  v_description text;
  v_quantity numeric(12,3);
  v_unit_price numeric(12,2);
  v_supplied_by text;
  v_receipt text;
  v_line_total numeric(12,2);
  v_total numeric(12,2) := 0;
  v_replay uuid;
begin
  if v_uid is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='28000'; end if;
  if p_booking_id is null then raise exception 'BOOKING_ID_REQUIRED' using errcode='22023'; end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) < 1 or jsonb_array_length(p_items) > 30 then
    raise exception 'MATERIAL_ITEMS_MUST_BE_ARRAY_1_TO_30' using errcode='22023';
  end if;

  select e.entity_id into v_replay
  from public.srk_booking_audit_events e
  where e.booking_id=p_booking_id and e.actor_user_id=v_uid
    and e.action='material_revision_submitted' and e.idempotency_key=v_key
  limit 1;
  if v_replay is not null then
    return jsonb_build_object('success',true,'revision_id',v_replay,'replayed',true);
  end if;

  select b.* into v_booking
  from public.service_bookings b
  where b.id=p_booking_id
  for update;
  if not found then raise exception 'BOOKING_NOT_FOUND' using errcode='P0002'; end if;

  select e.entity_id into v_replay
  from public.srk_booking_audit_events e
  where e.booking_id=p_booking_id and e.actor_user_id=v_uid
    and e.action='material_revision_submitted' and e.idempotency_key=v_key
  limit 1;
  if v_replay is not null then
    return jsonb_build_object('success',true,'revision_id',v_replay,'replayed',true);
  end if;

  if v_booking.timer_state <> 'stopped' or v_booking.final_bill_id is null then
    raise exception 'FINAL_LABOUR_BILL_REQUIRED' using errcode='55000';
  end if;

  select ep.id into v_profile_id
  from public.electrician_profiles ep
  where ep.id=v_booking.assigned_electrician_id
    and (ep.user_id=v_uid or ep.auth_user_id=v_uid)
    and ep.active=true and ep.verification_status='approved';
  if v_profile_id is null or not exists (
    select 1 from public.job_offers jo
    where jo.booking_id=p_booking_id and jo.electrician_id=v_profile_id and jo.status='accepted'
  ) then
    raise exception 'ASSIGNED_APPROVED_ELECTRICIAN_REQUIRED' using errcode='42501';
  end if;

  select fb.* into v_bill
  from public.srk_final_bills fb
  where fb.id=v_booking.final_bill_id and fb.booking_id=p_booking_id;
  if not found then raise exception 'FINAL_BILL_NOT_FOUND' using errcode='P0002'; end if;

  if exists (
    select 1 from public.srk_bill_material_revisions r
    where r.bill_id=v_bill.id and r.status in ('draft','pending')
  ) then
    raise exception 'MATERIAL_REVISION_ALREADY_OPEN' using errcode='55000';
  end if;

  select coalesce(max(r.revision),0)+1 into v_revision
  from public.srk_bill_material_revisions r where r.bill_id=v_bill.id;

  insert into public.srk_bill_material_revisions
    (bill_id,revision,status,created_by,submitted_at)
  values (v_bill.id,v_revision,'pending',v_uid,clock_timestamp())
  returning id into v_revision_id;

  for v_item in select value from jsonb_array_elements(p_items)
  loop
    if jsonb_typeof(v_item) <> 'object' then
      raise exception 'INVALID_MATERIAL_ITEM_FIELDS' using errcode='22023';
    end if;
    if exists (select 1 from jsonb_object_keys(v_item) k where k not in ('description','quantity','unit_price','supplied_by','receipt_reference')) then
      raise exception 'INVALID_MATERIAL_ITEM_FIELDS' using errcode='22023';
    end if;

    v_description := btrim(coalesce(v_item->>'description',''));
    v_quantity := (v_item->>'quantity')::numeric;
    v_unit_price := (v_item->>'unit_price')::numeric;
    v_supplied_by := v_item->>'supplied_by';
    v_receipt := nullif(btrim(coalesce(v_item->>'receipt_reference','')),'');

    if v_description is null or length(v_description) not between 1 and 240 then raise exception 'INVALID_MATERIAL_DESCRIPTION' using errcode='22023'; end if;
    if v_quantity is null or v_quantity <= 0 or v_quantity > 1000000 then raise exception 'INVALID_MATERIAL_QUANTITY' using errcode='22023'; end if;
    if v_unit_price is null or v_unit_price < 0 or v_unit_price > 10000000 then raise exception 'INVALID_MATERIAL_UNIT_PRICE' using errcode='22023'; end if;
    if v_supplied_by is null or v_supplied_by not in ('electrician','customer') then raise exception 'INVALID_MATERIAL_SUPPLIER' using errcode='22023'; end if;
    if v_supplied_by='electrician' and v_receipt is null then raise exception 'ELECTRICIAN_MATERIAL_RECEIPT_REQUIRED' using errcode='22023'; end if;
    if v_supplied_by='customer' and v_unit_price <> 0 then raise exception 'CUSTOMER_SUPPLIED_MATERIALS_MUST_NOT_BE_CHARGED' using errcode='22023'; end if;

    v_line := v_line + 1;
    v_line_total := case when v_supplied_by='electrician' then round(v_quantity*v_unit_price,2) else 0 end;
    v_total := v_total + v_line_total;
    if v_total > 10000000 then raise exception 'MATERIAL_PROPOSAL_LIMIT_EXCEEDED' using errcode='22023'; end if;

    insert into public.srk_bill_material_items
      (bill_id,revision_id,line_number,description,quantity,unit_price,line_total,supplied_by,receipt_reference,created_by)
    values
      (v_bill.id,v_revision_id,v_line,v_description,v_quantity,v_unit_price,v_line_total,v_supplied_by,v_receipt,v_uid);
  end loop;

  insert into public.srk_booking_audit_events
    (booking_id,actor_user_id,actor_kind,action,entity_type,entity_id,idempotency_key,metadata)
  values
    (p_booking_id,v_uid,'electrician','material_revision_submitted','material_revision',v_revision_id,v_key,
     jsonb_build_object('revision',v_revision,'item_count',v_line,'electrician_material_total',v_total));

  return jsonb_build_object('success',true,'revision_id',v_revision_id,'revision',v_revision,'item_count',v_line,'electrician_material_total',v_total,'replayed',false);
end
$function$;

create or replace function public.srk_customer_decide_material_revision(
  p_revision_id uuid,
  p_decision text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_revision public.srk_bill_material_revisions%rowtype;
  v_bill public.srk_final_bills%rowtype;
  v_booking public.service_bookings%rowtype;
  v_existing text;
  v_now timestamptz;
  v_total numeric(12,2);
begin
  if v_uid is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='28000'; end if;
  if p_revision_id is null or p_decision is null or p_decision not in ('approved','rejected') then
    raise exception 'INVALID_MATERIAL_DECISION' using errcode='22023';
  end if;

  select r.* into v_revision
  from public.srk_bill_material_revisions r
  where r.id=p_revision_id
  for update;
  if not found then raise exception 'MATERIAL_REVISION_NOT_FOUND' using errcode='P0002'; end if;

  select fb.* into v_bill from public.srk_final_bills fb where fb.id=v_revision.bill_id;
  if not found then raise exception 'FINAL_BILL_NOT_FOUND' using errcode='P0002'; end if;
  select b.* into v_booking from public.service_bookings b where b.id=v_bill.booking_id;
  if not found then raise exception 'BOOKING_NOT_FOUND' using errcode='P0002'; end if;
  if v_booking.customer_user_id is distinct from v_uid then
    raise exception 'BOOKING_ACCESS_DENIED' using errcode='42501';
  end if;

  if v_revision.status in ('approved','rejected') then
    if v_revision.status=p_decision then
      return jsonb_build_object('success',true,'revision_id',p_revision_id,'decision',v_revision.status,'replayed',true);
    end if;
    raise exception 'MATERIAL_REVISION_ALREADY_DECIDED' using errcode='55000';
  end if;
  if v_revision.status <> 'pending' then raise exception 'MATERIAL_REVISION_NOT_PENDING' using errcode='55000'; end if;

  select coalesce(sum(i.line_total),0) into v_total
  from public.srk_bill_material_items i
  where i.revision_id=p_revision_id and i.bill_id=v_bill.id;

  v_now := clock_timestamp();
  update public.srk_bill_material_revisions
  set status=p_decision,decided_at=v_now,decided_by=v_uid
  where id=p_revision_id;

  insert into public.srk_bill_material_approvals
    (bill_id,revision,customer_user_id,decision,decided_at,revision_id)
  values
    (v_bill.id,v_revision.revision,v_uid,p_decision,v_now,p_revision_id);

  insert into public.srk_booking_audit_events
    (booking_id,actor_user_id,actor_kind,action,entity_type,entity_id,metadata)
  values
    (v_booking.id,v_uid,'customer','material_revision_decided','material_revision',p_revision_id,
     jsonb_build_object('decision',p_decision,'revision',v_revision.revision,'electrician_material_total',v_total));

  return jsonb_build_object('success',true,'revision_id',p_revision_id,'decision',p_decision,'electrician_material_total',v_total,'replayed',false);
end
$function$;

revoke all on function public.srk_electrician_submit_material_revision(uuid,jsonb,text) from public,anon;
revoke all on function public.srk_customer_decide_material_revision(uuid,text) from public,anon;
grant execute on function public.srk_electrician_submit_material_revision(uuid,jsonb,text) to authenticated;
grant execute on function public.srk_customer_decide_material_revision(uuid,text) to authenticated;

commit;
