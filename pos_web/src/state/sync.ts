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
import { resetSerial } from '../offline/serial';
import { useSession } from './session';

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
    await enqueueOp(idbOutbox, op, key);
    await get().refreshCounts();
  },

  flush: async (outletId) => {
    if (get().replaying) return;
    set({ replaying: true });
    try {
      await replayOutbox(idbOutbox, outboxApi);
      await get().refreshCounts();
      if (outletId) {
        await useOrders.getState().refresh(outletId);
        const role = useSession.getState().session?.role;
        resetSerial(outletId, 'desktop_pos', role);
      }
    } finally {
      set({ replaying: false });
    }
  },

  discardDead: async (seq) => {
    await idbOutbox.remove(seq);
    await get().refreshCounts();
  },
}));
