# QuickBytes Design System

**QuickBytes** (quickbytes.buzz) is a complete restaurant point-of-sale platform for small and medium restaurants in **Bangladesh**. Three surfaces — a phone app (the floor), a desktop counter station, and a hardware POS terminal — sync to one cloud backend. Six order channels (website, Facebook Messenger chatbot, table QR, waiter, counter, manager) flow into one queue with one lifecycle: **pending → accepted → completed**. KOT prints the moment an order is accepted.

- **Currency:** ৳ Taka (BDT), integer amounts, always tabular numerals
- **Languages:** English + বাংলা, switchable at runtime
- **Audience tiers:** owners (business-school fluent — COGS, prime cost, cohort LTV) and managers/waiters (social-app fluent, Bengali-first, icon-driven)
- **Source:** product specification pasted by the user (2026-06-12). No Figma, codebase, or font binaries were provided.

## Design philosophy (one sentence)

Mostly white with **one electric-lime moment per screen** — calm enough for a busy kitchen, sharp enough to feel modern.

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

- **Color:** white surfaces on #F7F8F4 page; ink #1A1E14; muted #878C79. Electric lime #99FF47 is the only accent and is rationed to one moment per screen (the primary action). Text on lime is always #14180E — **never white on lime**. Lime-family text on white uses #3E7E14. Soft wash #F0FADF for emphasis panels, accept states, bot bubbles, analytics hero cards.
- **Signals:** success #498F18, warning #B0760A, danger #D43A3F, info #3E6FE0.
- **Occupied tables are slate** (#EDF1F7 / #D5DEEC / #4C679C) — deliberately not lime, because occupied is a neutral state, not an action.
- **Type:** Inter, weights 400–800. Tight tracking (-0.02em) on titles. Tabular numerals for all money/quantities. Bengali text uses Noto Sans Bengali.
- **Corners:** ≤12px. Cards 12px, buttons/inputs 10px, chips 6px. Only toggles and nav pills are fully round.
- **Elevation:** hairline borders (#EDEEE8) instead of box shadows. A soft shadow is permitted only on popovers/dropdowns.
- **Backgrounds:** flat color only. No gradients, no textures, no patterns, no hand-drawn illustration.
- **Hover:** slight darkening (or wash tint on white); **press:** darker still, no shrink transforms.
- **Animation:** restrained — quick fades and 150–200ms ease-out position/color transitions. No bounces, no infinite loops.
- **Imagery:** real photos of food/restaurants when needed (user-supplied); never SVG illustration.
- **Touch targets:** ≥44px mobile, ≥40px desktop.
- **Layout:** primary actions live in the bottom bar on mobile, never the top. Desktop is a fixed 1280×800 canvas with a 92px icon rail; nothing scrolls on the register screen.

## ICONOGRAPHY

No icon assets were provided. Recommended: **Lucide** (CDN: `https://unpkg.com/lucide@latest`) — 1.5–2px stroke, geometric, matches the calm/hairline aesthetic. Channel indicators may be tiny uppercase text badges (WEB, MSG, QR) where an icon would be ambiguous. Unicode glyphs used sparingly for inline actions (✕ reject). No emoji, ever. **Flagged: a real QuickBytes logo/wordmark has not been provided** — current wordmark is typographic (lime square + "QuickBytes" in Inter 700).

## INDEX

- `styles.css` — global entry; imports everything under `tokens/`
- `tokens/` — `colors.css`, `typography.css`, `spacing.css`, `fonts.css`
- `guidelines/` — foundation specimen cards (Design System tab)
- `templates/landing-page/` — marketing landing page for quickbytes.buzz (template)
- `SKILL.md` — agent skill entry point

**Not yet built** (next steps): reusable React components (Button, OrderCard, TableTile, ChatBubble…), UI kits for the three surfaces (mobile 410px, desktop 1280×800, terminal portrait).

## FONT SUBSTITUTION FLAG

Inter and Noto Sans Bengali are loaded from Google Fonts CDN — no font binaries were provided. If the brand owns self-hosted webfonts, add the files and replace the `@import` in `tokens/fonts.css` with `@font-face` rules.
