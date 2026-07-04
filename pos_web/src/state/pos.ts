// POS settings (floor layout, VAT, service charge, discount presets) + current shift.

import { create } from 'zustand';
import { api } from '../api/client';
import type { PosSettingsWire, PosShiftWire } from '../api/types';

interface PosState {
  settings: PosSettingsWire | null;
  shift: PosShiftWire | null;
  loading: boolean;
  error: string | null;
  load: (outletId: string) => Promise<void>;
  openShift: (outletId: string, openingCash: number, denominations: Record<string, number>) => Promise<void>;
  closeShift: (outletId: string, countedCash: number, denominations: Record<string, number>) => Promise<PosShiftWire>;
}

export const usePos = create<PosState>((set, get) => ({
  settings: null,
  shift: null,
  loading: false,
  error: null,

  load: async (outletId) => {
    set({ loading: true, error: null });
    try {
      const [settings, shift] = await Promise.all([
        api.fetchPosSettings(outletId),
        api.fetchCurrentShift(outletId),
      ]);
      set({ settings, shift, loading: false });
    } catch (e) {
      set({ loading: false, error: e instanceof Error ? e.message : String(e) });
    }
  },

  openShift: async (outletId, openingCash, denominations) => {
    const shift = await api.openShift(outletId, {
      id: crypto.randomUUID(),
      openingCash,
      denominations,
    });
    set({ shift });
  },

  closeShift: async (outletId, countedCash, denominations) => {
    const current = get().shift;
    if (!current) throw new Error('No open shift');
    const closed = await api.closeShift(outletId, current.id, { countedCash, denominations });
    set({ shift: null });
    return closed;
  },
}));
