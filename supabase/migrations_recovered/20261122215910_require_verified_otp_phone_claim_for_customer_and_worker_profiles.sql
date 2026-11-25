
do $fix$
declare
  v_customer text;
  v_worker text;
begin
  v_customer:=pg_get_functiondef('public.srk_customer_upsert_profile(text,text)'::regprocedure);
  if position('if v_auth_phone is not null and v_auth_phone<>'''' and v_auth_phone<>p_phone then' in lower(v_customer))=0 then
    raise exception 'Customer OTP phone guard pattern not found; stop';
  end if;
  v_customer:=replace(
    v_customer,
    'if v_auth_phone is not null and v_auth_phone<>'''' and v_auth_phone<>p_phone then',
    'if coalesce(v_auth_phone,'''')='''' or v_auth_phone<>p_phone then'
  );
  execute v_customer;

  v_worker:=pg_get_functiondef('public.srk_submit_worker_application(text,uuid,text,text,text,date,text,text,text,text,text,integer,text)'::regprocedure);
  if position('if v_auth_phone<>'''' and v_auth_phone<>p_phone then' in lower(v_worker))=0 then
    raise exception 'Worker OTP phone guard pattern not found; stop';
  end if;
  v_worker:=replace(
    v_worker,
    'if v_auth_phone<>'''' and v_auth_phone<>p_phone then',
    'if coalesce(v_auth_phone,'''')='''' or v_auth_phone<>p_phone then'
  );
  execute v_worker;
end
$fix$;
