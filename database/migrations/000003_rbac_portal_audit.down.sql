DROP TABLE IF EXISTS disputes;
ALTER TABLE refunds DROP COLUMN reviewed_at,DROP COLUMN reviewed_by,DROP COLUMN status;
ALTER TABLE support_tickets DROP COLUMN subject,DROP COLUMN assigned_staff_id,DROP COLUMN priority,DROP COLUMN status;
ALTER TABLE audit_logs DROP INDEX idx_audit_logs_subject,DROP COLUMN request_id;
ALTER TABLE user_roles DROP INDEX uq_user_roles_active;
