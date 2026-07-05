// Revenue / orders trend — SVG area + line, optional comparison series.
import { useId } from 'react';
import { buildLine, seriesMax } from './geometry';
import { useElementWidth } from './useElementWidth';
import './charts.css';

interface Props {
  values: number[];
  compare?: number[];
  labels?: string[];
  height?: number;
  color?: string;
  compareColor?: string;
  emptyLabel?: string;
}

export function AreaTrend({
  values, compare, labels, height = 150,
  color = 'var(--primary)', compareColor = 'var(--line-strong)', emptyLabel = 'No data',
}: Props) {
  const [ref, width] = useElementWidth<HTMLDivElement>();
  const gradId = useId();
  const hasData = values.some((v) => v > 0) || (compare?.some((v) => v > 0) ?? false);
  const pad = 8;
  const max = seriesMax(values, compare ?? []);
  const main = width > 0 ? buildLine(values, width, height, pad, max) : null;
  const cmp = width > 0 && compare ? buildLine(compare, width, height, pad, max) : null;

  const shownLabels = labels && labels.length > 6
    ? labels.filter((_, i) => i === 0 || i === labels.length - 1 || i === Math.floor(labels.length / 2))
    : labels;

  return (
    <div className="chart-area" ref={ref}>
      {main && hasData ? (
        <svg width={width} height={height} role="img" aria-label="Trend">
          <defs>
            <linearGradient id={gradId} x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor={color} stopOpacity="0.22" />
              <stop offset="100%" stopColor={color} stopOpacity="0" />
            </linearGradient>
          </defs>
          <path d={main.area} fill={`url(#${gradId})`} />
          {cmp && <path d={cmp.line} fill="none" stroke={compareColor} strokeWidth={1.5} strokeDasharray="4 4" />}
          <path d={main.line} fill="none" stroke={color} strokeWidth={2} strokeLinejoin="round" strokeLinecap="round" />
          {main.points.map((p, i) => (
            <circle key={i} cx={p.x} cy={p.y} r={2.5} fill={color} />
          ))}
        </svg>
      ) : (
        <div className="chart-empty" style={{ minHeight: height }}>{emptyLabel}</div>
      )}
      {shownLabels && hasData && (
        <div className="chart-xlabels">
          {shownLabels.map((l, i) => <span key={i}>{l}</span>)}
        </div>
      )}
    </div>
  );
}
