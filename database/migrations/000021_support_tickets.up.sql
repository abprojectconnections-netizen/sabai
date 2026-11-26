-- Customer support tickets. support_tickets existed as a shell with status, priority, assigned_staff_id and subject
-- (migration 000003) but nothing could create one. user_id is nullable only so the migration cannot fail on a database that
-- already holds a row; the API always sets it.
ALTER TABLE support_tickets
  ADD COLUMN user_id CHAR(36) NULL,
  ADD COLUMN booking_id CHAR(36) NULL,
  ADD COLUMN category VARCHAR(30) NOT NULL DEFAULT 'OTHER',
  ADD COLUMN description TEXT NULL,
  ADD INDEX idx_support_tickets_user (user_id, created_at),
  ADD INDEX idx_support_tickets_queue (status, created_at),
  ADD CONSTRAINT fk_support_tickets_user FOREIGN KEY (user_id) REFERENCES users(id),
  ADD CONSTRAINT fk_support_tickets_booking FOREIGN KEY (booking_id) REFERENCES bookings(id);

CREATE TABLE support_ticket_messages (
  id CHAR(36) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  updated_at DATETIME(6) NOT NULL,
  deleted_at DATETIME(6) NULL,
  ticket_id CHAR(36) NOT NULL,
  author_user_id CHAR(36) NOT NULL,
  author_kind VARCHAR(10) NOT NULL,
  body TEXT NOT NULL,
  PRIMARY KEY (id),
  INDEX idx_support_ticket_messages_ticket (ticket_id, created_at),
  CONSTRAINT fk_support_ticket_messages_ticket FOREIGN KEY (ticket_id) REFERENCES support_tickets(id),
  CONSTRAINT fk_support_ticket_messages_author FOREIGN KEY (author_user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
