
create or replace function public.srk_admin_add_service_type(
 p_category_id uuid,p_service_code text,p_service_name text,p_sort_order integer default 0
) returns public.srk_service_types
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v public.srk_service_types%rowtype;
begin
  if not public.srk_has_admin_permission('catalog.manage') then raise exception 'Catalog management permission required'; end if;
  if p_service_code !~ '^[a-z][a-z0-9_]{1,59}$' or length(btrim(p_service_name)) not between 2 and 120 then
    raise exception 'Invalid service code or name';
  end if;
  insert into public.srk_service_types(category_id,service_code,service_name,sort_order,is_active)
  values(p_category_id,p_service_code,btrim(p_service_name),coalesce(p_sort_order,0),true)
  returning * into v;
  return v;
end $$;

create or replace function public.srk_admin_add_service_skill(
 p_service_type_id uuid,p_skill_code text,p_skill_name text,p_sort_order integer default 0
) returns public.srk_service_skills
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v public.srk_service_skills%rowtype;
begin
  if not public.srk_has_admin_permission('catalog.manage') then raise exception 'Catalog management permission required'; end if;
  if p_skill_code !~ '^[a-z][a-z0-9_]{1,79}$' or length(btrim(p_skill_name)) not between 2 and 150 then
    raise exception 'Invalid skill code or name';
  end if;
  insert into public.srk_service_skills(service_type_id,skill_code,skill_name,sort_order,is_active)
  values(p_service_type_id,p_skill_code,btrim(p_skill_name),coalesce(p_sort_order,0),true)
  returning * into v;
  return v;
end $$;

create or replace function public.srk_admin_attach_booking_receipt(
 p_bill_id uuid,p_storage_path text,p_file_name text
) returns public.srk_booking_receipts
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v_booking uuid; v_receipt public.srk_booking_receipts%rowtype;
begin
  if not public.srk_has_admin_permission('bookings.manage') then raise exception 'Booking management permission required'; end if;
  if p_storage_path like '/%' or p_storage_path like '%..%' then raise exception 'Invalid receipt storage path'; end if;
  select booking_id into v_booking from public.srk_booking_final_bills where id=p_bill_id and status in ('issued','approved');
  if not found then raise exception 'Issued final bill not found'; end if;
  insert into public.srk_booking_receipts(bill_id,booking_id,storage_path,file_name,generated_by)
  values(p_bill_id,v_booking,p_storage_path,p_file_name,auth.uid())
  on conflict(bill_id) do update set storage_path=excluded.storage_path,file_name=excluded.file_name,generated_at=clock_timestamp(),generated_by=auth.uid()
  returning * into v_receipt;
  return v_receipt;
end $$;

revoke all on function public.srk_admin_add_service_type(uuid,text,text,integer) from public,anon;
revoke all on function public.srk_admin_add_service_skill(uuid,text,text,integer) from public,anon;
revoke all on function public.srk_admin_attach_booking_receipt(uuid,text,text) from public,anon;
grant execute on function public.srk_admin_add_service_type(uuid,text,text,integer) to authenticated;
grant execute on function public.srk_admin_add_service_skill(uuid,text,text,integer) to authenticated;
grant execute on function public.srk_admin_attach_booking_receipt(uuid,text,text) to authenticated;
