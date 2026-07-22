// Day-End — petpooja17 card grid fed by /pos/reports plus the cash-drawer summary
// from the current/closed shift. Close shift (counted drawer + variance) and a
// printable day-end ticket live here.

import { useEffect, useMemo, useState } from 'react';
import { api } from '../api/client';
import { useSession } from '../state/session';
import { t } from '../i18n/strings';
import { usePos } from '../state/pos';
import { usePrinters } from '../print/printManager';
import { renderDayEnd, type DayEndSummary, type TicketContext } from '../print/ticketRenderer';
import { formatTk } from '../core/money';
import type { PosReportWire, PosShiftWire } from '../api/types';
import { ShiftModal } from '../components/ShiftModal';
import './dayend.css';

export function DayEnd() {
  const session = useSession((s) => s.session)!;
  const lang = useSession((s) => s.lang);
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
      await printers.print(renderDayEnd(printers.paperDots(), ticketCtx, summary));
      flash(t('de.printed', lang));
    } catch (e) {
      flash(e instanceof Error ? e.message : String(e));
    }
  };

  const paySplit = Object.entries(summary.paymentSplit);

  return (
    <div className="dayend-root">
      <div className="dayend-head">
        <div>
          <h2>{t('de.title', lang)}</h2>
          <span className="dayend-date">{summary.date}</span>
        </div>
        <div className="dayend-head-actions">
          <button className="btn btn-outline btn-sm" onClick={load} disabled={loading}>↻ {t('de.refresh', lang)}</button>
          <button className="btn btn-outline btn-sm" onClick={() => void printDayEnd()}>🖨 {t('de.printDayEnd', lang)}</button>
          {pos.shift ? (
            <button className="btn btn-primary btn-sm" onClick={() => setShiftModal('close')}>{t('de.closeShift', lang)}</button>
          ) : (
            <button className="btn btn-primary btn-sm" onClick={() => setShiftModal('open')}>{t('de.openShift', lang)}</button>
          )}
        </div>
      </div>

      {err && <div className="dayend-err">{err}</div>}

      <div className="dayend-grid">
        <Card title={t('de.successOrders', lang)} value={formatTk(summary.sales)} sub={t('de.orders', lang).replace('{n}', String(summary.orders))} accent />
        <Card title={t('de.covers', lang)} value={String(summary.covers)} sub={t('de.guestsServed', lang)} />
        <Card title={t('de.voidedOrders', lang)} value={String(summary.voids)} sub={t('de.cancelled', lang)} />
        <Card title={t('de.complimentary', lang)} value={String(summary.comps)} sub={t('de.compOrders', lang)} />
        <Card title={t('de.salesReturns', lang)} value={String(summary.refunds)} sub={t('de.refunds', lang)} />
        <Card
          title={t('de.expectedDrawer', lang)}
          value={expectedCash != null ? formatTk(expectedCash) : '—'}
          sub={openingCash != null ? t('de.opening', lang).replace('{t}', formatTk(openingCash)) : t('de.noOpenShift', lang)}
        />
      </div>

      <div className="dayend-cols">
        <section className="card dayend-panel">
          <h3>{t('de.paymentSplit', lang)}</h3>
          {paySplit.length === 0 ? (
            <p className="dayend-muted">{t('de.noSettlements', lang)}</p>
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
          <h3>{t('de.cashDrawer', lang)}</h3>
          {shift ? (
            <>
              <div className="dayend-line"><span>{t('de.openingFloat', lang)}</span><span>{formatTk(openingCash ?? 0)}</span></div>
              <div className="dayend-line"><span>{t('de.cashTaken', lang)}</span><span>{formatTk(cashTaken)}</span></div>
              <div className="dayend-line strong"><span>{t('de.expected', lang)}</span><span>{formatTk(expectedCash ?? 0)}</span></div>
              {closedShift?.countedCash != null && (
                <div className="dayend-line"><span>{t('de.counted', lang)}</span><span>{formatTk(closedShift.countedCash)}</span></div>
              )}
              {closedShift?.varianceCash != null && (
                <div className={`dayend-line strong ${closedShift.varianceCash === 0 ? 'ok' : 'warn'}`}>
                  <span>{t('de.variance', lang)}</span>
                  <span>{closedShift.varianceCash > 0 ? '+' : ''}{formatTk(closedShift.varianceCash)}</span>
                </div>
              )}
              {closedShift && <p className="dayend-muted">{t('de.shiftClosed', lang)}</p>}
            </>
          ) : (
            <p className="dayend-muted">{t('de.noShift', lang)}</p>
          )}
        </section>

        <section className="card dayend-panel">
          <h3>{t('de.topItems', lang)}</h3>
          {(report?.items ?? []).slice(0, 6).map((it, i) => (
            <div className="dayend-line" key={i}>
              <span>{it.qty} × {it.name}</span>
              <span>{formatTk(it.sales)}</span>
            </div>
          ))}
          {(report?.items?.length ?? 0) === 0 && <p className="dayend-muted">{t('de.noItemsSold', lang)}</p>}
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
