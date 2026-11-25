
-- Preserve Motor Winding history; remove it only from new active catalog use.
UPDATE public.srk_service_types
SET is_active=false,
    admin_note='User-confirmed: Motor Winding is outside SRK ELECTRONIC; no SRK booking, billing, payment, or commission.',
    updated_at=clock_timestamp()
WHERE service_code='motor_winding';

UPDATE public.srk_service_skills
SET is_active=false,
    admin_note='Deactivated because Motor Winding is outside SRK ELECTRONIC.',
    updated_at=clock_timestamp()
WHERE service_type_id=(SELECT id FROM public.srk_service_types WHERE service_code='motor_winding');

-- Motor/Pump pricing is checking, inspection and fitting only. Winding is not a separate SRK charge.
UPDATE public.srk_service_pricing_rules
SET winding_charged_separately=false,
    pricing_note='Checking, inspection and fitting only; exact approved HP-tier price; timer disabled. Motor winding is outside SRK ELECTRONIC.',
    change_reason='User reconfirmed 2026-11-23: winding is outside SRK.'
WHERE service_type_id IN (
  SELECT id FROM public.srk_service_types
  WHERE service_code IN ('motor_repair','pump_repair','motor_pump_installation')
) AND pricing_unit='motor_hp';

-- Add the user-confirmed 3 HP tier for each of the three motor/pump services.
INSERT INTO public.srk_service_pricing_hp_tiers(pricing_rule_id,motor_hp,fixed_price)
SELECT r.id,3.0,800
FROM public.srk_service_pricing_rules r
JOIN public.srk_service_types s ON s.id=r.service_type_id
WHERE s.service_code IN ('motor_repair','pump_repair','motor_pump_installation')
  AND r.pricing_unit='motor_hp'
ON CONFLICT (pricing_rule_id,motor_hp)
DO UPDATE SET fixed_price=EXCLUDED.fixed_price;

-- Apply the user-approved Fridge Repair hourly labour rates.
UPDATE public.srk_service_rates
SET technician_hourly_rate=200,
    helper_hourly_rate=120,
    rate_status='approved',
    effective_from=clock_timestamp(),
    effective_to=NULL,
    change_reason='User-approved 2026-11-23: Fridge Repair Technician ₹200/hour, Helper ₹120/hour.'
WHERE service_type_id=(SELECT id FROM public.srk_service_types WHERE service_code='fridge_repair');

INSERT INTO public.srk_service_rates(
  category_id,skill_level_id,service_type_id,
  technician_hourly_rate,helper_hourly_rate,rate_status,effective_from,change_reason
)
SELECT source.category_id,source.skill_level_id,
       (SELECT id FROM public.srk_service_types WHERE service_code='fridge_repair'),
       200,120,'approved',clock_timestamp(),
       'User-approved 2026-11-23: Fridge Repair Technician ₹200/hour, Helper ₹120/hour.'
FROM public.srk_service_rates source
WHERE source.service_type_id=(SELECT id FROM public.srk_service_types WHERE service_code='ac_repair')
  AND NOT EXISTS (
    SELECT 1 FROM public.srk_service_rates existing
    WHERE existing.service_type_id=(SELECT id FROM public.srk_service_types WHERE service_code='fridge_repair')
      AND existing.skill_level_id=source.skill_level_id
      AND existing.rate_status='approved'
      AND existing.effective_to IS NULL
  );

-- Persist the user-approved remaining operating criteria.
INSERT INTO public.srk_system_settings(setting_key,setting_value,admin_note)
VALUES
('max_matching_attempts','10'::jsonb,'User-approved maximum of 10 matching attempts per booking.'),
('ai_language_test_min_pass_rate_percent','90'::jsonb,'User-approved minimum overall pass rate for Indian-language AI test suite.'),
('ai_language_test_critical_failures_allowed','0'::jsonb,'User-approved: zero critical failures in AI language tests.'),
('receipt_pdf_fields',
 '["booking_id","customer_name","customer_phone","service_name","motor_hp","work_description","work_duration","labour_charges","payment_method","payment_status","receipt_date"]'::jsonb,
 'User-approved receipt contents; no material line or company commission.'),
('backup_policy',
 '{"database":"daily","storage_objects":"daily","retention_days":30,"restore_test":"regular","offsite_required":true}'::jsonb,
 'User-approved backup target policy. Actual offsite automation requires a configured destination and credentials; this setting alone does not create backups.')
ON CONFLICT(setting_key)
DO UPDATE SET setting_value=EXCLUDED.setting_value,
              admin_note=EXCLUDED.admin_note,
              updated_at=clock_timestamp();
