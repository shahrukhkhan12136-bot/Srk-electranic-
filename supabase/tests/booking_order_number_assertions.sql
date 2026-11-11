\set ON_ERROR_STOP on
do $test$
declare n1 text; n2 text; v record; c integer;
begin
 select order_number into n1 from public.service_bookings where id='10000000-0000-0000-0000-000000000001';
 if n1 <> 'SRK-ORD-000011' then raise exception 'Legacy backfill did not continue after existing number: %',n1; end if;
 if (select order_number from public.service_bookings where id='10000000-0000-0000-0000-000000000003') <> 'SRK-ORD-000010' then raise exception 'Existing order number was changed'; end if;
 insert into public.service_bookings(id,customer_name,phone,address)
 values ('10000000-0000-0000-0000-000000000004','New','9000000004','New Address');
 select order_number into n2 from public.service_bookings where id='10000000-0000-0000-0000-000000000004';
 if n2 <> 'SRK-ORD-000012' then raise exception 'New booking number wrong after backfill: %',n2; end if;
 select count(distinct order_number) into c from public.service_bookings;
 if c <> 4 then raise exception 'Order numbers not unique'; end if;
 begin
  update public.service_bookings set order_number='SRK-ORD-999999' where id='10000000-0000-0000-0000-000000000001';
  raise exception 'Immutable order number trigger did not reject update';
 exception when sqlstate '55000' then null; end;
 begin
  insert into public.service_bookings(id,order_number) values('10000000-0000-0000-0000-000000000005','SRK-ORD-000001');
  raise exception 'Unique order number index did not reject duplicate';
 exception when unique_violation then null; end;
end
$test$;
-- Verify the authenticated electrician receives their order number, while customer PII
-- remains hidden until the booking is assigned to that electrician.
begin;
select set_config('request.jwt.claim.sub','30000000-0000-0000-0000-000000000001',true);
set local role authenticated;
do $rpc$
declare r record; n integer:=0;
begin
 for r in select * from public.srk_get_my_offer_details_v2() loop
  n:=n+1;
  if r.order_number is null or r.order_number !~ '^SRK-ORD-[0-9]{6,}$' then
   raise exception 'RPC did not return a valid order number';
  end if;
  if r.booking_id='10000000-0000-0000-0000-000000000002' then
   if r.customer_name <> 'Assigned Customer' or r.customer_phone <> '9000000002' or r.address <> 'Assigned Address' then
    raise exception 'Assigned booking should reveal customer contact';
   end if;
  elsif r.booking_id='10000000-0000-0000-0000-000000000003' then
   if r.customer_name is not null or r.customer_phone is not null or r.address is not null then
    raise exception 'Unassigned offer leaked customer PII';
   end if;
  end if;
 end loop;
 if n<>2 then raise exception 'Expected exactly two offers for authenticated electrician, got %',n; end if;
end
$rpc$;
rollback;
select 'booking order number + electrician RPC tests passed' as result;
