DROP TRIGGER trg_wallets_nod;
ALTER TABLE refund_transactions DROP FOREIGN KEY fk_refund_transactions_ledger;
DROP TABLE wallet_ledger_entries;
DROP TABLE refund_transactions;
ALTER TABLE wallets
  DROP FOREIGN KEY fk_wallets_user, DROP FOREIGN KEY fk_wallets_currency, DROP INDEX uq_wallets_user_currency,
  DROP CHECK ck_wallets_balances, DROP CHECK ck_wallets_type, DROP CHECK ck_wallets_status,
  DROP COLUMN balance_type, DROP COLUMN status;
DROP TABLE wallet_consents;
DROP TABLE refund_approvals;
ALTER TABLE commission_calculations DROP FOREIGN KEY fk_commission_calc_refund;
DROP TABLE refund_requests;
DROP TABLE partner_payouts;
DROP TABLE settlement_adjustments;
DROP TABLE partner_settlement_items;
DROP TABLE partner_settlement_batches;
DROP TABLE commission_calculations;

-- restore the 000001 skeletons
CREATE TABLE commissions (id CHAR(36) NOT NULL, created_at DATETIME(6) NOT NULL, updated_at DATETIME(6) NOT NULL, deleted_at DATETIME(6) NULL, PRIMARY KEY (id), INDEX idx_commissions_deleted_at (deleted_at)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE commission_transactions (id CHAR(36) NOT NULL, created_at DATETIME(6) NOT NULL, updated_at DATETIME(6) NOT NULL, deleted_at DATETIME(6) NULL, PRIMARY KEY (id), INDEX idx_commission_transactions_deleted_at (deleted_at)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE wallet_transactions (id CHAR(36) NOT NULL, created_at DATETIME(6) NOT NULL, updated_at DATETIME(6) NOT NULL, deleted_at DATETIME(6) NULL, PRIMARY KEY (id), INDEX idx_wallet_transactions_deleted_at (deleted_at)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE refunds (id CHAR(36) NOT NULL, created_at DATETIME(6) NOT NULL, updated_at DATETIME(6) NOT NULL, deleted_at DATETIME(6) NULL, status VARCHAR(30) NOT NULL, reviewed_by CHAR(36) NULL, reviewed_at DATETIME(6) NULL, PRIMARY KEY (id), INDEX idx_refunds_deleted_at (deleted_at)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE cancellations (id CHAR(36) NOT NULL, created_at DATETIME(6) NOT NULL, updated_at DATETIME(6) NOT NULL, deleted_at DATETIME(6) NULL, PRIMARY KEY (id), INDEX idx_cancellations_deleted_at (deleted_at)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE coupon_redemptions (id CHAR(36) NOT NULL, created_at DATETIME(6) NOT NULL, updated_at DATETIME(6) NOT NULL, deleted_at DATETIME(6) NULL, PRIMARY KEY (id), INDEX idx_coupon_redemptions_deleted_at (deleted_at)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
