// Mutation outbox: queued writes that survive a network blip and replay in order
// once we're back online. Idempotency is carried by the payloads themselves
// (order id UUID, KOT batchId, settle/audit eventId), so a replayed op is a no-op
// server-side. The engine is decoupled from IndexedDB (OutboxStore) and the HTTP
// client (OutboxApi) so it can be unit-tested with in-memory fakes.

export type SettleBody = {
  shiftId: string;
  discountPresetId?: string | null;
  customDiscountLabel?: string | null;
  discountAmount: number;
  serviceChargeRatePercent: number;
  serviceChargeAmount: number;
  totalAmount: number;
  settlements: { eventId: string; paymentMethod: string; amount: number; payerLabel?: string | null }[];
};

export type OutboxOp =
  | { kind: 'createOrder'; outletId: string; body: Record<string, unknown> }
  | { kind: 'updateOrderItems'; outletId: string; orderId: string; body: Record<string, unknown> }
  | { kind: 'updateOrderStatus'; outletId: string; orderId: string; status: string; updatedAt?: string }
  | { kind: 'sendKot'; outletId: string; orderId: string; body: { batchId: string; itemIds: string[]; note?: string } }
  | { kind: 'settleOrder'; outletId: string; orderId: string; body: SettleBody }
  | { kind: 'auditOrder'; outletId: string; orderId: string; body: Record<string, unknown> };

export interface OutboxRecord {
  seq: number;
  key: string; // idempotency key — one op per key in the queue
  op: OutboxOp;
  attempts: number;
  lastError?: string;
  deadLetter?: boolean;
  createdAt: string;
}

export interface OutboxStore {
  all(): Promise<OutboxRecord[]>;
  add(op: OutboxOp, key: string): Promise<OutboxRecord>;
  remove(seq: number): Promise<void>;
  update(seq: number, patch: Partial<OutboxRecord>): Promise<void>;
}

export interface OutboxApi {
  createOrder(outletId: string, body: Record<string, unknown>): Promise<unknown>;
  updateOrderItems(outletId: string, orderId: string, body: Record<string, unknown>): Promise<unknown>;
  updateOrderStatus(outletId: string, orderId: string, status: string, updatedAt?: string): Promise<unknown>;
  sendKot(outletId: string, orderId: string, body: { batchId: string; itemIds: string[]; note?: string }): Promise<unknown>;
  settleOrder(outletId: string, orderId: string, body: SettleBody): Promise<unknown>;
  auditOrder(outletId: string, orderId: string, body: Record<string, unknown>): Promise<unknown>;
}

export interface ReplayResult {
  done: number;
  dead: number;
  pending: number;
}

function dbg(...args: unknown[]) { console.log('[outbox]', ...args); }

/** Add an op unless one with the same idempotency key is already queued. */
export async function enqueue(store: OutboxStore, op: OutboxOp, key: string): Promise<boolean> {
  const existing = await store.all();
  if (existing.some((r) => r.key === key)) { dbg('enqueue skip (dup key)', key, op.kind); return false; }
  await store.add(op, key);
  dbg('enqueued', key, op.kind);
  return true;
}

export function dispatch(api: OutboxApi, op: OutboxOp): Promise<unknown> {
  dbg('dispatch', op.kind, 'orderId' in op ? op.orderId : '(no orderId)');
  switch (op.kind) {
    case 'createOrder':
      return api.createOrder(op.outletId, op.body);
    case 'updateOrderItems':
      return api.updateOrderItems(op.outletId, op.orderId, op.body);
    case 'updateOrderStatus':
      return api.updateOrderStatus(op.outletId, op.orderId, op.status, op.updatedAt);
    case 'sendKot':
      return api.sendKot(op.outletId, op.orderId, op.body);
    case 'settleOrder':
      return api.settleOrder(op.outletId, op.orderId, op.body);
    case 'auditOrder':
      return api.auditOrder(op.outletId, op.orderId, op.body);
  }
}

/**
 * Transient = retry later (offline, timeout, 5xx) → stop and preserve order.
 * Permanent = server rejected (4xx) → dead-letter and skip so the queue drains.
 */
export function classifyError(err: unknown): 'transient' | 'permanent' {
  const e = err as { offline?: boolean; status?: number } | null;
  if (e?.offline) return 'transient';
  const s = e?.status ?? 0;
  if (s === 0 || s >= 500 || s === 408 || s === 429) return 'transient';
  if (s >= 400) return 'permanent';
  return 'transient';
}

/**
 * Replay queued ops in FIFO order. Stops at the first transient failure (to keep
 * ordering intact) and dead-letters permanent failures so the rest can drain.
 */
export async function replayOutbox(store: OutboxStore, api: OutboxApi): Promise<ReplayResult> {
  const records = (await store.all())
    .filter((r) => !r.deadLetter)
    .sort((a, b) => a.seq - b.seq);

  dbg('replay start —', records.length, 'pending');
  let done = 0;
  let dead = 0;
  for (const r of records) {
    dbg('replay op', r.seq, r.op.kind, '(attempt', r.attempts + 1, ')');
    try {
      await dispatch(api, r.op);
      await store.remove(r.seq);
      done++;
      dbg('replay ok — removed seq', r.seq);
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      dbg('replay fail —', msg);
      if (classifyError(err) === 'permanent') {
        dbg('dead-lettering seq', r.seq);
        await store.update(r.seq, { deadLetter: true, lastError: msg, attempts: r.attempts + 1 });
        dead++;
      } else {
        dbg('transient — stopping');
        await store.update(r.seq, { attempts: r.attempts + 1, lastError: msg });
        break;
      }
    }
  }

  const pending = (await store.all()).filter((r) => !r.deadLetter).length;
  dbg('replay done — done:', done, 'dead:', dead, 'pending:', pending);
  return { done, dead, pending };
}
