# Terafoods (TF) POS — Design System

**Target:** mobile-first restaurant POS for budget Android (MediaTek Helio G35, 3–4 GB RAM)
**Locale:** bilingual EN / BN, switched by the active app locale (auto-handled by Tf widgets)
**Source of truth:** [`tf_design_system.dart`](../widgets/tf_design_system.dart) + [`app_theme.dart`](app_theme.dart)

Every UI surface in `admin_app/lib/src/features/**` is built from the `Tf*` primitives below. Do not introduce a parallel widget set, do not hand-roll equivalents, and do not deviate from the tokens listed here.

---

## 1. Color (`PosColors`)

| Token | Hex | Use |
|---|---|---|
| `primary` | `#F5C127` | Brand CTAs, focus accents, primary buttons |
| `primaryDark` / `slate` | `#1C1A17` | Headings, body text, dark surfaces, text on primary buttons |
| `background` | `#F7F4EE` | Scaffold background — warm off-white reduces glare in harsh light |
| `surface` | `#FFFFFF` | Cards, sheets, text-field fills |
| `muted` | `#888780` | Secondary text, section headers, helpers |
| `line` / `lineStrong` | `#E8E4DC` | All 0.5px borders and dividers |
| `success` / `successSoft` | `#3D7A5A` / `#EAF4EE` | Accepted orders, kitchen print confirm, active tables |
| `warning` / `warningSoft` | `#E28714` / `#FFF3E0` | Low stock, printer offline, modified-order notices |
| `danger` / `dangerSoft` | `#A32D2D` / `#FCEBEB` | Cancellations, deletions, destructive confirmations |
| `coral` / `coralSoft` | `#E88060` / `#FBE4DB` | Late/expedite signals (use sparingly) |
| `primarySoft` / `primaryWash` | `#FEF1C5` / `#FFF9E0` | Brand-tinted soft surfaces |

**Rules**
- Always reference `PosColors.*`. Hex literals (`Color(0xFF…)`) are forbidden in feature code; the only legal sites are the definitions in `app_theme.dart` and the food-tone palette in `menu_image_view.dart`.
- Primary yellow and warning amber are deliberately decoupled — never reuse the brand color to signal a warning.
- Third-party brand colors (bKash pink, etc.) are not part of `PosColors`. If a screen genuinely needs one, keep it scoped to that screen — do not promote it.

---

## 2. Typography

### Families
- English → `Inter`
- Bangla → `Hind Siliguri`

Always select the family with `tfFontFamily(context)`. Never write `'Inter'` or `'Hind Siliguri'` as a string literal in feature code. The `Tf*` widgets do this for you.

### Weights
Only two weights exist in app code:

| Weight | Use |
|---|---|
| `FontWeight.w400` | Body, helpers, descriptions |
| `FontWeight.w500` | Headings, buttons, labels, emphasis |

`w600`/`w700`/`w800`/`w900` are **banned**. Stronger visual emphasis comes from color, size, or surface contrast — not weight.

### Sizes (`theme.textTheme`)

| Style | Size | Use |
|---|---|---|
| `displaySmall` | 28 | Hero numerals |
| `headlineMedium` | 24 | Screen titles when not using `TfAppBar` |
| `titleLarge` | 18 | Card/section titles |
| `titleMedium` | 15 | Sub-titles |
| `titleSmall` | 13 | Small titles |
| `bodyLarge` | 15 | Body text |
| `bodyMedium` | 14 | Default body |
| `bodySmall` | 12 | Helpers, captions |
| `labelLarge` | 14 | Button labels |

Prefer `Theme.of(context).textTheme.*` over inline `TextStyle(fontSize:…)`. Inline sizes are acceptable only when the design genuinely needs a non-theme value.

### Bidirectional text
- `TfText(string)` converts Western digits to Bengali numerals (০–৯) in BN locale automatically.
- `TfMoney(amount)` formats with the Taka symbol (`৳`) using the active locale.
- Raw `Text(…)` is **banned** in feature code — always `TfText`.

---

## 3. Shape & spacing

### Radii (`PosRadii`)

| Token | Value | Use |
|---|---|---|
| `xs` | 8 | Bar-chart bars, very small chips |
| `sm` / `md` / `lg` / `xl` | 12 | Default for cards, buttons, fields, sheets, dialogs |
| `pill` | 999 | Pill buttons, circular avatars/dots, FAB |

Only `8`, `12`, and `999` are allowed. Do not introduce 10, 14, 16, 20, etc. — they create visible discordance.

**Narrow exception:** `circular(2)` is permitted for thin accent stripes only — `TfRail`, tab/bottom-nav indicator bars, hairline status indicators. These are 2–4px wide elements where any larger radius would visibly round the whole shape. Anything wider must use a `PosRadii` token.

PDF rendering (`pw.BorderRadius` / `pw.Radius` in `qr_pdf_screen.dart`) is out of scope — it follows the `printing` package conventions, not Flutter widget radii.

### Borders
- All borders are `0.5px`, using `PosColors.line` (or `lineStrong` on cards floating on `background`).
- One border per surface — no double borders, no nested outlines.

### Shadows (`PosShadows`)

| Token | Use |
|---|---|
| `card` | Empty list — most cards rely on the 0.5px border, not a shadow |
| `glow` | Single layer, `blurRadius: 8`, `offset: (0, 4)` — default for raised cards / FABs |
| `raised` | Single layer, `blurRadius: 8`, `offset: (0, 6)` — for sheet-like floating surfaces |

**Hard performance rules** (Mali/PowerVR-friendly):
- `blurRadius ≤ 8` anywhere on screen.
- `boxShadow` lists must have at most one entry.
- No `BackdropFilter` / `ImageFilter.blur`.
- No Material 3 surface-tint overrides — the theme already sets `surfaceTintColor: Colors.transparent` for dialogs, cards, sheets, app bars.

### Padding conventions
- Card content: `TfCard` default `EdgeInsets.fromLTRB(14, 12, 14, 12)`.
- Screen edges: `EdgeInsets.fromLTRB(16, 14, 16, 14)`.
- Section gaps: 16–22 between major sections, 8–12 between siblings.

---

## 4. Component catalog (`Tf*`)

All in [`tf_design_system.dart`](../widgets/tf_design_system.dart). Reuse first; extend the existing class with optional parameters when something is missing. Do not fork.

| Component | Purpose |
|---|---|
| `TfText(string, {style, maxLines, overflow, textAlign})` | All text. Localizes digits and font family automatically. |
| `TfMoney(amount, {style, showSymbol})` | Currency display with Taka symbol and locale-correct digits. |
| `TfTextPair({en, bn, …})` | Pick locale-correct string (falls back to `en` if `bn` empty). |
| `TfAppBar({title, titleBn, subtitle, subtitleBn, leading, trailing})` | Screen header. Rendered inside `Scaffold.body`, not `Scaffold.appBar`. |
| `TfButton({label, labelBn, icon, trailingIcon, variant, size, fullWidth, busy, onPressed})` | All buttons. Variants: `primary`, `dark`, `ghost`, `paper`. Sizes: `lg` (50), `md` (42), `sm` (32). |
| `TfIconButton({icon, tooltip, onPressed, badge, dark})` | 38×38 square icon target. `badge` shows a red count chip. `dark: true` swaps to filled primary-dark. |
| `TfFab({icon, tooltip, onPressed})` | 56×56 circular primary-yellow FAB. |
| `TfCard({child, padding, color, clip, padded})` | Bordered surface, 12 radius, 0.5px line. The default container for everything. |
| `TfChip({label, labelBn, active, onTap, small, leading})` | Toggleable pill. Replaces every `ChoiceChip`/`FilterChip`/`ActionChip`. |
| `TfStatusBadge({label, kind, upper})` | Small status pill. Kinds: `pending`, `accepted`, `late`, `served`, `info`, `warning`. |
| `TfSectionHeader({label, color, trailing, padding})` | Uppercase 11px section label. Default `color: PosColors.muted`. Pass `color: PosColors.danger` for alert variants. |
| `TfField({label, labelBn, controller, hint, hintBn, prefix, suffix, errorText, hintHelper, keyboardType, obscure, maxLines, onChanged})` | Form input wrapper. Use for all labeled fields. |
| `TfSearchField({controller, hintText, onChanged})` | Standalone rounded search field. 46 height, 12 radius. |
| `TfTabs({items, activeIndex, onChanged})` | Linear segmented control. Items are `TfTabItem(label, labelBn, count?)`. |
| `TfBottomNav({items, activeIndex, onChanged})` | Footer nav. Items are `TfBottomNavItem(icon, label, …)`. |
| `TfStickyCTA({child, helper})` | Pinned bottom action region; wrap a `TfButton`. |
| `TfRail({color, width})` | Coloured accent stripe used inside row tiles. |
| `TfEmptyState({title, message, titleBn, messageBn, icon, action})` | Empty-state placeholder. |
| `TfLoading({message, messageBn})` | Async block placeholder. |
| `TfOfflineBanner()` | Top-of-screen sync banner. |
| `TfConfirmSheet.show(context, {title, description, titleBn, descriptionBn, confirmLabel, confirmLabelBn, isDanger, onConfirm})` | Bottom-sheet confirmation. Use for every destructive/confirm flow. |
| `TfNavIcon.*` | Canonical icon constants (`orders`, `menu`, `home`, `inventory`, `settings`, `bell`, `plus`, `back`, `check`, `search`, `camera`, `printer`, `bluetooth`, `wifi`, `close`, `minus`, `dot`, `chevron`, `sparkle`, `flame`). Use these instead of raw `Icons.*` where a constant exists. |

---

## 5. Patterns

### Screen title
Render `TfAppBar` inside the body — never assign it to `Scaffold.appBar`. Pair `trailing:` with `HeaderLanguageButton` + `HeaderNotificationBell`.

```dart
TfAppBar(
  title: text.dashboard,
  subtitle: 'Right now · ${timePart}',
  trailing: [
    const HeaderLanguageButton(),
    HeaderNotificationBell(onNavigateToOrders: …),
  ],
)
```

### Section headers
Use `TfSectionHeader(label: '…')`. Pass `padding: EdgeInsets.zero` when inside a tight column so the surrounding `SizedBox`/`Padding` controls spacing.

### Lists / settings groups
```dart
TfCard(
  padding: EdgeInsets.zero,
  child: Column(children: [
    for (var i = 0; i < items.length; i++) ...[
      _TileRow(item: items[i]),
      if (i < items.length - 1)
        const Divider(height: 1, color: PosColors.lineStrong),
    ],
  ]),
)
```

### Forms
Use `TfField` for inputs. Group related fields without a card; group unrelated sections with `TfSectionHeader` + `TfCard`. Validation errors flow through `errorText:`.

### Destructive / confirm flows
```dart
TfConfirmSheet.show(
  context,
  title: 'Delete item',
  description: 'This cannot be undone.',
  confirmLabel: 'Delete',
  isDanger: true,
  onConfirm: () async { … },
);
```

`TfConfirmSheet` is fire-and-forget. For the rare case where you need a `Future<bool>` for branching, `showDialog<bool>` + `AlertDialog` is acceptable — but its action row must use `TfButton`s, not raw `FilledButton`/`TextButton`.

### Loading / empty
- Loading: `TfLoading(message: '…')` inside a `Center`.
- Empty: `TfEmptyState(title: …, message: …, icon: …, action: TfButton(…))`.

### Sticky bottom CTA
```dart
TfStickyCTA(
  child: TfButton(label: 'Confirm order', size: TfButtonSize.lg, onPressed: …),
  helper: 'Tap to finalize · Bn fallback ok',
)
```

### Offline state
Place `TfOfflineBanner()` above the body when `app.isOffline`. It uses warning amber + dark text and is locale-aware.

---

## 6. Adding new screens and components

1. **Reuse first.** If a `Tf*` covers it, use it.
2. **Extend, don't fork.** Add an optional parameter to the existing class rather than copying. Update this file's catalog when you do.
3. **Stay in the palette.** New colors require updating `PosColors` *and* this file.
4. **Stay on the radius scale.** 8 / 12 / 999. New radii require a written justification and a `PosRadii` update.
5. **Stay on the weight pair.** w400 / w500 only. If a design wants `w600`, redesign the hierarchy instead.
6. **Locale-safe text.** Always `TfText`, always `tfFontFamily(context)`.
7. **Budget GPU.** Single-layer `boxShadow`, `blurRadius ≤ 8`. No `BackdropFilter`.
8. **Single source of truth.** Do not create a second widget library (no more `pos_compact_ui.dart`-style forks). If a missing primitive forces you to, add it to `tf_design_system.dart` and document it here.

---

## 7. Hard prohibitions

The following must never appear in `lib/src/features/**` (or `lib/src/core/widgets/**` except `tf_design_system.dart` / `app_theme.dart`):

- `FontWeight.w600` / `.w700` / `.w800` / `.w900`
- `Color(0xFF…)` literals (use `PosColors`; the only exceptions are `app_theme.dart` definitions and `menu_image_view.dart`'s food palette)
- `'Inter'` / `'Hind Siliguri'` string literals (use `tfFontFamily(context)`)
- `Text(…)` (use `TfText`)
- `ChoiceChip` / `FilterChip` / `ActionChip` (use `TfChip`)
- `FilledButton` / `OutlinedButton` / `TextButton` / `ElevatedButton` (use `TfButton`)
- `BorderRadius.circular(N)` where `N ∉ {8, 12, 999}`
- `BoxShadow` with `blurRadius > 8` or `boxShadow` lists of length > 1
- `surfaceTintColor` overrides to anything but `Colors.transparent`
- Any second widget library that overlaps with `Tf*`

A grep sweep that finds any of these in feature code indicates a regression and should be fixed before merge.

---

## 8. Verification checklist (pre-merge)

```bash
cd admin_app
flutter analyze --no-fatal-warnings 2>&1 | grep " error " | grep -v "test/"   # expect empty

# Coherence regressions
grep -rn "FontWeight\.w[6-9]" lib/src/features lib/src/core/widgets --include="*.dart"  # expect empty
grep -rnE "(?<![\.\w])Text\(\s*['\"]" lib/src/features --include="*.dart" -P | grep -v TfText  # expect empty
grep -rn "ChoiceChip\|FilterChip\|ActionChip\|FilledButton\b\|OutlinedButton\b\|TextButton\b" lib/src/features --include="*.dart"  # expect empty
grep -rnE "(?<!pw\.)\b(BorderRadius|Radius)\.circular\((1[3-9]|2[0-9]|[3-9][0-9]|[1]|[3-7])\)" lib/src/features lib/src/core/widgets --include="*.dart" -P  # expect empty (2 is allowed for thin accents only)
grep -rnE "fontFamily:\s*'(Inter|Hind Siliguri)'" lib/src --include="*.dart" | grep -v "core/theme/app_theme.dart" | grep -v "core/widgets/tf_design_system.dart"  # expect empty
grep -rnE "blurRadius:\s*([1-9][0-9]+|9)" lib/src --include="*.dart" | grep -v "core/theme/app_theme.dart"  # expect empty
grep -rn "Compact\(Header\|IconButton\|SearchField\|SectionLabel\|Surface\)\|EmptyCompactState\|pos_compact_ui" lib/src --include="*.dart"  # expect empty
```

If any of those return matches, the change is out of spec.
