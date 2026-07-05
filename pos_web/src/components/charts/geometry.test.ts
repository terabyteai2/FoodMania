import { describe, expect, it } from 'vitest';
import { buildLine, seriesMax, donutSegments, ringArc } from './geometry';

describe('buildLine', () => {
  it('maps values to evenly spaced, baseline-anchored points', () => {
    const g = buildLine([0, 5, 10], 100, 40, 5, 10);
    expect(g.points).toEqual([
      { x: 5, y: 35 },
      { x: 50, y: 20 },
      { x: 95, y: 5 },
    ]);
    expect(g.line).toBe('M5 35 L50 20 L95 5');
    // area closes down to the baseline (y = height - pad = 35) and back
    expect(g.area).toBe('M5 35 L50 20 L95 5 L95 35 L5 35 Z');
  });

  it('centers a single point and never divides by zero', () => {
    const g = buildLine([0], 100, 40, 5, 0);
    expect(g.points).toEqual([{ x: 50, y: 35 }]);
  });

  it('returns empty geometry for no values', () => {
    expect(buildLine([], 100, 40, 5, 10)).toEqual({ points: [], line: '', area: '' });
  });
});

describe('seriesMax', () => {
  it('takes the max across all series', () => {
    expect(seriesMax([1, 2], [3, 0])).toBe(3);
  });
  it('floors at 1 so charts never divide by zero', () => {
    expect(seriesMax([], [0, 0])).toBe(1);
  });
});

describe('donutSegments', () => {
  it('splits values into ring segments with percentages', () => {
    const segs = donutSegments([1, 1], 100, 20);
    expect(segs).toHaveLength(2);
    expect(segs[0].pct).toBe(50);
    expect(segs[1].pct).toBe(50);
    expect(segs[0].d.startsWith('M')).toBe(true);
  });
  it('skips zero/negative slices', () => {
    expect(donutSegments([0, -3, 4], 100, 20)).toHaveLength(1);
  });
  it('returns nothing when the total is zero', () => {
    expect(donutSegments([0, 0], 100, 20)).toEqual([]);
  });
});

describe('ringArc', () => {
  it('produces a closed path with both arcs', () => {
    const d = ringArc(50, 50, 50, 30, 0, 90);
    expect(d.startsWith('M')).toBe(true);
    expect(d.endsWith('Z')).toBe(true);
    expect((d.match(/A/g) ?? []).length).toBe(2);
  });
});
