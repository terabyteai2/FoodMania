Terafoods (TF) POS — Core Design System

Target & Context: Indoor Bangladeshi restaurants (Tier 2/3 small dine-in). Shared, budget Android devices (Helio G35/Snapdragon 4, 3–4GB RAM, 720p screens). Requires one-handed operation under indoor lighting.
Locale & Code: Bilingual (EN/BN). Source of truth: tf_design_system.dart + app_theme.dart.
1. Core Principles

    Restraint: Accent color (#B8501F) covers ≤ 5% of any screen (CTAs, focus rings). 95% remains near-monochrome.

    Dominance Rule: Maximum one full-saturation accent element per visible viewport. Transitive selected items must drop to a soft surface to keep the primary CTA dominant.

    Glanceability: Operators scan rather than read; every screen must answer its primary question in under 2 seconds.

    Performance Constraint: Visual decisions must respect the target low-end hardware. Zero-jank delivery over decorative animation.

Core Palette

    paper (#FAFAF8): Warm off-white scaffold background.

    surface (#FFFFFF): Cards, sheets, fields, inputs.

    surfaceSunk (#F4F4F1): Search field fills, wells, depressed areas.

    ink (#0F1419) / inkSoft (#2A2F36): Primary text/headings, secondary dark.

    muted (#6B7280) / mutedSoft (#9CA3AF): Secondary text/helpers/eyebrows, placeholders.

    line (#E5E7EB) / lineStrong (#D1D5DB): Default 0.5 px borders, card outlines on paper.

Accent (Burnt Orange) — Warm, Food-Coded, Distinctive

    Rule: Accent never signals status or metrics. It is reserved purely for primary interactive states.

    accent (#B8501F): Primary buttons, FAB, focused states, primary CTAs.

    accentDeep (#8F3D14): Pressed states of accent elements.

    accentSoft (#F5D9C8): Selected-state backgrounds (pairs with ink text on top).

    accentWash (#FBEDE3): Subtle accent backgrounds, hovers.

    accentInk (#FFFFFF): Text and icons on full-strength accent surfaces.

Functional Signals — Functional Only, Never Decorative

    success (#15803D) / successSoft (#DCFCE7): Confirmed, healthy states, positive deltas only.

    warning (#B45309) / warningSoft (#FEF3C7): Low stock, caution, capacity warnings.

    danger (#7F1D1D) / dangerSoft (#FEE2E2): Out of stock, critical alerts, negative deltas.

    urgent (#9A3412) / urgentSoft (#FFEDD5): Variance alerts, expedite signals.

3. Critical Color Logic

    Deltas: Negative deltas use danger. Positive deltas use success. Accent is never used for data metrics.

    Inventory & Stock States:

        Low stock: Implements warning color tokens.

        Out of stock (Alert State): Implements danger color tokens.

        Intentionally empty SKU (Zero stock, no alert): Renders in neutral muted text on surface. Do not apply danger or warning treatments here.

    Soft Surfaces: All soft signal surfaces (successSoft, warningSoft, dangerSoft, urgentSoft, accentSoft) pair exclusively with ink or their respective full-strength signal color. Never pair them with muted.

4. Typography & Hierarchy
Typography Tokens

    Families: English → Inter, Bangla → Hind Siliguri.

    Weights: Only w400 (Body, captions) and w500 (Headings, UI labels). w600+ is forbidden to protect low-res Bangla legibility.

    Tracking: tight (-0.02em for hero scales), normal (0), wide (0.08em for uppercase eyebrows).

The Four Ladders
Ladder	Token	Size	Weight	Line Height	Primary Use Case
Display	

displayHero

displayLarge
	

44

36
	

w500

w500
	

1.05

1.10
	Single largest metric/total per screen.
Title	

titleLarge

titleMedium
	

18

16
	

w500

w500
	

1.30

1.35
	Card titles, alert/list headers. Pair with ink.
Body	

bodyLarge

bodyMedium

bodySmall
	

15

14

12
	

w400

w400

w400
	

1.50

1.45

1.40
	Readable text, descriptions, metadata captions.
Numeric (Tabular)	

numericHero

numericMedium
	

44

18
	

w500

w500
	Tabular	Use for all pricing, quantities, currencies (৳).
Label	

labelLarge

labelEyebrow
	

14

11
	

w500

w500
	

Normal

Wide
	Button strings; uppercase section identifiers.

Bilingual Rule: BN text runs 20–30% longer than EN and requires a +1 px line height offset. Fixed-width text wrappers are prohibited. Raw Text() widgets are banned; use TfText().
5. Spacing, Shapes, Layout & Shadows
Spacing (PosSpacing)

    sp1 (4 px) | sp2 (8 px) | sp3 (12 px) | sp4 (16 px) | sp5 (24 px) | sp6 (32 px)

    Standard Padding: Card contents & screen margins default to sp4 (16 px). Card sibling gap defaults to sp3 (12 px).

Shapes (PosRadii) & Borders

    xs (6 px): Badges, chips | sm (10 px): Inputs, small buttons | md (14 px): Cards, dialogs | pill (999 px): FAB, active selections.

    Borders: 0.5 px uniform width using line or lineStrong. No nested outlines.

Layout & Fixed Grids

    Floor Map Grid: 4 columns on 720p screens. Gaps use sp3.

    KPI rows / Quick Actions: 3 columns for status pulses; 4 columns for dashboard KPI tiles/actions.

    Container Caps: Mobile runs full viewport width minus sp4 margins. Tablet layouts are capped at a maximum width of 720 px centered.

Stacking Order (Bottom Up)

    System Navigation Inset → 2. TfBottomNav → 3. TfShiftStrip (Dashboard) OR TfStickyCTA (Flows) → 4. TfFab (Anchored bottom-right with sp4 margin from elements below).

Shadows (PosShadows)

    none: Default (relies on borders).

    soft (0 1px 2px rgba(15,20,25,0.05)): Stat tiles.

    glow (0 4px 12px rgba(15,20,25,0.06)): Raised items, FABs.

    raised (0 8px 24px rgba(15,20,25,0.08)): Sticky bottom CTAs, sheets.

6. Iconography (TfIcon)

    Source: Lucide library only. 2 px stroke outlines; fills and animated morphs are banned.

    Sizing (TfIconSize): xs (14) | sm (16) | md (20, Default) | lg (24) | xl (32) | xxl (48).

    Inheritance: Icons inherit parental text color natively. Use explicit signaling colors only for functional context (e.g., green checkmark for success, red cross for danger).

7. Performance & Implementation Code

    All static components must be compiled as const.

    Lists larger than 10 entries must utilize lazy-loaded ListView.builder with predefined fixed itemExtent.

    Image delivery must run through cached_network_image. Raw Image.network is banned. Menu items crop to 200×150 thumbnail files natively.
