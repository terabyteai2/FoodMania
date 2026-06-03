// Customer-menu theme registry. Slugs MUST match ALLOWED_MENU_THEMES in
// backend/routers/menu.py and customer_menu_themes.dart in the admin app.

import React, { createContext, useContext, useMemo } from 'react'
import {
  sultansHearthOverrides,
  brickOverrides,
  lanternOverrides,
  marbleOverrides,
} from './menu_templates/index.jsx'

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

const BRICK = {
  slug: 'brick',
  palette: {
    bg: '#F4EBDC', bgWarm: '#EDE0C9', bgCard: '#FFFFFF',
    ink: '#2A2420', inkSoft: '#6B5E4F', inkFaint: 'rgba(107,94,79,.55)',
    ember: '#E89A4A', amber: '#E8B547',
    line: '#D9CCB5',
  },
  fonts: {
    display: '"Anton", sans-serif',
    body: '"Inter", "Hind Siliguri", system-ui, sans-serif',
    accent: '"Bebas Neue", sans-serif',
  },
  hero: { mode: 'golden-cafe', brandCase: 'upper-tight', ctaShape: 'pill', ctaTextColor: '#2A2420', decor: 'dashed-brick' },
  menu: { layout: 'bright-cafe-list', categoryStyle: 'pill-row', accent: '#E89A4A' },
  divider: 'dashed-ember',
}

const LANTERN = {
  slug: 'lantern',
  palette: {
    bg: '#14181A', bgWarm: '#1F2628', bgCard: '#1F2628',
    ink: '#EDE8DD', inkSoft: '#8A9095', inkFaint: 'rgba(138,144,149,.52)',
    ember: '#E8744A', amber: '#5FB8C4',
    line: '#2A3235',
  },
  fonts: {
    display: '"Bodoni Moda", serif',
    body: '"Inter", "Hind Siliguri", system-ui, sans-serif',
    accent: '"Bodoni Moda", serif',
  },
  hero: { mode: 'neon-bistro', brandCase: 'mixed', ctaShape: 'soft-rect', ctaTextColor: '#14181A', decor: 'teal-rule' },
  menu: { layout: 'editorial-list', categoryStyle: 'underline-tabs', accent: '#5FB8C4' },
  divider: 'teal-dot-rule',
}

const MARBLE = {
  slug: 'marble',
  palette: {
    bg: '#FBF8F2', bgWarm: '#F2EDE3', bgCard: '#FFFFFF',
    ink: '#3B2A1F', inkSoft: '#6B5E50', inkFaint: 'rgba(107,94,80,.52)',
    ember: '#3B2A1F', amber: '#B89556',
    line: '#E8E0D2',
  },
  fonts: {
    display: '"Fraunces", serif',
    body: '"Inter", "Hind Siliguri", system-ui, sans-serif',
    accent: '"Fraunces", serif',
  },
  hero: { mode: 'high-key-bakery', brandCase: 'mixed', ctaShape: 'restrained-rect', ctaTextColor: '#FBF8F2', decor: 'brass-dot' },
  menu: { layout: 'airy-bakery-list', categoryStyle: 'text-tabs', accent: '#B89556' },
  divider: 'brass-dot',
}

export const THEMES = {
  sultans_hearth: SULTANS,
  brick: BRICK,
  lantern: LANTERN,
  marble: MARBLE,
}

export const DEFAULT_THEME_SLUG = 'sultans_hearth'

export function resolveTheme(slug) {
  return THEMES[slug] || THEMES[DEFAULT_THEME_SLUG]
}

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

const ThemeContext = createContext(flattenTokens(SULTANS))

export function ThemeProvider({ slug, children }) {
  const value = useMemo(() => flattenTokens(resolveTheme(slug)), [slug])
  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>
}

export function useTokens() {
  return useContext(ThemeContext)
}

export const THEME_OVERRIDES = {
  sultans_hearth: sultansHearthOverrides,
  brick: brickOverrides,
  lantern: lanternOverrides,
  marble: marbleOverrides,
}

export function resolveOverrides(slug) {
  return THEME_OVERRIDES[slug] || null
}

export function themeAssetPaths(slug) {
  const safe = THEMES[slug] ? slug : DEFAULT_THEME_SLUG
  const basename = safe === 'sultans_hearth' ? 'hearth' : safe
  return {
    placeholderVideo: `/uploads/template_placeholders/${basename}.mp4`,
    placeholderImage: `/uploads/template_placeholders/${basename}.png`,
  }
}
