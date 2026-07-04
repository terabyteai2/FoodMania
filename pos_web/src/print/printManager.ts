// Printer orchestration: per-role (bill / KOT) device assignment, persisted prefs,
// ticket dispatch with system-print fallback.

import { create } from 'zustand';
import { dotsForPaper, ticketBytes } from './escpos';
import {
  findPairedUsbPrinter, requestUsbPrinter, usbRef, usbSupported, writeUsb, type UsbPrinterRef,
} from './webusb';
import {
  bleRef, bleSupported, findPairedBlePrinter, requestBlePrinter, writeBle, type BlePrinterRef,
} from './webbluetooth';

export type PrinterRole = 'bill' | 'kot';
export type PrinterTransport = 'usb' | 'ble' | 'system' | 'none';

export interface RoleConfig {
  transport: PrinterTransport;
  paperWidthMm: 58 | 80;
  usb?: UsbPrinterRef | null;
  ble?: BlePrinterRef | null;
  kickDrawer?: boolean; // bill printer usually drives the cash drawer
  label?: string | null;
}

interface PrinterPrefs {
  bill: RoleConfig;
  kot: RoleConfig;
}

const PREFS_KEY = 'qbpos.printers';

const defaultRole = (role: PrinterRole): RoleConfig => ({
  transport: 'system',
  paperWidthMm: 80,
  usb: null,
  ble: null,
  kickDrawer: role === 'bill',
  label: null,
});

function loadPrefs(): PrinterPrefs {
  try {
    const raw = localStorage.getItem(PREFS_KEY);
    if (raw) {
      const parsed = JSON.parse(raw) as Partial<PrinterPrefs>;
      return {
        bill: { ...defaultRole('bill'), ...parsed.bill },
        kot: { ...defaultRole('kot'), ...parsed.kot },
      };
    }
  } catch {
    /* fresh prefs */
  }
  return { bill: defaultRole('bill'), kot: defaultRole('kot') };
}

// live device handles (not serializable — kept outside the store's persisted data)
const liveUsb: Partial<Record<PrinterRole, USBDevice>> = {};
const liveBle: Partial<Record<PrinterRole, BluetoothDevice>> = {};

interface PrinterState {
  prefs: PrinterPrefs;
  lastError: string | null;
  setRoleConfig: (role: PrinterRole, cfg: Partial<RoleConfig>) => void;
  pairUsb: (role: PrinterRole) => Promise<void>;
  pairBle: (role: PrinterRole) => Promise<void>;
  print: (role: PrinterRole, canvas: HTMLCanvasElement, opts?: { kickDrawer?: boolean }) => Promise<void>;
  paperDots: (role: PrinterRole) => number;
}

export const usePrinters = create<PrinterState>((set, get) => ({
  prefs: loadPrefs(),
  lastError: null,

  setRoleConfig: (role, cfg) => {
    const prefs = { ...get().prefs, [role]: { ...get().prefs[role], ...cfg } };
    localStorage.setItem(PREFS_KEY, JSON.stringify(prefs));
    set({ prefs });
  },

  pairUsb: async (role) => {
    const device = await requestUsbPrinter();
    liveUsb[role] = device;
    get().setRoleConfig(role, {
      transport: 'usb',
      usb: usbRef(device),
      ble: null,
      label: device.productName ?? `USB ${device.vendorId.toString(16)}:${device.productId.toString(16)}`,
    });
  },

  pairBle: async (role) => {
    const device = await requestBlePrinter();
    liveBle[role] = device;
    get().setRoleConfig(role, {
      transport: 'ble',
      ble: bleRef(device),
      usb: null,
      label: device.name ?? 'Bluetooth printer',
    });
  },

  print: async (role, canvas, opts = {}) => {
    const cfg = get().prefs[role];
    set({ lastError: null });
    try {
      if (cfg.transport === 'usb') {
        let device = liveUsb[role] ?? null;
        if (!device && cfg.usb) device = await findPairedUsbPrinter(cfg.usb);
        if (!device) throw new Error('USB printer not connected — re-pair in printer settings');
        liveUsb[role] = device;
        const image = canvas.getContext('2d')!.getImageData(0, 0, canvas.width, canvas.height);
        await writeUsb(device, ticketBytes(image, { kickDrawer: opts.kickDrawer && cfg.kickDrawer }));
        return;
      }
      if (cfg.transport === 'ble') {
        let device = liveBle[role] ?? null;
        if (!device && cfg.ble) device = await findPairedBlePrinter(cfg.ble);
        if (!device) throw new Error('Bluetooth printer not connected — re-pair in printer settings');
        liveBle[role] = device;
        const image = canvas.getContext('2d')!.getImageData(0, 0, canvas.width, canvas.height);
        await writeBle(device, ticketBytes(image, { kickDrawer: opts.kickDrawer && cfg.kickDrawer }));
        return;
      }
      if (cfg.transport === 'system') {
        systemPrint(canvas);
        return;
      }
      throw new Error('No printer configured for this role');
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      set({ lastError: msg });
      throw e;
    }
  },

  paperDots: (role) => dotsForPaper(get().prefs[role].paperWidthMm),
}));

/** Browser print-dialog fallback: ticket bitmap in a hidden iframe. */
function systemPrint(canvas: HTMLCanvasElement): void {
  const dataUrl = canvas.toDataURL('image/png');
  const frame = document.createElement('iframe');
  frame.style.position = 'fixed';
  frame.style.right = '0';
  frame.style.bottom = '0';
  frame.style.width = '0';
  frame.style.height = '0';
  frame.style.border = '0';
  document.body.appendChild(frame);
  const doc = frame.contentDocument!;
  doc.open();
  doc.write(`<!doctype html><html><head><title>ticket</title>
    <style>@page{margin:0}body{margin:0}img{width:72mm;display:block}</style>
    </head><body><img src="${dataUrl}" /></body></html>`);
  doc.close();
  const img = doc.querySelector('img')!;
  img.addEventListener('load', () => {
    frame.contentWindow!.focus();
    frame.contentWindow!.print();
    setTimeout(() => frame.remove(), 30_000);
  });
}

export const printerCaps = {
  usb: usbSupported,
  ble: bleSupported,
};
