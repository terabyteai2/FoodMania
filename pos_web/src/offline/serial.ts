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
  const next = raw ? Number(raw) + 1 : await seedFromCache(outletId, group);
  localStorage.setItem(key, String(next));
  return next;
}

async function seedFromCache(outletId: string, group: string): Promise<number> {
  const cached = await cacheGet<OrderWire[]>(`orders:${outletId}`);
  if (!cached || cached.length === 0) return 1;
  const today = new Date().toISOString().substring(0, 10);
  let max = 0;
  for (const o of cached) {
    if (!o.createdAt || !o.createdAt.startsWith(today)) continue;
    if (serialGroup(o.source, o.createdByRole) !== group) continue;
    if (o.serialNumber > max) max = o.serialNumber;
  }
  return max + 1;
}

/** Call after an outbox-replayed createOrder succeeds so the local counter
 *  stays in sync with the authoritative server value. */
export function syncSerial(outletId: string, source: string, role: string | null | undefined, serverSerial: number): void {
  const key = serialKey(outletId, serialGroup(source, role));
  localStorage.setItem(key, String(serverSerial));
}

/** Remove today's serial counter so the next call to nextSerial reseeds from cache. */
export function resetSerial(outletId: string, source: string, role?: string | null): void {
  const key = serialKey(outletId, serialGroup(source, role));
  localStorage.removeItem(key);
}
