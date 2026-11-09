DROP TRIGGER trg_bookings_guard;
DROP TRIGGER trg_payment_intents_guard;
DROP TRIGGER trg_payments_guard;
DROP TABLE financial_audit_logs;
DROP TABLE payment_webhook_events;
DROP TABLE payment_transactions;
ALTER TABLE payments
  DROP FOREIGN KEY fk_payments_intent, DROP FOREIGN KEY fk_payments_currency,
  DROP INDEX uq_payments_intent_leg, DROP INDEX uq_payments_provider_ref,
  DROP CHECK ck_payments_amount, DROP CHECK ck_payments_captured, DROP CHECK ck_payments_refunded, DROP CHECK ck_payments_status,
  DROP COLUMN payment_intent_id, DROP COLUMN leg_no, DROP COLUMN captured_amount, DROP COLUMN refunded_amount, DROP COLUMN succeeded_at;
DROP TRIGGER trg_payments_nod;
DROP TABLE payment_intents;
ALTER TABLE payment_methods
  DROP FOREIGN KEY fk_payment_methods_user, DROP CHECK ck_payment_methods_last4,
  DROP COLUMN user_id, DROP COLUMN method_type, DROP COLUMN provider_token, DROP COLUMN brand, DROP COLUMN last4, DROP COLUMN status;
DROP TABLE discount_allocations;
ALTER TABLE coupons
  DROP FOREIGN KEY fk_coupons_discount, DROP INDEX uq_coupons_code, DROP CHECK ck_coupons_redeemed,
  DROP COLUMN discount_id, DROP COLUMN redeemed_count;
DROP TABLE discounts;
DROP TABLE booking_status_histories;
ALTER TABLE booking_items
  DROP FOREIGN KEY fk_booking_items_partner, DROP CHECK ck_booking_items_qty, DROP CHECK ck_booking_items_amount,
  DROP COLUMN partner_id, DROP COLUMN service_date, DROP COLUMN external_booking_ref, DROP COLUMN title_snapshot;
DROP TRIGGER trg_bookings_nod;
ALTER TABLE bookings
  DROP FOREIGN KEY fk_bookings_partner, DROP FOREIGN KEY fk_bookings_seller, DROP FOREIGN KEY fk_bookings_snapshot,
  DROP FOREIGN KEY fk_bookings_quote, DROP FOREIGN KEY fk_bookings_currency,
  DROP INDEX uq_bookings_user_idem, DROP INDEX uq_bookings_code, DROP INDEX uq_bookings_snapshot,
  DROP CHECK ck_bookings_total, DROP CHECK ck_bookings_status,
  DROP COLUMN partner_id, DROP COLUMN seller_entity_id, DROP COLUMN price_snapshot_id, DROP COLUMN pricing_quote_id,
  DROP COLUMN idempotency_key, DROP COLUMN supplier_booking_ref, DROP COLUMN confirmation_deadline, DROP COLUMN expires_at;
DROP TABLE booking_price_snapshot_lines;
DROP TABLE booking_price_snapshots;
DROP TABLE pricing_quotes;
DROP TABLE pricing_rules;
ALTER TABLE partner_users
  DROP FOREIGN KEY fk_partner_users_partner, DROP FOREIGN KEY fk_partner_users_user,
  DROP INDEX uq_partner_users_active, DROP CHECK ck_partner_users_role,
  DROP COLUMN active_key, DROP COLUMN partner_role, DROP COLUMN user_id, DROP COLUMN partner_id;
ALTER TABLE partners
  DROP FOREIGN KEY fk_partners_legal_entity, DROP CHECK ck_partners_risk,
  DROP COLUMN legal_entity_id, DROP COLUMN category_set, DROP COLUMN risk_level, DROP COLUMN approved_at, DROP COLUMN approved_by;
