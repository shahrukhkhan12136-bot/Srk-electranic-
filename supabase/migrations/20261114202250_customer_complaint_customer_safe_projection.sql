-- Prevent customer-facing complaint history from returning internal Admin notes.
-- Harden related SECURITY DEFINER customer RPCs with an empty search_path.

alter function public.srk_customer_create_booking_complaint(uuid,text,text)
  set search_path = '';

create or replace function public.srk_customer_list_booking_complaints()
returns table(
  id uuid,booking_id uuid,category text,description text,status text,
  admin_note text,created_at timestamptz,updated_at timestamptz,
  resolved_at timestamptz,activity jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Customer login required' using errcode='42501';
  end if;

  -- Keep the existing response shape for the current UI, but never return
  -- private Admin notes or raw event notes to the customer session.
  return query
    select c.id,c.booking_id,c.category,c.description,c.status,
           null::text,c.created_at,c.updated_at,c.resolved_at,'[]'::jsonb
      from public.srk_booking_complaints c
     where c.customer_user_id=v_uid
     order by c.created_at desc
     limit 100;
end;
$function$;

revoke all on function public.srk_customer_list_booking_complaints() from public,anon;
grant execute on function public.srk_customer_list_booking_complaints() to authenticated;

comment on function public.srk_customer_list_booking_complaints() is
  'Customer-owned complaint list. Internal Admin notes and event notes are intentionally excluded.';
