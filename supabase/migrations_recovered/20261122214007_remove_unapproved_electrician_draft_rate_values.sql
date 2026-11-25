
update public.srk_service_rates r
set technician_hourly_rate=null,
    helper_hourly_rate=null
from public.srk_service_categories c,
     public.srk_skill_levels sl
where r.category_id=c.id
  and r.skill_level_id=sl.id
  and c.category_code='electrician'
  and sl.level_code in ('basic','residential_office')
  and r.rate_status='draft'
  and (r.technician_hourly_rate is not null or r.helper_hourly_rate is not null);
