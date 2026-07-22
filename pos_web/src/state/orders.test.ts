import { describe, expect, it } from 'vitest';
import {
  completedOrders, occupiedTables, ongoingOrders, pendingOnline, tableStateOf,
} from './orders';
import type { OrderStatus, OrderWire, ServiceType } from '../api/types';

let serial = 100;
function order(partial: Partial<OrderWire> & { status: OrderStatus }): OrderWire {
  return {
    id: crypto.randomUUID(),
    serialNumber: serial++,
    source: 'desktop_pos',
    totalAmount: 500,
    items: [{ name: 'Tea', qty: 1, price: 500, lineTotal: 500 }],
    serviceType: 'dine_in' as ServiceType,
    ...partial,
  };
}

describe('order derivations', () => {
  it('pendingOnline keeps only pending, drops rejected', () => {
    const list = [
      order({ status: 'pending' }),
      order({ status: 'accepted' }),
      order({ status: 'rejected' }),
    ];
    expect(pendingOnline(list).map((o) => o.status)).toEqual(['pending']);
  });

  it('ongoingOrders includes pending + accepted, excludes settled and dead; newest first', () => {
    const list = [
      order({ status: 'accepted', createdAt: '2026-07-05T10:00:00Z' }),
      order({ status: 'accepted', createdAt: '2026-07-05T12:00:00Z' }),
      order({ status: 'pending' }),
      order({ status: 'completed', settledAt: '2026-07-05T11:00:00Z' }),
      order({ status: 'cancelled' }),
    ];
    const ids = ongoingOrders(list);
    expect(ids).toHaveLength(3); // two accepted + pending
    expect(ids[0].createdAt).toBe('2026-07-05T12:00:00Z'); // newest first
  });

  it('completedOrders picks settled/completed, newest settle first', () => {
    const list = [
      order({ status: 'completed', settledAt: '2026-07-05T09:00:00Z' }),
      order({ status: 'accepted' }),
      order({ status: 'completed', settledAt: '2026-07-05T13:00:00Z' }),
    ];
    const done = completedOrders(list);
    expect(done).toHaveLength(2);
    expect(done[0].settledAt).toBe('2026-07-05T13:00:00Z');
  });

  it('occupiedTables maps dine-in tables, latest wins, ignores settled/takeaway', () => {
    const list = [
      order({ status: 'accepted', tableNo: 'A1', createdAt: '2026-07-05T10:00:00Z' }),
      order({ status: 'accepted', tableNo: 'A1', createdAt: '2026-07-05T12:00:00Z', totalAmount: 900 }),
      order({ status: 'accepted', tableNo: 'A2', serviceType: 'takeaway' }),
      order({ status: 'completed', tableNo: 'A3', settledAt: '2026-07-05T11:00:00Z' }),
    ];
    const map = occupiedTables(list);
    expect(map.get('A1')?.totalAmount).toBe(900); // latest wins
    expect(map.has('A2')).toBe(false); // takeaway isn't a table
    expect(map.has('A3')).toBe(false); // settled table freed
  });

  it('tableStateOf reflects vacant / running / kot / paid', () => {
    expect(tableStateOf(undefined)).toBe('vacant');
    expect(tableStateOf(order({ status: 'accepted' }))).toBe('running');
    expect(tableStateOf(order({
      status: 'accepted',
      items: [{ name: 'x', qty: 1, price: 1, lineTotal: 1, kotSentAt: '2026-07-05T10:00:00Z' }],
    }))).toBe('kot');
    expect(tableStateOf(order({ status: 'accepted', settledAt: '2026-07-05T10:00:00Z' }))).toBe('paid');
  });
});
