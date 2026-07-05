// Shared KPI card for the back-office panes (mirrors the DayEnd card look).
export function StatCard({
  title, value, sub, subTone, accent,
}: {
  title: string;
  value: string;
  sub?: string;
  subTone?: 'up' | 'down' | '';
  accent?: boolean;
}) {
  return (
    <div className={`card bo-card ${accent ? 'accent' : ''}`}>
      <span className="bo-card-title">{title}</span>
      <span className="bo-card-value">{value}</span>
      {sub && <span className={`bo-card-sub ${subTone ?? ''}`}>{sub}</span>}
    </div>
  );
}
