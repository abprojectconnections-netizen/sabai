-- Fixed platform roles; every user has CUSTOMER at registration, elevated roles require an ADMIN action.
INSERT INTO roles (id, created_at, updated_at, code, name) VALUES
  ('00000000-0000-4000-8000-000000000001', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6), 'CUSTOMER', 'Customer'),
  ('00000000-0000-4000-8000-000000000002', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6), 'PARTNER', 'Partner'),
  ('00000000-0000-4000-8000-000000000003', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6), 'STAFF', 'Staff'),
  ('00000000-0000-4000-8000-000000000004', UTC_TIMESTAMP(6), UTC_TIMESTAMP(6), 'ADMIN', 'Administrator')
ON DUPLICATE KEY UPDATE name = VALUES(name), updated_at = UTC_TIMESTAMP(6);

ALTER TABLE user_roles ADD UNIQUE KEY uq_user_roles_active (user_id, role_id, deleted_at);
ALTER TABLE audit_logs ADD COLUMN request_id VARCHAR(64) NULL AFTER ip_address;
ALTER TABLE audit_logs ADD INDEX idx_audit_logs_subject (subject_type, subject_id, created_at);

-- Portal work queues and dispute lifecycle.
ALTER TABLE support_tickets ADD COLUMN status VARCHAR(30) NOT NULL DEFAULT 'OPEN', ADD COLUMN priority VARCHAR(20) NOT NULL DEFAULT 'NORMAL', ADD COLUMN assigned_staff_id CHAR(36) NULL, ADD COLUMN subject VARCHAR(255) NULL;
ALTER TABLE refunds ADD COLUMN status VARCHAR(30) NOT NULL DEFAULT 'PENDING', ADD COLUMN reviewed_by CHAR(36) NULL, ADD COLUMN reviewed_at DATETIME(6) NULL;
CREATE TABLE disputes (
  id CHAR(36) NOT NULL, created_at DATETIME(6) NOT NULL, updated_at DATETIME(6) NOT NULL, deleted_at DATETIME(6) NULL,
  booking_id CHAR(36) NOT NULL, opened_by_user_id CHAR(36) NOT NULL, assigned_staff_id CHAR(36) NULL,
  reason VARCHAR(100) NOT NULL, description TEXT NULL, status VARCHAR(30) NOT NULL DEFAULT 'OPEN', resolution TEXT NULL, resolved_at DATETIME(6) NULL,
  PRIMARY KEY (id), INDEX idx_disputes_queue (status, assigned_staff_id, created_at),
  CONSTRAINT fk_disputes_booking FOREIGN KEY (booking_id) REFERENCES bookings(id),
  CONSTRAINT fk_disputes_opened_by FOREIGN KEY (opened_by_user_id) REFERENCES users(id),
  CONSTRAINT fk_disputes_assigned_staff FOREIGN KEY (assigned_staff_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
