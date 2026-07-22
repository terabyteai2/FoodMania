// Menu management (petpooja12 in-scope part) — category sidebar, search, inline-editable
// rows (name / short code / category / price / available), bulk actions, add/edit modal.
// No channel toggles, no multi-restaurant push. Writes are online-only for v1.

import { useMemo, useState } from 'react';
import { useSession } from '../state/session';
import { t } from '../i18n/strings';
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
    run(() => menu.saveItem(session.outletId, mergeMenuPayload(raw, patch)), t('mmg.saved', lang));

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
    const input = window.prompt(t('mmg.discountPrompt', lang));
    if (input === null) return;
    const pct = Number(input);
    if (!Number.isFinite(pct)) return;
    bulk((raw) => ({ tags: withDiscountTag(raw.tags, pct > 0 ? 'percent' : null, pct) }),
      pct > 0 ? t('mmg.appliedDiscount', lang).replace('{p}', String(pct)) : t('mmg.clearedDiscount', lang));
  };

  const saveFromModal = (payload: MenuItemPayload) => menu.saveItem(session.outletId, payload);

  return (
    <div className="mm-root">
      <aside className="mm-side">
        <button className={`mm-cat ${activeCat === 'all' ? 'active' : ''}`} onClick={() => setActiveCat('all')}>
          <span>{t('mmg.allItems', lang)}</span><span className="mm-cat-n">{menu.items.length}</span>
        </button>
        {menu.categories.map((c) => (
          <button key={c} className={`mm-cat ${activeCat === c ? 'active' : ''}`} onClick={() => setActiveCat(c)}>
            <span>{c}</span><span className="mm-cat-n">{counts[c] ?? 0}</span>
          </button>
        ))}
      </aside>

      <div className="mm-main">
        <div className="mm-head">
          <input className="input mm-search" placeholder={t('mmg.searchPlaceholder', lang)}
            value={search} onChange={(e) => setSearch(e.target.value)} />
          <button className="btn btn-outline btn-sm" onClick={() => menu.load(session.outletId)}>↻</button>
          <button className="btn btn-primary btn-sm" onClick={() => setEditing('new')}>+ {t('mmg.addItem', lang)}</button>
        </div>

        {selected.size > 0 && (
          <div className="mm-bulk">
            <span>{t('mmg.selected', lang).replace('{n}', String(selected.size))}</span>
            <button className="btn btn-outline btn-sm" disabled={busy}
              onClick={() => bulk(() => ({ isAvailable: true }), t('mmg.markAvailable', lang))}>{t('mmg.markAvailable', lang)}</button>
            <button className="btn btn-outline btn-sm" disabled={busy}
              onClick={() => bulk(() => ({ isAvailable: false }), t('mmg.markUnavailable', lang))}>{t('mmg.markUnavailable', lang)}</button>
            <button className="btn btn-outline btn-sm" disabled={busy} onClick={bulkDiscount}>{t('mmg.discount', lang)}</button>
            <button className="btn btn-outline btn-sm" onClick={() => setSelected(new Set())}>{t('mmg.clear', lang)}</button>
          </div>
        )}

        <div className="mm-table">
          <div className="mm-row mm-row-head">
            <span />
            <span>{t('mmg.itemName', lang)}</span>
            <span>{t('mmg.shortCode', lang)}</span>
            <span>{t('mmg.category', lang)}</span>
            <span className="mm-r">{t('mmg.price', lang)}</span>
            <span className="mm-c">{t('mmg.available', lang)}</span>
            <span />
          </div>
          {menu.loading && menu.items.length === 0 && <div className="bo-loading">{t('mmg.loading', lang)}</div>}
          {!menu.loading && filtered.length === 0 && <div className="bo-muted mm-empty">{t('mmg.noItems', lang)}</div>}
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
                  {raw.isAvailable ? t('mmg.availableYes', lang) : t('mmg.availableNo', lang)}
                </button>
                <div className="mm-actions">
                  <button className="mm-icon" title={t('mmg.edit', lang)} onClick={() => setEditing(raw)}>✎</button>
                  <button className="mm-icon danger" title={t('mmg.delete', lang)} disabled={busy}
                    onClick={() => { if (window.confirm(t('mmg.confirmDelete', lang).replace('{name}', raw.nameEn || raw.name))) void run(() => menu.deleteItem(session.outletId, raw.id), t('mmg.deleted', lang)); }}>🗑</button>
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
