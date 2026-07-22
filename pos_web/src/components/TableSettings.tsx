import { useState } from 'react';
import { api } from '../api/client';
import { useSession } from '../state/session';
import { usePos } from '../state/pos';
import { t, type Lang } from '../i18n/strings';
import type { PosFloorZoneWire } from '../api/types';

const PRESETS = [0, 4, 6, 8, 10, 12, 15, 20, 25, 30, 40, 50];

function fallbackFloor(count: number, lang: Lang): PosFloorZoneWire[] {
  return [{
    id: 'main',
    name: t('settingsMainHall', lang),
    sortOrder: 0,
    tables: Array.from({ length: count }, (_, i) => ({
      id: `T${i + 1}`,
      label: String(i + 1),
      seats: 4,
      sortOrder: i + 1,
    })),
  }];
}

export function TableSettings() {
  const session = useSession((s) => s.session)!;
  const lang = useSession((s) => s.lang);
  const loadPos = usePos((s) => s.load);
  const currentCount = usePos((s) => s.settings?.tableCount ?? s.settings?.floorLayout?.reduce((sum, z) => sum + z.tables.length, 0) ?? 10);
  const [count, setCount] = useState(currentCount);
  const [saving, setSaving] = useState(false);
  const [msg, setMsg] = useState<string | null>(null);

  const save = async () => {
    setSaving(true);
    setMsg(null);
    try {
      await api.patchPosSettings(session.outletId, { floorLayout: fallbackFloor(count, lang) });
      await loadPos(session.outletId);
      setMsg(t('settingsSaved', lang));
    } catch (e) {
      setMsg(e instanceof Error ? e.message : String(e));
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="settings-root">
      <div className="card settings-card table-settings-card">
        <h3>{t('settingsTables', lang)}</h3>
        <p className="settings-subtitle">{t('settingsTablesSubtitle', lang)}</p>

        <div className="table-settings-stepper">
          <button
            className="btn btn-outline table-settings-btn"
            disabled={count <= 0}
            onClick={() => setCount((c) => Math.max(0, c - 1))}
          >−</button>
          <div className="table-settings-count">
            <span className="table-settings-num">{count}</span>
            <span className="table-settings-unit">{t('tablesLabel', lang)}</span>
          </div>
          <button
            className="btn btn-outline table-settings-btn"
            disabled={count >= 200}
            onClick={() => setCount((c) => Math.min(200, c + 1))}
          >+</button>
        </div>

        <div className="table-settings-presets">
          {PRESETS.map((p) => (
            <button
              key={p}
              className={`btn btn-outline btn-sm ${count === p ? 'active' : ''}`}
              onClick={() => setCount(p)}
            >{p}</button>
          ))}
        </div>

        <button className="btn btn-primary" disabled={saving || count === currentCount} onClick={save}>
          {saving ? '…' : t('save', lang)}
        </button>

        {msg && <div className="settings-field-msg">{msg}</div>}
      </div>
    </div>
  );
}
