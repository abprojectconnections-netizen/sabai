-- Community feed: posts are public to signed-in users immediately; abuse is reported afterwards (no pre-moderation).
-- Reports are stored for staff review (the review tooling is out of scope here). Deleting a post is a soft delete.
CREATE TABLE community_posts (
  id CHAR(36) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  updated_at DATETIME(6) NOT NULL,
  deleted_at DATETIME(6) NULL,
  user_id CHAR(36) NOT NULL,
  body VARCHAR(2000) NOT NULL,
  PRIMARY KEY (id),
  KEY idx_community_posts_feed (deleted_at, created_at, id),
  KEY idx_community_posts_user (user_id),
  CONSTRAINT fk_community_posts_user FOREIGN KEY (user_id) REFERENCES users (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE community_reports (
  id CHAR(36) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  post_id CHAR(36) NOT NULL,
  reporter_id CHAR(36) NOT NULL,
  reason VARCHAR(20) NOT NULL,
  detail VARCHAR(500) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_community_reports (post_id, reporter_id),
  KEY idx_community_reports_reporter (reporter_id),
  CONSTRAINT fk_community_reports_post FOREIGN KEY (post_id) REFERENCES community_posts (id),
  CONSTRAINT fk_community_reports_user FOREIGN KEY (reporter_id) REFERENCES users (id),
  CONSTRAINT ck_community_reports_reason CHECK (reason IN ('SPAM', 'ABUSE', 'MISLEADING', 'OTHER'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
