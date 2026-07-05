// Menu item tag decoding — mirrors admin_app MenuItemExtras.fromTags.
// Tag grammar: "icon:<key>", "discount:percent:<n>", "discount:flat:<n>",
// "inc:<text>", "option:<name>:<priceDelta>", "size:<name>:<price>", "addon:<price>:<name>"

export interface MenuOption { name: string; priceDelta: number; }
export interface MenuAddOn { name: string; price: number; }
export interface MenuSizeVariant { name: string; price: number; }

export interface MenuExtras {
  iconKey: string | null;
  discountPercent: number | null;
  discountFlat: number | null;
  includes: string[];
  options: MenuOption[];
  sizes: MenuSizeVariant[];
  addOns: MenuAddOn[];
}

export function parseExtras(tags: string[] | null | undefined): MenuExtras {
  const extras: MenuExtras = {
    iconKey: null, discountPercent: null, discountFlat: null,
    includes: [], options: [], sizes: [], addOns: [],
  };
  for (const raw of tags ?? []) {
    const tag = raw.trim();
    if (tag.startsWith('icon:')) {
      extras.iconKey = tag.slice(5) || null;
    } else if (tag.startsWith('discount:percent:')) {
      extras.discountPercent = num(tag.slice(17));
    } else if (tag.startsWith('discount:flat:')) {
      extras.discountFlat = num(tag.slice(14));
    } else if (tag.startsWith('inc:')) {
      const text = tag.slice(4).trim();
      if (text) extras.includes.push(text);
    } else if (tag.startsWith('option:')) {
      const sep = tag.lastIndexOf(':');
      if (sep > 7) {
        const name = tag.slice(7, sep).trim();
        const delta = num(tag.slice(sep + 1));
        if (name && delta !== null) extras.options.push({ name, priceDelta: delta });
      }
    } else if (tag.startsWith('size:')) {
      const sep = tag.lastIndexOf(':');
      if (sep > 5) {
        const name = tag.slice(5, sep).trim();
        const price = num(tag.slice(sep + 1));
        if (name && price !== null && price > 0) extras.sizes.push({ name, price });
      }
    } else if (tag.startsWith('addon:')) {
      const rest = tag.slice(6);
      const sep = rest.indexOf(':');
      if (sep > 0) {
        const price = num(rest.slice(0, sep));
        const name = rest.slice(sep + 1).trim();
        if (name && price !== null) extras.addOns.push({ name, price });
      }
    }
  }
  return extras;
}

/** Encode extras back into the tag string list (inverse of parseExtras). */
export function buildTags(extras: MenuExtras): string[] {
  const tags: string[] = [];
  if (extras.iconKey) tags.push(`icon:${extras.iconKey}`);
  if (extras.discountPercent && extras.discountPercent > 0) {
    tags.push(`discount:percent:${extras.discountPercent}`);
  } else if (extras.discountFlat && extras.discountFlat > 0) {
    tags.push(`discount:flat:${extras.discountFlat}`);
  }
  for (const inc of extras.includes) if (inc.trim()) tags.push(`inc:${inc.trim()}`);
  for (const o of extras.options) if (o.name.trim()) tags.push(`option:${o.name.trim()}:${o.priceDelta}`);
  for (const s of extras.sizes) if (s.name.trim() && s.price > 0) tags.push(`size:${s.name.trim()}:${s.price}`);
  for (const a of extras.addOns) if (a.name.trim()) tags.push(`addon:${a.price}:${a.name.trim()}`);
  return tags;
}

/** Unit price after item-level discount tags (shown struck-through in the grid). */
export function effectiveUnitPrice(basePrice: number, extras: MenuExtras): number {
  let price = basePrice;
  if (extras.discountPercent && extras.discountPercent > 0) {
    price = price * (1 - Math.min(extras.discountPercent, 100) / 100);
  } else if (extras.discountFlat && extras.discountFlat > 0) {
    price = Math.max(0, price - extras.discountFlat);
  }
  return round2(price);
}

export function needsCustomization(extras: MenuExtras): boolean {
  return extras.sizes.length > 0 || extras.options.length > 0 || extras.addOns.length > 0;
}

function num(s: string): number | null {
  const v = Number(s);
  return Number.isFinite(v) ? v : null;
}

export function round2(v: number): number {
  return Math.round(v * 100) / 100;
}
