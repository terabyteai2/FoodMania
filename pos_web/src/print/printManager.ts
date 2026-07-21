import { create } from 'zustand';
import { dotsForPaper, ticketBytes } from './escpos';
import {
  findPairedUsbPrinter, requestUsbPrinter, usbRef, usbSupported, writeUsb, type UsbPrinterRef,
} from './webusb';
import {
  bleRef, bleSupported, findPairedBlePrinter, requestBlePrinter, writeBle, type BlePrinterRef,
} from './webbluetooth';

export type PrinterTransport = 'usb' | 'ble' | 'system' | 'none';

export interface PrinterConfig {
  transport: PrinterTransport;
  paperWidthMm: 58 | 80;
  usb?: UsbPrinterRef | null;
  ble?: BlePrinterRef | null;
  kickDrawer?: boolean;
  label?: string | null;
}

interface OldPrefs {
  bill?: PrinterConfig;
  kot?: PrinterConfig;
}

const PREFS_KEY = 'qbpos.printers';

const defaultConfig: PrinterConfig = {
  transport: 'system',
  paperWidthMm: 80,
  usb: null,
  ble: null,
  kickDrawer: true,
  label: null,
};

function isOldPrefs(v: unknown): v is OldPrefs {
  return typeof v === 'object' && v !== null && ('bill' in v || 'kot' in v);
}

function loadPrefs(): PrinterConfig {
  try {
    const raw = localStorage.getItem(PREFS_KEY);
    if (!raw) return { ...defaultConfig };
    const parsed = JSON.parse(raw);
    if (isOldPrefs(parsed)) {
      const bill = parsed.bill;
      const kot = parsed.kot;
      const pick = bill && bill.transport !== 'none' ? bill : kot && kot.transport !== 'none' ? kot : defaultConfig;
      localStorage.setItem(PREFS_KEY, JSON.stringify(pick));
      return { ...defaultConfig, ...pick };
    }
    return { ...defaultConfig, ...parsed };
  } catch {
    return { ...defaultConfig };
  }
}

let liveUsb: USBDevice | null = null;
let liveBle: BluetoothDevice | null = null;

interface PrinterState {
  config: PrinterConfig;
  lastError: string | null;
  setConfig: (cfg: Partial<PrinterConfig>) => void;
  pairUsb: () => Promise<void>;
  pairBle: () => Promise<void>;
  print: (canvas: HTMLCanvasElement, opts?: { kickDrawer?: boolean }) => Promise<void>;
  paperDots: () => number;
}

export const usePrinters = create<PrinterState>((set, get) => ({
  config: loadPrefs(),
  lastError: null,

  setConfig: (cfg) => {
    const config = { ...get().config, ...cfg };
    localStorage.setItem(PREFS_KEY, JSON.stringify(config));
    set({ config });
  },

  pairUsb: async () => {
    const device = await requestUsbPrinter();
    liveUsb = device;
    get().setConfig({
      transport: 'usb',
      usb: usbRef(device),
      ble: null,
      label: device.productName ?? `USB ${device.vendorId.toString(16)}:${device.productId.toString(16)}`,
    });
  },

  pairBle: async () => {
    const device = await requestBlePrinter();
    liveBle = device;
    get().setConfig({
      transport: 'ble',
      ble: bleRef(device),
      usb: null,
      label: device.name ?? 'Bluetooth printer',
    });
  },

  print: async (canvas, opts = {}) => {
    const cfg = get().config;
    set({ lastError: null });
    try {
      if (cfg.transport === 'usb') {
        let device = liveUsb;
        if (!device && cfg.usb) device = await findPairedUsbPrinter(cfg.usb);
        if (!device) throw new Error('USB printer not connected — re-pair in printer settings');
        liveUsb = device;
        const image = canvas.getContext('2d')!.getImageData(0, 0, canvas.width, canvas.height);
        await writeUsb(device, ticketBytes(image, { kickDrawer: opts.kickDrawer && cfg.kickDrawer }));
        return;
      }
      if (cfg.transport === 'ble') {
        let device = liveBle;
        if (!device && cfg.ble) device = await findPairedBlePrinter(cfg.ble);
        if (!device) throw new Error('Bluetooth printer not connected — re-pair in printer settings');
        liveBle = device;
        const image = canvas.getContext('2d')!.getImageData(0, 0, canvas.width, canvas.height);
        await writeBle(device, ticketBytes(image, { kickDrawer: opts.kickDrawer && cfg.kickDrawer }));
        return;
      }
      if (cfg.transport === 'system') {
        systemPrint(canvas);
        return;
      }
      throw new Error('No printer configured');
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      set({ lastError: msg });
      throw e;
    }
  },

  paperDots: () => dotsForPaper(get().config.paperWidthMm),
}));

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
