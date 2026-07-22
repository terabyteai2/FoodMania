// Today / 7 Days / 30 Days / Custom range selector for back-office reports.
// Maps to the backend `range` param: today | week | month | custom (+ start/end).
import { useState } from 'react';
import { useSession } from '../state/session';
import { t } from '../i18n/strings';
import type { AnalyticsRange } from '../api/types';

export interface Period { range: AnalyticsRange; start?: string; end?: string; }

const PRESET_KEYS: AnalyticsRange[] = ['today', 'week', 'month'];

export function PeriodPicker({ value, onChange }: { value: Period; onChange: (p: Period) => void }) {
  const lang = useSession((s) => s.lang);
  const [start, setStart] = useState(value.start ?? '');
  const [end, setEnd] = useState(value.end ?? '');

  const applyCustom = (s: string, e: string) => {
    setStart(s); setEnd(e);
    if (s && e) onChange({ range: 'custom', start: s, end: e });
  };

  return (
    <div className="period">
      {PRESET_KEYS.map((k) => (
        <button
          key={k}
          className={`period-btn ${value.range === k ? 'active' : ''}`}
          onClick={() => onChange({ range: k })}
        >{k === 'today' ? t('pp.today', lang) : k === 'week' ? t('pp.7days', lang) : t('pp.30days', lang)}</button>
      ))}
      <button
        className={`period-btn ${value.range === 'custom' ? 'active' : ''}`}
        onClick={() => (start && end ? onChange({ range: 'custom', start, end }) : onChange({ range: 'custom' }))}
      >{t('pp.custom', lang)}</button>
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
