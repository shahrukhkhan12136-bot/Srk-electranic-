-- Harden the SECURITY DEFINER payout trigger against search_path shadowing.
-- The trigger logic, ownership, and EXECUTE ACL remain unchanged.

CREATE OR REPLACE FUNCTION public.srk_create_electrician_payable()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
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
