
do $migration$
declare v_def text; v_old text; v_new text;
begin
 v_def:=pg_get_functiondef('public.srk_customer_create_booking(uuid,uuid,uuid,integer,integer,integer,text,text,text,text,double precision,double precision,double precision,double precision,numeric,uuid)'::regprocedure);
 v_old:=' if p_skill_level_id is not null then
   select * into v_requested_level from public.srk_skill_levels
   where id=p_skill_level_id and category_id=p_category_id and is_active;
   if not found then raise exception ''Selected qualification level is not active for this category''; end if;
 else
   select * into v_requested_level from public.srk_skill_levels
   where category_id=p_category_id and is_active order by sort_order limit 1;
 end if;';
 v_new:=' if p_skill_level_id is not null then
   select * into v_requested_level from public.srk_skill_levels
   where id=p_skill_level_id and category_id=p_category_id and is_active;
   if not found then raise exception ''Selected qualification level is not active for this category''; end if;
 else
   select * into v_requested_level from public.srk_skill_levels
   where category_id=p_category_id and is_active order by sort_order limit 1;
   p_skill_level_id:=v_requested_level.id;
 end if;';
 if position(v_old in v_def)=0 then raise exception 'Requested qualification default block not found'; end if;
 v_def:=replace(v_def,v_old,v_new);
 execute v_def;
end
$migration$;
