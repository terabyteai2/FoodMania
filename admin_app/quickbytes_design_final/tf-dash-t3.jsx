// Terafoods · Manage Mode — TIER 3 · Full-service
// Business: "Spice Garden" — full-service restaurant, 12 tables, Banani. Karim bhai.
// Priority scroll: NOW (money + live snapshot) → NEEDS YOU → ACTIONS → REVIEW → CLOSE.

const Dash_T3_Full = () => (
  <DashScreen navActive={2}>
    <DashHeader
      greet="Evening, Karim bhai" emoji=""
      biz="Spice Garden" bn="বনানী" date="Fri · 7:42 PM"
      tier="Full-service · 12 tables" tierBn="ফুল-সার্ভিস" tierTone="amber" badge={3}
    />

    {/* 1 · NOW — money hero with trend */}
    <Section top={4}>
      <EarnedCard
        amount="৳42,180"
        label="Earned today"
        bn="আজকের আয়"
        delta="12% vs yest" deltaUp
        note={<span>+৳4,640 over yesterday — <span style={{ color: DASH.onInk, fontWeight: 600 }}>strongest Friday in 3 weeks</span></span>}
        spark
      />
    </Section>

    {/* 2 · NOW — live snapshot */}
    <Section top={14}>
      <SecHead title="Right now" bn="এখন" />
      <TowerRow tiles={[
        { value: '7', vsub: '/12', sub: 'Tables seated', bn: 'টেবিল',   tone: 'amber' },
        { value: '4',              sub: 'In kitchen',   bn: 'কিচেনে',  tone: 'paper' },
        { value: '2',              sub: 'Late > 20m',   bn: 'দেরি',     tone: 'coral' },
      ]} />
    </Section>

    {/* 3 · NEEDS YOU */}
    <Section>
      <SecHead title="Needs you" bn="আপনার নজর চাই" count={2} />
      <AlertRow tag="LATE" tone="late" title="Table 6 · #137" sub="48 min waiting · Beef Tehari ×2" cta="Check" />
      <AlertRow tag="LOW"  tone="low"  title="Mutton stock · 0.8 kg left" sub="~3 more orders at today's pace" cta="Reorder" />
    </Section>

    {/* 4 · Quick actions */}
    <Section>
      <QuickActions actions={[
        { icon: 'plus', t: 'New order', accent: true },
        { icon: 'printer', t: 'Print bill' },
        { icon: 'bell', t: 'Call waiter' },
        { icon: 'chart', t: 'Reports' },
      ]} />
    </Section>

    {/* ─── REVIEW ─── */}
    <Section top={22}>
      <Divider label="Review" bn="পর্যালোচনা" />
    </Section>

    {/* 5 · Where money came from */}
    <Section top={14}>
      <SecHead title="Where it came from" bn="চ্যানেল" />
      <ChannelSplit rows={[
        { l: 'Dine-in',   bn: 'ডাইন-ইন',     v: '৳27.0k', pct: 64, accent: DASH.accent },
        { l: 'Takeaway',  bn: 'টেকঅ্যাওয়ে', v: '৳9.3k',  pct: 22, accent: DASH.ink },
        { l: 'Delivery',  bn: 'ডেলিভারি',    v: '৳5.9k',  pct: 14, accent: DASH.late },
      ]} />
    </Section>

    {/* 6 · Top movers */}
    <Section>
      <SecHead title="Top movers" bn="টপ আইটেম" action="See all" />
      <MoverRow rank={1} name="Chicken Biriyani" qty={22} rev="৳5,280" pct={1}    share="13%" />
      <MoverRow rank={2} name="Beef Tehari"      qty={12} rev="৳3,360" pct={0.64} share="8%" />
    </Section>

    {/* 7 · Close shift */}
    <Section top={14}>
      <div style={{ paddingBottom: 14 }}>
        <CloseCard amount="৳42,180" title="Close shift · hand over to night" kicker="Shift handover · ৳42,180" warn="9 open orders carry to next shift" />
      </div>
    </Section>
  </DashScreen>
);

Object.assign(window, { Dash_T3_Full });
