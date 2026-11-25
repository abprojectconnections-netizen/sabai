DELETE FROM feature_flags WHERE flag_key IN ('community.posting', 'coupons.claiming');
ALTER TABLE feature_flags
  DROP INDEX uq_feature_flags_flag_key,
  DROP COLUMN updated_by,
  DROP COLUMN enabled,
  DROP COLUMN description,
  DROP COLUMN flag_key;
