
REVOKE SELECT, UPDATE, USAGE ON SEQUENCE net.http_request_queue_id_seq FROM PUBLIC;
REVOKE SELECT, UPDATE, USAGE ON SEQUENCE net.http_request_queue_id_seq FROM anon;
REVOKE SELECT, UPDATE, USAGE ON SEQUENCE net.http_request_queue_id_seq FROM authenticated;
