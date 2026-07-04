// Web Bluetooth transport for BLE thermal printers.
// Classic-SPP-only printers cannot pair via Web Bluetooth — BLE models only.

export interface BlePrinterRef {
  deviceId: string;
  name?: string;
}

// Well-known BLE printer service/characteristic pairs
const PRINTER_SERVICES: { service: BluetoothServiceUUID; char?: BluetoothCharacteristicUUID }[] = [
  { service: 0x18f0, char: 0x2af1 },
  { service: '49535343-fe7d-4ae5-8fa9-9fafd205e455', char: '49535343-8841-43f4-a8d4-ecbe34729bb3' },
  { service: 'e7810a71-73ae-499d-8c15-faa9aef0c3f2', char: 'bef8d6c9-9c21-4c9e-b632-bd58c1009f9f' },
];

const CHUNK = 180; // safe below the common 185/512 MTU floors
const CHUNK_DELAY_MS = 12;

export async function requestBlePrinter(): Promise<BluetoothDevice> {
  return navigator.bluetooth.requestDevice({
    filters: PRINTER_SERVICES.map((s) => ({ services: [s.service] })),
    optionalServices: PRINTER_SERVICES.map((s) => s.service),
  });
}

export function bleRef(device: BluetoothDevice): BlePrinterRef {
  return { deviceId: device.id, name: device.name ?? undefined };
}

export async function findPairedBlePrinter(ref: BlePrinterRef): Promise<BluetoothDevice | null> {
  if (!('getDevices' in navigator.bluetooth)) return null;
  const devices = await navigator.bluetooth.getDevices();
  return devices.find((d) => d.id === ref.deviceId) ?? null;
}

async function findWritableChar(device: BluetoothDevice): Promise<BluetoothRemoteGATTCharacteristic> {
  const server = device.gatt?.connected ? device.gatt : await device.gatt?.connect();
  if (!server) throw new Error('Bluetooth GATT connection failed');
  for (const entry of PRINTER_SERVICES) {
    try {
      const service = await server.getPrimaryService(entry.service);
      if (entry.char) {
        try {
          return await service.getCharacteristic(entry.char);
        } catch {
          /* fall through to scan */
        }
      }
      const chars = await service.getCharacteristics();
      const writable = chars.find((c) => c.properties.writeWithoutResponse || c.properties.write);
      if (writable) return writable;
    } catch {
      /* service not present — try next */
    }
  }
  throw new Error('No writable printer characteristic found');
}

export async function writeBle(device: BluetoothDevice, bytes: Uint8Array): Promise<void> {
  const char = await findWritableChar(device);
  const useNoResponse = char.properties.writeWithoutResponse;
  for (let off = 0; off < bytes.length; off += CHUNK) {
    // Copy into a fresh ArrayBuffer-backed view (BufferSource requires non-Shared).
    const part = new Uint8Array(bytes.subarray(off, Math.min(off + CHUNK, bytes.length)));
    if (useNoResponse) await char.writeValueWithoutResponse(part);
    else await char.writeValueWithResponse(part);
    await new Promise((r) => setTimeout(r, CHUNK_DELAY_MS));
  }
}

export function bleSupported(): boolean {
  return typeof navigator !== 'undefined' && 'bluetooth' in navigator;
}
