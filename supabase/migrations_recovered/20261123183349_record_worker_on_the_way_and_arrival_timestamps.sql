
alter table public.srk_booking_workers
  add column if not exists on_the_way_at timestamptz,
  add column if not exists arrived_at timestamptz;

create or replace function public.srk_worker_update_arrival_status(
 p_booking_worker_id uuid,p_status text
)
returns public.srk_booking_workers
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare
 v_assignment public.srk_booking_workers%rowtype;
 v_booking_id uuid;
 v_customer_user_id uuid;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 if p_status not in ('on_the_way','arrived') then raise exception 'Status must be on_the_way or arrived' using errcode='22023'; end if;
 select bw.* into v_assignment
 from public.srk_booking_workers bw
 join public.srk_worker_profiles wp on wp.id=bw.worker_id
 where bw.id=p_booking_worker_id and wp.user_id=auth.uid()
 for update of bw;
 if not found or v_assignment.assignment_status not in ('accepted','assigned','working') then
   raise exception 'Active booking assignment not found' using errcode='42501';
 end if;
 if p_status='on_the_way' then
   update public.srk_booking_workers set on_the_way_at=coalesce(on_the_way_at,clock_timestamp()),updated_at=clock_timestamp()
   where id=p_booking_worker_id returning * into v_assignment;
 else
   update public.srk_booking_workers set on_the_way_at=coalesce(on_the_way_at,clock_timestamp()),
     arrived_at=coalesce(arrived_at,clock_timestamp()),updated_at=clock_timestamp()
   where id=p_booking_worker_id returning * into v_assignment;
 end if;
 select b.id,b.customer_user_id into v_booking_id,v_customer_user_id
 from public.service_bookings b where b.id=v_assignment.booking_id;
 if v_customer_user_id is not null then
   insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id,deep_link)
   values(v_customer_user_id,'worker_arrival_status',
     case when p_status='on_the_way' then 'Technician/Helper रास्ते में है' else 'Technician/Helper पहुँच गया है' end,
     case when p_status='on_the_way' then 'आपका assigned worker रास्ते में है।' else 'आपका assigned worker आपके दिए पते पर पहुँच गया है।' end,
     v_booking_id,'/bookings/'||v_booking_id::text);
 end if;
 return v_assignment;
end
$function$;
revoke all on function public.srk_worker_update_arrival_status(uuid,text) from public,anon;
grant execute on function public.srk_worker_update_arrival_status(uuid,text) to authenticated;
