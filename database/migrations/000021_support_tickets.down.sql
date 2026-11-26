DROP TABLE support_ticket_messages;
ALTER TABLE support_tickets
  DROP FOREIGN KEY fk_support_tickets_booking,
  DROP FOREIGN KEY fk_support_tickets_user,
  DROP INDEX idx_support_tickets_queue,
  DROP INDEX idx_support_tickets_user,
  DROP COLUMN description,
  DROP COLUMN category,
  DROP COLUMN booking_id,
  DROP COLUMN user_id;
