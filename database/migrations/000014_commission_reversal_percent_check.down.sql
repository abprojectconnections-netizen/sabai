-- Restores the 000008 rule. MySQL DDL is not transactional, so the stricter rule is first added under a temporary name: if percent
-- REFUND_REVERSAL rows exist (financial history that must not be dropped silently) this fails BEFORE anything is changed.
ALTER TABLE commission_calculations ADD CONSTRAINT ck_tmp_percent_v1 CHECK (commission_type <> 'PERCENT' OR (commission_rate IS NOT NULL AND commission_amount = ROUND(commission_base_amount * commission_rate, 2)));
ALTER TABLE commission_calculations DROP CONSTRAINT ck_commission_calc_percent;
ALTER TABLE commission_calculations ADD CONSTRAINT ck_commission_calc_percent CHECK (commission_type <> 'PERCENT' OR (commission_rate IS NOT NULL AND commission_amount = ROUND(commission_base_amount * commission_rate, 2)));
ALTER TABLE commission_calculations DROP CONSTRAINT ck_tmp_percent_v1;
