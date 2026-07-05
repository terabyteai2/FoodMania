// Menu management (petpooja12 in-scope part) — category sidebar, search, inline-editable
// rows (name / short code / category / price / available), bulk actions, add/edit modal.
// No channel toggles, no multi-restaurant push. Writes are online-only for v1.

import { useMemo, useState } from 'react';
import { useSession } from '../state/session';
import { useMenu, itemDisplayName } from '../state/menu';
import { mergeMenuPayload, withName, withCategory, withDiscountTag } from '../core/menuPayload';
import { MenuItemModal } from '../components/MenuItemModal';
import type { MenuItemPayload, MenuItemWire } from '../api/types';
import './backoffice.css';
import './menu-manage.css';

/** Commit-on-blur/Enter text input (matches the picture's inline-editable columns). */
function InlineField({
  value, onCommit, type = 'text', list, align,
}: {
  value: string; onCommit: (v: string) => void; type?: string; list?: string; align?: 'right';
}) {
  const [draft, setDraft] = useState(value);
  const commit = () => { if (draft !== value) onCommit(draft); };
  return (
    <input
      className="mm-inline" type={type} list={list} value={draft}
      style={align === 'right' ? { textAlign: 'right' } : undefined}
      onChange={(e) => setDraft(e.target.value)}
      onBlur={commit}
      onKeyDown={(e) => { if (e.key === 'Enter') (e.target as HTMLInputElement).blur(); if (e.key === 'Escape') setDraft(value); }}
    />
  );
}

export function MenuManage() {
  const session = useSession((s) => s.session)!;
  const lang = useSession((s) => s.lang);
  const menu = useMenu();

  const [activeCat, setActiveCat] = useState<string>('all');
  const [search, setSearch] = useState('');
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [editing, setEditing] = useState<MenuItemWire | null | 'new'>(null);
  const [toast, setToast] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const flash = (m: string) => { setToast(m); window.setTimeout(() => setToast(null), 2600); };

  const counts = useMemo(() => {
    const c: Record<string, number> = {};
    for (const it of menu.items) c[it.category] = (c[it.category] ?? 0) + 1;
    return c;
  }, [menu.items]);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    return menu.items.filter((it) => {
      if (activeCat !== 'all' && it.category !== activeCat) return false;
      if (!q) return true;
      const name = itemDisplayName(it, lang === 'bn').toLowerCase();
      return name.includes(q) || String(it.raw.shortCode ?? '').includes(q);
    });
  }, [menu.items, activeCat, search, lang]);

  const run = async (fn: () => Promise<void>, ok: string) => {
    setBusy(true);
    try { await fn(); flash(ok); }
    catch (e) { flash(e instanceof Error ? e.message : String(e)); }
    finally { setBusy(false); }
  };

  const savePatch = (raw: MenuItemWire, patch: Partial<MenuItemPayload>) =>
    run(() => menu.saveItem(session.outletId, mergeMenuPayload(raw, patch)), 'Saved');

  const toggleSel = (id: string) => {
    const next = new Set(selected);
    if (next.has(id)) next.delete(id); else next.add(id);
    setSelected(next);
  };

  const bulk = (patch: (raw: MenuItemWire) => Partial<MenuItemPayload>, ok: string) => {
    const payloads = menu.items.filter((i) => selected.has(i.raw.id)).map((i) => mergeMenuPayload(i.raw, patch(i.raw)));
    if (payloads.length === 0) return;
    void run(async () => { await menu.saveMany(session.outletId, payloads); setSelected(new Set()); }, ok);
  };

  const bulkDiscount = () => {
    const input = window.prompt('Apply percent discount to selected items (e.g. 10). Blank clears discount.');
    if (input === null) return;
    const pct = Number(input);
    if (!Number.isFinite(pct)) return;
    bulk((raw) => ({ tags: withDiscountTag(raw.tags, pct > 0 ? 'percent' : null, pct) }),
      pct > 0 ? `Applied ${pct}% discount` : 'Cleared discount');
  };

  const saveFromModal = (payload: MenuItemPayload) => menu.saveItem(session.outletId, payload);

  return (
    <div className="mm-root">
      <aside className="mm-side">
        <button className={`mm-cat ${activeCat === 'all' ? 'active' : ''}`} onClick={() => setActiveCat('all')}>
          <span>All items</span><span className="mm-cat-n">{menu.items.length}</span>
        </button>
        {menu.categories.map((c) => (
          <button key={c} className={`mm-cat ${activeCat === c ? 'active' : ''}`} onClick={() => setActiveCat(c)}>
            <span>{c}</span><span className="mm-cat-n">{counts[c] ?? 0}</span>
          </button>
        ))}
      </aside>

      <div className="mm-main">
        <div className="mm-head">
          <input className="input mm-search" placeholder="Search name or short code…"
            value={search} onChange={(e) => setSearch(e.target.value)} />
          <button className="btn btn-outline btn-sm" onClick={() => menu.load(session.outletId)}>↻</button>
          <button className="btn btn-primary btn-sm" onClick={() => setEditing('new')}>+ Add item</button>
        </div>

        {selected.size > 0 && (
          <div className="mm-bulk">
            <span>{selected.size} selected</span>
            <button className="btn btn-outline btn-sm" disabled={busy}
              onClick={() => bulk(() => ({ isAvailable: true }), 'Marked available')}>Mark available</button>
            <button className="btn btn-outline btn-sm" disabled={busy}
              onClick={() => bulk(() => ({ isAvailable: false }), 'Marked unavailable')}>Mark unavailable</button>
            <button className="btn btn-outline btn-sm" disabled={busy} onClick={bulkDiscount}>Discount %</button>
            <button className="btn btn-outline btn-sm" onClick={() => setSelected(new Set())}>Clear</button>
          </div>
        )}

        <div className="mm-table">
          <div className="mm-row mm-row-head">
            <span />
            <span>Item name</span>
            <span>Short code</span>
            <span>Category</span>
            <span className="mm-r">Price (৳)</span>
            <span className="mm-c">Available</span>
            <span />
          </div>
          {menu.loading && menu.items.length === 0 && <div className="bo-loading">Loading menu…</div>}
          {!menu.loading && filtered.length === 0 && <div className="bo-muted mm-empty">No items.</div>}
          {filtered.map((it) => {
            const raw = it.raw;
            return (
              <div className="mm-row" key={raw.id}>
                <input type="checkbox" checked={selected.has(raw.id)} onChange={() => toggleSel(raw.id)} />
                <InlineField value={raw.nameEn || raw.name} onCommit={(v) => v.trim() && savePatch(raw, withName({}, v.trim()))} />
                <InlineField value={raw.shortCode != null ? String(raw.shortCode) : ''} type="number"
                  onCommit={(v) => savePatch(raw, { shortCode: v.trim() ? Number(v) : null })} />
                <InlineField value={raw.categoryEn || raw.category || ''} list="mm-cat-list"
                  onCommit={(v) => savePatch(raw, withCategory({}, v))} />
                <InlineField value={String(raw.price)} type="number" align="right"
                  onCommit={(v) => { const n = Number(v); if (Number.isFinite(n) && n >= 0) savePatch(raw, { price: n }); }} />
                <button className={`mm-avail ${raw.isAvailable ? 'on' : 'off'}`} disabled={busy}
                  onClick={() => savePatch(raw, { isAvailable: !raw.isAvailable })}>
                  {raw.isAvailable ? 'Available' : 'Off'}
                </button>
                <div className="mm-actions">
                  <button className="mm-icon" title="Edit" onClick={() => setEditing(raw)}>✎</button>
                  <button className="mm-icon danger" title="Delete" disabled={busy}
                    onClick={() => { if (window.confirm(`Delete "${raw.nameEn || raw.name}"?`)) void run(() => menu.deleteItem(session.outletId, raw.id), 'Deleted'); }}>🗑</button>
                </div>
              </div>
            );
          })}
        </div>
        <datalist id="mm-cat-list">{menu.categories.map((c) => <option key={c} value={c} />)}</datalist>
      </div>

      {editing && (
        <MenuItemModal
          existing={editing === 'new' ? null : editing}
          categories={menu.categories}
          onClose={() => setEditing(null)}
          onSave={saveFromModal}
        />
      )}
      {toast && <div className="bo-toast">{toast}</div>}
    </div>
  );
}
