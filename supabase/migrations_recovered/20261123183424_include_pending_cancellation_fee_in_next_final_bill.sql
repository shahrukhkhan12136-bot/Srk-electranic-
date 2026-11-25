
do $migration$
declare v_def text; v_old text; v_new text;
begin
 v_def:=pg_get_functiondef('public.srk_admin_finalize_booking_bill(uuid)'::regprocedure);

 v_old:='v_expected_fixed_amount numeric(12,2);';
 v_new:='v_expected_fixed_amount numeric(12,2);
  v_cancellation_fee numeric(12,2):=0;';
 if position(v_old in v_def)=0 then raise exception 'Final bill declaration point not found'; end if;
 v_def:=replace(v_def,v_old,v_new);

 v_old:='  v_material:=0;';
 v_new:='  v_material:=0;
  v_cancellation_fee:=coalesce(v_booking.pending_cancellation_fee_amount,0);';
 if position(v_old in v_def)=0 then raise exception 'Final bill material reset not found'; end if;
 v_def:=replace(v_def,v_old,v_new);

 v_old:='service_amount=v_labour,materials_amount=v_material,';
 v_new:='service_amount=v_labour,materials_amount=v_material,cancellation_fee_amount=v_cancellation_fee,';
 if position(v_old in v_def)=0 then raise exception 'Final bill revision update fields not found'; end if;
 v_def:=replace(v_def,v_old,v_new);

 v_old:='booking_id,bill_number,revision_no,service_amount,materials_amount,status,prepared_at';
 v_new:='booking_id,bill_number,revision_no,service_amount,materials_amount,cancellation_fee_amount,status,prepared_at';
 if position(v_old in v_def)=0 then raise exception 'Final bill insert columns not found'; end if;
 v_def:=replace(v_def,v_old,v_new);

 v_old:='1,v_labour,v_material,''issued'',clock_timestamp()';
 v_new:='1,v_labour,v_material,v_cancellation_fee,''issued'',clock_timestamp()';
 if position(v_old in v_def)=0 then raise exception 'Final bill insert values not found'; end if;
 v_def:=replace(v_def,v_old,v_new);

 v_old:='    1,''booking'',v_labour
  );';
 v_new:='    1,''booking'',v_labour
  );
  if v_cancellation_fee>0 then
    insert into public.srk_booking_final_bill_items(
      bill_id,item_type,description,quantity,unit,unit_price
    ) values(v_bill.id,''cancellation_fee'',''Pending cancellation fee from a previous booking'',1,''booking'',v_cancellation_fee);
  end if;';
 if position(v_old in v_def)=0 then raise exception 'Final bill labour line item point not found'; end if;
 v_def:=replace(v_def,v_old,v_new);
 execute v_def;
end
$migration$;
