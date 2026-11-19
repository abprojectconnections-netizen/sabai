ALTER TABLE community_reports
  DROP KEY idx_community_reports_open,
  DROP COLUMN reviewed_by,
  DROP COLUMN reviewed_at;
