-- Keep admin visibility and customer ownership in one permissive SELECT policy.
-- This preserves the same access model while avoiding duplicate permissive policies.

DROP POLICY IF EXISTS srk_admin_read_bookings ON public.service_bookings;
DROP POLICY IF EXISTS srk_customer_read_own_bookings ON public.service_bookings;

CREATE POLICY srk_admin_or_customer_read_bookings
ON public.service_bookings
FOR SELECT
TO authenticated
USING (
  (SELECT public.is_srk_admin())
  OR (SELECT auth.uid()) = customer_user_id
);
