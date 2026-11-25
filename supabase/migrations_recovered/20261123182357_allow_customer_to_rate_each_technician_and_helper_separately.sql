
drop index if exists public.srk_one_customer_rating_per_booking;
drop index if exists public.srk_booking_ratings_one_per_rater_idx;

do $migration$
declare v_def text; v_old text; v_new text;
begin
 v_def:=pg_get_functiondef('public.srk_submit_booking_rating(uuid,integer,text,uuid)'::regprocedure);
 v_old:='v_target_worker uuid;';
 v_new:='v_target_worker uuid; v_target_user uuid;';
 if position(v_old in v_def)=0 then raise exception 'Rating function declarations not found'; end if;
 v_def:=replace(v_def,v_old,v_new);

 v_old:='if v_booking.customer_user_id=auth.uid() then
    if p_target_worker_id is not null then raise exception ''Customer rates the completed booking, not a selected worker''; end if;
    v_role:=''customer'';
    select bw.worker_id into v_target_worker
    from public.srk_booking_workers bw
    where bw.booking_id=p_booking_id and bw.worker_role=''technician'' and bw.assignment_status in (''completed'',''released'')
    order by bw.accepted_at nulls last,bw.assigned_at limit 1;
    if v_target_worker is null then raise exception ''Completed Technician assignment not found''; end if;
    insert into public.srk_booking_ratings(booking_id,rater_user_id,rater_role,target_worker_id,target_user_id,rating,comment,moderation_status)
    values(p_booking_id,auth.uid(),''customer'',v_target_worker,null,p_rating,p_comment,''pending'')
    returning * into v_rating_row;';
 v_new:='if v_booking.customer_user_id=auth.uid() then
    if p_target_worker_id is null then raise exception ''Select the Technician or Helper to rate''; end if;
    v_role:=''customer'';
    select wp.id,wp.user_id into v_target_worker,v_target_user
    from public.srk_booking_workers bw
    join public.srk_worker_profiles wp on wp.id=bw.worker_id
    where bw.booking_id=p_booking_id and bw.worker_id=p_target_worker_id
      and bw.assignment_status in (''completed'',''released'')
    limit 1;
    if v_target_worker is null then raise exception ''Selected completed Technician/Helper assignment not found''; end if;
    insert into public.srk_booking_ratings(booking_id,rater_user_id,rater_role,target_worker_id,target_user_id,rating,comment,moderation_status)
    values(p_booking_id,auth.uid(),''customer'',v_target_worker,v_target_user,p_rating,p_comment,''pending'')
    returning * into v_rating_row;';
 if position(v_old in v_def)=0 then raise exception 'Customer rating branch not found'; end if;
 v_def:=replace(v_def,v_old,v_new);
 execute v_def;
end
$migration$;
