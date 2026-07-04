import { describe, expect, it } from 'vitest';
import { computeTotals, formatTk, lineTotal } from './money';

describe('computeTotals', () => {
  it('matches the backend settle formula: subtotal + vat + delivery + service - discount', () => {
    const t = computeTotals({
      lines: [
        { qty: 2, unitPrice: 250 },
        { qty: 1, unitPrice: 428.57 },
      ],
      vatRatePercent: 5,
      serviceChargeRatePercent: 10,
      discount: { kind: 'flat', value: 50 },
      deliveryCharge: 30,
    });
    expect(t.subtotal).toBe(928.57);
    expect(t.vatAmount).toBe(46.43);
    expect(t.serviceChargeAmount).toBe(92.86);
    expect(t.discountAmount).toBe(50);
    expect(t.deliveryCharge).toBe(30);
    expect(t.total).toBe(928.57 + 46.43 + 92.86 + 30 - 50);
  });

  it('computes percent discounts on the item subtotal', () => {
    const t = computeTotals({
      lines: [{ qty: 4, unitPrice: 100 }],
      vatRatePercent: 0,
      serviceChargeRatePercent: 0,
      discount: { kind: 'percent', value: 25 },
    });
    expect(t.discountAmount).toBe(100);
    expect(t.total).toBe(300);
  });

  it('never lets a discount push the bill negative', () => {
    const t = computeTotals({
      lines: [{ qty: 1, unitPrice: 80 }],
      vatRatePercent: 0,
      serviceChargeRatePercent: 0,
      discount: { kind: 'flat', value: 500 },
    });
    expect(t.total).toBe(0);
  });

  it('handles an empty cart', () => {
    const t = computeTotals({ lines: [], vatRatePercent: 15, serviceChargeRatePercent: 10 });
    expect(t.subtotal).toBe(0);
    expect(t.total).toBe(0);
  });

  it('rounds line totals to 2 decimals', () => {
    expect(lineTotal({ qty: 3, unitPrice: 33.333 })).toBe(100);
  });
});

describe('formatTk', () => {
  it('formats whole taka without paisa', () => {
    expect(formatTk(750)).toBe('৳750');
    expect(formatTk(104253)).toBe('৳1,04,253');
  });
  it('keeps paisa when fractional', () => {
    expect(formatTk(428.57)).toBe('৳428.57');
  });
  it('handles negatives', () => {
    expect(formatTk(-20)).toBe('-৳20');
  });
});
