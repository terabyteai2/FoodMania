// Customer-menu theme registry. Slugs MUST match ALLOWED_MENU_THEMES in
// backend/routers/menu.py and customer_menu_themes.dart in the admin app.

import React, { createContext, useContext, useMemo } from 'react'

// ── Tokens ─────────────────────────────────────────────────────────────────────
// Each theme exposes the same shape so render code can read tokens uniformly:
//   palette: { bg, bgWarm, bgCard, ink, inkSoft, inkFaint, ember, amber, line }
//   fonts:   { display, body, mono?, accent? }
//   hero:    { mode, brandCase, ctaShape, ctaTextColor, decor? }
//   menu:    { layout, cardBg?, categoryStyle, accent? }
//   divider: string token (used by Hero and section dividers in MenuList)

const NAPOLI = {
  slug: 'napoli_trattoria',
  palette: {
    bg: '#1c1410', bgWarm: '#241914', bgCard: '#2b1f18',
    ink: '#fff3e0', inkSoft: 'rgba(255,243,224,.65)', inkFaint: 'rgba(255,243,224,.4)',
    ember: '#ff6a3d', amber: '#ffb547',
    line: 'rgba(255,243,224,.12)',
  },
  fonts: {
    display: '"Anton", "Bebas Neue", "Inter Tight", system-ui, sans-serif',
    body: '"Hind Siliguri", system-ui, -apple-system, sans-serif',
    mono: '"JetBrains Mono", ui-monospace, SFMono-Regular, Menlo, monospace',
    accent: '"Cormorant Garamond", "Anton", serif',
  },
  hero: { mode: 'video-vignette', brandCase: 'upper', ctaShape: 'pill', ctaTextColor: '#1a0c08', decor: 'flour-dust' },
  menu: { layout: 'grid-2col', categoryStyle: 'underline-display' },
  divider: 'flour-dust',
}

const TUSCAN = {
  slug: 'tuscan_herb',
  palette: {
    bg: '#F4ECDC', bgWarm: '#EFE5D0', bgCard: '#FBF6EA',
    ink: '#2C2A1F', inkSoft: 'rgba(44,42,31,.65)', inkFaint: 'rgba(44,42,31,.4)',
    ember: '#C97A5A', amber: '#8FA382',
    line: 'rgba(44,42,31,.16)',
  },
  fonts: {
    display: '"Fraunces", "Lora", Georgia, serif',
    body: '"Hind Siliguri", system-ui, sans-serif',
    accent: '"Caveat", "Petit Formal Script", cursive',
  },
  hero: { mode: 'sepia-torn', brandCase: 'mixed-italic', ctaShape: 'flat', ctaTextColor: '#FBF6EA', decor: 'rosemary' },
  menu: { layout: 'cookbook-2col', categoryStyle: 'serif-rule', accent: '#5A1F26' },
  divider: 'rosemary',
}

const AMALFI = {
  slug: 'amalfi_breeze',
  palette: {
    bg: '#FBFAF5', bgWarm: '#EAF1F5', bgCard: 'rgba(255,255,255,.55)',
    ink: '#1B2A3B', inkSoft: 'rgba(27,42,59,.62)', inkFaint: 'rgba(27,42,59,.4)',
    ember: '#E89A8A', amber: '#F5D547',
    line: 'rgba(27,42,59,.14)',
  },
  fonts: {
    display: '"General Sans", "Söhne", "Inter Tight", sans-serif',
    body: '"Hind Siliguri", system-ui, sans-serif',
    accent: '"Recoleta", "Boska", "Fraunces", serif',
  },
  hero: { mode: 'frosted-glass', brandCase: 'mixed', ctaShape: 'pill-white', ctaTextColor: '#2E6F8E', decor: 'lemon-slice' },
  menu: { layout: 'frosted-2col', categoryStyle: 'chip-row', accent: '#2E6F8E' },
  divider: 'lemon-slice',
}

const MILANO = {
  slug: 'milano_roast',
  palette: {
    bg: '#FAF7F2', bgWarm: '#F2EBDD', bgCard: '#FFFFFF',
    ink: '#15110D', inkSoft: 'rgba(21,17,13,.62)', inkFaint: 'rgba(21,17,13,.4)',
    ember: '#3B2A1F', amber: '#B89556',
    line: 'rgba(21,17,13,.18)',
  },
  fonts: {
    display: '"Futura", "GT America", "Inter Tight", sans-serif',
    body: '"Hind Siliguri", system-ui, sans-serif',
    mono: '"JetBrains Mono", "IBM Plex Mono", ui-monospace, monospace',
  },
  hero: { mode: 'video-vignette-light', brandCase: 'upper-tracked', ctaShape: 'outline', ctaTextColor: '#15110D', decor: 'brass-rule' },
  menu: { layout: 'leader-dots', categoryStyle: 'caps-rule' },
  divider: 'leader-dots',
}

const SULTANS = {
  slug: 'sultans_hearth',
  palette: {
    bg: '#1A1410', bgWarm: '#221814', bgCard: '#2A1F18',
    ink: '#F0E5D0', inkSoft: 'rgba(240,229,208,.7)', inkFaint: 'rgba(240,229,208,.45)',
    ember: '#E26B2C', amber: '#C9A24B',
    line: 'rgba(201,162,75,.32)',
  },
  fonts: {
    display: '"Cinzel", "Trajan Pro", "Anton", serif',
    body: '"Hind Siliguri", system-ui, sans-serif',
    accent: '"Cinzel", serif',
  },
  hero: { mode: 'gold-frame-dark', brandCase: 'upper', ctaShape: 'gold-rect', ctaTextColor: '#C9A24B', decor: 'arabesque-star' },
  menu: { layout: 'gold-rule-grid', categoryStyle: 'arabesque-center', accent: '#C9A24B' },
  divider: 'arabesque-star',
}

const CHARCOAL = {
  slug: 'charcoal_lodge',
  palette: {
    bg: '#E8E2D4', bgWarm: '#D6CFBE', bgCard: '#1C1C1E',
    ink: '#1C1C1E', inkSoft: 'rgba(28,28,30,.65)', inkFaint: 'rgba(28,28,30,.4)',
    ember: '#8B2828', amber: '#A0814D',
    line: 'rgba(28,28,30,.22)',
  },
  fonts: {
    display: '"Playfair Display", "Ogg", Georgia, serif',
    body: '"Hind Siliguri", system-ui, sans-serif',
    mono: '"Space Mono", "Major Mono Display", ui-monospace, monospace',
  },
  hero: { mode: 'stamped-leather', brandCase: 'upper-stamped', ctaShape: 'hard-rect', ctaTextColor: '#E8E2D4', decor: 'sear-cross' },
  menu: { layout: 'butcher-slate', categoryStyle: 'caps-brass', accent: '#A0814D' },
  divider: 'brass-hairline',
}

const BENGAL = {
  slug: 'bengal_bistro',
  palette: {
    bg: '#F5F2EB', bgWarm: '#EDE8DC', bgCard: '#FFFFFF',
    ink: '#2C3E66', inkSoft: 'rgba(44,62,102,.65)', inkFaint: 'rgba(44,62,102,.42)',
    ember: '#D9A431', amber: '#7BA88C',
    line: 'rgba(44,62,102,.18)',
  },
  fonts: {
    display: '"Fraunces", "Tiempos Text", "Lora", serif',
    body: '"Hind Siliguri", system-ui, sans-serif',
    accent: '"Hind Siliguri", system-ui, sans-serif',
  },
  hero: { mode: 'magazine-overhead', brandCase: 'mixed-stacked-bn', ctaShape: 'pill-mustard', ctaTextColor: '#2C3E66', decor: 'mustard-dot' },
  menu: { layout: 'magazine-bilingual', categoryStyle: 'pill-indigo', accent: '#D9A431' },
  divider: 'mustard-dot',
}

const MUGHAL = {
  slug: 'grand_mughal',
  palette: {
    bg: '#3A1F3D', bgWarm: '#321A35', bgCard: '#451F47',
    ink: '#F4EEDF', inkSoft: 'rgba(244,238,223,.7)', inkFaint: 'rgba(244,238,223,.42)',
    ember: '#E8A33D', amber: '#B8923A',
    line: 'rgba(184,146,58,.36)',
  },
  fonts: {
    display: '"Cormorant SC", "Trajan Pro", "Cinzel", serif',
    body: '"Hind Siliguri", system-ui, sans-serif',
    accent: '"Cormorant Garamond", serif',
  },
  hero: { mode: 'gold-frame-saffron', brandCase: 'serif-upper', ctaShape: 'gold-bordered', ctaTextColor: '#3A1F3D', decor: 'gold-flourish' },
  menu: { layout: 'manuscript-frame', categoryStyle: 'serif-flourish', accent: '#E8A33D' },
  divider: 'gold-rule',
}

export const THEMES = {
  napoli_trattoria: NAPOLI,
  tuscan_herb: TUSCAN,
  amalfi_breeze: AMALFI,
  milano_roast: MILANO,
  sultans_hearth: SULTANS,
  charcoal_lodge: CHARCOAL,
  bengal_bistro: BENGAL,
  grand_mughal: MUGHAL,
}

export const DEFAULT_THEME_SLUG = 'napoli_trattoria'

export function resolveTheme(slug) {
  return THEMES[slug] || THEMES[DEFAULT_THEME_SLUG]
}

// Flattened legacy view: keeps `T.bg`, `T.ember`, `T.display`, etc. working
// in all existing component code without per-call refactors.
function flattenTokens(theme) {
  return {
    ...theme.palette,
    display: theme.fonts.display,
    body: theme.fonts.body,
    mono: theme.fonts.mono || theme.fonts.body,
    accent: theme.fonts.accent || theme.fonts.display,
    _hero: theme.hero,
    _menu: theme.menu,
    _divider: theme.divider,
    _slug: theme.slug,
  }
}

const ThemeContext = createContext(flattenTokens(NAPOLI))

export function ThemeProvider({ slug, children }) {
  const value = useMemo(() => flattenTokens(resolveTheme(slug)), [slug])
  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>
}

// Hook that returns the flattened tokens. Existing components renaming
// `const T = ...` → `const T = useTokens()` works without other edits.
export function useTokens() {
  return useContext(ThemeContext)
}

// Where the user drops their per-theme placeholder media. Files don't have
// to exist — Hero falls back to a generated pattern when absent.
export function themeAssetPaths(slug) {
  const safe = THEMES[slug] ? slug : DEFAULT_THEME_SLUG
  return {
    placeholderVideo: `/themes/${safe}/hero-placeholder.mp4`,
    placeholderImage: `/themes/${safe}/hero-placeholder.jpg`,
  }
}
