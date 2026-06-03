Terafoods (TF) POS — Core Design System

Target & Context: Indoor Bangladeshi restaurants (Tier 2/3 small dine-in). Shared, budget Android devices (Helio G35/Snapdragon 4, 3–4GB RAM, 720p screens). Requires one-handed operation under indoor lighting.
Locale & Code: Bilingual (EN/BN). Source of truth: tf_design_system.dart + app_theme.dart.

─────────────────────────────────────────
1. CORE PRINCIPLES
─────────────────────────────────────────

    Restraint: Accent color (#4C1D5E) covers ≤ 5% of any screen (CTAs, focus rings). 95% remains near-monochrome violet-grey.

    Dominance Rule: Maximum one full-saturation accent element per visible viewport. Selected/active items drop to accentSoft background — which removes them from the saturation budget so the primary CTA stays dominant. accentMid secondary elements count toward the saturation budget; never place accent and accentMid in the same viewport.

    Glanceability: Operators scan rather than read; every screen must answer its primary question in under 2 seconds. The w700 hero number is the anchor — every other element on screen is subordinate to it.

    Performance Constraint: Visual decisions must respect the target low-end hardware. Zero-jank delivery over decorative animation.

─────────────────────────────────────────
2. CORE PALETTE
─────────────────────────────────────────

Scaffolding — Neutral-cool base. Keeps plum accent clean and uncontested.

    paper (#F8F8FA): Scaffold background. Near-white with the faintest violet cast — coheres with the plum accent, eliminates warmth conflict.

    surface (#FFFFFF): Cards, sheets, fields, inputs. Pure white for maximum ink contrast on content areas.

    surfaceSunk (#F1F1F5): Search field fills, wells, depressed areas. Violet-grey tint — clearly recessed without reading as blue or neutral grey.

Ink — Deep violet-black. Tonally related to accent; never competing.

    ink (#16101E): Primary text, headings, all w700 and w600 content. Near-black with violet undertone.

    inkSoft (#2D2438): Secondary dark. Subheadings, secondary emphasis, de-prioritised labels.

Secondary Text & Borders — Desaturated violet-grey.

    muted (#635B6E): Secondary text, helpers, eyebrow labels, placeholders. Desaturated violet — clearly subordinate, not cold grey.

    mutedSoft (#A097AB): Lightest readable text. Captions, timestamps, metadata only. Do not use for any interactive label.

    line (#E2DDE8): Default 0.5 px borders, card outlines on paper. Faint violet-grey.

    lineStrong (#CAC3D4): Stronger dividers, active card outlines, focused field rings (paired with accent glow, not used alone for focus).

─────────────────────────────────────────
3. ACCENT — Deep Plum
─────────────────────────────────────────

Professional, distinctive, non-food-coded. Reserved purely for primary interactive states.

    accent (#4C1D5E): Primary buttons, FAB, focused states, primary CTAs. Full saturation — one per viewport.

    accentDeep (#351244): Pressed/active states of accent elements only.

    accentMid (#6B3080): Secondary interactive elements (outlined buttons, secondary CTAs, active tab indicators). Never in the same viewport as a full accent element.

    accentSoft (#E8D8F0): Selected-state backgrounds. Pairs exclusively with ink (#16101E) or inkSoft (#2D2438) text on top. Never pair with muted or mutedSoft — this is a soft surface rule, same as signal soft surfaces.

    accentWash (#F4EDF8): Hover states, subtle background tints. Non-interactive use only — never the sole affordance for an interactive element.

    accentInk (#FFFFFF): Text and icons rendered on full-strength accent or accentDeep surfaces.

─────────────────────────────────────────
4. FUNCTIONAL SIGNALS — Functional Only, Never Decorative
─────────────────────────────────────────

    success (#15803D) / successSoft (#DCFCE7): Confirmed states, positive deltas, healthy metrics.

    warning (#B45309) / warningSoft (#FEF3C7): Low stock, caution states, capacity warnings.

    danger (#7F1D1D) / dangerSoft (#FEE2E2): Out of stock, critical alerts, negative deltas.

    urgent (#9A3412) / urgentSoft (#FFEDD5): Variance alerts, expedite signals.

Signal colors are functionally distinct from accent. On the violet-tinted base, all four signals retain clear perceptual separation from both the plum accent and from each other — no adjustments required.

─────────────────────────────────────────
5. CRITICAL COLOR LOGIC
─────────────────────────────────────────

    Deltas: Positive → success. Negative → danger. Accent is never used for data metrics.

    Inventory & Stock States:
        Low stock → warning tokens.
        Out of stock (alert) → danger tokens.
        Intentionally empty SKU (zero stock, no alert) → muted text on surface. No signal treatment.

    Soft Surface Pairing Rule: All soft surfaces — successSoft, warningSoft, dangerSoft, urgentSoft, accentSoft — pair exclusively with ink (#16101E), inkSoft (#2D2438), or their respective full-strength signal/accent color. Never pair soft surfaces with muted or mutedSoft. The contrast is insufficient and the hierarchy reads as broken.

    Focus States: Focused inputs use a lineStrong border + accentWash fill. Do not use full accent as a border color on inputs — reserve accent for interactive controls (buttons, FAB), not field chrome.

─────────────────────────────────────────
6. TYPOGRAPHY & HIERARCHY
─────────────────────────────────────────

Family & Weights

    Family: Inter across all content. Single family — unified weight control, superior legibility on 720p at w600 and w700.

    Weights in use: w400 · w600 · w700. Three rungs only.
        w700 — Hero display numbers and largest metrics. One per screen.
        w600 — All titles, card headers, UI labels, numeric values in lists.
        w400 — All body text, descriptions, metadata captions.
    The gap between w400 and w600 is the hierarchy engine. Do not introduce w500 — it sits ambiguously between the two and collapses the contrast.

    Tracking:
        Hero display (-0.03em): w700 at large sizes tightens into a single cohesive unit.
        Titles (-0.01em): Slightly tighter than body — reads as intentional, not default.
        Body (0): Normal tracking. Optimised for reading density on 720p.
        Eyebrows (0.07em): Wide tracking for uppercase section labels — creates visual separation from surrounding body content.

The Four Ladders

Ladder       | Token         | Size | Weight | Line Height | Primary Use Case
-------------|---------------|------|--------|-------------|----------------------------------------------
Display      | displayHero   | 48   | w700   | 1.00        | Single largest metric per screen (revenue, fleet total). One per screen, no exceptions.
             | displayLarge  | 36   | w700   | 1.05        | Secondary hero metrics (delta comparisons, sub-totals).
Title        | titleLarge    | 18   | w600   | 1.25        | Card titles, section headers, sheet headers, alert titles.
             | titleMedium   | 15   | w600   | 1.30        | Sub-card headers, list group labels, drawer section titles.
Body         | bodyLarge     | 15   | w400   | 1.55        | Primary readable content, item descriptions, alert body copy.
             | bodyMedium    | 14   | w400   | 1.50        | Standard body — item names in lists, settings labels, tab content.
             | bodySmall     | 12   | w400   | 1.45        | Metadata, timestamps, helper text, secondary captions.
Numeric      | numericHero   | 48   | w700   | 1.00        | Hero pricing and quantities (৳). Matches displayHero — the number IS the content.
(Tabular)    | numericMedium | 18   | w600   | Tabular     | Inline prices, ticket values, stock counts. w600 anchors the eye in dense list rows.
             | numericSmall  | 14   | w600   | Tabular     | Stat pill values, KPI tile numbers, compact table cells.
Label        | labelLarge    | 14   | w600   | Normal      | Button strings, tab labels, prominent UI control labels.
             | labelEyebrow  | 11   | w600   | Wide        | Uppercase section identifiers, category eyebrows. Always uppercase.

Sizing note: displayHero at 48px on a 720p screen (360dp logical width) occupies ~13% of screen width per character. At w700 with -0.03em tracking a 6-digit taka value (e.g. ৳14,820) fits comfortably within sp4 margins. Verify at implementation with the longest realistic value per context.

─────────────────────────────────────────
7. SPACING, SHAPES, LAYOUT & SHADOWS
─────────────────────────────────────────

Spacing (PosSpacing)

    sp1 (4 px) | sp2 (8 px) | sp3 (12 px) | sp4 (16 px) | sp5 (24 px) | sp6 (32 px)

    Standard Padding: Card contents & screen margins → sp4 (16 px). Card sibling gap → sp3 (12 px).

    Hero Clearance: displayHero and numericHero (48px w700) require sp3 (12 px) minimum above and sp2 (8 px) minimum below before the next element. The jump from 48px to any bodyMedium (14px) is extreme — insufficient spacing makes the hierarchy feel accidental rather than intentional.

    Section Gap: Between major scroll sections → sp5 (24 px). This is the primary visual breath on a dense analytics screen. Do not compress to sp4 — operators need the pause to register a section boundary while scanning.

Shapes (PosRadii) & Borders

    xs (6 px): Badges, signal chips, numeric pills.
    sm (10 px): Input fields, small buttons, eyebrow tags.
    md (14 px): Cards, bottom sheets, dialogs.
    pill (999 px): FAB, active tab selections, toggle switches.

    Borders: 0.5 px uniform width using line (#E2DDE8) as default, lineStrong (#CAC3D4) for active/focused states. No nested outlines. Cards on paper use line; cards on surface use no border (rely on shadow soft instead).

    accentSoft chips (selected state): Use pill radius (999 px) with accentSoft (#E8D8F0) fill and ink text. No accent border on the chip — the fill is the affordance.

Layout & Fixed Grids

    Floor Map Grid: 4 columns on 720p screens. Gaps → sp3 (12 px).

    KPI / Stat Rows: 3 columns for status pulse tiles; 4 columns for dashboard KPI and quick-action tiles. At 3 columns on 360dp logical width with sp4 margins, each tile is ~100dp wide — sufficient for numericSmall (14px w600) values with labelEyebrow above.

    Container Caps: Mobile → full viewport width minus sp4 (16 px) margins each side. Tablet → max-width 720 px centered.

    Hero Card: The top revenue/metric card on Review screens occupies full bleed width (no sp4 margin) with sp4 internal padding. Surface (#FFFFFF) background. This gives displayHero the full canvas it needs and visually anchors the scroll.

Stacking Order (Bottom Up)

    1. System Navigation Inset
    2. TfBottomNav — surface background, line top border.
    3. TfShiftStrip (Dashboard) OR TfStickyCTA (Flows) — raised shadow.
    4. TfFab — anchored bottom-right, sp4 margin from TfShiftStrip/TfStickyCTA above.

    FAB uses accent (#4C1D5E) fill with accentInk (#FFFFFF) icon. This is the one permitted full-saturation accent element in the bottom stacking zone. If a TfStickyCTA is also present (accent fill button), FAB must be suppressed — two accent elements in the stack violates the Dominance Rule.

Shadows (PosShadows)

    none: Default for cards on paper — relies on line border instead.

    soft (0 1px 2px rgba(22,16,30,0.05)): Stat tiles, KPI cards on surface.

    glow (0 4px 12px rgba(22,16,30,0.07)): Raised cards, FAB, active list items.

    raised (0 8px 24px rgba(22,16,30,0.09)): Sticky bottom CTAs, bottom sheets, dialogs.

    Shadow RGB base is ink (#16101E) → rgb(22,16,30). Shadows cast in violet-black. On the violet-tinted paper (#F8F8FA) base, these shadows read as depth without the blue-grey disconnect of neutral shadow values.

─────────────────────────────────────────
8. ICONOGRAPHY (TfIcon)
─────────────────────────────────────────

    Source: Lucide library only. 2 px stroke outlines. Fills and animated morphs are banned.

    Sizing (TfIconSize): xs (14) | sm (16) | md (20, default) | lg (24) | xl (32) | xxl (48).

    Color inheritance: Icons inherit parent text color. On paper or surface backgrounds, icons must use muted (#635B6E) minimum — never mutedSoft (#A097AB), which falls below 3:1 contrast on the violet-tinted base. Use explicit signal colors only for functional context (success checkmark, danger cross, warning triangle).

    Accent icons: Icons inside accent (#4C1D5E) or accentDeep surfaces use accentInk (#FFFFFF). Icons inside accentSoft surfaces use ink (#16101E).

─────────────────────────────────────────
9. PERFORMANCE & IMPLEMENTATION
─────────────────────────────────────────

    All static components must be compiled as const.

    Lists larger than 10 entries must use lazy-loaded ListView.builder with predefined fixed itemExtent.

    Image delivery must run through cached_network_image. Raw Image.network is banned. Menu items crop to 200×150 thumbnail files natively.

    Typography: Inter must be loaded as a bundled asset — do not rely on system font fallback. On low-end Helio G35 devices, system Inter variants may differ in weight rendering at w600/w700, collapsing the hierarchy contrast this system depends on.
