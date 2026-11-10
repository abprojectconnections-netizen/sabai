-- Partner contracts/bank accounts, suppliers, inventory, tax documents, reconciliation (design 0003 sections 1, 3, 6).

CREATE TABLE partner_contracts (
  id CHAR(36) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  partner_id CHAR(36) NOT NULL,
  contract_no VARCHAR(60) NOT NULL,
  version INT NOT NULL,
  starts_on DATE NOT NULL,
  ends_on DATE NULL,
  seller_of_record VARCHAR(10) NOT NULL DEFAULT 'PARTNER',
  invoice_authorization TINYINT(1) NOT NULL DEFAULT 0,
  psp_fee_bearer VARCHAR(10) NOT NULL DEFAULT 'PLATFORM',
  settlement_weekday VARCHAR(3) NOT NULL DEFAULT 'TUE',
  reconciliation_days INT NOT NULL DEFAULT 7,
  commission_policy_id CHAR(36) NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'DRAFT',
  legal_review_ref VARCHAR(150) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_partner_contracts_version (partner_id, contract_no, version),
  CONSTRAINT fk_partner_contracts_partner FOREIGN KEY (partner_id) REFERENCES partners(id),
  CONSTRAINT fk_partner_contracts_policy FOREIGN KEY (commission_policy_id) REFERENCES commission_policies(id),
  CONSTRAINT ck_partner_contracts_seller CHECK (seller_of_record IN ('PARTNER','PLATFORM')),
  CONSTRAINT ck_partner_contracts_fee CHECK (psp_fee_bearer IN ('PLATFORM','PARTNER','SHARED')),
  CONSTRAINT ck_partner_contracts_weekday CHECK (settlement_weekday IN ('MON','TUE','WED','THU','FRI')),
  CONSTRAINT ck_partner_contracts_recon CHECK (reconciliation_days >= 0),
  CONSTRAINT ck_partner_contracts_status CHECK (status IN ('DRAFT','ACTIVE','ENDED')),
  CONSTRAINT ck_partner_contracts_period CHECK (ends_on IS NULL OR ends_on >= starts_on),
  -- 8.7.1 / prohibition 5: the platform may issue documents for a partner, or sell in its own name, only with a recorded legal review
  CONSTRAINT ck_partner_contracts_legal CHECK ((invoice_authorization = 0 AND seller_of_record = 'PARTNER') OR legal_review_ref IS NOT NULL)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE partner_bank_accounts (
  id CHAR(36) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  partner_id CHAR(36) NOT NULL,
  bank_code VARCHAR(20) NOT NULL,
  account_name VARCHAR(200) NOT NULL,
  account_number_enc VARBINARY(512) NOT NULL COMMENT 'encrypted by the application with a managed key',
  account_last4 CHAR(4) NOT NULL,
  verified_at DATETIME(6) NULL,
  verified_by CHAR(36) NULL,
  valid_from DATETIME(6) NOT NULL,
  valid_to DATETIME(6) NULL,
  PRIMARY KEY (id),
  KEY idx_partner_bank_accounts_partner (partner_id),
  CONSTRAINT fk_partner_bank_accounts_partner FOREIGN KEY (partner_id) REFERENCES partners(id),
  CONSTRAINT ck_partner_bank_last4 CHECK (account_last4 REGEXP '^[0-9]{4}$'),
  CONSTRAINT ck_partner_bank_verified CHECK ((verified_at IS NULL) = (verified_by IS NULL))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
ALTER TABLE partner_payouts
  ADD CONSTRAINT fk_payouts_bank_account FOREIGN KEY (partner_bank_account_id) REFERENCES partner_bank_accounts(id);

CREATE TABLE suppliers (
  id CHAR(36) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  updated_at DATETIME(6) NOT NULL,
  supplier_type VARCHAR(20) NOT NULL,
  adapter_code VARCHAR(50) NOT NULL,
  mode VARCHAR(10) NOT NULL DEFAULT 'MOCK',
  status VARCHAR(20) NOT NULL DEFAULT 'DISABLED',
  timeout_ms INT NOT NULL DEFAULT 10000,
  max_retries INT NOT NULL DEFAULT 2,
  PRIMARY KEY (id),
  UNIQUE KEY uq_suppliers_adapter (adapter_code),
  CONSTRAINT ck_suppliers_type CHECK (supplier_type IN ('INTERNAL','HOTEL','TOUR','FLIGHT','TRANSPORT','ATTRACTION')),
  CONSTRAINT ck_suppliers_mode CHECK (mode IN ('MOCK','SANDBOX','LIVE')),
  CONSTRAINT ck_suppliers_status CHECK (status IN ('DISABLED','ENABLED')),
  CONSTRAINT ck_suppliers_limits CHECK (timeout_ms > 0 AND max_retries >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
INSERT INTO suppliers (id, created_at, updated_at, supplier_type, adapter_code, mode, status)
VALUES (UUID(), UTC_TIMESTAMP(6), UTC_TIMESTAMP(6), 'INTERNAL', 'internal', 'LIVE', 'ENABLED'),
       (UUID(), UTC_TIMESTAMP(6), UTC_TIMESTAMP(6), 'FLIGHT', 'mock_flight', 'MOCK', 'DISABLED');

CREATE TABLE supplier_credentials (
  id CHAR(36) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  supplier_id CHAR(36) NOT NULL,
  secret_ref VARCHAR(255) NOT NULL COMMENT 'pointer into the secret manager; never a secret value',
  rotated_at DATETIME(6) NULL,
  PRIMARY KEY (id),
  CONSTRAINT fk_supplier_credentials_supplier FOREIGN KEY (supplier_id) REFERENCES suppliers(id),
  CONSTRAINT ck_supplier_credentials_ref CHECK (secret_ref REGEXP '^[a-z0-9_-]+://')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE supplier_products (
  id CHAR(36) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  updated_at DATETIME(6) NOT NULL,
  supplier_id CHAR(36) NOT NULL,
  partner_id CHAR(36) NULL,
  category VARCHAR(20) NOT NULL,
  external_ref VARCHAR(150) NOT NULL,
  internal_ref_type VARCHAR(30) NULL,
  internal_ref_id CHAR(36) NULL,
  confirmation_mode VARCHAR(10) NOT NULL DEFAULT 'MANUAL',
  PRIMARY KEY (id),
  UNIQUE KEY uq_supplier_products_ext (supplier_id, external_ref),
  CONSTRAINT fk_supplier_products_supplier FOREIGN KEY (supplier_id) REFERENCES suppliers(id),
  CONSTRAINT fk_supplier_products_partner FOREIGN KEY (partner_id) REFERENCES partners(id),
  CONSTRAINT ck_supplier_products_category CHECK (category IN ('HOTEL','TOUR','FLIGHT','TRANSPORT','ATTRACTION')),
  CONSTRAINT ck_supplier_products_mode CHECK (confirmation_mode IN ('INSTANT','MANUAL','ADAPTER'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
ALTER TABLE booking_items
  ADD COLUMN supplier_product_id CHAR(36) NULL,
  ADD CONSTRAINT fk_booking_items_supplier_product FOREIGN KEY (supplier_product_id) REFERENCES supplier_products(id);

CREATE TABLE inventory_items (
  id CHAR(36) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  supplier_product_id CHAR(36) NOT NULL,
  sku VARCHAR(100) NOT NULL,
  capacity_unit VARCHAR(20) NOT NULL DEFAULT 'UNIT',
  status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
  PRIMARY KEY (id),
  UNIQUE KEY uq_inventory_items_sku (supplier_product_id, sku),
  CONSTRAINT fk_inventory_items_product FOREIGN KEY (supplier_product_id) REFERENCES supplier_products(id),
  CONSTRAINT ck_inventory_items_status CHECK (status IN ('ACTIVE','PAUSED','RETIRED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE inventory_availability (
  id CHAR(36) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  updated_at DATETIME(6) NOT NULL,
  inventory_item_id CHAR(36) NOT NULL,
  service_date DATE NOT NULL,
  quantity_total INT NOT NULL,
  quantity_sold INT NOT NULL DEFAULT 0,
  base_price DECIMAL(14,2) NOT NULL,
  currency_code CHAR(3) NOT NULL DEFAULT 'THB',
  PRIMARY KEY (id),
  UNIQUE KEY uq_inventory_availability_day (inventory_item_id, service_date),
  CONSTRAINT fk_inventory_availability_item FOREIGN KEY (inventory_item_id) REFERENCES inventory_items(id),
  CONSTRAINT fk_inventory_availability_currency FOREIGN KEY (currency_code) REFERENCES currencies(code),
  -- overselling is impossible at the database level, whatever the application does
  CONSTRAINT ck_inventory_availability_qty CHECK (quantity_total >= 0 AND quantity_sold >= 0 AND quantity_sold <= quantity_total),
  CONSTRAINT ck_inventory_availability_price CHECK (base_price >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE inventory_holds (
  id CHAR(36) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  updated_at DATETIME(6) NOT NULL,
  booking_id CHAR(36) NOT NULL,
  inventory_item_id CHAR(36) NOT NULL,
  service_date DATE NOT NULL,
  quantity INT NOT NULL,
  expires_at DATETIME(6) NOT NULL,
  status VARCHAR(10) NOT NULL DEFAULT 'HELD',
  PRIMARY KEY (id),
  UNIQUE KEY uq_inventory_holds_booking_item (booking_id, inventory_item_id, service_date),
  KEY idx_inventory_holds_expiry (status, expires_at),
  CONSTRAINT fk_inventory_holds_booking FOREIGN KEY (booking_id) REFERENCES bookings(id),
  CONSTRAINT fk_inventory_holds_item FOREIGN KEY (inventory_item_id) REFERENCES inventory_items(id),
  CONSTRAINT ck_inventory_holds_qty CHECK (quantity > 0),
  CONSTRAINT ck_inventory_holds_status CHECK (status IN ('HELD','CONSUMED','RELEASED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------- tax documents ----------
CREATE TABLE tax_documents (
  id CHAR(36) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  updated_at DATETIME(6) NOT NULL,
  document_type VARCHAR(30) NOT NULL,
  issuer_entity_id CHAR(36) NOT NULL,
  series VARCHAR(20) NULL,
  document_no VARCHAR(60) NULL,
  recipient_name VARCHAR(255) NULL,
  recipient_tax_id VARCHAR(30) NULL,
  recipient_address TEXT NULL,
  recipient_branch VARCHAR(10) NULL,
  issued_at DATETIME(6) NULL,
  taxable_amount DECIMAL(14,2) NOT NULL DEFAULT 0,
  vat_amount DECIMAL(14,2) NOT NULL DEFAULT 0,
  total_amount DECIMAL(14,2) NOT NULL DEFAULT 0,
  currency_code CHAR(3) NOT NULL DEFAULT 'THB',
  parent_document_id CHAR(36) NULL,
  booking_id CHAR(36) NULL,
  settlement_batch_id CHAR(36) NULL,
  refund_request_id CHAR(36) NULL,
  status VARCHAR(10) NOT NULL DEFAULT 'DRAFT',
  PRIMARY KEY (id),
  UNIQUE KEY uq_tax_documents_no (issuer_entity_id, series, document_no),
  CONSTRAINT fk_tax_documents_issuer FOREIGN KEY (issuer_entity_id) REFERENCES legal_entities(id),
  CONSTRAINT fk_tax_documents_parent FOREIGN KEY (parent_document_id) REFERENCES tax_documents(id),
  CONSTRAINT fk_tax_documents_booking FOREIGN KEY (booking_id) REFERENCES bookings(id),
  CONSTRAINT fk_tax_documents_batch FOREIGN KEY (settlement_batch_id) REFERENCES partner_settlement_batches(id),
  CONSTRAINT fk_tax_documents_refund FOREIGN KEY (refund_request_id) REFERENCES refund_requests(id),
  CONSTRAINT fk_tax_documents_currency FOREIGN KEY (currency_code) REFERENCES currencies(code),
  CONSTRAINT ck_tax_documents_type CHECK (document_type IN ('BOOKING_CONFIRMATION','PAYMENT_RECEIPT','TAX_INVOICE','COMMISSION_INVOICE','CREDIT_NOTE','REFUND_CONFIRMATION','SETTLEMENT_STATEMENT')),
  CONSTRAINT ck_tax_documents_status CHECK (status IN ('DRAFT','ISSUED','VOIDED')),
  CONSTRAINT ck_tax_documents_total CHECK (total_amount = taxable_amount + vat_amount AND taxable_amount >= 0 AND vat_amount >= 0),
  CONSTRAINT ck_tax_documents_issued CHECK (status = 'DRAFT' OR (document_no IS NOT NULL AND issued_at IS NOT NULL)),
  CONSTRAINT ck_tax_documents_credit CHECK (document_type <> 'CREDIT_NOTE' OR parent_document_id IS NOT NULL)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
ALTER TABLE partner_settlement_batches
  ADD CONSTRAINT fk_settlement_batches_statement FOREIGN KEY (statement_document_id) REFERENCES tax_documents(id);

CREATE TABLE tax_document_items (
  id CHAR(36) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  tax_document_id CHAR(36) NOT NULL,
  description VARCHAR(500) NOT NULL,
  quantity DECIMAL(12,3) NOT NULL DEFAULT 1,
  unit_price DECIMAL(14,2) NOT NULL,
  tax_rate_id CHAR(36) NULL,
  taxable_amount DECIMAL(14,2) NOT NULL,
  vat_amount DECIMAL(14,2) NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  CONSTRAINT fk_tax_document_items_doc FOREIGN KEY (tax_document_id) REFERENCES tax_documents(id),
  CONSTRAINT fk_tax_document_items_rate FOREIGN KEY (tax_rate_id) REFERENCES tax_rates(id),
  CONSTRAINT ck_tax_document_items_qty CHECK (quantity > 0 AND unit_price >= 0 AND taxable_amount >= 0 AND vat_amount >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------- reconciliation ----------
CREATE TABLE payment_reconciliations (
  id CHAR(36) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  provider VARCHAR(50) NOT NULL,
  period_from DATETIME(6) NOT NULL,
  period_to DATETIME(6) NOT NULL,
  source_file_ref VARCHAR(255) NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'RUNNING',
  matched_count INT NOT NULL DEFAULT 0,
  unmatched_count INT NOT NULL DEFAULT 0,
  run_by CHAR(36) NULL,
  PRIMARY KEY (id),
  CONSTRAINT ck_payment_recon_status CHECK (status IN ('RUNNING','COMPLETED','FAILED')),
  CONSTRAINT ck_payment_recon_period CHECK (period_to > period_from),
  CONSTRAINT ck_payment_recon_counts CHECK (matched_count >= 0 AND unmatched_count >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE financial_reconciliation_records (
  id CHAR(36) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  reconciliation_id CHAR(36) NOT NULL,
  subject_type VARCHAR(10) NOT NULL,
  subject_id CHAR(36) NULL,
  provider_amount DECIMAL(14,2) NULL,
  our_amount DECIMAL(14,2) NULL,
  result VARCHAR(20) NOT NULL,
  resolved_by CHAR(36) NULL,
  resolution_note VARCHAR(500) NULL,
  PRIMARY KEY (id),
  CONSTRAINT fk_recon_records_recon FOREIGN KEY (reconciliation_id) REFERENCES payment_reconciliations(id),
  CONSTRAINT ck_recon_records_subject CHECK (subject_type IN ('PAYMENT','REFUND','PAYOUT')),
  CONSTRAINT ck_recon_records_result CHECK (result IN ('MATCHED','MISSING_PROVIDER','MISSING_OURS','AMOUNT_MISMATCH')),
  CONSTRAINT ck_recon_records_match CHECK (result <> 'MATCHED' OR (provider_amount IS NOT NULL AND provider_amount = our_amount)),
  CONSTRAINT ck_recon_records_mismatch CHECK (result <> 'AMOUNT_MISMATCH' OR (provider_amount IS NOT NULL AND our_amount IS NOT NULL AND provider_amount <> our_amount))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE disputes
  ADD COLUMN payment_id CHAR(36) NULL,
  ADD COLUMN dispute_type VARCHAR(20) NOT NULL DEFAULT 'CUSTOMER',
  ADD CONSTRAINT fk_disputes_payment FOREIGN KEY (payment_id) REFERENCES payments(id),
  ADD CONSTRAINT ck_disputes_type CHECK (dispute_type IN ('CUSTOMER','CHARGEBACK','FRAUD_ALERT'));

-- ---------- invariants ----------
DELIMITER $$
-- The legal gate for tax invoices issued on a partner's behalf (8.7.1, prohibition 5), enforced where it cannot be bypassed.
CREATE TRIGGER trg_tax_documents_issuer_gate BEFORE INSERT ON tax_documents FOR EACH ROW
BEGIN
  DECLARE issuer_type VARCHAR(20);
  DECLARE authorised INT DEFAULT 0;
  IF NEW.document_type IN ('TAX_INVOICE','CREDIT_NOTE') THEN
    SELECT entity_type INTO issuer_type FROM legal_entities WHERE id = NEW.issuer_entity_id;
    IF issuer_type = 'PARTNER' AND NEW.status <> 'DRAFT' THEN
      SELECT COUNT(*) INTO authorised
        FROM bookings b JOIN partner_contracts c ON c.partner_id = b.partner_id AND c.status = 'ACTIVE'
        WHERE b.id = NEW.booking_id AND c.invoice_authorization = 1 AND c.legal_review_ref IS NOT NULL;
      IF authorised = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'a tax invoice for a partner can only be issued with invoice authorization and a recorded legal review';
      END IF;
    END IF;
  END IF;
END$$
-- Issued tax documents are immutable; only DRAFT -> ISSUED and ISSUED -> VOIDED are allowed. Corrections are credit notes.
CREATE TRIGGER trg_tax_documents_guard BEFORE UPDATE ON tax_documents FOR EACH ROW
BEGIN
  IF OLD.status IN ('ISSUED','VOIDED') AND
     (NEW.document_no <=> OLD.document_no) AND (NEW.taxable_amount = OLD.taxable_amount) AND (NEW.vat_amount = OLD.vat_amount)
     AND (NEW.total_amount = OLD.total_amount) AND (NEW.issuer_entity_id = OLD.issuer_entity_id)
     AND (NEW.recipient_name <=> OLD.recipient_name) AND (NEW.recipient_tax_id <=> OLD.recipient_tax_id)
     AND (NEW.status = OLD.status OR (OLD.status = 'ISSUED' AND NEW.status = 'VOIDED')) THEN
    SET NEW.updated_at = NEW.updated_at;
  ELSEIF OLD.status = 'DRAFT' THEN
    SET NEW.updated_at = NEW.updated_at;
  ELSE
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'issued tax documents are immutable; issue a credit note instead';
  END IF;
END$$
-- Gap-free numbering helper invariant: the sequence can only move forward by one.
CREATE TRIGGER trg_document_sequences_forward BEFORE UPDATE ON document_sequences FOR EACH ROW
BEGIN
  IF NEW.last_number <> OLD.last_number + 1 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'document_sequences can only advance by exactly one';
  END IF;
END$$
DELIMITER ;
CREATE TRIGGER trg_document_sequences_nod BEFORE DELETE ON document_sequences FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'document_sequences cannot be deleted';
CREATE TRIGGER trg_tax_documents_nod BEFORE DELETE ON tax_documents FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'tax_documents cannot be deleted';
CREATE TRIGGER trg_tax_document_items_nou BEFORE UPDATE ON tax_document_items FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'tax_document_items is immutable';
CREATE TRIGGER trg_tax_document_items_nod BEFORE DELETE ON tax_document_items FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'tax_document_items is immutable';
CREATE TRIGGER trg_recon_records_nou BEFORE UPDATE ON financial_reconciliation_records FOR EACH ROW
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'financial_reconciliation_records is append-only';
CREATE TRIGGER trg_recon_records_nod BEFORE DELETE ON financial_reconciliation_records FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'financial_reconciliation_records is append-only';
CREATE TRIGGER trg_partner_contracts_nou BEFORE UPDATE ON partner_contracts FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'partner_contracts are versioned: insert a new version';
CREATE TRIGGER trg_partner_contracts_nod BEFORE DELETE ON partner_contracts FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'partner_contracts cannot be deleted';
CREATE TRIGGER trg_partner_bank_nod BEFORE DELETE ON partner_bank_accounts FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'partner_bank_accounts cannot be deleted';
