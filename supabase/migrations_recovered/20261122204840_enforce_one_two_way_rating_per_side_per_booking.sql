
create unique index if not exists srk_one_customer_rating_per_booking
on public.srk_booking_ratings(booking_id,rater_user_id)
where rater_role='customer';

create unique index if not exists srk_one_worker_rating_per_booking
on public.srk_booking_ratings(booking_id,rater_user_id)
where rater_role in ('technician','helper');

create or replace function public.srk_submit_booking_rating(
 p_booking_id uuid,p_rating integer,p_comment text default null,p_target_worker_id uuid default null
) returns public.srk_booking_ratings
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v_booking public.service_bookings%rowtype; v_role text; v_worker uuid; v_target_worker uuid;
  v_rating_row public.srk_booking_ratings%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_rating not between 1 and 5 then raise exception 'Rating must be between 1 and 5'; end if;
  select * into v_booking from public.service_bookings where id=p_booking_id;
  if not found or v_booking.status<>'completed' then raise exception 'Only completed bookings can be rated'; end if;

  if v_booking.customer_user_id=auth.uid() then
    v_role:='customer';
    select bw.worker_id into v_target_worker
    from public.srk_booking_workers bw
    where bw.booking_id=p_booking_id and bw.worker_role='technician' and bw.assignment_status='completed'
    order by bw.accepted_at nulls last,bw.assigned_at limit 1;
    if v_target_worker is null then raise exception 'Completed Technician assignment not found'; end if;
    insert into public.srk_booking_ratings(booking_id,rater_user_id,rater_role,target_worker_id,target_user_id,rating,comment,moderation_status)
    values(p_booking_id,auth.uid(),'customer',v_target_worker,null,p_rating,p_comment,'pending')
    returning * into v_rating_row;
  else
    select w.id,w.worker_type into v_worker,v_role
    from public.srk_booking_workers bw join public.srk_worker_profiles w on w.id=bw.worker_id
    where bw.booking_id=p_booking_id and w.user_id=auth.uid()
      and bw.assignment_status in ('completed','released') limit 1;
    if v_worker is null then raise exception 'Only completed booking workers can rate the customer'; end if;
    insert into public.srk_booking_ratings(booking_id,rater_user_id,rater_role,target_worker_id,target_user_id,rating,comment,moderation_status)
    values(p_booking_id,auth.uid(),v_role,v_worker,v_booking.customer_user_id,p_rating,p_comment,'pending')
    returning * into v_rating_row;
  end if;
  return v_rating_row;
end $$;
