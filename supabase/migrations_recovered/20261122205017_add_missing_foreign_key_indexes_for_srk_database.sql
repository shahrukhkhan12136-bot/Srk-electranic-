
do $$
declare r record; idx_name text;
begin
  for r in
    select distinct ns.nspname schema_name, rel.relname table_name, att.attname column_name
    from pg_constraint fk
    join pg_class rel on rel.oid=fk.conrelid
    join pg_namespace ns on ns.oid=rel.relnamespace
    join lateral unnest(fk.conkey) with ordinality cols(attnum,ord) on true
    join pg_attribute att on att.attrelid=rel.oid and att.attnum=cols.attnum
    where fk.contype='f'
      and ns.nspname='public'
      and (rel.relname like 'srk_%' or rel.relname='service_bookings')
      and not exists(
        select 1 from pg_index ix
        where ix.indrelid=rel.oid and ix.indisvalid and ix.indisready
          and ix.indpred is null and ix.indexprs is null
          and ix.indkey[0]=att.attnum
      )
  loop
    idx_name:=left('fk_'||r.table_name||'_'||r.column_name,48)||'_'||
      substr(md5(r.table_name||'.'||r.column_name),1,8);
    execute format('create index if not exists %I on %I.%I (%I)',
      idx_name,r.schema_name,r.table_name,r.column_name);
  end loop;
end $$;
