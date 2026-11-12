-- Cash Platform Fee Due + next-online-booking settlement.
-- Cash receipts remain direct between customer and electrician. SRK records the
-- 15% labour-only fee as due; a later verified online booking settles that due
-- from the electrician's share, never by adding a surcharge to the customer.
alter table public.srk_electrician_payouts
  add column if not exists previous_platform_fee_settled numeric(12,2) not null default 0;

alter table public.srk_electrician_payouts
  add constraint srk_payout_previous_fee_nonnegative
  check (previous_platform_fee_settled >= 0);

create table if not exists public.srk_platform_fee_ledger (
  id uuid primary key default gen_random_uuid(),
  electrician_profile_id uuid not null references public.electrician_profiles(id) on delete restrict,
  booking_id uuid not null references public.service_bookings(id) on delete restrict,
  entry_type text not null check (entry_type in (
    'cash_due','cash_due_reversal','online_fee','cash_due_settlement',
    'cash_due_restore','online_fee_reversal'
  )),
  amount numeric(12,2) not null check (amount > 0),
  idempotency_key text not null unique,
  note text,
  created_by uuid references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint srk_platform_fee_ledger_note_length check (note is null or length(note) <= 250)
);

create index if not exists srk_platform_fee_ledger_partner_created_idx
  on public.srk_platform_fee_ledger(electrician_profile_id, created_at desc);
create index if not exists srk_platform_fee_ledger_booking_idx
  on public.srk_platform_fee_ledger(booking_id);

alter table public.srk_platform_fee_ledger enable row level security;
revoke all on public.srk_platform_fee_ledger from public, anon, authenticated;

comment on table public.srk_platform_fee_ledger is
'Immutable audit ledger for cash Platform Fee due and deductions from later verified online booking receipts. Amounts are labour-only.';

create or replace function public.srk_create_electrician_payable()
returns trigger
language plpgsql
security definer
set search_path to 'pg_catalog', 'public', 'auth', 'pg_temp'
as $function$
declare
  v_service numeric(12,2);
  v_materials numeric(12,2);
  v_total numeric(12,2);
  v_rate numeric(7,2);
  v_current_fee numeric(12,2);
  v_previous_due numeric(12,2);
  v_previous_settled numeric(12,2);
  v_profile_id uuid;
  v_is_cash boolean;
begin
  if new.payment_status = 'paid'
     and new.status = 'completed'
     and new.quote_status = 'approved'
     and new.assigned_electrician_id is not null
     and new.payment_verified_at is not null
     and (
       new.razorpay_payment_id is not null
       or exists (
         select 1 from public.srk_manual_payment_entries e
          where e.booking_id = new.id
            and round(coalesce(e.amount,0),2) = round(coalesce(new.amount_paid,0),2)
       )
     ) then
    v_profile_id := new.assigned_electrician_id;
    v_service := round(coalesce(new.service_charge,0),2);
    v_materials := round(coalesce(new.materials_amount,0),2);
    v_total := round(v_service + v_materials,2);
    v_rate := new.commission_rate;

    if v_rate is null or v_rate < 0 or v_rate > 100 then
      raise exception 'Platform Fee rate must be between 0 and 100';
    end if;
    if v_service <= 0 or round(coalesce(new.amount_paid,0),2) <> v_total then
      raise exception 'Verified payment amount does not match approved quote total';
    end if;

    v_current_fee := round(v_service * v_rate / 100,2);
    v_is_cash := lower(coalesce(new.payment_method,'')) like '%cash%'
                 or lower(coalesce(new.payment_method,'')) like '%नकद%';

    if v_is_cash then
      -- Cash is paid directly to the electrician; no SRK payout is created.
      -- The fee becomes a due balance, once per booking.
      insert into public.srk_platform_fee_ledger
        (electrician_profile_id,booking_id,entry_type,amount,idempotency_key,note,created_by)
      values
        (v_profile_id,new.id,'cash_due',v_current_fee,
         'cash_due:'||new.id::text,
         'Cash booking: labour-only Platform Fee due',auth.uid())
      on conflict (idempotency_key) do nothing;
    else
      -- Serialize financial settlement per electrician without taking a profile
      -- row lock (booking rows are already locked by the payment update).
      perform pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtextextended(v_profile_id::text, 0)
      );

      -- A repeated webhook/update must not recalculate a previously posted split.
      if not exists (
        select 1 from public.srk_platform_fee_ledger
         where idempotency_key = 'online_fee:'||new.id::text
      ) then
        select greatest(
          coalesce(sum(case
            when entry_type in ('cash_due','cash_due_restore') then amount
            when entry_type in ('cash_due_reversal','cash_due_settlement') then -amount
            else 0 end),0),0
        ) into v_previous_due
          from public.srk_platform_fee_ledger
         where electrician_profile_id = v_profile_id;

        -- Current fee is always reserved first. Old cash dues are collected
        -- only from the remaining electrician share, so the payout never goes
        -- negative and any unpaid balance carries forward.
        v_previous_settled := least(
          coalesce(v_previous_due,0),
          greatest(v_service + v_materials - v_current_fee,0)
        );

        insert into public.srk_platform_fee_ledger
          (electrician_profile_id,booking_id,entry_type,amount,idempotency_key,note,created_by)
        values
          (v_profile_id,new.id,'online_fee',v_current_fee,
           'online_fee:'||new.id::text,
           'Current booking Platform Fee collected from verified online receipt',auth.uid())
        on conflict (idempotency_key) do nothing;

        if v_previous_settled > 0 then
          insert into public.srk_platform_fee_ledger
            (electrician_profile_id,booking_id,entry_type,amount,idempotency_key,note,created_by)
          values
            (v_profile_id,new.id,'cash_due_settlement',v_previous_settled,
             'cash_due_settlement:'||new.id::text,
             'Previous cash Platform Fee due deducted from online receipt',auth.uid())
          on conflict (idempotency_key) do nothing;
        end if;

        insert into public.srk_electrician_payouts (
          booking_id,electrician_profile_id,razorpay_payment_id,
          gross_service_amount,materials_amount,platform_commission,
          previous_platform_fee_settled,electrician_payable,payout_status
        ) values (
          new.id,v_profile_id,new.razorpay_payment_id,
          v_service,v_materials,round(v_current_fee+v_previous_settled,2),
          v_previous_settled,
          greatest(round(v_total-v_current_fee-v_previous_settled,2),0),
          'pending'
        )
        on conflict (booking_id) do update set
          electrician_profile_id = excluded.electrician_profile_id,
          razorpay_payment_id = excluded.razorpay_payment_id,
          gross_service_amount = excluded.gross_service_amount,
          materials_amount = excluded.materials_amount,
          platform_commission = excluded.platform_commission,
          previous_platform_fee_settled = excluded.previous_platform_fee_settled,
          electrician_payable = excluded.electrician_payable,
          updated_at = now()
        where public.srk_electrician_payouts.payout_status = 'pending';
      end if;
    end if;

  elsif new.payment_status = 'refunded' then
    -- Refund reversals are immutable and idempotent. A refunded cash booking
    -- cancels its due; an online refund restores any old cash due it had settled.
    insert into public.srk_platform_fee_ledger
      (electrician_profile_id,booking_id,entry_type,amount,idempotency_key,note,created_by)
    select electrician_profile_id,booking_id,'cash_due_reversal',amount,
           'cash_due_reversal:'||booking_id::text,
           'Cash booking refunded; corresponding fee due reversed',auth.uid()
      from public.srk_platform_fee_ledger
     where booking_id = new.id and entry_type = 'cash_due'
    on conflict (idempotency_key) do nothing;

    insert into public.srk_platform_fee_ledger
      (electrician_profile_id,booking_id,entry_type,amount,idempotency_key,note,created_by)
    select electrician_profile_id,booking_id,'cash_due_restore',amount,
           'cash_due_restore:'||booking_id::text,
           'Online booking refunded; previously settled cash fee due restored',auth.uid()
      from public.srk_platform_fee_ledger
     where booking_id = new.id and entry_type = 'cash_due_settlement'
    on conflict (idempotency_key) do nothing;

    insert into public.srk_platform_fee_ledger
      (electrician_profile_id,booking_id,entry_type,amount,idempotency_key,note,created_by)
    select electrician_profile_id,booking_id,'online_fee_reversal',amount,
           'online_fee_reversal:'||booking_id::text,
           'Online booking refunded; current Platform Fee reversed',auth.uid()
      from public.srk_platform_fee_ledger
     where booking_id = new.id and entry_type = 'online_fee'
    on conflict (idempotency_key) do nothing;

    update public.srk_electrician_payouts
       set payout_status = 'refunded',updated_at = now()
     where booking_id = new.id and payout_status = 'pending';
  end if;
  return new;
end;
$function$;

revoke all on function public.srk_create_electrician_payable() from public, anon, authenticated;

create or replace function public.srk_get_my_platform_fee_summary()
returns jsonb
language plpgsql
stable
security definer
set search_path to 'pg_catalog', 'public', 'auth', 'pg_temp'
as $function$
declare
  v_profile_id uuid;
  v_due numeric(12,2);
  v_entries jsonb;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  select id into v_profile_id
    from public.electrician_profiles
   where (user_id = auth.uid() or auth_user_id = auth.uid())
     and verification_status = 'approved'
   order by created_at desc limit 1;
  if v_profile_id is null then
    raise exception 'Approved electrician profile required' using errcode = '42501';
  end if;

  select greatest(coalesce(sum(case
    when entry_type in ('cash_due','cash_due_restore') then amount
    when entry_type in ('cash_due_reversal','cash_due_settlement') then -amount
    else 0 end),0),0)
    into v_due
    from public.srk_platform_fee_ledger
   where electrician_profile_id = v_profile_id;

  select coalesce(jsonb_agg(x.row_data order by x.created_at desc),'[]'::jsonb)
    into v_entries
    from (
      select created_at,
        jsonb_build_object(
          'booking_id',booking_id,
          'entry_type',entry_type,
          'amount',amount,
          'note',note,
          'created_at',created_at
        ) as row_data
        from public.srk_platform_fee_ledger
       where electrician_profile_id = v_profile_id
       order by created_at desc limit 20
    ) x;

  return jsonb_build_object('outstanding_due',round(coalesce(v_due,0),2),'entries',v_entries);
end;
$function$;

revoke all on function public.srk_get_my_platform_fee_summary() from public, anon;
grant execute on function public.srk_get_my_platform_fee_summary() to authenticated;

create or replace function public.srk_admin_commission_report()
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog', 'public', 'auth', 'pg_temp'
as $function$
declare
  v_result jsonb;
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'Admin access required' using errcode = '42501';
  end if;

  with paid_completed as (
    select assigned_electrician_id,
           coalesce(amount_paid,0)::numeric as gross,
           coalesce(commission_amount,0)::numeric as commission
      from public.service_bookings
     where status = 'completed' and payment_status = 'paid'
  ),
  fee_due as (
    select electrician_profile_id,
      greatest(coalesce(sum(case
        when entry_type in ('cash_due','cash_due_restore') then amount
        when entry_type in ('cash_due_reversal','cash_due_settlement') then -amount
        else 0 end),0),0)::numeric as due,
      coalesce(sum(case when entry_type in ('online_fee','cash_due_settlement') then amount when entry_type in ('online_fee_reversal','cash_due_restore') then -amount else 0 end),0)::numeric as collected,
      coalesce(sum(case when entry_type = 'online_fee' then amount else 0 end),0)::numeric as current_online_fee
    from public.srk_platform_fee_ledger
    group by electrician_profile_id
  ),
  totals as (
    select coalesce(sum(gross),0)::numeric as collected,
           coalesce(sum(commission),0)::numeric as commission,
           coalesce((select sum(due) from fee_due),0)::numeric as platform_fee_due,
           coalesce((select sum(collected) from fee_due),0)::numeric as platform_fee_collected
      from paid_completed
  ),
  partners as (
    select p.id as electrician_id,
           p.display_name,
           count(pc.*)::integer as paid_completed_jobs,
           coalesce(sum(pc.gross),0)::numeric as gross_received,
           coalesce(sum(pc.commission),0)::numeric as company_commission,
           coalesce(sum(pc.gross-pc.commission),0)::numeric as electrician_earning,
           coalesce(fd.due,0)::numeric as platform_fee_due,
           coalesce(fd.collected,0)::numeric as platform_fee_collected
      from public.electrician_profiles p
      left join paid_completed pc on pc.assigned_electrician_id = p.id
      left join fee_due fd on fd.electrician_profile_id = p.id
     group by p.id,p.display_name,fd.due,fd.collected
     order by p.display_name
  )
  select jsonb_build_object(
    'total_collected',t.collected,
    'total_commission',t.commission,
    'total_electrician_payable',t.collected-t.commission,
    'total_platform_fee_due',t.platform_fee_due,
    'total_platform_fee_collected',t.platform_fee_collected,
    'partners',coalesce((select jsonb_agg(to_jsonb(partners)) from partners),'[]'::jsonb)
  ) into v_result
    from totals t;
  return v_result;
end;
$function$;

-- Keep the existing Admin-only payout confirmation gate, but validate the
-- total fee as current fee plus the previous cash dues actually settled.
create or replace function public.srk_admin_mark_electrician_payout_paid(
  p_payout_id uuid,p_method text,p_reference text,p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog', 'public', 'auth', 'pg_temp'
as $function$
declare
  v_row public.srk_electrician_payouts%rowtype;
  v_booking_id uuid;
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'Admin access required' using errcode = '42501';
  end if;
  if p_payout_id is null then raise exception 'Payout ID is required'; end if;
  if p_method is null or p_method not in ('upi','bank') then
    raise exception 'Payout method must be upi or bank';
  end if;
  if p_reference is null or length(btrim(p_reference)) < 4 or length(btrim(p_reference)) > 120 then
    raise exception 'Valid UTR / UPI reference is required';
  end if;
  if p_note is not null and length(p_note) > 250 then raise exception 'Payout note is too long'; end if;

  select booking_id into v_booking_id
    from public.srk_electrician_payouts where id = p_payout_id;
  if not found or v_booking_id is null then raise exception 'Payout record not found or has no booking'; end if;

  perform 1 from public.service_bookings where id = v_booking_id for update;
  if not found then raise exception 'Payout booking not found'; end if;

  select * into v_row from public.srk_electrician_payouts
   where id = p_payout_id for update;
  if not found or v_row.booking_id is distinct from v_booking_id then
    raise exception 'Payout record changed; retry the operation';
  end if;
  if v_row.payout_status <> 'pending' then raise exception 'Only pending payouts can be marked paid'; end if;

  if not exists (
    select 1 from public.service_bookings b
     where b.id = v_row.booking_id
       and b.status = 'completed'
       and b.quote_status = 'approved'
       and b.payment_status = 'paid'
       and b.payment_verified_at is not null
       and (
         (v_row.razorpay_payment_id is not null and b.razorpay_payment_id = v_row.razorpay_payment_id)
         or
         (v_row.razorpay_payment_id is null and b.razorpay_payment_id is null
          and exists (select 1 from public.srk_manual_payment_entries e
            where e.booking_id = b.id
              and round(coalesce(e.amount,0),2)=round(coalesce(b.amount_paid,0),2)))
       )
       and b.assigned_electrician_id = v_row.electrician_profile_id
       and round(coalesce(b.amount_paid,0),2)=round(coalesce(b.service_charge,0)+coalesce(b.materials_amount,0),2)
       and round(coalesce(v_row.gross_service_amount,0),2)=round(coalesce(b.service_charge,0),2)
       and round(coalesce(v_row.materials_amount,0),2)=round(coalesce(b.materials_amount,0),2)
       and round(coalesce(v_row.previous_platform_fee_settled,0),2)=
           round(coalesce((select sum(e.amount) from public.srk_platform_fee_ledger e
             where e.booking_id=b.id and e.entry_type='cash_due_settlement'),0),2)
       and round(coalesce(v_row.platform_commission,0),2)=
           round(coalesce(b.service_charge,0)*b.commission_rate/100,2)+
           round(coalesce(v_row.previous_platform_fee_settled,0),2)
       and round(coalesce(v_row.electrician_payable,0),2)=
           greatest(round(coalesce(b.service_charge,0)+coalesce(b.materials_amount,0)-
             round(coalesce(b.service_charge,0)*b.commission_rate/100,2)-
             coalesce(v_row.previous_platform_fee_settled,0),2),0)
  ) then
    raise exception 'Booking payment or payout ledger does not match verified booking; payout blocked';
  end if;

  update public.srk_electrician_payouts
     set payout_status='paid',payout_method=p_method,
         payout_reference=btrim(p_reference),
         payout_note=nullif(btrim(p_note),''),
         paid_by=auth.uid(),paid_at=now(),updated_at=now()
   where id=p_payout_id;

  return jsonb_build_object('success',true,'payout_id',p_payout_id,'status','paid');
end;
$function$;

revoke all on function public.srk_admin_commission_report() from public, anon;
grant execute on function public.srk_admin_commission_report() to authenticated;
revoke all on function public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text) from public, anon;
grant execute on function public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text) to authenticated;
