// Reports hub — order buckets (Success / Cancelled / Complimentary + payments) from
// GET /reports/order-buckets, and an item Performance report from GET /reports/performance.

import { useEffect, useState } from 'react';
import { api } from '../api/client';
import { useSession } from '../state/session';
import { t } from '../i18n/strings';
import { formatTk } from '../core/money';
import { downloadCsv } from '../core/csv';
import { StatCard } from '../components/StatCard';
import { PeriodPicker, type Period } from '../components/PeriodPicker';
import type { OrderBucketsWire, PerformanceReportWire } from '../api/types';
import './backoffice.css';

const WINDOWS = [7, 30, 90];

export function Reports() {
  const session = useSession((s) => s.session)!;
  const lang = useSession((s) => s.lang);

  const [period, setPeriod] = useState<Period>({ range: 'today' });
  const [buckets, setBuckets] = useState<OrderBucketsWire | null>(null);
  const [perf, setPerf] = useState<PerformanceReportWire | null>(null);
  const [days, setDays] = useState(30);
  const [err, setErr] = useState<string | null>(null);

  const loadBuckets = () => {
    api.fetchOrderBuckets(session.outletId, period.range, period.start, period.end)
      .then(setBuckets)
      .catch((e: unknown) => setErr(e instanceof Error ? e.message : String(e)));
  };
  const loadPerf = () => {
    api.fetchPerformanceReport(session.outletId, { days })
      .then(setPerf)
      .catch((e: unknown) => setErr(e instanceof Error ? e.message : String(e)));
  };
  useEffect(loadBuckets, [session.outletId, period.range, period.start, period.end]);
  useEffect(loadPerf, [session.outletId, days]);

  const paymentsTotal = (buckets?.payments ?? []).reduce((s, p) => s + p.totalBdt, 0);

  const downloadPerfCsv = () => {
    if (!perf) return;
    const rows: (string | number)[][] = [[t('an.csvItem', lang), t('an.csvCat', lang), t('rpt.csvQty', lang), t('rpt.csvSales', lang), t('an.csvAvgPrice', lang)]];
    for (const it of perf.items) rows.push([it.name, it.category, it.qty, it.salesBdt, it.avgUnitPrice]);
    downloadCsv(`performance_${days}d.csv`, rows);
  };

  return (
    <div className="bo-root">
      <div className="bo-head">
        <div>
          <h2>{t('rpt.title', lang)}</h2>
          <span className="bo-sub">{session.outletName}</span>
        </div>
        <div className="bo-head-actions">
          <PeriodPicker value={period} onChange={setPeriod} />
        </div>
      </div>

      {err && <div className="bo-err">{err}</div>}

      {buckets && (
        <div className="bo-grid">
          {buckets.buckets.map((b) => (
            <StatCard
              key={b.key}
              title={b.label}
              value={String(b.count)}
              sub={formatTk(b.totalBdt)}
              accent={b.key === 'success'}
            />
          ))}
          <StatCard title={t('rpt.payments', lang)} value={formatTk(paymentsTotal)} sub={t('rpt.methods', lang).replace('{n}', String(buckets.payments.length))} />
        </div>
      )}

      {buckets && buckets.payments.length > 0 && (
        <section className="card bo-panel">
          <h3>{t('rpt.paymentInfo', lang)}</h3>
          {buckets.payments.map((p) => (
            <div className="bo-line" key={p.key}><span>{p.label}</span><span>{formatTk(p.totalBdt)}</span></div>
          ))}
        </section>
      )}

      <section className="card bo-panel">
        <div className="bo-chart-head">
          <h3>{t('rpt.performanceReport', lang)}</h3>
          <div className="bo-head-actions">
            <div className="bo-toggle">
              {WINDOWS.map((w) => (
                <button key={w} className={days === w ? 'active' : ''} onClick={() => setDays(w)}>{w}{t('rpt.daySuffix', lang)}</button>
              ))}
            </div>
            <button className="btn btn-outline btn-sm" onClick={downloadPerfCsv} disabled={!perf}>⬇ {t('an.csv', lang)}</button>
          </div>
        </div>
        <div className="bo-rank">
          {perf && perf.items.length === 0 && <p className="bo-muted">{t('rpt.noSalesInDays', lang).replace('{n}', String(days))}</p>}
          {(perf?.items ?? []).slice(0, 50).map((it) => (
            <div className="bo-rank-row" key={it.menuItemId}>
              <span className="bo-rank-name">{it.name}<span className="bo-line-sub"> · {it.category}</span></span>
              <span className="bo-rank-qty">{t('dash.sold', lang).replace('{n}', String(it.qty))}</span>
              <span className="bo-rank-val">{formatTk(it.salesBdt)}</span>
            </div>
          ))}
        </div>
      </section>
    </div>
  );
}
