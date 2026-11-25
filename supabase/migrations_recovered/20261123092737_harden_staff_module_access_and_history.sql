
-- Refine Staff RLS: separate SELECT from write policies to avoid permissive-policy overlap.
do $$
declare
  rec record;
begin
 for rec in
  select * from (values
   ('srk_staff_departments','public.srk_has_admin_permission(''staff.manage'')'),
   ('srk_staff_designations','public.srk_has_admin_permission(''staff.manage'')'),
   ('srk_staff_profiles','public.srk_has_admin_permission(''staff.manage'')'),
   ('srk_staff_attendance','(public.srk_has_admin_permission(''attendance.manage'') or public.srk_has_admin_permission(''staff.manage''))'),
   ('srk_staff_leave_types','(public.srk_has_admin_permission(''leave.manage'') or public.srk_has_admin_permission(''staff.manage''))'),
   ('srk_staff_leave_requests','(public.srk_has_admin_permission(''leave.manage'') or public.srk_has_admin_permission(''staff.manage''))'),
   ('srk_staff_salary_structures','public.srk_has_admin_permission(''payroll.manage'')'),
   ('srk_staff_payroll_records','public.srk_has_admin_permission(''payroll.manage'')'),
   ('srk_staff_work_assignments','public.srk_has_admin_permission(''staff.manage'')'),
   ('srk_staff_performance_reviews','(public.srk_has_admin_permission(''performance.manage'') or public.srk_has_admin_permission(''staff.manage''))'),
   ('srk_staff_documents','public.srk_has_admin_permission(''staff.manage'')')
  ) as x(table_name,write_check)
 loop
  execute format('drop policy if exists %I on public.%I',replace(rec.table_name,'srk_','')||'_write',rec.table_name);
  -- Existing policy names are stable and explicitly dropped below.
  execute format('drop policy if exists %I on public.%I',
    case rec.table_name
      when 'srk_staff_departments' then 'staff_departments_write'
      when 'srk_staff_designations' then 'staff_designations_write'
      when 'srk_staff_profiles' then 'staff_profiles_write'
      when 'srk_staff_attendance' then 'staff_attendance_write'
      when 'srk_staff_leave_types' then 'staff_leave_types_write'
      when 'srk_staff_leave_requests' then 'staff_leave_requests_write'
      when 'srk_staff_salary_structures' then 'staff_salary_structures_write'
      when 'srk_staff_payroll_records' then 'staff_payroll_records_write'
      when 'srk_staff_work_assignments' then 'staff_assignments_write'
      when 'srk_staff_performance_reviews' then 'staff_reviews_write'
      when 'srk_staff_documents' then 'staff_documents_write'
    end,rec.table_name);
  execute format('create policy %I on public.%I for insert to authenticated with check (%s)',
    rec.table_name||'_insert',rec.table_name,rec.write_check);
  execute format('create policy %I on public.%I for update to authenticated using (%s) with check (%s)',
    rec.table_name||'_update',rec.table_name,rec.write_check,rec.write_check);
  execute format('create policy %I on public.%I for delete to authenticated using (%s)',
    rec.table_name||'_delete',rec.table_name,rec.write_check);
 end loop;
end $$;

-- Keep payroll records immutable once paid and enforce a controlled status flow.
create or replace function public.srk_guard_staff_payroll_mutation()
returns trigger language plpgsql
set search_path = pg_catalog, public
as $$
begin
 if tg_op='DELETE' then
   if old.status='paid' then raise exception 'Paid payroll records cannot be deleted'; end if;
   return old;
 end if;
 if old.status='paid' then
   raise exception 'Paid payroll records are immutable; use a separate adjustment record';
 end if;
 if old.status='cancelled' and new.status<>'cancelled' then
   raise exception 'Cancelled payroll records cannot be reopened';
 end if;
 if old.status='draft' and new.status not in ('draft','approved','on_hold','cancelled') then
   raise exception 'Invalid payroll transition from draft';
 end if;
 if old.status='approved' and new.status not in ('approved','paid','on_hold','cancelled') then
   raise exception 'Invalid payroll transition from approved';
 end if;
 if old.status='on_hold' and new.status not in ('on_hold','draft','approved','cancelled') then
   raise exception 'Invalid payroll transition from on_hold';
 end if;
 return new;
end $$;
revoke all on function public.srk_guard_staff_payroll_mutation() from public,anon,authenticated;
drop trigger if exists srk_staff_payroll_guard on public.srk_staff_payroll_records;
create trigger srk_staff_payroll_guard before update or delete on public.srk_staff_payroll_records
for each row execute function public.srk_guard_staff_payroll_mutation();

-- Salary structures are versioned: only closing an open version is permitted; no rewriting history.
create or replace function public.srk_guard_staff_salary_version()
returns trigger language plpgsql
set search_path = pg_catalog, public
as $$
begin
 if tg_op='DELETE' then
   raise exception 'Salary history cannot be deleted; close the effective period instead';
 end if;
 if old.effective_to is not null then
   raise exception 'Closed salary versions are immutable';
 end if;
 if (to_jsonb(new) - 'effective_to') is distinct from (to_jsonb(old) - 'effective_to') then
   raise exception 'Salary version terms are immutable; create a new effective-dated version';
 end if;
 if new.effective_to is null or new.effective_to < old.effective_from then
   raise exception 'A current salary version may only be closed with a valid effective_to date';
 end if;
 return new;
end $$;
revoke all on function public.srk_guard_staff_salary_version() from public,anon,authenticated;
drop trigger if exists srk_staff_salary_version_guard on public.srk_staff_salary_structures;
create trigger srk_staff_salary_version_guard before update or delete on public.srk_staff_salary_structures
for each row execute function public.srk_guard_staff_salary_version();

-- Updated timestamps are database-maintained.
create or replace function public.srk_staff_touch_updated_at()
returns trigger language plpgsql
set search_path = pg_catalog
as $$ begin new.updated_at=clock_timestamp(); return new; end $$;
revoke all on function public.srk_staff_touch_updated_at() from public,anon,authenticated;
do $$
declare t text;
begin
 foreach t in array array[
  'srk_staff_departments','srk_staff_designations','srk_staff_profiles',
  'srk_staff_attendance','srk_staff_leave_requests','srk_staff_payroll_records',
  'srk_staff_work_assignments','srk_staff_performance_reviews'
 ] loop
  execute format('drop trigger if exists %I on public.%I',t||'_touch_updated_at',t);
  execute format('create trigger %I before update on public.%I for each row execute function public.srk_staff_touch_updated_at()',t||'_touch_updated_at',t);
 end loop;
end $$;
