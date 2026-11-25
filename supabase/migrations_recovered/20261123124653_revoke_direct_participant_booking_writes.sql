revoke insert, update, delete, truncate, references, trigger
on table
 public.srk_booking_admin_changes,
 public.srk_booking_chat_members,
 public.srk_booking_chat_rooms,
 public.srk_booking_location_shares,
 public.srk_booking_matching_queue,
 public.srk_booking_ratings,
 public.srk_booking_schedule_proposals,
 public.srk_booking_workers
from anon, authenticated;

revoke insert, update, delete, truncate, references, trigger
on table
 public.srk_booking_admin_changes,
 public.srk_booking_chat_members,
 public.srk_booking_chat_rooms,
 public.srk_booking_location_shares,
 public.srk_booking_matching_queue,
 public.srk_booking_ratings,
 public.srk_booking_schedule_proposals,
 public.srk_booking_workers
from public;