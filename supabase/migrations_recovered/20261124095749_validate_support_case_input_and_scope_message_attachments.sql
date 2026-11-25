CREATE OR REPLACE FUNCTION public.srk_create_support_case(
 p_booking_id uuid,p_category text,p_subject text,p_description text,p_priority text DEFAULT 'normal'
) RETURNS public.srk_support_cases
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth'
AS $function$
declare v_role text; v_case public.srk_support_cases%rowtype;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if p_category is null or length(btrim(p_category)) not between 2 and 80
  or p_subject is null or length(btrim(p_subject)) not between 3 and 160
  or p_description is null or length(btrim(p_description)) not between 10 and 4000
  or p_priority not in ('low','normal','high','urgent','emergency') then
  raise exception 'Enter a valid support category, subject, description and priority' using errcode='22023';
 end if;
 if p_booking_id is not null then
  if exists(select 1 from public.service_bookings where id=p_booking_id and customer_user_id=auth.uid()) then
   v_role:='customer';
  else
   select w.worker_type into v_role
   from public.srk_booking_workers bw
   join public.srk_worker_profiles w on w.id=bw.worker_id
   where bw.booking_id=p_booking_id and w.user_id=auth.uid()
   limit 1;
  end if;
 else
  if exists(select 1 from public.srk_customer_profiles where user_id=auth.uid()) then
   v_role:='customer';
  else
   select worker_type into v_role from public.srk_worker_profiles where user_id=auth.uid();
  end if;
 end if;
 if v_role is null then raise exception 'Customer or worker profile required'; end if;
 insert into public.srk_support_cases(
  booking_id,raised_by,raised_by_role,category,subject,description,priority
 ) values(
  p_booking_id,auth.uid(),v_role,btrim(p_category),btrim(p_subject),btrim(p_description),p_priority
 ) returning * into v_case;
 insert into public.srk_support_case_events(case_id,actor_user_id,action,new_status,note)
 values(v_case.id,auth.uid(),'case_created','open',btrim(p_description));
 return v_case;
end
$function$;

CREATE OR REPLACE FUNCTION public.srk_send_support_message(
 p_case_id uuid,p_message text,p_attachment_path text DEFAULT NULL
) RETURNS public.srk_support_messages
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth'
AS $function$
declare v_msg public.srk_support_messages%rowtype;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if p_case_id is null or p_message is null or length(btrim(p_message)) not between 1 and 4000 then
  raise exception 'Support message must contain 1 to 4000 characters' using errcode='22023';
 end if;
 if p_attachment_path is not null and (
  p_attachment_path like '/%' or p_attachment_path like '%..%'
  or p_attachment_path ~ '[\\\\]'
  or split_part(p_attachment_path,'/',1)<>p_case_id::text
  or split_part(p_attachment_path,'/',2)<>auth.uid()::text
  or length(p_attachment_path)>1000
 ) then
  raise exception 'Attachment must be uploaded inside this support case and your own private folder' using errcode='22023';
 end if;
 if not exists(select 1 from public.srk_support_cases c where c.id=p_case_id
  and (c.raised_by=auth.uid() or c.assigned_staff=auth.uid()
   or public.srk_has_admin_permission('support.manage'))) then
  raise exception 'Not authorized for this support case' using errcode='42501';
 end if;
 if p_attachment_path is not null and not exists(
  select 1 from storage.objects o
  where o.bucket_id='srk-support-attachments' and o.name=p_attachment_path
 ) then
  raise exception 'Support attachment is not present in the private support bucket';
 end if;
 insert into public.srk_support_messages(case_id,sender_user_id,message,attachment_path)
 values(p_case_id,auth.uid(),btrim(p_message),p_attachment_path) returning * into v_msg;
 return v_msg;
end
$function$;