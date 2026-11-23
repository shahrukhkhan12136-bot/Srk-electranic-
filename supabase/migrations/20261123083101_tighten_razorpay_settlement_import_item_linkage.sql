-- Preserve provider-created time separately; the settlement list endpoint does not provide a processed timestamp.
-- Reject recon rows that explicitly point at a different settlement.
do $$
declare
  v_def text;
begin
  v_def := pg_get_functiondef('public.srk_service_import_razorpay_settlement(jsonb,jsonb,text)'::regprocedure);
  if position('case when v_status=''processed'' then v_created_at else null end' in v_def) = 0 then
    raise exception 'Expected settlement timestamp expression was not found; refusing patch';
  end if;
  v_def := replace(v_def,
    'case when v_status=''processed'' then v_created_at else null end',
    'null');
  if position('or (v_item ? ''settlement_id'' and v_item->>''settlement_id'' is distinct from v_settlement_ref)' in v_def) = 0 then
    v_def := replace(v_def,
      'or coalesce(v_item->>''currency'',''INR'') <> ''INR''',
      'or coalesce(v_item->>''currency'',''INR'') <> ''INR''' || E'\n       ' ||
      'or (v_item ? ''settlement_id'' and v_item->>''settlement_id'' is distinct from v_settlement_ref)');
  end if;
  execute v_def;
end $$;
