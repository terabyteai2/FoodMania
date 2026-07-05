// Tiny inline trend line (dashboard KPI). Fixed size, non-scaling stroke.
import { useId } from 'react';
import { buildLine, seriesMax } from './geometry';
import './charts.css';

interface Props {
  values: number[];
  width?: number;
  height?: number;
  color?: string;
}

export function Sparkline({ values, width = 120, height = 36, color = 'var(--primary)' }: Props) {
  const gradId = useId();
  const g = buildLine(values, width, height, 3, seriesMax(values));
  if (!values.some((v) => v > 0)) return <svg className="sparkline" width={width} height={height} />;
  return (
    <svg className="sparkline" width={width} height={height} role="img" aria-label="Sparkline">
      <defs>
        <linearGradient id={gradId} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor={color} stopOpacity="0.2" />
          <stop offset="100%" stopColor={color} stopOpacity="0" />
        </linearGradient>
      </defs>
      <path d={g.area} fill={`url(#${gradId})`} />
      <path d={g.line} fill="none" stroke={color} strokeWidth={1.5} strokeLinejoin="round" strokeLinecap="round" />
    </svg>
  );
}
