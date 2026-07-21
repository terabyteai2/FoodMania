// Orders store: recent orders (open + settled for the day), realtime refetch, and
// online-order accept/reject. State is refetched on any WS order event (server wins);
// mutations optimistically replace the affected order in the list.

/** Merge helper: keep local orders whose IDs don't appear in the server list.
 *  These are orders created offline that haven't been synced yet. */
function mergeOrders(server: OrderWire[], local: OrderWire[]): OrderWire[] {
  const serverIds = new Set(server.map((o) => o.id));
  const extras = local.filter((o) => !serverIds.has(o.id));
  return extras.length > 0 ? [...server, ...extras] : server;
}

import { create } from 'zustand';
import { api, wsUrl } from '../api/client';
import { connectRealtime, type RealtimeHandle, type WsEvent } from '../api/ws';
import { cacheGet, cacheSet } from '../offline/db';
import type { OrderWire, ServiceType } from '../api/types';

interface OrdersState {
  orders: OrderWire[];
  loading: boolean;
  error: string | null;
  connected: boolean;
  unseen: number; // new online (pending) orders not yet acknowledged — drives the bell badge
  knownPendingIds: string[];
  handle: RealtimeHandle | null;

  load: (outletId: string) => Promise<void>;
  refresh: (outletId: string) => Promise<void>;
  connect: (outletId: string, token: string) => void;
  disconnect: () => void;
  markSeen: () => void;
  replace: (order: OrderWire) => void;
  accept: (outletId: string, order: OrderWire, prepMinutes?: number) => Promise<OrderWire>;
  reject: (outletId: string, order: OrderWire) => Promise<OrderWire>;
  voidOrder: (outletId: string, order: OrderWire, reason: string) => Promise<void>;
}

function isOrderEvent(ev: WsEvent): boolean {
  const hay = `${ev.type ?? ''} ${ev.entity ?? ''} ${ev.event ?? ''}`.toLowerCase();
  return hay.includes('order') || hay.includes('kot') || hay.includes('settle');
}

/** Short two-tone chime for a newly-arrived online order (no audio asset needed). */
function playChime() {
  try {
    const Ctx = window.AudioContext ?? (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
    if (!Ctx) return;
    const ctx = new Ctx();
    const now = ctx.currentTime;
    [880, 1320].forEach((freq, i) => {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.frequency.value = freq;
      osc.type = 'sine';
      gain.gain.setValueAtTime(0.0001, now + i * 0.16);
      gain.gain.exponentialRampToValueAtTime(0.2, now + i * 0.16 + 0.02);
      gain.gain.exponentialRampToValueAtTime(0.0001, now + i * 0.16 + 0.15);
      osc.connect(gain).connect(ctx.destination);
      osc.start(now + i * 0.16);
      osc.stop(now + i * 0.16 + 0.16);
    });
    setTimeout(() => void ctx.close(), 700);
  } catch {
    /* audio blocked — silent is fine */
  }
}

export const useOrders = create<OrdersState>((set, get) => ({
  orders: [],
  loading: false,
  error: null,
  connected: false,
  unseen: 0,
  knownPendingIds: [],
  handle: null,

  load: async (outletId) => {
    set({ loading: true, error: null });
    try {
      const orders = await api.fetchOrders(outletId);
      const cached = await cacheGet<OrderWire[]>(`orders:${outletId}`);
      const merged = cached ? mergeOrders(orders, cached) : orders;
      await cacheSet(`orders:${outletId}`, merged);
      set({
        orders: merged,
        loading: false,
        knownPendingIds: merged.filter((o) => o.status === 'pending').map((o) => o.id),
      });
    } catch (e) {
      const cached = await cacheGet<OrderWire[]>(`orders:${outletId}`);
      if (cached) {
        set({
          orders: cached,
          loading: false,
          knownPendingIds: cached.filter((o) => o.status === 'pending').map((o) => o.id),
        });
        return;
      }
      set({ loading: false, error: e instanceof Error ? e.message : String(e) });
    }
  },

  refresh: async (outletId) => {
    try {
      const orders = await api.fetchOrders(outletId);
      const local = get().orders;
      const merged = mergeOrders(orders, local);
      void cacheSet(`orders:${outletId}`, merged);
      const prev = new Set(get().knownPendingIds);
      const pending = merged.filter((o) => o.status === 'pending');
      const fresh = pending.filter((o) => !prev.has(o.id));
      if (fresh.length > 0) playChime();
      set({
        orders: merged,
        unseen: get().unseen + fresh.length,
        knownPendingIds: pending.map((o) => o.id),
      });
    } catch {
      /* keep last-known orders on a failed refresh */
    }
  },

  connect: (outletId, token) => {
    if (get().handle) return;
    const handle = connectRealtime({
      url: wsUrl(outletId, token),
      onStatus: (open) => set({ connected: open }),
      onEvent: (ev) => {
        if (isOrderEvent(ev)) void get().refresh(outletId);
      },
    });
    set({ handle });
  },

  disconnect: () => {
    get().handle?.close();
    set({ handle: null, connected: false });
  },

  markSeen: () => set({ unseen: 0 }),

  replace: (order) => {
    set((s) => ({
      orders: s.orders.some((o) => o.id === order.id)
        ? s.orders.map((o) => (o.id === order.id ? order : o))
        : [order, ...s.orders],
    }));
  },

  accept: async (outletId, order, prepMinutes) => {
    if (prepMinutes != null) {
      try {
        await api.updateOrderDetails(outletId, order.id, { prepMinutes });
      } catch {
        /* prep time is advisory — don't block the accept */
      }
    }
    const updated = await api.updateOrderStatus(outletId, order.id, 'accepted', order.updatedAt ?? undefined);
    get().replace(updated);
    set((s) => ({ knownPendingIds: s.knownPendingIds.filter((id) => id !== order.id) }));
    return updated;
  },

  reject: async (outletId, order) => {
    const updated = await api.updateOrderStatus(outletId, order.id, 'rejected', order.updatedAt ?? undefined);
    get().replace(updated);
    set((s) => ({ knownPendingIds: s.knownPendingIds.filter((id) => id !== order.id) }));
    return updated;
  },

  // Void = record a manager audit event, then reject the order (mirrors the mobile flow).
  voidOrder: async (outletId, order, reason) => {
    await api.auditOrder(outletId, order.id, {
      eventId: crypto.randomUUID(),
      action: 'void',
      reason,
      shiftId: order.shiftId ?? null,
    });
    if (order.status !== 'completed') {
      const updated = await api.updateOrderStatus(outletId, order.id, 'rejected', order.updatedAt ?? undefined);
      get().replace(updated);
    } else {
      void get().refresh(outletId);
    }
  },
}));

// ---------- derivations (pure) ----------

export function isSettled(o: OrderWire): boolean {
  const r = !!o.settledAt || o.status === 'completed' || o.status === 'served';
  return r;
}
export function isDead(o: OrderWire): boolean {
  return o.status === 'rejected' || o.status === 'cancelled';
}
/** Online orders awaiting a counter decision. */
export function pendingOnline(orders: OrderWire[]): OrderWire[] {
  return orders.filter((o) => o.status === 'pending' && !isDead(o));
}
/** Accepted work in progress (dine-in / takeaway / accepted delivery), not yet settled. */
export function ongoingOrders(orders: OrderWire[]): OrderWire[] {
  return orders
    .filter((o) => !isSettled(o) && !isDead(o) && o.status !== 'pending')
    .sort((a, b) => (b.createdAt ?? '').localeCompare(a.createdAt ?? ''));
}
export function completedOrders(orders: OrderWire[]): OrderWire[] {
  return orders
    .filter((o) => isSettled(o))
    .sort((a, b) => (b.settledAt ?? b.updatedAt ?? '').localeCompare(a.settledAt ?? a.updatedAt ?? ''));
}

export type TableState = 'vacant' | 'running' | 'kot' | 'paid';

/** Map of table label → the open dine-in order occupying it (latest wins). */
export function occupiedTables(orders: OrderWire[]): Map<string, OrderWire> {
  const map = new Map<string, OrderWire>();
  for (const o of orders) {
    if (isSettled(o) || isDead(o) || o.status === 'pending') continue;
    if ((o.serviceType ?? 'dine_in') !== ('dine_in' as ServiceType)) continue;
    if (!o.tableNo) continue;
    const prev = map.get(o.tableNo);
    if (!prev || (o.createdAt ?? '') > (prev.createdAt ?? '')) map.set(o.tableNo, o);
  }
  return map;
}

export function tableStateOf(order: OrderWire | undefined): TableState {
  if (!order) return 'vacant';
  if (order.settledAt) return 'paid';
  const hasKot = (order.kotBatches?.length ?? 0) > 0 || order.items.some((it) => it.kotSentAt);
  return hasKot ? 'kot' : 'running';
}
