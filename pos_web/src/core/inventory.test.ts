import { describe, expect, it } from 'vitest';
import {
  adjustmentDelta, mergeInventoryPayload, netToday, summaryWindow, todayBdtDate,
} from './inventory';
import type { InventoryItemWire } from '../api/types';

describe('adjustmentDelta', () => {
  it('adds on restock, subtracts on usage/waste, passes correction through signed', () => {
    expect(adjustmentDelta('restock', 5)).toBe(5);
    expect(adjustmentDelta('usage', 5)).toBe(-5);
    expect(adjustmentDelta('waste', 3)).toBe(-3);
    expect(adjustmentDelta('correction', -2)).toBe(-2);
    expect(adjustmentDelta('correction', 4)).toBe(4);
  });
  it('treats a negative magnitude as a positive quantity for restock/usage', () => {
    expect(adjustmentDelta('restock', -5)).toBe(5);
    expect(adjustmentDelta('usage', -5)).toBe(-5);
  });
});

describe('todayBdtDate', () => {
  it('rolls to the next calendar day once BDT (UTC+6) crosses midnight', () => {
    // 2026-07-05 19:30 UTC = 2026-07-06 01:30 in Bangladesh.
    expect(todayBdtDate(new Date('2026-07-05T19:30:00Z'))).toBe('2026-07-06');
    // 2026-07-05 10:00 UTC = 2026-07-05 16:00 in Bangladesh (same day).
    expect(todayBdtDate(new Date('2026-07-05T10:00:00Z'))).toBe('2026-07-05');
  });
});

describe('netToday', () => {
  it('is in minus out, rounded', () => {
    expect(netToday({ todayIn: 10, todayOut: 3.5 })).toBe(6.5);
    expect(netToday({ todayIn: 0, todayOut: 2 })).toBe(-2);
  });
});

describe('summaryWindow', () => {
  const now = new Date('2026-07-05T12:00:00Z');
  it('sends no bounds for today (backend defaults to the BDT day)', () => {
    expect(summaryWindow({ range: 'today' }, now)).toEqual({});
  });
  it('rolls a 7-day window for week', () => {
    const w = summaryWindow({ range: 'week' }, now);
    expect(w.end).toBe('2026-07-05T12:00:00.000Z');
    expect(w.start).toBe('2026-06-28T12:00:00.000Z');
  });
  it('anchors custom to BDT midnight boundaries', () => {
    expect(summaryWindow({ range: 'custom', start: '2026-07-01', end: '2026-07-03' }, now)).toEqual({
      start: '2026-07-01T00:00:00+06:00',
      end: '2026-07-03T23:59:59+06:00',
    });
  });
  it('falls back to no bounds when a custom endpoint is missing', () => {
    expect(summaryWindow({ range: 'custom', start: '2026-07-01' }, now)).toEqual({});
  });
});

describe('mergeInventoryPayload', () => {
  const raw: InventoryItemWire = {
    id: 'i1', outletId: 'o1', name: 'Chicken', category: 'raw', unit: 'kg',
    quantity: 12, minThreshold: 5, costPerUnit: 320, notes: 'thigh',
    defaultSupplierId: 's1', defaultReorderQty: 20,
    createdAt: '2026-07-01T00:00:00Z', updatedAt: '2026-07-01T00:00:00Z',
  };
  it('sends a full payload preserving untouched fields', () => {
    const p = mergeInventoryPayload(raw, { costPerUnit: 340 });
    expect(p.costPerUnit).toBe(340);
    expect(p.quantity).toBe(12); // preserved — quantity changes go via adjustments
    expect(p.minThreshold).toBe(5);
    expect(p.defaultSupplierId).toBe('s1');
    expect(p.defaultReorderQty).toBe(20);
    expect(p.name).toBe('Chicken');
  });
  it('nulls a cleared default supplier', () => {
    const p = mergeInventoryPayload({ ...raw, defaultSupplierId: null }, {});
    expect(p.defaultSupplierId).toBeNull();
  });
});
