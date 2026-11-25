
create index if not exists srk_fixed_allocations_booking_idx
  on public.srk_fixed_price_worker_allocations(booking_id);
create index if not exists srk_fixed_allocations_worker_idx
  on public.srk_fixed_price_worker_allocations(worker_id);
create index if not exists srk_fixed_alloc_events_booking_created_idx
  on public.srk_fixed_price_worker_allocation_events(booking_id,created_at desc);
