create or replace function public.srk_create_electrician_payable()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_service numeric(12,2);
  v_materials numeric(12,2);
  v_total numeric(12,2);
  v_rate numeric(7,2);
  v_commission numeric(12,2);
begin
  if new.payment_status = 'paid'
     and new.status = 'completed'
     and new.quote_status = 'approved'
     and new.assigned_electrician_id is not null
     and new.payment_verified_at is not null
     and new.razorpay_payment_id is not null then
    v_service := round(coalesce(new.service_charge,0),2);
    v_materials := round(coalesce(new.materials_amount,0),2);
    v_total := round(v_service + v_materials,2);
    v_rate := new.commission_rate;

    if v_rate < 0 or v_rate > 100 then
      raise exception 'Commission rate must be between 0 and 100; payout ledger not created';
    end if;

    if round(coalesce(new.amount_paid,0),2) <> v_total then
      raise exception 'Verified payment amount does not match approved quote total; payout ledger not created';
    end if;

    v_commission := round(v_service * v_rate / 100,2);

    insert into public.srk_electrician_payouts (
      booking_id, electrician_profile_id, razorpay_payment_id,
      gross_service_amount, materials_amount, platform_commission,
      electrician_payable, payout_status
    ) values (
      new.id, new.assigned_electrician_id, new.razorpay_payment_id,
      v_service, v_materials, v_commission,
      round(v_service + v_materials - v_commission,2), 'pending'
    )
    on conflict (booking_id) do update set
      electrician_profile_id = excluded.electrician_profile_id,
      razorpay_payment_id = excluded.razorpay_payment_id,
      gross_service_amount = excluded.gross_service_amount,
      materials_amount = excluded.materials_amount,
      platform_commission = excluded.platform_commission,
      electrician_payable = excluded.electrician_payable,
      updated_at = now()
    where public.srk_electrician_payouts.payout_status = 'pending';
  elsif new.payment_status = 'refunded' then
    update public.srk_electrician_payouts
      set payout_status = 'refunded', updated_at = now()
      where booking_id = new.id and payout_status = 'pending';
  end if;
  return new;
end;
$function$;

create or replace function public.srk_admin_mark_electrician_payout_paid(
  p_payout_id uuid,
  p_method text,
  p_reference text,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_row public.srk_electrician_payouts%rowtype;
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'Admin access required' using errcode = '42501';
  end if;
  if p_method not in ('upi','bank') then
    raise exception 'Payout method must be upi or bank';
  end if;
  if p_reference is null or length(trim(p_reference)) < 4 then
    raise exception 'Valid UTR / UPI reference is required';
  end if;

  select * into v_row
    from public.srk_electrician_payouts
    where id = p_payout_id
    for update;

  if not found then
    raise exception 'Payout record not found';
  end if;
  if v_row.payout_status <> 'pending' then
    raise exception 'Only pending payouts can be marked paid';
  end if;

  if not exists (
    select 1
    from public.service_bookings b
    where b.id = v_row.booking_id
      and b.status = 'completed'
      and b.quote_status = 'approved'
      and b.payment_status = 'paid'
      and b.payment_verified_at is not null
      and b.razorpay_payment_id = v_row.razorpay_payment_id
      and b.assigned_electrician_id = v_row.electrician_profile_id
      and round(coalesce(b.amount_paid,0),2) =
          round(coalesce(b.service_charge,0) + coalesce(b.materials_amount,0),2)
      and round(coalesce(v_row.gross_service_amount,0),2) =
          round(coalesce(b.service_charge,0),2)
      and round(coalesce(v_row.materials_amount,0),2) =
          round(coalesce(b.materials_amount,0),2)
      and round(coalesce(v_row.platform_commission,0),2) =
          round(coalesce(b.service_charge,0) * b.commission_rate / 100,2)
      and round(coalesce(v_row.electrician_payable,0),2) =
          round(coalesce(b.service_charge,0) + coalesce(b.materials_amount,0)
                - round(coalesce(b.service_charge,0) * b.commission_rate / 100,2),2)
  ) then
    raise exception 'Booking payment or payout ledger does not match verified booking; payout blocked';
  end if;

  update public.srk_electrician_payouts
    set payout_status='paid',
        payout_method=p_method,
        payout_reference=trim(p_reference),
        payout_note=nullif(trim(p_note),''),
        paid_by=auth.uid(),
        paid_at=now(),
        updated_at=now()
    where id=p_payout_id;

  return jsonb_build_object('success',true,'payout_id',p_payout_id,'status','paid');
end;
$function$;