-- Prevent internal staff notes from leaking through customer complaint/refund RPCs.
-- Preserve existing RPC signatures for compatibility; admin_note is returned as NULL.
-- Complaint activity omits event.note because the current event model has no
-- explicit customer-visible/internal visibility flag.

create or replace function public.srk_customer_list_booking_complaints()
returns table (
  id uuid,
  booking_id uuid,
  category text,
  description text,
  status text,
  admin_note text,
  created_at timestamptz,
  updated_at timestamptz,
  resolved_at timestamptz,
  activity jsonb
)
language plpgsql
stable
security definer
set search_path = pg_catalog, public, auth, pg_temp
as $function$
begin
  if auth.uid() is null then
    raise exception 'Customer login required' using errcode = '42501';
  end if;

  return query
    select
      c.id,
      c.booking_id,
      c.category,
      c.description,
      c.status,
      null::text as admin_note,
      c.created_at,
      c.updated_at,
      c.resolved_at,
      coalesce(
        (
          select jsonb_agg(
            jsonb_build_object(
              'actor_role', e.actor_role,
              'from_status', e.from_status,
              'to_status', e.to_status,
              'created_at', e.created_at
            )
            order by e.created_at asc
          )
          from public.srk_booking_complaint_events e
          where e.complaint_id = c.id
        ),
        '[]'::jsonb
      ) as activity
    from public.srk_booking_complaints c
    where c.customer_user_id = auth.uid()
    order by c.created_at desc
    limit 100;
end;
$function$;

create or replace function public.srk_customer_list_booking_refund_requests()
returns table (
  id uuid,
  booking_id uuid,
  amount numeric,
  reason text,
  status text,
  admin_note text,
  created_at timestamptz,
  updated_at timestamptz,
  processed_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $function$
begin
  if auth.uid() is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode = '28000';
  end if;

  return query
    select
      r.id,
      r.booking_id,
      r.amount,
      r.reason,
      r.status,
      null::text as admin_note,
      r.created_at,
      r.updated_at,
      r.processed_at
    from public.srk_booking_refund_requests r
    where r.customer_user_id = auth.uid()
    order by r.created_at desc;
end
$function$;

revoke all on function public.srk_customer_list_booking_complaints() from public, anon;
grant execute on function public.srk_customer_list_booking_complaints() to authenticated;

revoke all on function public.srk_customer_list_booking_refund_requests() from public, anon;
grant execute on function public.srk_customer_list_booking_refund_requests() to authenticated;
