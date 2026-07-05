// Dashboard — live "money-first + right now" tower (petpooja18/19/20 aesthetic),
// fed by GET /dashboard/summary. Today-scoped (the dashboard is a live view).

import { useEffect, useState } from 'react';
import { api } from '../api/client';
import { useSession } from '../state/session';
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
          <h2>Dashboard</h2>
          <span className="bo-sub">{session.outletName} · today</span>
        </div>
        <div className="bo-head-actions">
          <button className="btn btn-outline btn-sm" onClick={load} disabled={loading}>↻ Refresh</button>
        </div>
      </div>

      {err && <div className="bo-err">{err}</div>}
      {loading && !data && <div className="bo-loading">Loading…</div>}

      {mf && (
        <>
          <div className="bo-grid">
            <StatCard
              title="Earned Today" accent value={formatTk(mf.earnedToday)}
              sub={`${deltaUp ? '▲' : '▼'} ${Math.abs(mf.deltaPct)}% vs yesterday`}
              subTone={deltaUp ? 'up' : 'down'}
            />
            <StatCard title="Orders" value={String(mf.kpis.orders)} sub={`${mf.kpis.openOrders} open`} />
            <StatCard title="Avg Ticket" value={formatTk(mf.kpis.avgTicket)} sub="per order" />
            <StatCard
              title="Profit" value={mf.kpis.profitPct != null ? `${mf.kpis.profitPct}%` : '—'}
              sub="est. margin"
            />
          </div>

          <div className="bo-cols">
            <section className="card bo-panel">
              <h3>Last 7 days</h3>
              <Sparkline values={mf.sparkline} width={260} height={64} />
              <span className="bo-muted">Earned yesterday {formatTk(mf.earnedYesterday)} · {mf.deltaNote}</span>
            </section>

            <section className="card bo-panel">
              <h3>Service mix</h3>
              <Donut data={mixData} format={formatTk} centerValue={formatTk(mf.earnedToday)} centerLabel="today" />
            </section>

            <section className="card bo-panel">
              <h3>Top movers</h3>
              <div className="bo-rank">
                {mf.topMovers.length === 0 && <p className="bo-muted">No sales yet.</p>}
                {mf.topMovers.map((m) => (
                  <div className="bo-rank-row" key={m.menuItemId}>
                    <span className="bo-rank-name">{m.nameEn || m.nameBn || 'Item'}</span>
                    <span className="bo-rank-qty">{m.qty} sold</span>
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
            <h3>Right now</h3>
            <div className="bo-line"><span>Tables seated</span><span>{rn.tablesSeated}{rn.tablesTotal ? ` / ${rn.tablesTotal}` : ''}</span></div>
            <div className="bo-line"><span>Orders in kitchen</span><span>{rn.ordersInKitchen}</span></div>
            <div className={`bo-line ${rn.lateOrders > 0 ? 'neg' : ''}`}>
              <span>Late orders</span><span>{rn.lateOrders} <span className="bo-line-sub">(&gt;{rn.lateMinThreshold}m)</span></span>
            </div>
            <div className="bo-line strong"><span>Collected so far</span><span>{formatTk(rn.todaySoFarBdt)}</span></div>
          </section>

          <section className="card bo-panel bo-panel-wide">
            <h3>Needs attention</h3>
            <div className="bo-attn">
              {rn.needsAttention.length === 0 && <p className="bo-muted">All clear — nothing needs attention.</p>}
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
