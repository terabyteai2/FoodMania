// Pure helpers that merge the owner-analytics insights payload (/analytics) into
// the sales-breakdown summary payload (/analytics/summary). Kept in core/ so the
// join logic is unit-tested outside the screen components.

import type { InsightsProductWire } from '../api/types';

export interface ItemInsight {
  marginPct: number | null;
  growthPct: number;
}

/**
 * Left-join insights.products onto item-wise rows by menuItemId.
 * Rows without a matching product (name-fallback keys, deleted items) get null.
 */
export function itemInsightById(
  products: InsightsProductWire[] | undefined | null,
): Map<string, ItemInsight> {
  const map = new Map<string, ItemInsight>();
  for (const p of products ?? []) {
    map.set(p.menuItemId, { marginPct: p.marginPct, growthPct: p.growthPct });
  }
  return map;
}

/**
 * Percent delta of current vs previous, mirroring the backend _delta_pct rule:
 * prev <= 0 → null (caller hides the badge instead of showing a bogus 0/100%).
 */
export function deltaPct(current: number, previous: number): number | null {
  if (previous <= 0) return null;
  return Math.round(((current - previous) / previous) * 1000) / 10;
}
