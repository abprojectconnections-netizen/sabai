-- Central tagging for user content. A tag is a normalised slug plus its display label; content_tags links a tag to
-- one piece of content (polymorphic: content_type + content_id, like reviews.subject_*, so there is no per-type foreign key
-- and the API verifies the content exists and who may tag it).
CREATE TABLE tags (
  id CHAR(36) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  updated_at DATETIME(6) NOT NULL,
  slug VARCHAR(64) NOT NULL,
  label VARCHAR(100) NOT NULL,
  created_by CHAR(36) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_tags_slug (slug)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE content_tags (
  id CHAR(36) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  tag_id CHAR(36) NOT NULL,
  content_type VARCHAR(30) NOT NULL,
  content_id CHAR(36) NOT NULL,
  tagged_by CHAR(36) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_content_tags (tag_id, content_type, content_id),
  KEY idx_content_tags_content (content_type, content_id),
  CONSTRAINT fk_content_tags_tag FOREIGN KEY (tag_id) REFERENCES tags (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
