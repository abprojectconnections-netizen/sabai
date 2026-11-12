import { describe, expect, it } from 'vitest';
import { BOOKING_STATUS, CANCEL_REASONS, refundFor } from '../../src/domain/bookings';

describe('booking rules', () => {
  it('shows only an indicative refund equal to the amount paid and invents no percentage', () => {
    expect(refundFor({ type: 'flight', amount: 1040 })).toBe(1040);
    expect(refundFor({ type: 'hotel', amount: 1564 })).toBe(1564);
  });
  it('exposes labelled statuses and cancel reasons', () => {
    expect(Object.keys(BOOKING_STATUS).sort()).toEqual(['cancelled', 'completed', 'confirmed', 'pending', 'refunded']);
    expect(CANCEL_REASONS.length).toBeGreaterThan(2);
  });
});
