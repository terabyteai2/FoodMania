// Menu write payloads. POST /menu (upsert) and PATCH /menu/{id} are FULL replacements,
// so every field must be sent — build the complete payload from the existing wire item
// plus a partial edit, preserving shortCode/tags/isFavorite and bumping version.

import type { MenuItemPayload, MenuItemWire } from '../api/types';

/** Full payload from an existing item + a partial edit (for inline edits & bulk actions). */
export function mergeMenuPayload(raw: MenuItemWire, patch: Partial<MenuItemPayload> = {}): MenuItemPayload {
  const base: MenuItemPayload = {
    id: raw.id,
    name: raw.name,
    nameEn: raw.nameEn ?? null,
    nameBn: raw.nameBn ?? null,
    description: raw.description ?? null,
    descriptionEn: raw.descriptionEn ?? null,
    descriptionBn: raw.descriptionBn ?? null,
    price: raw.price,
    costPrice: raw.costPrice ?? null,
    shortCode: raw.shortCode ?? null,
    isFavorite: raw.isFavorite ?? false,
    category: raw.category ?? null,
    categoryEn: raw.categoryEn ?? null,
    categoryBn: raw.categoryBn ?? null,
    isAvailable: raw.isAvailable,
    imageUrl: raw.imageUrl ?? null,
    tags: raw.tags ?? null,
    version: (raw.version ?? 1) + 1,
  };
  return { ...base, ...patch };
}

/** Set the name across the localized fields from a single input (mirrors admin_app). */
export function withName(patch: Partial<MenuItemPayload>, name: string): Partial<MenuItemPayload> {
  return { ...patch, name, nameEn: name };
}

/** Set the (English) category across category/categoryEn from a single input. */
export function withCategory(patch: Partial<MenuItemPayload>, category: string): Partial<MenuItemPayload> {
  const c = category.trim() || null;
  return { ...patch, category: c, categoryEn: c };
}

/** Replace discount tags (percent|flat) while keeping every other tag intact. */
export function withDiscountTag(
  tags: string[] | null | undefined, kind: 'percent' | 'flat' | null, value: number,
): string[] {
  const kept = (tags ?? []).filter((t) => !t.startsWith('discount:'));
  if (kind && value > 0) kept.push(`discount:${kind}:${value}`);
  return kept;
}
