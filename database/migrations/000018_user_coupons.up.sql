-- Coupons that a user saved. The coupon and its discount rules already exist (coupons/discounts, migration 000007, applied by
-- the booking service when a booking request carries coupon_code). Saving a coupon changes nothing about any price: it is a
-- wallet-style list. No client applies saved coupons at checkout yet (funding rules are open decisions in design note 0004).
CREATE TABLE user_coupons (
  id CHAR(36) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  user_id CHAR(36) NOT NULL,
  coupon_id CHAR(36) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_user_coupons (user_id, coupon_id),
  CONSTRAINT fk_user_coupons_user FOREIGN KEY (user_id) REFERENCES users (id),
  CONSTRAINT fk_user_coupons_coupon FOREIGN KEY (coupon_id) REFERENCES coupons (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
