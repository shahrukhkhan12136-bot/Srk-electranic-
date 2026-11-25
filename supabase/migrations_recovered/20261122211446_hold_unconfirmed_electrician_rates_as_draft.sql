
update public.srk_service_rates r
set rate_status='draft',
    change_reason='Held as draft: current canonical checklist marks Electrician Basic and Residential/Office rates as pending confirmation; do not expose to customers until explicitly approved'
from public.srk_service_categories c
join public.srk_skill_levels l on l.category_id=c.id
where r.category_id=c.id and r.skill_level_id=l.id
  and c.category_code='electrician'
  and l.level_code in ('basic','residential_office')
  and r.service_type_id is null
  and r.change_reason='Previously user-approved SRK ELECTRONIC hourly rate; helper optional as specified';
