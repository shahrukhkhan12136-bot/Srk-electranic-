
create table if not exists public.srk_helper_booking_cycle (
  helper_id uuid primary key references public.srk_worker_profiles(id) on delete restrict,
  completed_booking_count bigint not null default 0 check (completed_booking_count >= 0),
  last_completed_at timestamptz,
  updated_at timestamptz not null default now()
);
create table if not exists public.srk_helper_booking_sequence (
  id uuid primary key default gen_random_uuid(),
  helper_id uuid not null references public.srk_worker_profiles(id) on delete restrict,
  booking_id uuid not null references public.service_bookings(id) on delete restrict,
  sequence_number bigint not null check (sequence_number > 0),
  payment_method text check (payment_method is null or payment_method in ('cash','online')),
  completed_at timestamptz not null default now(),
  unique(helper_id, booking_id),
  unique(helper_id, sequence_number)
);
create index if not exists srk_helper_booking_sequence_booking_idx
  on public.srk_helper_booking_sequence(booking_id);

alter table public.srk_helper_booking_cycle enable row level security;
alter table public.srk_helper_booking_sequence enable row level security;

create or replace function public.srk_on_booking_payment_completed()
returns trigger
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare
  v_bw record;
  v_count bigint;
  v_next bigint;
  v_method text;
  v_normalized_method text;
  v_payment_done boolean;
begin
  v_payment_done := new.status='completed'
    and lower(coalesce(new.payment_status,'')) in ('paid','completed');
  v_method := lower(coalesce(new.payment_method,''));
  v_normalized_method := case
    when v_method in ('upi','card','online') then 'online'
    when v_method='cash' then 'cash'
    else null
  end;

  if new.status='completed' and old.status is distinct from 'completed' then
    for v_bw in
      select bw.worker_id
      from public.srk_booking_workers bw
      join public.srk_worker_profiles wp on wp.id=bw.worker_id
      where bw.booking_id=new.id
        and bw.worker_role='technician'
        and wp.worker_type='technician'
        and bw.assignment_status in ('completed','released')
      order by bw.worker_id
    loop
      if exists (
        select 1 from public.srk_technician_booking_sequence s
        where s.technician_id=v_bw.worker_id and s.booking_id=new.id
      ) then continue; end if;

      insert into public.srk_technician_booking_cycle(technician_id)
      values(v_bw.worker_id) on conflict(technician_id) do nothing;

      select completed_booking_count into v_count
      from public.srk_technician_booking_cycle
      where technician_id=v_bw.worker_id for update;

      v_next := v_count+1;
      if mod(v_next,3)=0 and v_payment_done and v_normalized_method<>'online' then
        raise exception 'Technician completed booking number % must be paid online',v_next;
      end if;

      update public.srk_technician_booking_cycle
      set completed_booking_count=v_next,last_completed_at=clock_timestamp(),updated_at=clock_timestamp()
      where technician_id=v_bw.worker_id;

      insert into public.srk_technician_booking_sequence(technician_id,booking_id,sequence_number,payment_method)
      values(v_bw.worker_id,new.id,v_next,case when v_payment_done then v_normalized_method else null end);
    end loop;

    -- Helpers have their own independent 1-6 payment sequence.
    for v_bw in
      select bw.worker_id
      from public.srk_booking_workers bw
      join public.srk_worker_profiles wp on wp.id=bw.worker_id
      where bw.booking_id=new.id
        and bw.worker_role='helper'
        and wp.worker_type='helper'
        and bw.assignment_status in ('completed','released')
      order by bw.worker_id
    loop
      if exists (
        select 1 from public.srk_helper_booking_sequence s
        where s.helper_id=v_bw.worker_id and s.booking_id=new.id
      ) then continue; end if;

      insert into public.srk_helper_booking_cycle(helper_id)
      values(v_bw.worker_id) on conflict(helper_id) do nothing;

      select completed_booking_count into v_count
      from public.srk_helper_booking_cycle
      where helper_id=v_bw.worker_id for update;

      v_next := v_count+1;
      if mod(v_next,3)=0 and v_payment_done and v_normalized_method<>'online' then
        raise exception 'Helper completed booking number % must be paid online',v_next;
      end if;

      update public.srk_helper_booking_cycle
      set completed_booking_count=v_next,last_completed_at=clock_timestamp(),updated_at=clock_timestamp()
      where helper_id=v_bw.worker_id;

      insert into public.srk_helper_booking_sequence(helper_id,booking_id,sequence_number,payment_method)
      values(v_bw.worker_id,new.id,v_next,case when v_payment_done then v_normalized_method else null end);
    end loop;
  end if;

  if v_payment_done
     and not (old.status='completed' and lower(coalesce(old.payment_status,'')) in ('paid','completed')) then
    if v_normalized_method is null then
      raise exception 'A valid payment method is required before marking payment completed';
    end if;

    if exists(
      select 1 from public.srk_technician_booking_sequence s
      where s.booking_id=new.id and mod(s.sequence_number,3)=0
        and v_normalized_method<>'online'
    ) then
      raise exception 'Technician booking number 3 or 6 must be paid online';
    end if;
    if exists(
      select 1 from public.srk_helper_booking_sequence s
      where s.booking_id=new.id and mod(s.sequence_number,3)=0
        and v_normalized_method<>'online'
    ) then
      raise exception 'Helper booking number 3 or 6 must be paid online';
    end if;

    update public.srk_technician_booking_sequence
    set payment_method=v_normalized_method where booking_id=new.id;
    update public.srk_helper_booking_sequence
    set payment_method=v_normalized_method where booking_id=new.id;

    update public.srk_worker_earnings
    set payment_method=v_normalized_method,updated_at=clock_timestamp()
    where booking_id=new.id;

    perform public.srk_post_one_worker_earning(e.id)
    from public.srk_worker_earnings e where e.booking_id=new.id;
  end if;
  return new;
end
$function$;
