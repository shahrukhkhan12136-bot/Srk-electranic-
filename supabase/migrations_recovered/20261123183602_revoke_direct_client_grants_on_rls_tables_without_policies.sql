
do $migration$
declare r record;
begin
 for r in
   select n.nspname,c.relname
   from pg_class c join pg_namespace n on n.oid=c.relnamespace
   where n.nspname in ('public','private','srk_private')
     and c.relkind='r' and c.relrowsecurity
     and not exists(
       select 1 from pg_policies p
       where p.schemaname=n.nspname and p.tablename=c.relname
     )
 loop
   execute format('revoke all privileges on table %I.%I from anon, authenticated',r.nspname,r.relname);
 end loop;
end
$migration$;
