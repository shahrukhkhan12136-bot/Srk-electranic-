create or replace function public.srk_stop_booking_location_share(p_share_id uuid)
returns boolean
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $function$
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode='42501';
  end if;

  update public.srk_booking_location_shares sh
  set ended_at=clock_timestamp()
  where sh.id=p_share_id
    and sh.ended_at is null
    and (
      sh.started_by=auth.uid()
      or public.srk_has_admin_permission('bookings.manage')
      or public.srk_has_admin_permission('support.manage')
      or exists(
        select 1 from public.service_bookings b
        where b.id=sh.booking_id
          and b.customer_user_id=auth.uid()
          and b.status in ('assigned','in_progress')
      )
      or exists(
        select 1 from public.srk_booking_workers bw
        join public.srk_worker_profiles w on w.id=bw.worker_id
        where bw.booking_id=sh.booking_id
          and w.user_id=auth.uid()
          and bw.assignment_status in ('accepted','assigned','working','paused')
      )
    );

  return found;
end
$function$;

revoke all on function public.srk_stop_booking_location_share(uuid) from public,anon;
grant execute on function public.srk_stop_booking_location_share(uuid) to authenticated;