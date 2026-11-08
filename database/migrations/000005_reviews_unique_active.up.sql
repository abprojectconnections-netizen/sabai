-- One active review per (user, subject). The application check-then-insert is racy; the constraint is authoritative.
-- Soft-deleted reviews are excluded via the NULL-valued active_key, so a user may review again after deleting.
-- Keep the newest active review when duplicates already exist.
UPDATE reviews r
JOIN (
  SELECT id, ROW_NUMBER() OVER (PARTITION BY user_id, subject_type, subject_id ORDER BY created_at DESC, id DESC) AS rn
  FROM reviews WHERE deleted_at IS NULL
) d ON d.id = r.id
SET r.deleted_at = UTC_TIMESTAMP(6)
WHERE d.rn > 1;

ALTER TABLE reviews
  ADD COLUMN active_key TINYINT GENERATED ALWAYS AS (IF(deleted_at IS NULL, 1, NULL)) VIRTUAL,
  ADD UNIQUE KEY uq_reviews_one_active (user_id, subject_type, subject_id, active_key);
