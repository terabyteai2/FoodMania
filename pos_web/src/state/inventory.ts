// Inventory store (Phase B3) — owner-only, online-first. Network-first with an
// IndexedDB fallback for the stock hub so an offline boot can still repaint the
// last snapshot; writes (item CRUD, adjustments, counts) hit the network and reload.

import { create } from 'zustand';
import { api } from '../api/client';
import type {
  DailyStockCountPayload, InventoryDailyReportWire, InventoryItemPayload, InventoryItemWire,
  InventorySummaryWire, InventorySupplierPayload, InventorySupplierWire, StockAdjustmentPayload,
} from '../api/types';
import { summaryWindow } from '../core/inventory';
import type { Period } from '../components/PeriodPicker';
import { cacheGet, cacheSet } from '../offline/db';

interface InventoryState {
  summary: InventorySummaryWire | null;
  items: InventoryItemWire[]; // raw materials (for the edit form) keyed by id below
  itemsById: Record<string, InventoryItemWire>;
  suppliers: InventorySupplierWire[];
  report: InventoryDailyReportWire | null;
  period: Period; // active flow window — preserved across mutation reloads
  loading: boolean;
  reportLoading: boolean;
  error: string | null;

  loadStock: (outletId: string, period: Period) => Promise<void>;
  loadReport: (outletId: string, date?: string) => Promise<void>;
  saveItem: (outletId: string, payload: InventoryItemPayload) => Promise<void>;
  deleteItem: (outletId: string, itemId: string) => Promise<void>;
  adjust: (outletId: string, payload: StockAdjustmentPayload) => Promise<void>;
  count: (outletId: string, payload: DailyStockCountPayload) => Promise<void>;
  saveSupplier: (outletId: string, payload: InventorySupplierPayload) => Promise<void>;
}

function indexById(items: InventoryItemWire[]): Record<string, InventoryItemWire> {
  const map: Record<string, InventoryItemWire> = {};
  for (const it of items) map[it.id] = it;
  return map;
}

export const useInventory = create<InventoryState>((set, get) => ({
  summary: null,
  items: [],
  itemsById: {},
  suppliers: [],
  report: null,
  period: { range: 'today' },
  loading: false,
  reportLoading: false,
  error: null,

  // Pull the stock hub (summary) + raw item list + suppliers together. Summary is
  // cached for a fast offline repaint; the pull (needed for editing) is best-effort.
  loadStock: async (outletId, period) => {
    set({ loading: true, error: null, period });
    const win = summaryWindow(period);
    try {
      const [summary, pull] = await Promise.all([
        api.fetchInventorySummary(outletId, win),
        api.pullInventory(outletId),
      ]);
      const items = pull.items.filter((i) => !i.deletedAt);
      await cacheSet(`inv:summary:${outletId}`, summary);
      await cacheSet(`inv:items:${outletId}`, items);
      set({
        summary,
        items,
        itemsById: indexById(items),
        suppliers: pull.suppliers,
        loading: false,
      });
    } catch (e) {
      const cachedSummary = await cacheGet<InventorySummaryWire>(`inv:summary:${outletId}`);
      const cachedItems = await cacheGet<InventoryItemWire[]>(`inv:items:${outletId}`);
      if (cachedSummary) {
        set({
          summary: cachedSummary,
          items: cachedItems ?? [],
          itemsById: indexById(cachedItems ?? []),
          loading: false,
          error: null,
        });
      } else {
        set({ loading: false, error: e instanceof Error ? e.message : String(e) });
      }
    }
  },

  loadReport: async (outletId, date) => {
    set({ reportLoading: true });
    try {
      const report = await api.fetchInventoryDailyReport(outletId, date);
      set({ report, reportLoading: false });
    } catch (e) {
      set({ reportLoading: false, error: e instanceof Error ? e.message : String(e) });
    }
  },

  saveItem: async (outletId, payload) => {
    await api.pushInventoryItem(outletId, payload);
    await get().loadStock(outletId, get().period);
  },
  deleteItem: async (outletId, itemId) => {
    await api.deleteInventoryItem(outletId, itemId);
    await get().loadStock(outletId, get().period);
  },
  adjust: async (outletId, payload) => {
    await api.postInventoryAdjustment(outletId, payload);
    await get().loadStock(outletId, get().period);
  },
  count: async (outletId, payload) => {
    await api.postDailyStockCount(outletId, payload);
    await get().loadStock(outletId, get().period);
  },
  saveSupplier: async (outletId, payload) => {
    const supplier = await api.saveInventorySupplier(outletId, payload);
    set({ suppliers: [...get().suppliers, supplier].sort((a, b) => a.name.localeCompare(b.name)) });
  },
}));
