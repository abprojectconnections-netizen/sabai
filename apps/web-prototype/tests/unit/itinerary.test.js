import { describe, expect, it } from 'vitest';
import { buildItinerary } from '../../src/domain/itinerary';

describe('AI itinerary builder', () => {
  it('returns the curated 3-day Chiang Mai plan with places for navigation', () => {
    const it3 = buildItinerary({ destinationName: 'เชียงใหม่', days: 3, budget: 10000, styles: [] });
    expect(it3.days).toHaveLength(3);
    expect(it3.days[0].items[0].place).toBe('สนามบินเชียงใหม่');
    expect(it3.budgetBreakdown.reduce((s, b) => s + b.value, 0)).toBe(10000);
  });
  it('generates a generic plan: capped at 7 days, every stop has a navigable place', () => {
    const plan = buildItinerary({ destinationName: 'ภูเก็ต', days: 10, budget: 20000, styles: ['ธรรมชาติ'] });
    expect(plan.days).toHaveLength(7);
    plan.days.forEach((d) => d.items.forEach((i) => { expect(i.place).toContain('ภูเก็ต'); expect(i.time).toMatch(/^\d{2}:\d{2}$/); }));
    expect(plan.days[0].items[2].text).toContain('ธรรมชาติ');
  });
  it('applies a minimum budget and keeps a flight line for pricing', () => {
    const plan = buildItinerary({ destinationName: 'กระบี่', days: 2, budget: 500, styles: [] });
    const total = plan.budgetBreakdown.reduce((s, b) => s + b.value, 0);
    expect(total).toBeGreaterThan(2000);
    expect(plan.budgetBreakdown.some((b) => b.label === 'เที่ยวบิน')).toBe(true);
  });
});
