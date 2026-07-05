// Donut chart + legend (payment / collection split).
import { donutSegments } from './geometry';
import './charts.css';

export interface DonutDatum { label: string; value: number; color: string; }

interface Props {
  data: DonutDatum[];
  format: (v: number) => string;
  size?: number;
  thickness?: number;
  centerLabel?: string;
  centerValue?: string;
  emptyLabel?: string;
}

export function Donut({
  data, format, size = 140, thickness = 26, centerLabel, centerValue, emptyLabel = 'No data',
}: Props) {
  const segments = donutSegments(data.map((d) => d.value), size, thickness);
  if (segments.length === 0) return <div className="chart-empty">{emptyLabel}</div>;
  // segments skip zero slices, so map back to the colored data in order.
  const colored = data.filter((d) => d.value > 0);
  return (
    <div className="donut">
      <svg className="donut-svg" width={size} height={size} viewBox={`0 0 ${size} ${size}`} role="img" aria-label="Split">
        {segments.map((s, i) => (
          <path key={i} d={s.d} fill={colored[i]?.color ?? 'var(--line)'} />
        ))}
        {(centerValue || centerLabel) && (
          <>
            {centerValue && (
              <text x={size / 2} y={size / 2} textAnchor="middle" className="donut-center-value"
                dominantBaseline="central" dy={centerLabel ? '-0.3em' : '0'}>{centerValue}</text>
            )}
            {centerLabel && (
              <text x={size / 2} y={size / 2} textAnchor="middle" className="donut-center-label"
                dominantBaseline="central" dy="1.1em">{centerLabel}</text>
            )}
          </>
        )}
      </svg>
      <div className="donut-legend">
        {colored.map((d, i) => (
          <div className="donut-legend-row" key={i}>
            <span className="donut-dot" style={{ background: d.color }} />
            <span className="donut-legend-label">{d.label}</span>
            <span className="donut-legend-val">{format(d.value)}</span>
          </div>
        ))}
      </div>
    </div>
  );
}
