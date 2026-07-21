// Sync store: owns the IndexedDB outbox, exposes queued/dead-letter counts, and
// drains the queue (flush) on reconnect. Mutation call-sites enqueue through here
// when a write fails offline; replay reconciles by refetching orders afterward.

import { create } from 'zustand';
import { api } from '../api/client';
import { idbOutbox } from '../offline/db';
import {
  enqueue as enqueueOp, replayOutbox,
  type OutboxApi, type OutboxOp, type OutboxRecord,
} from '../offline/outbox';
import { useOrders } from './orders';

function dbg(...args: unknown[]) { console.log('[sync]', ...args); }

const outboxApi: OutboxApi = api;

interface SyncState {
  queued: number;
  dead: OutboxRecord[];
  replaying: boolean;
  refreshCounts: () => Promise<void>;
  enqueue: (op: OutboxOp, key: string) => Promise<void>;
  flush: (outletId?: string) => Promise<void>;
  discardDead: (seq: number) => Promise<void>;
}

export const useSync = create<SyncState>((set, get) => ({
  queued: 0,
  dead: [],
  replaying: false,

  refreshCounts: async () => {
    const all = await idbOutbox.all();
    set({
      queued: all.filter((r) => !r.deadLetter).length,
      dead: all.filter((r) => r.deadLetter),
    });
  },

  enqueue: async (op, key) => {
    dbg('enqueue', op.kind, key);
    await enqueueOp(idbOutbox, op, key);
    await get().refreshCounts();
  },

  flush: async (outletId) => {
    if (get().replaying) { dbg('flush skipped — already replaying'); return; }
    dbg('flush start, outletId:', outletId);
    set({ replaying: true });
    try {
      const result = await replayOutbox(idbOutbox, outboxApi);
      dbg('flush replay result — done:', result.done, 'dead:', result.dead, 'pending:', result.pending);
      await get().refreshCounts();
      if (result.done > 0 && outletId) {
        dbg('flush → orders.refresh()');
        await useOrders.getState().refresh(outletId);
      } else {
        dbg('flush skipped refresh (no ops drained or no outletId)');
      }
    } finally {
      set({ replaying: false });
      dbg('flush done');
    }
  },

  discardDead: async (seq) => {
    await idbOutbox.remove(seq);
    await get().refreshCounts();
  },
}));
