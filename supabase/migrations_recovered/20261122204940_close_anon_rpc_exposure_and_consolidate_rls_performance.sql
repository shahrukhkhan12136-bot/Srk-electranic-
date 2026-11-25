
drop function if exists public.srk_admin_moderate_booking_rating(uuid,text);
revoke all on function public.srk_admin_moderate_booking_rating(uuid,text,text) from public,anon;
grant execute on function public.srk_admin_moderate_booking_rating(uuid,text,text) to authenticated;
revoke all on function public.srk_hold_worker_earnings_for_refund() from public,anon,authenticated;

drop policy if exists srk_admin_read_service_booking_history on public.service_booking_status_history;
drop policy if exists srk_admin_or_customer_read_bookings on public.service_bookings;
drop policy if exists srk_worker_read_assigned_bookings on public.service_bookings;
create policy srk_booking_participant_read on public.service_bookings
for select to authenticated using(
  public.is_srk_admin()
  or customer_user_id=(select auth.uid())
  or public.srk_has_admin_permission('bookings.manage')
  or exists(select 1 from public.srk_booking_workers bw join public.srk_worker_profiles w on w.id=bw.worker_id
    where bw.booking_id=service_bookings.id and w.user_id=(select auth.uid()))
);

drop policy if exists srk_schedule_events_participant on public.srk_booking_schedule_events;
drop policy if exists srk_schedule_proposals_participant on public.srk_booking_schedule_proposals;
drop policy if exists srk_offline_timer_participant_read on public.srk_worker_offline_timer_events;

do $$
declare r record; v_using text; v_check text; v_sql text;
begin
  for r in
    select n.nspname schema_name,c.relname table_name,p.polname policy_name,
      pg_get_expr(p.polqual,p.polrelid) using_expr,
      pg_get_expr(p.polwithcheck,p.polrelid) check_expr
    from pg_policy p
    join pg_class c on c.oid=p.polrelid
    join pg_namespace n on n.oid=c.relnamespace
    where n.nspname in ('public','storage')
      and (coalesce(pg_get_expr(p.polqual,p.polrelid),'') ~ 'auth\.(uid|jwt|role)\(\)'
        or coalesce(pg_get_expr(p.polwithcheck,p.polrelid),'') ~ 'auth\.(uid|jwt|role)\(\)')
  loop
    v_using:=replace(replace(replace(r.using_expr,'auth.uid()','(select auth.uid())'),
      'auth.jwt()','(select auth.jwt())'),'auth.role()','(select auth.role())');
    v_check:=replace(replace(replace(r.check_expr,'auth.uid()','(select auth.uid())'),
      'auth.jwt()','(select auth.jwt())'),'auth.role()','(select auth.role())');
    v_sql:=format('alter policy %I on %I.%I',r.policy_name,r.schema_name,r.table_name);
    if r.using_expr is not null then v_sql:=v_sql||format(' using (%s)',v_using); end if;
    if r.check_expr is not null then v_sql:=v_sql||format(' with check (%s)',v_check); end if;
    execute v_sql;
  end loop;
end $$;
