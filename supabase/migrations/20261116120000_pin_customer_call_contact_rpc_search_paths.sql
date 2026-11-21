-- Pin the customer call-contact implementation and its invoker wrapper.
-- All relation/function references in the implementation are schema-qualified.
alter function private.srk_get_customer_call_contacts_impl()
  set search_path = '';
alter function public.srk_get_customer_call_contacts()
  set search_path = '';
