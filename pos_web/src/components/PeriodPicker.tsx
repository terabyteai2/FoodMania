// Today / 7 Days / 30 Days / Custom range selector for back-office reports.
// Maps to the backend `range` param: today | week | month | custom (+ start/end).
import { useState } from 'react';
import type { AnalyticsRange } from '../api/types';

export interface Period { range: AnalyticsRange; start?: string; end?: string; }

const PRESETS: { key: AnalyticsRange; label: string }[] = [
  { key: 'today', label: 'Today' },
  { key: 'week', label: '7 Days' },
  { key: 'month', label: '30 Days' },
];

export function PeriodPicker({ value, onChange }: { value: Period; onChange: (p: Period) => void }) {
  const [start, setStart] = useState(value.start ?? '');
  const [end, setEnd] = useState(value.end ?? '');

  const applyCustom = (s: string, e: string) => {
    setStart(s); setEnd(e);
    if (s && e) onChange({ range: 'custom', start: s, end: e });
  };

  return (
    <div className="period">
      {PRESETS.map((p) => (
        <button
          key={p.key}
          className={`period-btn ${value.range === p.key ? 'active' : ''}`}
          onClick={() => onChange({ range: p.key })}
        >{p.label}</button>
      ))}
      <button
        className={`period-btn ${value.range === 'custom' ? 'active' : ''}`}
        onClick={() => (start && end ? onChange({ range: 'custom', start, end }) : onChange({ range: 'custom' }))}
      >Custom</button>
      {value.range === 'custom' && (
        <span className="period-custom">
          <input className="input" type="date" value={start} max={end || undefined}
            onChange={(e) => applyCustom(e.target.value, end)} />
          <span className="period-dash">–</span>
          <input className="input" type="date" value={end} min={start || undefined}
            onChange={(e) => applyCustom(start, e.target.value)} />
        </span>
      )}
    </div>
  );
}
