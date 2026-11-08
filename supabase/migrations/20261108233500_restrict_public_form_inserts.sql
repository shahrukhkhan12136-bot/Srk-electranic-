-- Route public customer bookings and electrician applications through
-- rate-limited Netlify server functions using the server-side service role.
-- Browser clients must not be able to insert directly through the Supabase Data API.

DROP POLICY IF EXISTS "public can submit bookings" ON public.service_bookings;
DROP POLICY IF EXISTS "public can apply as electrician" ON public.electrician_applications;

REVOKE INSERT ON TABLE public.service_bookings FROM anon, authenticated;
REVOKE INSERT ON TABLE public.electrician_applications FROM anon, authenticated;

GRANT INSERT ON TABLE public.service_bookings TO service_role;
GRANT INSERT ON TABLE public.electrician_applications TO service_role;
