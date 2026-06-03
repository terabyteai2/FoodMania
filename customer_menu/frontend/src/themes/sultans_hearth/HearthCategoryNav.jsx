import React, { useEffect, useRef } from 'react'
import { useTokens } from '../index.jsx'
import { useLang, t } from './i18n.js'

export function categorySlug(name) {
  return 'cat-' + String(name || '').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '')
}

// Sticky chip row. Reveals once we've scrolled past the hero.
export default function HearthCategoryNav({
  categories,
  categoryBnMap = {},
  active,
  onPick,
  visible,
  topOffset = 0,
}) {
  const T = useTokens()
  const lang = useLang()
  const trackRef = useRef(null)
  const chipRefs = useRef({})

  // Auto-scroll the active chip into view when it changes.
  useEffect(() => {
    const el = chipRefs.current[active]
    const track = trackRef.current
    if (!el || !track) return
    const elLeft = el.offsetLeft
    const elRight = elLeft + el.offsetWidth
    const trackLeft = track.scrollLeft
    const trackRight = trackLeft + track.clientWidth
    if (elLeft < trackLeft + 16) track.scrollTo({ left: Math.max(0, elLeft - 16), behavior: 'smooth' })
    else if (elRight > trackRight - 16) track.scrollTo({ left: elRight - track.clientWidth + 16, behavior: 'smooth' })
  }, [active])

  return (
    <div
      role="navigation"
      aria-label="Menu categories"
      style={{
        position: 'sticky',
        top: topOffset,
        zIndex: 20,
        background: 'rgba(26,20,16,.92)',
        backdropFilter: 'blur(8px)',
        WebkitBackdropFilter: 'blur(8px)',
        borderBottom: `1px solid ${T.line}`,
        transform: visible ? 'translateY(0)' : 'translateY(-100%)',
        transition: 'transform .22s ease',
        paddingTop: 'env(safe-area-inset-top)',
      }}
    >
      <div
        ref={trackRef}
        style={{
          display: 'flex',
          gap: 8,
          padding: '12px 16px',
          overflowX: 'auto',
          scrollbarWidth: 'none',
          WebkitOverflowScrolling: 'touch',
        }}
      >
        {categories.map(cat => {
          const isActive = cat === active
          const labelEn = cat === 'All' ? t('all', 'en') : cat
          const labelBn = cat === 'All' ? t('all', 'bn') : (categoryBnMap[cat] || labelEn)
          const label = lang === 'bn' ? labelBn : labelEn
          return (
            <button
              key={cat}
              ref={el => { chipRefs.current[cat] = el }}
              type="button"
              aria-pressed={isActive}
              onClick={() => onPick(cat)}
              style={{
                flex: '0 0 auto',
                minHeight: 40,
                padding: '0 18px',
                borderRadius: 22,
                background: isActive ? '#E8A33D' : 'transparent',
                color: isActive ? '#1A1410' : '#F4EEDF',
                border: `1px solid ${isActive ? '#E8A33D' : '#C9A24B'}`,
                fontFamily: lang === 'bn'
                  ? '"Hind Siliguri", system-ui, sans-serif'
                  : '"Cinzel", serif',
                fontSize: 12,
                fontWeight: isActive ? 700 : 500,
                letterSpacing: lang === 'bn' ? '.02em' : '.16em',
                textTransform: lang === 'bn' ? 'none' : 'uppercase',
                cursor: 'pointer',
                whiteSpace: 'nowrap',
                WebkitTapHighlightColor: 'transparent',
                transition: 'background .18s, color .18s',
                display: 'inline-flex', alignItems: 'center',
              }}
            >
              {label}
            </button>
          )
        })}
      </div>
    </div>
  )
}
