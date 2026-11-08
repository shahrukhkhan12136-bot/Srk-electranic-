ALTER TABLE public.service_bookings
  ADD COLUMN IF NOT EXISTS customer_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_service_bookings_customer_user_created
  ON public.service_bookings (customer_user_id, created_at DESC)
  WHERE customer_user_id IS NOT NULL;

DROP POLICY IF EXISTS srk_customer_read_own_bookings ON public.service_bookings;
CREATE POLICY srk_customer_read_own_bookings
  ON public.service_bookings
  FOR SELECT
  TO authenticated
  USING ((SELECT auth.uid()) = customer_user_id);

COMMENT ON COLUMN public.service_bookings.customer_user_id IS
  'Verified Supabase Auth user who created this booking; null for guest bookings. Customers may read only their own linked bookings.';
