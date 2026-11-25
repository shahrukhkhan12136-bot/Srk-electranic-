
do $migration$
declare v_def text; v_old text; v_new text;
begin
 v_def:=pg_get_functiondef('public.srk_customer_create_booking(uuid,uuid,uuid,integer,integer,integer,text,text,text,text,double precision,double precision,double precision,double precision,numeric,uuid)'::regprocedure);
 v_old:=' v_settings_snapshot jsonb;';
 v_new:=' v_settings_snapshot jsonb;
 v_pending_fee_amount numeric(12,2):=0;';
 if position(v_old in v_def)=0 then raise exception 'Booking pending fee variable point not found'; end if;
 v_def:=replace(v_def,v_old,v_new);

 v_old:=' if v_booking.requested_skill_level_id is not null then
   insert into public.srk_booking_skill_level_events(booking_id,actor_user_id,event_type,to_skill_level_id,reason)
   values(v_booking.id,auth.uid(),''requested_level_selected'',v_booking.requested_skill_level_id,''Qualification level selected/defaulted at booking creation'');
 end if;
 return v_booking;';
 v_new:=' if v_booking.requested_skill_level_id is not null then
   insert into public.srk_booking_skill_level_events(booking_id,actor_user_id,event_type,to_skill_level_id,reason)
   values(v_booking.id,auth.uid(),''requested_level_selected'',v_booking.requested_skill_level_id,''Qualification level selected/defaulted at booking creation'');
 end if;
 update public.srk_booking_cancellation_fees
 set status=''added_to_next_booking'',next_booking_id=v_booking.id,added_to_next_booking_at=clock_timestamp()
 where customer_user_id=auth.uid() and status=''pending'';
 select coalesce(sum(fee_amount),0) into v_pending_fee_amount
 from public.srk_booking_cancellation_fees
 where next_booking_id=v_booking.id and status=''added_to_next_booking'';
 if v_pending_fee_amount>0 then
   update public.service_bookings set pending_cancellation_fee_amount=v_pending_fee_amount
   where id=v_booking.id returning * into v_booking;
 end if;
 return v_booking;';
 if position(v_old in v_def)=0 then raise exception 'Booking creation fee attachment point not found'; end if;
 v_def:=replace(v_def,v_old,v_new);
 execute v_def;
end
$migration$;
