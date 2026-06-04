// Terafoods · Computer OS — Day close (Z report) + Analytics screens

// ────────────────────────────────────────────────────────────────
// Hourly bar chart — used on Today + Footfall.
// pts: array of {h, v, vs?} — v is today, vs is the comparison average.
// ────────────────────────────────────────────────────────────────
const PcBarChart = ({ pts, height = 220, accent, vsAccent, yAxis, peakIdx, peakLabel }) => {
  const maxV = Math.max(...pts.flatMap(p => [p.v, p.vs || 0])) * 1.1;
  const padL = 44, padR = 16, padT = 14, padB = 28;
  const w = 760;
  const innerW = w - padL - padR;
  const innerH = height - padT - padB;
  const barW = (innerW / pts.length) * 0.55;
  const slotW = innerW / pts.length;
  const ticks = 4;
  const col = accent || PC.C.accent;
  const vsCol = vsAccent || PC.C.borderStrong;

  return (
    <svg width="100%" height={height} viewBox={`0 0 ${w} ${height}`} preserveAspectRatio="none" style={{ display: 'block' }}>
      {/* y grid */}
      {Array.from({ length: ticks + 1 }, (_, i) => {
        const y = padT + (innerH * i / ticks);
        const val = Math.round(maxV * (1 - i / ticks));
        return (
          <g key={i}>
            <line x1={padL} y1={y} x2={w - padR} y2={y} stroke={PC.C.border} strokeWidth="1" strokeDasharray={i === ticks ? '' : '3,3'} />
            {yAxis && (
              <text x={padL - 6} y={y + 3} fontSize="10" fill={PC.C.textTer} textAnchor="end" fontFamily={PC.C.mono} fontWeight="600">
                {yAxis(val)}
              </text>
            )}
          </g>
        );
      })}
      {/* bars */}
      {pts.map((p, i) => {
        const cx = padL + slotW * i + slotW / 2;
        const todayH = (p.v / maxV) * innerH;
        const vsH = p.vs ? (p.vs / maxV) * innerH : 0;
        const isPeak = i === peakIdx;
        return (
          <g key={i}>
            {/* vs shadow */}
            {p.vs && (
              <rect x={cx - barW / 2 - 2} y={padT + innerH - vsH}
                    width={barW + 4} height={vsH} fill={vsCol} opacity="0.5" rx="2" />
            )}
            <rect x={cx - barW / 2} y={padT + innerH - todayH}
                  width={barW} height={todayH} fill={isPeak ? PC.C.ink : col} rx="2" />
            <text x={cx} y={height - padB + 16} fontSize="10" fill={PC.C.textSec} textAnchor="middle" fontFamily={PC.C.mono} fontWeight="600">
              {p.h}
            </text>
            {isPeak && peakLabel && (
              <g>
                <rect x={cx - 36} y={padT + innerH - todayH - 24} width="72" height="18" rx="3" fill={PC.C.ink} />
                <text x={cx} y={padT + innerH - todayH - 11} fontSize="9.5" fill="#fff" textAnchor="middle" fontWeight="700" fontFamily={PC.C.mono} letterSpacing="0.4">
                  {peakLabel}
                </text>
              </g>
            )}
          </g>
        );
      })}
    </svg>
  );
};

// ────────────────────────────────────────────────────────────────
// 5 · Day close · Z report — receipt-style, narrow centered column
// ────────────────────────────────────────────────────────────────
const PC_Zreport = () => (
  <PcShell activeNav="reports" chromeTitle="Day close · Z report"
    title="Close day · Z report"
    sub="Monday 2 June · ready to lock the till"
    footerHints={[{ k: 'Ctrl+P', l: 'Print Z' }, { k: 'Ctrl+W', l: 'Send WhatsApp' }, { k: 'Ctrl+Enter', l: 'Lock & close' }, { k: 'Esc', l: 'Cancel' }]}>
    <div style={{ flex: 1, minWidth: 0, padding: 28, display: 'flex', justifyContent: 'center', gap: 24, overflow: 'hidden' }}>
      {/* receipt */}
      <div style={{
        width: 380, background: '#FCFAF5',
        boxShadow: '0 10px 30px rgba(22,16,30,0.12), 0 0 0 1px rgba(22,16,30,0.06)',
        padding: '28px 22px',
        fontFamily: '"Inter", monospace',
        // jagged top + bottom edges
        WebkitMaskImage: `url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='380' height='700' preserveAspectRatio='none'%3E%3Cpath d='M0 6 L8 0 L16 6 L24 0 L32 6 L40 0 L48 6 L56 0 L64 6 L72 0 L80 6 L88 0 L96 6 L104 0 L112 6 L120 0 L128 6 L136 0 L144 6 L152 0 L160 6 L168 0 L176 6 L184 0 L192 6 L200 0 L208 6 L216 0 L224 6 L232 0 L240 6 L248 0 L256 6 L264 0 L272 6 L280 0 L288 6 L296 0 L304 6 L312 0 L320 6 L328 0 L336 6 L344 0 L352 6 L360 0 L368 6 L376 0 L380 6 L380 694 L376 700 L368 694 L360 700 L352 694 L344 700 L336 694 L328 700 L320 694 L312 700 L304 694 L296 700 L288 694 L280 700 L272 694 L264 700 L256 694 L248 700 L240 694 L232 700 L224 694 L216 700 L208 694 L200 700 L192 694 L184 700 L176 694 L168 700 L160 694 L152 700 L144 694 L136 700 L128 694 L120 700 L112 694 L104 700 L96 694 L88 700 L80 694 L72 700 L64 694 L56 700 L48 694 L40 700 L32 694 L24 700 L16 694 L8 700 L0 694 Z' fill='black'/%3E%3C/svg%3E")`,
        WebkitMaskSize: '100% 100%',
        height: 690,
        overflow: 'hidden',
      }}>
        <div style={{ textAlign: 'center' }}>
          <div style={{ fontSize: 18, fontWeight: 700, letterSpacing: 4 }}>CHA GHOR</div>
          <div style={{ fontSize: 10.5, color: PC.C.textSec, marginTop: 3, letterSpacing: 1 }}>Sector 7 · Uttara · Dhaka 1230</div>
          <div style={{
            margin: '14px 0', borderTop: '1px dashed rgba(22,16,30,0.4)',
            borderBottom: '1px dashed rgba(22,16,30,0.4)', padding: '8px 0',
            fontSize: 13, fontWeight: 700, letterSpacing: 2,
          }}>Z REPORT · END OF DAY</div>
          <div style={{ fontSize: 10.5, color: PC.C.text, ...PC.C.num }}>
            Mon 02 Jun 2026 · 11:42 PM<br />
            Cashier · Rashed Hossain · ID 04<br />
            Z# 0428 · Shift 14h 24m
          </div>
        </div>

        <ReceiptSection label="SALES">
          {[
            ['Gross sales', '৳62,840'],
            ['Discounts', '−৳1,820'],
            ['Voids · 3', '−৳640'],
            ['Comps · 1', '−৳280'],
            ['Service · 5%', '৳2,985'],
            ['VAT · 5%', '৳3,124'],
          ]}
        </ReceiptSection>
        <ReceiptTotal label="NET SALES" v="৳66,209" />

        <ReceiptSection label="PAYMENTS">
          {[
            ['Cash', '৳28,420 · 43%'],
            ['bKash', '৳18,560 · 28%'],
            ['Nagad', '৳9,840 · 15%'],
            ['Card · Visa/Mc', '৳7,189 · 11%'],
            ['Pay later · khata', '৳2,200 ·  3%'],
          ]}
        </ReceiptSection>

        <ReceiptSection label="DRAWER">
          {[
            ['Opening cash', '৳12,910'],
            ['+ Cash sales', '+৳28,420'],
            ['− Paid out (3)', '−৳1,200'],
            ['Expected', '৳40,130'],
            ['Counted', '৳40,080'],
          ]}
        </ReceiptSection>
        <ReceiptTotal label="VARIANCE" v="−৳50" col={PC.C.late} />

        <ReceiptSection label="ORDERS">
          {[
            ['Dine-in · 38 covers', '24 orders'],
            ['Takeaway',           '18 orders'],
            ['Delivery',           '9 orders'],
            ['Avg ticket',         '৳1,310'],
          ]}
        </ReceiptSection>

        <div style={{ marginTop: 14, textAlign: 'center', fontSize: 10, color: PC.C.textSec, letterSpacing: 0.5 }}>
          ────  END OF Z REPORT  ────<br />
          Send to owner · WhatsApp Friday 8PM<br />
          Powered by Terafoods · v2.4.1
        </div>
      </div>

      {/* side panel */}
      <div style={{ width: 380, display: 'flex', flexDirection: 'column', gap: 14 }}>
        <PcCard pad={18}>
          <PcEyebrow color={PC.C.late}>Action needed before close</PcEyebrow>
          <div style={{ marginTop: 12, display: 'flex', flexDirection: 'column', gap: 8 }}>
            {[
              ['Variance', '−৳50 · within tolerance', PC.C.good],
              ['Open tables', '0 · all settled', PC.C.good],
              ['Unsynced orders', '2 · queued, will sync', PC.C.warn],
              ['Cash deposited', 'Pending · enter envelope ID', PC.C.late],
            ].map(([l, s, c], i) => (
              <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '8px 10px', borderRadius: 7, background: PC.C.surfaceAlt }}>
                <span style={{ width: 7, height: 7, borderRadius: 4, background: c }} />
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: 12.5, fontWeight: 600, color: PC.C.text }}>{l}</div>
                  <div style={{ fontSize: 11, color: PC.C.textSec, marginTop: 2 }}>{s}</div>
                </div>
              </div>
            ))}
          </div>
        </PcCard>

        <PcCard pad={18}>
          <PcEyebrow>Top 3 sellers today</PcEyebrow>
          <div style={{ marginTop: 10 }}>
            {[
              ['Chicken biryani', '46 plates', '৳14,720'],
              ['Beef bhuna', '28 plates', '৳7,840'],
              ['Cha doodh', '184 cups', '৳4,600'],
            ].map(([n, q, r], i) => (
              <div key={i} style={{
                display: 'flex', alignItems: 'center', gap: 12,
                padding: '8px 0', borderBottom: i < 2 ? `1px solid ${PC.C.border}` : 'none',
              }}>
                <span style={{ fontSize: 11, fontFamily: PC.C.mono, fontWeight: 700, color: PC.C.textTer, ...PC.C.num }}>0{i + 1}</span>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontSize: 13, fontWeight: 600, color: PC.C.text }}>{n}</div>
                  <div style={{ fontSize: 11, color: PC.C.textSec, ...PC.C.num }}>{q}</div>
                </div>
                <span style={{ fontSize: 13, fontWeight: 700, color: PC.C.text, ...PC.C.num }}>{r}</span>
              </div>
            ))}
          </div>
        </PcCard>

        <div style={{ flex: 1 }} />
        <PcBtn variant="ghost" icon="wifi" sk="Ctrl+W" full>Send to owner · WhatsApp</PcBtn>
        <PcBtn variant="surface" icon="printer" sk="Ctrl+P" full>Print Z report · RP-80</PcBtn>
        <PcBtn variant="dark" size="xl" icon="check" sk="Ctrl+Enter" full>Lock till · close day</PcBtn>
      </div>
    </div>
  </PcShell>
);

const ReceiptSection = ({ label, children }) => (
  <div style={{ marginTop: 14 }}>
    <div style={{ fontSize: 9.5, fontWeight: 700, color: PC.C.textSec, letterSpacing: 1, textAlign: 'center', marginBottom: 6 }}>
      ──  {label}  ──
    </div>
    {children.map(([l, v], i) => (
      <div key={i} style={{ display: 'flex', justifyContent: 'space-between', padding: '2px 0', fontSize: 11.5, color: PC.C.text }}>
        <span>{l}</span>
        <span style={{ fontWeight: 600, ...PC.C.num }}>{v}</span>
      </div>
    ))}
  </div>
);
const ReceiptTotal = ({ label, v, col }) => (
  <div style={{
    marginTop: 8, padding: '6px 0',
    borderTop: '1px solid rgba(22,16,30,0.4)',
    borderBottom: '1px double rgba(22,16,30,0.4)',
    display: 'flex', justifyContent: 'space-between',
  }}>
    <span style={{ fontSize: 12, fontWeight: 700, letterSpacing: 1 }}>{label}</span>
    <span style={{ fontSize: 14, fontWeight: 700, color: col || PC.C.ink, ...PC.C.num }}>{v}</span>
  </div>
);

// ────────────────────────────────────────────────────────────────
// 6 · Analytics · Today
// ────────────────────────────────────────────────────────────────
const PC_AnalyticsToday = () => {
  // hourly: 11am – 11pm
  const hours = ['11', '12', '13', '14', '15', '16', '17', '18', '19', '20', '21', '22'];
  const todayVals = [1200, 4800, 6400, 3200, 1800, 1400, 2200, 4600, 9200, 11800, 8400, 4200];
  const vsVals    = [1100, 4200, 5800, 3000, 2000, 1600, 2400, 4200, 8000, 10200, 7800, 3800];
  const points = hours.map((h, i) => ({ h, v: todayVals[i], vs: vsVals[i] }));
  return (
    <PcShell activeNav="reports" chromeTitle="Reports · today"
      title="Reports · today"
      sub="Mon 2 Jun · service in progress · refreshed 2s ago"
      topActions={
        <>
          <div style={{
            display: 'inline-flex', background: PC.C.surfaceAlt, borderRadius: 7, padding: 3,
            border: `1px solid ${PC.C.border}`,
          }}>
            {[['Today', true], ['Yesterday'], ['This week'], ['Month']].map(([l, on], i) => (
              <span key={i} style={{
                padding: '5px 12px', borderRadius: 5,
                background: on ? PC.C.surface : 'transparent',
                color: on ? PC.C.text : PC.C.textSec,
                border: on ? `1px solid ${PC.C.borderStrong}` : '1px solid transparent',
                fontSize: 12, fontWeight: 600,
              }}>{l}</span>
            ))}
          </div>
          <PcBtn variant="ghost" icon="printer" sk="Ctrl+P">Export PDF</PcBtn>
        </>
      }>
      <div style={{ flex: 1, padding: 20, overflow: 'hidden', display: 'flex', flexDirection: 'column', gap: 14 }}>
        {/* KPI row */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12 }}>
          <PcKpi label="Today's sales" value="৳58,400" sub="vs last Mon avg ৳52,200" delta="+11.9%" deltaUp />
          <PcKpi label="Orders" value="51" sub="38 covers · 13 takeaway" delta="+6" deltaUp />
          <PcKpi label="Avg ticket" value="৳1,145" sub="last 7 days ৳1,082" delta="+5.8%" deltaUp />
          <PcKpi label="Gross margin" value="58.4%" sub="₹ food cost ৳24,290" delta="−1.2%" />
        </div>

        {/* main chart + side */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 360px', gap: 12, flex: 1, minHeight: 0 }}>
          <PcCard pad={18} style={{ display: 'flex', flexDirection: 'column' }}>
            <PcSectionHead
              title="Hourly sales · today vs same weekday last 7"
              sub="Bars: today · faint band: average Mon for prior 7 weeks"
              right={
                <div style={{ display: 'flex', gap: 14, fontSize: 11, color: PC.C.textSec, fontFamily: PC.C.mono, fontWeight: 600 }}>
                  <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5 }}>
                    <span style={{ width: 10, height: 10, borderRadius: 2, background: PC.C.accent }} />Today
                  </span>
                  <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5 }}>
                    <span style={{ width: 10, height: 10, borderRadius: 2, background: PC.C.borderStrong }} />Mon avg
                  </span>
                </div>
              }
            />
            <div style={{ flex: 1, minHeight: 0 }}>
              <PcBarChart pts={points} height={280} accent={PC.C.accent}
                yAxis={v => v >= 1000 ? `৳${(v / 1000).toFixed(0)}k` : `৳${v}`}
                peakIdx={9} peakLabel="PEAK ৳11.8K" />
            </div>
            <div style={{ display: 'flex', gap: 18, marginTop: 14, padding: '12px 4px 0', borderTop: `1px solid ${PC.C.border}` }}>
              {[
                ['Peak hour', '8 PM', '৳11,800 · 9 orders'],
                ['Slow hour', '4 PM', '৳1,400 · 2 orders'],
                ['Lunch share', '31%', '৳18,100 · 11–3 PM'],
                ['Dinner share', '57%', '৳33,400 · 7–10 PM'],
              ].map(([l, v, s], i) => (
                <div key={i} style={{ flex: 1 }}>
                  <PcEyebrow>{l}</PcEyebrow>
                  <div style={{ fontSize: 18, fontWeight: 700, color: PC.C.ink, marginTop: 4, letterSpacing: -0.3, ...PC.C.num }}>{v}</div>
                  <div style={{ fontSize: 11, color: PC.C.textSec, marginTop: 3, ...PC.C.num }}>{s}</div>
                </div>
              ))}
            </div>
          </PcCard>

          <div style={{ display: 'flex', flexDirection: 'column', gap: 12, minHeight: 0 }}>
            {/* payment split */}
            <PcCard pad={16}>
              <PcSectionHead title="Payment method split" />
              <PcDonut data={[
                { l: 'Cash', v: 24800, c: PC.C.accent },
                { l: 'bKash', v: 16200, c: PC.C.accentMid },
                { l: 'Nagad', v: 9400, c: PC.C.inkRaised },
                { l: 'Card', v: 5800, c: PC.C.borderStrong },
                { l: 'Pay later', v: 2200, c: PC.C.textTer },
              ]} />
            </PcCard>

            <PcCard pad={16} style={{ flex: 1, minHeight: 0 }}>
              <PcSectionHead title="vs last Monday · this hour" sub="Quick variance" />
              {[
                ['Sales', '৳58,400', '+৳6,200', true],
                ['Avg ticket', '৳1,145', '+৳63', true],
                ['Covers/hr', '4.2', '+0.4', true],
                ['Voids', '3 · ৳640', '−1', true],
                ['Discounts', '৳1,820', '+৳420', false],
              ].map(([l, v, d, up], i) => (
                <div key={i} style={{ display: 'flex', alignItems: 'center', padding: '8px 0', borderBottom: i < 4 ? `1px solid ${PC.C.border}` : 'none' }}>
                  <span style={{ flex: 1, fontSize: 12.5, color: PC.C.textSec }}>{l}</span>
                  <span style={{ fontSize: 13, fontWeight: 700, color: PC.C.text, marginRight: 10, ...PC.C.num }}>{v}</span>
                  <span style={{
                    fontSize: 11, fontWeight: 700, padding: '2px 6px', borderRadius: 4,
                    background: up ? PC.C.goodSoft : PC.C.dangerSoft,
                    color: up ? PC.C.good : PC.C.danger, ...PC.C.num,
                  }}>{up ? '↑' : '↓'} {d}</span>
                </div>
              ))}
            </PcCard>
          </div>
        </div>
      </div>
    </PcShell>
  );
};

// donut + legend (used on the payment split card)
const PcDonut = ({ data }) => {
  const total = data.reduce((s, d) => s + d.v, 0);
  let acc = 0;
  const R = 44, S = 14;
  const C = 2 * Math.PI * R;
  return (
    <div style={{ display: 'flex', gap: 18, alignItems: 'center', marginTop: 4 }}>
      <svg width="120" height="120" viewBox="0 0 120 120">
        <circle cx="60" cy="60" r={R} fill="none" stroke={PC.C.surfaceAlt} strokeWidth={S} />
        {data.map((d, i) => {
          const frac = d.v / total;
          const dash = `${frac * C} ${C}`;
          const el = (
            <circle key={i} cx="60" cy="60" r={R} fill="none" stroke={d.c} strokeWidth={S}
                    strokeDasharray={dash} strokeDashoffset={-acc * C}
                    transform="rotate(-90 60 60)" strokeLinecap="butt" />
          );
          acc += frac;
          return el;
        })}
        <text x="60" y="56" fontSize="11" fill={PC.C.textSec} textAnchor="middle" fontFamily={PC.C.mono} fontWeight="700" letterSpacing="0.5">TOTAL</text>
        <text x="60" y="73" fontSize="15" fill={PC.C.ink} textAnchor="middle" fontWeight="700" style={{ ...PC.C.num }}>৳{(total / 1000).toFixed(1)}k</text>
      </svg>
      <div style={{ flex: 1, minWidth: 0 }}>
        {data.map((d, i) => (
          <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '4px 0' }}>
            <span style={{ width: 8, height: 8, borderRadius: 2, background: d.c, flexShrink: 0 }} />
            <span style={{ flex: 1, fontSize: 12, color: PC.C.text, fontWeight: 600 }}>{d.l}</span>
            <span style={{ fontSize: 12, color: PC.C.textSec, ...PC.C.num }}>{Math.round(d.v / total * 100)}%</span>
            <span style={{ fontSize: 12.5, fontWeight: 700, color: PC.C.text, marginLeft: 8, minWidth: 50, textAlign: 'right', ...PC.C.num }}>৳{(d.v / 1000).toFixed(1)}k</span>
          </div>
        ))}
      </div>
    </div>
  );
};

// ────────────────────────────────────────────────────────────────
// 7 · Analytics · Items (top sellers / slow movers / margin)
// ────────────────────────────────────────────────────────────────
const PC_ITEM_ROWS = [
  { n: 'Chicken biryani',  cat: 'Rice',  q: 46, rev: 14720, cost: 5800, margin: 60.6, t: 'top',  pts: [.6,.65,.7,.66,.72,.78,.82,.88,.84,.9,.96,1] },
  { n: 'Beef bhuna',       cat: 'Curry', q: 28, rev: 7840,  cost: 3520, margin: 55.1, t: 'top',  pts: [.5,.6,.55,.62,.66,.7,.72,.74,.76,.8,.84,.86] },
  { n: 'Cha · doodh',      cat: 'Tea',   q: 184, rev: 4600, cost: 1380, margin: 70.0, t: 'top',  pts: [.4,.5,.55,.6,.66,.7,.74,.78,.84,.88,.92,1] },
  { n: 'Naan · butter',    cat: 'Snack', q: 96, rev: 4800,  cost: 1440, margin: 70.0, t: 'top',  pts: [.4,.46,.5,.55,.6,.62,.65,.7,.74,.78,.82,.84] },
  { n: 'Chicken tikka',    cat: 'Kebab', q: 22, rev: 4840,  cost: 1750, margin: 63.8, t: 'top',  pts: [.3,.32,.35,.4,.42,.46,.5,.55,.6,.66,.7,.74] },
  { n: 'Beef shashlik',    cat: 'Kebab', q: 14, rev: 5040,  cost: 2520, margin: 50.0, t: 'top',  pts: [.2,.22,.25,.3,.36,.42,.5,.56,.62,.68,.74,.8] },
  { n: 'Mutton rezala',    cat: 'Curry', q: 4,  rev: 1520,  cost: 920,  margin: 39.5, t: 'slow', pts: [.4,.36,.32,.3,.28,.24,.22,.2,.18,.16,.14,.12] },
  { n: 'Firni',            cat: 'Dess.', q: 3,  rev: 300,   cost: 80,   margin: 73.3, t: 'slow', pts: [.5,.4,.36,.3,.26,.22,.2,.18,.16,.14,.12,.1] },
];

const PC_AnalyticsItems = () => (
  <PcShell activeNav="reports" chromeTitle="Reports · items"
    title="Reports · items"
    sub="Last 7 days · 38 SKUs sold · ranked by revenue"
    topActions={
      <>
        <div style={{
          display: 'inline-flex', background: PC.C.surfaceAlt, borderRadius: 7, padding: 3,
          border: `1px solid ${PC.C.border}`,
        }}>
          {[['Top sellers', true], ['Slow movers'], ['Best margin'], ['Worst margin']].map(([l, on], i) => (
            <span key={i} style={{
              padding: '5px 12px', borderRadius: 5,
              background: on ? PC.C.surface : 'transparent',
              color: on ? PC.C.text : PC.C.textSec,
              border: on ? `1px solid ${PC.C.borderStrong}` : '1px solid transparent',
              fontSize: 12, fontWeight: 600,
            }}>{l}</span>
          ))}
        </div>
        <PcBtn variant="ghost" icon="printer" sk="Ctrl+P">Export CSV</PcBtn>
      </>
    }>
    <div style={{ flex: 1, padding: 20, overflow: 'hidden', display: 'flex', gap: 14 }}>
      {/* main table */}
      <PcCard pad={0} style={{ flex: 1, minWidth: 0, overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
        <div style={{ padding: '16px 18px 0' }}>
          <PcSectionHead
            title="Top sellers · last 7 days"
            sub="Click a row to see the daily trend · right-click for context menu"
            right={
              <div style={{ display: 'flex', gap: 6 }}>
                {['Rice', 'Curry', 'Tea', 'Kebab', 'Snack', 'Dessert'].map((c, i) => (
                  <span key={i} style={{
                    padding: '4px 9px', borderRadius: 6,
                    background: i === 0 ? PC.C.accentSoft : PC.C.surfaceAlt,
                    color: i === 0 ? PC.C.accent : PC.C.textSec,
                    fontSize: 11, fontWeight: 700,
                  }}>{c}</span>
                ))}
              </div>
            }
          />
        </div>
        {/* table */}
        <div style={{ flex: 1, minHeight: 0, overflowY: 'hidden', display: 'flex', flexDirection: 'column' }}>
          <div style={{
            display: 'grid', gridTemplateColumns: '40px 1.5fr 90px 70px 110px 110px 100px 1fr',
            gap: 12, padding: '10px 18px', background: PC.C.surfaceAlt,
            borderTop: `1px solid ${PC.C.border}`, borderBottom: `1px solid ${PC.C.border}`,
            position: 'sticky', top: 0,
          }}>
            {['#', 'ITEM', 'CATEGORY', 'QTY', 'GROSS', 'EST. COST', 'MARGIN %', '7-DAY TREND'].map((h, i) => (
              <span key={i} style={{
                fontSize: 9.5, fontFamily: PC.C.mono, fontWeight: 700,
                color: PC.C.textSec, letterSpacing: 0.7,
                textAlign: i >= 3 && i <= 6 ? 'right' : 'left',
              }}>{h}</span>
            ))}
          </div>
          {PC_ITEM_ROWS.map((r, i) => {
            const marginTone = r.margin >= 60 ? PC.C.good : r.margin >= 50 ? PC.C.text : PC.C.late;
            return (
              <div key={i} style={{
                display: 'grid', gridTemplateColumns: '40px 1.5fr 90px 70px 110px 110px 100px 1fr',
                gap: 12, padding: '12px 18px', alignItems: 'center',
                borderBottom: `1px solid ${PC.C.border}`,
                background: i === 0 ? PC.C.accentWash : PC.C.surface,
              }}>
                <span style={{ fontSize: 11, fontFamily: PC.C.mono, fontWeight: 700, color: PC.C.textTer, ...PC.C.num }}>
                  {String(i + 1).padStart(2, '0')}
                </span>
                <div>
                  <div style={{ fontSize: 13.5, fontWeight: 600, color: PC.C.text }}>{r.n}</div>
                  <div style={{ fontSize: 11, color: PC.C.textTer, marginTop: 2, fontFamily: PC.C.mono, fontWeight: 600 }}>
                    {r.t === 'slow' ? 'SLOW · consider removing / promoting' : 'TRENDING'}
                  </div>
                </div>
                <span style={{ fontSize: 12, color: PC.C.textSec, fontWeight: 600 }}>{r.cat}</span>
                <span style={{ fontSize: 13.5, fontWeight: 700, color: PC.C.text, textAlign: 'right', ...PC.C.num }}>{r.q}</span>
                <span style={{ fontSize: 13.5, fontWeight: 700, color: PC.C.text, textAlign: 'right', ...PC.C.num }}>৳{r.rev.toLocaleString()}</span>
                <span style={{ fontSize: 12.5, color: PC.C.textSec, textAlign: 'right', ...PC.C.num }}>৳{r.cost.toLocaleString()}</span>
                <span style={{ fontSize: 13.5, fontWeight: 700, color: marginTone, textAlign: 'right', ...PC.C.num }}>{r.margin.toFixed(1)}%</span>
                <div style={{ paddingLeft: 8 }}>
                  <PcSpark points={r.pts} height={28} accent={r.t === 'slow' ? PC.C.late : PC.C.accent} fill />
                </div>
              </div>
            );
          })}
        </div>
      </PcCard>

      {/* right · 'remove' candidates */}
      <div style={{ width: 280, display: 'flex', flexDirection: 'column', gap: 12 }}>
        <PcCard pad={16}>
          <PcEyebrow>Suggestion · slow movers</PcEyebrow>
          <div style={{ fontSize: 13, color: PC.C.text, marginTop: 8, lineHeight: 1.5 }}>
            <b>Mutton rezala</b> and <b>Firni</b> have sold fewer than 5 units in 7 days. Consider removing or running a promo.
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 6, marginTop: 12 }}>
            <PcBtn variant="surface" size="sm">Promo</PcBtn>
            <PcBtn variant="surface" size="sm">Remove</PcBtn>
          </div>
        </PcCard>

        <PcCard pad={16}>
          <PcEyebrow>Gross profit · last 7 days</PcEyebrow>
          <div style={{ fontSize: 28, fontWeight: 700, color: PC.C.ink, marginTop: 8, letterSpacing: '-0.025em', ...PC.C.num }}>
            ৳248,420
          </div>
          <div style={{ fontSize: 12, color: PC.C.textSec, marginTop: 4, ...PC.C.num }}>
            ৳406,200 gross · ৳157,780 est. food cost
          </div>
          <div style={{ marginTop: 12 }}>
            <PcSpark height={48} fill points={[.5,.55,.62,.7,.66,.78,.84,.78,.88,.92,.96,1]} />
          </div>
        </PcCard>

        <PcCard pad={16} style={{ flex: 1 }}>
          <PcEyebrow>Quick filter</PcEyebrow>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 4, marginTop: 10 }}>
            {[
              ['All categories', 38, true],
              ['Veg only', 14],
              ['< ৳100 price', 12],
              ['Margin < 40%', 4],
              ['Added last 30 days', 6],
            ].map(([l, n, on], i) => (
              <div key={i} style={{
                display: 'flex', alignItems: 'center', padding: '7px 9px', borderRadius: 7,
                background: on ? PC.C.surfaceAlt : 'transparent',
              }}>
                <span style={{
                  width: 14, height: 14, borderRadius: 4, border: `1.5px solid ${on ? PC.C.accent : PC.C.borderStrong}`,
                  background: on ? PC.C.accent : 'transparent', marginRight: 8, color: '#fff',
                  display: 'grid', placeItems: 'center', fontSize: 9, fontWeight: 700,
                }}>{on ? '✓' : ''}</span>
                <span style={{ flex: 1, fontSize: 12.5, color: PC.C.text, fontWeight: on ? 700 : 500 }}>{l}</span>
                <span style={{ fontSize: 11, color: PC.C.textTer, fontFamily: PC.C.mono, fontWeight: 700, ...PC.C.num }}>{n}</span>
              </div>
            ))}
          </div>
        </PcCard>
      </div>
    </div>
  </PcShell>
);

// ────────────────────────────────────────────────────────────────
// 8 · Analytics · Staff & footfall
// ────────────────────────────────────────────────────────────────
const PC_STAFF = [
  { n: 'Salma Rahman',   r: 'Waiter',  o: 18, c: 64, rev: 22400, voids: 1, disc: 420, top: true,  pts: [.6,.7,.74,.82,.88,.94,1] },
  { n: 'Mahbub Alam',    r: 'Waiter',  o: 14, c: 51, rev: 18200, voids: 0, disc: 280, pts: [.5,.55,.6,.66,.72,.78,.84] },
  { n: 'Karim Hossain',  r: 'Counter', o: 22, c: 0,  rev: 12800, voids: 2, disc: 880, pts: [.4,.46,.52,.58,.64,.7,.74] },
  { n: 'Anika Sultana',  r: 'Waiter',  o: 11, c: 38, rev: 9400,  voids: 0, disc: 100, pts: [.3,.32,.38,.44,.5,.56,.62] },
];

const PC_AnalyticsStaff = () => {
  // hourly footfall — covers per hour
  const hours = ['11', '12', '13', '14', '15', '16', '17', '18', '19', '20', '21', '22'];
  const cov = [2, 8, 14, 6, 3, 2, 4, 10, 22, 28, 18, 8];
  const points = hours.map((h, i) => ({ h, v: cov[i] }));
  return (
    <PcShell activeNav="reports" chromeTitle="Reports · staff & footfall"
      title="Reports · staff & footfall"
      sub="Last 7 days · 4 staff active · weekly digest sent to owner Fri 8 PM"
      topActions={
        <PcBtn variant="ghost" icon="printer" sk="Ctrl+P">Export PDF</PcBtn>
      }>
      <div style={{ flex: 1, padding: 20, overflow: 'hidden', display: 'flex', flexDirection: 'column', gap: 14 }}>
        {/* staff table */}
        <PcCard pad={0}>
          <div style={{ padding: '14px 18px' }}>
            <PcSectionHead title="Staff performance · last 7 days" sub="Logins by waiter / counter cashier · sorted by revenue" />
          </div>
          <div style={{
            display: 'grid', gridTemplateColumns: '60px 1.5fr 90px 70px 90px 110px 70px 90px 1fr',
            gap: 12, padding: '10px 18px',
            background: PC.C.surfaceAlt, borderTop: `1px solid ${PC.C.border}`, borderBottom: `1px solid ${PC.C.border}`,
          }}>
            {['#', 'STAFF', 'ROLE', 'ORDERS', 'COVERS', 'REVENUE', 'VOIDS', 'DISCOUNTS', 'TREND'].map((h, i) => (
              <span key={i} style={{
                fontSize: 9.5, fontFamily: PC.C.mono, fontWeight: 700,
                color: PC.C.textSec, letterSpacing: 0.7,
                textAlign: i >= 3 && i <= 7 ? 'right' : 'left',
              }}>{h}</span>
            ))}
          </div>
          {PC_STAFF.map((s, i) => (
            <div key={i} style={{
              display: 'grid', gridTemplateColumns: '60px 1.5fr 90px 70px 90px 110px 70px 90px 1fr',
              gap: 12, padding: '12px 18px', alignItems: 'center',
              borderBottom: i < PC_STAFF.length - 1 ? `1px solid ${PC.C.border}` : 'none',
              background: i === 0 ? PC.C.accentWash : 'transparent',
            }}>
              <div style={{
                width: 32, height: 32, borderRadius: 16,
                background: s.top ? PC.C.accent : PC.C.surfaceAlt,
                color: s.top ? PC.C.accentInk : PC.C.text,
                display: 'grid', placeItems: 'center', fontSize: 12, fontWeight: 700,
              }}>{s.n.split(' ').map(x => x[0]).join('')}</div>
              <div>
                <div style={{ fontSize: 13.5, fontWeight: 600, color: PC.C.text }}>{s.n}</div>
                {s.top && (
                  <div style={{ fontSize: 10, fontFamily: PC.C.mono, fontWeight: 700, color: PC.C.accent, marginTop: 2, letterSpacing: 0.6 }}>
                    TOP THIS WEEK
                  </div>
                )}
              </div>
              <span style={{ fontSize: 12, color: PC.C.textSec, fontWeight: 600 }}>{s.r}</span>
              <span style={{ fontSize: 13, fontWeight: 700, color: PC.C.text, textAlign: 'right', ...PC.C.num }}>{s.o}</span>
              <span style={{ fontSize: 13, color: PC.C.text, textAlign: 'right', ...PC.C.num }}>{s.c || '—'}</span>
              <span style={{ fontSize: 13.5, fontWeight: 700, color: PC.C.ink, textAlign: 'right', ...PC.C.num }}>৳{s.rev.toLocaleString()}</span>
              <span style={{
                fontSize: 12.5, fontWeight: 700, textAlign: 'right',
                color: s.voids > 1 ? PC.C.late : PC.C.text, ...PC.C.num,
              }}>{s.voids}</span>
              <span style={{
                fontSize: 12.5, color: s.disc > 500 ? PC.C.warn : PC.C.text, textAlign: 'right',
                fontWeight: 600, ...PC.C.num,
              }}>৳{s.disc}</span>
              <div style={{ paddingLeft: 8 }}>
                <PcSpark height={24} accent={s.top ? PC.C.accent : PC.C.textSec} points={s.pts} />
              </div>
            </div>
          ))}
        </PcCard>

        {/* footfall + weekly digest */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 360px', gap: 12, flex: 1, minHeight: 0 }}>
          <PcCard pad={18} style={{ display: 'flex', flexDirection: 'column' }}>
            <PcSectionHead
              title="Hourly footfall · today"
              sub="Covers per hour · peak helps you schedule the next week"
            />
            <div style={{ flex: 1, minHeight: 0 }}>
              <PcBarChart pts={points} height={200} accent={PC.C.accentMid}
                yAxis={v => `${v}`} peakIdx={9} peakLabel="PEAK 28P" />
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 14, marginTop: 12, padding: '12px 4px 0', borderTop: `1px solid ${PC.C.border}` }}>
              {[
                ['Total covers', '125'],
                ['Peak · 8 PM', '28 covers'],
                ['Avg wait at peak', '8 min'],
                ['Suggestion', 'Add 1 waiter 7–9 PM'],
              ].map(([l, v], i) => (
                <div key={i}>
                  <PcEyebrow>{l}</PcEyebrow>
                  <div style={{ fontSize: 15, fontWeight: 700, color: i === 3 ? PC.C.accent : PC.C.ink, marginTop: 4, letterSpacing: -0.2, ...PC.C.num }}>{v}</div>
                </div>
              ))}
            </div>
          </PcCard>

          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            <PcCard pad={16}>
              <PcEyebrow>Weekly summary · WhatsApp digest</PcEyebrow>
              <div style={{
                marginTop: 12, padding: '12px 14px', borderRadius: 10,
                background: PC.C.bg, border: `1px dashed ${PC.C.borderStrong}`,
                fontSize: 12.5, color: PC.C.text, lineHeight: 1.55,
              }}>
                <div style={{ fontWeight: 700 }}>Cha Ghor · week 22</div>
                <div style={{ marginTop: 6, color: PC.C.textSec }}>
                  Sales <b style={{ color: PC.C.text }}>৳406,200</b> (↑11% vs prev). Best day Sat ৳72,400.
                  Top item: Chicken biryani (212 plates). Slow: Mutton rezala.
                  Margin <b style={{ color: PC.C.good }}>58.4%</b>. Voids ৳3,420 (Karim ×6).
                </div>
                <div style={{ marginTop: 8, fontSize: 11, color: PC.C.textTer, fontFamily: PC.C.mono, fontWeight: 700, letterSpacing: 0.5 }}>
                  + sales chart · attached as image
                </div>
              </div>
              <div style={{ marginTop: 12, display: 'flex', alignItems: 'center', gap: 8 }}>
                <span style={{
                  display: 'inline-flex', alignItems: 'center', gap: 6,
                  padding: '5px 10px', borderRadius: 999,
                  background: PC.C.goodSoft, color: PC.C.good,
                  fontSize: 11, fontWeight: 700, fontFamily: PC.C.mono, letterSpacing: 0.3,
                }}>
                  <span style={{ width: 6, height: 6, borderRadius: 3, background: PC.C.good }} />
                  AUTO-SEND FRI 8PM
                </span>
                <div style={{ flex: 1 }} />
                <PcBtn variant="ghost" size="sm">Edit</PcBtn>
                <PcBtn variant="surface" size="sm">Preview</PcBtn>
              </div>
            </PcCard>

            <PcCard pad={16} style={{ flex: 1 }}>
              <PcEyebrow>Owner notes · staff watch</PcEyebrow>
              <div style={{ marginTop: 10, display: 'flex', flexDirection: 'column', gap: 8 }}>
                {[
                  ['Karim', '6 voids in 7 days · review', PC.C.late],
                  ['Anika', 'New · onboarding day 4', PC.C.text],
                  ['Salma', 'Top performer · consider raise', PC.C.good],
                ].map(([n, s, c], i) => (
                  <div key={i} style={{ display: 'flex', alignItems: 'flex-start', gap: 10, padding: '8px 10px', borderRadius: 7, background: PC.C.surfaceAlt }}>
                    <span style={{
                      width: 24, height: 24, borderRadius: 12, background: PC.C.surface,
                      border: `1px solid ${PC.C.border}`, display: 'grid', placeItems: 'center',
                      fontSize: 10, fontWeight: 700, color: PC.C.text, flexShrink: 0,
                    }}>{n[0]}</span>
                    <div style={{ flex: 1 }}>
                      <div style={{ fontSize: 12.5, fontWeight: 600, color: PC.C.text }}>{n}</div>
                      <div style={{ fontSize: 11.5, color: c, marginTop: 2 }}>{s}</div>
                    </div>
                  </div>
                ))}
              </div>
            </PcCard>
          </div>
        </div>
      </div>
    </PcShell>
  );
};

Object.assign(window, { PC_Zreport, PC_AnalyticsToday, PC_AnalyticsItems, PC_AnalyticsStaff, PcBarChart, PcDonut });
