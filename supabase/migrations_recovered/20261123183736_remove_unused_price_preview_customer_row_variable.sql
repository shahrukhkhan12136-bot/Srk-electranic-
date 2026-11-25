
do $migration$
declare v_def text; v_old text; v_new text;
begin
 v_def:=pg_get_functiondef('public.srk_customer_preview_booking_price(uuid,uuid,uuid,uuid,integer,integer,integer,numeric,integer)'::regprocedure);
 v_old:=' v_customer public.srk_customer_profiles%rowtype;';
 if position(v_old in v_def)=0 then raise exception 'Price preview customer variable not found'; end if;
 v_def:=replace(v_def,v_old,'');
 v_old:=' select * into v_customer from public.srk_customer_profiles where user_id=auth.uid() and account_status=''active'';
 if not found then raise exception ''Active customer profile required''; end if;';
 v_new:=' if not exists(select 1 from public.srk_customer_profiles where user_id=auth.uid() and account_status=''active'') then
   raise exception ''Active customer profile required'';
 end if;';
 if position(v_old in v_def)=0 then raise exception 'Price preview profile lookup not found'; end if;
 v_def:=replace(v_def,v_old,v_new);
 execute v_def;
end
$migration$;
