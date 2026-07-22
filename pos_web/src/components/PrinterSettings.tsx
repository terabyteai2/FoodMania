import { useState } from 'react';
import { useSession } from '../state/session';
import { t } from '../i18n/strings';
import { printerCaps, usePrinters } from '../print/printManager';
import { renderTestTicket } from '../print/ticketRenderer';

export function PrinterSettings() {
  const lang = useSession((s) => s.lang);
  const printers = usePrinters();
  const [busy, setBusy] = useState<string | null>(null);
  const [msg, setMsg] = useState<string | null>(null);
  const cfg = printers.config;

  const attempt = (label: string, fn: () => Promise<void>) => {
    setBusy(label);
    setMsg(null);
    fn()
      .then(() => setMsg(`${label}: ${t('ps.ok', lang)}`))
      .catch((e: unknown) => setMsg(`${label}: ${e instanceof Error ? e.message : String(e)}`))
      .finally(() => setBusy(null));
  };

  return (
    <div className="printer-settings">
      <div className="card printer-card">
        <div className="printer-card-head">
          <div>
            <h3>{t('ps.printerConnection', lang)}</h3>
            <span className="printer-hint">{t('ps.kitchenTickets', lang)}</span>
          </div>
          <span className={`printer-status ${cfg.transport !== 'none' ? 'ok' : ''}`}>
            {cfg.transport === 'usb' && `USB · ${cfg.label ?? t('ps.paired', lang)}`}
            {cfg.transport === 'ble' && `Bluetooth · ${cfg.label ?? t('ps.paired', lang)}`}
            {cfg.transport === 'system' && t('ps.systemDialog', lang)}
            {cfg.transport === 'none' && t('ps.notConfigured', lang)}
          </span>
        </div>

        <div className="printer-row">
          <button
            className="btn btn-outline btn-sm" disabled={!printerCaps.usb() || busy !== null}
            onClick={() => attempt(t('ps.pairUsb', lang), () => printers.pairUsb())}
          >{t('ps.pairUsb', lang)}</button>
          <button
            className="btn btn-outline btn-sm" disabled={!printerCaps.ble() || busy !== null}
            onClick={() => attempt(t('ps.pairBluetooth', lang), () => printers.pairBle())}
          >{t('ps.pairBluetooth', lang)}</button>
          <button
            className="btn btn-outline btn-sm"
            onClick={() => printers.setConfig({ transport: 'system' })}
          >{t('ps.useSystemDialog', lang)}</button>
        </div>

        <div className="printer-row">
          <label className="printer-paper">
            {t('ps.paper', lang)}
            <select
              className="input"
              value={cfg.paperWidthMm}
              onChange={(e) => printers.setConfig({ paperWidthMm: Number(e.target.value) as 58 | 80 })}
            >
              <option value={58}>{t('ps.58mm', lang)}</option>
              <option value={80}>{t('ps.80mm', lang)}</option>
            </select>
          </label>
          <label className="printer-drawer">
            <input
              type="checkbox" checked={!!cfg.kickDrawer}
              onChange={(e) => printers.setConfig({ kickDrawer: e.target.checked })}
            /> {t('ps.kickDrawer', lang)}
          </label>
          <button
            className="btn btn-primary btn-sm" disabled={busy !== null}
            onClick={() =>
              attempt(t('ps.testPrint', lang), () =>
                printers.print(renderTestTicket(printers.paperDots(), cfg.label ?? t('ps.printer', lang))),
              )
            }
          >{t('ps.testPrint', lang)}</button>
        </div>
      </div>

      {msg && <div className="printer-msg">{msg}</div>}
      <p className="printer-note">{t('ps.note', lang)}</p>
    </div>
  );
}
