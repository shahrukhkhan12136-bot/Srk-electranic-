-- SRK ELECTRONIC electrician home-inspection quote workflow.
alter table public.service_bookings
  add column if not exists service_charge numeric(12,2),
  add column if not exists materials_amount numeric(12,2) not null default 0,
  add column if not exists quote_status text not null default 'not_submitted',
  add column if not exists quote_note text,
  add column if not exists quote_submitted_at timestamptz,
  add column if not exists quote_responded_at timestamptz,
  add column if not exists work_started_at timestamptz;
alter table public.service_bookings
  add constraint service_bookings_service_charge_nonnegative check (service_charge is null or service_charge >= 0),
  add constraint service_bookings_materials_amount_nonnegative check (materials_amount >= 0),
  add constraint service_bookings_quote_status_valid check (quote_status in ('not_submitted','pending','approved','rejected'));
create or replace function public.srk_calculate_booking_commission()
returns trigger language plpgsql set search_path to 'pg_catalog','public','pg_temp'
as $function$
begin
 if new.amount_paid is not null and new.amount_paid < 0 then raise exception 'amount_paid cannot be negative'; end if;
 if new.commission_rate is null or new.commission_rate < 0 or new.commission_rate > 100 then raise exception 'commission_rate must be between 0 and 100'; end if;
 if new.service_charge is not null and new.service_charge < 0 then raise exception 'service_charge cannot be negative'; end if;
 if new.status='completed' and new.payment_status='paid' and new.amount_paid is not null and new.service_charge is not null
 then new.commission_amount:=round(new.service_charge*new.commission_rate/100,2);
 else new.commission_amount:=null; end if;
 return new;
end;$function$;
create or replace function public.srk_submit_booking_quote(p_booking_id uuid,p_service_charge numeric,p_materials_amount numeric,p_quote_note text default null)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog','public','auth','pg_temp'
as $function$
declare v_profile_id uuid; v_booking public.service_bookings%rowtype;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if p_booking_id is null or p_service_charge is null or p_service_charge<=0 or p_materials_amount is null or p_materials_amount<0 or p_service_charge>10000000 or p_materials_amount>10000000 then raise exception 'Invalid quote amounts'; end if;
 select id into v_profile_id from public.electrician_profiles where user_id=auth.uid() and verification_status='approved' and active=true;
 if v_profile_id is null then raise exception 'Approved active electrician required'; end if;
 select * into v_booking from public.service_bookings where id=p_booking_id and assigned_electrician_id=v_profile_id for update;
 if not found then raise exception 'Assigned booking not found'; end if;
 if v_booking.status not in ('assigned','inspection','quote_rejected') then raise exception 'Booking is not ready for a quote'; end if;
 update public.service_bookings set service_charge=round(p_service_charge,2),materials_amount=round(p_materials_amount,2),
 quoted_amount=round(p_service_charge+p_materials_amount,2),quote_note=left(coalesce(p_quote_note,''),1000),
 quote_status='pending',quote_submitted_at=now(),quote_responded_at=null,status='awaiting_quote_approval' where id=p_booking_id;
 return jsonb_build_object('success',true,'total',round(p_service_charge+p_materials_amount,2),'quote_status','pending');
end;$function$;
create or replace function public.srk_customer_respond_booking_quote(p_booking_id uuid,p_response text)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog','public','auth','pg_temp'
as $function$
declare v_booking public.service_bookings%rowtype;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if p_response not in ('approved','rejected') then raise exception 'Invalid quote response'; end if;
 select * into v_booking from public.service_bookings where id=p_booking_id and customer_user_id=auth.uid() for update;
 if not found then raise exception 'Customer booking not found'; end if;
 if v_booking.status<>'awaiting_quote_approval' or v_booking.quote_status<>'pending' then raise exception 'No quote is waiting for approval'; end if;
 update public.service_bookings set quote_status=p_response,quote_responded_at=now(),
 status=case when p_response='approved' then 'quote_approved' else 'quote_rejected' end where id=p_booking_id;
 return jsonb_build_object('success',true,'quote_status',p_response);
end;$function$;
create or replace function public.srk_update_booking_work_status(p_booking_id uuid,p_status text)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog','public','auth','pg_temp'
as $function$
declare v_profile_id uuid; v_booking public.service_bookings%rowtype;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if p_status not in ('inspection','in_progress','completed') then raise exception 'Invalid work status'; end if;
 select id into v_profile_id from public.electrician_profiles where user_id=auth.uid() and verification_status='approved' and active=true;
 if v_profile_id is null then raise exception 'Approved active electrician required'; end if;
 select * into v_booking from public.service_bookings where id=p_booking_id and assigned_electrician_id=v_profile_id for update;
 if not found then raise exception 'Assigned booking not found'; end if;
 if p_status='inspection' and v_booking.status='assigned' then update public.service_bookings set status='inspection' where id=p_booking_id;
 elsif p_status='in_progress' and v_booking.status='quote_approved' and v_booking.quote_status='approved' then update public.service_bookings set status='in_progress',work_started_at=now() where id=p_booking_id;
 elsif p_status='completed' and v_booking.status='in_progress' then update public.service_bookings set status='completed' where id=p_booking_id;
 else raise exception 'Invalid booking status transition'; end if;
 return jsonb_build_object('success',true,'status',p_status);
end;$function$;
drop function if exists public.srk_get_my_offer_details();
create function public.srk_get_my_offer_details()
returns table(offer_id uuid,offer_status text,match_level text,offer_created_at timestamptz,booking_id uuid,service_type text,state text,district text,pincode text,preferred_date date,preferred_time time,work_details text,quoted_amount numeric,booking_status text,customer_name text,customer_phone text,address text,location_lat double precision,location_lng double precision,service_charge numeric,materials_amount numeric,quote_status text,quote_note text)
language sql stable security definer set search_path to 'pg_catalog','public','auth','pg_temp'
as $function$
 select o.id,o.status,o.match_level,o.created_at,b.id,b.service_type,b.state,b.district,b.pincode,b.preferred_date,b.preferred_time,b.work_details,b.quoted_amount,b.status,
 case when b.assigned_electrician_id=p.id then b.customer_name else null end,
 case when b.assigned_electrician_id=p.id then b.phone else null end,
 case when b.assigned_electrician_id=p.id then b.address else null end,
 case when b.assigned_electrician_id=p.id then b.location_lat else null end,
 case when b.assigned_electrician_id=p.id then b.location_lng else null end,
 case when b.assigned_electrician_id=p.id then b.service_charge else null end,
 case when b.assigned_electrician_id=p.id then b.materials_amount else null end,
 case when b.assigned_electrician_id=p.id then b.quote_status else null end,
 case when b.assigned_electrician_id=p.id then b.quote_note else null end
 from public.job_offers o join public.electrician_profiles p on p.id=o.electrician_id join public.service_bookings b on b.id=o.booking_id
 where p.user_id=auth.uid() and p.verification_status='approved' and p.active=true order by o.created_at desc limit 100;
$function$;
revoke all on function public.srk_submit_booking_quote(uuid,numeric,numeric,text) from public,anon;
revoke all on function public.srk_customer_respond_booking_quote(uuid,text) from public,anon;
revoke all on function public.srk_update_booking_work_status(uuid,text) from public,anon;
revoke all on function public.srk_get_my_offer_details() from public,anon;
grant execute on function public.srk_submit_booking_quote(uuid,numeric,numeric,text) to authenticated;
grant execute on function public.srk_customer_respond_booking_quote(uuid,text) to authenticated;
grant execute on function public.srk_update_booking_work_status(uuid,text) to authenticated;
grant execute on function public.srk_get_my_offer_details() to authenticated;
