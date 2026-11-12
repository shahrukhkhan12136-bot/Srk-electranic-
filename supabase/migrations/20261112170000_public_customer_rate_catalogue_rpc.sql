-- Public-safe read API for the currently effective customer-facing category rates.
-- The underlying catalogue remains inaccessible directly to anon/authenticated.
begin;

create or replace function public.srk_get_current_customer_rates()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $function$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'category_code', active.category_code,
        'category_label', active.category_label,
        'version', active.version,
        'hourly_rate', active.hourly_rate,
        'eight_hour_amount', round(active.hourly_rate * 8, 2),
        'effective_from', active.effective_from
      )
      order by case active.category_code
        when 'helper' then 1
        when 'ordinary' then 2
        when 'skilled' then 3
        when 'master' then 4
        else 5
      end
    ),
    '[]'::jsonb
  )
  from (
    select distinct on (c.category_code)
      c.category_code,c.category_label,c.version,c.hourly_rate,c.effective_from
    from public.srk_rate_catalogue c
    where c.effective_from <= current_date
    order by c.category_code,c.effective_from desc,c.version desc
  ) active;
$function$;

revoke all on function public.srk_get_current_customer_rates() from public;
revoke all on function public.srk_get_current_customer_rates() from anon,authenticated;
grant execute on function public.srk_get_current_customer_rates() to anon,authenticated;

commit;
