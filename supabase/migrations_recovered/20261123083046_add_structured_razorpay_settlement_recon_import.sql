-- Extend settlement reconciliation items with the structured fields returned by Razorpay Settlement Recon.
alter table public.srk_razorpay_settlement_items
  add column if not exists provider_entity_type text,
  add column if not exists debit_amount_paise bigint,
  add column if not exists credit_amount_paise bigint,
  add column if not exists fee_amount_paise bigint not null default 0,
  add column if not exists tax_amount_paise bigint not null default 0,
  add column if not exists settled boolean,
  add column if not exists on_hold boolean,
  add column if not exists provider_created_at timestamptz,
  add column if not exists settled_at timestamptz,
  add column if not exists settlement_utr text,
  add column if not exists razorpay_order_id text,
  add column if not exists razorpay_payment_id text;

alter table public.srk_razorpay_settlement_items
  add constraint srk_razorpay_settlement_item_amounts_nonnegative
    check (amount_paise >= 0 and fee_amount_paise >= 0 and tax_amount_paise >= 0
      and (debit_amount_paise is null or debit_amount_paise >= 0)
      and (credit_amount_paise is null or credit_amount_paise >= 0)) not valid,
  add constraint srk_razorpay_settlement_item_provider_type_check
    check (provider_entity_type is null or provider_entity_type in ('payment','refund','transfer','adjustment')) not valid;

alter table public.srk_razorpay_settlement_items
  validate constraint srk_razorpay_settlement_item_amounts_nonnegative;
alter table public.srk_razorpay_settlement_items
  validate constraint srk_razorpay_settlement_item_provider_type_check;

-- gross_amount is only derivable from the recon rows; keep it NULL until those rows are imported.
alter table public.srk_razorpay_settlements
  alter column gross_amount_paise drop not null;

create or replace function public.srk_service_import_razorpay_settlement(
  p_settlement jsonb,
  p_recon_items jsonb,
  p_source text default 'api'
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $function$
declare
  v_settlement_id uuid;
  v_settlement_ref text;
  v_status text;
  v_amount bigint;
  v_fees bigint;
  v_tax bigint;
  v_utr text;
  v_created_at timestamptz;
  v_gross bigint;
  v_item jsonb;
  v_type text;
  v_provider_ref text;
  v_booking_id uuid;
  v_transaction_id uuid;
  v_inserted integer := 0;
  v_updated integer := 0;
  v_count integer := 0;
begin
  if auth.role() <> 'service_role' then
    raise exception 'Service role required';
  end if;
  if jsonb_typeof(p_settlement) <> 'object' or jsonb_typeof(p_recon_items) <> 'array' then
    raise exception 'Settlement object and recon item array are required';
  end if;
  if jsonb_array_length(p_recon_items) > 1000 then
    raise exception 'At most 1000 recon items may be imported per settlement call';
  end if;

  v_settlement_ref := p_settlement->>'id';
  v_status := p_settlement->>'status';
  if coalesce(p_settlement->>'entity','') <> 'settlement'
     or v_settlement_ref !~ '^setl_[A-Za-z0-9]+$'
     or v_status not in ('created','processed','failed')
     or coalesce(p_settlement->>'currency','INR') <> 'INR'
     or coalesce(p_settlement->>'amount','') !~ '^[0-9]+$'
     or coalesce(p_settlement->>'fees','0') !~ '^[0-9]+$'
     or coalesce(p_settlement->>'tax','0') !~ '^[0-9]+$'
     or coalesce(p_source,'') not in ('api','report_import','webhook') then
    raise exception 'Razorpay settlement payload failed validation';
  end if;
  v_amount := (p_settlement->>'amount')::bigint;
  v_fees := coalesce((p_settlement->>'fees')::bigint,0);
  v_tax := coalesce((p_settlement->>'tax')::bigint,0);
  v_utr := nullif(trim(p_settlement->>'utr'),'');
  v_created_at := case when (p_settlement->>'created_at') ~ '^[0-9]+$'
    then to_timestamp((p_settlement->>'created_at')::double precision) else null end;

  select coalesce(sum((x->>'amount')::bigint),0)
    into v_gross
  from jsonb_array_elements(p_recon_items) x
  where x->>'type'='payment'
    and coalesce(x->>'amount','') ~ '^[0-9]+$';

  insert into public.srk_razorpay_settlements
    (razorpay_settlement_id,settlement_status,currency,gross_amount_paise,
     fee_amount_paise,tax_amount_paise,provider_net_amount_paise,utr,
     provider_created_at,provider_processed_at,source,provider_payload,updated_at)
  values
    (v_settlement_ref,v_status,'INR',case when jsonb_array_length(p_recon_items)>0 then v_gross else null end,
     v_fees,v_tax,v_amount,v_utr,v_created_at,
     case when v_status='processed' then v_created_at else null end,
     p_source,jsonb_build_object('id',v_settlement_ref,'entity','settlement',
       'amount',v_amount,'status',v_status,'fees',v_fees,'tax',v_tax,'utr',v_utr,
       'created_at',p_settlement->'created_at'),'now'::text::timestamptz)
  on conflict (razorpay_settlement_id) do update set
    settlement_status=excluded.settlement_status,
    fee_amount_paise=excluded.fee_amount_paise,
    tax_amount_paise=excluded.tax_amount_paise,
    provider_net_amount_paise=excluded.provider_net_amount_paise,
    utr=excluded.utr,
    provider_created_at=coalesce(excluded.provider_created_at,public.srk_razorpay_settlements.provider_created_at),
    provider_processed_at=case when excluded.settlement_status='processed'
      then coalesce(excluded.provider_processed_at,public.srk_razorpay_settlements.provider_processed_at) else null end,
    gross_amount_paise=case when excluded.gross_amount_paise is not null then excluded.gross_amount_paise
      else public.srk_razorpay_settlements.gross_amount_paise end,
    source=excluded.source,provider_payload=excluded.provider_payload,updated_at=now()
  returning id into v_settlement_id;

  for v_item in select value from jsonb_array_elements(p_recon_items)
  loop
    v_count := v_count + 1;
    v_type := v_item->>'type';
    v_provider_ref := v_item->>'entity_id';
    if v_type not in ('payment','refund','transfer','adjustment')
       or coalesce(v_provider_ref,'') = ''
       or coalesce(v_item->>'amount','') !~ '^[0-9]+$'
       or coalesce(v_item->>'currency','INR') <> 'INR'
       or (v_item ? 'debit' and coalesce(v_item->>'debit','') !~ '^[0-9]+$')
       or (v_item ? 'credit' and coalesce(v_item->>'credit','') !~ '^[0-9]+$')
       or (v_item ? 'fee' and coalesce(v_item->>'fee','') !~ '^[0-9]+$')
       or (v_item ? 'tax' and coalesce(v_item->>'tax','') !~ '^[0-9]+$') then
      raise exception 'Invalid settlement recon item at index %',v_count-1;
    end if;

    v_booking_id := null;
    v_transaction_id := null;
    if v_type='payment' and nullif(v_item->>'order_id','') is not null then
      select po.booking_id into v_booking_id
      from public.srk_razorpay_payment_orders po
      where po.razorpay_order_id=v_item->>'order_id'
      limit 1;
    elsif v_type='refund' and nullif(v_item->>'payment_id','') is not null then
      select bt.booking_id,bt.id into v_booking_id,v_transaction_id
      from public.srk_booking_transactions bt
      where bt.provider='razorpay' and bt.provider_reference=v_item->>'payment_id'
      order by bt.created_at desc limit 1;
    end if;
    if v_booking_id is not null and v_transaction_id is null then
      select bt.id into v_transaction_id
      from public.srk_booking_transactions bt
      where bt.booking_id=v_booking_id and bt.provider='razorpay'
        and (bt.provider_reference=v_provider_ref or bt.order_reference=v_item->>'order_id')
      order by bt.created_at desc limit 1;
    end if;

    insert into public.srk_razorpay_settlement_items
      (settlement_id,item_type,provider_reference,booking_id,booking_transaction_id,
       amount_paise,currency,item_note,provider_item,provider_entity_type,
       debit_amount_paise,credit_amount_paise,fee_amount_paise,tax_amount_paise,
       settled,on_hold,provider_created_at,settled_at,settlement_utr,
       razorpay_order_id,razorpay_payment_id)
    values
      (v_settlement_id,case when v_type in ('payment','refund','adjustment') then v_type else 'other' end,
       v_provider_ref,v_booking_id,v_transaction_id,(v_item->>'amount')::bigint,'INR',
       nullif(v_item->>'description',''),
       jsonb_strip_nulls(jsonb_build_object(
         'entity_id',v_provider_ref,'type',v_type,'amount',v_item->'amount',
         'debit',v_item->'debit','credit',v_item->'credit','fee',v_item->'fee','tax',v_item->'tax',
         'settled',v_item->'settled','on_hold',v_item->'on_hold','order_id',v_item->'order_id',
         'payment_id',v_item->'payment_id','settlement_id',v_item->'settlement_id',
         'settlement_utr',v_item->'settlement_utr','created_at',v_item->'created_at',
         'settled_at',v_item->'settled_at','description',v_item->'description')),
       v_type,
       case when coalesce(v_item->>'debit','') ~ '^[0-9]+$' then (v_item->>'debit')::bigint else null end,
       case when coalesce(v_item->>'credit','') ~ '^[0-9]+$' then (v_item->>'credit')::bigint else null end,
       coalesce((v_item->>'fee')::bigint,0),coalesce((v_item->>'tax')::bigint,0),
       case when v_item ? 'settled' then (v_item->>'settled')::boolean else null end,
       case when v_item ? 'on_hold' then (v_item->>'on_hold')::boolean else null end,
       case when coalesce(v_item->>'created_at','') ~ '^[0-9]+$' then to_timestamp((v_item->>'created_at')::double precision) else null end,
       case when coalesce(v_item->>'settled_at','') ~ '^[0-9]+$' then to_timestamp((v_item->>'settled_at')::double precision) else null end,
       nullif(v_item->>'settlement_utr',''),nullif(v_item->>'order_id',''),nullif(v_item->>'payment_id',''))
    on conflict (settlement_id,item_type,provider_reference) do update set
      booking_id=coalesce(excluded.booking_id,public.srk_razorpay_settlement_items.booking_id),
      booking_transaction_id=coalesce(excluded.booking_transaction_id,public.srk_razorpay_settlement_items.booking_transaction_id),
      amount_paise=excluded.amount_paise,item_note=excluded.item_note,provider_item=excluded.provider_item,
      provider_entity_type=excluded.provider_entity_type,debit_amount_paise=excluded.debit_amount_paise,
      credit_amount_paise=excluded.credit_amount_paise,fee_amount_paise=excluded.fee_amount_paise,
      tax_amount_paise=excluded.tax_amount_paise,settled=excluded.settled,on_hold=excluded.on_hold,
      provider_created_at=excluded.provider_created_at,settled_at=excluded.settled_at,
      settlement_utr=excluded.settlement_utr,razorpay_order_id=excluded.razorpay_order_id,
      razorpay_payment_id=excluded.razorpay_payment_id;
    v_inserted := v_inserted + 1;
  end loop;

  return jsonb_build_object('success',true,'settlement_id',v_settlement_id,
    'razorpay_settlement_id',v_settlement_ref,'recon_items_seen',v_count,
    'gross_amount_paise',case when jsonb_array_length(p_recon_items)>0 then v_gross else null end,
    'provider_net_amount_paise',v_amount);
end;
$function$;

revoke all on function public.srk_service_import_razorpay_settlement(jsonb,jsonb,text) from public,anon,authenticated;
grant execute on function public.srk_service_import_razorpay_settlement(jsonb,jsonb,text) to service_role;
