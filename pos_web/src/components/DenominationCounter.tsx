// Cash denomination counter (Bangladesh Taka notes/coins). Reports running total
// and the per-denomination counts (persisted with the shift for the day-end drawer).

import { useState } from 'react';
import { formatTk } from '../core/money';

const DENOMS = [1000, 500, 200, 100, 50, 20, 10, 5, 2, 1];

export function DenominationCounter({
  onChange,
}: {
  onChange: (total: number, counts: Record<string, number>) => void;
}) {
  const [counts, setCounts] = useState<Record<string, number>>({});

  const set = (denom: number, n: number) => {
    const next: Record<string, number> = { ...counts, [denom]: n };
    if (n === 0) delete next[String(denom)];
    setCounts(next);
    onChange(DENOMS.reduce((s, d) => s + d * (next[d] ?? 0), 0), next);
  };

  const total = DENOMS.reduce((s, d) => s + d * (counts[d] ?? 0), 0);

  return (
    <div className="denom">
      {DENOMS.map((d) => (
        <div className="denom-row" key={d}>
          <span className="denom-face">৳{d}</span>
          <span className="denom-x">×</span>
          <input
            className="input denom-count" inputMode="numeric" value={counts[d] ?? ''} placeholder="0"
            onChange={(e) => set(d, Math.max(0, Number(e.target.value.replace(/\D/g, '')) || 0))}
          />
          <span className="denom-sub">{formatTk(d * (counts[d] ?? 0))}</span>
        </div>
      ))}
      <div className="denom-total">
        <span>Total counted</span>
        <span>{formatTk(total)}</span>
      </div>
    </div>
  );
}
