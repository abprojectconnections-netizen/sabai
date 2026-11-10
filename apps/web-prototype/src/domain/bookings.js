export const BOOKING_STATUS = {
  confirmed: { label: 'ยืนยันแล้ว', bg: 'var(--pine-pale)', color: 'var(--pine)' },
  completed: { label: 'เสร็จสิ้น', bg: 'var(--muted-bg)', color: 'var(--ink-soft)' },
  cancelled: { label: 'ยกเลิกแล้ว', bg: 'var(--danger-soft)', color: 'var(--danger)' },
};

export const CANCEL_REASONS = ['เปลี่ยนแผนการเดินทาง', 'จองผิดวันหรือผิดรายการ', 'พบราคาที่ถูกกว่า', 'เหตุฉุกเฉิน', 'อื่นๆ'];

/**
 * INDICATIVE refund shown before cancelling. It is NOT a rule: the real amount is computed by the server from the booking's own price
 * snapshot and cancellation terms, may need approval, and is paid back to the original payment method unless the customer
 * explicitly consents to Sabai Wallet credit. The prototype therefore never invents percentages or moves money on its own.
 */
export function refundFor(booking) {
  return Math.round(booking.amount);
}
