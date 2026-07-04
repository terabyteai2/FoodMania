// IndexedDB persistence: a key/value cache (menu, settings, orders snapshots for
// offline boot) and the mutation outbox store. Everything is best-effort — if IDB
// is unavailable the app still runs online-only (helpers swallow and no-op).

import { openDB, type IDBPDatabase } from 'idb';
import type { OutboxOp, OutboxRecord, OutboxStore } from './outbox';

const DB_NAME = 'qbpos';
const DB_VERSION = 1;
const KV = 'kv';
const OUTBOX = 'outbox';

let dbp: Promise<IDBPDatabase> | null = null;

function db(): Promise<IDBPDatabase> {
  if (!dbp) {
    dbp = openDB(DB_NAME, DB_VERSION, {
      upgrade(d) {
        if (!d.objectStoreNames.contains(KV)) d.createObjectStore(KV);
        if (!d.objectStoreNames.contains(OUTBOX)) d.createObjectStore(OUTBOX, { keyPath: 'seq', autoIncrement: true });
      },
    });
  }
  return dbp;
}

// ---------- cache (read-through / write-through for boot) ----------
export async function cacheGet<T>(key: string): Promise<T | null> {
  try {
    return (await (await db()).get(KV, key)) as T ?? null;
  } catch {
    return null;
  }
}

export async function cacheSet(key: string, value: unknown): Promise<void> {
  try {
    await (await db()).put(KV, value, key);
  } catch {
    /* ignore — cache is best-effort */
  }
}

// ---------- outbox store ----------
export const idbOutbox: OutboxStore = {
  async all() {
    try {
      return (await (await db()).getAll(OUTBOX)) as OutboxRecord[];
    } catch {
      return [];
    }
  },
  async add(op: OutboxOp, key: string) {
    const record = { op, key, attempts: 0, createdAt: new Date().toISOString() };
    const seq = await (await db()).add(OUTBOX, record);
    return { ...record, seq: Number(seq) };
  },
  async remove(seq: number) {
    await (await db()).delete(OUTBOX, seq);
  },
  async update(seq: number, patch: Partial<OutboxRecord>) {
    const d = await db();
    const existing = (await d.get(OUTBOX, seq)) as OutboxRecord | undefined;
    if (existing) await d.put(OUTBOX, { ...existing, ...patch });
  },
};
