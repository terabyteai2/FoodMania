import { create } from 'zustand';
import { api } from '../api/client';
import type { MenuItemPayload, MenuItemWire } from '../api/types';
import { parseExtras, effectiveUnitPrice, type MenuExtras } from '../core/tags';
import { cacheGet, cacheSet } from '../offline/db';

const FAV_KEY = 'qbpos.favorites';

export interface PosMenuItem {
  raw: MenuItemWire;
  extras: MenuExtras;
  price: number; // after item discount tags
  category: string;
}

interface MenuState {
  items: PosMenuItem[];
  categories: string[];
  favorites: Set<string>;
  loading: boolean;
  error: string | null;
  load: (outletId: string) => Promise<void>;
  toggleFavorite: (itemId: string) => void;
  // Phase B menu management — POST upsert / DELETE, then reload (online-only for v1).
  saveItem: (outletId: string, payload: MenuItemPayload) => Promise<void>;
  saveMany: (outletId: string, payloads: MenuItemPayload[]) => Promise<void>;
  deleteItem: (outletId: string, itemId: string) => Promise<void>;
}

function loadFavorites(): Set<string> {
  try {
    return new Set(JSON.parse(localStorage.getItem(FAV_KEY) ?? '[]') as string[]);
  } catch {
    return new Set();
  }
}

export const useMenu = create<MenuState>((set, get) => ({
  items: [],
  categories: [],
  favorites: loadFavorites(),
  loading: false,
  error: null,

  // Network-first with an IndexedDB fallback so the menu is available on an offline boot.
  load: async (outletId) => {
    set({ loading: true, error: null });
    let wire: MenuItemWire[] | null = null;
    try {
      wire = await api.fetchMenu(outletId);
      await cacheSet(`menu:${outletId}`, wire);
    } catch (e) {
      wire = await cacheGet<MenuItemWire[]>(`menu:${outletId}`);
      if (!wire) {
        set({ loading: false, error: e instanceof Error ? e.message : String(e) });
        return;
      }
    }
    const items = wire
      .filter((w) => !w.deletedAt)
      .map((raw): PosMenuItem => {
        const extras = parseExtras(raw.tags);
        return {
          raw,
          extras,
          price: effectiveUnitPrice(raw.price, extras),
          category: (raw.categoryEn || raw.category || 'Uncategorized').trim() || 'Uncategorized',
        };
      });
    const categories = [...new Set(items.map((i) => i.category))].sort((a, b) => a.localeCompare(b));
    set({ items, categories, loading: false });
  },

  toggleFavorite: (itemId) => {
    const next = new Set(get().favorites);
    if (next.has(itemId)) next.delete(itemId);
    else next.add(itemId);
    localStorage.setItem(FAV_KEY, JSON.stringify([...next]));
    set({ favorites: next });
  },

  saveItem: async (outletId, payload) => {
    await api.pushMenuItem(outletId, payload);
    await get().load(outletId);
  },

  saveMany: async (outletId, payloads) => {
    for (const p of payloads) await api.pushMenuItem(outletId, p);
    await get().load(outletId);
  },

  deleteItem: async (outletId, itemId) => {
    await api.deleteMenuItem(outletId, itemId);
    await get().load(outletId);
  },
}));

export function itemDisplayName(item: PosMenuItem, bn: boolean): string {
  const { raw } = item;
  return (bn ? raw.nameBn : raw.nameEn) || raw.name;
}

/**
 * Resolve a typed short-code entry (digits only) to an available menu item.
 * Returns null for blank/non-numeric input or when nothing matches.
 */
export function matchShortCode(items: PosMenuItem[], input: string): PosMenuItem | null {
  const trimmed = input.trim();
  if (!/^\d+$/.test(trimmed)) return null;
  const code = Number(trimmed);
  return items.find((i) => i.raw.shortCode === code && i.raw.isAvailable) ?? null;
}
