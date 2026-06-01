// Terafoods · Manage Mode — TIER 2 · Small dine-in
// Business: "Cha Ghor" — tea & snacks café, 6 tables, Mohammadpur. Owner: Shuvo.
// Priority scroll: NOW (money + floor) → NEEDS YOU (alerts + actions) → REVIEW → CLOSE.

const Dash_T2_Dinein = () => (
  <DashScreen navActive={2}>
    <DashHeader
      greet="Afternoon, Shuvo" emoji=""
      biz="Cha Ghor" bn="মোহাম্মদপুর" date="Sat · 3:08 PM"
      tier="Dine-in · 6 tables" tierBn="ডাইন-ইন" tierTone="paper" badge={1}
    />

    {/* 1 · NOW — the hero. numericHero = 48 w700; secondary callouts in the
        note stay at body weight, with explicit ink color (not onInk, which
        was rendering white-on-white). */}
    <Section top={4}>
      <EarnedCard
        amount="৳14,820"
        label="Earned today"
        bn="আজকের আয়"
        delta="8% vs yest" deltaUp
        note={<span>+<span style={{ color: DASH.ink, fontWeight: 600, ...DASH.num }}>৳1,090</span> over yesterday — <span style={{ color: DASH.ink, fontWeight: 600 }}>busy lunch rush</span></span>}
      />
    </Section>

    {/* 2 · NOW — floor glance */}
    <Section top={14}>
      <SecHead title="Floor" bn="টেবিল" action="3 of 6 busy" />
      <FloorMap
        cols={3}
        tables={[
          { n: 'T1', state: 'seated', cover: 2 },
          { n: 'T2', state: 'idle' },
          { n: 'T3', state: 'bill', cover: 4 },
          { n: 'T4', state: 'seated', cover: 3 },
          { n: 'T5', state: 'idle' },
          { n: 'T6', state: 'idle' },
        ]}
        legend={['idle', 'seated', 'bill']}
      />
    </Section>

    {/* 3 · NEEDS YOU */}
    <Section>
      <SecHead title="Needs you" bn="নজর দিন" count={1} />
      <AlertRow tag="LATE" tone="late" title="Table 3 · #84 · 24 min" sub="Cha + Singara · over the 20-min mark" cta="Check" />
    </Section>

    {/* 4 · Quick actions */}
    <Section>
      <QuickActions actions={[
        { icon: 'plus', t: 'New order', accent: true },
        { icon: 'printer', t: 'Print bill' },
      ]} />
    </Section>

    {/* ─── REVIEW ─── */}
    <Section top={22}>
      <Divider label="Review" bn="পর্যালোচনা" />
    </Section>

    <Section top={14}>
      <SecHead title="Top items" bn="টপ আইটেম" action="See all" />
      <MoverRow rank={1} name="Milk Tea (Cha)" qty={64} rev="৳1,920" pct={1} />
      <MoverRow rank={2} name="Singara" qty={48} rev="৳960" pct={0.5} />
      <MoverRow rank={3} name="Samosa" qty={31} rev="৳930" pct={0.48} />
    </Section>

    <Section top={14}>
      <div style={{ paddingBottom: 14 }}>
        <CloseCard amount="৳14,820" title="Close day · ৳14,820" kicker="End of day · দিন শেষ" warn="3 orders still open — settle before closing" />
      </div>
    </Section>
  </DashScreen>
);

Object.assign(window, { Dash_T2_Dinein });
