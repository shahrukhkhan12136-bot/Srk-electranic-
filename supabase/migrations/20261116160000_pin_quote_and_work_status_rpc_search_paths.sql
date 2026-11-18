-- Older feature-branch history may already have retired these legacy quotation RPCs.
-- Resolve each signature before altering it so clean replay is safe when absent.
-- pg_catalog remains implicitly searched for built-in functions and operators.
do $$
declare
  v_signature text;
  v_function regprocedure;
begin
  foreach v_signature in array array[
    'public.srk_submit_booking_quote(uuid,numeric,numeric,text)',
    'public.srk_customer_respond_booking_quote(uuid,text)',
    'public.srk_update_booking_work_status(uuid,text)'
  ]
  loop
    v_function := to_regprocedure(v_signature);
    if v_function is not null then
      execute format('alter function %s set search_path = %L', v_function, '');
    end if;
  end loop;
end;
$$;
