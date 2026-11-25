
insert into public.srk_service_types(category_id,service_code,service_name,sort_order)
select c.id,v.service_code,v.service_name,v.sort_order
from public.srk_service_categories c
join (values
 ('electrician','basic_electrical','Basic Electrical Work',1),
 ('electrician','residential_office_wiring','Residential/Office Wiring',2),
 ('electrician','factory_industrial_wiring','Factory/Industrial Wiring',3),
 ('electrician','master_electrician_work','Master Electrician Work',4)
) v(category_code,service_code,service_name,sort_order) on c.category_code=v.category_code
on conflict(service_code) do update set service_name=excluded.service_name,sort_order=excluded.sort_order;

insert into public.srk_service_skills(service_type_id,skill_code,skill_name,sort_order)
select s.id,v.skill_code,v.skill_name,v.sort_order
from public.srk_service_types s
join (values
 ('basic_electrical','fan_install_repair','Fan Install/Repair',1),
 ('basic_electrical','light_bulb_tube_install_repair','Light/Bulb/Tube Install/Repair',2),
 ('basic_electrical','switch_socket_holder','Switch/Socket/Holder',3),
 ('basic_electrical','mcb_work','MCB Work',4),
 ('basic_electrical','domestic_electrical_fault','General Domestic Electrical Fault',5),
 ('residential_office_wiring','new_old_wiring','New/Old Wiring',1),
 ('residential_office_wiring','switchboard_work','Switchboard Work',2),
 ('residential_office_wiring','db_mcb_work','DB/MCB Work',3),
 ('residential_office_wiring','electrical_points','Electrical Points',4),
 ('factory_industrial_wiring','factory_wiring','Factory Wiring',1),
 ('factory_industrial_wiring','machine_power_connection','Machine Power Connection',2),
 ('factory_industrial_wiring','industrial_panels_factory','Industrial Panels',3),
 ('factory_industrial_wiring','control_wiring','Control Wiring',4),
 ('factory_industrial_wiring','machine_faults','Machine Faults',5),
 ('master_electrician_work','complex_electrical_projects','Complex Electrical Projects',1),
 ('master_electrician_work','industrial_panels_master','Industrial Panels',2),
 ('master_electrician_work','control_systems','Control Systems',3),
 ('master_electrician_work','three_phase_supply','Three-Phase Supply',4),
 ('master_electrician_work','large_site_supervision','Large Site Supervision',5)
) v(service_code,skill_code,skill_name,sort_order) on s.service_code=v.service_code
on conflict(skill_code) do update set skill_name=excluded.skill_name,sort_order=excluded.sort_order;

create or replace function public.srk_admin_review_worker_profile(
  p_worker_id uuid,
  p_decision text,
  p_note text default null
) returns public.srk_worker_profiles
language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare
  v_worker public.srk_worker_profiles%rowtype;
  v_before jsonb;
begin
  if not coalesce(public.is_srk_admin(),false) then raise exception 'Admin permission required'; end if;
  if p_decision not in ('approved','rejected','under_review','suspended') then raise exception 'Invalid review decision'; end if;
  select to_jsonb(w) into v_before from public.srk_worker_profiles w where id=p_worker_id for update;
  if v_before is null then raise exception 'Worker profile not found'; end if;

  update public.srk_worker_profiles
    set verification_status=p_decision,is_active=(p_decision='approved'),updated_at=clock_timestamp()
    where id=p_worker_id returning * into v_worker;

  insert into public.srk_admin_audit_events
    (entity_type,entity_id,action,actor_user_id,actor_role,changed_fields,before_data,after_data)
  values('worker_profile',p_worker_id,'verification_'||p_decision,auth.uid(),'admin',
    array['verification_status','is_active'],v_before,to_jsonb(v_worker));
  return v_worker;
end $$;

create or replace function public.srk_worker_request_payout(p_amount numeric)
returns public.srk_worker_payout_requests
language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare v_worker uuid; v_available numeric(12,2); v_reserved numeric(12,2); v_payout public.srk_worker_payout_requests%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select id into v_worker from public.srk_worker_profiles where user_id=auth.uid() for update;
  if not found then raise exception 'Worker profile not found'; end if;
  if p_amount is null or p_amount<=0 then raise exception 'Payout amount must be positive'; end if;
  select coalesce(sum(balance_effect),0) into v_available from public.srk_worker_wallet_ledger where worker_id=v_worker;
  select coalesce(sum(coalesce(approved_amount,requested_amount)),0) into v_reserved
  from public.srk_worker_payout_requests where worker_id=v_worker and status in ('requested','under_review','approved');
  if p_amount>v_available-v_reserved then raise exception 'Payout exceeds unreserved available wallet balance'; end if;
  insert into public.srk_worker_payout_requests(worker_id,requested_amount,status)
  values(v_worker,p_amount,'requested') returning * into v_payout;
  return v_payout;
end $$;

create or replace function public.srk_admin_review_worker_payout(
  p_payout_id uuid,p_approve boolean,p_approved_amount numeric default null,p_note text default null
) returns public.srk_worker_payout_requests
language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare v_payout public.srk_worker_payout_requests%rowtype; v_available numeric(12,2); v_reserved numeric(12,2); v_amount numeric(12,2);
begin
  if not coalesce(public.is_srk_admin(),false) then raise exception 'Admin permission required'; end if;
  select * into v_payout from public.srk_worker_payout_requests where id=p_payout_id for update;
  if not found or v_payout.status not in ('requested','under_review') then raise exception 'Payout request is not reviewable'; end if;
  perform 1 from public.srk_worker_profiles where id=v_payout.worker_id for update;
  if not p_approve then
    update public.srk_worker_payout_requests set status='rejected',reviewed_at=clock_timestamp(),reviewed_by=auth.uid(),admin_note=p_note
    where id=p_payout_id returning * into v_payout;
    return v_payout;
  end if;
  v_amount:=coalesce(p_approved_amount,v_payout.requested_amount);
  select coalesce(sum(balance_effect),0) into v_available from public.srk_worker_wallet_ledger where worker_id=v_payout.worker_id;
  select coalesce(sum(coalesce(approved_amount,requested_amount)),0) into v_reserved
  from public.srk_worker_payout_requests
  where worker_id=v_payout.worker_id and id<>p_payout_id and status in ('requested','under_review','approved');
  if v_amount<=0 or v_amount>v_payout.requested_amount or v_amount>v_available-v_reserved then
    raise exception 'Approved amount exceeds unreserved available balance';
  end if;
  update public.srk_worker_payout_requests set status='approved',approved_amount=v_amount,
    reviewed_at=clock_timestamp(),reviewed_by=auth.uid(),admin_note=p_note
  where id=p_payout_id returning * into v_payout;
  return v_payout;
end $$;

create or replace function public.srk_admin_mark_worker_payout_paid(
  p_payout_id uuid,p_payment_method text,p_payment_reference text,p_note text default null
) returns public.srk_worker_payout_requests
language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare v_payout public.srk_worker_payout_requests%rowtype; v_available numeric(12,2); v_reserved numeric(12,2);
begin
  if not coalesce(public.is_srk_admin(),false) then raise exception 'Admin permission required'; end if;
  if nullif(btrim(p_payment_reference),'') is null then raise exception 'UTR/transaction reference is required'; end if;
  if p_payment_method not in ('upi','bank_transfer','phonepe','other') then raise exception 'Invalid payout method'; end if;
  select * into v_payout from public.srk_worker_payout_requests where id=p_payout_id for update;
  if not found or v_payout.status<>'approved' then raise exception 'Only approved payouts can be marked paid'; end if;
  perform 1 from public.srk_worker_profiles where id=v_payout.worker_id for update;
  select coalesce(sum(balance_effect),0) into v_available from public.srk_worker_wallet_ledger where worker_id=v_payout.worker_id;
  select coalesce(sum(approved_amount),0) into v_reserved from public.srk_worker_payout_requests
  where worker_id=v_payout.worker_id and id<>p_payout_id and status='approved';
  if v_payout.approved_amount>v_available-v_reserved then raise exception 'Wallet balance changed; payout cannot be paid'; end if;
  insert into public.srk_worker_wallet_ledger(worker_id,entry_type,amount,balance_effect,description,reference_id,idempotency_key)
  values(v_payout.worker_id,'payout_paid',v_payout.approved_amount,-v_payout.approved_amount,
    'Admin verified payout',p_payment_reference,'payout-paid:'||v_payout.id::text);
  update public.srk_worker_payout_requests set status='paid',payment_method=p_payment_method,
    payment_reference=p_payment_reference,admin_note=coalesce(p_note,admin_note),paid_at=clock_timestamp()
  where id=p_payout_id returning * into v_payout;
  return v_payout;
end $$;
