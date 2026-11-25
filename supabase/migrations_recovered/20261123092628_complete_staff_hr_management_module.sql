
-- SRK ELECTRONIC HR / Staff Management module
create sequence if not exists public.srk_staff_code_seq;

create table if not exists public.srk_staff_departments (
  id uuid primary key default gen_random_uuid(),
  department_code text not null unique,
  department_name text not null unique,
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (department_code ~ '^[A-Z0-9_]{2,30}$'),
  check (length(btrim(department_name)) between 2 and 100)
);

create table if not exists public.srk_staff_designations (
  id uuid primary key default gen_random_uuid(),
  department_id uuid references public.srk_staff_departments(id) on delete restrict,
  designation_code text not null unique,
  designation_name text not null,
  grade_level integer,
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (designation_code ~ '^[A-Z0-9_]{2,30}$'),
  check (length(btrim(designation_name)) between 2 and 100),
  check (grade_level is null or grade_level between 1 and 20)
);

create table if not exists public.srk_staff_profiles (
  id uuid primary key default gen_random_uuid(),
  staff_code text not null unique default ('SRK-STF-' || lpad(nextval('public.srk_staff_code_seq')::text,6,'0')),
  user_id uuid unique references auth.users(id) on delete restrict,
  full_name text not null,
  phone text,
  email text,
  date_of_birth date,
  gender text,
  address text,
  emergency_contact_name text,
  emergency_contact_phone text,
  department_id uuid references public.srk_staff_departments(id) on delete restrict,
  designation_id uuid references public.srk_staff_designations(id) on delete restrict,
  manager_staff_id uuid references public.srk_staff_profiles(id) on delete set null,
  employment_type text not null default 'full_time',
  joining_date date not null default current_date,
  employment_status text not null default 'active',
  probation_end_date date,
  notice_period_days integer,
  exit_date date,
  exit_reason text,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (length(btrim(full_name)) between 2 and 150),
  check (phone is null or phone ~ '^[+]?[0-9 -]{8,20}$'),
  check (email is null or position('@' in email) > 1),
  check (gender is null or gender in ('male','female','other','prefer_not_to_say')),
  check (employment_type in ('full_time','part_time','contract','temporary','intern')),
  check (employment_status in ('active','on_probation','on_leave','notice_period','suspended','resigned','terminated')),
  check (notice_period_days is null or notice_period_days between 0 and 365),
  check (exit_date is null or exit_date >= joining_date),
  check (probation_end_date is null or probation_end_date >= joining_date)
);

create table if not exists public.srk_staff_attendance (
  id uuid primary key default gen_random_uuid(),
  staff_id uuid not null references public.srk_staff_profiles(id) on delete restrict,
  attendance_date date not null,
  attendance_status text not null,
  check_in_at timestamptz,
  check_out_at timestamptz,
  break_minutes integer not null default 0,
  work_minutes integer,
  source text not null default 'admin',
  location_note text,
  remarks text,
  marked_by uuid references auth.users(id) on delete set null,
  approved_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(staff_id,attendance_date),
  check (attendance_status in ('present','absent','half_day','leave','holiday','week_off','work_from_home')),
  check (break_minutes between 0 and 1440),
  check (work_minutes is null or work_minutes between 0 and 1440),
  check (check_out_at is null or check_in_at is not null and check_out_at >= check_in_at),
  check (source in ('admin','staff_app','import','system'))
);

create table if not exists public.srk_staff_leave_types (
  id uuid primary key default gen_random_uuid(),
  leave_code text not null unique,
  leave_name text not null unique,
  paid_leave boolean not null default true,
  annual_quota numeric(6,2),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  check (annual_quota is null or annual_quota >= 0)
);

create table if not exists public.srk_staff_leave_requests (
  id uuid primary key default gen_random_uuid(),
  staff_id uuid not null references public.srk_staff_profiles(id) on delete restrict,
  leave_type_id uuid not null references public.srk_staff_leave_types(id) on delete restrict,
  start_date date not null,
  end_date date not null,
  requested_days numeric(6,2) not null,
  reason text not null,
  status text not null default 'pending',
  requested_at timestamptz not null default now(),
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  reviewer_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (end_date >= start_date),
  check (requested_days > 0 and requested_days <= 366),
  check (length(btrim(reason)) between 3 and 2000),
  check (status in ('pending','approved','rejected','cancelled','withdrawn')),
  check ((status='pending' and reviewed_at is null) or status<>'pending')
);

create table if not exists public.srk_staff_salary_structures (
  id uuid primary key default gen_random_uuid(),
  staff_id uuid not null references public.srk_staff_profiles(id) on delete restrict,
  currency_code char(3) not null default 'INR',
  pay_frequency text not null default 'monthly',
  base_salary numeric(12,2) not null,
  allowances jsonb not null default '{}'::jsonb,
  standard_deductions jsonb not null default '{}'::jsonb,
  effective_from date not null,
  effective_to date,
  created_by uuid references auth.users(id) on delete set null,
  change_reason text not null,
  created_at timestamptz not null default now(),
  check (currency_code='INR'),
  check (pay_frequency in ('monthly','weekly','daily','hourly')),
  check (base_salary >= 0),
  check (jsonb_typeof(allowances)='object' and jsonb_typeof(standard_deductions)='object'),
  check (effective_to is null or effective_to >= effective_from),
  check (length(btrim(change_reason)) >= 5)
);
create unique index if not exists srk_staff_one_current_salary_structure
  on public.srk_staff_salary_structures(staff_id) where effective_to is null;

create table if not exists public.srk_staff_payroll_records (
  id uuid primary key default gen_random_uuid(),
  staff_id uuid not null references public.srk_staff_profiles(id) on delete restrict,
  salary_structure_id uuid references public.srk_staff_salary_structures(id) on delete restrict,
  period_start date not null,
  period_end date not null,
  gross_amount numeric(12,2) not null,
  deductions_amount numeric(12,2) not null default 0,
  net_amount numeric(12,2) generated always as (gross_amount-deductions_amount) stored,
  currency_code char(3) not null default 'INR',
  status text not null default 'draft',
  paid_at timestamptz,
  payment_method text,
  payment_reference text,
  prepared_by uuid references auth.users(id) on delete set null,
  approved_by uuid references auth.users(id) on delete set null,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(staff_id,period_start,period_end),
  check (period_end >= period_start),
  check (gross_amount >= 0 and deductions_amount >= 0 and deductions_amount <= gross_amount),
  check (currency_code='INR'),
  check (status in ('draft','approved','paid','on_hold','cancelled')),
  check (payment_method is null or payment_method in ('bank_transfer','upi','cash','cheque','other')),
  check ((status='paid' and paid_at is not null) or status<>'paid')
);

create table if not exists public.srk_staff_work_assignments (
  id uuid primary key default gen_random_uuid(),
  staff_id uuid not null references public.srk_staff_profiles(id) on delete restrict,
  title text not null,
  description text,
  priority text not null default 'normal',
  status text not null default 'assigned',
  assigned_by uuid references auth.users(id) on delete set null,
  assigned_at timestamptz not null default now(),
  due_at timestamptz,
  started_at timestamptz,
  completed_at timestamptz,
  completion_note text,
  related_booking_id uuid references public.service_bookings(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (length(btrim(title)) between 2 and 200),
  check (priority in ('low','normal','high','urgent')),
  check (status in ('assigned','accepted','in_progress','blocked','completed','cancelled')),
  check (completed_at is null or started_at is not null and completed_at >= started_at)
);

create table if not exists public.srk_staff_performance_reviews (
  id uuid primary key default gen_random_uuid(),
  staff_id uuid not null references public.srk_staff_profiles(id) on delete restrict,
  reviewer_user_id uuid not null references auth.users(id) on delete restrict,
  period_start date not null,
  period_end date not null,
  ratings jsonb not null default '{}'::jsonb,
  overall_score numeric(3,2),
  strengths text,
  improvement_areas text,
  goals text,
  review_status text not null default 'draft',
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (period_end >= period_start),
  check (jsonb_typeof(ratings)='object'),
  check (overall_score is null or overall_score between 1 and 5),
  check (review_status in ('draft','shared','acknowledged','finalized'))
);

create table if not exists public.srk_staff_employment_history (
  id uuid primary key default gen_random_uuid(),
  staff_id uuid not null references public.srk_staff_profiles(id) on delete restrict,
  event_type text not null,
  effective_at timestamptz not null default now(),
  old_data jsonb not null default '{}'::jsonb,
  new_data jsonb not null default '{}'::jsonb,
  reason text,
  actor_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  check (event_type in ('created','profile_updated','department_changed','designation_changed','status_changed','manager_changed','employment_exit','manual_note'))
);

create table if not exists public.srk_staff_documents (
  id uuid primary key default gen_random_uuid(),
  staff_id uuid not null references public.srk_staff_profiles(id) on delete restrict,
  document_type text not null,
  storage_path text not null,
  original_file_name text,
  verification_status text not null default 'pending',
  uploaded_by uuid references auth.users(id) on delete set null,
  verified_by uuid references auth.users(id) on delete set null,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  check (document_type in ('identity','address','education','employment','offer_letter','contract','other')),
  check (verification_status in ('pending','verified','rejected'))
);

create index if not exists srk_staff_profiles_department_idx on public.srk_staff_profiles(department_id);
create index if not exists srk_staff_profiles_designation_idx on public.srk_staff_profiles(designation_id);
create index if not exists srk_staff_attendance_date_idx on public.srk_staff_attendance(attendance_date desc);
create index if not exists srk_staff_leave_staff_status_idx on public.srk_staff_leave_requests(staff_id,status,start_date);
create index if not exists srk_staff_payroll_period_idx on public.srk_staff_payroll_records(period_start desc,status);
create index if not exists srk_staff_assignments_staff_status_idx on public.srk_staff_work_assignments(staff_id,status,due_at);
create index if not exists srk_staff_reviews_staff_period_idx on public.srk_staff_performance_reviews(staff_id,period_end desc);
create index if not exists srk_staff_history_staff_date_idx on public.srk_staff_employment_history(staff_id,effective_at desc);
create index if not exists srk_staff_documents_staff_idx on public.srk_staff_documents(staff_id,created_at desc);

-- Dedicated permissions keep payroll and personnel records separated.
insert into public.srk_admin_permissions(permission_code,description) values
 ('staff.read','Read staff directory and HR profiles'),
 ('attendance.manage','Manage staff attendance'),
 ('leave.manage','Review and manage staff leave'),
 ('payroll.manage','Prepare, approve and reconcile staff payroll'),
 ('performance.manage','Manage staff performance reviews')
on conflict(permission_code) do update set description=excluded.description;

insert into public.srk_admin_roles(role_code,role_name,is_active)
values ('hr_manager','HR Manager',true)
on conflict(role_code) do update set role_name=excluded.role_name,is_active=true;

insert into public.srk_admin_role_permissions(role_id,permission_code)
select r.id,p.permission_code
from public.srk_admin_roles r
cross join (values ('staff.read'),('staff.manage'),('attendance.manage'),('leave.manage'),('performance.manage')) p(permission_code)
where r.role_code='hr_manager'
on conflict do nothing;

insert into public.srk_admin_role_permissions(role_id,permission_code)
select r.id,'payroll.manage' from public.srk_admin_roles r
where r.role_code='finance_manager'
on conflict do nothing;

-- Row-level access: no public/anonymous access; each module requires its own permission.
do $$
declare t text;
begin
 foreach t in array array[
  'srk_staff_departments','srk_staff_designations','srk_staff_profiles',
  'srk_staff_attendance','srk_staff_leave_types','srk_staff_leave_requests',
  'srk_staff_salary_structures','srk_staff_payroll_records',
  'srk_staff_work_assignments','srk_staff_performance_reviews',
  'srk_staff_employment_history','srk_staff_documents'
 ] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('revoke all on table public.%I from anon, authenticated',t);
  execute format('grant select,insert,update,delete on table public.%I to authenticated',t);
 end loop;
end $$;

create policy staff_departments_read on public.srk_staff_departments for select to authenticated
 using (public.srk_has_admin_permission('staff.read') or public.srk_has_admin_permission('staff.manage'));
create policy staff_departments_write on public.srk_staff_departments for all to authenticated
 using (public.srk_has_admin_permission('staff.manage')) with check (public.srk_has_admin_permission('staff.manage'));

create policy staff_designations_read on public.srk_staff_designations for select to authenticated
 using (public.srk_has_admin_permission('staff.read') or public.srk_has_admin_permission('staff.manage'));
create policy staff_designations_write on public.srk_staff_designations for all to authenticated
 using (public.srk_has_admin_permission('staff.manage')) with check (public.srk_has_admin_permission('staff.manage'));

create policy staff_profiles_read on public.srk_staff_profiles for select to authenticated
 using (public.srk_has_admin_permission('staff.read') or public.srk_has_admin_permission('staff.manage'));
create policy staff_profiles_write on public.srk_staff_profiles for all to authenticated
 using (public.srk_has_admin_permission('staff.manage')) with check (public.srk_has_admin_permission('staff.manage'));

create policy staff_attendance_read on public.srk_staff_attendance for select to authenticated
 using (public.srk_has_admin_permission('attendance.manage') or public.srk_has_admin_permission('staff.manage'));
create policy staff_attendance_write on public.srk_staff_attendance for all to authenticated
 using (public.srk_has_admin_permission('attendance.manage') or public.srk_has_admin_permission('staff.manage'))
 with check (public.srk_has_admin_permission('attendance.manage') or public.srk_has_admin_permission('staff.manage'));

create policy staff_leave_types_read on public.srk_staff_leave_types for select to authenticated
 using (public.srk_has_admin_permission('leave.manage') or public.srk_has_admin_permission('staff.manage'));
create policy staff_leave_types_write on public.srk_staff_leave_types for all to authenticated
 using (public.srk_has_admin_permission('leave.manage') or public.srk_has_admin_permission('staff.manage'))
 with check (public.srk_has_admin_permission('leave.manage') or public.srk_has_admin_permission('staff.manage'));

create policy staff_leave_requests_read on public.srk_staff_leave_requests for select to authenticated
 using (public.srk_has_admin_permission('leave.manage') or public.srk_has_admin_permission('staff.manage'));
create policy staff_leave_requests_write on public.srk_staff_leave_requests for all to authenticated
 using (public.srk_has_admin_permission('leave.manage') or public.srk_has_admin_permission('staff.manage'))
 with check (public.srk_has_admin_permission('leave.manage') or public.srk_has_admin_permission('staff.manage'));

create policy staff_salary_structures_read on public.srk_staff_salary_structures for select to authenticated
 using (public.srk_has_admin_permission('payroll.manage'));
create policy staff_salary_structures_write on public.srk_staff_salary_structures for all to authenticated
 using (public.srk_has_admin_permission('payroll.manage')) with check (public.srk_has_admin_permission('payroll.manage'));

create policy staff_payroll_records_read on public.srk_staff_payroll_records for select to authenticated
 using (public.srk_has_admin_permission('payroll.manage'));
create policy staff_payroll_records_write on public.srk_staff_payroll_records for all to authenticated
 using (public.srk_has_admin_permission('payroll.manage')) with check (public.srk_has_admin_permission('payroll.manage'));

create policy staff_assignments_read on public.srk_staff_work_assignments for select to authenticated
 using (public.srk_has_admin_permission('staff.read') or public.srk_has_admin_permission('staff.manage'));
create policy staff_assignments_write on public.srk_staff_work_assignments for all to authenticated
 using (public.srk_has_admin_permission('staff.manage')) with check (public.srk_has_admin_permission('staff.manage'));

create policy staff_reviews_read on public.srk_staff_performance_reviews for select to authenticated
 using (public.srk_has_admin_permission('performance.manage') or public.srk_has_admin_permission('staff.manage'));
create policy staff_reviews_write on public.srk_staff_performance_reviews for all to authenticated
 using (public.srk_has_admin_permission('performance.manage') or public.srk_has_admin_permission('staff.manage'))
 with check (public.srk_has_admin_permission('performance.manage') or public.srk_has_admin_permission('staff.manage'));

create policy staff_history_read on public.srk_staff_employment_history for select to authenticated
 using (public.srk_has_admin_permission('staff.manage'));
create policy staff_history_write on public.srk_staff_employment_history for insert to authenticated
 with check (public.srk_has_admin_permission('staff.manage'));

create policy staff_documents_read on public.srk_staff_documents for select to authenticated
 using (public.srk_has_admin_permission('staff.manage'));
create policy staff_documents_write on public.srk_staff_documents for all to authenticated
 using (public.srk_has_admin_permission('staff.manage')) with check (public.srk_has_admin_permission('staff.manage'));

-- Profile edits automatically create an immutable employment-history event.
create or replace function public.srk_staff_profile_history_trigger()
returns trigger language plpgsql security definer
set search_path = pg_catalog, public, auth
as $$
declare v_event text := 'profile_updated';
begin
 if tg_op='INSERT' then
   insert into public.srk_staff_employment_history(staff_id,event_type,new_data,actor_user_id)
   values(new.id,'created',to_jsonb(new),auth.uid());
   return new;
 end if;
 if old.department_id is distinct from new.department_id then v_event:='department_changed';
 elsif old.designation_id is distinct from new.designation_id then v_event:='designation_changed';
 elsif old.employment_status is distinct from new.employment_status then
   v_event:=case when new.employment_status in ('resigned','terminated') then 'employment_exit' else 'status_changed' end;
 elsif old.manager_staff_id is distinct from new.manager_staff_id then v_event:='manager_changed';
 end if;
 insert into public.srk_staff_employment_history(staff_id,event_type,old_data,new_data,reason,actor_user_id)
 values(new.id,v_event,
   jsonb_build_object('full_name',old.full_name,'department_id',old.department_id,'designation_id',old.designation_id,
     'manager_staff_id',old.manager_staff_id,'employment_status',old.employment_status,'employment_type',old.employment_type,
     'joining_date',old.joining_date,'exit_date',old.exit_date),
   jsonb_build_object('full_name',new.full_name,'department_id',new.department_id,'designation_id',new.designation_id,
     'manager_staff_id',new.manager_staff_id,'employment_status',new.employment_status,'employment_type',new.employment_type,
     'joining_date',new.joining_date,'exit_date',new.exit_date),
   null,coalesce(new.updated_by,auth.uid()));
 return new;
end $$;
revoke all on function public.srk_staff_profile_history_trigger() from public,anon,authenticated;
drop trigger if exists srk_staff_profile_history_after_insert on public.srk_staff_profiles;
drop trigger if exists srk_staff_profile_history_after_update on public.srk_staff_profiles;
create trigger srk_staff_profile_history_after_insert after insert on public.srk_staff_profiles
for each row execute function public.srk_staff_profile_history_trigger();
create trigger srk_staff_profile_history_after_update after update on public.srk_staff_profiles
for each row execute function public.srk_staff_profile_history_trigger();

-- Prevent overlapping active/pending leave requests for the same staff member.
create or replace function public.srk_guard_staff_leave_overlap()
returns trigger language plpgsql
set search_path = pg_catalog, public
as $$
begin
 perform 1 from public.srk_staff_profiles where id=new.staff_id for update;
 if new.status in ('pending','approved') and exists (
   select 1 from public.srk_staff_leave_requests x
   where x.staff_id=new.staff_id and x.id<>coalesce(new.id,'00000000-0000-0000-0000-000000000000'::uuid)
     and x.status in ('pending','approved')
     and daterange(x.start_date,x.end_date,'[]') && daterange(new.start_date,new.end_date,'[]')
 ) then
   raise exception 'Staff leave dates overlap an existing pending or approved request';
 end if;
 return new;
end $$;
revoke all on function public.srk_guard_staff_leave_overlap() from public,anon,authenticated;
drop trigger if exists srk_staff_leave_no_overlap on public.srk_staff_leave_requests;
create trigger srk_staff_leave_no_overlap before insert or update of staff_id,start_date,end_date,status
on public.srk_staff_leave_requests for each row execute function public.srk_guard_staff_leave_overlap();

-- Standard starter leave categories; quotas are deliberately unset until company policy is approved.
insert into public.srk_staff_leave_types(leave_code,leave_name,paid_leave,annual_quota)
values ('CASUAL','Casual Leave',true,null),('SICK','Sick Leave',true,null),
       ('UNPAID','Unpaid Leave',false,null),('OTHER','Other Leave',false,null)
on conflict(leave_code) do nothing;

-- Standard starter departments and designations are editable; no employee/pay data is fabricated.
insert into public.srk_staff_departments(department_code,department_name,description) values
 ('OPERATIONS','Operations','Daily service operations and coordination'),
 ('CUSTOMER_SUPPORT','Customer Support','Customer queries and complaint support'),
 ('BOOKING','Booking','Booking coordination and assignment operations'),
 ('FINANCE','Finance','Payments, reconciliation and payroll'),
 ('HR','Human Resources','Staff administration and HR operations'),
 ('TECHNICAL','Technical Support','Technical issue triage and platform support')
on conflict(department_code) do nothing;

insert into public.srk_staff_designations(department_id,designation_code,designation_name)
select d.id,x.code,x.name from (values
 ('OPERATIONS','OPS_MANAGER','Operations Manager'),
 ('OPERATIONS','OPS_EXECUTIVE','Operations Executive'),
 ('CUSTOMER_SUPPORT','SUPERVISOR','Support Supervisor'),
 ('CUSTOMER_SUPPORT','SUPPORT_EXECUTIVE','Support Executive'),
 ('BOOKING','BOOKING_MANAGER','Booking Manager'),
 ('BOOKING','BOOKING_EXECUTIVE','Booking Executive'),
 ('FINANCE','FINANCE_MANAGER','Finance Manager'),
 ('FINANCE','ACCOUNTS_EXECUTIVE','Accounts Executive'),
 ('HR','HR_MANAGER','HR Manager'),
 ('HR','HR_EXECUTIVE','HR Executive'),
 ('TECHNICAL','TECH_SUPPORT_EXECUTIVE','Technical Support Executive')
) x(dept,code,name) join public.srk_staff_departments d on d.department_code=x.dept
on conflict(designation_code) do nothing;
