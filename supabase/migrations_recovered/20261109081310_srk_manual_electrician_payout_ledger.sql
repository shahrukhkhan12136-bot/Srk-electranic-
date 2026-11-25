
create table if not exists public.srk_electrician_payouts (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references public.service_bookings(id) on delete restrict,
  electrician_profile_id uuid not null references public.electrician_profiles(id) on delete restrict,
  razorpay_payment_id text,
  gross_service_amount numeric(12,2) not null check (gross_service_amount >= 0),
  materials_amount numeric(12,2) not null check (materials_amount >= 0),
  platform_commission numeric(12,2) not null check (platform_commission >= 0),
  electrician_payable numeric(12,2) not null check (electrician_payable >= 0),
  payout_status text not null default 'pending' check (payout_status in ('pending','paid','blocked','refunded')),
  payout_method text check (payout_method in ('upi','bank')),
  payout_reference text,
  payout_note text,
  paid_by uuid references auth.users(id),
  paid_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint srk_payout_paid_fields_check check (
    (payout_status <> 'paid') or
    (payout_method is not null and payout_reference is not null and length(trim(payout_reference)) >= 4 and paid_at is not null and paid_by is not null)
  )
);
create index if not exists srk_electrician_payouts_status_idx on public.srk_electrician_payouts(payout_status, created_at desc);
alter table public.srk_electrician_payouts enable row level security;
revoke all on public.srk_electrician_payouts from anon, authenticated;
grant select on public.srk_electrician_payouts to authenticated;
drop policy if exists srk_admin_read_electrician_payouts on public.srk_electrician_payouts;
create policy srk_admin_read_electrician_payouts on public.srk_electrician_payouts
for select to authenticated using ((select public.is_srk_admin()));

create or replace function public.srk_create_electrician_payable()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_service numeric(12,2);
  v_materials numeric(12,2);
  v_total numeric(12,2);
begin
  if new.payment_status = 'paid'
     and new.status = 'completed'
     and new.quote_status = 'approved'
     and new.assigned_electrician_id is not null
     and new.payment_verified_at is not null
     and new.razorpay_payment_id is not null then
    v_service := round(coalesce(new.service_charge,0),2);
    v_materials := round(coalesce(new.materials_amount,0),2);
    v_total := round(v_service + v_materials,2);
    if round(coalesce(new.amount_paid,0),2) <> v_total then
      raise exception 'Verified payment amount does not match approved quote total; payout ledger not created';
    end if;
    insert into public.srk_electrician_payouts (
      booking_id, electrician_profile_id, razorpay_payment_id,
      gross_service_amount, materials_amount, platform_commission,
      electrician_payable, payout_status
    ) values (
      new.id, new.assigned_electrician_id, new.razorpay_payment_id,
      v_service, v_materials, round(v_service * 0.15,2),
      round(v_service * 0.85,2) + v_materials, 'pending'
    )
    on conflict (booking_id) do update set
      razorpay_payment_id = excluded.razorpay_payment_id,
      gross_service_amount = excluded.gross_service_amount,
      materials_amount = excluded.materials_amount,
      platform_commission = excluded.platform_commission,
      electrician_payable = excluded.electrician_payable,
      updated_at = now()
    where public.srk_electrician_payouts.payout_status = 'pending';
  elsif new.payment_status = 'refunded' then
    update public.srk_electrician_payouts
      set payout_status = 'refunded', updated_at = now()
      where booking_id = new.id and payout_status = 'pending';
  end if;
  return new;
end;
$$;
drop trigger if exists trg_srk_create_electrician_payable on public.service_bookings;
create trigger trg_srk_create_electrician_payable
after insert or update of payment_status, status, quote_status, service_charge, materials_amount, assigned_electrician_id, payment_verified_at, razorpay_payment_id, amount_paid
on public.service_bookings
for each row execute function public.srk_create_electrician_payable();

create or replace function public.srk_admin_mark_electrician_payout_paid(
  p_payout_id uuid,
  p_method text,
  p_reference text,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.srk_electrician_payouts%rowtype;
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'Admin access required';
  end if;
  if p_method not in ('upi','bank') then
    raise exception 'Payout method must be upi or bank';
  end if;
  if p_reference is null or length(trim(p_reference)) < 4 then
    raise exception 'Valid UTR / UPI reference is required';
  end if;
  select * into v_row from public.srk_electrician_payouts
    where id = p_payout_id for update;
  if not found then raise exception 'Payout record not found'; end if;
  if v_row.payout_status <> 'pending' then
    raise exception 'Only pending payouts can be marked paid';
  end if;
  if not exists (
    select 1 from public.service_bookings b
    where b.id = v_row.booking_id
      and b.status = 'completed'
      and b.quote_status = 'approved'
      and b.payment_status = 'paid'
      and b.payment_verified_at is not null
      and b.razorpay_payment_id = v_row.razorpay_payment_id
      and round(coalesce(b.amount_paid,0),2) =
          round(coalesce(b.service_charge,0) + coalesce(b.materials_amount,0),2)
  ) then
    raise exception 'Booking payment or completion is not verified; payout blocked';
  end if;
  update public.srk_electrician_payouts
    set payout_status='paid', payout_method=p_method,
        payout_reference=trim(p_reference), payout_note=nullif(trim(p_note),''),
        paid_by=auth.uid(), paid_at=now(), updated_at=now()
    where id=p_payout_id;
  return jsonb_build_object('success',true,'payout_id',p_payout_id,'status','paid');
end;
$$;
revoke all on function public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text) from public, anon;
grant execute on function public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text) to authenticated;
revoke all on function public.srk_create_electrician_payable() from public, anon, authenticated;
