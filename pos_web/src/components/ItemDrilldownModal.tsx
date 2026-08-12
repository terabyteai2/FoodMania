// Item drill-down — daily sales series for one menu item over the current
// Analytics period, from GET /analytics/item/{menuItemId}.

import { useEffect, useState } from 'react';
import { api } from '../api/client';
import { useSession } from '../state/session';
import { t } from '../i18n/strings';
import { formatTk } from '../core/money';
import { Modal } from './Modal';
import { AreaTrend } from './charts/AreaTrend';
import type { Period } from './PeriodPicker';
import type { AnalyticsItemDetailWire } from '../api/types';

export function ItemDrilldownModal({
  outletId, menuItemId, fallbackName, period, onClose,
}: {
  outletId: string;
  menuItemId: string;
  fallbackName: string;
  period: Period;
  onClose: () => void;
}) {
  const lang = useSession((s) => s.lang);
  const [data, setData] = useState<AnalyticsItemDetailWire | null>(null);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    setLoading(true); setErr(null);
    api.fetchAnalyticsItemDetail(outletId, menuItemId, {
      range: period.range, start: period.start, end: period.end,
    })
      .then((d) => { if (!cancelled) setData(d); })
      .catch((e: unknown) => { if (!cancelled) setErr(e instanceof Error ? e.message : String(e)); })
      .finally(() => { if (!cancelled) setLoading(false); });
    return () => { cancelled = true; };
  }, [outletId, menuItemId, period.range, period.start, period.end]);

  const hasSales = (data?.totalBdt ?? 0) > 0;

  return (
    <Modal title={data?.name || fallbackName} onClose={onClose} width={560}>
      {loading && <p className="bo-muted">{t('an.loading', lang)}</p>}
      {err && <p className="bo-err">{t('an.itemError', lang)}</p>}
      {data && !loading && (
        <>
          <div className="bo-line strong">
            <span>{formatTk(data.totalBdt)}</span>
            <span>{t('dash.sold', lang).replace('{n}', String(data.units))}</span>
          </div>
          <h4 className="bo-muted">{t('an.dailySales', lang)}</h4>
          {hasSales ? (
            <AreaTrend
              values={data.dailySales.map((d) => d.salesBdt)}
              labels={data.dailySales.map((d) => d.date.slice(5))}
              height={160}
            />
          ) : (
            <p className="bo-muted">{t('an.noSalesItem', lang)}</p>
          )}
        </>
      )}
    </Modal>
  );
}
