
create sequence if not exists public.srk_order_id_seq start 1;
create sequence if not exists public.srk_customer_id_seq start 1;
create sequence if not exists public.srk_helper_id_seq start 1;

create or replace function public.srk_assign_customer_code()
returns trigger language plpgsql set search_path=pg_catalog,public as $$
begin
  if new.customer_code is null then
    new.customer_code := 'SRK-CUS-' || lpad(nextval('public.srk_customer_id_seq')::text,6,'0');
  end if;
  return new;
end $$;

create or replace function public.srk_assign_order_number()
returns trigger language plpgsql set search_path=pg_catalog,public as $$
begin
  if new.order_number is null then
    new.order_number := 'SRK-ORD-' || lpad(nextval('public.srk_order_id_seq')::text,6,'0');
  end if;
  return new;
end $$;

create table if not exists public.srk_worker_id_counters (
  category_code text primary key,
  last_value bigint not null default 0 check(last_value>=0)
);

create or replace function public.srk_assign_worker_code()
returns trigger
language plpgsql
security definer
set search_path=pg_catalog,public
as $$
declare
  v_category_code text;
  v_prefix text;
  v_number bigint;
begin
  if new.verification_status='approved' and new.worker_code is null then
    select category_code into v_category_code
    from public.srk_service_categories where id=new.category_id;
    if v_category_code is null then raise exception 'Worker category is required before approval'; end if;

    v_prefix := case v_category_code
      when 'electrician' then 'ELE'
      when 'plumber' then 'PLB'
      when 'painter' then 'PNT'
      when 'ac_fridge_technician' then 'AC'
      when 'motor_pump_technician' then 'MPT'
      when 'cooler_technician' then 'CLT'
      else 'WRK' end;

    if new.worker_type='helper' then v_prefix := 'HLP'; end if;

    insert into public.srk_worker_id_counters(category_code,last_value)
    values(v_prefix,1)
    on conflict(category_code) do update
      set last_value=public.srk_worker_id_counters.last_value+1
    returning last_value into v_number;

    new.worker_code := 'SRK-'||v_prefix||'-'||lpad(v_number::text,6,'0');
  end if;
  return new;
end $$;

drop trigger if exists srk_worker_code_trigger on public.srk_worker_profiles;
create trigger srk_worker_code_trigger
before insert or update of verification_status,category_id,worker_type
on public.srk_worker_profiles
for each row execute function public.srk_assign_worker_code();

create or replace function public.srk_admin_review_worker_profile(
  p_worker_id uuid,
  p_decision text,
  p_note text default null
) returns public.srk_worker_profiles
language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare v_worker public.srk_worker_profiles%rowtype;
begin
  if not coalesce(public.is_srk_admin(),false) then raise exception 'Admin permission required'; end if;
  if p_decision not in ('approved','rejected','under_review','suspended') then raise exception 'Invalid review decision'; end if;
  update public.srk_worker_profiles
    set verification_status=p_decision,
        is_active=(p_decision='approved'),
        updated_at=clock_timestamp()
    where id=p_worker_id returning * into v_worker;
  if not found then raise exception 'Worker profile not found'; end if;

  insert into public.srk_admin_audit_events(event_type,entity_type,entity_id,details)
  values('worker_profile_review','worker_profile',p_worker_id,
    jsonb_build_object('decision',p_decision,'note',p_note,'admin_user_id',auth.uid()));
  return v_worker;
end $$;

create or replace function public.srk_admin_review_worker_skill(
  p_worker_skill_id uuid,
  p_decision text,
  p_skill_level_id uuid,
  p_note text default null
) returns public.srk_worker_skills
language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare v_skill public.srk_worker_skills%rowtype;
begin
  if not coalesce(public.is_srk_admin(),false) then raise exception 'Admin permission required'; end if;
  if p_decision not in ('approved','rejected','pending') then raise exception 'Invalid skill decision'; end if;
  if p_decision='approved' and p_skill_level_id is null then raise exception 'Approved skill requires a skill level'; end if;
  update public.srk_worker_skills
    set verification_status=p_decision,skill_level_id=coalesce(p_skill_level_id,skill_level_id),
        reviewed_by=auth.uid(),reviewed_at=case when p_decision='pending' then null else clock_timestamp() end,
        admin_note=p_note,updated_at=clock_timestamp()
    where id=p_worker_skill_id returning * into v_skill;
  if not found then raise exception 'Worker skill not found'; end if;
  return v_skill;
end $$;

revoke all on function public.srk_admin_review_worker_profile(uuid,text,text) from public,anon;
revoke all on function public.srk_admin_review_worker_skill(uuid,text,uuid,text) from public,anon;
grant execute on function public.srk_admin_review_worker_profile(uuid,text,text) to authenticated,service_role;
grant execute on function public.srk_admin_review_worker_skill(uuid,text,uuid,text) to authenticated,service_role;
