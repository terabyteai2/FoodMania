import { describe, expect, it } from 'vitest';
import { matchShortCode, type PosMenuItem } from './menu';
import type { MenuItemWire } from '../api/types';
import { parseExtras } from '../core/tags';

function item(id: string, shortCode: number | null, isAvailable = true): PosMenuItem {
  const raw: MenuItemWire = {
    id, name: id, price: 100, isAvailable, shortCode, version: 1,
  };
  return { raw, extras: parseExtras(raw.tags), price: raw.price, category: 'Test' };
}

const items = [
  item('burger', 12),
  item('fries', 7),
  item('soldout', 99, false),
];

describe('matchShortCode', () => {
  it('resolves an exact available short code', () => {
    expect(matchShortCode(items, '12')?.raw.id).toBe('burger');
    expect(matchShortCode(items, '7')?.raw.id).toBe('fries');
  });

  it('trims surrounding whitespace', () => {
    expect(matchShortCode(items, '  12 ')?.raw.id).toBe('burger');
  });

  it('never returns an unavailable item', () => {
    expect(matchShortCode(items, '99')).toBeNull();
  });

  it('returns null for an unknown code', () => {
    expect(matchShortCode(items, '404')).toBeNull();
  });

  it('rejects blank and non-numeric input', () => {
    expect(matchShortCode(items, '')).toBeNull();
    expect(matchShortCode(items, '   ')).toBeNull();
    expect(matchShortCode(items, '1a')).toBeNull();
    expect(matchShortCode(items, '1.5')).toBeNull();
    expect(matchShortCode(items, 'burger')).toBeNull();
  });

  it('does not match items that have no short code', () => {
    const noCode = [item('x', null)];
    expect(matchShortCode(noCode, '0')).toBeNull();
  });
});
