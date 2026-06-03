import React, { useEffect, useRef, useState } from 'react'
import { taka } from '../../App.jsx'
import { useLang, t } from './i18n.js'

export default function HearthFloatingCart({ count, total, onTap }) {
  const lang = useLang()
  const [pop, setPop] = useState(false)
  const prev = useRef(count)

  useEffect(() => {
    if (count !== prev.current) {
      prev.current = count
      if (count > 0) {
        setPop(true)
        const id = window.setTimeout(() => setPop(false), 450)
        return () => window.clearTimeout(id)
      }
    }
  }, [count])

  if (count <= 0) return null

  return (
    <button
      type="button"
      onClick={onTap}
      aria-label={`${t('yourOrder', lang)} · ${count} · ${taka(total)}`}
      className={pop ? 'hearth-cart-pop' : undefined}
      style={{
        position: 'fixed',
        right: 18,
        bottom: 'calc(env(safe-area-inset-bottom) + 18px)',
        zIndex: 40,
        minHeight: 56,
        padding: '0 20px',
        borderRadius: 28,
        border: 'none',
        background: '#E8A33D',
        color: '#1A1410',
        display: 'inline-flex', alignItems: 'center', gap: 12,
        fontFamily: '"Cinzel", serif',
        fontWeight: 700,
        fontSize: 14,
        letterSpacing: '.14em',
        textTransform: 'uppercase',
        cursor: 'pointer',
        boxShadow: '0 14px 38px rgba(201,162,75,.45), inset 0 0 0 1px #C9A24B',
        WebkitTapHighlightColor: 'transparent',
      }}
    >
      <span style={{
        minWidth: 26, height: 26, borderRadius: 13,
        background: '#1A1410', color: '#E8A33D',
        display: 'grid', placeItems: 'center',
        fontSize: 13, fontFamily: '"Hind Siliguri", system-ui, sans-serif',
      }}>{count}</span>
      <span>{t('yourOrder', lang)}</span>
      <span style={{
        paddingLeft: 10, borderLeft: '1px solid rgba(26,20,16,.35)',
        fontSize: 14, letterSpacing: '.04em',
      }}>{taka(total)}</span>
    </button>
  )
}
