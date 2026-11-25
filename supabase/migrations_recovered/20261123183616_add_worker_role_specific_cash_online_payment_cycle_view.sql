
create or replace function public.srk_worker_get_my_payment_cycle()
returns table(
 worker_id uuid,worker_role text,completed_booking_count bigint,
 next_sequence_number bigint,next_booking_requires_online boolean
)
language plpgsql
stable
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare v_worker public.srk_worker_profiles%rowtype; v_count bigint:=0;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 select * into v_worker from public.srk_worker_profiles where user_id=auth.uid() and is_active;
 if not found then raise exception 'Active worker profile not found' using errcode='42501'; end if;
 if v_worker.worker_type='technician' then
   select coalesce(c.completed_booking_count,0) into v_count
   from public.srk_technician_booking_cycle c where c.technician_id=v_worker.id;
 else
   select coalesce(c.completed_booking_count,0) into v_count
   from public.srk_helper_booking_cycle c where c.helper_id=v_worker.id;
 end if;
 v_count:=coalesce(v_count,0);
 return query select v_worker.id,v_worker.worker_type,v_count,v_count+1,mod(v_count+1,3)=0;
end
$function$;
revoke all on function public.srk_worker_get_my_payment_cycle() from public,anon;
grant execute on function public.srk_worker_get_my_payment_cycle() to authenticated;
