// Analytics — Sales Breakdown + Item-wise report (petpooja10/18 aesthetic) fed by
// GET /analytics/summary. Includes the range-scoped Tax Summary (petpooja11 intent).

import { useEffect, useMemo, useState } from 'react';
import { api } from '../api/client';
import { useSession } from '../state/session';
import { usePos } from '../state/pos';
import { usePrinters } from '../print/printManager';
import { renderTaxSummary, type TicketContext } from '../print/ticketRenderer';
import { formatTk } from '../core/money';
import { downloadCsv } from '../core/csv';
import { StatCard } from '../components/StatCard';
import { PeriodPicker, type Period } from '../components/PeriodPicker';
import { AreaTrend } from '../components/charts/AreaTrend';
import { BarChart, type BarDatum } from '../components/charts/BarChart';
import { Donut, type DonutDatum } from '../components/charts/Donut';
import type { AnalyticsSummaryWire } from '../api/types';
import './backoffice.css';

const SERVICE_COLORS: Record<string, string> = {
  dineIn: 'var(--primary)', takeaway: 'var(--warning)', delivery: 'var(--success)',
};
const PALETTE = ['var(--primary)', 'var(--warning)', 'var(--success)', 'var(--secondary)', 'var(--favorite)', 'var(--line-strong)'];

function periodLabel(p: Period): string {
  if (p.range === 'week') return 'Last 7 days';
  if (p.range === 'month') return 'Last 30 days';
  if (p.range === 'custom') return `${p.start ?? '?'} – ${p.end ?? '?'}`;
  return 'Today';
}

export function Analytics() {
  const session = useSession((s) => s.session)!;
  const pos = usePos();
  const printers = usePrinters();

  const [period, setPeriod] = useState<Period>({ range: 'today' });
  const [data, setData] = useState<AnalyticsSummaryWire | null>(null);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);
  const [tab, setTab] = useState<'sales' | 'items'>('sales');
  const [trendMode, setTrendMode] = useState<'revenue' | 'orders'>('revenue');
  const [toast, setToast] = useState<string | null>(null);

  const load = () => {
    setLoading(true); setErr(null);
    api.fetchAnalyticsSummary(session.outletId, { range: period.range, start: period.start, end: period.end })
      .then(setData)
      .catch((e: unknown) => setErr(e instanceof Error ? e.message : String(e)))
      .finally(() => setLoading(false));
  };
  useEffect(load, [session.outletId, period.range, period.start, period.end]);

  const flash = (m: string) => { setToast(m); window.setTimeout(() => setToast(null), 2600); };

  const vatRate = pos.settings?.vatRatePercent ?? 0;
  const trendVals = useMemo(
    () => (data?.trend ?? []).map((t) => (trendMode === 'revenue' ? t.revenue : t.orders)),
    [data, trendMode],
  );
  const trendLabels = useMemo(() => (data?.trend ?? []).map((t) => t.date.slice(5)), [data]);
  const serviceBars: BarDatum[] = (data?.serviceWise ?? []).map((s) => ({
    label: s.label, value: s.valueBdt, color: SERVICE_COLORS[s.key] ?? 'var(--primary)',
  }));
  const collectionDonut: DonutDatum[] = (data?.collection ?? []).map((c, i) => ({
    label: c.label, value: c.valueBdt, color: PALETTE[i % PALETTE.length],
  }));

  const ticketCtx: TicketContext = {
    restaurantName: session.restaurantName, outletName: session.outletName, serverRole: session.role,
  };

  const printTax = async () => {
    if (!data) return;
    try {
      await printers.print('bill', renderTaxSummary(printers.paperDots('bill'), ticketCtx, {
        periodLabel: periodLabel(period),
        taxableBdt: data.salesSummary.netSales,
        vatRatePercent: vatRate,
        taxCollectedBdt: data.taxAndDuty,
        ordersCompleted: data.salesSummary.ordersCompleted,
        grossSalesBdt: data.salesSummary.grossSales,
        totalCollectionBdt: data.totalCollection,
      }));
      flash('Tax summary printed');
    } catch (e) {
      flash(e instanceof Error ? e.message : String(e));
    }
  };

  const downloadTaxCsv = () => {
    if (!data) return;
    downloadCsv(`tax_summary_${period.range}.csv`, [
      ['Metric', 'Value'],
      ['Period', periodLabel(period)],
      ['Orders completed', data.salesSummary.ordersCompleted],
      ['Gross sales', data.salesSummary.grossSales],
      ['Taxable amount (net sales)', data.salesSummary.netSales],
      ['VAT rate (%)', vatRate],
      ['Tax collected', data.taxAndDuty],
      ['Total collection', data.totalCollection],
    ]);
  };

  const downloadItemsCsv = () => {
    if (!data) return;
    const rows: (string | number)[][] = [['Category', 'Item', 'Units', 'Avg Unit Price', 'Total']];
    for (const cat of data.itemWise) {
      for (const it of cat.items) rows.push([cat.category, it.name, it.units, it.avgUnitPrice, it.totalPrice]);
    }
    downloadCsv(`item_sales_${period.range}.csv`, rows);
  };

  return (
    <div className="bo-root">
      <div className="bo-head">
        <div>
          <h2>Analytics</h2>
          <span className="bo-sub">{session.outletName} · {periodLabel(period)}</span>
        </div>
        <div className="bo-head-actions">
          <PeriodPicker value={period} onChange={setPeriod} />
          <button className="btn btn-outline btn-sm" onClick={load} disabled={loading}>↻</button>
          <button className="btn btn-outline btn-sm" onClick={downloadItemsCsv} disabled={!data}>⬇ CSV</button>
        </div>
      </div>

      {err && <div className="bo-err">{err}</div>}
      {loading && !data && <div className="bo-loading">Loading…</div>}

      <div className="bo-tabs">
        <button className={`bo-tab ${tab === 'sales' ? 'active' : ''}`} onClick={() => setTab('sales')}>Sales Breakdown</button>
        <button className={`bo-tab ${tab === 'items' ? 'active' : ''}`} onClick={() => setTab('items')}>Item-wise</button>
      </div>

      {data && tab === 'sales' && (
        <>
          <div className="bo-grid">
            <StatCard title="Orders Completed" value={String(data.salesSummary.ordersCompleted)} sub="in period" />
            <StatCard title="Gross Sales" value={formatTk(data.salesSummary.grossSales)} sub="before discount" />
            <StatCard title="Net Sales" value={formatTk(data.salesSummary.netSales)} sub="after discount" />
            <StatCard title="Discount & Commission" value={formatTk(data.discountAndCommission)} sub="given" />
            <StatCard title="Other Income" value={formatTk(data.otherIncome)} sub="service + delivery" />
            <StatCard title="Tax & Duty" value={formatTk(data.taxAndDuty)} sub="VAT collected" />
            <StatCard title="Total Collection" value={formatTk(data.totalCollection)} accent sub="all payments" />
            {data.dueReceivable != null && (
              <StatCard title="Due Receivable" value={formatTk(data.dueReceivable)} sub="pay later" />
            )}
          </div>

          <section className="card bo-panel">
            <div className="bo-chart-head">
              <h3>Revenue trend</h3>
              <div className="bo-toggle">
                <button className={trendMode === 'revenue' ? 'active' : ''} onClick={() => setTrendMode('revenue')}>Revenue</button>
                <button className={trendMode === 'orders' ? 'active' : ''} onClick={() => setTrendMode('orders')}>Orders</button>
              </div>
            </div>
            <AreaTrend values={trendVals} labels={trendLabels} height={170} />
          </section>

          <div className="bo-cols">
            <section className="card bo-panel">
              <h3>Service-wise sales</h3>
              <BarChart data={serviceBars} format={formatTk} />
            </section>

            <section className="card bo-panel">
              <h3>Collection summary</h3>
              {collectionDonut.length > 0
                ? <Donut data={collectionDonut} format={formatTk} centerValue={formatTk(data.totalCollection)} centerLabel="collected" />
                : <p className="bo-muted">No collections in this period.</p>}
            </section>

            <section className="card bo-panel">
              <h3>Profit estimation</h3>
              <div className="bo-line"><span>Net sales</span><span>{formatTk(data.profit.netSales)}</span></div>
              <div className="bo-line pos"><span>+ Service charge</span><span>{formatTk(data.profit.serviceCharge)}</span></div>
              <div className="bo-line pos"><span>+ Delivery charge</span><span>{formatTk(data.profit.deliveryCharge)}</span></div>
              <div className="bo-line neg"><span>− Preparation cost</span><span>{formatTk(data.profit.preparationCost)}</span></div>
              <div className="bo-line neg"><span>− Wastage</span><span>{formatTk(data.profit.wastage)}</span></div>
              <div className="bo-line neg"><span>− Payment fee</span><span>{formatTk(data.profit.paymentFee)}</span></div>
              <div className="bo-line neg"><span>− Taxes</span><span>{formatTk(data.profit.taxes)}</span></div>
              <div className="bo-line strong"><span>Gross profit</span><span>{formatTk(data.profit.grossProfit)}</span></div>
            </section>

            <section className="card bo-panel">
              <h3>Popular dishes</h3>
              <div className="bo-rank">
                {data.popularDishes.length === 0 && <p className="bo-muted">No items sold.</p>}
                {data.popularDishes.map((d, i) => (
                  <div className="bo-rank-row" key={i}>
                    <span className="bo-rank-name">{d.name}</span>
                    <span className="bo-rank-qty">{d.qty} sold</span>
                    <span className="bo-rank-val">{formatTk(d.salesBdt)}</span>
                  </div>
                ))}
              </div>
            </section>

            <section className="card bo-panel">
              <div className="bo-chart-head">
                <h3>Tax summary</h3>
                <div className="bo-head-actions">
                  <button className="btn btn-outline btn-sm" onClick={() => void printTax()}>🖨 Print</button>
                  <button className="btn btn-outline btn-sm" onClick={downloadTaxCsv}>⬇ CSV</button>
                </div>
              </div>
              <div className="bo-line"><span>Taxable amount (net sales)</span><span>{formatTk(data.salesSummary.netSales)}</span></div>
              <div className="bo-line"><span>VAT rate</span><span>{vatRate}%</span></div>
              <div className="bo-line strong"><span>Tax collected</span><span>{formatTk(data.taxAndDuty)}</span></div>
            </section>
          </div>
        </>
      )}

      {data && tab === 'items' && (
        <div className="bo-cols">
          {data.itemWise.length === 0 && <p className="bo-muted">No items sold in this period.</p>}
          {data.itemWise.map((cat) => (
            <section className="card bo-panel" key={cat.category}>
              <div className="bo-cat-head">
                <h3>{cat.category}</h3>
                <span className="bo-cat-meta">{cat.units} units · {formatTk(cat.totalPrice)}</span>
              </div>
              <div className="bo-rank">
                {cat.items.map((it) => (
                  <div className="bo-rank-row" key={it.menuItemId}>
                    <span className="bo-rank-name">{it.name}</span>
                    <span className="bo-rank-qty">{it.units} × {formatTk(it.avgUnitPrice)}</span>
                    <span className="bo-rank-val">{formatTk(it.totalPrice)}</span>
                  </div>
                ))}
              </div>
            </section>
          ))}
        </div>
      )}

      {toast && <div className="bo-toast">{toast}</div>}
    </div>
  );
}
