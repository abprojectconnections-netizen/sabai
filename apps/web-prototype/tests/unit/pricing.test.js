import { describe, expect, it } from 'vitest';
import { payableTotal } from '../../src/domain/pricing';

describe('pricing', () => {
  it('adds no fee of its own: the listed price is the payable total (the server is authoritative)', () => {
    expect(payableTotal(1000)).toBe(1000);
    expect(payableTotal(1564)).toBe(1564);
  });
});
