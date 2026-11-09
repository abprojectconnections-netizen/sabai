-- Financial reference/configuration data (design 0003 sections 1,4,5,6). Config is DATA, never constants:
-- commission rate, approval limits, tax rates, retention classes, consent wording, go-live approvals.
-- Append-only convention: financial tables have no deleted_at and reject DELETE via triggers.

-- `currencies` already exists in 000001 (unique code); extend it. Only THB is enabled at launch.
ALTER TABLE currencies
  ADD COLUMN minor_unit TINYINT NOT NULL DEFAULT 2,
  ADD COLUMN enabled TINYINT(1) NOT NULL DEFAULT 0,
  ADD CONSTRAINT ck_currencies_code CHECK (code REGEXP '^[A-Z]{3}$');
INSERT INTO currencies (id, created_at, updated_at, code, name, symbol, minor_unit, enabled)
VALUES (UUID(), UTC_TIMESTAMP(6), UTC_TIMESTAMP(6), 'THB', 'Thai Baht', '฿', 2, 1)
ON DUPLICATE KEY UPDATE enabled = 1, minor_unit = 2;

CREATE TABLE legal_entities (
  id CHAR(36) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  entity_type VARCHAR(20) NOT NULL,
  legal_name VARCHAR(255) NOT NULL,
  tax_id_enc VARBINARY(512) NULL COMMENT 'encrypted by the application with a managed key',
  tax_id_last4 CHAR(4) NULL,
  vat_registered TINYINT(1) NOT NULL DEFAULT 0,
  vat_effective_from DATE NULL,
  branch_code VARCHAR(10) NULL,
  registered_address TEXT NULL,
  verification_status VARCHAR(20) NOT NULL DEFAULT 'UNVERIFIED',
  PRIMARY KEY (id),
  CONSTRAINT ck_legal_entities_type CHECK (entity_type IN ('PLATFORM','PARTNER')),
  CONSTRAINT ck_legal_entities_verif CHECK (verification_status IN ('UNVERIFIED','VERIFIED','REJECTED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE commission_policies (
  id CHAR(36) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  scope VARCHAR(20) NOT NULL,
  partner_id CHAR(36) NULL,
  category VARCHAR(30) NULL,
  campaign_id CHAR(36) NULL,
  commission_type VARCHAR(10) NOT NULL,
  rate DECIMAL(9,6) NULL,
  fixed_amount DECIMAL(14,2) NULL,
  currency_code CHAR(3) NOT NULL DEFAULT 'THB',
  effective_from DATETIME(6) NOT NULL,
  effective_to DATETIME(6) NULL,
  policy_version INT NOT NULL,
  supersedes_id CHAR(36) NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'DRAFT',
  approved_by CHAR(36) NULL,
  approved_at DATETIME(6) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_commission_policies_version (scope, partner_id, category, campaign_id, policy_version),
  KEY idx_commission_policies_lookup (scope, status, effective_from),
  CONSTRAINT fk_commission_policies_partner FOREIGN KEY (partner_id) REFERENCES partners(id),
  CONSTRAINT fk_commission_policies_supersedes FOREIGN KEY (supersedes_id) REFERENCES commission_policies(id),
  CONSTRAINT fk_commission_policies_currency FOREIGN KEY (currency_code) REFERENCES currencies(code),
  CONSTRAINT ck_commission_policies_scope CHECK (scope IN ('DEFAULT','CATEGORY','PARTNER','CAMPAIGN')),
  CONSTRAINT ck_commission_policies_type CHECK (
    (commission_type = 'PERCENT' AND rate IS NOT NULL AND rate >= 0 AND rate <= 1 AND fixed_amount IS NULL) OR
    (commission_type = 'FIXED' AND fixed_amount IS NOT NULL AND fixed_amount >= 0 AND rate IS NULL)),
  CONSTRAINT ck_commission_policies_status CHECK (status IN ('DRAFT','ACTIVE','SUPERSEDED','RETIRED')),
  CONSTRAINT ck_commission_policies_period CHECK (effective_to IS NULL OR effective_to > effective_from)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
-- The 5% default exists as data (decision DEC-08-04), not as a constant in code.
INSERT INTO commission_policies (id, created_at, scope, commission_type, rate, effective_from, policy_version, status, approved_at)
VALUES (UUID(), UTC_TIMESTAMP(6), 'DEFAULT', 'PERCENT', 0.050000, '2000-01-01 00:00:00.000000', 1, 'ACTIVE', UTC_TIMESTAMP(6));

CREATE TABLE approval_limits (
  id CHAR(36) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  role_code VARCHAR(40) NOT NULL,
  max_amount DECIMAL(14,2) NULL COMMENT 'NULL = no upper limit',
  currency_code CHAR(3) NOT NULL DEFAULT 'THB',
  effective_from DATETIME(6) NOT NULL,
  effective_to DATETIME(6) NULL,
  version INT NOT NULL,
  status VARCHAR(30) NOT NULL DEFAULT 'PROPOSAL',
  PRIMARY KEY (id),
  UNIQUE KEY uq_approval_limits_version (role_code, currency_code, version),
  CONSTRAINT fk_approval_limits_currency FOREIGN KEY (currency_code) REFERENCES currencies(code),
  CONSTRAINT ck_approval_limits_amount CHECK (max_amount IS NULL OR max_amount >= 0),
  CONSTRAINT ck_approval_limits_status CHECK (status IN ('PROPOSAL','APPROVED','RETIRED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
-- DEC-08-12: internal proposal, flagged PROPOSAL until the business approves it.
INSERT INTO approval_limits (id, created_at, role_code, max_amount, effective_from, version) VALUES
  (UUID(), UTC_TIMESTAMP(6), 'AUTO', 3000.00, '2000-01-01', 1),
  (UUID(), UTC_TIMESTAMP(6), 'REFUND_OFFICER', 5000.00, '2000-01-01', 1),
  (UUID(), UTC_TIMESTAMP(6), 'FINANCE_MANAGER', 50000.00, '2000-01-01', 1),
  (UUID(), UTC_TIMESTAMP(6), 'CFO_CEO', NULL, '2000-01-01', 1);

CREATE TABLE tax_rates (
  id CHAR(36) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  tax_code VARCHAR(30) NOT NULL,
  rate DECIMAL(9,6) NOT NULL,
  effective_from DATE NOT NULL,
  effective_to DATE NULL,
  category_scope VARCHAR(30) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_tax_rates (tax_code, effective_from, category_scope),
  CONSTRAINT ck_tax_rates_rate CHECK (rate >= 0 AND rate <= 1)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE consent_versions (
  id CHAR(36) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  consent_type VARCHAR(30) NOT NULL DEFAULT 'WALLET_REFUND',
  version INT NOT NULL,
  locale VARCHAR(10) NOT NULL,
  text MEDIUMTEXT NOT NULL,
  text_sha256 CHAR(64) NOT NULL,
  legal_approved_by CHAR(36) NULL,
  legal_approved_at DATETIME(6) NULL,
  effective_from DATETIME(6) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_consent_versions (consent_type, version, locale),
  CONSTRAINT ck_consent_versions_legal CHECK ((legal_approved_at IS NULL) = (legal_approved_by IS NULL)),
  CONSTRAINT ck_consent_versions_effective CHECK (effective_from IS NULL OR legal_approved_at IS NOT NULL)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE retention_policies (
  id CHAR(36) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  data_class VARCHAR(30) NOT NULL,
  min_retention_years INT NULL,
  legal_basis VARCHAR(255) NULL,
  status VARCHAR(30) NOT NULL DEFAULT 'PENDING_LEGAL_REVIEW',
  PRIMARY KEY (id),
  UNIQUE KEY uq_retention_policies_class (data_class),
  CONSTRAINT ck_retention_status CHECK (status IN ('PENDING_LEGAL_REVIEW','APPROVED')),
  CONSTRAINT ck_retention_approved_has_years CHECK (status <> 'APPROVED' OR min_retention_years IS NOT NULL)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
-- Only what the specification states (VAT documents: 5 years). Everything else waits for legal review (DEC-08-13).
INSERT INTO retention_policies (id, created_at, data_class, min_retention_years, legal_basis, status) VALUES
  (UUID(), UTC_TIMESTAMP(6), 'TAX_DOCUMENT', 5, 'Stated in Business Model specification 8.7 (VAT documents)', 'APPROVED'),
  (UUID(), UTC_TIMESTAMP(6), 'PAYMENT', NULL, NULL, 'PENDING_LEGAL_REVIEW'),
  (UUID(), UTC_TIMESTAMP(6), 'REFUND', NULL, NULL, 'PENDING_LEGAL_REVIEW'),
  (UUID(), UTC_TIMESTAMP(6), 'SETTLEMENT', NULL, NULL, 'PENDING_LEGAL_REVIEW'),
  (UUID(), UTC_TIMESTAMP(6), 'WALLET_LEDGER', NULL, NULL, 'PENDING_LEGAL_REVIEW'),
  (UUID(), UTC_TIMESTAMP(6), 'CONSENT', NULL, NULL, 'PENDING_LEGAL_REVIEW'),
  (UUID(), UTC_TIMESTAMP(6), 'AUDIT', NULL, NULL, 'PENDING_LEGAL_REVIEW'),
  (UUID(), UTC_TIMESTAMP(6), 'PERSONAL_DATA', NULL, NULL, 'PENDING_LEGAL_REVIEW');

CREATE TABLE go_live_approvals (
  id CHAR(36) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  approval_type VARCHAR(20) NOT NULL,
  approved_by CHAR(36) NOT NULL,
  approved_at DATETIME(6) NOT NULL,
  evidence_ref VARCHAR(255) NOT NULL,
  PRIMARY KEY (id),
  CONSTRAINT ck_go_live_type CHECK (approval_type IN ('PSP','LEGAL','ACCOUNTING','SECURITY'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE document_sequences (
  id CHAR(36) NOT NULL,
  issuer_entity_id CHAR(36) NOT NULL,
  series VARCHAR(20) NOT NULL,
  last_number BIGINT NOT NULL DEFAULT 0,
  updated_at DATETIME(6) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_document_sequences (issuer_entity_id, series),
  CONSTRAINT fk_document_sequences_issuer FOREIGN KEY (issuer_entity_id) REFERENCES legal_entities(id),
  CONSTRAINT ck_document_sequences_nonneg CHECK (last_number >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Policies are versioned and never edited in place; configuration tables reject DELETE.
-- (UPDATE stays possible only for status/approval fields on policies; amounts and rates are guarded below.)
DELIMITER $$
CREATE TRIGGER trg_commission_policies_guard BEFORE UPDATE ON commission_policies FOR EACH ROW
BEGIN
  IF NEW.rate <=> OLD.rate AND NEW.fixed_amount <=> OLD.fixed_amount AND NEW.commission_type = OLD.commission_type
     AND NEW.scope = OLD.scope AND NEW.policy_version = OLD.policy_version AND NEW.effective_from = OLD.effective_from
     AND NEW.partner_id <=> OLD.partner_id AND NEW.category <=> OLD.category THEN
    SET NEW.created_at = OLD.created_at;
  ELSE
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'commission_policies are versioned: create a new version instead of editing';
  END IF;
END$$
DELIMITER ;
CREATE TRIGGER trg_commission_policies_nodelete BEFORE DELETE ON commission_policies FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'commission_policies cannot be deleted';
CREATE TRIGGER trg_approval_limits_nodelete BEFORE DELETE ON approval_limits FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'approval_limits cannot be deleted';
CREATE TRIGGER trg_go_live_approvals_noupdate BEFORE UPDATE ON go_live_approvals FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'go_live_approvals is append-only';
CREATE TRIGGER trg_go_live_approvals_nodelete BEFORE DELETE ON go_live_approvals FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'go_live_approvals is append-only';
CREATE TRIGGER trg_consent_versions_nodelete BEFORE DELETE ON consent_versions FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'consent_versions cannot be deleted';
