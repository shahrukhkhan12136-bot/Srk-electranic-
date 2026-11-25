-- Admin-only person history lookup and six-category skill counts.
-- Internal SECURITY DEFINER routines stay in the non-exposed srk_private schema.
-- Public RPC wrappers are SECURITY INVOKER and grant EXECUTE only to authenticated users.

create table if not exists srk_private.admin_person_history_access_log (
  id bigint generated always as identity primary key,
  admin_user_id uuid not null,
  person_type text not null,
  person_id uuid not null,
  person_code text not null,
  from_date date not null,
  to_date date not null,
  generated_at timestamptz not null default clock_timestamp()
);

alter table srk_private.admin_person_history_access_log enable row level security;
revoke all on srk_private.admin_person_history_access_log from public, anon, authenticated;

create or replace function srk_private.get_admin_person_history(
  p_id_number text,
  p_from_date date,
  p_to_date date
) returns jsonb
language plpgsql
volatile
security definer
set search_path = pg_catalog, public, auth, srk_private
as $function$
declare
  v_worker public.srk_worker_profiles%rowtype;
  v_customer public.srk_customer_profiles%rowtype;
  v_staff public.srk_staff_profiles%rowtype;
  v_documents jsonb := '[]'::jsonb;
  v_insights jsonb := '[]'::jsonb;
  v_improvements jsonb := '[]'::jsonb;
  v_strengths jsonb := '[]'::jsonb;
  v_completed_count integer := 0;
  v_cancelled_count integer := 0;
  v_rejected_count integer := 0;
  v_person_type text;
  v_person_id uuid;
  v_user_id uuid;
  v_person jsonb;
  v_bookings jsonb := '[]'::jsonb;
  v_sessions jsonb := '[]'::jsonb;
  v_earnings jsonb := '[]'::jsonb;
  v_payouts jsonb := '[]'::jsonb;
  v_ledger jsonb := '[]'::jsonb;
  v_complaints jsonb := '[]'::jsonb;
  v_activity jsonb := '[]'::jsonb;
  v_summary jsonb;
  v_performance jsonb;
  v_from timestamptz;
  v_until timestamptz;
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'Main Admin permission required' using errcode='42501';
  end if;
  if nullif(btrim(p_id_number), '') is null then
    raise exception 'ID number is required' using errcode='22023';
  end if;
  if p_from_date is null or p_to_date is null or p_to_date < p_from_date then
    raise exception 'A valid report date range is required' using errcode='22023';
  end if;
  if p_to_date - p_from_date > 3650 then
    raise exception 'Report range cannot exceed 10 years' using errcode='22023';
  end if;
  v_from := p_from_date::timestamp at time zone 'Asia/Kolkata';
  v_until := (p_to_date + 1)::timestamp at time zone 'Asia/Kolkata';

  select * into v_worker
  from public.srk_worker_profiles
  where upper(worker_code) = upper(btrim(p_id_number))
  limit 1;

  if found then
    v_person_type := case when v_worker.worker_type = 'helper' then 'helper' else 'technician' end;
    v_person_id := v_worker.id;
    v_user_id := v_worker.user_id;
    v_person := jsonb_build_object(
      'id', v_worker.id, 'code', v_worker.worker_code, 'type', v_person_type,
      'name', v_worker.full_name, 'phone', v_worker.phone,
      'verification_status', v_worker.verification_status,
      'is_active', v_worker.is_active, 'is_online', v_worker.is_online,
      'father_name',v_worker.father_name,'date_of_birth',v_worker.date_of_birth,
      'photo_path',v_worker.photo_path,'address',v_worker.address,
      'state', v_worker.state, 'district', v_worker.district, 'pincode', v_worker.pincode,
      'service_radius_km',v_worker.service_radius_km,'experience_years', v_worker.experience_years,
      'has_helper',v_worker.has_helper,'bank_account_last4',v_worker.bank_account_last4,
      'upi_id',v_worker.upi_id,'payout_details_change_status',v_worker.payout_details_change_status,
      'created_at', v_worker.created_at,'updated_at', v_worker.updated_at,
      'application',(select jsonb_build_object('application_id',a.id,'status',a.status,
        'submitted_at',a.created_at,'reviewed_at',a.reviewed_at,'reviewed_by',a.reviewed_by,
        'admin_note',a.admin_note,'about',a.about)
        from public.srk_worker_applications a where a.user_id=v_worker.user_id
        order by a.created_at desc limit 1)
    );

    select coalesce(jsonb_agg(jsonb_build_object(
      'booking_id', b.id, 'order_number', b.order_number, 'service', b.service_type,
      'state', b.state, 'district', b.district, 'status', b.status,
      'payment_status', b.payment_status, 'payment_method', b.payment_method,
      'created_at', b.created_at, 'assigned_at', bw.assigned_at,
      'accepted_at', bw.accepted_at, 'rejected_at', bw.rejected_at,
      'on_the_way_at', bw.on_the_way_at, 'arrived_at', bw.arrived_at,
      'completed_at', bw.worker_completed_at, 'assignment_status', bw.assignment_status,
      'completion_note', bw.worker_completion_note, 'hourly_rate_snapshot', bw.hourly_rate_snapshot
    ) order by b.created_at desc), '[]'::jsonb)
    into v_bookings
    from public.srk_booking_workers bw
    join public.service_bookings b on b.id = bw.booking_id
    where bw.worker_id = v_worker.id
      and coalesce(bw.worker_completed_at, bw.accepted_at, bw.assigned_at, b.created_at)
           >= v_from
      and coalesce(bw.worker_completed_at, bw.accepted_at, bw.assigned_at, b.created_at)
          < v_until;

    select coalesce(jsonb_agg(jsonb_build_object(
      'booking_worker_id', ws.booking_worker_id, 'work_date', ws.work_date,
      'status', ws.session_status, 'started_at', ws.started_at, 'ended_at', ws.ended_at,
      'billable_seconds', ws.billable_seconds, 'pause_reason', ws.pause_reason,
      'completion_note', ws.completion_note, 'start_latitude', ws.start_latitude,
      'start_longitude', ws.start_longitude, 'last_gps_at', ws.last_gps_at
    ) order by ws.work_date desc, ws.started_at desc), '[]'::jsonb)
    into v_sessions
    from public.srk_worker_work_sessions ws
    where ws.worker_id = v_worker.id
      and ws.work_date between p_from_date and p_to_date;

    select coalesce(jsonb_agg(jsonb_build_object(
      'earning_id', e.id, 'booking_id', e.booking_id, 'worker_role', e.worker_role,
      'gross_service_earning', e.gross_service_earning,
      'commission_rate', e.company_commission_rate, 'company_commission', e.company_commission,
      'net_earning', e.net_earning, 'payout_status', e.payout_status,
      'settlement_status', e.settlement_status, 'payment_method', e.payment_method,
      'billable_seconds', e.billable_seconds, 'normal_seconds', e.normal_billable_seconds,
      'overtime_seconds', e.overtime_billable_seconds, 'created_at', e.created_at
    ) order by e.created_at desc), '[]'::jsonb)
    into v_earnings
    from public.srk_worker_earnings e
    where e.worker_id = v_worker.id
      and e.created_at >= v_from
      and e.created_at < v_until;

    select coalesce(jsonb_agg(jsonb_build_object(
      'payout_code', p.payout_code, 'requested_amount', p.requested_amount,
      'approved_amount', p.approved_amount, 'status', p.status,
      'payment_method', p.payment_method, 'payment_reference', p.payment_reference,
      'requested_at', p.requested_at, 'reviewed_at', p.reviewed_at, 'paid_at', p.paid_at,
      'admin_note', p.admin_note
    ) order by p.requested_at desc), '[]'::jsonb)
    into v_payouts
    from public.srk_worker_payout_requests p
    where p.worker_id = v_worker.id
      and p.requested_at >= v_from
      and p.requested_at < v_until;

    select coalesce(jsonb_agg(jsonb_build_object(
      'transaction_code', l.transaction_code, 'entry_type', l.entry_type,
      'amount', l.amount, 'balance_effect', l.balance_effect,
      'description', l.description, 'reference_id', l.reference_id, 'created_at', l.created_at
    ) order by l.created_at desc), '[]'::jsonb)
    into v_ledger
    from public.srk_worker_wallet_ledger l
    where l.worker_id = v_worker.id
      and l.created_at >= v_from
      and l.created_at < v_until;

    select coalesce(jsonb_agg(jsonb_build_object(
      'complaint_id', c.id, 'booking_id', c.booking_id, 'category', c.category,
      'description', c.description, 'status', c.status, 'admin_note', c.admin_note,
      'reporter_role', c.reporter_role, 'created_at', c.created_at,
      'resolved_at', c.resolved_at
    ) order by c.created_at desc), '[]'::jsonb)
    into v_complaints
    from public.srk_booking_complaints c
    where (c.reported_to_worker_id = v_worker.id
       or c.reported_by_user_id = v_user_id
       or c.reported_to_user_id = v_user_id)
      and c.created_at >= v_from
      and c.created_at < v_until;


    select coalesce(jsonb_agg(jsonb_build_object(
      'document_id',d.id,'document_type',d.document_type,'file_name',d.file_name,
      'mime_type',d.mime_type,'file_size_bytes',d.file_size_bytes,
      'review_status',d.review_status,'admin_note',d.admin_note,
      'created_at',d.created_at,'reviewed_at',d.reviewed_at,'storage_path',d.storage_path
    ) order by d.created_at desc),'[]'::jsonb)
    into v_documents
    from public.srk_worker_documents d
    where d.worker_id=v_worker.id
       or d.application_id in (select a.id from public.srk_worker_applications a where a.user_id=v_user_id);

  else
    select * into v_customer
    from public.srk_customer_profiles
    where upper(customer_code) = upper(btrim(p_id_number))
    limit 1;

    if found then
      v_person_type := 'customer';
      v_person_id := v_customer.id;
      v_user_id := v_customer.user_id;
      v_person := jsonb_build_object(
        'id', v_customer.id, 'code', v_customer.customer_code, 'type', 'customer',
        'name', v_customer.full_name, 'phone', v_customer.phone, 'email', v_customer.email,
        'account_status', v_customer.account_status, 'created_at', v_customer.created_at,
        'updated_at', v_customer.updated_at
      );

      select coalesce(jsonb_agg(jsonb_build_object(
        'booking_id', b.id, 'order_number', b.order_number, 'service', b.service_type,
        'state', b.state, 'district', b.district, 'status', b.status,
        'payment_status', b.payment_status, 'payment_method', b.payment_method,
        'amount_paid', b.amount_paid, 'created_at', b.created_at,
        'preferred_date', b.preferred_date, 'preferred_time', b.preferred_time,
        'work_started_at', b.work_started_at, 'completed_at', b.customer_completed_at
      ) order by b.created_at desc), '[]'::jsonb)
      into v_bookings
      from public.service_bookings b
      where (b.customer_id = v_customer.id or b.customer_user_id = v_customer.user_id)
        and b.created_at >= v_from
        and b.created_at < v_until;

      select coalesce(jsonb_agg(jsonb_build_object(
        'complaint_id', c.id, 'booking_id', c.booking_id, 'category', c.category,
        'description', c.description, 'status', c.status, 'admin_note', c.admin_note,
        'created_at', c.created_at, 'resolved_at', c.resolved_at
      ) order by c.created_at desc), '[]'::jsonb)
      into v_complaints
      from public.srk_booking_complaints c
      where (c.customer_user_id = v_customer.user_id or c.reported_by_user_id = v_customer.user_id)
        and c.created_at >= v_from
        and c.created_at < v_until;
    else
      select * into v_staff
      from public.srk_staff_profiles
      where upper(staff_code) = upper(btrim(p_id_number))
      limit 1;

      if not found then
        raise exception 'No person found for this ID number' using errcode='P0002';
      end if;

      v_person_type := 'staff';
      v_person_id := v_staff.id;
      v_user_id := v_staff.user_id;
      v_person := jsonb_build_object(
        'id',v_staff.id,'code',v_staff.staff_code,'type','staff',
        'name',v_staff.full_name,'phone',v_staff.phone,'email',v_staff.email,
        'date_of_birth',v_staff.date_of_birth,'gender',v_staff.gender,'address',v_staff.address,
        'emergency_contact_name',v_staff.emergency_contact_name,
        'emergency_contact_phone',v_staff.emergency_contact_phone,
        'department_id',v_staff.department_id,'designation_id',v_staff.designation_id,
        'manager_staff_id',v_staff.manager_staff_id,'employment_type',v_staff.employment_type,
        'joining_date',v_staff.joining_date,'employment_status',v_staff.employment_status,
        'probation_end_date',v_staff.probation_end_date,'notice_period_days',v_staff.notice_period_days,
        'exit_date',v_staff.exit_date,'exit_reason',v_staff.exit_reason,'notes',v_staff.notes,
        'created_at',v_staff.created_at,'updated_at',v_staff.updated_at
      );

      select coalesce(jsonb_agg(jsonb_build_object(
        'document_id',d.id,'document_type',d.document_type,'file_name',d.original_file_name,
        'verification_status',d.verification_status,'created_at',d.created_at,
        'verified_at',d.verified_at,'storage_path',d.storage_path
      ) order by d.created_at desc),'[]'::jsonb)
      into v_documents
      from public.srk_staff_documents d where d.staff_id=v_staff.id;

      select coalesce(jsonb_agg(jsonb_build_object(
        'entity_type', a.entity_type, 'entity_id', a.entity_id, 'booking_id', a.booking_id,
        'action', a.action, 'actor_role', a.actor_role, 'changed_fields', a.changed_fields,
        'before_data', a.before_data, 'after_data', a.after_data, 'created_at', a.created_at
      ) order by a.created_at desc), '[]'::jsonb)
      into v_activity
      from public.srk_admin_audit_events a
      where a.actor_user_id = v_staff.user_id
        and a.created_at >= v_from
        and a.created_at < v_until;
    end if;
  end if;

  select count(*) filter(where coalesce(x.item->>'assignment_status',x.item->>'status')='completed'),
         count(*) filter(where coalesce(x.item->>'assignment_status',x.item->>'status') in ('cancelled','rejected')),
         count(*) filter(where x.item->>'assignment_status' in ('rejected','expired','released'))
    into v_completed_count,v_cancelled_count,v_rejected_count
  from jsonb_array_elements(v_bookings) as x(item);

  if v_completed_count>0 then
    v_strengths:=v_strengths||jsonb_build_array('इस अवधि में '||v_completed_count::text||' काम पूरे होने का रिकॉर्ड दर्ज है।');
  end if;
  if v_cancelled_count>0 then
    v_improvements:=v_improvements||jsonb_build_array('इस अवधि में '||v_cancelled_count::text||' रद्द/अस्वीकृत रिकॉर्ड हैं; कारण और संबंधित घटना की समीक्षा करें।');
  end if;
  if v_rejected_count>0 then
    v_improvements:=v_improvements||jsonb_build_array('कुछ Work Offers अस्वीकार/रिलीज़ हुए; Offer और उपलब्धता इतिहास की समीक्षा करें।');
  end if;
  if jsonb_array_length(v_complaints)>0 then
    v_improvements:=v_improvements||jsonb_build_array(jsonb_array_length(v_complaints)::text||' शिकायत/विवाद रिकॉर्ड मिले; Admin निर्णय और साक्ष्य की समीक्षा आवश्यक है।');
  end if;
  if jsonb_array_length(v_documents)=0 and v_person_type in ('technician','helper','staff') then
    v_improvements:=v_improvements||jsonb_build_array('इस अवधि की रिपोर्ट में कोई दस्तावेज़ रिकॉर्ड नहीं मिला; इसका अर्थ यह नहीं कि दस्तावेज़ कभी जमा नहीं हुए।');
  end if;
  if v_person_type='staff' and jsonb_array_length(v_activity)=0 then
    v_insights:=v_insights||jsonb_build_array('इस अवधि में Staff/Admin Audit Activity रिकॉर्ड नहीं मिला; निष्कर्ष निकालने के लिए पर्याप्त डेटा नहीं है।');
  end if;
  if jsonb_array_length(v_sessions)>0 then
    v_insights:=v_insights||jsonb_build_array(jsonb_array_length(v_sessions)::text||' Work Session रिकॉर्ड मिले; वास्तविक काम और Pause समय की समीक्षा की जा सकती है।');
  end if;

  v_summary := jsonb_build_object(
    'booking_count', jsonb_array_length(v_bookings),
    'completed_count',v_completed_count,
    'cancelled_or_rejected_count',v_cancelled_count,
    'offer_rejected_or_released_count',v_rejected_count,
    'work_session_count', jsonb_array_length(v_sessions),
    'earning_count', jsonb_array_length(v_earnings),
    'payout_count', jsonb_array_length(v_payouts),
    'complaint_count', jsonb_array_length(v_complaints),
    'document_count',jsonb_array_length(v_documents),
    'activity_count', jsonb_array_length(v_activity)
  );
  v_performance:=jsonb_build_object('strengths',v_strengths,'insights',v_insights,'improvement_areas',v_improvements);

  insert into srk_private.admin_person_history_access_log(
    admin_user_id, person_type, person_id, person_code, from_date, to_date
  ) values (auth.uid(), v_person_type, v_person_id, v_person->>'code', p_from_date, p_to_date);

  return jsonb_build_object(
    'person', v_person,
    'period', jsonb_build_object('from', p_from_date, 'to', p_to_date),
    'summary', v_summary,
    'bookings', v_bookings,
    'work_sessions', v_sessions,
    'earnings', v_earnings,
    'payouts', v_payouts,
    'ledger', v_ledger,
    'complaints', v_complaints,
    'admin_activity', v_activity,
    'documents',v_documents,
    'performance',v_performance,
    'generated_at', clock_timestamp(),
    'data_notes', jsonb_build_array(
      'रिपोर्ट में केवल चुनी गई अवधि के रिकॉर्ड शामिल हैं।',
      'जो जानकारी सिस्टम में दर्ज नहीं है, उसे अनुमान से नहीं भरा गया है।'
    )
  );
end;
$function$;

create or replace function srk_private.get_admin_category_skill_counts()
returns table(
  category_id uuid,
  category_name text,
  worker_type text,
  total_skill_holders bigint,
  pending_skill_holders bigint,
  approved_skill_holders bigint,
  active_skill_holders bigint,
  currently_working bigint
)
language plpgsql
stable
security definer
set search_path = pg_catalog, public, auth, srk_private
as $function$
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'Main Admin permission required' using errcode='42501';
  end if;

  return query
  select c.id, c.category_name, w.worker_type,
    count(distinct w.id)::bigint,
    (count(distinct w.id) filter (where ws.verification_status in ('pending','submitted','under_review')))::bigint,
    (count(distinct w.id) filter (where ws.verification_status in ('approved','verified')))::bigint,
    (count(distinct w.id) filter (where ws.verification_status in ('approved','verified') and w.is_active))::bigint,
    (count(distinct w.id) filter (where exists (
      select 1
      from public.srk_booking_workers bw
      join public.service_bookings b on b.id = bw.booking_id
      where bw.worker_id = w.id
        and bw.assignment_status in ('accepted','on_the_way','arrived','working','in_progress')
        and b.status not in ('completed','cancelled','rejected')
    )))::bigint
  from public.srk_service_categories c
  cross join (values ('technician'::text),('helper'::text)) as roles(worker_type)
  left join public.srk_service_types st on st.category_id = c.id and st.is_active
  left join public.srk_service_skills sk on sk.service_type_id = st.id and sk.is_active
  left join public.srk_worker_skills ws on ws.skill_id = sk.id
  left join public.srk_worker_profiles w on w.id = ws.worker_id and w.worker_type = roles.worker_type
  where c.is_active
  group by c.id, c.category_name, c.sort_order, roles.worker_type
  order by c.sort_order, roles.worker_type;
end;
$function$;

revoke all on function srk_private.get_admin_person_history(text,date,date) from public, anon;
revoke all on function srk_private.get_admin_category_skill_counts() from public, anon;
grant usage on schema srk_private to authenticated;
grant execute on function srk_private.get_admin_person_history(text,date,date) to authenticated;
grant execute on function srk_private.get_admin_category_skill_counts() to authenticated;

create or replace function public.srk_admin_get_person_history(
  p_id_number text,
  p_from_date date,
  p_to_date date
) returns jsonb
language sql
volatile
security invoker
set search_path = pg_catalog, public
as $function$
  select srk_private.get_admin_person_history(p_id_number, p_from_date, p_to_date);
$function$;

create or replace function public.srk_admin_get_category_skill_counts()
returns table(
  category_id uuid,
  category_name text,
  worker_type text,
  total_skill_holders bigint,
  pending_skill_holders bigint,
  approved_skill_holders bigint,
  active_skill_holders bigint,
  currently_working bigint
)
language sql
stable
security invoker
set search_path = pg_catalog, public
as $function$
  select * from srk_private.get_admin_category_skill_counts();
$function$;

revoke all on function public.srk_admin_get_person_history(text,date,date) from public, anon;
revoke all on function public.srk_admin_get_category_skill_counts() from public, anon;
grant execute on function public.srk_admin_get_person_history(text,date,date) to authenticated;
grant execute on function public.srk_admin_get_category_skill_counts() to authenticated;
