-- Confirmed SRK ELECTRONIC service rates only.
-- Conflicting/unallocated prices remain pending and are never customer-bookable.
INSERT INTO public.srk_service_rates
(service_code,level_code,level_label,technician_hourly_paise,helper_hourly_paise,fixed_labour_paise,rate_version,status)
VALUES
 ('residential_wiring','basic','Basic',10000,0,NULL,'SRK-ELECTRICIAN-2026-11-22-V1','active'),
 ('residential_wiring','expert','Expert Residential',12500,6250,NULL,'SRK-ELECTRICIAN-2026-11-22-V1','active'),
 ('residential_wiring','master','Master Electrician',70000,20000,NULL,'SRK-ELECTRICIAN-2026-11-22-V1','active'),
 ('factory_wiring','expert','Expert Factory / Industrial Wiring',30000,12500,NULL,'SRK-ELECTRICIAN-2026-11-22-V1','active'),
 ('factory_wiring','master','Master Electrician',70000,20000,NULL,'SRK-ELECTRICIAN-2026-11-22-V1','active'),

 ('interior_painting','basic','Basic Painter',8750,0,NULL,'SRK-PAINTER-2026-11-22-V1','active'),
 ('interior_painting','expert','Expert Painter',11250,7500,NULL,'SRK-PAINTER-2026-11-22-V1','active'),
 ('interior_painting','master','Master / Commercial Painter',15000,10000,NULL,'SRK-PAINTER-2026-11-22-V1','active'),
 ('exterior_painting','basic','Basic Painter',8750,0,NULL,'SRK-PAINTER-2026-11-22-V1','active'),
 ('exterior_painting','expert','Expert Painter',11250,7500,NULL,'SRK-PAINTER-2026-11-22-V1','active'),
 ('exterior_painting','master','Master / Commercial Painter',15000,10000,NULL,'SRK-PAINTER-2026-11-22-V1','active'),

 ('fridge_technician','standard','Fridge Technician + Helper',15000,7500,NULL,'SRK-FRIDGE-2026-11-22-V1','active'),

 ('motor_winding','hp_0_5','0.5 HP',NULL,0,50000,'SRK-MOTOR-PUMP-2026-11-22-V1','active'),
 ('motor_winding','hp_1','1 HP',NULL,0,60000,'SRK-MOTOR-PUMP-2026-11-22-V1','active'),
 ('motor_winding','hp_1_5','1.5 HP',NULL,0,70000,'SRK-MOTOR-PUMP-2026-11-22-V1','active'),
 ('motor_winding','hp_2','2 HP',NULL,0,80000,'SRK-MOTOR-PUMP-2026-11-22-V1','active'),
 ('motor_winding','hp_3','3 HP',NULL,0,90000,'SRK-MOTOR-PUMP-2026-11-22-V1','active'),
 ('motor_winding','hp_5','5 HP',NULL,0,100000,'SRK-MOTOR-PUMP-2026-11-22-V1','active'),
 ('motor_winding','hp_7_5','7.5 HP',NULL,0,110000,'SRK-MOTOR-PUMP-2026-11-22-V1','active'),
 ('motor_winding','hp_10','10 HP',NULL,0,120000,'SRK-MOTOR-PUMP-2026-11-22-V1','active'),
 ('motor_winding','hp_15','15 HP',NULL,0,130000,'SRK-MOTOR-PUMP-2026-11-22-V1','active'),
 ('motor_winding','hp_20','20 HP',NULL,0,140000,'SRK-MOTOR-PUMP-2026-11-22-V1','active'),

 ('cooler_repair','standard','Cooler Repair / per cooler',NULL,0,50000,'SRK-COOLER-2026-11-22-V1','active'),
 ('cooler_motor_winding','hp_0_5','0.5 HP',NULL,0,50000,'SRK-COOLER-2026-11-22-V1','active'),
 ('cooler_motor_winding','hp_1','1 HP',NULL,0,60000,'SRK-COOLER-2026-11-22-V1','active'),
 ('cooler_motor_winding','hp_1_5','1.5 HP',NULL,0,70000,'SRK-COOLER-2026-11-22-V1','active'),
 ('cooler_motor_winding','hp_2','2 HP',NULL,0,80000,'SRK-COOLER-2026-11-22-V1','active'),
 ('cooler_motor_winding','hp_3','3 HP',NULL,0,90000,'SRK-COOLER-2026-11-22-V1','active'),
 ('cooler_motor_winding','hp_5','5 HP',NULL,0,100000,'SRK-COOLER-2026-11-22-V1','active'),
 ('cooler_motor_winding','hp_7_5','7.5 HP',NULL,0,110000,'SRK-COOLER-2026-11-22-V1','active'),
 ('cooler_motor_winding','hp_10','10 HP',NULL,0,120000,'SRK-COOLER-2026-11-22-V1','active'),
 ('cooler_motor_winding','hp_15','15 HP',NULL,0,130000,'SRK-COOLER-2026-11-22-V1','active'),
 ('cooler_motor_winding','hp_20','20 HP',NULL,0,140000,'SRK-COOLER-2026-11-22-V1','active')
ON CONFLICT(service_code,level_code,rate_version) DO NOTHING;

-- AC Installation and AC Repair have an approved combined team rate of ₹437/hour,
-- but the Technician/Helper pay split is not specified. Keep explicit pending rows.
INSERT INTO public.srk_service_rates
(service_code,level_code,level_label,technician_hourly_paise,helper_hourly_paise,fixed_labour_paise,rate_version,status)
VALUES
 ('ac_installation','team','AC Technician + Helper Team ₹437/hour — Pay Split Pending',NULL,0,NULL,'SRK-AC-2026-11-22-PENDING','pending_admin_configuration'),
 ('ac_repair','team','AC Technician + Helper Team ₹437/hour — Pay Split Pending',NULL,0,NULL,'SRK-AC-2026-11-22-PENDING','pending_admin_configuration'),
 ('pump_repair','standard','Pump Repair — Admin Rate Pending',NULL,0,NULL,'SRK-PUMP-2026-11-22-PENDING','pending_admin_configuration'),
 ('residential_wiring','basic_helper','Basic Electrician + Helper — Helper Rate Pending',10000,0,NULL,'SRK-ELECTRICIAN-2026-11-22-PENDING','pending_admin_configuration'),
 ('motor_winding','hp_over_20','Above 20 HP — Admin Rate Pending',NULL,0,NULL,'SRK-MOTOR-PUMP-2026-11-22-PENDING','pending_admin_configuration'),
 ('cooler_motor_winding','hp_over_20','Above 20 HP — Admin Rate Pending',NULL,0,NULL,'SRK-COOLER-2026-11-22-PENDING','pending_admin_configuration')
ON CONFLICT(service_code,level_code,rate_version) DO NOTHING;
