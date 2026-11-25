begin;

create or replace function public.srk_submit_labour_quote(
  p_booking_id uuid,
  p_service_charge numeric,
  p_quote_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth','pg_temp'
as $function$
declare
  v_profile_id uuid;
  v_booking public.service_bookings%rowtype;
  v_total numeric(12,2);
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode='42501';
  end if;

  if p_booking_id is null or p_service_charge is null
     or p_service_charge<=0 or p_service_charge>10000000
     or p_service_charge<>round(p_service_charge,2) then
    raise exception 'Invalid labour quote' using errcode='22023';
  end if;

  select id into v_profile_id
  from public.electrician_profiles
  where (user_id=auth.uid() or auth_user_id=auth.uid())
    and verification_status='approved'
    and active=true
  order by created_at desc
  limit 1;

  if v_profile_id is null then
    raise exception 'Approved active technician required' using errcode='42501';
  end if;

  select * into v_booking
  from public.service_bookings
  where id=p_booking_id
    and assigned_electrician_id=v_profile_id
  for update;

  if not found then
    raise exception 'Assigned booking not found' using errcode='42501';
  end if;

  if v_booking.status not in ('assigned','inspection','quote_rejected') then
    raise exception 'Booking is not ready for a labour quote' using errcode='22023';
  end if;

  v_total:=round(p_service_charge,2);

  update public.service_bookings
  set service_charge=v_total,
      quoted_amount=v_total,
      quote_note=left(coalesce(p_quote_note,''),1000),
      quote_status='pending',
      quote_submitted_at=pg_catalog.now(),
      quote_responded_at=null,
      status='awaiting_quote_approval'
  where id=p_booking_id;

  return pg_catalog.jsonb_build_object(
    'success',true,
    'labour_amount',v_total,
    'total',v_total,
    'quote_status','pending'
  );
end
$function$;

revoke all on function public.srk_submit_labour_quote(uuid,numeric,text) from public;
revoke all on function public.srk_submit_labour_quote(uuid,numeric,text) from anon;
grant execute on function public.srk_submit_labour_quote(uuid,numeric,text) to authenticated,service_role;

-- The final bill total is strictly the approved labour amount.
create or replace function public.srk_set_final_bill_total()
returns trigger
language plpgsql
set search_path to 'pg_catalog','public'
as $function$
begin
  if new.service_amount is null or new.service_amount<0 then
    raise exception 'Invalid labour amount' using errcode='22023';
  end if;
  new.total_amount:=round(new.service_amount+coalesce(new.cancellation_fee_amount,0)-coalesce(new.discount_amount,0)+coalesce(new.tax_amount,0),2);
  return new;
end;
$function$;

-- Keep the existing finalization safeguards and worker-earning calculations,
-- but ensure the generated bill contains only the labour line.
do $migration$
declare
  v_definition text;
  v_old text;
begin
  v_definition:=pg_get_functiondef('public.srk_admin_finalize_booking_bill(uuid)'::regprocedure);

  if position('v_material numeric(12,2);' in v_definition)=0
     or position('v_cancellation_fee numeric(12,2):=0;' in v_definition)=0
     or position('if v_material>0 then' in v_definition)=0
     or position('if v_cancellation_fee>0 then' in v_definition)=0 then
    raise exception 'Final bill function no longer matches the reviewed definition; stop and review manually';
  end if;

  v_definition:=replace(v_definition,'  v_material numeric(12,2);'||E'\n','');
  v_definition:=replace(v_definition,'  v_cancellation_fee numeric(12,2):=0;'||E'\n','');
  v_definition:=replace(v_definition,'  v_material:=0;'||E'\n','');
  v_definition:=replace(v_definition,'  v_cancellation_fee:=coalesce(v_booking.pending_cancellation_fee_amount,0);'||E'\n','');
  v_definition:=replace(v_definition,
    'service_amount=v_labour,materials_amount=v_material,cancellation_fee_amount=v_cancellation_fee,',
    'service_amount=v_labour,materials_amount=0,cancellation_fee_amount=0,');
  v_definition:=replace(v_definition,
    '1,v_labour,v_material,v_cancellation_fee,''issued'',clock_timestamp()',
    '1,v_labour,0,0,''issued'',clock_timestamp()');

  v_old:=$old$  if v_material>0 then
    insert into public.srk_booking_final_bill_items(
      bill_id,item_type,description,quantity,unit,unit_price
    ) values (
      v_bill.id,'material','Materials supplied (separate from commission)',1,'booking',v_material
    );
  end if;

$old$;
  if position(v_old in v_definition)=0 then
    raise exception 'Final bill item block changed; stop and review manually';
  end if;
  v_definition:=replace(v_definition,v_old,'');

  v_old:=$old$  if v_cancellation_fee>0 then
    insert into public.srk_booking_final_bill_items(
      bill_id,item_type,description,quantity,unit,unit_price
    ) values(v_bill.id,'cancellation_fee','Pending cancellation fee from a previous booking',1,'booking',v_cancellation_fee);
  end if;

$old$;
  if position(v_old in v_definition)=0 then
    raise exception 'Cancellation fee bill item block changed; stop and review manually';
  end if;
  v_definition:=replace(v_definition,v_old,'');

  if position('v_material' in v_definition)>0 then
    raise exception 'Non-labour bill calculation remains; stop and review manually';
  end if;

  execute v_definition;
end
$migration$;

commit;
