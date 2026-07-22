// Inventory (petpooja21/22/23, in-scope subset) — owner-only. Stock hub (summary +
// raw-material CRUD + stock-in/usage/waste/count) and a Daily Report (variance,
// reorder suggestions, stock flow, revenue split, top sellers). No PO approvals,
// no receipt scan, no marketplace — per Phase B scope.

import { useEffect, useMemo, useState } from 'react';
import { useSession } from '../state/session';
import { t } from '../i18n/strings';
import { useInventory } from '../state/inventory';
import { InventoryItemModal } from '../components/InventoryItemModal';
import { StockAdjustModal, type AdjustMode } from '../components/StockAdjustModal';
import { PeriodPicker, type Period } from '../components/PeriodPicker';
import { Donut, type DonutDatum } from '../components/charts/Donut';
import { formatTk } from '../core/money';
import { inventoryDisplayName, netToday, todayBdtDate } from '../core/inventory';
import type { InventoryDailyReportWire, InventorySummaryItemWire } from '../api/types';
import './backoffice.css';
import './menu-manage.css'; // shared modal form classes (.mm-form / .mm-form-row / .mm-area)
import './inventory.css';

const SPLIT_COLORS: Record<string, string> = {
  cash: 'var(--success)', card: 'var(--primary)', online: 'var(--secondary)',
};

export function Inventory() {
  const session = useSession((s) => s.session)!;
  const lang = useSession((s) => s.lang);
  const bn = lang === 'bn';
  const inv = useInventory();

  const [tab, setTab] = useState<'stock' | 'report'>('stock');
  const [period, setPeriod] = useState<Period>({ range: 'today' });
  const [activeCat, setActiveCat] = useState('all');
  const [editing, setEditing] = useState<InventorySummaryItemWire | 'new' | null>(null);
  const [adjust, setAdjust] = useState<{ item: InventorySummaryItemWire; mode: AdjustMode } | null>(null);
  const [reportDate, setReportDate] = useState(todayBdtDate());
  const [toast, setToast] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const flash = (m: string) => { setToast(m); window.setTimeout(() => setToast(null), 2600); };

  useEffect(() => { void inv.loadStock(session.outletId, period); }, [session.outletId, period]);
  useEffect(() => {
    if (tab === 'report') void inv.loadReport(session.outletId, reportDate);
  }, [tab, session.outletId, reportDate]);

  const summary = inv.summary;
  const filtered = useMemo(() => {
    const items = summary?.items ?? [];
    return activeCat === 'all' ? items : items.filter((i) => i.category === activeCat);
  }, [summary, activeCat]);

  const run = async (fn: () => Promise<void>, ok: string) => {
    setBusy(true);
    try { await fn(); flash(ok); }
    catch (e) { flash(e instanceof Error ? e.message : String(e)); }
    finally { setBusy(false); }
  };

  const editItem = (s: InventorySummaryItemWire) => {
    const raw = inv.itemsById[s.id];
    if (!raw) { flash(t('inv.notLoaded', lang)); return; }
    setEditing(s);
  };

  const editingRaw = editing && editing !== 'new' ? inv.itemsById[editing.id] ?? null : null;

  return (
    <div className="bo-root">
      <div className="bo-head">
        <div>
          <h2>{t('inv.title', lang)}</h2>
          <span className="bo-sub">{session.outletName} · {t('inv.subtitle', lang)}</span>
        </div>
        <div className="bo-head-actions">
          <div className="bo-tabs">
            <button className={`bo-tab ${tab === 'stock' ? 'active' : ''}`} onClick={() => setTab('stock')}>{t('inv.stockTab', lang)}</button>
            <button className={`bo-tab ${tab === 'report' ? 'active' : ''}`} onClick={() => setTab('report')}>{t('inv.reportTab', lang)}</button>
          </div>
        </div>
      </div>

      {inv.error && <div className="bo-err">{inv.error}</div>}

      {tab === 'stock' ? (
        <>
          <div className="bo-head-actions inv-toolbar">
            <PeriodPicker value={period} onChange={setPeriod} />
            <div className="inv-toolbar-right">
              <button className="btn btn-outline btn-sm" onClick={() => void inv.loadStock(session.outletId, period)} disabled={inv.loading}>↻</button>
              <button className="btn btn-primary btn-sm" onClick={() => setEditing('new')}>+ {t('inv.addMaterial', lang)}</button>
            </div>
          </div>

          <div className="bo-grid">
            <div className="card bo-card accent">
              <span className="bo-card-title">{t('inv.stockValue', lang)}</span>
              <span className="bo-card-value">{formatTk(summary?.stockValueBdt ?? 0)}</span>
              <span className="bo-card-sub">{t('inv.onHandAtCost', lang)}</span>
            </div>
            <div className="card bo-card">
              <span className="bo-card-title">{t('inv.alerts', lang)}</span>
              <span className="bo-card-value">{summary?.alerts ?? 0}</span>
              <span className="bo-card-sub">{t('inv.lowOutVariance', lang)}</span>
            </div>
            <div className="card bo-card">
              <span className="bo-card-title">{t('inv.varianceToday', lang)}</span>
              <span className="bo-card-value">{formatTk(summary?.varianceTodayBdt ?? 0)}</span>
              <span className="bo-card-sub">{t('inv.itemsCountedOff', lang).replace('{n}', String(summary?.varianceItemCount ?? 0))}</span>
            </div>
            <div className="card bo-card">
              <span className="bo-card-title">{t('inv.materials', lang)}</span>
              <span className="bo-card-value">{summary?.items.length ?? 0}</span>
              <span className="bo-card-sub">{t('inv.tracked', lang)}</span>
            </div>
          </div>

          {(summary?.categories.length ?? 0) > 0 && (
            <div className="inv-cats">
              {summary!.categories.map((c) => (
                <button key={c.key} className={`inv-cat ${activeCat === c.key ? 'active' : ''}`}
                  onClick={() => setActiveCat(c.key)}>
                  {bn ? c.labelBn : c.labelEn}<span className="inv-cat-n">{c.count}</span>
                </button>
              ))}
            </div>
          )}

          <div className="card inv-table">
            <div className="inv-row inv-row-head">
              <span>{t('inv.material', lang)}</span>
              <span className="inv-r">{t('inv.in', lang)}</span>
              <span className="inv-r">{t('inv.out', lang)}</span>
              <span className="inv-r">{t('inv.net', lang)}</span>
              <span className="inv-r">{t('inv.onHand', lang)}</span>
              <span className="inv-r">{t('inv.spend', lang)}</span>
              <span className="inv-actions-h">{t('inv.actions', lang)}</span>
            </div>
            {inv.loading && !summary && <div className="bo-loading">{t('inv.loading', lang)}</div>}
            {summary && filtered.length === 0 && (
              <div className="bo-muted inv-empty">{t('inv.noMaterials', lang)}</div>
            )}
            {filtered.map((it) => {
              const low = it.varianceStatus === 'low' || it.varianceStatus === 'out';
              return (
                <div className="inv-row" key={it.id}>
                  <span className="inv-name">
                    <span className={`inv-dot inv-dot-${it.varianceStatus}`} title={it.varianceStatus} />
                    <span className="inv-name-text">{inventoryDisplayName(it, bn)}</span>
                    <span className="inv-unit">{it.unit}</span>
                  </span>
                  <span className="inv-r">{it.todayIn || '—'}</span>
                  <span className="inv-r">{it.todayOut || '—'}</span>
                  <span className="inv-r">{netToday(it) || '—'}</span>
                  <span className={`inv-r inv-onhand ${low ? 'low' : ''}`}>
                    {it.onHand}
                    {it.minThreshold > 0 && <span className="inv-min">{t('inv.min', lang).replace('{n}', String(it.minThreshold))}</span>}
                  </span>
                  <span className="inv-r">{it.todaySpendBdt ? formatTk(it.todaySpendBdt) : '—'}</span>
                  <div className="inv-actions">
                    <button className="inv-icon" title={t('inv.stockIn', lang)} disabled={busy}
                      onClick={() => setAdjust({ item: it, mode: 'restock' })}>↑</button>
                    <button className="inv-icon" title={t('inv.count', lang)} disabled={busy}
                      onClick={() => setAdjust({ item: it, mode: 'count' })}>▣</button>
                    <button className="inv-icon" title={t('mmg.edit', lang)} onClick={() => editItem(it)}>✎</button>
                    <button className="inv-icon danger" title={t('mmg.delete', lang)} disabled={busy}
                      onClick={() => { if (window.confirm(t('inv.confirmDelete', lang).replace('{name}', inventoryDisplayName(it, bn)))) void run(() => inv.deleteItem(session.outletId, it.id), t('inv.deleted', lang)); }}>🗑</button>
                  </div>
                </div>
              );
            })}
          </div>
        </>
      ) : (
        <ReportTab
          date={reportDate}
          onDate={setReportDate}
          loading={inv.reportLoading}
          report={inv.report}
          reload={() => void inv.loadReport(session.outletId, reportDate)}
        />
      )}

      {editing && (
        <InventoryItemModal
          existing={editing === 'new' ? null : editingRaw}
          categories={inv.items.map((i) => i.category).filter((c, i, a) => c && a.indexOf(c) === i)}
          suppliers={inv.suppliers}
          onClose={() => setEditing(null)}
          onSave={(p) => inv.saveItem(session.outletId, p)}
        />
      )}
      {adjust && (
        <StockAdjustModal
          item={{ id: adjust.item.id, name: inventoryDisplayName(adjust.item, bn), unit: adjust.item.unit, onHand: adjust.item.onHand }}
          mode={adjust.mode}
          suppliers={inv.suppliers}
          onClose={() => setAdjust(null)}
          onAdjust={(p) => inv.adjust(session.outletId, p)}
          onCount={(p) => inv.count(session.outletId, p)}
        />
      )}
      {toast && <div className="bo-toast">{toast}</div>}
    </div>
  );
}

function ReportTab({
  date, onDate, loading, report, reload,
}: {
  date: string;
  onDate: (d: string) => void;
  loading: boolean;
  report: InventoryDailyReportWire | null;
  reload: () => void;
}) {
  const lang = useSession((s) => s.lang);
  const split: DonutDatum[] = (report?.revenueSplit ?? []).map((r) => ({
    label: r.label, value: r.valueBdt, color: SPLIT_COLORS[r.key] ?? 'var(--muted)',
  }));
  const revenueTotal = (report?.revenueSplit ?? []).reduce((s, r) => s + r.valueBdt, 0);

  return (
    <>
      <div className="bo-head-actions inv-toolbar">
        <label className="field inv-date"><span>{t('inv.businessDate', lang)}</span>
          <input className="input" type="date" value={date} max={todayBdtDate()} onChange={(e) => onDate(e.target.value)} />
        </label>
        <button className="btn btn-outline btn-sm" onClick={reload} disabled={loading}>↻</button>
      </div>

      {loading && !report && <div className="bo-loading">{t('inv.loadingReport', lang)}</div>}

      {report && (
        <>
          {report.headlineEn && <div className="inv-headline">{report.headlineEn}</div>}

          <div className="bo-grid">
            <div className="card bo-card accent">
              <span className="bo-card-title">{t('inv.unexplainedVariance', lang)}</span>
              <span className="bo-card-value">{formatTk(report.unexplainedVarianceBdt)}</span>
              <span className="bo-card-sub">{t('inv.varianceItems', lang).replace('{n}', String(report.varianceItemCount))}</span>
            </div>
            <div className="card bo-card">
              <span className="bo-card-title">{t('inv.stockInCard', lang)}</span>
              <span className="bo-card-value">{report.stockFlow.inQty}</span>
              <span className="bo-card-sub">{t('inv.unitsReceived', lang)}</span>
            </div>
            <div className="card bo-card">
              <span className="bo-card-title">{t('inv.stockOut', lang)}</span>
              <span className="bo-card-value">{report.stockFlow.outQty}</span>
              <span className="bo-card-sub">{t('inv.usedWasted', lang)}</span>
            </div>
            <div className="card bo-card">
              <span className="bo-card-title">{t('inv.purchaseSpend', lang)}</span>
              <span className="bo-card-value">{formatTk(report.stockFlow.spendBdt)}</span>
              <span className="bo-card-sub">{t('inv.onStockIn', lang)}</span>
            </div>
          </div>

          <div className="bo-cols">
            <section className="card bo-panel">
              <h3>{t('inv.revenueSplit', lang)}</h3>
              <Donut data={split} format={formatTk} centerValue={formatTk(revenueTotal)} centerLabel={t('inv.sales', lang)}
                emptyLabel={t('inv.noSalesDay', lang)} />
            </section>

            <section className="card bo-panel">
              <h3>{t('inv.topSellers', lang)}</h3>
              <div className="bo-rank">
                {(report.topSellers ?? []).map((t, i) => (
                  <div className="bo-rank-row" key={i}>
                    <span className="bo-rank-name">{t.name}</span>
                    <span className="bo-rank-qty">{t.qty}×</span>
                    <span className="bo-rank-val">{formatTk(t.salesBdt)}</span>
                  </div>
                ))}
                {(report.topSellers?.length ?? 0) === 0 && <p className="bo-muted">{t('inv.noSalesRecorded', lang)}</p>}
              </div>
            </section>

            {report.reorderSuggestions.length > 0 && (
              <section className="card bo-panel">
                <h3>{t('inv.reorderBeforeNoon', lang)}</h3>
                <div className="inv-reorder">
                  {report.reorderSuggestions.map((r) => (
                    <div className="inv-reorder-row" key={r.itemId}>
                      <span className="inv-reorder-name">{r.nameEn}</span>
                      <span className="inv-reorder-qty">{t('inv.orderQty', lang).replace('{n}', String(r.qtyToOrder)).replace('{u}', r.unit)}</span>
                    </div>
                  ))}
                </div>
              </section>
            )}
          </div>

          <section className="card bo-panel bo-panel-wide">
            <h3>{t('inv.varianceBreakdown', lang)}</h3>
            {report.breakdown.length === 0 ? (
              <p className="bo-muted">{t('inv.noVariance', lang)}</p>
            ) : (
              <div className="inv-var-table">
                <div className="inv-var-row inv-var-head">
                  <span>{t('inv.material', lang)}</span>
                  <span className="inv-r">{t('inv.expected', lang)}</span>
                  <span className="inv-r">{t('inv.actual', lang)}</span>
                  <span className="inv-r">{t('inv.varianceCol', lang)}</span>
                  <span className="inv-r">৳</span>
                  <span>{t('inv.noteCol', lang)}</span>
                </div>
                {report.breakdown.map((b) => (
                  <div className="inv-var-row" key={b.itemId}>
                    <span className="inv-name-text">{b.nameEn}</span>
                    <span className="inv-r">{b.expectedQty} {b.unit}</span>
                    <span className="inv-r">{b.actualQty} {b.unit}</span>
                    <span className={`inv-r ${b.varianceQty < 0 ? 'neg' : 'pos'}`}>{b.varianceQty > 0 ? '+' : ''}{b.varianceQty} {b.unit}</span>
                    <span className={`inv-r ${b.varianceBdt < 0 ? 'neg' : 'pos'}`}>{formatTk(b.varianceBdt)}</span>
                    <span className="inv-var-note">{b.recurringWeeks >= 2 ? `⚠ ${t('inv.recurringWeeks', lang).replace('{n}', String(b.recurringWeeks))}` : b.noteEn}</span>
                  </div>
                ))}
              </div>
            )}
          </section>
        </>
      )}
    </>
  );
}
