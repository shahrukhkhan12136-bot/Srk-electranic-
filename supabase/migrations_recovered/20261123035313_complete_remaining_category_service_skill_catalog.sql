
with catalog(category_code,service_code,service_name,sort_order,admin_note) as (
 values
 ('plumber','plumbing_repair_maintenance','Plumbing Repair & Maintenance',1,'Approved service catalog seed; hourly level rates remain governed by existing approved plumber rate master.'),
 ('plumber','bathroom_kitchen_plumbing','Bathroom & Kitchen Plumbing',2,'Common residential plumbing service.'),
 ('plumber','water_tank_pipeline','Water Tank & Pipeline Work',3,'Water supply, storage and pipeline work.'),
 ('plumber','drainage_blockage','Drainage & Blockage Work',4,'Drainage and blockage troubleshooting.'),
 ('painter','interior_painting','Interior Painting',1,'Common residential/commercial painting service.'),
 ('painter','exterior_painting','Exterior Painting',2,'Exterior wall and weather-facing painting.'),
 ('painter','putty_primer_surface','Putty, Primer & Surface Preparation',3,'Surface preparation before finishing coats.'),
 ('painter','texture_polish_finish','Texture, Polish & Special Finish',4,'Decorative and specialist surface finishing.'),
 ('painter','industrial_painting','Industrial Painting',5,'Industrial structures and equipment painting.'),
 ('ac_fridge_technician','ac_repair','AC Repair',1,'Existing approved service; skills added.'),
 ('ac_fridge_technician','ac_installation','AC Installation',2,'Existing approved service; skills added.'),
 ('ac_fridge_technician','fridge_repair','Fridge Repair',3,'Existing approved service; skills added.'),
 ('motor_pump_technician','motor_repair','Motor Repair',1,'Proposed option accepted for catalog setup; rate remains unapproved.'),
 ('motor_pump_technician','pump_repair','Pump Repair',2,'Proposed option accepted for catalog setup; rate remains unapproved.'),
 ('motor_pump_technician','motor_winding','Motor Winding',3,'Proposed option accepted for catalog setup; rate remains unapproved.'),
 ('motor_pump_technician','motor_pump_installation','Motor & Pump Installation',4,'Additional combined installation service; rate remains unapproved.'),
 ('cooler_technician','cooler_repair','Cooler Repair',1,'Proposed option accepted for catalog setup; rate remains unapproved.'),
 ('cooler_technician','cooler_service','Cooler Service',2,'Proposed option accepted for catalog setup; rate remains unapproved.'),
 ('cooler_technician','cooler_motor_repair','Cooler Motor Repair',3,'Proposed option accepted for catalog setup; rate remains unapproved.'),
 ('cooler_technician','cooler_pump_repair','Cooler Pump Repair',4,'Proposed option accepted for catalog setup; rate remains unapproved.')
)
insert into public.srk_service_types(category_id,service_code,service_name,is_active,sort_order,admin_note)
select c.id,x.service_code,x.service_name,true,x.sort_order,x.admin_note
from catalog x join public.srk_service_categories c on c.category_code=x.category_code
on conflict (service_code) do update set service_name=excluded.service_name,is_active=true,sort_order=excluded.sort_order,admin_note=excluded.admin_note,updated_at=now();

with skill_catalog(category_code,service_code,skill_code,skill_name,sort_order) as (
 values
 -- Plumber
 ('plumber','plumbing_repair_maintenance','tap_mixer_repair','Tap & Mixer Repair',1),
 ('plumber','plumbing_repair_maintenance','toilet_flush_repair','Toilet & Flush Repair',2),
 ('plumber','plumbing_repair_maintenance','leakage_detection_repair','Water Leakage Detection & Repair',3),
 ('plumber','plumbing_repair_maintenance','washbasin_sink_repair','Washbasin & Sink Repair',4),
 ('plumber','bathroom_kitchen_plumbing','bathroom_fitting_installation','Bathroom Fittings Installation',1),
 ('plumber','bathroom_kitchen_plumbing','kitchen_sink_fittings','Kitchen Sink & Fittings',2),
 ('plumber','bathroom_kitchen_plumbing','shower_geyser_connections','Shower & Geyser Plumbing Connections',3),
 ('plumber','water_tank_pipeline','water_tank_installation_repair','Water Tank Installation & Repair',1),
 ('plumber','water_tank_pipeline','water_supply_pipeline','Water Supply Pipeline Work',2),
 ('plumber','water_tank_pipeline','pipe_fitting_replacement','Pipe Fitting & Replacement',3),
 ('plumber','drainage_blockage','drain_blockage_removal','Drain Blockage Removal',1),
 ('plumber','drainage_blockage','drainage_line_repair','Drainage Line Repair',2),
 ('plumber','drainage_blockage','sewer_line_troubleshooting','Sewer Line Troubleshooting',3),
 -- Painter
 ('painter','interior_painting','interior_wall_painting','Interior Wall Painting',1),
 ('painter','interior_painting','ceiling_painting','Ceiling Painting',2),
 ('painter','interior_painting','door_window_painting','Door & Window Painting',3),
 ('painter','exterior_painting','exterior_wall_painting','Exterior Wall Painting',1),
 ('painter','exterior_painting','weatherproof_coating','Weatherproof Coating Application',2),
 ('painter','exterior_painting','building_facade_painting','Building Facade Painting',3),
 ('painter','putty_primer_surface','wall_putty_application','Wall Putty Application',1),
 ('painter','putty_primer_surface','sanding_surface_smoothing','Sanding & Surface Smoothing',2),
 ('painter','putty_primer_surface','primer_application','Primer Application',3),
 ('painter','texture_polish_finish','texture_paint_application','Texture Paint Application',1),
 ('painter','texture_polish_finish','wood_polish_finishing','Wood Polish & Finishing',2),
 ('painter','texture_polish_finish','decorative_special_finish','Decorative & Special Finish',3),
 ('painter','industrial_painting','industrial_structure_painting','Industrial Structure Painting',1),
 ('painter','industrial_painting','metal_surface_coating','Metal Surface Coating',2),
 ('painter','industrial_painting','protective_anticorrosive_coating','Protective & Anti-corrosive Coating',3),
 -- AC
 ('ac_fridge_technician','ac_repair','ac_cooling_fault_diagnosis','AC Cooling Fault Diagnosis',1),
 ('ac_fridge_technician','ac_repair','ac_gas_leak_check','AC Gas Leakage Inspection',2),
 ('ac_fridge_technician','ac_repair','ac_filter_coil_cleaning','AC Filter & Coil Cleaning',3),
 ('ac_fridge_technician','ac_repair','ac_drainage_repair','AC Drainage & Water Leakage Repair',4),
 ('ac_fridge_technician','ac_repair','ac_electrical_control_fault','AC Electrical & Control Fault Diagnosis',5),
 ('ac_fridge_technician','ac_repair','ac_compressor_diagnosis','AC Compressor Diagnosis',6),
 ('ac_fridge_technician','ac_installation','split_ac_installation','Split AC Installation',1),
 ('ac_fridge_technician','ac_installation','window_ac_installation','Window AC Installation',2),
 ('ac_fridge_technician','ac_installation','ac_uninstallation_reinstallation','AC Uninstallation & Reinstallation',3),
 ('ac_fridge_technician','ac_installation','ac_copper_drain_piping','AC Copper & Drain Piping',4),
 ('ac_fridge_technician','ac_installation','ac_vacuum_commissioning','AC Vacuuming & Commissioning',5),
 ('ac_fridge_technician','fridge_repair','fridge_not_cooling_diagnosis','Fridge Not Cooling Diagnosis',1),
 ('ac_fridge_technician','fridge_repair','fridge_compressor_repair','Fridge Compressor Diagnosis & Repair',2),
 ('ac_fridge_technician','fridge_repair','fridge_thermostat_sensor','Fridge Thermostat & Sensor Repair',3),
 ('ac_fridge_technician','fridge_repair','fridge_defrost_system_repair','Fridge Defrost System Repair',4),
 ('ac_fridge_technician','fridge_repair','fridge_door_gasket_repair','Fridge Door Gasket Repair',5),
 ('ac_fridge_technician','fridge_repair','fridge_electrical_fault','Fridge Electrical Fault Diagnosis',6),
 -- Motor and pump
 ('motor_pump_technician','motor_repair','single_phase_motor_repair','Single-phase Motor Repair',1),
 ('motor_pump_technician','motor_repair','three_phase_motor_repair','Three-phase Motor Repair',2),
 ('motor_pump_technician','motor_repair','motor_bearing_replacement','Motor Bearing Replacement',3),
 ('motor_pump_technician','motor_repair','motor_overheating_fault','Motor Overheating & Fault Diagnosis',4),
 ('motor_pump_technician','pump_repair','water_pump_repair','Water Pump Repair',1),
 ('motor_pump_technician','pump_repair','submersible_pump_repair','Submersible Pump Repair',2),
 ('motor_pump_technician','pump_repair','pump_seal_impeller_repair','Pump Seal & Impeller Repair',3),
 ('motor_pump_technician','pump_repair','pump_pressure_flow_fault','Pump Pressure & Flow Fault Diagnosis',4),
 ('motor_pump_technician','motor_winding','single_phase_motor_winding','Single-phase Motor Winding',1),
 ('motor_pump_technician','motor_winding','three_phase_motor_winding','Three-phase Motor Winding',2),
 ('motor_pump_technician','motor_winding','coil_rewinding_insulation','Coil Rewinding & Insulation',3),
 ('motor_pump_technician','motor_pump_installation','domestic_motor_pump_installation','Domestic Motor & Pump Installation',1),
 ('motor_pump_technician','motor_pump_installation','industrial_motor_pump_installation','Industrial Motor & Pump Installation',2),
 ('motor_pump_technician','motor_pump_installation','motor_pump_alignment_connection','Motor/Pump Alignment & Connection',3),
 -- Cooler
 ('cooler_technician','cooler_repair','cooler_body_repair','Cooler Body Repair',1),
 ('cooler_technician','cooler_repair','cooler_water_leakage_repair','Cooler Water Leakage Repair',2),
 ('cooler_technician','cooler_repair','cooler_airflow_fault','Cooler Airflow Fault Diagnosis',3),
 ('cooler_technician','cooler_service','cooler_cleaning_service','Cooler Cleaning & Service',1),
 ('cooler_technician','cooler_service','cooler_pad_replacement','Cooler Cooling Pad Replacement',2),
 ('cooler_technician','cooler_service','cooler_water_distribution_service','Cooler Water Distribution Service',3),
 ('cooler_technician','cooler_motor_repair','cooler_fan_motor_repair','Cooler Fan Motor Repair',1),
 ('cooler_technician','cooler_motor_repair','cooler_motor_bearing_replacement','Cooler Motor Bearing Replacement',2),
 ('cooler_technician','cooler_motor_repair','cooler_motor_wiring_fault','Cooler Motor Wiring Fault',3),
 ('cooler_technician','cooler_pump_repair','cooler_water_pump_repair','Cooler Water Pump Repair',1),
 ('cooler_technician','cooler_pump_repair','cooler_pump_blockage','Cooler Pump Blockage & Flow Fault',2),
 ('cooler_technician','cooler_pump_repair','cooler_pump_replacement','Cooler Pump Replacement',3)
)
insert into public.srk_service_skills(service_type_id,skill_code,skill_name,is_active,sort_order,admin_note)
select t.id,s.skill_code,s.skill_name,true,s.sort_order,'Catalog skill seed; does not itself authorize worker qualification or change approved rates.'
from skill_catalog s
join public.srk_service_categories c on c.category_code=s.category_code
join public.srk_service_types t on t.category_id=c.id and t.service_code=s.service_code
on conflict (skill_code) do update set service_type_id=excluded.service_type_id,skill_name=excluded.skill_name,is_active=true,sort_order=excluded.sort_order,updated_at=now();
