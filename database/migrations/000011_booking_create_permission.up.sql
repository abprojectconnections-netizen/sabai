-- Customers (and partners/staff) may create bookings and pay; a permission so it can be switched off per role without code changes.
INSERT INTO permissions (id, created_at, updated_at, code, name) VALUES (UUID(), UTC_TIMESTAMP(6), UTC_TIMESTAMP(6), 'booking.create', 'Create bookings and pay for them');
INSERT INTO role_permissions (id, created_at, updated_at, role_id, permission_id)
SELECT UUID(), UTC_TIMESTAMP(6), UTC_TIMESTAMP(6), r.id, p.id FROM roles r JOIN permissions p ON p.code = 'booking.create' WHERE r.code IN ('CUSTOMER','PARTNER','STAFF','BOOKING_OFFICER');
