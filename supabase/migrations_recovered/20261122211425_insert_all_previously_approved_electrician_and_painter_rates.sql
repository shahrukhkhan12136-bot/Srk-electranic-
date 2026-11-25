
insert into public.srk_service_rates(
 category_id,service_type_id,skill_level_id,
 technician_hourly_rate,helper_hourly_rate,rate_status,
 effective_from,change_reason
)
select c.id,null,l.id,v.technician_rate,v.helper_rate,'approved',
       clock_timestamp(),'Previously user-approved SRK ELECTRONIC hourly rate; helper optional as specified'
from (values
 ('electrician','basic',100::numeric,0::numeric),
 ('electrician','residential_office',125::numeric,75::numeric),
 ('painter','basic',100::numeric,50::numeric),
 ('painter','expert',150::numeric,75::numeric),
 ('painter','master',225::numeric,100::numeric)
) as v(category_code,level_code,technician_rate,helper_rate)
join public.srk_service_categories c on c.category_code=v.category_code
join public.srk_skill_levels l on l.category_id=c.id and l.level_code=v.level_code
where not exists(
 select 1 from public.srk_service_rates r
 where r.category_id=c.id and r.skill_level_id=l.id
   and r.service_type_id is null and r.rate_status='approved'
);
