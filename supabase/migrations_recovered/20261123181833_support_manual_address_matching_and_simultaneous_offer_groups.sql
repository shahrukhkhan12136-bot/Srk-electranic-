
do $migration$
declare v_def text; v_old text; v_new text;
begin
  v_def:=pg_get_functiondef('public.srk_find_eligible_workers(uuid,text)'::regprocedure);
  v_old:='if v_booking.booking_latitude is null or v_booking.booking_longitude is null then raise exception ''Booking GPS required''; end if;';
  if position(v_old in v_def)=0 then raise exception 'GPS-only matching guard not found'; end if;
  v_def:=replace(v_def,v_old,'');

  v_old:='round((6371*acos(least(1,greatest(-1,
      cos(radians(v_booking.booking_latitude))*cos(radians(w.location_lat))*cos(radians(w.location_lng)-radians(v_booking.booking_longitude))+
      sin(radians(v_booking.booking_latitude))*sin(radians(w.location_lat))
    ))))::numeric,2)';
  v_new:='case when v_booking.booking_latitude is null then null::numeric else round((6371*acos(least(1,greatest(-1,
      cos(radians(v_booking.booking_latitude))*cos(radians(w.location_lat))*cos(radians(w.location_lng)-radians(v_booking.booking_longitude))+
      sin(radians(v_booking.booking_latitude))*sin(radians(w.location_lat))
    ))))::numeric,2) end';
  if position(v_old in v_def)=0 then raise exception 'Worker distance projection not found'; end if;
  v_def:=replace(v_def,v_old,v_new);

  v_old:='and (6371*acos(least(1,greatest(-1,
      cos(radians(v_booking.booking_latitude))*cos(radians(w.location_lat))*cos(radians(w.location_lng)-radians(v_booking.booking_longitude))+
      sin(radians(v_booking.booking_latitude))*sin(radians(w.location_lat))
    ))))<=least(30,w.service_radius_km)';
  v_new:='and ((v_booking.booking_latitude is not null and (6371*acos(least(1,greatest(-1,
      cos(radians(v_booking.booking_latitude))*cos(radians(w.location_lat))*cos(radians(w.location_lng)-radians(v_booking.booking_longitude))+
      sin(radians(v_booking.booking_latitude))*sin(radians(w.location_lat))
    ))))<=least(30,w.service_radius_km))
    or (v_booking.booking_latitude is null and
      (w.pincode=v_booking.pincode or
       (lower(trim(w.state))=lower(trim(v_booking.state)) and lower(trim(w.district))=lower(trim(v_booking.district))))))';
  if position(v_old in v_def)=0 then raise exception 'Worker radius filter not found'; end if;
  v_def:=replace(v_def,v_old,v_new);

  v_old:='order by 4,w.created_at;';
  v_new:='order by case when v_booking.booking_latitude is null and w.pincode=v_booking.pincode then 0 else 1 end,4 nulls last,w.created_at;';
  if position(v_old in v_def)=0 then raise exception 'Candidate ordering not found'; end if;
  v_def:=replace(v_def,v_old,v_new);
  execute v_def;

  v_def:=pg_get_functiondef('public.srk_process_booking_matching_queue()'::regprocedure);
  v_old:='   update public.srk_booking_matching_queue set queue_status=''searching'',attempts=attempts+1,
    last_attempt_at=clock_timestamp(),next_attempt_at=clock_timestamp()+interval ''1 minute'',
    last_error=null,updated_at=clock_timestamp() where booking_id=v_booking.id;
   v_inserted:=v_inserted+1; v_offered:=true; exit;
  end loop;
  if not v_offered then';
  v_new:='   v_inserted:=v_inserted+1; v_offered:=true;
  end loop;
  if v_offered then
   update public.srk_booking_matching_queue set queue_status=''searching'',attempts=attempts+1,
    last_attempt_at=clock_timestamp(),next_attempt_at=clock_timestamp()+interval ''10 minutes'',
    last_error=null,updated_at=clock_timestamp() where booking_id=v_booking.id;
  end if;
  if not v_offered then';
  if position(v_old in v_def)=0 then raise exception 'Single-candidate dispatch block not found'; end if;
  v_def:=replace(v_def,v_old,v_new);
  execute v_def;
end
$migration$;
