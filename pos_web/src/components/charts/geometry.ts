// Pure SVG chart geometry — no React, no DOM, so it can be unit-tested directly.
// Hand-rolled (no chart lib) per the pos_web "no UI framework" stack rule.

export interface LineGeometry {
  points: { x: number; y: number }[];
  line: string; // "M … L …"
  area: string; // closed path down to the baseline
}

/** Round to avoid 12-decimal SVG coordinate noise (keeps snapshots/tests stable). */
function r(n: number): number {
  return Math.round(n * 100) / 100;
}

/**
 * Map a series of values to an x-evenly-spaced polyline inside a padded box.
 * `max` is shared across series so multiple lines share one vertical scale.
 */
export function buildLine(
  values: number[],
  width: number,
  height: number,
  pad: number,
  max: number,
): LineGeometry {
  const n = values.length;
  const innerW = Math.max(1, width - pad * 2);
  const innerH = Math.max(1, height - pad * 2);
  const safeMax = max > 0 ? max : 1;
  const baseline = height - pad;

  const points = values.map((v, i) => ({
    x: r(pad + (n <= 1 ? innerW / 2 : (i * innerW) / (n - 1))),
    y: r(baseline - (Math.max(0, v) / safeMax) * innerH),
  }));

  if (points.length === 0) return { points, line: '', area: '' };

  const line = points.map((p, i) => `${i === 0 ? 'M' : 'L'}${p.x} ${p.y}`).join(' ');
  const first = points[0];
  const last = points[points.length - 1];
  const area = `${line} L${last.x} ${r(baseline)} L${first.x} ${r(baseline)} Z`;
  return { points, line, area };
}

/** Largest value across one or more series, floored at 1 so charts never divide by 0. */
export function seriesMax(...series: number[][]): number {
  let m = 0;
  for (const s of series) for (const v of s) if (v > m) m = v;
  return m > 0 ? m : 1;
}

export interface DonutSegment {
  value: number;
  pct: number; // 0..100
  d: string; // ring-segment path
}

function polar(cx: number, cy: number, radius: number, angleDeg: number): { x: number; y: number } {
  const a = ((angleDeg - 90) * Math.PI) / 180; // 0° at 12 o'clock, clockwise
  return { x: r(cx + radius * Math.cos(a)), y: r(cy + radius * Math.sin(a)) };
}

/** Path for a donut ring segment between two angles (outer radius R, inner r). */
export function ringArc(
  cx: number, cy: number, rOuter: number, rInner: number, startAngle: number, endAngle: number,
): string {
  // Guard: a full 360° arc can't be drawn as one arc (start==end) — nudge it.
  const sweep = Math.min(359.999, endAngle - startAngle);
  const a1 = startAngle;
  const a2 = startAngle + sweep;
  const largeArc = sweep > 180 ? 1 : 0;
  const oStart = polar(cx, cy, rOuter, a1);
  const oEnd = polar(cx, cy, rOuter, a2);
  const iEnd = polar(cx, cy, rInner, a2);
  const iStart = polar(cx, cy, rInner, a1);
  return [
    `M${oStart.x} ${oStart.y}`,
    `A${rOuter} ${rOuter} 0 ${largeArc} 1 ${oEnd.x} ${oEnd.y}`,
    `L${iEnd.x} ${iEnd.y}`,
    `A${rInner} ${rInner} 0 ${largeArc} 0 ${iStart.x} ${iStart.y}`,
    'Z',
  ].join(' ');
}

/** Split values into donut ring segments (skips zero/negative slices). */
export function donutSegments(
  values: number[], size: number, thickness: number,
): DonutSegment[] {
  const total = values.reduce((s, v) => s + Math.max(0, v), 0);
  const cx = size / 2;
  const cy = size / 2;
  const rOuter = size / 2;
  const rInner = size / 2 - thickness;
  if (total <= 0) return [];
  let angle = 0;
  const out: DonutSegment[] = [];
  for (const v of values) {
    const val = Math.max(0, v);
    if (val <= 0) continue;
    const frac = val / total;
    const end = angle + frac * 360;
    out.push({ value: v, pct: r(frac * 100), d: ringArc(cx, cy, rOuter, rInner, angle, end) });
    angle = end;
  }
  return out;
}
