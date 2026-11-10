-- Permission-based RBAC (design 0002 section 4 / Section 8.16). Roles are bundles of permission codes (data, not code).
-- Legacy roles stay valid: ADMIN is mapped to System Admin (NO financial authority), STAFF to Booking Officer, PARTNER to Partner Admin.

ALTER TABLE permissions
  ADD UNIQUE KEY uq_permissions_code (code),
  ADD COLUMN description VARCHAR(255) NULL;
ALTER TABLE role_permissions
  ADD COLUMN active_key TINYINT GENERATED ALWAYS AS (IF(deleted_at IS NULL, 1, NULL)) VIRTUAL,
  ADD UNIQUE KEY uq_role_permissions_active (role_id, permission_id, active_key);

INSERT INTO roles (id, created_at, updated_at, code, name) VALUES
  (UUID(), UTC_TIMESTAMP(6), UTC_TIMESTAMP(6), 'PARTNER_ADMIN', 'Partner Admin'),
  (UUID(), UTC_TIMESTAMP(6), UTC_TIMESTAMP(6), 'PARTNER_FINANCE', 'Partner Finance'),
  (UUID(), UTC_TIMESTAMP(6), UTC_TIMESTAMP(6), 'BOOKING_OFFICER', 'Booking Officer'),
  (UUID(), UTC_TIMESTAMP(6), UTC_TIMESTAMP(6), 'REFUND_OFFICER', 'Refund Officer'),
  (UUID(), UTC_TIMESTAMP(6), UTC_TIMESTAMP(6), 'FINANCE_MANAGER', 'Finance Manager'),
  (UUID(), UTC_TIMESTAMP(6), UTC_TIMESTAMP(6), 'CFO_CEO', 'CFO / CEO'),
  (UUID(), UTC_TIMESTAMP(6), UTC_TIMESTAMP(6), 'SYSTEM_ADMIN', 'System Administrator'),
  (UUID(), UTC_TIMESTAMP(6), UTC_TIMESTAMP(6), 'AUDITOR', 'Auditor')
ON DUPLICATE KEY UPDATE name = VALUES(name);

INSERT INTO permissions (id, created_at, updated_at, code, name, description) VALUES
  (UUID(), UTC_TIMESTAMP(6), UTC_TIMESTAMP(6), 'portal.read', 'Read the staff portal', NULL),
  (UUID(), UTC_TIMESTAMP(6), UTC_TIMESTAMP(6), 'booking.manage', 'Change booking status (non-financial transitions)', NULL),
  (UUID(), UTC_TIMESTAMP(6), UTC_TIMESTAMP(6), 'support.manage', 'Handle tickets and disputes', NULL),
  (UUID(), UTC_TIMESTAMP(6), UTC_TIMESTAMP(6), 'partner.review', 'Approve or suspend partners', NULL),
  (UUID(), UTC_TIMESTAMP(6), UTC_TIMESTAMP(6), 'refund.review', 'Review refund requests', NULL),
  (UUID(), UTC_TIMESTAMP(6), UTC_TIMESTAMP(6), 'refund.approve', 'Approve refunds up to the approver limit', NULL),
  (UUID(), UTC_TIMESTAMP(6), UTC_TIMESTAMP(6), 'settlement.review', 'Review settlement batches', NULL),
  (UUID(), UTC_TIMESTAMP(6), UTC_TIMESTAMP(6), 'settlement.approve', 'Approve settlement batches', NULL),
  (UUID(), UTC_TIMESTAMP(6), UTC_TIMESTAMP(6), 'reconciliation.run', 'Run and resolve reconciliation', NULL),
  (UUID(), UTC_TIMESTAMP(6), UTC_TIMESTAMP(6), 'commission.policy.approve', 'Approve commission policies', NULL),
  (UUID(), UTC_TIMESTAMP(6), UTC_TIMESTAMP(6), 'audit.read', 'Read audit, ledger and tax documents', NULL),
  (UUID(), UTC_TIMESTAMP(6), UTC_TIMESTAMP(6), 'config.manage', 'Manage non-financial configuration', NULL),
  (UUID(), UTC_TIMESTAMP(6), UTC_TIMESTAMP(6), 'user.manage', 'Manage users', NULL),
  (UUID(), UTC_TIMESTAMP(6), UTC_TIMESTAMP(6), 'role.request', 'Request a role assignment', NULL),
  (UUID(), UTC_TIMESTAMP(6), UTC_TIMESTAMP(6), 'role.approve', 'Approve a (non-financial) role assignment', NULL),
  (UUID(), UTC_TIMESTAMP(6), UTC_TIMESTAMP(6), 'role.approve.financial', 'Approve assignment of a financial role', NULL),
  (UUID(), UTC_TIMESTAMP(6), UTC_TIMESTAMP(6), 'partner.manage.own', 'Manage own partner profile and products', NULL),
  (UUID(), UTC_TIMESTAMP(6), UTC_TIMESTAMP(6), 'settlement.read.own', 'Read own settlements and commissions', NULL);

-- role -> permission (System Admin / legacy ADMIN deliberately get NO refund, settlement, payment or payout permission)
INSERT INTO role_permissions (id, created_at, updated_at, role_id, permission_id)
SELECT UUID(), UTC_TIMESTAMP(6), UTC_TIMESTAMP(6), r.id, p.id FROM (
  SELECT 'STAFF' role_code, 'portal.read' perm UNION ALL SELECT 'STAFF','booking.manage' UNION ALL SELECT 'STAFF','support.manage' UNION ALL SELECT 'STAFF','partner.review'
  UNION ALL SELECT 'BOOKING_OFFICER','portal.read' UNION ALL SELECT 'BOOKING_OFFICER','booking.manage' UNION ALL SELECT 'BOOKING_OFFICER','support.manage'
  UNION ALL SELECT 'REFUND_OFFICER','portal.read' UNION ALL SELECT 'REFUND_OFFICER','refund.review' UNION ALL SELECT 'REFUND_OFFICER','refund.approve'
  UNION ALL SELECT 'FINANCE_MANAGER','portal.read' UNION ALL SELECT 'FINANCE_MANAGER','refund.review' UNION ALL SELECT 'FINANCE_MANAGER','refund.approve'
  UNION ALL SELECT 'FINANCE_MANAGER','settlement.review' UNION ALL SELECT 'FINANCE_MANAGER','settlement.approve' UNION ALL SELECT 'FINANCE_MANAGER','reconciliation.run'
  UNION ALL SELECT 'CFO_CEO','portal.read' UNION ALL SELECT 'CFO_CEO','refund.approve' UNION ALL SELECT 'CFO_CEO','commission.policy.approve'
  UNION ALL SELECT 'CFO_CEO','role.approve' UNION ALL SELECT 'CFO_CEO','role.approve.financial' UNION ALL SELECT 'CFO_CEO','audit.read'
  UNION ALL SELECT 'ADMIN','config.manage' UNION ALL SELECT 'ADMIN','user.manage' UNION ALL SELECT 'ADMIN','role.request' UNION ALL SELECT 'ADMIN','role.approve'
  UNION ALL SELECT 'SYSTEM_ADMIN','config.manage' UNION ALL SELECT 'SYSTEM_ADMIN','user.manage' UNION ALL SELECT 'SYSTEM_ADMIN','role.request' UNION ALL SELECT 'SYSTEM_ADMIN','role.approve'
  UNION ALL SELECT 'AUDITOR','audit.read' UNION ALL SELECT 'AUDITOR','portal.read'
  UNION ALL SELECT 'PARTNER','partner.manage.own' UNION ALL SELECT 'PARTNER_ADMIN','partner.manage.own'
  UNION ALL SELECT 'PARTNER','settlement.read.own' UNION ALL SELECT 'PARTNER_FINANCE','settlement.read.own'
) m JOIN roles r ON r.code = m.role_code JOIN permissions p ON p.code = m.perm;

-- Role assignment needs a request by one person and an approval by a different one.
CREATE TABLE role_change_requests (
  id CHAR(36) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  target_user_id CHAR(36) NOT NULL,
  role_id CHAR(36) NOT NULL,
  requested_by CHAR(36) NOT NULL,
  reason VARCHAR(500) NULL,
  status VARCHAR(10) NOT NULL DEFAULT 'PENDING',
  decided_by CHAR(36) NULL,
  decided_at DATETIME(6) NULL,
  pending_key TINYINT GENERATED ALWAYS AS (IF(status = 'PENDING', 1, NULL)) VIRTUAL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_role_change_pending (target_user_id, role_id, pending_key),
  CONSTRAINT fk_role_change_target FOREIGN KEY (target_user_id) REFERENCES users(id),
  CONSTRAINT fk_role_change_role FOREIGN KEY (role_id) REFERENCES roles(id),
  CONSTRAINT fk_role_change_requester FOREIGN KEY (requested_by) REFERENCES users(id),
  CONSTRAINT fk_role_change_decider FOREIGN KEY (decided_by) REFERENCES users(id),
  CONSTRAINT ck_role_change_status CHECK (status IN ('PENDING','APPROVED','REJECTED')),
  -- nobody requests a role for themselves; the decider is a third party
  CONSTRAINT ck_role_change_self CHECK (target_user_id <> requested_by),
  CONSTRAINT ck_role_change_sod CHECK (decided_by IS NULL OR (decided_by <> requested_by AND decided_by <> target_user_id)),
  CONSTRAINT ck_role_change_decided CHECK ((status = 'PENDING') = (decided_by IS NULL))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TRIGGER trg_role_change_nod BEFORE DELETE ON role_change_requests FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'role_change_requests cannot be deleted';
