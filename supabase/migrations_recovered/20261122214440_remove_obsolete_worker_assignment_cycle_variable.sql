
do $migration$
declare
  v_def text;
begin
  v_def := pg_get_functiondef('public.srk_worker_respond_assignment(uuid,boolean)'::regprocedure);
  if position('; v_count bigint;' in v_def)=0 then
    raise exception 'Expected obsolete cycle variable not found';
  end if;
  v_def := replace(v_def,'; v_count bigint;',';');
  execute v_def;
end
$migration$;
