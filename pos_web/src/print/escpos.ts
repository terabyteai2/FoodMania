// ESC/POS byte builder — raster-image only (same philosophy as the Flutter apps:
// all content is a bitmap, so Bengali shaping is handled by canvas fonts, and the
// only printer commands are init / raster / feed / cut / drawer-kick).

const ESC = 0x1b;
const GS = 0x1d;

export const CMD = {
  init: [ESC, 0x40],
  feed: (lines: number) => [ESC, 0x64, Math.max(0, Math.min(255, lines))],
  cut: [GS, 0x56, 0x42, 0x00], // partial cut with feed
  drawerKick: [ESC, 0x70, 0x00, 0x19, 0xfa],
} as const;

/** Structural subset of ImageData so the encoder is testable in Node. */
export interface PixelSource {
  width: number;
  height: number;
  data: Uint8ClampedArray;
}

/**
 * Convert canvas RGBA pixels to 1-bit rows (1 = black dot).
 * Width is padded to a multiple of 8.
 */
export function rasterize(image: PixelSource, threshold = 160): { widthBytes: number; height: number; data: Uint8Array } {
  const { width, height, data } = image;
  const widthBytes = Math.ceil(width / 8);
  const out = new Uint8Array(widthBytes * height);
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const i = (y * width + x) * 4;
      const alpha = data[i + 3];
      // luminance on white background
      const lum = alpha === 0 ? 255 : (data[i] * 299 + data[i + 1] * 587 + data[i + 2] * 114) / 1000;
      if (lum < threshold) {
        out[y * widthBytes + (x >> 3)] |= 0x80 >> (x & 7);
      }
    }
  }
  return { widthBytes, height, data: out };
}

/**
 * GS v 0 raster blocks, band-sliced so cheap printers don't overflow their buffer.
 */
export function rasterCommands(
  raster: { widthBytes: number; height: number; data: Uint8Array },
  bandHeight = 256,
): Uint8Array {
  const chunks: number[] = [];
  const { widthBytes, height, data } = raster;
  for (let top = 0; top < height; top += bandHeight) {
    const rows = Math.min(bandHeight, height - top);
    chunks.push(
      GS, 0x76, 0x30, 0x00,
      widthBytes & 0xff, (widthBytes >> 8) & 0xff,
      rows & 0xff, (rows >> 8) & 0xff,
    );
    const start = top * widthBytes;
    for (let i = 0; i < rows * widthBytes; i++) chunks.push(data[start + i]);
  }
  return Uint8Array.from(chunks);
}

export interface TicketBytesOptions {
  feedLines?: number;
  cut?: boolean;
  kickDrawer?: boolean;
}

/** Full ESC/POS job for one ticket bitmap. */
export function ticketBytes(image: PixelSource, opts: TicketBytesOptions = {}): Uint8Array {
  const raster = rasterize(image);
  const body = rasterCommands(raster);
  const tail: number[] = [
    ...CMD.feed(opts.feedLines ?? 4),
    ...(opts.cut !== false ? CMD.cut : []),
    ...(opts.kickDrawer ? CMD.drawerKick : []),
  ];
  const out = new Uint8Array(CMD.init.length + body.length + tail.length);
  out.set(CMD.init, 0);
  out.set(body, CMD.init.length);
  out.set(tail, CMD.init.length + body.length);
  return out;
}

/** Paper width in printer dots. */
export function dotsForPaper(widthMm: 58 | 80): number {
  return widthMm === 80 ? 576 : 384;
}
