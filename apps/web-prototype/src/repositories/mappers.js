import { fmtDate } from '../domain/dates';

/**
 * Pure mappers from API payloads to the shapes the screens already use.
 * Amounts arrive as decimal strings and are converted to numbers for DISPLAY only: the client never computes, rounds or
 * decides a price, refund or balance (the server owns every figure).
 */
const day = (iso) => (typeof iso === 'string' && /^\d{4}-\d{2}-\d{2}/.test(iso) ? fmtDate(iso.slice(0, 10)) : '');
const num = (s) => { const n = Number(s); return Number.isFinite(n) ? n : 0; };

const BOOKING_STATUS = { PENDING_PAYMENT: 'pending', PAID: 'confirmed', CONFIRMED: 'confirmed', COMPLETED: 'completed', CANCELLED: 'cancelled', REFUNDED: 'refunded', EXPIRED: 'cancelled' };

export function toBooking(b) {
  return {
    id: b.id, number: b.booking_code, type: 'tour', title: b.title || b.booking_code,
    subtitle: b.status === 'PENDING_PAYMENT' ? 'รอชำระเงิน' : '', amount: num(b.payable_total), method: '',
    date: day(b.created_at), status: BOOKING_STATUS[b.status] || String(b.status || '').toLowerCase(),
    serverStatus: b.status, paymentStatus: b.payment_status || null,
  };
}

const LEDGER_LABEL = { REFUND_CREDIT: 'เงินคืนเข้ากระเป๋า (เครดิตคืนเงิน)' };
export function toWalletTransaction(t) {
  const credit = num(t.credit_amount);
  return { id: t.id, type: credit > 0 ? 'in' : 'out', label: LEDGER_LABEL[t.type] || t.type, date: day(t.created_at), amount: credit > 0 ? credit : num(t.debit_amount) };
}

export function toNotification(n) {
  return { id: n.id, type: n.type || 'system', title: n.title, message: n.body, time: day(n.created_at), read: !!n.read };
}

const REVIEW_TYPE = { DESTINATION: 'destination', HOTEL: 'hotel', RESTAURANT: 'restaurant', TOUR: 'tour', BOOKING: 'booking' };
export function toReview(r) {
  return { id: r.id, itemName: r.subject_id, itemType: REVIEW_TYPE[r.subject_type] || 'destination', rating: r.rating, comment: r.body || '', date: day(r.created_at) };
}

const CATEGORY_TYPE = { HOTEL: 'hotel', FLIGHT: 'flight', ATTRACTION: 'attraction', TOUR: 'attraction', TRANSPORT: 'attraction' };
/** Catalogue row -> the listing shape the search screens use. `id` stays the inventory item UUID so a booking can reference it. */
export function toListing(i) {
  return {
    id: i.id, inventoryItemId: i.id, type: CATEGORY_TYPE[i.category] || 'attraction', name: i.title, location: i.partner_name || '',
    rating: 0, reviews: 0, price: num(i.from_price), serviceDate: i.next_available_date || '',
  };
}
