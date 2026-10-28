import { describe, expect, it } from 'vitest';
import { BOOKING_STATUS, CANCEL_REASONS, refundFor } from '../../src/domain/bookings';

describe('booking rules', () => {
  it('refunds 80% of flights and 100% of other bookings, rounded', () => {
    expect(refundFor({ type: 'flight', amount: 1040 })).toBe(832);
    expect(refundFor({ type: 'hotel', amount: 1564 })).toBe(1564);
    expect(refundFor({ type: 'flight', amount: 999 })).toBe(799);
  });
  it('exposes labelled statuses and cancel reasons', () => {
    expect(Object.keys(BOOKING_STATUS)).toEqual(['confirmed', 'completed', 'cancelled']);
    expect(CANCEL_REASONS.length).toBeGreaterThan(2);
  });
});
