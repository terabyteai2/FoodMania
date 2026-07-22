// Cart + order actions for the billing screen.
// Save creates the order (source 'desktop_pos', status 'accepted' — serial assigned by server);
// further edits PATCH items; KOT and settle use the /pos endpoints.

import { create } from 'zustand';
import { api, ApiError } from '../api/client';
import type {
  OrderLineWire, OrderWire, PaymentMethod, PosSettlementLineWire, ServiceType,
} from '../api/types';
import { computeTotals, type BillTotals, type DiscountInput } from '../core/money';
import { round2 } from '../core/tags';
import { useSession } from './session';
import { usePos } from './pos';
import { useSync } from './sync';
import { useOrders } from './orders';
import { cacheSet } from '../offline/db';
import { nextSerial } from '../offline/serial';

function replaceOrderInStore(order: OrderWire, outletId: string) {
  useOrders.getState().replace(order);
  void cacheSet(`orders:${outletId}`, useOrders.getState().orders);
}

/** Should this failed write be queued for offline replay (vs. surfaced as an error)? */
function shouldQueue(e: unknown): boolean {
  return e instanceof ApiError && (e.offline || e.status === 0 || e.status >= 500);
}

const HELD_KEY = 'qbpos.heldOrders';

export interface CartLine {
  lineId: string;
  menuItemId: string | null;
  nameEn: string;
  nameBn: string | null;
  suffix: string | null; // "(Large, Extra Cheese)"
  unitPrice: number;
  qty: number;
  note: string | null;
  kotSentAt: string | null; // set once included in a sent KOT batch
}

export interface HeldDraft {
  id: string;
  heldAt: string;
  serviceType: ServiceType;
  tableNo: string | null;
  customerName: string | null;
  lines: CartLine[];
  note: string | null;
}

interface CartState {
  lines: CartLine[];
  serviceType: ServiceType;
  tableNo: string | null;
  covers: number | null;
  customerName: string | null;
  deliveryAddress: string | null;
  mobileNumber: string | null;
  note: string | null;
  discount: (DiscountInput & { presetId?: string | null }) | null;
  paymentMethod: PaymentMethod;
  /** Once saved, the active order (server copy). */
  order: OrderWire | null;
  held: HeldDraft[];
  busy: boolean;
  autoPrint: boolean;

  addLine: (line: Omit<CartLine, 'lineId' | 'qty' | 'kotSentAt'>, qty?: number) => void;
  setQty: (lineId: string, qty: number) => void;
  removeLine: (lineId: string) => void;
  setLineNote: (lineId: string, note: string | null) => void;
  setService: (s: ServiceType) => void;
  setTable: (tableNo: string | null) => void;
  setCustomer: (fields: { customerName?: string | null; deliveryAddress?: string | null; mobileNumber?: string | null }) => void;
  setDiscount: (d: CartState['discount']) => void;
  setPaymentMethod: (m: PaymentMethod) => void;
  setNote: (note: string | null) => void;
  clear: () => void;
  loadOrder: (order: OrderWire) => void;

  totals: () => BillTotals;
  saveOrder: () => Promise<OrderWire>;
  sendKot: (note?: string) => Promise<{ order: OrderWire; batchLines: CartLine[]; batchId: string }>;
  settle: (settlements: PosSettlementLineWire[]) => Promise<OrderWire>;

  hold: () => void;
  resumeHeld: (id: string) => void;
  discardHeld: (id: string) => void;
  toggleAutoPrint: () => void;
}

function loadHeld(): HeldDraft[] {
  try {
    return JSON.parse(localStorage.getItem(HELD_KEY) ?? '[]') as HeldDraft[];
  } catch {
    return [];
  }
}
function persistHeld(held: HeldDraft[]) {
  localStorage.setItem(HELD_KEY, JSON.stringify(held));
}

function toWireLines(lines: CartLine[]): OrderLineWire[] {
  return lines.map((l) => ({
    id: l.lineId,
    menuItemId: l.menuItemId,
    name: l.suffix ? `${l.nameEn} ${l.suffix}` : l.nameEn,
    nameEn: l.suffix ? `${l.nameEn} ${l.suffix}` : l.nameEn,
    nameBn: l.nameBn,
    qty: l.qty,
    price: l.unitPrice,
    lineTotal: round2(l.qty * l.unitPrice),
    note: l.note,
    kotSentAt: l.kotSentAt,
  }));
}

const emptyState = {
  lines: [] as CartLine[],
  serviceType: 'dine_in' as ServiceType,
  tableNo: null as string | null,
  covers: null as number | null,
  customerName: null as string | null,
  deliveryAddress: null as string | null,
  mobileNumber: null as string | null,
  note: null as string | null,
  discount: null as CartState['discount'],
  paymentMethod: 'cash' as PaymentMethod,
  order: null as OrderWire | null,
};

export const useCart = create<CartState>((set, get) => ({
  ...emptyState,
  held: loadHeld(),
  busy: false,
  autoPrint: true,

  addLine: (line, qty = 1) => {
    const { lines } = get();
    // merge with an identical un-KOTed line (same item, suffix, price, no note)
    const existing = lines.find(
      (l) =>
        l.menuItemId === line.menuItemId &&
        l.suffix === line.suffix &&
        l.unitPrice === line.unitPrice &&
        !l.note && !line.note && !l.kotSentAt,
    );
    if (existing) {
      set({ lines: lines.map((l) => (l.lineId === existing.lineId ? { ...l, qty: l.qty + qty } : l)) });
    } else {
      set({
        lines: [
          ...lines,
          { ...line, lineId: crypto.randomUUID(), qty, kotSentAt: null },
        ],
      });
    }
  },

  setQty: (lineId, qty) => {
    if (qty <= 0) {
      get().removeLine(lineId);
      return;
    }
    set({ lines: get().lines.map((l) => (l.lineId === lineId ? { ...l, qty } : l)) });
  },

  removeLine: (lineId) => set({ lines: get().lines.filter((l) => l.lineId !== lineId) }),
  setLineNote: (lineId, note) =>
    set({ lines: get().lines.map((l) => (l.lineId === lineId ? { ...l, note } : l)) }),
  setService: (serviceType) => set({ serviceType }),
  setTable: (tableNo) => set({ tableNo }),
  setCustomer: (fields) => set(fields),
  setDiscount: (discount) => set({ discount }),
  setPaymentMethod: (paymentMethod) => set({ paymentMethod }),
  setNote: (note) => set({ note }),
  clear: () => set({ ...emptyState }),

  loadOrder: (order) => {
    set({
      ...emptyState,
      order,
      serviceType: (order.serviceType ?? 'dine_in') as ServiceType,
      tableNo: order.tableNo ?? null,
      covers: order.covers ?? null,
      customerName: order.customerName ?? null,
      deliveryAddress: order.deliveryAddress ?? null,
      mobileNumber: order.mobileNumber ?? null,
      note: order.notes ?? null,
      paymentMethod: (order.paymentMethod ?? 'cash') as PaymentMethod,
      discount:
        order.discountAmount && order.discountAmount > 0
          ? { kind: 'flat', value: order.discountAmount, label: order.discountLabel }
          : null,
      lines: order.items.map((it) => ({
        lineId: it.id ?? crypto.randomUUID(),
        menuItemId: it.menuItemId ?? null,
        nameEn: it.nameEn ?? it.name,
        nameBn: it.nameBn ?? null,
        suffix: null,
        unitPrice: it.price,
        qty: it.qty,
        note: it.note ?? null,
        kotSentAt: it.kotSentAt ?? null,
      })),
    });
  },

  totals: () => {
    const s = get();
    const { settings } = usePos.getState();
    return computeTotals({
      lines: s.lines,
      vatRatePercent: settings?.vatRatePercent ?? 0,
      serviceChargeRatePercent: s.serviceType === 'dine_in' ? settings?.serviceChargePercent ?? 0 : 0,
      discount: s.discount,
      // Counter-punched delivery orders carry no auto delivery charge (that's the
      // online-channel flow); staff can reflect it via a custom line if needed.
      deliveryCharge: 0,
    });
  },

  saveOrder: async () => {
    const s = get();
    const session = useSession.getState().session;
    if (!session) throw new Error('Not signed in');
    if (s.lines.length === 0) throw new Error('Cart is empty');
    set({ busy: true });
    try {
      const totals = s.totals();
      const { settings, shift } = usePos.getState();
      const nowIso = new Date().toISOString();
      const common = {
        shiftId: shift?.id ?? null,
        subtotal: totals.subtotal,
        vatRatePercent: settings?.vatRatePercent ?? 0,
        vatAmount: totals.vatAmount,
        deliveryCharge: totals.deliveryCharge,
        totalAmount: totals.total,
        serviceType: s.serviceType,
        covers: s.covers,
        paymentMethod: s.paymentMethod,
        tableNo: s.serviceType === 'dine_in' ? s.tableNo : null,
        items: toWireLines(s.lines),
        notes: s.note,
        customerName: s.customerName,
        deliveryAddress: s.serviceType === 'delivery' ? s.deliveryAddress : null,
        mobileNumber: s.mobileNumber,
        discountLabel: s.discount?.label ?? null,
        discountAmount: totals.discountAmount,
        serviceChargeRatePercent: s.serviceType === 'dine_in' ? settings?.serviceChargePercent ?? 0 : 0,
        serviceChargeAmount: totals.serviceChargeAmount,
        updatedAt: nowIso,
      };

      let order: OrderWire;
      if (s.order) {
        const itemsBody = {
          items: common.items,
          subtotal: common.subtotal,
          totalAmount: common.totalAmount,
          vatRatePercent: common.vatRatePercent,
          vatAmount: common.vatAmount,
          deliveryCharge: common.deliveryCharge,
          shiftId: common.shiftId,
          updatedAt: nowIso,
        };
        try {
          order = await api.updateOrderItems(session.outletId, s.order.id, itemsBody);
        } catch (e) {
          if (!shouldQueue(e)) throw e;
          await useSync.getState().enqueue(
            { kind: 'updateOrderItems', outletId: session.outletId, orderId: s.order.id, body: itemsBody },
            `items:${s.order.id}:${nowIso}`,
          );
          order = { ...s.order, ...common, id: s.order.id, serialNumber: s.order.serialNumber, updatedAt: nowIso } as OrderWire;
        }
        replaceOrderInStore(order, session.outletId);
      } else {
        const id = crypto.randomUUID();
        const createBody = {
          id,
          serialNumber: 0,
          source: 'desktop_pos',
          status: 'accepted' as const,
          createdByAccountId: session.account.id,
          createdByRole: session.role,
          createdAt: nowIso,
          ...common,
        };
        try {
          order = await api.createOrder(session.outletId, createBody);
        } catch (e) {
          if (!shouldQueue(e)) throw e;
          createBody.serialNumber = await nextSerial(session.outletId, 'desktop_pos', session.role);
          await useSync.getState().enqueue(
            { kind: 'createOrder', outletId: session.outletId, body: createBody },
            `create:${id}`,
          );
          order = createBody as unknown as OrderWire;
        }
        replaceOrderInStore(order, session.outletId);
      }
      set({ order });
      return order;
    } finally {
      set({ busy: false });
    }
  },

  sendKot: async (note) => {
    const s = get();
    const session = useSession.getState().session;
    if (!session) throw new Error('Not signed in');
    const order = s.order ?? (await get().saveOrder());
    const pending = get().lines.filter((l) => !l.kotSentAt);
    if (pending.length === 0) throw new Error('No new items for KOT');
    set({ busy: true });
    try {
      const batchId = crypto.randomUUID();
      const body = { batchId, itemIds: pending.map((l) => l.lineId), note };
      const sentAt = new Date().toISOString();
      const markSent = () =>
        set((prev) => ({ lines: prev.lines.map((l) => (l.kotSentAt ? l : { ...l, kotSentAt: sentAt })) }));
      try {
        const updated = await api.sendKot(session.outletId, order.id, body);
        set({ order: updated });
        replaceOrderInStore(updated, session.outletId);
        markSent();
        return { order: updated, batchLines: pending, batchId };
      } catch (e) {
        if (!shouldQueue(e)) throw e;
        await useSync.getState().enqueue(
          { kind: 'sendKot', outletId: session.outletId, orderId: order.id, body },
          `kot:${batchId}`,
        );
        markSent();
        return { order, batchLines: pending, batchId };
      }
    } finally {
      set({ busy: false });
    }
  },

  settle: async (settlements) => {
    const s = get();
    const session = useSession.getState().session;
    const { shift, settings } = usePos.getState();
    if (!session) throw new Error('Not signed in');
    if (!shift || shift.status !== 'open') throw new Error('Open a shift before settling');
    const order = s.order ?? (await get().saveOrder());
    const totals = get().totals();
    const body = {
      shiftId: shift.id,
      discountPresetId: s.discount?.presetId ?? null,
      customDiscountLabel: s.discount?.presetId ? null : s.discount?.label ?? null,
      discountAmount: totals.discountAmount,
      serviceChargeRatePercent: s.serviceType === 'dine_in' ? settings?.serviceChargePercent ?? 0 : 0,
      serviceChargeAmount: totals.serviceChargeAmount,
      totalAmount: totals.total,
      settlements,
    };
    set({ busy: true });
    try {
      const settled = await api.settleOrder(session.outletId, order.id, body);
      replaceOrderInStore(settled, session.outletId);
      return settled;
    } catch (e) {
      if (!shouldQueue(e)) throw e;
      await useSync.getState().enqueue(
        { kind: 'settleOrder', outletId: session.outletId, orderId: order.id, body },
        `settle:${order.id}`,
      );
      const localSettled = {
        ...order,
        status: 'completed',
        settledAt: new Date().toISOString(),
        paymentMethod: (settlements[0]?.paymentMethod ?? s.paymentMethod) as PaymentMethod,
        totalAmount: totals.total,
        serviceChargeAmount: totals.serviceChargeAmount,
        discountAmount: totals.discountAmount,
      } as OrderWire;
      replaceOrderInStore(localSettled, session.outletId);
      return localSettled;
    } finally {
      set({ busy: false });
    }
  },

  hold: () => {
    const s = get();
    if (s.lines.length === 0 || s.order) return;
    const draft: HeldDraft = {
      id: crypto.randomUUID(),
      heldAt: new Date().toISOString(),
      serviceType: s.serviceType,
      tableNo: s.tableNo,
      customerName: s.customerName,
      lines: s.lines,
      note: s.note,
    };
    const held = [draft, ...s.held];
    persistHeld(held);
    set({ ...emptyState, held });
  },

  resumeHeld: (id) => {
    const s = get();
    const draft = s.held.find((h) => h.id === id);
    if (!draft) return;
    const held = s.held.filter((h) => h.id !== id);
    persistHeld(held);
    set({
      ...emptyState,
      held,
      lines: draft.lines,
      serviceType: draft.serviceType,
      tableNo: draft.tableNo,
      customerName: draft.customerName,
      note: draft.note,
    });
  },

  discardHeld: (id) => {
    const held = get().held.filter((h) => h.id !== id);
    persistHeld(held);
    set({ held });
  },
  toggleAutoPrint: () => set((s) => ({ autoPrint: !s.autoPrint })),
}));
