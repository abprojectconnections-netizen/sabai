-- Serialises audit-chain writers on ONE row. (Locking "the last audit row" with ORDER BY ... FOR UPDATE takes gap locks and deadlocks
-- under concurrency; found by the integration tests.)
CREATE TABLE financial_audit_head (
  id TINYINT NOT NULL,
  last_seq BIGINT NOT NULL DEFAULT 0,
  last_hash CHAR(64) NULL,
  PRIMARY KEY (id),
  CONSTRAINT ck_financial_audit_head_single CHECK (id = 1)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
INSERT INTO financial_audit_head (id, last_seq, last_hash)
SELECT 1, COALESCE(MAX(seq), 0), (SELECT row_hash FROM financial_audit_logs ORDER BY seq DESC LIMIT 1) FROM financial_audit_logs;
CREATE TRIGGER trg_financial_audit_head_nod BEFORE DELETE ON financial_audit_head FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'financial_audit_head cannot be deleted';
