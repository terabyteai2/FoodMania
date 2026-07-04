import { create } from 'zustand';
import { api } from '../api/client';
import type { MenuItemWire } from '../api/types';
import { parseExtras, effectiveUnitPrice, type MenuExtras } from '../core/tags';

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

  load: async (outletId) => {
    set({ loading: true, error: null });
    try {
      const wire = await api.fetchMenu(outletId);
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
    } catch (e) {
      set({ loading: false, error: e instanceof Error ? e.message : String(e) });
    }
  },

  toggleFavorite: (itemId) => {
    const next = new Set(get().favorites);
    if (next.has(itemId)) next.delete(itemId);
    else next.add(itemId);
    localStorage.setItem(FAV_KEY, JSON.stringify([...next]));
    set({ favorites: next });
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
