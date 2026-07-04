// Printer configuration per role (bill / KOT): transport pairing, paper width, test print.

import { useState } from 'react';
import { printerCaps, usePrinters, type PrinterRole } from '../print/printManager';
import { renderTestTicket } from '../print/ticketRenderer';

const ROLES: { id: PrinterRole; title: string; hint: string }[] = [
  { id: 'bill', title: 'Bill printer', hint: 'Customer receipts · cash drawer' },
  { id: 'kot', title: 'KOT printer', hint: 'Kitchen order tickets' },
];

export function PrinterSettings() {
  const printers = usePrinters();
  const [busy, setBusy] = useState<string | null>(null);
  const [msg, setMsg] = useState<string | null>(null);

  const attempt = (label: string, fn: () => Promise<void>) => {
    setBusy(label);
    setMsg(null);
    fn()
      .then(() => setMsg(`${label}: OK`))
      .catch((e: unknown) => setMsg(`${label}: ${e instanceof Error ? e.message : String(e)}`))
      .finally(() => setBusy(null));
  };

  return (
    <div className="printer-settings">
      {ROLES.map(({ id, title, hint }) => {
        const cfg = printers.prefs[id];
        return (
          <div className="card printer-card" key={id}>
            <div className="printer-card-head">
              <div>
                <h3>{title}</h3>
                <span className="printer-hint">{hint}</span>
              </div>
              <span className={`printer-status ${cfg.transport !== 'none' ? 'ok' : ''}`}>
                {cfg.transport === 'usb' && `USB · ${cfg.label ?? 'paired'}`}
                {cfg.transport === 'ble' && `Bluetooth · ${cfg.label ?? 'paired'}`}
                {cfg.transport === 'system' && 'System print dialog'}
                {cfg.transport === 'none' && 'Not configured'}
              </span>
            </div>

            <div className="printer-row">
              <button
                className="btn btn-outline btn-sm" disabled={!printerCaps.usb() || busy !== null}
                onClick={() => attempt(`Pair USB (${title})`, () => printers.pairUsb(id))}
              >Pair USB printer</button>
              <button
                className="btn btn-outline btn-sm" disabled={!printerCaps.ble() || busy !== null}
                onClick={() => attempt(`Pair Bluetooth (${title})`, () => printers.pairBle(id))}
              >Pair Bluetooth printer</button>
              <button
                className="btn btn-outline btn-sm"
                onClick={() => printers.setRoleConfig(id, { transport: 'system' })}
              >Use system dialog</button>
            </div>

            <div className="printer-row">
              <label className="printer-paper">
                Paper:
                <select
                  className="input"
                  value={cfg.paperWidthMm}
                  onChange={(e) => printers.setRoleConfig(id, { paperWidthMm: Number(e.target.value) as 58 | 80 })}
                >
                  <option value={58}>58 mm (384 dots)</option>
                  <option value={80}>80 mm (576 dots)</option>
                </select>
              </label>
              {id === 'bill' && (
                <label className="printer-drawer">
                  <input
                    type="checkbox" checked={!!cfg.kickDrawer}
                    onChange={(e) => printers.setRoleConfig(id, { kickDrawer: e.target.checked })}
                  /> Kick cash drawer on cash settle
                </label>
              )}
              <button
                className="btn btn-primary btn-sm" disabled={busy !== null}
                onClick={() =>
                  attempt(`Test print (${title})`, () =>
                    printers.print(id, renderTestTicket(printers.paperDots(id), cfg.label ?? title)),
                  )
                }
              >Test print</button>
            </div>
          </div>
        );
      })}

      {msg && <div className="printer-msg">{msg}</div>}
      <p className="printer-note">
        USB printing needs Chrome/Edge over HTTPS. If Windows blocks the USB printer
        (driver already claims it), swap its driver to WinUSB once using Zadig, or use
        the system print dialog instead. Bluetooth works with BLE-capable printers only.
      </p>
    </div>
  );
}
