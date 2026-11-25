create or replace function public.srk_admin_list_worker_payment_cycles(p_limit integer default 300)
returns table(
 worker_id uuid,
 worker_type text,
 full_name text,
 completed_booking_count bigint,
 next_sequence_number bigint,
 next_booking_requires_online boolean,
 recent_history jsonb
)
language plpgsql
stable
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
begin
 if auth.uid() is null or not (
   public.srk_has_admin_permission('workers.manage')
   or public.srk_has_admin_permission('workers.verify')
   or public.srk_has_admin_permission('payouts.read')
 ) then
   raise exception 'Worker management or payout read permission required' using errcode='42501';
 end if;
 return query
 select w.id,w.worker_type,w.full_name,
   coalesce(c.completed_booking_count,0)::bigint,
   coalesce(c.completed_booking_count,0)::bigint+1,
   mod(coalesce(c.completed_booking_count,0)::bigint+1,3)=0,
   coalesce(h.items,'[]'::jsonb)
 from public.srk_worker_profiles w
 left join public.srk_technician_booking_cycle c
   on w.worker_type='technician' and c.technician_id=w.id
 left join public.srk_helper_booking_cycle hc
   on w.worker_type='helper' and hc.helper_id=w.id
 left join lateral (
   select coalesce(jsonb_agg(jsonb_build_object(
     'sequence_number',x.sequence_number,
     'booking_id',x.booking_id,
     'payment_method',x.payment_method,
     'completed_at',x.completed_at
   ) order by x.sequence_number desc),'[]'::jsonb) as items
   from (
     select s.sequence_number,s.booking_id,s.payment_method,s.completed_at
     from public.srk_technician_booking_sequence s
     where w.worker_type='technician' and s.technician_id=w.id
     union all
     select s.sequence_number,s.booking_id,s.payment_method,s.completed_at
     from public.srk_helper_booking_sequence s
     where w.worker_type='helper' and s.helper_id=w.id
     order by sequence_number desc limit 6
   ) x
 ) h on true
 where w.worker_type in ('technician','helper')
 order by w.created_at desc
 limit greatest(1,least(coalesce(p_limit,300),1000));
end
$function$;
revoke all on function public.srk_admin_list_worker_payment_cycles(integer) from public, anon;
grant execute on function public.srk_admin_list_worker_payment_cycles(integer) to authenticated;