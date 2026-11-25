
REVOKE INSERT, UPDATE, DELETE ON TABLE
  public.srk_worker_profiles,
  public.srk_booking_chat_messages,
  public.srk_booking_live_locations,
  public.srk_support_messages
FROM authenticated;
