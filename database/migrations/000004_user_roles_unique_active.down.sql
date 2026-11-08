ALTER TABLE user_roles
  DROP INDEX uq_user_roles_one_active,
  DROP COLUMN active_key,
  ADD UNIQUE KEY uq_user_roles_active (user_id, role_id, deleted_at);
