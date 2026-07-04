// Day-End — petpooja17 card grid fed by /pos/reports plus the cash-drawer summary
// from the current/closed shift. Close shift (counted drawer + variance) and a
// printable day-end ticket live here.

import { useEffect, useMemo, useState } from 'react';
import { api } from '../api/client';
import { useSession } from '../state/session';
import { usePos } from '../state/pos';
import { usePrinters } from '../print/printManager';
import { renderDayEnd, type DayEndSummary, type TicketContext } from '../print/ticketRenderer';
import { formatTk } from '../core/money';
import type { PosReportWire, PosShiftWire } from '../api/types';
import { ShiftModal } from '../components/ShiftModal';
import './dayend.css';

export function DayEnd() {
  const session = useSession((s) => s.session)!;
  const pos = usePos();
  const printers = usePrinters();

  const [report, setReport] = useState<PosReportWire | null>(null);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);
  const [shiftModal, setShiftModal] = useState<'open' | 'close' | null>(null);
  const [closedShift, setClosedShift] = useState<PosShiftWire | null>(null);
  const [toast, setToast] = useState<string | null>(null);

  const load = () => {
    setLoading(true);
    api.fetchPosReport(session.outletId, 1)
      .then((r) => setReport(r))
      .catch((e: unknown) => setErr(e instanceof Error ? e.message : String(e)))
      .finally(() => setLoading(false));
  };
  useEffect(load, [session.outletId]);

  const shift = closedShift ?? pos.shift;
  const cashTaken = report?.paymentSplit?.cash ?? 0;
  const openingCash = shift?.openingCash ?? null;
  const expectedCash = openingCash != null ? openingCash + cashTaken : null;

  const summary: DayEndSummary = useMemo(() => ({
    date: new Date().toISOString().slice(0, 10),
    sales: report?.sales ?? 0,
    orders: report?.orders ?? 0,
    covers: report?.covers ?? 0,
    paymentSplit: report?.paymentSplit ?? {},
    voids: report?.auditCounts?.void ?? 0,
    comps: report?.auditCounts?.comp ?? 0,
    refunds: report?.auditCounts?.refund ?? 0,
    openingCash,
    expectedCash,
    countedCash: closedShift?.countedCash ?? null,
    varianceCash: closedShift?.varianceCash ?? null,
  }), [report, openingCash, expectedCash, closedShift]);

  const ticketCtx: TicketContext = {
    restaurantName: session.restaurantName,
    outletName: session.outletName,
    serverRole: session.role,
  };

  const flash = (m: string) => { setToast(m); window.setTimeout(() => setToast(null), 2600); };

  const printDayEnd = async () => {
    try {
      await printers.print('bill', renderDayEnd(printers.paperDots('bill'), ticketCtx, summary));
      flash('Day-end printed');
    } catch (e) {
      flash(e instanceof Error ? e.message : String(e));
    }
  };

  const paySplit = Object.entries(summary.paymentSplit);

  return (
    <div className="dayend-root">
      <div className="dayend-head">
        <div>
          <h2>Day End</h2>
          <span className="dayend-date">{summary.date}</span>
        </div>
        <div className="dayend-head-actions">
          <button className="btn btn-outline btn-sm" onClick={load} disabled={loading}>↻ Refresh</button>
          <button className="btn btn-outline btn-sm" onClick={() => void printDayEnd()}>🖨 Print day-end</button>
          {pos.shift ? (
            <button className="btn btn-primary btn-sm" onClick={() => setShiftModal('close')}>Close shift</button>
          ) : (
            <button className="btn btn-primary btn-sm" onClick={() => setShiftModal('open')}>Open shift</button>
          )}
        </div>
      </div>

      {err && <div className="dayend-err">{err}</div>}

      <div className="dayend-grid">
        <Card title="Success Orders" value={formatTk(summary.sales)} sub={`${summary.orders} orders`} accent />
        <Card title="Covers" value={String(summary.covers)} sub="guests served" />
        <Card title="Voided Orders" value={String(summary.voids)} sub="cancelled" />
        <Card title="Complimentary" value={String(summary.comps)} sub="comp orders" />
        <Card title="Sales Returns" value={String(summary.refunds)} sub="refunds" />
        <Card
          title="Expected Drawer"
          value={expectedCash != null ? formatTk(expectedCash) : '—'}
          sub={openingCash != null ? `opening ${formatTk(openingCash)}` : 'no open shift'}
        />
      </div>

      <div className="dayend-cols">
        <section className="card dayend-panel">
          <h3>Payment split</h3>
          {paySplit.length === 0 ? (
            <p className="dayend-muted">No settlements yet.</p>
          ) : (
            paySplit.map(([m, amt]) => (
              <div className="dayend-line" key={m}>
                <span>{m.toUpperCase()}</span>
                <span>{formatTk(amt)}</span>
              </div>
            ))
          )}
        </section>

        <section className="card dayend-panel">
          <h3>Cash drawer</h3>
          {shift ? (
            <>
              <div className="dayend-line"><span>Opening float</span><span>{formatTk(openingCash ?? 0)}</span></div>
              <div className="dayend-line"><span>Cash taken</span><span>{formatTk(cashTaken)}</span></div>
              <div className="dayend-line strong"><span>Expected</span><span>{formatTk(expectedCash ?? 0)}</span></div>
              {closedShift?.countedCash != null && (
                <div className="dayend-line"><span>Counted</span><span>{formatTk(closedShift.countedCash)}</span></div>
              )}
              {closedShift?.varianceCash != null && (
                <div className={`dayend-line strong ${closedShift.varianceCash === 0 ? 'ok' : 'warn'}`}>
                  <span>Variance</span>
                  <span>{closedShift.varianceCash > 0 ? '+' : ''}{formatTk(closedShift.varianceCash)}</span>
                </div>
              )}
              {closedShift && <p className="dayend-muted">Shift closed.</p>}
            </>
          ) : (
            <p className="dayend-muted">No open shift. Open one to track the drawer.</p>
          )}
        </section>

        <section className="card dayend-panel">
          <h3>Top items</h3>
          {(report?.items ?? []).slice(0, 6).map((it, i) => (
            <div className="dayend-line" key={i}>
              <span>{it.qty} × {it.name}</span>
              <span>{formatTk(it.sales)}</span>
            </div>
          ))}
          {(report?.items?.length ?? 0) === 0 && <p className="dayend-muted">No items sold yet.</p>}
        </section>
      </div>

      {shiftModal && (
        <ShiftModal
          mode={shiftModal}
          onClose={() => setShiftModal(null)}
          onDone={(s) => {
            if (s) setClosedShift(s);
            setShiftModal(null);
            load();
          }}
        />
      )}

      {toast && <div className="toast">{toast}</div>}
    </div>
  );
}

function Card({ title, value, sub, accent }: { title: string; value: string; sub: string; accent?: boolean }) {
  return (
    <div className={`card dayend-card ${accent ? 'accent' : ''}`}>
      <span className="dayend-card-title">{title}</span>
      <span className="dayend-card-value">{value}</span>
      <span className="dayend-card-sub">{sub}</span>
    </div>
  );
}
