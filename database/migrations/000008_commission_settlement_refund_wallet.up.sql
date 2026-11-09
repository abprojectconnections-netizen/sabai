-- Commission, settlement, payout, refund, Sabai Wallet ledger, consent (design 0003 sections 4-5).
-- Replaces the id-only skeleton tables from 000001 (none held data; no foreign keys referenced them).

DROP TABLE commissions;
DROP TABLE commission_transactions;
DROP TABLE wallet_transactions;
DROP TABLE refunds;
DROP TABLE cancellations;
DROP TABLE coupon_redemptions;

-- ---------- commission ----------
CREATE TABLE commission_calculations (
  id CHAR(36) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  booking_id CHAR(36) NOT NULL,
  partner_id CHAR(36) NOT NULL,
  kind VARCHAR(20) NOT NULL DEFAULT 'ORIGINAL',
  refund_request_id CHAR(36) NULL,
  commission_policy_id CHAR(36) NOT NULL,
  policy_version INT NOT NULL,
  commission_type VARCHAR(10) NOT NULL,
  commission_rate DECIMAL(9,6) NULL,
  eligible_service_amount DECIMAL(14,2) NOT NULL,
  partner_funded_discount DECIMAL(14,2) NOT NULL DEFAULT 0,
  excluded_pass_through DECIMAL(14,2) NOT NULL DEFAULT 0,
  commission_base_amount DECIMAL(14,2) NOT NULL,
  commission_amount DECIMAL(14,2) NOT NULL,
  currency_code CHAR(3) NOT NULL,
  calculation_timestamp DATETIME(6) NOT NULL,
  PRIMARY KEY (id),
  KEY idx_commission_calc_booking (booking_id),
  KEY idx_commission_calc_partner (partner_id, calculation_timestamp),
  UNIQUE KEY uq_commission_calc_original (booking_id, kind, refund_request_id),
  CONSTRAINT fk_commission_calc_booking FOREIGN KEY (booking_id) REFERENCES bookings(id),
  CONSTRAINT fk_commission_calc_partner FOREIGN KEY (partner_id) REFERENCES partners(id),
  CONSTRAINT fk_commission_calc_policy FOREIGN KEY (commission_policy_id) REFERENCES commission_policies(id),
  CONSTRAINT fk_commission_calc_currency FOREIGN KEY (currency_code) REFERENCES currencies(code),
  CONSTRAINT ck_commission_calc_kind CHECK (kind IN ('ORIGINAL','REFUND_REVERSAL')),
  CONSTRAINT ck_commission_calc_type CHECK (commission_type IN ('PERCENT','FIXED')),
  -- 8.4.2: base = eligible service amount - partner-funded discount - excluded pass-through (platform-funded discounts do not reduce it)
  CONSTRAINT ck_commission_calc_base CHECK (commission_base_amount = eligible_service_amount - partner_funded_discount - excluded_pass_through),
  CONSTRAINT ck_commission_calc_nonneg CHECK (eligible_service_amount >= 0 AND partner_funded_discount >= 0 AND excluded_pass_through >= 0),
  -- percent rule: amount = ROUND(base * rate, 2); the spec example (10,000 at 5% = 500) is a unit test
  CONSTRAINT ck_commission_calc_percent CHECK (commission_type <> 'PERCENT' OR (commission_rate IS NOT NULL AND commission_amount = ROUND(commission_base_amount * commission_rate, 2))),
  CONSTRAINT ck_commission_calc_sign CHECK ((kind = 'ORIGINAL' AND commission_amount >= 0) OR (kind = 'REFUND_REVERSAL' AND commission_amount <= 0 AND refund_request_id IS NOT NULL))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------- settlement ----------
CREATE TABLE partner_settlement_batches (
  id CHAR(36) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  updated_at DATETIME(6) NOT NULL,
  partner_id CHAR(36) NOT NULL,
  period_from DATE NOT NULL,
  period_to DATE NOT NULL,
  currency_code CHAR(3) NOT NULL,
  gross_sales DECIMAL(14,2) NOT NULL DEFAULT 0,
  commission_total DECIMAL(14,2) NOT NULL DEFAULT 0,
  fees_total DECIMAL(14,2) NOT NULL DEFAULT 0,
  refunds_total DECIMAL(14,2) NOT NULL DEFAULT 0,
  net_amount DECIMAL(14,2) NOT NULL DEFAULT 0,
  status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
  on_hold_reason VARCHAR(255) NULL,
  created_by CHAR(36) NULL COMMENT 'NULL = created by the scheduled system job',
  reviewed_by CHAR(36) NULL,
  approved_by CHAR(36) NULL,
  approved_at DATETIME(6) NULL,
  statement_document_id CHAR(36) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_settlement_batches_period (partner_id, period_from, period_to),
  CONSTRAINT fk_settlement_batches_partner FOREIGN KEY (partner_id) REFERENCES partners(id),
  CONSTRAINT fk_settlement_batches_currency FOREIGN KEY (currency_code) REFERENCES currencies(code),
  CONSTRAINT ck_settlement_batches_period CHECK (period_to >= period_from),
  CONSTRAINT ck_settlement_batches_status CHECK (status IN ('PENDING','CALCULATED','UNDER_REVIEW','APPROVED','ON_HOLD','PAYOUT_PROCESSING','PAID','FAILED')),
  -- net = gross - commission - fees - refunds
  CONSTRAINT ck_settlement_batches_net CHECK (net_amount = gross_sales - commission_total - fees_total - refunds_total),
  -- separation of duties: whoever created or reviewed a batch cannot approve it
  CONSTRAINT ck_settlement_batches_sod CHECK (approved_by IS NULL OR ((created_by IS NULL OR approved_by <> created_by) AND (reviewed_by IS NULL OR approved_by <> reviewed_by))),
  CONSTRAINT ck_settlement_batches_approved CHECK (status NOT IN ('APPROVED','PAYOUT_PROCESSING','PAID') OR (approved_by IS NOT NULL AND approved_at IS NOT NULL)),
  CONSTRAINT ck_settlement_batches_hold CHECK (status <> 'ON_HOLD' OR on_hold_reason IS NOT NULL)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE partner_settlement_items (
  id CHAR(36) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  batch_id CHAR(36) NOT NULL,
  booking_id CHAR(36) NOT NULL,
  commission_calculation_id CHAR(36) NOT NULL,
  kind VARCHAR(20) NOT NULL DEFAULT 'ORIGINAL',
  eligible_on DATETIME(6) NOT NULL COMMENT 'service completed + reconciliation window',
  gross_amount DECIMAL(14,2) NOT NULL,
  commission_amount DECIMAL(14,2) NOT NULL,
  net_amount DECIMAL(14,2) NOT NULL,
  on_hold TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uq_settlement_items_calc (commission_calculation_id) COMMENT 'a commission calculation can be settled once',
  KEY idx_settlement_items_batch (batch_id),
  CONSTRAINT fk_settlement_items_batch FOREIGN KEY (batch_id) REFERENCES partner_settlement_batches(id),
  CONSTRAINT fk_settlement_items_booking FOREIGN KEY (booking_id) REFERENCES bookings(id),
  CONSTRAINT fk_settlement_items_calc FOREIGN KEY (commission_calculation_id) REFERENCES commission_calculations(id),
  CONSTRAINT ck_settlement_items_kind CHECK (kind IN ('ORIGINAL','REFUND_REVERSAL')),
  CONSTRAINT ck_settlement_items_net CHECK (net_amount = gross_amount - commission_amount)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE settlement_adjustments (
  id CHAR(36) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  batch_id CHAR(36) NOT NULL,
  adjustment_type VARCHAR(30) NOT NULL,
  amount DECIMAL(14,2) NOT NULL COMMENT 'signed',
  reason VARCHAR(255) NOT NULL,
  created_by CHAR(36) NOT NULL,
  approved_by CHAR(36) NULL,
  PRIMARY KEY (id),
  CONSTRAINT fk_settlement_adjustments_batch FOREIGN KEY (batch_id) REFERENCES partner_settlement_batches(id),
  CONSTRAINT ck_settlement_adjustments_amount CHECK (amount <> 0),
  CONSTRAINT ck_settlement_adjustments_sod CHECK (approved_by IS NULL OR approved_by <> created_by)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE partner_payouts (
  id CHAR(36) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  updated_at DATETIME(6) NOT NULL,
  batch_id CHAR(36) NOT NULL,
  attempt_no INT NOT NULL,
  partner_bank_account_id CHAR(36) NULL,
  amount DECIMAL(14,2) NOT NULL,
  currency_code CHAR(3) NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
  payout_reference VARCHAR(150) NULL,
  idempotency_key VARCHAR(100) NOT NULL,
  initiated_by CHAR(36) NULL,
  failed_reason VARCHAR(255) NULL,
  live_key TINYINT GENERATED ALWAYS AS (IF(status = 'FAILED', NULL, 1)) VIRTUAL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_payouts_attempt (batch_id, attempt_no),
  UNIQUE KEY uq_payouts_idem (idempotency_key),
  UNIQUE KEY uq_payouts_one_live (batch_id, live_key) COMMENT 'at most one non-failed payout per batch: no duplicate payout',
  CONSTRAINT fk_payouts_batch FOREIGN KEY (batch_id) REFERENCES partner_settlement_batches(id),
  CONSTRAINT fk_payouts_currency FOREIGN KEY (currency_code) REFERENCES currencies(code),
  CONSTRAINT ck_payouts_amount CHECK (amount > 0),
  CONSTRAINT ck_payouts_status CHECK (status IN ('PENDING','PROCESSING','PAID','FAILED')),
  CONSTRAINT ck_payouts_failed CHECK (status <> 'FAILED' OR failed_reason IS NOT NULL)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------- refunds ----------
CREATE TABLE refund_requests (
  id CHAR(36) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  updated_at DATETIME(6) NOT NULL,
  booking_id CHAR(36) NOT NULL,
  payment_id CHAR(36) NOT NULL,
  requested_by CHAR(36) NULL COMMENT 'NULL = system (supplier rejection / timeout)',
  reason_code VARCHAR(40) NOT NULL,
  reason_text VARCHAR(500) NULL,
  requested_amount DECIMAL(14,2) NOT NULL,
  calculated_amount DECIMAL(14,2) NULL,
  approved_amount DECIMAL(14,2) NULL,
  currency_code CHAR(3) NOT NULL,
  method VARCHAR(20) NOT NULL COMMENT 'no default: wallet is never preselected',
  status VARCHAR(20) NOT NULL DEFAULT 'REQUESTED',
  supplier_refund_status VARCHAR(10) NULL,
  psp_refund_status VARCHAR(10) NULL,
  risk_flag TINYINT(1) NOT NULL DEFAULT 0,
  auto_eligible TINYINT(1) NOT NULL DEFAULT 0,
  idempotency_key VARCHAR(100) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_refund_requests_idem (idempotency_key),
  KEY idx_refund_requests_booking (booking_id),
  KEY idx_refund_requests_payment (payment_id),
  CONSTRAINT fk_refund_requests_booking FOREIGN KEY (booking_id) REFERENCES bookings(id),
  CONSTRAINT fk_refund_requests_payment FOREIGN KEY (payment_id) REFERENCES payments(id),
  CONSTRAINT fk_refund_requests_currency FOREIGN KEY (currency_code) REFERENCES currencies(code),
  CONSTRAINT ck_refund_requests_method CHECK (method IN ('ORIGINAL_METHOD','SABAI_WALLET')),
  CONSTRAINT ck_refund_requests_status CHECK (status IN ('REQUESTED','UNDER_REVIEW','APPROVED','REJECTED','PROCESSING','COMPLETED','FAILED')),
  CONSTRAINT ck_refund_requests_amounts CHECK (requested_amount > 0 AND (approved_amount IS NULL OR (approved_amount > 0 AND approved_amount <= requested_amount))),
  CONSTRAINT ck_refund_requests_sub CHECK ((supplier_refund_status IS NULL OR supplier_refund_status IN ('PENDING','DONE','FAILED')) AND (psp_refund_status IS NULL OR psp_refund_status IN ('PENDING','DONE','FAILED'))),
  CONSTRAINT ck_refund_requests_approved CHECK (status NOT IN ('APPROVED','PROCESSING','COMPLETED') OR approved_amount IS NOT NULL)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE commission_calculations
  ADD CONSTRAINT fk_commission_calc_refund FOREIGN KEY (refund_request_id) REFERENCES refund_requests(id);

CREATE TABLE refund_approvals (
  id CHAR(36) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  refund_request_id CHAR(36) NOT NULL,
  approver_user_id CHAR(36) NOT NULL,
  approver_role VARCHAR(40) NOT NULL,
  decision VARCHAR(10) NOT NULL,
  limit_at_decision DECIMAL(14,2) NULL,
  reason VARCHAR(500) NULL,
  decided_at DATETIME(6) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_refund_approvals_once (refund_request_id, approver_user_id) COMMENT 'two-approver rule needs two distinct people',
  CONSTRAINT fk_refund_approvals_request FOREIGN KEY (refund_request_id) REFERENCES refund_requests(id),
  CONSTRAINT fk_refund_approvals_user FOREIGN KEY (approver_user_id) REFERENCES users(id),
  CONSTRAINT ck_refund_approvals_decision CHECK (decision IN ('APPROVE','REJECT'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE wallet_consents (
  id CHAR(36) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  user_id CHAR(36) NOT NULL,
  booking_id CHAR(36) NOT NULL,
  refund_request_id CHAR(36) NOT NULL,
  consent_version_id CHAR(36) NOT NULL,
  text_sha256_shown CHAR(64) NOT NULL,
  presented_at DATETIME(6) NOT NULL,
  accepted_at DATETIME(6) NOT NULL,
  ip_address VARCHAR(64) NULL,
  device_info VARCHAR(255) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_wallet_consents_request (refund_request_id),
  CONSTRAINT fk_wallet_consents_user FOREIGN KEY (user_id) REFERENCES users(id),
  CONSTRAINT fk_wallet_consents_booking FOREIGN KEY (booking_id) REFERENCES bookings(id),
  CONSTRAINT fk_wallet_consents_request FOREIGN KEY (refund_request_id) REFERENCES refund_requests(id),
  CONSTRAINT fk_wallet_consents_version FOREIGN KEY (consent_version_id) REFERENCES consent_versions(id),
  CONSTRAINT ck_wallet_consents_time CHECK (accepted_at >= presented_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------- wallet ----------
ALTER TABLE wallets
  ADD COLUMN balance_type VARCHAR(20) NOT NULL DEFAULT 'REFUND_CREDIT',
  ADD COLUMN status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
  ADD CONSTRAINT fk_wallets_user FOREIGN KEY (user_id) REFERENCES users(id),
  ADD CONSTRAINT fk_wallets_currency FOREIGN KEY (currency_code) REFERENCES currencies(code),
  ADD UNIQUE KEY uq_wallets_user_currency (user_id, currency_code),
  ADD CONSTRAINT ck_wallets_balances CHECK (available_balance >= 0 AND pending_balance >= 0),
  ADD CONSTRAINT ck_wallets_type CHECK (balance_type IN ('REFUND_CREDIT')),
  ADD CONSTRAINT ck_wallets_status CHECK (status IN ('ACTIVE','FROZEN','CLOSED'));

CREATE TABLE refund_transactions (
  id CHAR(36) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  updated_at DATETIME(6) NOT NULL,
  refund_request_id CHAR(36) NOT NULL,
  attempt_no INT NOT NULL,
  destination VARCHAR(20) NOT NULL,
  amount DECIMAL(14,2) NOT NULL,
  currency_code CHAR(3) NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
  psp_reference VARCHAR(150) NULL,
  wallet_ledger_entry_id CHAR(36) NULL,
  idempotency_key VARCHAR(100) NOT NULL,
  live_key TINYINT GENERATED ALWAYS AS (IF(status = 'FAILED', NULL, 1)) VIRTUAL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_refund_transactions_attempt (refund_request_id, attempt_no),
  UNIQUE KEY uq_refund_transactions_idem (idempotency_key),
  UNIQUE KEY uq_refund_transactions_one_live (refund_request_id, live_key) COMMENT 'one live disbursement per refund: no double refund',
  CONSTRAINT fk_refund_transactions_request FOREIGN KEY (refund_request_id) REFERENCES refund_requests(id),
  CONSTRAINT fk_refund_transactions_currency FOREIGN KEY (currency_code) REFERENCES currencies(code),
  CONSTRAINT ck_refund_transactions_dest CHECK (destination IN ('ORIGINAL_METHOD','SABAI_WALLET')),
  CONSTRAINT ck_refund_transactions_amount CHECK (amount > 0),
  CONSTRAINT ck_refund_transactions_status CHECK (status IN ('PENDING','PROCESSING','COMPLETED','FAILED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE wallet_ledger_entries (
  id CHAR(36) NOT NULL,
  seq BIGINT NOT NULL AUTO_INCREMENT,
  created_at DATETIME(6) NOT NULL,
  wallet_id CHAR(36) NOT NULL,
  user_id CHAR(36) NOT NULL,
  transaction_type VARCHAR(20) NOT NULL,
  reference_type VARCHAR(30) NOT NULL,
  reference_id CHAR(36) NOT NULL,
  credit_amount DECIMAL(14,2) NOT NULL DEFAULT 0,
  debit_amount DECIMAL(14,2) NOT NULL DEFAULT 0,
  balance_after DECIMAL(14,2) NOT NULL,
  currency_code CHAR(3) NOT NULL,
  status VARCHAR(12) NOT NULL DEFAULT 'POSTED',
  created_by CHAR(36) NULL,
  idempotency_key VARCHAR(100) NOT NULL,
  prev_entry_id CHAR(36) NULL,
  chain_key CHAR(36) GENERATED ALWAYS AS (COALESCE(prev_entry_id, 'ROOT')) VIRTUAL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_wallet_ledger_seq (seq),
  UNIQUE KEY uq_wallet_ledger_idem (wallet_id, idempotency_key),
  UNIQUE KEY uq_wallet_ledger_chain (wallet_id, chain_key) COMMENT 'each entry has exactly one successor: concurrent writers cannot both extend the same balance',
  KEY idx_wallet_ledger_user (user_id, seq),
  CONSTRAINT fk_wallet_ledger_wallet FOREIGN KEY (wallet_id) REFERENCES wallets(id),
  CONSTRAINT fk_wallet_ledger_user FOREIGN KEY (user_id) REFERENCES users(id),
  CONSTRAINT fk_wallet_ledger_currency FOREIGN KEY (currency_code) REFERENCES currencies(code),
  CONSTRAINT fk_wallet_ledger_prev FOREIGN KEY (prev_entry_id) REFERENCES wallet_ledger_entries(id),
  -- TOPUP / TRANSFER / WITHDRAWAL are deliberately absent (DEC-08-09)
  CONSTRAINT ck_wallet_ledger_type CHECK (transaction_type IN ('REFUND_CREDIT','PAYMENT_DEBIT','ADJUSTMENT_CREDIT','ADJUSTMENT_DEBIT')),
  CONSTRAINT ck_wallet_ledger_amounts CHECK ((credit_amount > 0 AND debit_amount = 0) OR (debit_amount > 0 AND credit_amount = 0)),
  CONSTRAINT ck_wallet_ledger_direction CHECK ((transaction_type IN ('REFUND_CREDIT','ADJUSTMENT_CREDIT') AND credit_amount > 0) OR (transaction_type IN ('PAYMENT_DEBIT','ADJUSTMENT_DEBIT') AND debit_amount > 0)),
  CONSTRAINT ck_wallet_ledger_balance CHECK (balance_after >= 0),
  CONSTRAINT ck_wallet_ledger_status CHECK (status IN ('POSTED','REVERSED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE refund_transactions
  ADD CONSTRAINT fk_refund_transactions_ledger FOREIGN KEY (wallet_ledger_entry_id) REFERENCES wallet_ledger_entries(id);

-- ---------- invariants that need more than a CHECK ----------
DELIMITER $$
-- Ledger continuity: balance_after = previous balance + credit - debit; a wallet's first entry starts from 0.
CREATE TRIGGER trg_wallet_ledger_continuity BEFORE INSERT ON wallet_ledger_entries FOR EACH ROW
BEGIN
  DECLARE prev_balance DECIMAL(14,2);
  DECLARE prev_wallet CHAR(36);
  IF NEW.prev_entry_id IS NULL THEN
    SET prev_balance = 0;
  ELSE
    SELECT balance_after, wallet_id INTO prev_balance, prev_wallet FROM wallet_ledger_entries WHERE id = NEW.prev_entry_id;
    IF prev_wallet IS NULL OR prev_wallet <> NEW.wallet_id THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'wallet ledger: prev_entry_id must belong to the same wallet';
    END IF;
  END IF;
  IF NEW.balance_after <> prev_balance + NEW.credit_amount - NEW.debit_amount THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'wallet ledger: balance_after does not follow from the previous balance';
  END IF;
END$$
-- A wallet refund may only be executed with a recorded, matching consent (DEC-08-10/11).
CREATE TRIGGER trg_refund_transactions_wallet_consent BEFORE INSERT ON refund_transactions FOR EACH ROW
BEGIN
  DECLARE n INT;
  IF NEW.destination = 'SABAI_WALLET' THEN
    SELECT COUNT(*) INTO n FROM wallet_consents wc JOIN refund_requests rr ON rr.id = wc.refund_request_id
      WHERE wc.refund_request_id = NEW.refund_request_id AND rr.method = 'SABAI_WALLET';
    IF n = 0 THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'refund to Sabai Wallet requires recorded customer consent';
    END IF;
  END IF;
END$$
-- Refund execution can never exceed what was approved, nor what the payment still allows.
CREATE TRIGGER trg_refund_transactions_amount BEFORE INSERT ON refund_transactions FOR EACH ROW
BEGIN
  DECLARE approved DECIMAL(14,2);
  DECLARE st VARCHAR(20);
  SELECT approved_amount, status INTO approved, st FROM refund_requests WHERE id = NEW.refund_request_id;
  IF st NOT IN ('APPROVED','PROCESSING') OR approved IS NULL OR NEW.amount <> approved THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'refund_transactions: refund must be APPROVED and the amount must equal the approved amount';
  END IF;
END$$
CREATE TRIGGER trg_refund_requests_guard BEFORE UPDATE ON refund_requests FOR EACH ROW
BEGIN
  IF NEW.requested_amount <> OLD.requested_amount OR NEW.booking_id <> OLD.booking_id OR NEW.payment_id <> OLD.payment_id
     OR NEW.method <> OLD.method OR NEW.currency_code <> OLD.currency_code THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'refund_requests: amount, booking, payment, method and currency are immutable';
  END IF;
  IF OLD.status IN ('REJECTED','COMPLETED') AND NEW.status <> OLD.status THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'refund_requests: terminal status cannot change';
  END IF;
END$$
CREATE TRIGGER trg_settlement_batches_guard BEFORE UPDATE ON partner_settlement_batches FOR EACH ROW
BEGIN
  IF OLD.status IN ('APPROVED','PAYOUT_PROCESSING','PAID') AND
     (NEW.net_amount <> OLD.net_amount OR NEW.gross_sales <> OLD.gross_sales OR NEW.commission_total <> OLD.commission_total
      OR NEW.fees_total <> OLD.fees_total OR NEW.refunds_total <> OLD.refunds_total OR NEW.partner_id <> OLD.partner_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'settlement batch amounts are frozen once approved; use settlement_adjustments';
  END IF;
  IF OLD.status = 'PAID' AND NEW.status <> 'PAID' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'a PAID settlement batch cannot change status';
  END IF;
END$$
DELIMITER ;

-- Append-only / no-delete
CREATE TRIGGER trg_commission_calc_nou BEFORE UPDATE ON commission_calculations FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'commission_calculations is immutable';
CREATE TRIGGER trg_commission_calc_nod BEFORE DELETE ON commission_calculations FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'commission_calculations is immutable';
CREATE TRIGGER trg_settlement_items_nou BEFORE UPDATE ON partner_settlement_items FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'partner_settlement_items is immutable';
CREATE TRIGGER trg_settlement_items_nod BEFORE DELETE ON partner_settlement_items FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'partner_settlement_items is immutable';
CREATE TRIGGER trg_settlement_adjustments_nou BEFORE UPDATE ON settlement_adjustments FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'settlement_adjustments is immutable';
CREATE TRIGGER trg_settlement_adjustments_nod BEFORE DELETE ON settlement_adjustments FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'settlement_adjustments is immutable';
CREATE TRIGGER trg_settlement_batches_nod BEFORE DELETE ON partner_settlement_batches FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'partner_settlement_batches cannot be deleted';
CREATE TRIGGER trg_payouts_nod BEFORE DELETE ON partner_payouts FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'partner_payouts cannot be deleted';
CREATE TRIGGER trg_refund_requests_nod BEFORE DELETE ON refund_requests FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'refund_requests cannot be deleted';
CREATE TRIGGER trg_refund_approvals_nou BEFORE UPDATE ON refund_approvals FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'refund_approvals is immutable';
CREATE TRIGGER trg_refund_approvals_nod BEFORE DELETE ON refund_approvals FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'refund_approvals is immutable';
CREATE TRIGGER trg_refund_transactions_nod BEFORE DELETE ON refund_transactions FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'refund_transactions cannot be deleted';
CREATE TRIGGER trg_wallet_consents_nou BEFORE UPDATE ON wallet_consents FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'wallet_consents is immutable';
CREATE TRIGGER trg_wallet_consents_nod BEFORE DELETE ON wallet_consents FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'wallet_consents is immutable';
CREATE TRIGGER trg_wallet_ledger_nou BEFORE UPDATE ON wallet_ledger_entries FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'wallet_ledger_entries is append-only';
CREATE TRIGGER trg_wallet_ledger_nod BEFORE DELETE ON wallet_ledger_entries FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'wallet_ledger_entries is append-only';
CREATE TRIGGER trg_wallets_nod BEFORE DELETE ON wallets FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'wallets cannot be deleted';
