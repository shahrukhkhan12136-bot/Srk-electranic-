
create or replace function public.srk_customer_preview_booking_price_v2(
 p_category_id uuid,p_service_type_id uuid,p_skill_id uuid,p_skill_level_id uuid,
 p_technician_count integer,p_helper_count integer,p_duration_hours integer,
 p_motor_hp numeric default null,p_unit_count integer default 1
)
returns table(
 pricing_unit text,qualification_level text,
 technician_rate numeric,helper_rate numeric,
 estimated_base_total numeric,estimated_company_commission numeric,
 estimated_worker_net numeric,overtime_may_apply boolean,
 materials_included boolean,price_note text,
 pending_cancellation_fee_amount numeric,estimated_customer_total numeric
)
language sql
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
 select p.pricing_unit,p.qualification_level,p.technician_rate,p.helper_rate,
   p.estimated_base_total,p.estimated_company_commission,p.estimated_worker_net,
   p.overtime_may_apply,p.materials_included,p.price_note,
   coalesce(f.pending_fee,0)::numeric,
   round(p.estimated_base_total+coalesce(f.pending_fee,0),2)
 from public.srk_customer_preview_booking_price(
   p_category_id,p_service_type_id,p_skill_id,p_skill_level_id,
   p_technician_count,p_helper_count,p_duration_hours,p_motor_hp,p_unit_count
 ) p
 cross join lateral (
   select sum(cf.fee_amount) pending_fee
   from public.srk_booking_cancellation_fees cf
   where cf.customer_user_id=auth.uid() and cf.status='pending'
 ) f
$function$;
revoke all on function public.srk_customer_preview_booking_price_v2(uuid,uuid,uuid,uuid,integer,integer,integer,numeric,integer) from public,anon;
grant execute on function public.srk_customer_preview_booking_price_v2(uuid,uuid,uuid,uuid,integer,integer,integer,numeric,integer) to authenticated;
