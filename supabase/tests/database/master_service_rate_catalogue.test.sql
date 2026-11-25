BEGIN;
SELECT plan(23);

SELECT has_table('public','srk_service_offerings','service offerings are separate from technician skills');
SELECT has_table('public','srk_service_rates','versioned Admin-controlled labour rates exist');
SELECT has_table('public','srk_service_rate_events','rate changes have an audit ledger');
SELECT has_column('public','service_bookings','srk_service_code','booking stores the selected service');
SELECT has_column('public','service_bookings','srk_rate_version_snapshot','booking stores the immutable rate version');
SELECT has_column('public','service_bookings','srk_technician_hourly_paise_snapshot','booking stores Technician hourly rate');
SELECT has_column('public','service_bookings','srk_helper_hourly_paise_snapshot','booking stores Helper hourly rate');
SELECT has_column('public','service_bookings','srk_fixed_labour_paise_snapshot','booking stores fixed labour price');
SELECT has_column('public','service_bookings','srk_service_quantity','booking stores fixed service quantity');
SELECT has_index('public','srk_service_rates','srk_service_rates_one_active_level_uidx',
  'only one active rate exists per service and level');
SELECT has_trigger('public','srk_service_rates','srk_guard_service_rate_history',
  'active and retired rate versions cannot be rewritten');
SELECT has_trigger('public','srk_service_rate_events','srk_service_rate_events_append_only',
  'rate audit history is append-only');

SELECT ok(
  has_function('public','srk_customer_get_service_rate',ARRAY['text','text'])
  AND has_function('public','srk_customer_list_active_service_rates',ARRAY[]::text[]),
  'customer rate lookup and active rate list RPCs exist'
);
SELECT ok(
  has_function('public','srk_admin_upsert_service_offering',ARRAY['text','text','text','text','text','text','boolean'])
  AND has_function('public','srk_admin_upsert_service_rate',
    ARRAY['text','text','text','bigint','bigint','bigint','text','text','timestamp with time zone','timestamp with time zone']),
  'Admin service and rate catalogue RPCs exist'
);
SELECT ok(
  has_function('public','srk_admin_list_service_rates',ARRAY[]::text[]),
  'Admin can review the complete rate catalogue and pending configurations'
);
SELECT ok(
  has_function_privilege('anon','public.srk_customer_list_active_service_rates()','EXECUTE')
  AND has_function_privilege('authenticated','public.srk_customer_list_active_service_rates()','EXECUTE')
  AND NOT has_function_privilege('anon','public.srk_customer_get_service_rate(text,text)','EXECUTE')
  AND has_function_privilege('service_role','public.srk_customer_get_service_rate(text,text)','EXECUTE'),
  'public can read only active rate list; booking backend resolves a selected rate'
);
SELECT ok(
  has_function_privilege('authenticated','public.srk_admin_upsert_service_rate(text,text,text,bigint,bigint,bigint,text,text,timestamptz,timestamptz)','EXECUTE')
  AND NOT has_function_privilege('anon','public.srk_admin_upsert_service_rate(text,text,text,bigint,bigint,bigint,text,text,timestamptz,timestamptz)','EXECUTE'),
  'Admin rate mutation RPC is not available to anonymous users'
);
SELECT ok(
  (SELECT relrowsecurity FROM pg_class WHERE oid='public.srk_service_rates'::regclass)
  AND (SELECT relrowsecurity FROM pg_class WHERE oid='public.srk_service_offerings'::regclass),
  'rate and service catalogue tables have RLS enabled'
);
SELECT ok(
  NOT EXISTS(SELECT 1 FROM public.srk_service_rates r
    LEFT JOIN public.srk_service_offerings o ON o.service_code=r.service_code
    WHERE o.service_code IS NULL)
  AND NOT EXISTS(SELECT 1 FROM public.srk_service_rates
    WHERE service_code IN ('residential_wiring','factory_wiring','interior_painting','exterior_painting',
      'ac_technician','ac_installation','ac_repair','fridge_technician','motor_winding','pump_repair','cooler_repair','cooler_motor_winding')
      AND status='active'),
  'rates are only created for exact existing offerings; unconfigured services remain fail-closed'
);
SELECT ok(
  (SELECT count(*) FROM public.srk_customer_list_active_service_rates()) =
  (SELECT count(*) FROM public.srk_service_rates r
    JOIN public.srk_service_offerings o ON o.service_code=r.service_code AND o.is_active
    WHERE r.status='active' AND r.effective_from<=clock_timestamp()
      AND (r.effective_to IS NULL OR r.effective_to>clock_timestamp())),
  'customer rate list exposes exactly the configured active offering rates'
);
SELECT ok(
  NOT EXISTS(
    SELECT 1 FROM public.srk_service_offerings o
    JOIN public.srk_service_skills s ON s.skill_code=o.skill_code
    WHERE (s.display_name ILIKE '%winding%' OR s.display_name ILIKE '%rewinding%') AND o.is_active
  ),
  'all winding offerings are inactive while historical skill rows are preserved'
);
SELECT ok(
  (SELECT count(*) FROM public.srk_service_offerings)=(SELECT count(*) FROM public.srk_service_skills)
  AND NOT EXISTS(
    SELECT 1 FROM public.srk_service_skills s
    LEFT JOIN public.srk_service_offerings o ON o.skill_code=s.skill_code
    WHERE o.skill_code IS NULL OR o.is_active IS DISTINCT FROM s.is_active
  ),
  'each skill has exactly one offering that preserves its active/inactive state'
);
SELECT ok(
  position('srk_service_category_code' in pg_get_constraintdef((
    SELECT oid FROM pg_constraint WHERE conname='service_bookings_srk_rate_snapshot_complete'
  )))>0,
  'new booking rate snapshot requires canonical service identity'
);

SELECT * FROM finish();
ROLLBACK;
