DROP POLICY IF EXISTS "public can submit bookings" ON public.service_bookings;
DROP POLICY IF EXISTS "public can apply as electrician" ON public.electrician_applications;
REVOKE INSERT ON TABLE public.service_bookings FROM anon, authenticated;
REVOKE INSERT ON TABLE public.electrician_applications FROM anon, authenticated;
GRANT INSERT ON TABLE public.service_bookings TO service_role;
GRANT INSERT ON TABLE public.electrician_applications TO service_role;