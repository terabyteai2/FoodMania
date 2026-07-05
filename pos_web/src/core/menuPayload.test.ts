import { describe, expect, it } from 'vitest';
import { mergeMenuPayload, withName, withCategory, withDiscountTag } from './menuPayload';
import type { MenuItemWire } from '../api/types';

const raw: MenuItemWire = {
  id: 'm1', name: 'Naan', nameEn: 'Naan', nameBn: 'নান',
  price: 100, costPrice: 40, category: 'Bread', categoryEn: 'Bread', categoryBn: 'রুটি',
  isAvailable: true, isFavorite: true, shortCode: 42, tags: ['icon:bread', 'discount:percent:10'],
  version: 3,
};

describe('mergeMenuPayload', () => {
  it('sends a full payload, preserving untouched fields and bumping version', () => {
    const p = mergeMenuPayload(raw, { price: 120 });
    expect(p.price).toBe(120);
    expect(p.shortCode).toBe(42);
    expect(p.tags).toEqual(['icon:bread', 'discount:percent:10']);
    expect(p.isFavorite).toBe(true);
    expect(p.nameBn).toBe('নান');
    expect(p.version).toBe(4); // 3 + 1
  });

  it('applies an availability toggle without touching anything else', () => {
    const p = mergeMenuPayload(raw, { isAvailable: false });
    expect(p.isAvailable).toBe(false);
    expect(p.name).toBe('Naan');
  });
});

describe('withName / withCategory', () => {
  it('spreads name across name + nameEn', () => {
    expect(withName({}, 'Roti')).toEqual({ name: 'Roti', nameEn: 'Roti' });
  });
  it('spreads a trimmed category across category + categoryEn', () => {
    expect(withCategory({}, '  Bread ')).toEqual({ category: 'Bread', categoryEn: 'Bread' });
  });
  it('nulls an empty category', () => {
    expect(withCategory({}, '   ')).toEqual({ category: null, categoryEn: null });
  });
});

describe('withDiscountTag', () => {
  it('replaces the discount tag but keeps the rest', () => {
    expect(withDiscountTag(['icon:x', 'discount:percent:10'], 'flat', 15))
      .toEqual(['icon:x', 'discount:flat:15']);
  });
  it('clears the discount tag when kind is null or value is 0', () => {
    expect(withDiscountTag(['discount:percent:10'], null, 0)).toEqual([]);
    expect(withDiscountTag(['icon:x', 'discount:percent:10'], 'percent', 0)).toEqual(['icon:x']);
  });
});
