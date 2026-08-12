// Analytics — Sales Breakdown + Item-wise report (petpooja10/18 aesthetic) fed by
// GET /analytics/summary, layered with owner insights from GET /analytics
// (channels, dayparts, prev-period ghost, forecast, growth/margin). Includes the
// range-scoped Tax Summary (petpooja11 intent). The insights fetch is isolated:
// if it fails, the page still renders from the summary alone.

import { useEffect, useMemo, useState } from 'react';
import { api } from '../api/client';
import { useSession } from '../state/session';
import { t, type StringKey } from '../i18n/strings';
import { usePos } from '../state/pos';
import { usePrinters } from '../print/printManager';
import { renderTaxSummary, type TicketContext } from '../print/ticketRenderer';
import { formatTk } from '../core/money';
import { downloadCsv } from '../core/csv';
import { deltaPct, itemInsightById } from '../core/insights';
import { StatCard } from '../components/StatCard';
import { PeriodPicker, type Period } from '../components/PeriodPicker';
import { AreaTrend } from '../components/charts/AreaTrend';
import { BarChart, type BarDatum } from '../components/charts/BarChart';
import { Donut, type DonutDatum } from '../components/charts/Donut';
import { ItemDrilldownModal } from '../components/ItemDrilldownModal';
import type { AnalyticsInsightsWire, AnalyticsSummaryWire } from '../api/types';
import './backoffice.css';

const SERVICE_COLORS: Record<string, string> = {
  dineIn: 'var(--primary)', takeaway: 'var(--warning)', delivery: 'var(--success)',
};
const PALETTE = ['var(--primary)', 'var(--warning)', 'var(--success)', 'var(--secondary)', 'var(--favorite)', 'var(--line-strong)'];
const DAYPART_LABEL: Record<string, StringKey> = { lunch: 'an.dpLunch', dinner: 'an.dpDinner', late: 'an.dpLate' };

export function Analytics() {
  const session = useSession((s) => s.session)!;
  const lang = useSession((s) => s.lang);
  const pos = usePos();
  const printers = usePrinters();

  const [period, setPeriod] = useState<Period>({ range: 'today' });
  const [data, setData] = useState<AnalyticsSummaryWire | null>(null);
  const [insights, setInsights] = useState<AnalyticsInsightsWire | null>(null);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);
  const [tab, setTab] = useState<'sales' | 'items'>('sales');
  const [trendMode, setTrendMode] = useState<'revenue' | 'orders'>('revenue');
  const [drilldown, setDrilldown] = useState<{ id: string; name: string } | null>(null);
  const [toast, setToast] = useState<string | null>(null);

  const load = () => {
    setLoading(true); setErr(null);
    api.fetchAnalyticsSummary(session.outletId, { range: period.range, start: period.start, end: period.end })
      .then(setData)
      .catch((e: unknown) => setErr(e instanceof Error ? e.message : String(e)))
      .finally(() => setLoading(false));
    // Insights layer — failure hides the extra panels, never breaks the page.
    api.fetchAnalyticsInsights(session.outletId, { range: period.range, start: period.start, end: period.end })
      .then(setInsights)
      .catch(() => setInsights(null));
  };
  useEffect(load, [session.outletId, period.range, period.start, period.end]);

  const periodLabel = (p: Period): string => {
    if (p.range === 'week') return t('an.periodLabel7', lang);
    if (p.range === 'month') return t('an.periodLabel30', lang);
    if (p.range === 'custom') return `${p.start ?? '?'} – ${p.end ?? '?'}`;
    return t('an.periodLabel', lang);
  };
  const flash = (m: string) => { setToast(m); window.setTimeout(() => setToast(null), 2600); };

  const vatRate = pos.settings?.vatRatePercent ?? 0;
  const trendVals = useMemo(
    () => (data?.trend ?? []).map((t) => (trendMode === 'revenue' ? t.revenue : t.orders)),
    [data, trendMode],
  );
  const trendLabels = useMemo(() => (data?.trend ?? []).map((t) => t.date.slice(5)), [data]);
  // Ghost series — /analytics trends are in ৳ thousands; scale to ৳ and only
  // overlay in revenue mode when both series cover the same 7-day window.
  const trendGhost = useMemo(() => {
    if (trendMode !== 'revenue' || !insights) return undefined;
    if (insights.prevSalesTrend.length !== trendVals.length) return undefined;
    return insights.prevSalesTrend.map((v) => v * 1000);
  }, [insights, trendMode, trendVals.length]);
  const serviceBars: BarDatum[] = (data?.serviceWise ?? []).map((s) => ({
    label: s.label, value: s.valueBdt, color: SERVICE_COLORS[s.key] ?? 'var(--primary)',
  }));
  const collectionDonut: DonutDatum[] = (data?.collection ?? []).map((c, i) => ({
    label: c.label, value: c.valueBdt, color: PALETTE[i % PALETTE.length],
  }));
  const channelDonut: DonutDatum[] = (insights?.channels ?? []).map((c, i) => ({
    label: c.label, value: c.valueBdt, color: PALETTE[i % PALETTE.length],
  }));
  const channelTotal = channelDonut.reduce((s, d) => s + d.value, 0);
  const revDelta = insights ? deltaPct(insights.revenue, insights.prevRevenue) : null;
  const insightsById = useMemo(() => itemInsightById(insights?.products), [insights]);
  const forecast = insights?.advanced?.forecast ?? null;

  const ticketCtx: TicketContext = {
    restaurantName: session.restaurantName, outletName: session.outletName, serverRole: session.role,
  };

  const printTax = async () => {
    if (!data) return;
    try {
      await printers.print(renderTaxSummary(printers.paperDots(), ticketCtx, {
        periodLabel: periodLabel(period),
        taxableBdt: data.salesSummary.netSales,
        vatRatePercent: vatRate,
        taxCollectedBdt: data.taxAndDuty,
        ordersCompleted: data.salesSummary.ordersCompleted,
        grossSalesBdt: data.salesSummary.grossSales,
        totalCollectionBdt: data.totalCollection,
      }));
      flash(t('an.taxPrinted', lang));
    } catch (e) {
      flash(e instanceof Error ? e.message : String(e));
    }
  };

  const downloadTaxCsv = () => {
    if (!data) return;
    downloadCsv(`tax_summary_${period.range}.csv`, [
        [t('an.csvMetric', lang), t('an.csvValue', lang)],
        [t('an.csvPeriod', lang), periodLabel(period)],
        [t('an.csvOrdersCompleted', lang), data.salesSummary.ordersCompleted],
        [t('an.csvGrossSales', lang), data.salesSummary.grossSales],
        [t('an.csvTaxableAmount', lang), data.salesSummary.netSales],
        [t('an.csvVatRate', lang), vatRate],
        [t('an.csvTaxCollected', lang), data.taxAndDuty],
        [t('an.csvTotalCollection', lang), data.totalCollection],
    ]);
  };

  const downloadItemsCsv = () => {
    if (!data) return;
    const rows: (string | number)[][] = [[t('an.csvCat', lang), t('an.csvItem', lang), t('an.csvUnits', lang), t('an.csvAvgPrice', lang), t('an.csvTotal', lang)]];
    for (const cat of data.itemWise) {
      for (const it of cat.items) rows.push([cat.category, it.name, it.units, it.avgUnitPrice, it.totalPrice]);
    }
    downloadCsv(`item_sales_${period.range}.csv`, rows);
  };

  return (
    <div className="bo-root">
      <div className="bo-head">
        <div>
          <h2>{t('an.title', lang)}</h2>
          <span className="bo-sub">{session.outletName} · {periodLabel(period)}</span>
        </div>
        <div className="bo-head-actions">
          <PeriodPicker value={period} onChange={setPeriod} />
          <button className="btn btn-outline btn-sm" onClick={load} disabled={loading}>↻</button>
          <button className="btn btn-outline btn-sm" onClick={downloadItemsCsv} disabled={!data}>⬇ CSV</button>
        </div>
      </div>

      {err && <div className="bo-err">{err}</div>}
      {loading && !data && <div className="bo-loading">{t('an.loading', lang)}</div>}

      <div className="bo-tabs">
        <button className={`bo-tab ${tab === 'sales' ? 'active' : ''}`} onClick={() => setTab('sales')}>{t('an.salesBreakdown', lang)}</button>
        <button className={`bo-tab ${tab === 'items' ? 'active' : ''}`} onClick={() => setTab('items')}>{t('an.itemWise', lang)}</button>
      </div>

      {data && tab === 'sales' && (
        <>
          <div className="bo-grid">
            <StatCard title={t('an.ordersCompleted', lang)} value={String(data.salesSummary.ordersCompleted)} sub={t('an.inPeriod', lang)} />
            <StatCard title={t('an.grossSales', lang)} value={formatTk(data.salesSummary.grossSales)} sub={t('an.beforeDiscount', lang)} />
            <StatCard title={t('an.netSales', lang)} value={formatTk(data.salesSummary.netSales)} sub={t('an.afterDiscount', lang)} />
            <StatCard title={t('an.discountAndCommission', lang)} value={formatTk(data.discountAndCommission)} sub={t('an.given', lang)} />
            <StatCard title={t('an.otherIncome', lang)} value={formatTk(data.otherIncome)} sub={t('an.servicePlusDelivery', lang)} />
            <StatCard title={t('an.taxAndDuty', lang)} value={formatTk(data.taxAndDuty)} sub={t('an.vatCollected', lang)} />
            <StatCard
              title={t('an.totalCollection', lang)} value={formatTk(data.totalCollection)} accent
              sub={revDelta != null
                ? `${revDelta >= 0 ? '▲' : '▼'} ${Math.abs(revDelta)}% ${t('an.vsPrev', lang)}`
                : t('an.allPayments', lang)}
              subTone={revDelta != null ? (revDelta >= 0 ? 'up' : 'down') : ''}
            />
            {data.dueReceivable != null && (
              <StatCard title={t('an.dueReceivable', lang)} value={formatTk(data.dueReceivable)} sub={t('an.payLater', lang)} />
            )}
          </div>

          <section className="card bo-panel">
            <div className="bo-chart-head">
              <h3>{t('an.revenueTrend', lang)}</h3>
              <div className="bo-head-actions">
                {trendGhost && (
                  <div className="bo-legend">
                    <span className="bo-legend-item"><span className="bo-legend-swatch" />{t('an.revenue', lang)}</span>
                    <span className="bo-legend-item"><span className="bo-legend-swatch ghost" />{t('an.prevPeriod', lang)}</span>
                  </div>
                )}
                <div className="bo-toggle">
                  <button className={trendMode === 'revenue' ? 'active' : ''} onClick={() => setTrendMode('revenue')}>{t('an.revenue', lang)}</button>
                  <button className={trendMode === 'orders' ? 'active' : ''} onClick={() => setTrendMode('orders')}>{t('an.ordersCompleted', lang)}</button>
                </div>
              </div>
            </div>
            <AreaTrend values={trendVals} compare={trendGhost} labels={trendLabels} height={170} />
          </section>

          <div className="bo-cols">
            <section className="card bo-panel">
              <h3>{t('an.serviceWiseSales', lang)}</h3>
              <BarChart data={serviceBars} format={formatTk} />
            </section>

            <section className="card bo-panel">
              <h3>{t('an.collectionSummary', lang)}</h3>
              {collectionDonut.length > 0
                ? <Donut data={collectionDonut} format={formatTk} centerValue={formatTk(data.totalCollection)} centerLabel={t('an.collected', lang)} />
                : <p className="bo-muted">{t('an.noCollections', lang)}</p>}
            </section>

            {insights && channelDonut.length > 0 && (
              <section className="card bo-panel">
                <h3>{t('an.channels', lang)}</h3>
                <Donut data={channelDonut} format={formatTk} centerValue={formatTk(channelTotal)} centerLabel={t('an.revenue', lang)} />
              </section>
            )}

            {insights && insights.orders > 0 && (
              <section className="card bo-panel">
                <h3>{t('an.dayparts', lang)}</h3>
                {insights.dayparts.map((d) => (
                  <div className="bo-line" key={d.key}>
                    <span>{t(DAYPART_LABEL[d.key] ?? 'an.dayparts', lang)} <span className="bo-line-sub">{d.time}</span></span>
                    <span>
                      {Math.round(d.share * 100)}% · {t('de.orders', lang).replace('{n}', String(d.orders))}
                      {d.marginPct != null && ` · ${d.marginPct}% ${t('an.margin', lang)}`}
                    </span>
                  </div>
                ))}
              </section>
            )}

            {forecast && (
              <section className="card bo-panel">
                <h3>{t('an.forecast', lang)}</h3>
                <div className="bo-line"><span>{t('an.projected', lang)}</span><span>{formatTk(forecast.projected)}</span></div>
                <div className="bo-line"><span>{t('an.target', lang)}</span><span>{forecast.target != null ? formatTk(forecast.target) : '—'}</span></div>
                {forecast.pace != null && (
                  <div className={`bo-line strong ${forecast.pace >= 1 ? 'pos' : 'neg'}`}>
                    <span>{t('an.pace', lang)}</span>
                    <span>{t(forecast.pace >= 1 ? 'an.onTrack' : 'an.behind', lang).replace('{p}', String(forecast.pace))}</span>
                  </div>
                )}
              </section>
            )}

            <section className="card bo-panel">
              <h3>{t('an.profitEstimation', lang)}</h3>
              <div className="bo-line"><span>{t('an.netSalesLine', lang)}</span><span>{formatTk(data.profit.netSales)}</span></div>
              <div className="bo-line pos"><span>{t('an.plusService', lang)}</span><span>{formatTk(data.profit.serviceCharge)}</span></div>
              <div className="bo-line pos"><span>{t('an.plusDelivery', lang)}</span><span>{formatTk(data.profit.deliveryCharge)}</span></div>
              <div className="bo-line neg"><span>{t('an.minusPrep', lang)}</span><span>{formatTk(data.profit.preparationCost)}</span></div>
              <div className="bo-line neg"><span>{t('an.minusWastage', lang)}</span><span>{formatTk(data.profit.wastage)}</span></div>
              <div className="bo-line neg"><span>{t('an.minusPaymentFee', lang)}</span><span>{formatTk(data.profit.paymentFee)}</span></div>
              <div className="bo-line neg"><span>{t('an.minusTaxes', lang)}</span><span>{formatTk(data.profit.taxes)}</span></div>
              <div className="bo-line strong"><span>{t('an.grossProfit', lang)}</span><span>{formatTk(data.profit.grossProfit)}</span></div>
            </section>

            <section className="card bo-panel">
              <h3>{t('an.popularDishes', lang)}</h3>
              <div className="bo-rank">
                {data.popularDishes.length === 0 && <p className="bo-muted">{t('an.noItemsSold', lang)}</p>}
                {data.popularDishes.map((d, i) => (
                  <div className="bo-rank-row" key={i}>
                    <span className="bo-rank-name">{d.name}</span>
                    <span className="bo-rank-qty">{t('dash.sold', lang).replace('{n}', String(d.qty))}</span>
                    <span className="bo-rank-val">{formatTk(d.salesBdt)}</span>
                  </div>
                ))}
              </div>
            </section>

            <section className="card bo-panel">
              <div className="bo-chart-head">
                <h3>{t('an.taxSummary', lang)}</h3>
                <div className="bo-head-actions">
                  <button className="btn btn-outline btn-sm" onClick={() => void printTax()}>🖨 {t('an.print', lang)}</button>
                  <button className="btn btn-outline btn-sm" onClick={downloadTaxCsv}>⬇ {t('an.csv', lang)}</button>
                </div>
              </div>
              <div className="bo-line"><span>{t('an.taxableAmount', lang)}</span><span>{formatTk(data.salesSummary.netSales)}</span></div>
              <div className="bo-line"><span>{t('an.vatRate', lang)}</span><span>{vatRate}%</span></div>
              <div className="bo-line strong"><span>{t('an.taxCollected', lang)}</span><span>{formatTk(data.taxAndDuty)}</span></div>
            </section>
          </div>
        </>
      )}

      {data && tab === 'items' && (
        <div className="bo-cols">
          {data.itemWise.length === 0 && <p className="bo-muted">{t('an.noItemsPeriod', lang)}</p>}
          {data.itemWise.map((cat) => (
            <section className="card bo-panel" key={cat.category}>
              <div className="bo-cat-head">
                <h3>{cat.category}</h3>
                <span className="bo-cat-meta">{cat.units} {t('an.units', lang)} · {formatTk(cat.totalPrice)}</span>
              </div>
              <div className="bo-rank">
                {cat.items.map((it) => {
                  const insight = insightsById.get(it.menuItemId);
                  return (
                    <div
                      className="bo-rank-row clickable" key={it.menuItemId}
                      onClick={() => setDrilldown({ id: it.menuItemId, name: it.name })}
                    >
                      <span className="bo-rank-name">
                        {it.name}
                        {insight && (
                          <span className="bo-badges">
                            {insight.growthPct !== 0 && (
                              <span className={`bo-badge ${insight.growthPct > 0 ? 'up' : 'down'}`}>
                                {insight.growthPct > 0 ? '▲' : '▼'} {Math.abs(insight.growthPct)}%
                              </span>
                            )}
                            {insight.marginPct != null && (
                              <span className="bo-badge">{insight.marginPct}% {t('an.margin', lang)}</span>
                            )}
                          </span>
                        )}
                      </span>
                      <span className="bo-rank-qty">{it.units} × {formatTk(it.avgUnitPrice)}</span>
                      <span className="bo-rank-val">{formatTk(it.totalPrice)}</span>
                    </div>
                  );
                })}
              </div>
            </section>
          ))}
        </div>
      )}

      {drilldown && (
        <ItemDrilldownModal
          outletId={session.outletId}
          menuItemId={drilldown.id}
          fallbackName={drilldown.name}
          period={period}
          onClose={() => setDrilldown(null)}
        />
      )}

      {toast && <div className="bo-toast">{toast}</div>}
    </div>
  );
}
