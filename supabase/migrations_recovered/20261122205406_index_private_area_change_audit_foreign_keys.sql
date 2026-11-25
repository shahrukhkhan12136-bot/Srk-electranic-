
create index if not exists srk_electrician_area_change_actor_user_id_idx
  on srk_private.srk_electrician_area_change_requests(actor_user_id);
create index if not exists srk_electrician_area_change_reviewed_by_idx
  on srk_private.srk_electrician_area_change_requests(reviewed_by);
