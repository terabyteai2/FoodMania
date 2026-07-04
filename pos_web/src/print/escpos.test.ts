import { describe, expect, it } from 'vitest';
import {
  CMD, dotsForPaper, rasterCommands, rasterize, ticketBytes, type PixelSource,
} from './escpos';

/** Build a white RGBA canvas, then paint the given (x,y) coords solid black. */
function canvas(width: number, height: number, black: [number, number][] = []): PixelSource {
  const data = new Uint8ClampedArray(width * height * 4).fill(255); // opaque white
  for (const [x, y] of black) {
    const i = (y * width + x) * 4;
    data[i] = 0; data[i + 1] = 0; data[i + 2] = 0; data[i + 3] = 255;
  }
  return { width, height, data };
}

describe('rasterize', () => {
  it('sets the MSB-first bit for a black pixel', () => {
    const r = rasterize(canvas(8, 1, [[0, 0]]));
    expect(r.widthBytes).toBe(1);
    expect(r.height).toBe(1);
    expect([...r.data]).toEqual([0x80]);
  });

  it('packs bits left-to-right within a byte', () => {
    const r = rasterize(canvas(8, 1, [[0, 0], [7, 0]]));
    expect([...r.data]).toEqual([0x81]);
  });

  it('pads the row width up to a whole byte', () => {
    const r = rasterize(canvas(9, 1, [[8, 0]]));
    expect(r.widthBytes).toBe(2);
    expect([...r.data]).toEqual([0x00, 0x80]);
  });

  it('treats fully transparent pixels as white (unset)', () => {
    const img = canvas(8, 1);
    img.data[3] = 0; // pixel 0 transparent
    const r = rasterize(img);
    expect([...r.data]).toEqual([0x00]);
  });
});

describe('rasterCommands', () => {
  it('emits a GS v 0 header with little-endian width/height', () => {
    const cmd = rasterCommands({ widthBytes: 1, height: 1, data: Uint8Array.of(0x80) });
    expect([...cmd]).toEqual([0x1d, 0x76, 0x30, 0x00, 0x01, 0x00, 0x01, 0x00, 0x80]);
  });

  it('slices tall images into bands', () => {
    const data = new Uint8Array(3).fill(0xff); // 1 byte wide × 3 rows
    const cmd = rasterCommands({ widthBytes: 1, height: 3, data }, 2);
    // two headers: rows=2 then rows=1
    expect(cmd[6]).toBe(2); // first band row count (low byte)
    const secondHeader = cmd.indexOf(0x1d, 1);
    expect(cmd[secondHeader + 6]).toBe(1); // second band row count
  });
});

describe('ticketBytes', () => {
  it('wraps the raster with init, feed and cut', () => {
    const out = ticketBytes(canvas(8, 1, [[0, 0]]));
    expect([...out.slice(0, 2)]).toEqual(CMD.init);
    expect(hasSeq(out, CMD.cut)).toBe(true);
    expect(hasSeq(out, CMD.feed(4))).toBe(true);
    expect(hasSeq(out, CMD.drawerKick)).toBe(false);
  });

  it('appends a drawer kick only when requested', () => {
    const out = ticketBytes(canvas(8, 1, [[0, 0]]), { kickDrawer: true });
    expect(hasSeq(out, CMD.drawerKick)).toBe(true);
  });

  it('omits the cut when cut:false', () => {
    const out = ticketBytes(canvas(8, 1, [[0, 0]]), { cut: false });
    expect(hasSeq(out, CMD.cut)).toBe(false);
  });
});

describe('dotsForPaper', () => {
  it('maps 58mm→384 and 80mm→576 dots', () => {
    expect(dotsForPaper(58)).toBe(384);
    expect(dotsForPaper(80)).toBe(576);
  });
});

function hasSeq(hay: Uint8Array, needle: readonly number[]): boolean {
  for (let i = 0; i + needle.length <= hay.length; i++) {
    if (needle.every((v, k) => hay[i + k] === v)) return true;
  }
  return false;
}
