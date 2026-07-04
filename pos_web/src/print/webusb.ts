// WebUSB transport for USB ESC/POS printers.
// Field caveat (accepted): on Windows, usbprint.sys often claims the printer; a
// one-time WinUSB driver swap (Zadig) is needed before Chrome can open it.

export interface UsbPrinterRef {
  vendorId: number;
  productId: number;
  serialNumber?: string;
  productName?: string;
}

const CHUNK = 16 * 1024;

export async function requestUsbPrinter(): Promise<USBDevice> {
  // USB printer class 7; some ESC/POS boards report vendor-specific (0xFF)
  const device = await navigator.usb.requestDevice({
    filters: [{ classCode: 7 }, { classCode: 0xff }],
  });
  return device;
}

export async function findPairedUsbPrinter(ref: UsbPrinterRef): Promise<USBDevice | null> {
  const devices = await navigator.usb.getDevices();
  return (
    devices.find(
      (d) =>
        d.vendorId === ref.vendorId &&
        d.productId === ref.productId &&
        (!ref.serialNumber || d.serialNumber === ref.serialNumber),
    ) ?? null
  );
}

export function usbRef(device: USBDevice): UsbPrinterRef {
  return {
    vendorId: device.vendorId,
    productId: device.productId,
    serialNumber: device.serialNumber ?? undefined,
    productName: device.productName ?? undefined,
  };
}

interface ClaimedEndpoint {
  interfaceNumber: number;
  endpointNumber: number;
}

async function claimOutEndpoint(device: USBDevice): Promise<ClaimedEndpoint> {
  if (!device.opened) await device.open();
  if (device.configuration == null) await device.selectConfiguration(1);
  const config = device.configuration!;
  for (const iface of config.interfaces) {
    for (const alt of iface.alternates) {
      // prefer printer class, fall back to any interface with a bulk-out endpoint
      const out = alt.endpoints.find((e) => e.direction === 'out' && e.type === 'bulk');
      if (out && (alt.interfaceClass === 7 || alt.interfaceClass === 0xff)) {
        await device.claimInterface(iface.interfaceNumber);
        return { interfaceNumber: iface.interfaceNumber, endpointNumber: out.endpointNumber };
      }
    }
  }
  // fallback: first bulk-out anywhere
  for (const iface of config.interfaces) {
    for (const alt of iface.alternates) {
      const out = alt.endpoints.find((e) => e.direction === 'out' && e.type === 'bulk');
      if (out) {
        await device.claimInterface(iface.interfaceNumber);
        return { interfaceNumber: iface.interfaceNumber, endpointNumber: out.endpointNumber };
      }
    }
  }
  throw new Error('No bulk-out endpoint found on this USB device');
}

export async function writeUsb(device: USBDevice, bytes: Uint8Array): Promise<void> {
  const ep = await claimOutEndpoint(device);
  try {
    for (let off = 0; off < bytes.length; off += CHUNK) {
      // Copy into a fresh ArrayBuffer-backed view (BufferSource requires non-Shared).
      const part = new Uint8Array(bytes.subarray(off, Math.min(off + CHUNK, bytes.length)));
      const result = await device.transferOut(ep.endpointNumber, part);
      if (result.status !== 'ok') throw new Error(`USB transfer failed: ${result.status}`);
    }
  } finally {
    try {
      await device.releaseInterface(ep.interfaceNumber);
    } catch {
      /* ignore */
    }
  }
}

export function usbSupported(): boolean {
  return typeof navigator !== 'undefined' && 'usb' in navigator;
}
