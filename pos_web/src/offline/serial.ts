// Local order serial number assignment for offline-created orders.
// Mirrors the backend's per-group, per-day MAX+1 counter logic so offline
// orders get a plausible number instead of 0. The server always computes the
// authoritative number on sync; this is only a display-time best guess.

import { cacheGet } from './db';
import type { OrderWire } from '../api/types';

const WEB_SOURCES = /^(customer_web|cloud|cloud_customer|customer_cloud|online|web_cloud)$/;
const MESSENGER_SOURCES = /^(facebook_messenger|facebook|messenger|fb_messenger)$/;
const WAITER_ROLES = /^(waiter|staff)$/;

export function serialGroup(source: string, role?: string | null): string {
  const src = (source ?? '').trim().toLowerCase();
  if (WEB_SOURCES.test(src)) return 'W';
  if (MESSENGER_SOURCES.test(src)) return 'M';
  const r = (role ?? '').trim().toLowerCase();
  if (WAITER_ROLES.test(r)) return 'S';
  return '';
}

function serialKey(outletId: string, group: string): string {
  const today = new Date().toISOString().substring(0, 10);
  return `qbpos.serial.${outletId}.${today}.${group}`;
}

/** Read the next serial number for the given outlet/source/role group,
 *  seeding from the IDB order cache on first use for the day. */
export async function nextSerial(outletId: string, source: string, role?: string | null): Promise<number> {
  const group = serialGroup(source, role);
  const key = serialKey(outletId, group);
  const raw = localStorage.getItem(key);
  if (raw) return Number(raw) + 1;
  const seeded = await seedFromCache(outletId, group);
  localStorage.setItem(key, String(seeded));
  return seeded;
}

async function seedFromCache(outletId: string, group: string): Promise<number> {
  const cached = await cacheGet<OrderWire[]>(`orders:${outletId}`);
  if (!cached || cached.length === 0) return 1;
  let max = 0;
  for (const o of cached) {
    if (serialGroup(o.source, o.createdByRole) !== group) continue;
    if (o.serialNumber > max) max = o.serialNumber;
  }
  return max + 1;
}

/** Call after an outbox-replayed createOrder succeeds so the local counter
 *  stays in sync with the authoritative server value. */
export async function syncSerial(outletId: string, source: string, role: string | null | undefined, serverSerial: number): Promise<void> {
  const group = serialGroup(source, role);
  const key = serialKey(outletId, group);
  const raw = localStorage.getItem(key);
  const current = raw ? Number(raw) : (await seedFromCache(outletId, group)) - 1;
  if (serverSerial > current) {
    localStorage.setItem(key, String(serverSerial));
  }
}
