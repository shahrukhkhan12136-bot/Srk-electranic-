
DO $$
DECLARE
  v_count integer;
BEGIN
  UPDATE public.srk_service_rates r
  SET technician_hourly_rate = CASE
        WHEN t.service_code = 'basic_electrical' THEN 100
        WHEN t.service_code = 'residential_office_wiring' THEN 150
      END,
      helper_hourly_rate = CASE
        WHEN t.service_code = 'basic_electrical' THEN NULL
        WHEN t.service_code = 'residential_office_wiring' THEN 100
      END,
      rate_status = 'approved',
      change_reason = CASE
        WHEN t.service_code = 'basic_electrical'
          THEN 'User-approved 2026-11-23: Electrician Basic Technician ₹100/hour; no Helper.'
        WHEN t.service_code = 'residential_office_wiring'
          THEN 'User-approved 2026-11-23: Residential/Office Wiring Technician ₹150/hour and Helper ₹100/hour.'
      END
  FROM public.srk_service_types t
  JOIN public.srk_service_categories c ON c.id = t.category_id
  JOIN public.srk_skill_levels l ON l.category_id = c.id
  WHERE r.service_type_id = t.id
    AND r.skill_level_id = l.id
    AND c.category_code = 'electrician'
    AND ((t.service_code = 'basic_electrical' AND l.level_code = 'basic')
      OR (t.service_code = 'residential_office_wiring' AND l.level_code = 'residential_office'))
    AND r.rate_status = 'draft';
  GET DIAGNOSTICS v_count = ROW_COUNT;
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'Expected to approve exactly 2 Electrician rates; updated %', v_count;
  END IF;
END $$;