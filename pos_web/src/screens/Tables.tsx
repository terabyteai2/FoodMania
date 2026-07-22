// Table View — petpooja15: online-order accept/reject rail, zone sections with
// live table tiles (vacant / running / running-KOT / paid), Delivery & Pick Up
// quick-starts, and a floor-layout editor behind + Add Table.

import { useMemo, useState } from 'react';
import { api } from '../api/client';
import { useSession } from '../state/session';
import { usePos } from '../state/pos';
import { useCart } from '../state/cart';
import { useNav } from '../state/nav';
import { useOrders, occupiedTables, pendingOnline, tableStateOf } from '../state/orders';
import { usePrinters } from '../print/printManager';
import { renderKot, type TicketContext } from '../print/ticketRenderer';
import { formatTk } from '../core/money';
import type { OrderWire, PosFloorZoneWire, ServiceType } from '../api/types';
import { t, type Lang } from '../i18n/strings';
import { Modal } from '../components/Modal';
import './tables.css';

function elapsed(iso?: string | null): string {
  if (!iso) return '';
  const mins = Math.max(0, Math.round((Date.now() - new Date(iso).getTime()) / 60000));
  if (mins < 60) return `${mins}m`;
  return `${Math.floor(mins / 60)}h ${String(mins % 60).padStart(2, '0')}m`;
}

function serviceBadge(s: ServiceType | null | undefined, lang: Lang): string {
  if (s === 'delivery') return t('foh.delivery', lang);
  if (s === 'takeaway') return t('foh.pickUp', lang);
  return t('foh.dineIn', lang);
}

export function Tables() {
  const lang = useSession((s) => s.lang);
  const session = useSession((s) => s.session)!;
  const pos = usePos();
  const cart = useCart();
  const orders = useOrders();
  const printers = usePrinters();
  const go = useNav((s) => s.go);

  const [editor, setEditor] = useState(false);
  const [accepting, setAccepting] = useState<OrderWire | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [err, setErr] = useState<string | null>(null);

  const zones = pos.settings?.floorLayout ?? [];
  const occupied = useMemo(() => occupiedTables(orders.orders), [orders.orders]);
  const online = useMemo(() => pendingOnline(orders.orders), [orders.orders]);

  const ticketCtx: TicketContext = {
    restaurantName: session.restaurantName,
    outletName: session.outletName,
    serverRole: session.role,
  };

  const openVacant = (label: string) => {
    cart.clear();
    cart.setService('dine_in');
    cart.setTable(label);
    go('billing');
  };

  const openOrder = (order: OrderWire) => {
    cart.loadOrder(order);
    go('billing');
  };

  const quickStart = (service: ServiceType) => {
    cart.clear();
    cart.setService(service);
    go('billing');
  };

  const reject = async (order: OrderWire) => {
    setBusyId(order.id);
    setErr(null);
    try {
      await orders.reject(session.outletId, order);
    } catch (e) {
      setErr(e instanceof Error ? e.message : String(e));
    } finally {
      setBusyId(null);
    }
  };

  return (
    <div className="tables-root">
      {online.length > 0 && (
        <div className="online-rail">
          {online.map((o) => (
            <div className="online-card card" key={o.id}>
              <div className="online-card-head">
                <span className="online-src">🌐 {o.source.replace(/_/g, ' ')}</span>
                <span className="badge online-badge">{serviceBadge(o.serviceType, lang)}</span>
              </div>
              <div className="online-card-meta">
                <span>#{o.serialNumber}</span>
                <span>{o.createdAt ? new Date(o.createdAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : ''}</span>
                <span className="online-total">{formatTk(o.totalAmount)}</span>
              </div>
              <div className="online-lines">
                {o.items.slice(0, 5).map((it, i) => (
                  <div className="online-line" key={i}>{it.qty} × {it.name}</div>
                ))}
                {o.items.length > 5 && <div className="online-line more">+{o.items.length - 5}{t('tables.more', lang)}…</div>}
              </div>
              <div className="online-actions">
                <button
                  className="btn btn-danger-outline btn-sm" disabled={busyId === o.id}
                  onClick={() => void reject(o)}
                >{t('orders.reject', lang)}</button>
                <button
                  className="btn btn-primary btn-sm" disabled={busyId === o.id}
                  onClick={() => setAccepting(o)}
                >{t('orders.accept', lang)}</button>
              </div>
            </div>
          ))}
        </div>
      )}

      <div className="tables-bar">
        <h2>{t('tables.tableView', lang)}</h2>
        <button className="tables-refresh" title={t('tables.refresh', lang)} onClick={() => void orders.refresh(session.outletId)}>⟳</button>
        <div className="tables-bar-spacer" />
        <button className="btn btn-outline btn-sm" onClick={() => quickStart('delivery')}>{t('tables.delivery', lang)}</button>
        <button className="btn btn-outline btn-sm" onClick={() => quickStart('takeaway')}>{t('tables.pickUp', lang)}</button>
        <button className="btn btn-primary btn-sm" onClick={() => setEditor(true)}>{t('tables.addTable', lang)}</button>
      </div>

      <div className="tables-legend">
        <span><i className="dot dot-vacant" /> {t('tables.vacant', lang)}</span>
        <span><i className="dot dot-running" /> {t('tables.running', lang)}</span>
        <span><i className="dot dot-kot" /> {t('tables.runningKOT', lang)}</span>
        <span><i className="dot dot-paid" /> {t('tables.paid', lang)}</span>
      </div>

      {err && <div className="tables-err">{err}</div>}

      {zones.length === 0 ? (
        <div className="tables-empty card">
          <p>{t('tables.noTables', lang)}</p>
          <button className="btn btn-primary btn-sm" onClick={() => setEditor(true)}>{t('tables.addTable', lang)}</button>
        </div>
      ) : (
        zones.map((zone) => (
          <section className="zone" key={zone.id}>
            <h3 className="zone-name">{zone.name}</h3>
            <div className="zone-grid">
              {zone.tables.map((tbl) => {
                const order = occupied.get(tbl.label);
                const state = tableStateOf(order);
                return (
                  <button
                    key={tbl.id}
                    className={`table-tile state-${state}`}
                    onClick={() => (order ? openOrder(order) : openVacant(tbl.label))}
                  >
                    <span className="table-label">{tbl.label}</span>
                    {order ? (
                      <>
                        <span className="table-amount">{formatTk(order.totalAmount)}</span>
                        <span className="table-elapsed">{elapsed(order.createdAt)}</span>
                      </>
                    ) : (
                      <span className="table-seats">{tbl.seats}{t('tables.seats', lang)}</span>
                    )}
                  </button>
                );
              })}
            </div>
          </section>
        ))
      )}

      {accepting && (
        <AcceptModal
          lang={lang}
          order={accepting}
          onClose={() => setAccepting(null)}
          onAccept={async (prepMinutes, printKot) => {
            setBusyId(accepting.id);
            setErr(null);
            try {
              const updated = await orders.accept(session.outletId, accepting, prepMinutes);
              if (printKot) {
                const canvas = renderKot(
                  printers.paperDots(), ticketCtx, updated,
                  updated.items.map((it) => ({ qty: it.qty, name: it.name, note: it.note })),
                );
                await printers.print(canvas);
              }
              setAccepting(null);
            } catch (e) {
              setErr(e instanceof Error ? e.message : String(e));
            } finally {
              setBusyId(null);
            }
          }}
        />
      )}

      {editor && (
        <FloorEditor
          lang={lang}
          initial={zones}
          onClose={() => setEditor(false)}
          onSave={async (next) => {
            await api.patchPosSettings(session.outletId, { floorLayout: next });
            await pos.load(session.outletId);
            setEditor(false);
          }}
        />
      )}
    </div>
  );
}

// ---------------------------------------------------------------- Accept -----
function AcceptModal({
  lang, order, onClose, onAccept,
}: {
  lang: Lang;
  order: OrderWire;
  onClose: () => void;
  onAccept: (prepMinutes: number, printKot: boolean) => Promise<void>;
}) {
  const [prep, setPrep] = useState(20);
  const [busy, setBusy] = useState(false);

  const run = (printKot: boolean) => {
    setBusy(true);
    void onAccept(prep, printKot).finally(() => setBusy(false));
  };

  return (
    <Modal title={t('tables.acceptOrder', lang) + order.serialNumber} onClose={onClose} width={440}>
      <div className="accept-body">
        <label className="accept-row">
          {t('tables.prepTime', lang)}
          <span className="stepper">
            <button onClick={() => setPrep((v) => Math.max(0, v - 5))}>−</button>
            <input className="input" value={prep} inputMode="numeric"
              onChange={(e) => setPrep(Math.max(0, Number(e.target.value.replace(/\D/g, '')) || 0))} />
            <button onClick={() => setPrep((v) => v + 5)}>+</button>
          </span>
        </label>
        <div className="accept-actions">
          <button className="btn btn-outline" disabled={busy} onClick={() => run(false)}>{t('orders.accept', lang)}</button>
          <button className="btn btn-primary" disabled={busy} onClick={() => run(true)}>{t('tables.acceptPrint', lang)}</button>
        </div>
      </div>
    </Modal>
  );
}

// ------------------------------------------------------------ Floor editor ----
type DraftZone = PosFloorZoneWire;

function FloorEditor({
  lang, initial, onClose, onSave,
}: {
  lang: Lang;
  initial: PosFloorZoneWire[];
  onClose: () => void;
  onSave: (zones: PosFloorZoneWire[]) => Promise<void>;
}) {
  const [zones, setZones] = useState<DraftZone[]>(() =>
    initial.map((z) => ({ ...z, tables: z.tables.map((t) => ({ ...t })) })),
  );
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  const addZone = () =>
    setZones((zs) => [
      ...zs,
      { id: crypto.randomUUID(), name: t('tables.zone', lang).replace('{n}', String(zs.length + 1)), sortOrder: zs.length, tables: [] },
    ]);

  const renameZone = (id: string, name: string) =>
    setZones((zs) => zs.map((z) => (z.id === id ? { ...z, name } : z)));

  const removeZone = (id: string) => setZones((zs) => zs.filter((z) => z.id !== id));

  const addTable = (zoneId: string) =>
    setZones((zs) =>
      zs.map((z) => {
        if (z.id !== zoneId) return z;
        const n = z.tables.length + 1;
        return {
          ...z,
          tables: [
            ...z.tables,
            { id: crypto.randomUUID(), label: `${z.name.slice(0, 2).toUpperCase()}${n}`, seats: 4, sortOrder: n },
          ],
        };
      }),
    );

  const setTableLabel = (zoneId: string, tid: string, label: string) =>
    setZones((zs) =>
      zs.map((z) => (z.id === zoneId ? { ...z, tables: z.tables.map((t) => (t.id === tid ? { ...t, label } : t)) } : z)),
    );

  const removeTable = (zoneId: string, tid: string) =>
    setZones((zs) => zs.map((z) => (z.id === zoneId ? { ...z, tables: z.tables.filter((t) => t.id !== tid) } : z)));

  const save = () => {
    const cleaned = zones
      .map((z, i) => ({
        ...z,
        name: z.name.trim() || t('tables.zone', lang).replace('{n}', String(i + 1)),
        sortOrder: i,
        tables: z.tables
          .map((t, j) => ({ ...t, label: t.label.trim(), sortOrder: j }))
          .filter((t) => t.label),
      }));
    setBusy(true);
    setErr(null);
    onSave(cleaned).catch((e: unknown) => {
      setErr(e instanceof Error ? e.message : String(e));
      setBusy(false);
    });
  };

  return (
    <Modal title={t('tables.tableSetup', lang)} onClose={onClose} width={620}>
      <div className="floor-editor">
        {zones.map((z) => (
          <div className="floor-zone" key={z.id}>
            <div className="floor-zone-head">
              <input className="input floor-zone-name" value={z.name}
                onChange={(e) => renameZone(z.id, e.target.value)} />
              <button className="btn btn-danger-outline btn-sm" onClick={() => removeZone(z.id)}>{t('tables.removeZone', lang)}</button>
            </div>
            <div className="floor-tables">
              {z.tables.map((t) => (
                <span className="floor-table" key={t.id}>
                  <input className="input" value={t.label}
                    onChange={(e) => setTableLabel(z.id, t.id, e.target.value)} />
                  <button className="floor-table-x" onClick={() => removeTable(z.id, t.id)}>×</button>
                </span>
              ))}
              <button className="btn btn-outline btn-sm" onClick={() => addTable(z.id)}>{t('tables.addTableBtn', lang)}</button>
            </div>
          </div>
        ))}
        <button className="btn btn-outline btn-sm" onClick={addZone}>{t('tables.addZone', lang)}</button>
        {err && <div className="tables-err">{err}</div>}
        <div className="floor-actions">
          <button className="btn btn-outline" onClick={onClose}>{t('cancel', lang)}</button>
          <button className="btn btn-primary" disabled={busy} onClick={save}>{busy ? t('tables.saving', lang) : t('tables.saveLayout', lang)}</button>
        </div>
      </div>
    </Modal>
  );
}
