import { describe, expect, it } from 'vitest';
import { parseExtras, buildTags, type MenuExtras } from './tags';

describe('buildTags / parseExtras round-trip', () => {
  it('re-encodes extras into tags that decode back identically', () => {
    const extras: MenuExtras = {
      iconKey: 'pizza',
      discountPercent: 15,
      discountFlat: null,
      includes: ['Fries', 'Drink'],
      sizes: [{ name: 'Large', price: 250 }],
      options: [{ name: 'Extra spicy', priceDelta: 0 }],
      addOns: [{ name: 'Cheese', price: 30 }],
    };
    const tags = buildTags(extras);
    expect(tags).toContain('icon:pizza');
    expect(tags).toContain('discount:percent:15');
    expect(tags).toContain('inc:Fries');
    expect(tags).toContain('size:Large:250');
    expect(tags).toContain('option:Extra spicy:0');
    expect(tags).toContain('addon:30:Cheese');

    const back = parseExtras(tags);
    expect(back).toEqual(extras);
  });

  it('prefers percent over flat and drops zero/blank entries', () => {
    const tags = buildTags({
      iconKey: null, discountPercent: 10, discountFlat: 20,
      includes: ['', ' '], sizes: [{ name: 'X', price: 0 }],
      options: [{ name: '', priceDelta: 5 }], addOns: [],
    });
    expect(tags).toEqual(['discount:percent:10']);
  });
});
