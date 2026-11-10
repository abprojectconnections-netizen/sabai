-- A trigger variable declared without a collation takes the DATABASE default collation, which differs between environments
-- (CI/prod create the database with the server default utf8mb4_0900_ai_ci; our tables are utf8mb4_unicode_ci), and comparing the two fails with
-- "Illegal mix of collations". Found by CI. Declare the collation explicitly.
DROP TRIGGER trg_wallet_ledger_continuity;
DELIMITER $$
CREATE TRIGGER trg_wallet_ledger_continuity BEFORE INSERT ON wallet_ledger_entries FOR EACH ROW
BEGIN
  DECLARE prev_balance DECIMAL(14,2);
  DECLARE prev_wallet CHAR(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
  IF NEW.prev_entry_id IS NULL THEN
    SET prev_balance = 0;
  ELSE
    SELECT balance_after, wallet_id INTO prev_balance, prev_wallet FROM wallet_ledger_entries WHERE id = NEW.prev_entry_id;
    IF prev_wallet IS NULL OR prev_wallet COLLATE utf8mb4_unicode_ci <> NEW.wallet_id THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'wallet ledger: prev_entry_id must belong to the same wallet';
    END IF;
  END IF;
  IF NEW.balance_after <> prev_balance + NEW.credit_amount - NEW.debit_amount THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'wallet ledger: balance_after does not follow from the previous balance';
  END IF;
END$$
DELIMITER ;
