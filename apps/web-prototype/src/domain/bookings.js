export const BOOKING_STATUS = {
  confirmed: { label: 'ยืนยันแล้ว', bg: 'var(--pine-pale)', color: 'var(--pine)' },
  completed: { label: 'เสร็จสิ้น', bg: 'var(--muted-bg)', color: 'var(--ink-soft)' },
  cancelled: { label: 'ยกเลิกแล้ว', bg: 'var(--danger-soft)', color: 'var(--danger)' },
};

export const CANCEL_REASONS = ['เปลี่ยนแผนการเดินทาง', 'จองผิดวันหรือผิดรายการ', 'พบราคาที่ถูกกว่า', 'เหตุฉุกเฉิน', 'อื่นๆ'];

export function refundFor(booking) {
  const rate = booking.type === 'flight' ? 0.8 : 1;
  return Math.round(booking.amount * rate);
}
