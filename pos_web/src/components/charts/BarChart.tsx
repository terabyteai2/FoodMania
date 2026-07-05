// Horizontal value bars (service-wise sales etc.) — pure CSS, crisp at any width.
import './charts.css';

export interface BarDatum { label: string; value: number; color?: string; }

interface Props {
  data: BarDatum[];
  format: (v: number) => string;
  emptyLabel?: string;
}

export function BarChart({ data, format, emptyLabel = 'No data' }: Props) {
  const max = data.reduce((m, d) => Math.max(m, d.value), 0) || 1;
  if (data.every((d) => d.value <= 0)) return <div className="chart-empty">{emptyLabel}</div>;
  return (
    <div className="barchart">
      {data.map((d, i) => (
        <div className="barchart-row" key={i}>
          <span className="barchart-label" title={d.label}>{d.label}</span>
          <div className="barchart-track">
            <div
              className="barchart-fill"
              style={{ width: `${Math.max(0, (d.value / max) * 100)}%`, background: d.color ?? 'var(--primary)' }}
            />
          </div>
          <span className="barchart-value">{format(d.value)}</span>
        </div>
      ))}
    </div>
  );
}
