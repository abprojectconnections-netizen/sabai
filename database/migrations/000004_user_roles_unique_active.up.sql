-- user_roles had UNIQUE (user_id, role_id, deleted_at). Active rows have deleted_at = NULL and MySQL treats
-- NULLs as distinct in unique indexes, so the same role could be granted twice (INSERT IGNORE never ignored it).
-- active_key is 1 for active rows and NULL for soft-deleted ones, so (user_id, role_id, active_key) is unique
-- exactly for active grants while any number of soft-deleted rows may remain.

-- Keep the oldest of any duplicated active grants (role grants are not financial records).
DELETE newer FROM user_roles newer
JOIN user_roles older
  ON older.user_id = newer.user_id AND older.role_id = newer.role_id
 AND older.deleted_at IS NULL AND newer.deleted_at IS NULL
 AND (older.created_at < newer.created_at OR (older.created_at = newer.created_at AND older.id < newer.id));

ALTER TABLE user_roles
  DROP INDEX uq_user_roles_active,
  ADD COLUMN active_key TINYINT GENERATED ALWAYS AS (IF(deleted_at IS NULL, 1, NULL)) VIRTUAL,
  ADD UNIQUE KEY uq_user_roles_one_active (user_id, role_id, active_key);
