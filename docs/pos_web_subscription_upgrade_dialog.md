# pos_web — Subscription Upgrade Dialog with Addon Pricing

## Goal

Add the same subscription upgrade dialog (addon checkboxes + total price calculation) from admin_app to pos_web's existing ScreenBlocker.

---

## Backend

No changes needed. `GET /admin/subscription/upgrade` already returns:

```json
{
  "title": "Subscription — Standard",
  "message": "Current plan: Standard (expired)...",
  "inputField": true,
  "inputLabel": "Your bKash number (if different from account phone)",
  "currentPackage": "standard",
  "subscriptionPrices": {"standard": 500, "pro": 700, "premium": 1000},
  "addonOptions": [
    {"key": "inventory",    "label": "Inventory",    "price": 199, "owned": false},
    {"key": "website_qr",   "label": "Website Qr",   "price": 199, "owned": false},
    {"key": "messenger_bot","label": "Messenger Bot","price": 199, "owned": false}
  ]
}
```

The existing `client.ts:79` already unwraps `{data, error}` envelopes.

---

## Changes — 4 files, ~75 lines

### 1. `src/api/types.ts` — Add interfaces

```ts
export interface AddonOption {
  key: string;
  label: string;
  price: number;
  owned: boolean;
}

export interface UpgradeInfo {
  title: string;
  message: string;
  inputField: boolean;
  inputLabel: string | null;
  currentPackage: string;
  subscriptionPrices: Record<string, number>;
  addonOptions: AddonOption[];
}
```

### 2. `src/api/client.ts` — Add method

```ts
fetchUpgradeInfo: () => request<UpgradeInfo>('/admin/subscription/upgrade'),
```

Place after `fetchBlockingNotice()` / `respondBlockingNotice()` in the `api` object.

### 3. `src/App.tsx` — Fetch + pass upgradeInfo

- Add `useState<UpgradeInfo | null>(null)` for upgradeInfo
- Fetch upgradeInfo in `handleRetry` **after** `refreshAccess()` succeeds
- On fetch error → set null (fallback to existing blocker message)
- Pass `upgradeInfo={upgradeInfo}` to `<ScreenBlocker>`

```tsx
// New state:
const [upgradeInfo, setUpgradeInfo] = useState<UpgradeInfo | null>(null);

// In handleRetry, after refreshAccess():
try {
  const info = await api.fetchUpgradeInfo();
  setUpgradeInfo(info);
} catch {
  setUpgradeInfo(null); // fallback — blocker shows without addons
}
```

### 4. `src/components/ScreenBlocker.tsx` — Addon checkboxes + pricing

- Accept optional `upgradeInfo?: UpgradeInfo | null` prop
- Add local state: `const [checkedAddons, setCheckedAddons] = useState(new Set<string>())`
- When `notice.type === 'subscription'` and `upgradeInfo` is set, render section between the title and the helper text:

```
Add-ons
  ☑ Inventory (৳199/mo)        [Already owned]  (disabled if owned)
  ☐ Website Qr (৳199/mo)                          (toggleable)
  ☐ Messenger Bot (৳199/mo)                        (toggleable)

───────────────────────────
Plan (Standard)              ৳500/mo
Add-ons                      ৳199/mo   ← only if addonTotal > 0
───────────────────────────
Total                        ৳699/mo
```

**CSS tokens (all exist):**

| Element | Token |
|---------|-------|
| Divider | `<hr style="border:none;border-top:1px solid var(--line);margin:8px 0">` |
| Plan/Addon labels | `var(--ink-2)` / `var(--fs-13)` |
| Plan price | `var(--heading)` / `var(--fs-13)` / `font-weight:600` |
| Total label | `var(--heading)` / `var(--fs-16)` / `font-weight:700` |
| Total price | `var(--success)` / `var(--fs-16)` / `font-weight:700` |
| Addon owned subtitle | `var(--success)` / `var(--fs-12)` |

**Price calculation (inline in render):**

```ts
const basePrice = upgradeInfo.subscriptionPrices[upgradeInfo.currentPackage] ?? 500;
let addonTotal = 0;
for (const opt of upgradeInfo.addonOptions) {
  if (opt.owned || checkedAddons.has(opt.key)) addonTotal += opt.price;
}
const grandTotal = basePrice + addonTotal;
```

**Addon checkbox rendering:**

```tsx
{upgradeInfo.addonOptions.map(opt => (
  <label key={opt.key} style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '4px 0' }}>
    <input
      type="checkbox"
      checked={opt.owned || checkedAddons.has(opt.key)}
      disabled={opt.owned}
      onChange={(e) => {
        const next = new Set(checkedAddons);
        if (e.target.checked) next.add(opt.key);
        else next.delete(opt.key);
        setCheckedAddons(next);
      }}
    />
    <span>{opt.label} (৳{opt.price}/mo)</span>
    {opt.owned && <span style={{ color: 'var(--success)', fontSize: 'var(--fs-12)' }}>Already owned</span>}
  </label>
))}
```

**React immutable Set pattern** — always create a new Set via `new Set(old)`, mutate, then `setCheckedAddons`.

---

## Edge cases

| Scenario | Behavior |
|----------|----------|
| Upgrade endpoint error | `upgradeInfo` null → blocker renders current fallback |
| `addonOptions` empty | Plan row + Total only, no checkboxes |
| All addons owned | All checked+disabled with "Already owned"; total includes all |
| `notice.type !== 'subscription'` | Blocker unchanged (no addons) |
| `subscriptionPrices` missing currentPackage key | `basePrice` falls back to 500 |

## Files NOT modified

- `session.ts` (Zustand store) — upgradeInfo is local useState
- `strings.ts` — no i18n needed (same as admin_app — hardcoded labels)
- `tokens.css` — all tokens already exist
- `Modal.tsx` — no changes
- Any backend file

## Verification

```bash
npm run typecheck
npm run test
```