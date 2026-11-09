-- Bookings, price snapshots, discounts, payments, webhooks, financial audit (design 0003 sections 1-3, 6).
-- Money = DECIMAL(14,2) + currency. Status columns are constrained to the 8.15 state machines (transitions are enforced by the
-- application inside a transaction; these CHECKs stop impossible values). Legacy booking status PENDING is kept until the
-- portal moves to the 8.15 booking states.

-- ---------- partners ----------
ALTER TABLE partners
  ADD COLUMN legal_entity_id CHAR(36) NULL,
  ADD COLUMN category_set VARCHAR(255) NULL,
  ADD COLUMN risk_level VARCHAR(10) NOT NULL DEFAULT 'MEDIUM',
  ADD COLUMN approved_at DATETIME(6) NULL,
  ADD COLUMN approved_by CHAR(36) NULL,
  ADD CONSTRAINT fk_partners_legal_entity FOREIGN KEY (legal_entity_id) REFERENCES legal_entities(id),
  ADD CONSTRAINT ck_partners_risk CHECK (risk_level IN ('LOW','MEDIUM','HIGH'));

ALTER TABLE partner_users
  ADD COLUMN partner_id CHAR(36) NULL,
  ADD COLUMN user_id CHAR(36) NULL,
  ADD COLUMN partner_role VARCHAR(20) NOT NULL DEFAULT 'PARTNER_ADMIN',
  ADD COLUMN active_key TINYINT GENERATED ALWAYS AS (IF(deleted_at IS NULL, 1, NULL)) VIRTUAL,
  ADD CONSTRAINT fk_partner_users_partner FOREIGN KEY (partner_id) REFERENCES partners(id),
  ADD CONSTRAINT fk_partner_users_user FOREIGN KEY (user_id) REFERENCES users(id),
  ADD CONSTRAINT ck_partner_users_role CHECK (partner_role IN ('PARTNER_ADMIN','PARTNER_FINANCE')),
  ADD UNIQUE KEY uq_partner_users_active (partner_id, user_id, active_key);

-- ---------- price snapshots / quotes / pricing rules ----------
CREATE TABLE pricing_rules (
  id CHAR(36) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  rule_version INT NOT NULL,
  category VARCHAR(30) NULL,
  partner_id CHAR(36) NULL,
  rule_type VARCHAR(20) NOT NULL,
  value DECIMAL(14,6) NOT NULL,
  effective_from DATETIME(6) NOT NULL,
  effective_to DATETIME(6) NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'DRAFT',
  PRIMARY KEY (id),
  CONSTRAINT fk_pricing_rules_partner FOREIGN KEY (partner_id) REFERENCES partners(id),
  CONSTRAINT ck_pricing_rules_type CHECK (rule_type IN ('MARKUP_PERCENT','MARKUP_FIXED','MANDATORY_FEE','TAX')),
  CONSTRAINT ck_pricing_rules_status CHECK (status IN ('DRAFT','ACTIVE','RETIRED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE pricing_quotes (
  id CHAR(36) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  user_id CHAR(36) NOT NULL,
  items_json JSON NOT NULL,
  payable_total DECIMAL(14,2) NOT NULL,
  currency_code CHAR(3) NOT NULL,
  supplier_ref VARCHAR(150) NULL,
  expires_at DATETIME(6) NOT NULL,
  revalidated_at DATETIME(6) NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'OPEN',
  PRIMARY KEY (id),
  KEY idx_pricing_quotes_user (user_id, created_at),
  CONSTRAINT fk_pricing_quotes_user FOREIGN KEY (user_id) REFERENCES users(id),
  CONSTRAINT fk_pricing_quotes_currency FOREIGN KEY (currency_code) REFERENCES currencies(code),
  CONSTRAINT ck_pricing_quotes_amount CHECK (payable_total >= 0),
  CONSTRAINT ck_pricing_quotes_status CHECK (status IN ('OPEN','USED','EXPIRED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE booking_price_snapshots (
  id CHAR(36) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  base_total DECIMAL(14,2) NOT NULL,
  discount_total DECIMAL(14,2) NOT NULL DEFAULT 0,
  tax_total DECIMAL(14,2) NOT NULL DEFAULT 0,
  mandatory_fee_total DECIMAL(14,2) NOT NULL DEFAULT 0,
  optional_fee_total DECIMAL(14,2) NOT NULL DEFAULT 0,
  service_fee_total DECIMAL(14,2) NOT NULL DEFAULT 0 COMMENT 'disabled by default (design 0002 Q1)',
  payable_total DECIMAL(14,2) NOT NULL,
  currency_code CHAR(3) NOT NULL,
  terms_json JSON NOT NULL COMMENT 'cancellation/refund policy as shown at purchase',
  supplier_price_ref VARCHAR(150) NULL,
  captured_at DATETIME(6) NOT NULL,
  PRIMARY KEY (id),
  CONSTRAINT fk_price_snapshots_currency FOREIGN KEY (currency_code) REFERENCES currencies(code),
  CONSTRAINT ck_price_snapshots_nonneg CHECK (base_total >= 0 AND discount_total >= 0 AND tax_total >= 0 AND mandatory_fee_total >= 0 AND optional_fee_total >= 0 AND service_fee_total >= 0),
  -- the payable total must equal its parts: the server can never persist an inconsistent price
  CONSTRAINT ck_price_snapshots_sum CHECK (payable_total = base_total - discount_total + tax_total + mandatory_fee_total + optional_fee_total + service_fee_total),
  CONSTRAINT ck_price_snapshots_payable CHECK (payable_total >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE booking_price_snapshot_lines (
  id CHAR(36) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  snapshot_id CHAR(36) NOT NULL,
  line_type VARCHAR(20) NOT NULL,
  label VARCHAR(255) NOT NULL,
  amount DECIMAL(14,2) NOT NULL,
  taxed_by_entity_id CHAR(36) NULL,
  vat_included VARCHAR(12) NOT NULL DEFAULT 'UNVERIFIED',
  PRIMARY KEY (id),
  KEY idx_snapshot_lines_snapshot (snapshot_id),
  CONSTRAINT fk_snapshot_lines_snapshot FOREIGN KEY (snapshot_id) REFERENCES booking_price_snapshots(id),
  CONSTRAINT fk_snapshot_lines_entity FOREIGN KEY (taxed_by_entity_id) REFERENCES legal_entities(id),
  CONSTRAINT ck_snapshot_lines_type CHECK (line_type IN ('BASE','DISCOUNT','TAX','MANDATORY_FEE','OPTIONAL_FEE','SERVICE_FEE')),
  CONSTRAINT ck_snapshot_lines_vat CHECK (vat_included IN ('YES','NO','UNVERIFIED')),
  CONSTRAINT ck_snapshot_lines_amount CHECK (amount >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------- bookings ----------
ALTER TABLE bookings
  ADD COLUMN partner_id CHAR(36) NULL,
  ADD COLUMN seller_entity_id CHAR(36) NULL,
  ADD COLUMN price_snapshot_id CHAR(36) NULL,
  ADD COLUMN pricing_quote_id CHAR(36) NULL,
  ADD COLUMN idempotency_key VARCHAR(100) NULL,
  ADD COLUMN supplier_booking_ref VARCHAR(150) NULL,
  ADD COLUMN confirmation_deadline DATETIME(6) NULL,
  ADD COLUMN expires_at DATETIME(6) NULL,
  ADD CONSTRAINT fk_bookings_partner FOREIGN KEY (partner_id) REFERENCES partners(id),
  ADD CONSTRAINT fk_bookings_seller FOREIGN KEY (seller_entity_id) REFERENCES legal_entities(id),
  ADD CONSTRAINT fk_bookings_snapshot FOREIGN KEY (price_snapshot_id) REFERENCES booking_price_snapshots(id),
  ADD CONSTRAINT fk_bookings_quote FOREIGN KEY (pricing_quote_id) REFERENCES pricing_quotes(id),
  ADD CONSTRAINT fk_bookings_currency FOREIGN KEY (currency_code) REFERENCES currencies(code),
  ADD UNIQUE KEY uq_bookings_user_idem (user_id, idempotency_key),
  ADD UNIQUE KEY uq_bookings_code (booking_code),
  ADD UNIQUE KEY uq_bookings_snapshot (price_snapshot_id),
  ADD CONSTRAINT ck_bookings_total CHECK (total_amount >= 0),
  ADD CONSTRAINT ck_bookings_status CHECK (status IN ('PENDING','DRAFT','PENDING_PAYMENT','PAYMENT_FAILED','PAID','PENDING_SUPPLIER_CONFIRMATION','CONFIRMED','REJECTED','IN_PROGRESS','COMPLETED','CANCELLATION_REQUESTED','CANCELLED'));

ALTER TABLE booking_items
  ADD COLUMN partner_id CHAR(36) NULL,
  ADD COLUMN service_date DATE NULL,
  ADD COLUMN external_booking_ref VARCHAR(150) NULL,
  ADD COLUMN title_snapshot VARCHAR(255) NULL,
  ADD CONSTRAINT fk_booking_items_partner FOREIGN KEY (partner_id) REFERENCES partners(id),
  ADD CONSTRAINT ck_booking_items_qty CHECK (quantity > 0),
  ADD CONSTRAINT ck_booking_items_amount CHECK (unit_amount >= 0);

CREATE TABLE booking_status_histories (
  id CHAR(36) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  booking_id CHAR(36) NOT NULL,
  from_status VARCHAR(30) NULL,
  to_status VARCHAR(30) NOT NULL,
  actor_type VARCHAR(20) NOT NULL,
  actor_id CHAR(36) NULL,
  reason VARCHAR(255) NULL,
  request_id VARCHAR(64) NULL,
  PRIMARY KEY (id),
  KEY idx_booking_status_histories_booking (booking_id, created_at),
  CONSTRAINT fk_booking_status_histories_booking FOREIGN KEY (booking_id) REFERENCES bookings(id),
  CONSTRAINT ck_booking_status_actor CHECK (actor_type IN ('USER','STAFF','SYSTEM','WEBHOOK','SUPPLIER'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------- discounts ----------
CREATE TABLE discounts (
  id CHAR(36) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  owner_type VARCHAR(10) NOT NULL,
  owner_partner_id CHAR(36) NULL,
  discount_type VARCHAR(10) NOT NULL,
  value DECIMAL(14,2) NOT NULL,
  min_booking_amount DECIMAL(14,2) NULL,
  max_discount DECIMAL(14,2) NULL,
  eligible_categories VARCHAR(255) NULL,
  valid_from DATETIME(6) NOT NULL,
  valid_to DATETIME(6) NULL,
  usage_limit_total INT NULL,
  usage_limit_per_user INT NULL,
  customer_eligibility VARCHAR(30) NOT NULL DEFAULT 'ALL',
  funded_by VARCHAR(10) NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'DRAFT',
  PRIMARY KEY (id),
  CONSTRAINT fk_discounts_partner FOREIGN KEY (owner_partner_id) REFERENCES partners(id),
  CONSTRAINT ck_discounts_owner CHECK (owner_type IN ('PLATFORM','PARTNER') AND ((owner_type = 'PARTNER') = (owner_partner_id IS NOT NULL))),
  CONSTRAINT ck_discounts_type CHECK (discount_type IN ('FIXED','PERCENT')),
  CONSTRAINT ck_discounts_value CHECK (value > 0 AND (discount_type <> 'PERCENT' OR value <= 100)),
  CONSTRAINT ck_discounts_funded CHECK (funded_by IN ('PLATFORM','PARTNER')),
  CONSTRAINT ck_discounts_status CHECK (status IN ('DRAFT','ACTIVE','PAUSED','RETIRED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE coupons
  ADD COLUMN discount_id CHAR(36) NULL,
  ADD COLUMN redeemed_count INT NOT NULL DEFAULT 0,
  ADD CONSTRAINT fk_coupons_discount FOREIGN KEY (discount_id) REFERENCES discounts(id),
  ADD UNIQUE KEY uq_coupons_code (code),
  ADD CONSTRAINT ck_coupons_redeemed CHECK (redeemed_count >= 0 AND (max_redemptions IS NULL OR redeemed_count <= max_redemptions));

CREATE TABLE discount_allocations (
  id CHAR(36) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  booking_id CHAR(36) NOT NULL,
  discount_id CHAR(36) NOT NULL,
  coupon_id CHAR(36) NULL,
  funded_by VARCHAR(10) NOT NULL,
  amount DECIMAL(14,2) NOT NULL,
  currency_code CHAR(3) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_discount_allocations_booking (booking_id) COMMENT 'one coupon per booking',
  CONSTRAINT fk_discount_alloc_booking FOREIGN KEY (booking_id) REFERENCES bookings(id),
  CONSTRAINT fk_discount_alloc_discount FOREIGN KEY (discount_id) REFERENCES discounts(id),
  CONSTRAINT fk_discount_alloc_coupon FOREIGN KEY (coupon_id) REFERENCES coupons(id),
  CONSTRAINT fk_discount_alloc_currency FOREIGN KEY (currency_code) REFERENCES currencies(code),
  CONSTRAINT ck_discount_alloc_funded CHECK (funded_by IN ('PLATFORM','PARTNER')),
  CONSTRAINT ck_discount_alloc_amount CHECK (amount > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------- payments ----------
ALTER TABLE payment_methods
  ADD COLUMN user_id CHAR(36) NULL,
  ADD COLUMN method_type VARCHAR(20) NULL,
  ADD COLUMN provider_token VARCHAR(255) NULL COMMENT 'PSP token only; never PAN/CVV',
  ADD COLUMN brand VARCHAR(30) NULL,
  ADD COLUMN last4 CHAR(4) NULL,
  ADD COLUMN status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
  ADD CONSTRAINT fk_payment_methods_user FOREIGN KEY (user_id) REFERENCES users(id),
  ADD CONSTRAINT ck_payment_methods_last4 CHECK (last4 IS NULL OR last4 REGEXP '^[0-9]{4}$');

CREATE TABLE payment_intents (
  id CHAR(36) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  updated_at DATETIME(6) NOT NULL,
  booking_id CHAR(36) NOT NULL,
  user_id CHAR(36) NOT NULL,
  provider VARCHAR(50) NOT NULL,
  payment_reference VARCHAR(100) NOT NULL,
  provider_intent_id VARCHAR(150) NULL,
  amount DECIMAL(14,2) NOT NULL,
  currency_code CHAR(3) NOT NULL,
  method VARCHAR(20) NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
  expires_at DATETIME(6) NOT NULL,
  idempotency_key VARCHAR(100) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_payment_intents_reference (payment_reference),
  UNIQUE KEY uq_payment_intents_idem (user_id, idempotency_key),
  KEY idx_payment_intents_booking (booking_id),
  CONSTRAINT fk_payment_intents_booking FOREIGN KEY (booking_id) REFERENCES bookings(id),
  CONSTRAINT fk_payment_intents_user FOREIGN KEY (user_id) REFERENCES users(id),
  CONSTRAINT fk_payment_intents_currency FOREIGN KEY (currency_code) REFERENCES currencies(code),
  CONSTRAINT ck_payment_intents_amount CHECK (amount > 0),
  CONSTRAINT ck_payment_intents_method CHECK (method IN ('PROMPTPAY_QR','CARD','SABAI_WALLET')),
  CONSTRAINT ck_payment_intents_status CHECK (status IN ('PENDING','PROCESSING','SUCCEEDED','FAILED','EXPIRED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE payments
  ADD COLUMN payment_intent_id CHAR(36) NULL,
  ADD COLUMN leg_no INT NOT NULL DEFAULT 1,
  ADD COLUMN captured_amount DECIMAL(14,2) NOT NULL DEFAULT 0,
  ADD COLUMN refunded_amount DECIMAL(14,2) NOT NULL DEFAULT 0,
  ADD COLUMN succeeded_at DATETIME(6) NULL,
  ADD CONSTRAINT fk_payments_intent FOREIGN KEY (payment_intent_id) REFERENCES payment_intents(id),
  ADD CONSTRAINT fk_payments_currency FOREIGN KEY (currency_code) REFERENCES currencies(code),
  ADD UNIQUE KEY uq_payments_intent_leg (payment_intent_id, leg_no),
  ADD UNIQUE KEY uq_payments_provider_ref (provider, provider_reference),
  ADD CONSTRAINT ck_payments_amount CHECK (amount > 0),
  -- you can never refund more than you captured, and never capture more than the payment
  ADD CONSTRAINT ck_payments_captured CHECK (captured_amount >= 0 AND captured_amount <= amount),
  ADD CONSTRAINT ck_payments_refunded CHECK (refunded_amount >= 0 AND refunded_amount <= captured_amount),
  ADD CONSTRAINT ck_payments_status CHECK (status IN ('PENDING','PROCESSING','SUCCEEDED','FAILED','EXPIRED'));

CREATE TABLE payment_transactions (
  id CHAR(36) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  payment_id CHAR(36) NOT NULL,
  provider VARCHAR(50) NOT NULL,
  external_id VARCHAR(150) NOT NULL,
  event_type VARCHAR(20) NOT NULL,
  amount DECIMAL(14,2) NOT NULL,
  currency_code CHAR(3) NOT NULL,
  status VARCHAR(20) NOT NULL,
  raw_payload_hash CHAR(64) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_payment_transactions_external (provider, external_id, event_type),
  KEY idx_payment_transactions_payment (payment_id),
  CONSTRAINT fk_payment_transactions_payment FOREIGN KEY (payment_id) REFERENCES payments(id),
  CONSTRAINT fk_payment_transactions_currency FOREIGN KEY (currency_code) REFERENCES currencies(code),
  CONSTRAINT ck_payment_transactions_type CHECK (event_type IN ('CHARGE','REFUND','VOID','CHARGEBACK')),
  CONSTRAINT ck_payment_transactions_amount CHECK (amount >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE payment_webhook_events (
  id CHAR(36) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  provider VARCHAR(50) NOT NULL,
  event_id VARCHAR(150) NOT NULL,
  signature_valid TINYINT(1) NOT NULL,
  event_timestamp DATETIME(6) NOT NULL,
  received_at DATETIME(6) NOT NULL,
  payload_hash CHAR(64) NOT NULL,
  processed_at DATETIME(6) NULL,
  processing_result VARCHAR(30) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_payment_webhook_events (provider, event_id) COMMENT 'duplicate delivery is rejected by the database',
  CONSTRAINT ck_payment_webhook_result CHECK (processing_result IS NULL OR processing_result IN ('APPLIED','IGNORED_DUPLICATE','REJECTED_SIGNATURE','REJECTED_REPLAY','REJECTED_UNKNOWN','FAILED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------- financial audit (hash chained, append-only) ----------
CREATE TABLE financial_audit_logs (
  id CHAR(36) NOT NULL,
  seq BIGINT NOT NULL AUTO_INCREMENT,
  occurred_at DATETIME(6) NOT NULL,
  actor_user_id CHAR(36) NULL,
  actor_type VARCHAR(20) NOT NULL DEFAULT 'USER',
  actor_roles_json JSON NULL,
  entity_type VARCHAR(50) NOT NULL,
  entity_id CHAR(36) NOT NULL,
  action VARCHAR(100) NOT NULL,
  field_changes_json JSON NULL,
  reason VARCHAR(255) NULL,
  reference_id VARCHAR(100) NULL,
  ip_address VARCHAR(64) NULL,
  device_info VARCHAR(255) NULL,
  request_id VARCHAR(64) NULL,
  prev_hash CHAR(64) NULL,
  row_hash CHAR(64) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_financial_audit_seq (seq),
  KEY idx_financial_audit_entity (entity_type, entity_id, seq),
  CONSTRAINT ck_financial_audit_actor CHECK (actor_type IN ('USER','STAFF','SYSTEM','WEBHOOK','SUPPLIER'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------- immutability ----------
-- Append-only tables: neither UPDATE nor DELETE.
CREATE TRIGGER trg_price_snapshots_nou BEFORE UPDATE ON booking_price_snapshots FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'booking_price_snapshots is immutable';
CREATE TRIGGER trg_price_snapshots_nod BEFORE DELETE ON booking_price_snapshots FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'booking_price_snapshots is immutable';
CREATE TRIGGER trg_snapshot_lines_nou BEFORE UPDATE ON booking_price_snapshot_lines FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'booking_price_snapshot_lines is immutable';
CREATE TRIGGER trg_snapshot_lines_nod BEFORE DELETE ON booking_price_snapshot_lines FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'booking_price_snapshot_lines is immutable';
CREATE TRIGGER trg_booking_histories_nou BEFORE UPDATE ON booking_status_histories FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'booking_status_histories is append-only';
CREATE TRIGGER trg_booking_histories_nod BEFORE DELETE ON booking_status_histories FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'booking_status_histories is append-only';
CREATE TRIGGER trg_discount_alloc_nou BEFORE UPDATE ON discount_allocations FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'discount_allocations is immutable';
CREATE TRIGGER trg_discount_alloc_nod BEFORE DELETE ON discount_allocations FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'discount_allocations is immutable';
CREATE TRIGGER trg_payment_transactions_nou BEFORE UPDATE ON payment_transactions FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'payment_transactions is append-only';
CREATE TRIGGER trg_payment_transactions_nod BEFORE DELETE ON payment_transactions FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'payment_transactions is append-only';
CREATE TRIGGER trg_financial_audit_nou BEFORE UPDATE ON financial_audit_logs FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'financial_audit_logs is append-only';
CREATE TRIGGER trg_financial_audit_nod BEFORE DELETE ON financial_audit_logs FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'financial_audit_logs is append-only';
-- Webhook events may only be completed (processed_at / processing_result), never rewritten or removed.
CREATE TRIGGER trg_webhook_events_nod BEFORE DELETE ON payment_webhook_events FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'payment_webhook_events cannot be deleted';
-- Money-bearing rows with a mutable status: block DELETE, and block edits to amount/currency/reference.
CREATE TRIGGER trg_payments_nod BEFORE DELETE ON payments FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'payments cannot be deleted';
CREATE TRIGGER trg_payment_intents_nod BEFORE DELETE ON payment_intents FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'payment_intents cannot be deleted';
CREATE TRIGGER trg_bookings_nod BEFORE DELETE ON bookings FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'bookings cannot be deleted';
DELIMITER $$
CREATE TRIGGER trg_payments_guard BEFORE UPDATE ON payments FOR EACH ROW
BEGIN
  IF NEW.amount <> OLD.amount OR NEW.currency_code <> OLD.currency_code OR NOT (NEW.booking_id <=> OLD.booking_id)
     OR NEW.provider <> OLD.provider OR NEW.user_id <> OLD.user_id THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'payments: amount, currency, booking, provider and user are immutable';
  END IF;
  IF OLD.status IN ('SUCCEEDED','FAILED','EXPIRED') AND NEW.status <> OLD.status THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'payments: terminal status cannot change';
  END IF;
END$$
CREATE TRIGGER trg_payment_intents_guard BEFORE UPDATE ON payment_intents FOR EACH ROW
BEGIN
  IF NEW.amount <> OLD.amount OR NEW.currency_code <> OLD.currency_code OR NEW.booking_id <> OLD.booking_id
     OR NEW.payment_reference <> OLD.payment_reference OR NEW.user_id <> OLD.user_id THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'payment_intents: amount, currency, booking and reference are immutable';
  END IF;
  IF OLD.status IN ('SUCCEEDED','FAILED','EXPIRED') AND NEW.status <> OLD.status THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'payment_intents: terminal status cannot change';
  END IF;
END$$
CREATE TRIGGER trg_bookings_guard BEFORE UPDATE ON bookings FOR EACH ROW
BEGIN
  IF NEW.total_amount <> OLD.total_amount OR NEW.currency_code <> OLD.currency_code OR NEW.user_id <> OLD.user_id
     OR NEW.booking_code <> OLD.booking_code OR (OLD.price_snapshot_id IS NOT NULL AND NOT (NEW.price_snapshot_id <=> OLD.price_snapshot_id)) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'bookings: total, currency, owner, code and price snapshot are immutable';
  END IF;
END$$
DELIMITER ;
