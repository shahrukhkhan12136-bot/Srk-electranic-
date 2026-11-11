-- SRK ELECTRONIC: ownership-scoped read API for timer, bill and evidence.
-- Browser roles receive no direct SELECT on workflow tables.

begin;

create or replace function public.srk_get_booking_timer_bill_details(p_booking_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_booking public.service_bookings%rowtype;
  v_profile_id uuid;
  v_is_admin boolean := false;
  v_result jsonb;
begin
  if v_uid is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='28000'; end if;
  if p_booking_id is null then raise exception 'BOOKING_ID_REQUIRED' using errcode='22023'; end if;

  select b.* into v_booking
  from public.service_bookings b
  where b.id=p_booking_id;
  if not found then raise exception 'BOOKING_NOT_FOUND' using errcode='P0002'; end if;

  if v_booking.customer_user_id=v_uid then
    null;
  else
    select ep.id into v_profile_id
    from public.electrician_profiles ep
    where ep.id=v_booking.assigned_electrician_id
      and (ep.user_id=v_uid or ep.auth_user_id=v_uid)
      and ep.active=true and ep.verification_status='approved';
    if v_profile_id is not null and exists (
      select 1 from public.job_offers jo
      where jo.booking_id=p_booking_id and jo.electrician_id=v_profile_id and jo.status='accepted'
    ) then
      null;
    else
      v_is_admin := public.is_srk_admin();
      if not v_is_admin then raise exception 'BOOKING_ACCESS_DENIED' using errcode='42501'; end if;
    end if;
  end if;

  select jsonb_build_object(
    'booking_id',b.id,
    'timer_state',b.timer_state,
    'service_category_code',b.service_category_code,
    'service_category_label',b.service_category_label,
    'hourly_rate_snapshot',b.hourly_rate_snapshot,
    'electrician_arrived_at',b.electrician_arrived_at,
    'timer_started_at',b.timer_started_at,
    'timer_start_approved_at',b.timer_start_approved_at,
    'timer_stop_requested_at',b.timer_stop_requested_at,
    'timer_stopped_at',b.timer_stopped_at,
    'timer_stop_approved_at',b.timer_stop_approved_at,
    'timer_elapsed_seconds',b.timer_elapsed_seconds,
    'timer_billable_minutes',b.timer_billable_minutes,
    'final_bill_id',b.final_bill_id,
    'timer_decisions',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',d.id,'action',d.action,'decision',d.decision,
        'requested_at',d.requested_at,'decided_at',d.decided_at,
        'effective_at',d.effective_at
      ) order by d.requested_at)
      from public.srk_booking_timer_decisions d where d.booking_id=b.id
    ),'[]'::jsonb),
    'final_bill',(
      select jsonb_build_object(
        'id',fb.id,'bill_version',fb.bill_version,
        'category_code',fb.category_code,'category_label',fb.category_label,
        'hourly_rate',fb.hourly_rate,'started_at',fb.started_at,
        'stopped_at',fb.stopped_at,'elapsed_seconds',fb.elapsed_seconds,
        'billable_minutes',fb.billable_minutes,'labour_amount',fb.labour_amount,
        'calculation_version',fb.calculation_version,'generated_at',fb.generated_at
      )
      from public.srk_final_bills fb where fb.id=b.final_bill_id
    ),
    'material_revisions',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',r.id,'revision',r.revision,'status',r.status,
        'created_at',r.created_at,'submitted_at',r.submitted_at,
        'decided_at',r.decided_at,
        'items',coalesce((
          select jsonb_agg(jsonb_build_object(
            'id',i.id,'line_number',i.line_number,'description',i.description,
            'quantity',i.quantity,'unit_price',i.unit_price,'line_total',i.line_total,
            'supplied_by',i.supplied_by,'receipt_reference',i.receipt_reference
          ) order by i.line_number)
          from public.srk_bill_material_items i where i.revision_id=r.id
        ),'[]'::jsonb)
      ) order by r.revision)
      from public.srk_bill_material_revisions r
      join public.srk_final_bills fb on fb.id=r.bill_id
      where fb.id=b.final_bill_id
    ),'[]'::jsonb),
    'payable_snapshots',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',ps.id,'bill_id',ps.bill_id,'bill_version',ps.bill_version,
        'material_revision_id',ps.material_revision_id,
        'labour_amount',ps.labour_amount,'materials_amount',ps.materials_amount,
        'total_amount',ps.total_amount,'amount_paise',ps.amount_paise,
        'currency',ps.currency,'created_at',ps.created_at
      ) order by ps.created_at)
      from public.srk_booking_payable_snapshots ps where ps.booking_id=b.id
    ),'[]'::jsonb),
    'cash_receipts',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',cr.id,'payable_snapshot_id',cr.payable_snapshot_id,
        'amount_paise',cr.amount_paise,'currency',cr.currency,
        'confirmed_at',cr.confirmed_at,'receipt_note',cr.receipt_note
      ) order by cr.confirmed_at)
      from public.srk_cash_receipts cr where cr.booking_id=b.id
    ),'[]'::jsonb),
    'is_admin_view',v_is_admin
  ) into v_result
  from public.service_bookings b
  where b.id=p_booking_id;

  return v_result;
end
$function$;

revoke all on function public.srk_get_booking_timer_bill_details(uuid) from public,anon;
grant execute on function public.srk_get_booking_timer_bill_details(uuid) to authenticated;

commit;
