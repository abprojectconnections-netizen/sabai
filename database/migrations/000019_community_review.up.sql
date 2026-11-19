-- Staff moderation of community reports: a report is "open" until staff dismiss it or remove the post.
ALTER TABLE community_reports
  ADD COLUMN reviewed_at DATETIME(6) NULL,
  ADD COLUMN reviewed_by CHAR(36) NULL,
  ADD KEY idx_community_reports_open (reviewed_at, post_id);
