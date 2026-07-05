// Pure inventory helpers — kept side-effect-free so the signing/date/merge logic
// can be unit-tested. Mirrors backend/routers/inventory.py conventions.

import type {
  AdjustmentType, InventoryItemPayload, InventoryItemWire, InventorySummaryItemWire,
  VarianceStatus,
} from '../api/types';
import type { Period } from '../components/PeriodPicker';

const BDT_OFFSET_MS = 6 * 60 * 60 * 1000; // Bangladesh is UTC+6 (backend BDT_OFFSET)

/** Today's business date (YYYY-MM-DD) on Bangladesh wall-clock — matches the
 *  backend's `count_date` default so end-of-day counts land on the right day. */
export function todayBdtDate(now: Date = new Date()): string {
  return new Date(now.getTime() + BDT_OFFSET_MS).toISOString().slice(0, 10);
}

/** Signed delta for an adjustment given a positive magnitude the user typed.
 *  Restock adds stock; usage/waste remove it; correction is passed through signed. */
export function adjustmentDelta(type: AdjustmentType, magnitude: number): number {
  const m = Math.abs(magnitude);
  switch (type) {
    case 'restock':
      return m;
    case 'usage':
    case 'waste':
      return -m;
    case 'correction':
      return magnitude; // caller decides the sign for a manual correction
  }
}

/** Net movement over the summary window (in − out), rounded like the backend. */
export function netToday(item: Pick<InventorySummaryItemWire, 'todayIn' | 'todayOut'>): number {
  return Math.round((item.todayIn - item.todayOut) * 1000) / 1000;
}

/** CSS class suffix for a stock status dot / row (ok | low | out | variance). */
export function statusTone(status: VarianceStatus): string {
  return status; // used directly as `inv-dot inv-dot-<status>`
}

/** Convert the shared PeriodPicker value into the summary endpoint's flow window.
 *  Today → no bounds (backend defaults to the BDT day). week/month → rolling window
 *  ending now. custom → the picked days, anchored to BDT midnight boundaries. */
export function summaryWindow(period: Period, now: Date = new Date()): { start?: string; end?: string } {
  const iso = (ms: number) => new Date(ms).toISOString();
  switch (period.range) {
    case 'today':
      return {};
    case 'week':
      return { start: iso(now.getTime() - 7 * 86400_000), end: iso(now.getTime()) };
    case 'month':
      return { start: iso(now.getTime() - 30 * 86400_000), end: iso(now.getTime()) };
    case 'custom':
      if (!period.start || !period.end) return {};
      return { start: `${period.start}T00:00:00+06:00`, end: `${period.end}T23:59:59+06:00` };
  }
}

/** Build the full upsert payload from an existing raw item + an edited patch.
 *  The backend upsert is a full replacement, so every field must be present. */
export function mergeInventoryPayload(
  raw: InventoryItemWire,
  patch: Partial<InventoryItemPayload>,
): InventoryItemPayload {
  return {
    id: raw.id,
    name: raw.name,
    category: raw.category,
    unit: raw.unit,
    quantity: raw.quantity,
    minThreshold: raw.minThreshold,
    costPerUnit: raw.costPerUnit,
    notes: raw.notes,
    defaultSupplierId: raw.defaultSupplierId ?? null,
    defaultReorderQty: raw.defaultReorderQty,
    updatedAt: new Date().toISOString(),
    ...patch,
  };
}

export const UNITS: readonly string[] = ['kg', 'gm', 'ltr', 'ml', 'pcs'];

/** Bilingual display name honoring the current language, with an English fallback. */
export function inventoryDisplayName(
  item: { nameEn: string; nameBn: string },
  bn: boolean,
): string {
  return (bn ? item.nameBn : item.nameEn) || item.nameEn || item.nameBn;
}
