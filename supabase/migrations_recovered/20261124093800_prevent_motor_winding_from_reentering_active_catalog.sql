alter table public.srk_service_types
 add constraint srk_service_types_no_active_winding_check
 check (
  not is_active or not (
   service_code ~* 'wind|rewind'
   or service_name ~* 'wind|rewind|वाइंड|वाइन्ड'
  )
 );

CREATE OR REPLACE FUNCTION public.srk_admin_add_service_type(
 p_category_id uuid,p_service_code text,p_service_name text,p_sort_order integer,p_reason text
) RETURNS public.srk_service_types
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth'
AS $function$
declare v public.srk_service_types%rowtype;
begin
 if auth.uid() is null or not public.srk_has_admin_permission('catalog.manage') then
  raise exception 'Catalog management permission required';
 end if;
 if length(coalesce(p_reason,''))<10 then
  raise exception 'Reason must be at least 10 characters';
 end if;
 if p_service_code !~ '^[a-z][a-z0-9_]{1,59}$' or length(btrim(p_service_name)) not between 2 and 120 then
  raise exception 'Invalid service code or name';
 end if;
 if p_service_code ~* 'wind|rewind'
    or p_service_name ~* 'wind|rewind|वाइंड|वाइन्ड' then
  raise exception 'Motor Winding is permanently outside the SRK ELECTRONIC service catalog';
 end if;
 insert into public.srk_service_types(category_id,service_code,service_name,sort_order,is_active,admin_note)
 values(p_category_id,p_service_code,btrim(p_service_name),coalesce(p_sort_order,0),true,btrim(p_reason))
 returning * into v;
 return v;
end
$function$;

REVOKE ALL ON FUNCTION public.srk_admin_add_service_type(uuid,text,text,integer)
FROM PUBLIC,anon,authenticated;