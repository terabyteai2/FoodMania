// Dashboard — live "money-first + right now" tower (petpooja18/19/20 aesthetic),
// fed by GET /dashboard/summary. Today-scoped (the dashboard is a live view).

import { useEffect, useState } from 'react';
import { api } from '../api/client';
import { useSession } from '../state/session';
import { t } from '../i18n/strings';
import { formatTk } from '../core/money';
import { StatCard } from '../components/StatCard';
import { Sparkline } from '../components/charts/Sparkline';
import { Donut, type DonutDatum } from '../components/charts/Donut';
import type { DashboardSummaryWire } from '../api/types';
import './backoffice.css';

const MIX_COLORS: Record<string, string> = {
  dineIn: 'var(--primary)', takeaway: 'var(--warning)', delivery: 'var(--success)',
};

export function Dashboard() {
  const session = useSession((s) => s.session)!;
  const lang = useSession((s) => s.lang);
  const [data, setData] = useState<DashboardSummaryWire | null>(null);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);

  const load = () => {
    setLoading(true); setErr(null);
    api.fetchDashboardSummary(session.outletId)
      .then(setData)
      .catch((e: unknown) => setErr(e instanceof Error ? e.message : String(e)))
      .finally(() => setLoading(false));
  };
  useEffect(load, [session.outletId]);

  const mf = data?.moneyFirst;
  const rn = data?.rightNow;
  const deltaUp = (mf?.deltaPct ?? 0) >= 0;
  const mixData: DonutDatum[] = (mf?.serviceMix ?? []).map((s) => ({
    label: s.label, value: s.valueBdt, color: MIX_COLORS[s.key] ?? 'var(--line-strong)',
  }));

  return (
    <div className="bo-root">
      <div className="bo-head">
        <div>
          <h2>{t('dash.title', lang)}</h2>
          <span className="bo-sub">{session.outletName} · {t('dash.today', lang)}</span>
        </div>
        <div className="bo-head-actions">
          <button className="btn btn-outline btn-sm" onClick={load} disabled={loading}>↻ {t('dash.refresh', lang)}</button>
        </div>
      </div>

      {err && <div className="bo-err">{err}</div>}
      {loading && !data && <div className="bo-loading">{t('dash.loading', lang)}</div>}

      {mf && (
        <>
          <div className="bo-grid">
            <StatCard
              title={t('dash.earnedToday', lang)} accent value={formatTk(mf.earnedToday)}
              sub={`${deltaUp ? '▲' : '▼'} ${Math.abs(mf.deltaPct)}% ${t('dash.vsYesterday', lang)}`}
              subTone={deltaUp ? 'up' : 'down'}
            />
            <StatCard title={t('dash.orders', lang)} value={String(mf.kpis.orders)} sub={t('dash.openOrders', lang).replace('{n}', String(mf.kpis.openOrders))} />
            <StatCard title={t('dash.avgTicket', lang)} value={formatTk(mf.kpis.avgTicket)} sub={t('dash.perOrder', lang)} />
            <StatCard
              title={t('dash.profit', lang)} value={mf.kpis.profitPct != null ? `${mf.kpis.profitPct}%` : '—'}
              sub={t('dash.estMargin', lang)}
            />
          </div>

          <div className="bo-cols">
            <section className="card bo-panel">
              <h3>{t('dash.last7days', lang)}</h3>
              <Sparkline values={mf.sparkline} width={260} height={64} />
              <span className="bo-muted">{t('dash.earnedYesterday', lang)} {formatTk(mf.earnedYesterday)} · {mf.deltaNote}</span>
            </section>

            <section className="card bo-panel">
              <h3>{t('dash.serviceMix', lang)}</h3>
              <Donut data={mixData} format={formatTk} centerValue={formatTk(mf.earnedToday)} centerLabel={t('dash.today', lang)} />
            </section>

            <section className="card bo-panel">
              <h3>{t('dash.topMovers', lang)}</h3>
              <div className="bo-rank">
                {mf.topMovers.length === 0 && <p className="bo-muted">{t('dash.noSalesYet', lang)}</p>}
                {mf.topMovers.map((m) => (
                  <div className="bo-rank-row" key={m.menuItemId}>
                    <span className="bo-rank-name">{m.nameEn || m.nameBn || t('dash.item', lang)}</span>
                    <span className="bo-rank-qty">{t('dash.sold', lang).replace('{n}', String(m.qty))}</span>
                    <span className="bo-rank-val">{formatTk(m.salesBdt)}</span>
                  </div>
                ))}
              </div>
            </section>
          </div>
        </>
      )}

      {rn && (
        <div className="bo-cols">
          <section className="card bo-panel">
            <h3>{t('dash.rightNow', lang)}</h3>
            <div className="bo-line"><span>{t('dash.tablesSeated', lang)}</span><span>{rn.tablesSeated}{rn.tablesTotal ? ` / ${rn.tablesTotal}` : ''}</span></div>
            <div className="bo-line"><span>{t('dash.ordersInKitchen', lang)}</span><span>{rn.ordersInKitchen}</span></div>
            <div className={`bo-line ${rn.lateOrders > 0 ? 'neg' : ''}`}>
              <span>{t('dash.lateOrders', lang)}</span><span>{rn.lateOrders} <span className="bo-line-sub">({t('dash.lateMinThreshold', lang).replace('{n}', String(rn.lateMinThreshold))})</span></span>
            </div>
            <div className="bo-line strong"><span>{t('dash.collectedSoFar', lang)}</span><span>{formatTk(rn.todaySoFarBdt)}</span></div>
          </section>

          <section className="card bo-panel bo-panel-wide">
            <h3>{t('dash.needsAttention', lang)}</h3>
            <div className="bo-attn">
              {rn.needsAttention.length === 0 && <p className="bo-muted">{t('dash.allClear', lang)}</p>}
              {rn.needsAttention.map((a, i) => (
                <div className={`bo-attn-row ${a.kind}`} key={a.refId ?? i}>
                  <span className="bo-attn-title">{a.title}</span>
                  <span className="bo-attn-body">{a.body}</span>
                </div>
              ))}
            </div>
          </section>
        </div>
      )}
    </div>
  );
}
