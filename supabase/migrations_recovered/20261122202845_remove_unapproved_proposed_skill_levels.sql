
delete from public.srk_skill_levels l
using public.srk_service_categories c
where l.category_id=c.id
  and ((c.category_code='motor_pump_technician' and l.level_code in ('basic','expert','master'))
    or (c.category_code='cooler_technician' and l.level_code in ('basic','expert','master'))
    or (c.category_code='ac_fridge_technician' and l.level_code='fridge_technician'))
  and not exists(select 1 from public.srk_worker_skills ws where ws.skill_level_id=l.id)
  and not exists(select 1 from public.srk_service_rates r where r.skill_level_id=l.id);
