
do $migration$
declare v_def text; v_old text; v_new text;
begin
 -- Customer cancellation policy values are frozen in each booking snapshot.
 v_def:=pg_get_functiondef('public.srk_customer_cancel_booking_v2(uuid,text)'::regprocedure);
 v_old:=' v_fee_basis text;
begin';
 v_new:=' v_fee_basis text;
 v_free_minutes integer;
 v_on_way_fee numeric(12,2);
 v_arrived_fee numeric(12,2);
begin';
 if position(v_old in v_def)=0 then raise exception 'Cancellation policy declarations not found'; end if;
 v_def:=replace(v_def,v_old,v_new);
 v_old:=' if v.status not in (''new'',''confirmed'',''assigned'') then';
 v_new:=' v_free_minutes:=coalesce((v.operational_settings_snapshot->>''cancellation_free_window_minutes'')::integer,
   (select (setting_value #>> ''{}'')::integer from public.srk_system_settings where setting_key=''cancellation_free_window_minutes''),5);
 v_on_way_fee:=coalesce((v.operational_settings_snapshot->>''cancellation_technician_on_way_fee'')::numeric,
   (select (setting_value #>> ''{}'')::numeric from public.srk_system_settings where setting_key=''cancellation_technician_on_way_fee''),49);
 v_arrived_fee:=coalesce((v.operational_settings_snapshot->>''cancellation_technician_arrived_fee'')::numeric,
   (select (setting_value #>> ''{}'')::numeric from public.srk_system_settings where setting_key=''cancellation_technician_arrived_fee''),99);
 if v.status not in (''new'',''confirmed'',''assigned'') then';
 if position(v_old in v_def)=0 then raise exception 'Cancellation policy setting point not found'; end if;
 v_def:=replace(v_def,v_old,v_new);
 v_old:='clock_timestamp()>v.created_at+interval ''5 minutes''';
 v_new:='clock_timestamp()>v.created_at+make_interval(mins=>v_free_minutes)';
 if position(v_old in v_def)=0 then raise exception 'Cancellation free window literal not found'; end if;
 v_def:=replace(v_def,v_old,v_new);
 v_old:='v_fee_amount:=99; v_fee_basis:=''technician_arrived'';';
 v_new:='v_fee_amount:=v_arrived_fee; v_fee_basis:=''technician_arrived'';';
 if position(v_old in v_def)=0 then raise exception 'Arrived cancellation fee literal not found'; end if;
 v_def:=replace(v_def,v_old,v_new);
 v_old:='v_fee_amount:=49; v_fee_basis:=''technician_on_the_way'';';
 v_new:='v_fee_amount:=v_on_way_fee; v_fee_basis:=''technician_on_the_way'';';
 if position(v_old in v_def)=0 then raise exception 'On-the-way cancellation fee literal not found'; end if;
 v_def:=replace(v_def,v_old,v_new);
 execute v_def;

 -- No-show waiting period is frozen in the booking snapshot.
 v_def:=pg_get_functiondef('public.srk_customer_report_worker_no_show(uuid,text)'::regprocedure);
 v_old:='declare v_assignment public.srk_booking_workers%rowtype; v_report public.srk_booking_no_show_reports%rowtype;';
 v_new:='declare v_assignment public.srk_booking_workers%rowtype; v_booking public.service_bookings%rowtype;
 v_report public.srk_booking_no_show_reports%rowtype; v_no_show_minutes integer;';
 if position(v_old in v_def)=0 then raise exception 'No-show declaration point not found'; end if;
 v_def:=replace(v_def,v_old,v_new);
 v_old:=' if v_assignment.arrived_at is not null then raise exception ''Worker is already marked arrived''; end if;';
 v_new:=' select * into v_booking from public.service_bookings where id=v_assignment.booking_id;
 v_no_show_minutes:=coalesce((v_booking.operational_settings_snapshot->>''no_show_wait_minutes'')::integer,
   (select (setting_value #>> ''{}'')::integer from public.srk_system_settings where setting_key=''no_show_wait_minutes''),10);
 if v_assignment.arrived_at is not null then raise exception ''Worker is already marked arrived''; end if;';
 if position(v_old in v_def)=0 then raise exception 'No-show booking snapshot insertion point not found'; end if;
 v_def:=replace(v_def,v_old,v_new);
 v_old:='clock_timestamp()+make_interval(mins=>coalesce((select (setting_value #>> ''{}'')::integer from public.srk_system_settings where setting_key=''no_show_wait_minutes''),10))';
 v_new:='clock_timestamp()+make_interval(mins=>v_no_show_minutes)';
 if position(v_old in v_def)=0 then raise exception 'No-show wait interval expression not found'; end if;
 v_def:=replace(v_def,v_old,v_new);
 execute v_def;

 -- Pause duration uses the values frozen for this booking.
 v_def:=pg_get_functiondef('public.srk_worker_session_action(uuid,text,text,text,text)'::regprocedure);
 v_old:='v_now timestamptz:=clock_timestamp(); v_elapsed bigint;';
 v_new:='v_now timestamptz:=clock_timestamp(); v_elapsed bigint; v_booking public.service_bookings%rowtype;';
 if position(v_old in v_def)=0 then raise exception 'Pause function declaration point not found'; end if;
 v_def:=replace(v_def,v_old,v_new);
 v_old:='  if v_user_id is distinct from auth.uid() and not coalesce(public.is_srk_admin(),false) then';
 v_new:='  select * into v_booking from public.service_bookings where id=v_booking_id;
  if v_user_id is distinct from auth.uid() and not coalesce(public.is_srk_admin(),false) then';
 if position(v_old in v_def)=0 then raise exception 'Pause function booking snapshot lookup point not found'; end if;
 v_def:=replace(v_def,v_old,v_new);
 v_old:='v_now+case when p_pause_reason=''lunch'' then interval ''1 hour'' else interval ''2 hours'' end';
 v_new:='v_now+make_interval(mins=>case when p_pause_reason=''lunch''
        then coalesce((v_booking.operational_settings_snapshot->>''lunch_pause_minimum_minutes'')::integer,60)
        else coalesce((v_booking.operational_settings_snapshot->>''other_pause_minimum_minutes'')::integer,120) end)';
 if position(v_old in v_def)=0 then raise exception 'Pause minimum duration literals not found'; end if;
 v_def:=replace(v_def,v_old,v_new);
 execute v_def;
end
$migration$;
