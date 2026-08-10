# QuickBytes Design System v2

**QuickBytes** (quickbytes.buzz) is a complete restaurant point-of-sale platform for small and medium restaurants in **Bangladesh**. Three surfaces — a phone app (the floor), a desktop counter station, and a hardware POS terminal — sync to one cloud backend. Six order channels (website, Facebook Messenger chatbot, table QR, waiter, counter, manager) flow into one queue with one lifecycle: **pending → accepted → completed**. KOT prints the moment an order is accepted.

- **Currency:** ৳ Taka (BDT), integer amounts, always tabular numerals
- **Languages:** English + বাংলা, switchable at runtime
- **Audience tiers:** owners (business-school fluent — COGS, prime cost, cohort LTV) and managers/waiters (social-app fluent, Bengali-first, icon-driven)
- **Source:** product specification pasted by the user (2026-06-12). No Figma, codebase, or font binaries were provided.

## Design philosophy (one sentence)

White surfaces, **calm royal-indigo blue** as the one primary — dense enough for a busy kitchen, modern enough to feel sharp.

## CONTENT FUNDAMENTALS

- **Tone:** direct, confident, zero fluff. Claims are concrete ("KOT prints the moment you accept — not when you remember to"), never vague ("streamline your operations").
- **Voice:** speaks to "you" (the owner/operator). The product is "QuickBytes" or "it", never "we're excited to…".
- **Owner-facing copy** uses real business vocabulary unapologetically: COGS, prime cost, contribution margin, cohort LTV, attach rate. Never dumbed down, never "coming soon".
- **Staff-facing copy** is short, action-first, icon-supported: "Accept", "Print KOT", "Stock-in". Every staff-facing string has a Bengali equivalent.
- **Casing:** sentence case for headings and buttons. UPPERCASE reserved for tiny tracked overlines (channel badges, "BYTES BOT" labels).
- **Numbers:** money always with ৳ prefix, integers only (৳18,450 — never ৳18,450.00). Order serials as #24. Tabular numerals everywhere money or quantity appears.
- **Emoji:** none. Not part of the brand.
- **Bengali:** real translations, not decoration. The EN/বাংলা toggle is a first-class feature and a selling point.

## VISUAL FOUNDATIONS

- **Color:** white surfaces on #F6F7F9 page; ink #1B2330; muted #8A93A3. Royal-indigo #2F4FE0 is the only primary — one primary action per screen. Blue press #2440C2; blue tint #EEF1FE (wash/selected/highlight); blue strong #1D339B (blue text on white). Navy #1E2A44 is the secondary action colour (paired footer: navy + blue).
- **Signals:** success #1E9E5A, warning #C98208, danger #D8434A, info = primary blue. Each has a soft tint. Destructive = red only.
- **Table / order states** use Petpooja-style pastel fills: running #DCEBFB, printed #E3F6EC, running KOT #FCF3CF, available #FFFFFF. Each with matching dark ink label.
- **Type:** Inter, weights 400–800. Tight tracking (-0.02em) on titles. Tabular numerals for all money/quantities. Bengali text uses Noto Sans Bengali.
- **Corners:** 8–16px. Cards 14–16px, buttons 12px, chips/pills fully round. Marketing can reach 20–24px for hero frames.
- **Elevation:** soft card shadow (0 1px 2px / 0 2px 8px) + 1px hairline; e3 for popovers/dropdowns; blue glow shadow for accent moments.
- **Backgrounds:** flat colour only. No gradients, no textures, no patterns, no hand-drawn illustration. A soft radial blue glow is permitted on the marketing site hero/CTA.
- **Hover:** slight darkening (or tint on white); **press:** darker still, no shrink transforms.
- **Animation:** restrained — quick fades and 150–200ms ease-out position/colour transitions. No bounces, no infinite loops.
- **Imagery:** real product screenshots or food photos when needed (user-supplied); never SVG illustration.
- **Touch targets:** ≥44px mobile, ≥40px desktop.
- **Layout:** primary actions live in the bottom bar on mobile, never the top. Desktop is a fixed 1280×800 canvas with an icon rail; nothing scrolls on the register screen.

## ICONOGRAPHY

No icon assets were provided. Recommended: **Lucide** (CDN: `https://unpkg.com/lucide@latest`) — 1.5–2px stroke, geometric, matches the calm/hairline aesthetic. Channel indicators may be tiny uppercase text badges (WEB, MSG, QR) where an icon would be ambiguous. Unicode glyphs used sparingly for inline actions (✕ reject). No emoji, ever. **The QuickBytes logo/wordmark** is a rounded square with a white lightning bolt on the brand blue.

## INDEX

- `styles.css` — global entry; imports everything under `tokens/`
- `tokens/` — `colors.css`, `typography.css`, `spacing.css`, `fonts.css`
- `guidelines/` — foundation specimen cards (Design System tab)
- `templates/landing-page/` — marketing landing page for quickbytes.buzz
- `SKILL.md` — agent skill entry point

**Not yet built** (next steps): reusable React components (Button, OrderCard, TableTile, ChatBubble…), UI kits for the three surfaces (mobile 410px, desktop 1280×800, terminal portrait).

## FONT SUBSTITUTION FLAG

Inter and Noto Sans Bengali are loaded from Google Fonts CDN — no font binaries were provided. If the brand owns self-hosted webfonts, add the files and replace the `@import` in `tokens/fonts.css` with `@font-face` rules.
