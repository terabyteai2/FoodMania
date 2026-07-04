import { describe, expect, it } from 'vitest';
import {
  classifyError, enqueue, replayOutbox,
  type OutboxApi, type OutboxOp, type OutboxRecord, type OutboxStore,
} from './outbox';

function memStore(): OutboxStore & { records: OutboxRecord[] } {
  let seq = 1;
  const records: OutboxRecord[] = [];
  return {
    records,
    async all() { return records.map((r) => ({ ...r })); },
    async add(op, key) {
      const r: OutboxRecord = { seq: seq++, op, key, attempts: 0, createdAt: 'now' };
      records.push(r);
      return { ...r };
    },
    async remove(s) {
      const i = records.findIndex((r) => r.seq === s);
      if (i >= 0) records.splice(i, 1);
    },
    async update(s, patch) {
      const r = records.find((x) => x.seq === s);
      if (r) Object.assign(r, patch);
    },
  };
}

/** Fake API that records dispatched kinds and can reject per op-kind. */
function fakeApi(reject?: Partial<Record<OutboxOp['kind'], { offline?: boolean; status?: number }>>) {
  const calls: OutboxOp['kind'][] = [];
  const h = (kind: OutboxOp['kind']) => {
    calls.push(kind);
    const err = reject?.[kind];
    return err ? Promise.reject(err) : Promise.resolve({});
  };
  const api: OutboxApi = {
    createOrder: () => h('createOrder'),
    updateOrderItems: () => h('updateOrderItems'),
    updateOrderStatus: () => h('updateOrderStatus'),
    sendKot: () => h('sendKot'),
    settleOrder: () => h('settleOrder'),
    auditOrder: () => h('auditOrder'),
  };
  return { api, calls };
}

const createOp: OutboxOp = { kind: 'createOrder', outletId: 'o1', body: { id: 'x' } };
const kotOp: OutboxOp = { kind: 'sendKot', outletId: 'o1', orderId: 'x', body: { batchId: 'b1', itemIds: ['l1'] } };

describe('enqueue', () => {
  it('is idempotent on the key', async () => {
    const store = memStore();
    expect(await enqueue(store, createOp, 'create:x')).toBe(true);
    expect(await enqueue(store, createOp, 'create:x')).toBe(false);
    expect(store.records).toHaveLength(1);
  });
});

describe('replayOutbox', () => {
  it('drains all ops on success (FIFO), removing each', async () => {
    const store = memStore();
    await enqueue(store, createOp, 'create:x');
    await enqueue(store, kotOp, 'kot:b1');
    const { api, calls } = fakeApi();
    const res = await replayOutbox(store, api);
    expect(calls).toEqual(['createOrder', 'sendKot']);
    expect(res).toEqual({ done: 2, dead: 0, pending: 0 });
    expect(store.records).toHaveLength(0);
  });

  it('stops at the first transient failure and preserves ordering', async () => {
    const store = memStore();
    await enqueue(store, createOp, 'create:x');
    await enqueue(store, kotOp, 'kot:b1');
    const { api, calls } = fakeApi({ createOrder: { offline: true } });
    const res = await replayOutbox(store, api);
    expect(calls).toEqual(['createOrder']); // never reached the KOT
    expect(res).toEqual({ done: 0, dead: 0, pending: 2 });
    expect(store.records[0].attempts).toBe(1);
    expect(store.records[0].deadLetter).toBeUndefined();
  });

  it('dead-letters a permanent failure and continues draining', async () => {
    const store = memStore();
    await enqueue(store, createOp, 'create:x');
    await enqueue(store, kotOp, 'kot:b1');
    const { api, calls } = fakeApi({ createOrder: { status: 422 } });
    const res = await replayOutbox(store, api);
    expect(calls).toEqual(['createOrder', 'sendKot']);
    expect(res).toEqual({ done: 1, dead: 1, pending: 0 });
    const create = store.records.find((r) => r.key === 'create:x');
    expect(create?.deadLetter).toBe(true);
    expect(store.records.find((r) => r.key === 'kot:b1')).toBeUndefined(); // succeeded, removed
  });

  it('skips already dead-lettered records on the next pass', async () => {
    const store = memStore();
    await enqueue(store, createOp, 'create:x');
    store.records[0].deadLetter = true;
    const { api, calls } = fakeApi();
    const res = await replayOutbox(store, api);
    expect(calls).toEqual([]);
    expect(res.pending).toBe(0);
  });
});

describe('classifyError', () => {
  it('treats offline / timeout / 5xx as transient', () => {
    expect(classifyError({ offline: true })).toBe('transient');
    expect(classifyError({ status: 0 })).toBe('transient');
    expect(classifyError({ status: 503 })).toBe('transient');
    expect(classifyError({ status: 429 })).toBe('transient');
  });
  it('treats 4xx rejections as permanent', () => {
    expect(classifyError({ status: 422 })).toBe('permanent');
    expect(classifyError({ status: 404 })).toBe('permanent');
    expect(classifyError({ status: 409 })).toBe('permanent');
  });
});
