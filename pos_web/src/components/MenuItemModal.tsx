// Add / edit a menu item. Core fields inline + a collapsible Advanced block that
// round-trips the tag grammar (includes / options / add-ons / discount) via core/tags.
import { useState } from 'react';
import { Modal } from './Modal';
import { parseExtras, buildTags, type MenuExtras } from '../core/tags';
import { mergeMenuPayload } from '../core/menuPayload';
import type { MenuItemPayload, MenuItemWire } from '../api/types';

interface Props {
  existing: MenuItemWire | null; // null = create
  categories: string[];
  onClose: () => void;
  onSave: (payload: MenuItemPayload) => Promise<void>;
}

function linesOf(s: string): string[] {
  return s.split('\n').map((l) => l.trim()).filter(Boolean);
}
function parsePair(line: string): { name: string; value: number } | null {
  const i = line.lastIndexOf(':');
  if (i <= 0) return null;
  const name = line.slice(0, i).trim();
  const value = Number(line.slice(i + 1));
  return name && Number.isFinite(value) ? { name, value } : null;
}

export function MenuItemModal({ existing, categories, onClose, onSave }: Props) {
  const ex: MenuExtras = parseExtras(existing?.tags);
  const [name, setName] = useState(existing?.nameEn || existing?.name || '');
  const [price, setPrice] = useState(String(existing?.price ?? ''));
  const [costPrice, setCostPrice] = useState(existing?.costPrice != null ? String(existing.costPrice) : '');
  const [shortCode, setShortCode] = useState(existing?.shortCode != null ? String(existing.shortCode) : '');
  const [category, setCategory] = useState(existing?.categoryEn || existing?.category || '');
  const [available, setAvailable] = useState(existing?.isAvailable ?? true);
  const [discountKind, setDiscountKind] = useState<'none' | 'percent' | 'flat'>(
    ex.discountPercent ? 'percent' : ex.discountFlat ? 'flat' : 'none',
  );
  const [discountValue, setDiscountValue] = useState(String(ex.discountPercent ?? ex.discountFlat ?? ''));
  const [advanced, setAdvanced] = useState(false);
  const [description, setDescription] = useState(existing?.descriptionEn || existing?.description || '');
  const [includes, setIncludes] = useState(ex.includes.join('\n'));
  const [options, setOptions] = useState(ex.options.map((o) => `${o.name}:${o.priceDelta}`).join('\n'));
  const [addons, setAddons] = useState(ex.addOns.map((a) => `${a.name}:${a.price}`).join('\n'));
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  const priceNum = Number(price);
  const valid = name.trim().length > 0 && Number.isFinite(priceNum) && priceNum >= 0;

  const submit = async () => {
    if (!valid) { setErr('Enter a name and a valid price.'); return; }
    setBusy(true); setErr(null);
    const dVal = Number(discountValue);
    const extras: MenuExtras = {
      iconKey: ex.iconKey,
      discountPercent: discountKind === 'percent' && dVal > 0 ? dVal : null,
      discountFlat: discountKind === 'flat' && dVal > 0 ? dVal : null,
      includes: linesOf(includes),
      sizes: ex.sizes, // sizes editing is out of scope — preserve existing
      options: linesOf(options).map(parsePair).filter((p): p is { name: string; value: number } => !!p)
        .map((p) => ({ name: p.name, priceDelta: p.value })),
      addOns: linesOf(addons).map(parsePair).filter((p): p is { name: string; value: number } => !!p)
        .map((p) => ({ name: p.name, price: p.value })),
    };
    const cat = category.trim() || null;
    const patch: Partial<MenuItemPayload> = {
      name: name.trim(), nameEn: name.trim(),
      price: priceNum,
      costPrice: costPrice.trim() ? Number(costPrice) : null,
      shortCode: shortCode.trim() ? Number(shortCode) : null,
      category: cat, categoryEn: cat,
      isAvailable: available,
      description: description.trim() || null, descriptionEn: description.trim() || null,
      tags: buildTags(extras),
    };
    const payload: MenuItemPayload = existing
      ? mergeMenuPayload(existing, patch)
      : { id: crypto.randomUUID(), version: 1, isFavorite: false, ...patch } as MenuItemPayload;
    try {
      await onSave(payload);
      onClose();
    } catch (e) {
      setErr(e instanceof Error ? e.message : String(e));
      setBusy(false);
    }
  };

  return (
    <Modal
      title={existing ? 'Edit item' : 'Add item'}
      onClose={onClose}
      width={520}
      footer={
        <>
          <button className="btn btn-outline" onClick={onClose} disabled={busy}>Cancel</button>
          <button className="btn btn-primary" onClick={() => void submit()} disabled={busy || !valid}>
            {busy ? 'Saving…' : 'Save'}
          </button>
        </>
      }
    >
      <div className="mm-form">
        <label className="field"><span>Item name</span>
          <input className="input" value={name} onChange={(e) => setName(e.target.value)} autoFocus />
        </label>
        <div className="mm-form-row">
          <label className="field"><span>Price (৳)</span>
            <input className="input" type="number" inputMode="decimal" value={price} onChange={(e) => setPrice(e.target.value)} />
          </label>
          <label className="field"><span>Cost price (৳)</span>
            <input className="input" type="number" inputMode="decimal" value={costPrice} onChange={(e) => setCostPrice(e.target.value)} />
          </label>
        </div>
        <div className="mm-form-row">
          <label className="field"><span>Short code</span>
            <input className="input" type="number" inputMode="numeric" value={shortCode} onChange={(e) => setShortCode(e.target.value)} />
          </label>
          <label className="field"><span>Category</span>
            <input className="input" list="mm-categories" value={category} onChange={(e) => setCategory(e.target.value)} />
            <datalist id="mm-categories">{categories.map((c) => <option key={c} value={c} />)}</datalist>
          </label>
        </div>
        <label className="mm-check">
          <input type="checkbox" checked={available} onChange={(e) => setAvailable(e.target.checked)} />
          <span>Available for sale</span>
        </label>
        <div className="mm-form-row">
          <label className="field"><span>Discount</span>
            <select className="input" value={discountKind} onChange={(e) => setDiscountKind(e.target.value as 'none' | 'percent' | 'flat')}>
              <option value="none">None</option>
              <option value="percent">Percent %</option>
              <option value="flat">Flat ৳</option>
            </select>
          </label>
          <label className="field"><span>Amount</span>
            <input className="input" type="number" inputMode="decimal" value={discountValue}
              disabled={discountKind === 'none'} onChange={(e) => setDiscountValue(e.target.value)} />
          </label>
        </div>

        <button className="mm-advanced-toggle" onClick={() => setAdvanced((v) => !v)}>
          {advanced ? '▾' : '▸'} Advanced (description, includes, options, add-ons)
        </button>
        {advanced && (
          <div className="mm-advanced">
            <label className="field"><span>Description</span>
              <textarea className="input mm-area" value={description} onChange={(e) => setDescription(e.target.value)} rows={2} />
            </label>
            <label className="field"><span>Includes (one per line)</span>
              <textarea className="input mm-area" value={includes} onChange={(e) => setIncludes(e.target.value)} rows={2} />
            </label>
            <label className="field"><span>Options — name:priceDelta (one per line)</span>
              <textarea className="input mm-area" value={options} onChange={(e) => setOptions(e.target.value)} rows={2} placeholder="Large:50" />
            </label>
            <label className="field"><span>Add-ons — name:price (one per line)</span>
              <textarea className="input mm-area" value={addons} onChange={(e) => setAddons(e.target.value)} rows={2} placeholder="Extra cheese:30" />
            </label>
          </div>
        )}
        {err && <div className="bo-err">{err}</div>}
      </div>
    </Modal>
  );
}
