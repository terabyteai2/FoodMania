import { describe, expect, it } from 'vitest';
import { deltaPct, itemInsightById } from './insights';
import type { InsightsProductWire } from '../api/types';

const product = (over: Partial<InsightsProductWire>): InsightsProductWire => ({
  menuItemId: 'item-1',
  name: 'Kacchi',
  category: 'Mains',
  qty: 10,
  salesBdt: 3500,
  marginPct: 62.5,
  growthPct: 12.3,
  ...over,
});

describe('itemInsightById', () => {
  it('maps products by menuItemId with margin + growth', () => {
    const map = itemInsightById([product({}), product({ menuItemId: 'item-2', marginPct: null })]);
    expect(map.get('item-1')).toEqual({ marginPct: 62.5, growthPct: 12.3 });
    expect(map.get('item-2')).toEqual({ marginPct: null, growthPct: 12.3 });
  });

  it('returns an empty map for missing products (left join → nulls)', () => {
    const map = itemInsightById(undefined);
    expect(map.size).toBe(0);
    expect(map.get('anything')).toBeUndefined();
  });
});

describe('deltaPct', () => {
  it('computes signed percent change rounded to one decimal', () => {
    expect(deltaPct(1125, 1000)).toBe(12.5);
    expect(deltaPct(900, 1000)).toBe(-10);
  });

  it('returns null when previous period has no revenue (hide the badge)', () => {
    expect(deltaPct(500, 0)).toBeNull();
    expect(deltaPct(0, 0)).toBeNull();
  });
});
