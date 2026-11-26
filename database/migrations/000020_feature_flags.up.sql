-- Feature flags: runtime kill switches that staff with config.manage can flip without a deploy.
-- The table existed as an empty shell (id and timestamps only); nothing wrote to it, so adding columns is safe.
ALTER TABLE feature_flags
  ADD COLUMN flag_key VARCHAR(80) NOT NULL DEFAULT '' AFTER deleted_at,
  ADD COLUMN description VARCHAR(255) NOT NULL DEFAULT '' AFTER flag_key,
  ADD COLUMN enabled TINYINT(1) NOT NULL DEFAULT 1 AFTER description,
  ADD COLUMN updated_by CHAR(36) NULL AFTER enabled,
  ADD UNIQUE KEY uq_feature_flags_flag_key (flag_key);

INSERT INTO feature_flags (id, created_at, updated_at, flag_key, description, enabled) VALUES
  (UUID(), UTC_TIMESTAMP(6), UTC_TIMESTAMP(6), 'community.posting', 'อนุญาตให้ผู้ใช้โพสต์ใหม่ในชุมชน (ปิดเพื่อหยุดโพสต์ชั่วคราว การอ่านและรายงานยังใช้ได้)', 1),
  (UUID(), UTC_TIMESTAMP(6), UTC_TIMESTAMP(6), 'coupons.claiming', 'อนุญาตให้ผู้ใช้เก็บคูปองด้วยโค้ด (ปิดเมื่อพบการเดาโค้ดหรือแคมเปญผิดพลาด)', 1);
