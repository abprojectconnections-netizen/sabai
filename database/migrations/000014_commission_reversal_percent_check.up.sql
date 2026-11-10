-- 000008 required percent commissions to equal ROUND(base * rate, 2) for every row, which made a negative REFUND_REVERSAL
-- impossible to store (base >= 0 but the amount must be <= 0). A reversal is the negative of the same rounding rule.
ALTER TABLE commission_calculations DROP CONSTRAINT ck_commission_calc_percent;
ALTER TABLE commission_calculations ADD CONSTRAINT ck_commission_calc_percent CHECK (
  commission_type <> 'PERCENT' OR (commission_rate IS NOT NULL AND
    ((kind = 'ORIGINAL' AND commission_amount = ROUND(commission_base_amount * commission_rate, 2))
  OR (kind = 'REFUND_REVERSAL' AND commission_amount = -ROUND(commission_base_amount * commission_rate, 2)))));
