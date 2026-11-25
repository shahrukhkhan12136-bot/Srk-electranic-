
alter table public.srk_worker_profiles add column if not exists admin_note text;

create or replace function public.srk_admin_review_worker_profile(p_worker_id uuid,p_decision text,p_note text default null)
returns public.srk_worker_profiles
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v_worker public.srk_worker_profiles%rowtype;
begin
  if not public.srk_has_admin_permission('workers.verify') then raise exception 'Worker verification permission required'; end if;
  if p_decision not in ('approved','rejected','under_review','suspended') then raise exception 'Invalid review decision'; end if;
  update public.srk_worker_profiles set verification_status=p_decision,is_active=(p_decision='approved'),
    admin_note=p_note,updated_at=clock_timestamp()
  where id=p_worker_id returning * into v_worker;
  if not found then raise exception 'Worker profile not found'; end if;
  return v_worker;
end $$;

create or replace function public.srk_admin_set_worker_status(p_worker_id uuid,p_status text,p_reason text)
returns public.srk_worker_profiles
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v public.srk_worker_profiles%rowtype;
begin
  if not public.srk_has_admin_permission('workers.manage') then raise exception 'Worker management permission required'; end if;
  if p_status not in ('approved','under_review','rejected','suspended') then raise exception 'Invalid worker status'; end if;
  update public.srk_worker_profiles set verification_status=p_status,is_active=(p_status='approved'),
    is_online=case when p_status='approved' then is_online else false end,
    location_lat=case when p_status='approved' then location_lat else null end,
    location_lng=case when p_status='approved' then location_lng else null end,
    admin_note=p_reason,updated_at=clock_timestamp()
  where id=p_worker_id returning * into v;
  if not found then raise exception 'Worker not found'; end if;
  insert into public.srk_app_notifications(user_id,notification_type,title,body)
  values(v.user_id,'worker_status','Worker account status updated','Your account status is now: '||p_status||'. Reason: '||coalesce(p_reason,'Not specified'));
  return v;
end $$;

drop trigger if exists srk_audit_customer_profile_admin on public.srk_customer_profiles;
create trigger srk_audit_customer_profile_admin after insert or update or delete on public.srk_customer_profiles
for each row execute function public.srk_log_admin_entity_change('customer_profile');

drop trigger if exists srk_audit_worker_skill_admin on public.srk_worker_skills;
create trigger srk_audit_worker_skill_admin after insert or update or delete on public.srk_worker_skills
for each row execute function public.srk_log_admin_entity_change('worker_skill');

drop trigger if exists srk_audit_worker_document_admin on public.srk_worker_documents;
create trigger srk_audit_worker_document_admin after insert or update or delete on public.srk_worker_documents
for each row execute function public.srk_log_admin_entity_change('worker_document');

drop trigger if exists srk_audit_final_bill_admin on public.srk_booking_final_bills;
create trigger srk_audit_final_bill_admin after insert or update or delete on public.srk_booking_final_bills
for each row execute function public.srk_log_admin_entity_change('final_bill');

drop trigger if exists srk_audit_payment_dispute_admin on public.srk_booking_payment_disputes;
create trigger srk_audit_payment_dispute_admin after insert or update or delete on public.srk_booking_payment_disputes
for each row execute function public.srk_log_admin_entity_change('payment_dispute');

drop trigger if exists srk_audit_admin_staff_admin on public.srk_admin_staff_members;
create trigger srk_audit_admin_staff_admin after insert or update or delete on public.srk_admin_staff_members
for each row execute function public.srk_log_admin_entity_change('admin_staff');
