import React, { useEffect, useRef } from 'react'
import { useTokens } from '../index.jsx'
import { buildMedia, MenuFallbackIcon, taka } from '../../App.jsx'
import { StarDivider, FlameGlyph } from './StarOrnament.jsx'
import { useLang, t, pick } from './i18n.js'

function spiceLevelFor(item) {
  if (typeof item?.spiceLevel === 'number') return Math.max(0, Math.min(3, item.spiceLevel))
  const tags = []
  if (Array.isArray(item?.tags)) tags.push(...item.tags)
  if (typeof item?.tag === 'string') tags.push(item.tag)
  for (const raw of tags) {
    const s = String(raw).toLowerCase().trim()
    const m = s.match(/^spice[:=](\d)/)
    if (m) return Math.max(0, Math.min(3, parseInt(m[1], 10)))
    if (s === 'spicy' || s === 'hot') return 2
    if (s === 'mild') return 1
    if (s === 'extra hot' || s === 'extra-hot' || s === 'fiery') return 3
  }
  return 0
}

export default function HearthItemSheet({ item, qty, onAdd, onRemove, onClose }) {
  const T = useTokens()
  const lang = useLang()
  const videoRef = useRef(null)
  const media = buildMedia(item)
  const current = media[0]

  useEffect(() => {
    function onKey(e) { if (e.key === 'Escape') onClose() }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [onClose])

  useEffect(() => {
    if (videoRef.current) videoRef.current.play().catch(() => {})
  }, [item?.id])

  if (!item) return null

  const primaryName = pick(item, 'name', lang) || item.nameEn || item.name || item.nameBn
  const secondaryName = lang === 'bn'
    ? (item.nameEn || item.name || '')
    : (item.nameBn || '')
  const description = pick(item, 'description', lang)
  const spice = spiceLevelFor(item)

  return (
    <div
      className="fade-in"
      onClick={e => { if (e.target === e.currentTarget) onClose() }}
      style={{
        position: 'fixed', inset: 0, zIndex: 50,
        background: 'rgba(0,0,0,.7)',
        display: 'flex', alignItems: 'flex-end',
        backdropFilter: 'blur(4px)',
      }}
      role="dialog"
      aria-modal="true"
      aria-label={primaryName}
    >
      <div
        className="slide-up"
        style={{
          width: '100%',
          maxHeight: '92svh',
          background: '#1A1410',
          color: '#F4EEDF',
          borderTopLeftRadius: 22,
          borderTopRightRadius: 22,
          boxShadow: '0 -22px 60px rgba(0,0,0,.55)',
          border: `1px solid ${T.line}`,
          borderBottom: 'none',
          display: 'flex', flexDirection: 'column', overflow: 'hidden',
        }}
      >
        {/* Photo / video header */}
        <div style={{
          position: 'relative', flexShrink: 0,
          height: 240,
          background: '#2A1F1A',
          ...(current?.type === 'image' ? {
            backgroundImage: `url(${current.url})`,
            backgroundSize: 'cover', backgroundPosition: 'center',
          } : {}),
        }}>
          {current?.type === 'video' && (
            <video
              ref={videoRef}
              src={current.url}
              autoPlay muted loop playsInline
              style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover' }}
            />
          )}
          {!current && <MenuFallbackIcon item={item} size={64} />}

          {/* Bottom shade for legibility */}
          <div aria-hidden="true" style={{
            position: 'absolute', inset: 0,
            background: 'linear-gradient(180deg, rgba(26,20,16,.05) 0%, rgba(26,20,16,.85) 100%)',
          }} />

          {/* Close */}
          <button
            type="button"
            onClick={onClose}
            aria-label={t('back', lang)}
            style={{
              position: 'absolute', top: 12, right: 12,
              width: 40, height: 40, borderRadius: 20,
              border: `1px solid ${T.line}`,
              background: 'rgba(26,20,16,.65)',
              color: '#F4EEDF',
              fontSize: 18, cursor: 'pointer',
              display: 'grid', placeItems: 'center',
              backdropFilter: 'blur(6px)',
              WebkitTapHighlightColor: 'transparent',
            }}
          >×</button>

          {/* Inner gold hairline */}
          <div aria-hidden="true" style={{
            position: 'absolute', inset: 8, borderRadius: 14,
            boxShadow: 'inset 0 0 0 1px rgba(201,162,75,.32)',
            pointerEvents: 'none',
          }} />
        </div>

        {/* Body */}
        <div style={{
          flex: 1, overflowY: 'auto',
          padding: '20px 22px 24px',
        }}>
          <div style={{
            display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', gap: 12,
            flexWrap: 'wrap',
          }}>
            <h2 style={{
              margin: 0,
              fontFamily: lang === 'bn'
                ? '"Hind Siliguri", system-ui, sans-serif'
                : '"Cormorant Garamond", serif',
              fontStyle: lang === 'bn' ? 'normal' : 'italic',
              fontWeight: lang === 'bn' ? 600 : 500,
              fontSize: 26, lineHeight: 1.15,
              color: '#F4EEDF',
            }}>{primaryName}</h2>
            <div style={{
              fontFamily: '"Cinzel", serif',
              fontWeight: 600,
              fontSize: 22,
              color: '#E8A33D',
              letterSpacing: '.02em',
            }}>
              <span style={{ fontSize: 14, marginRight: 2, opacity: .85 }}>৳</span>
              {Math.round(item.price).toLocaleString('en-BD')}
            </div>
          </div>

          {secondaryName && secondaryName !== primaryName && (
            <div style={{
              marginTop: 4,
              fontFamily: '"Hind Siliguri", system-ui, sans-serif',
              fontSize: 17,
              color: '#A89580',
              fontWeight: 600,
            }}>{secondaryName}</div>
          )}

          {spice > 0 && (
            <div style={{ marginTop: 10, display: 'inline-flex', alignItems: 'center', gap: 4 }}>
              {[1, 2, 3].map(i => <FlameGlyph key={i} color="#E26B2C" dim={i > spice} />)}
            </div>
          )}

          {description && (
            <>
              <div style={{ margin: '18px 0 6px' }}><StarDivider /></div>
              <p style={{
                margin: 0,
                fontFamily: lang === 'bn'
                  ? '"Hind Siliguri", system-ui, sans-serif'
                  : '"Cormorant Garamond", serif',
                fontSize: 16, lineHeight: 1.55,
                color: '#F4EEDF',
                opacity: .9,
              }}>{description}</p>
            </>
          )}
        </div>

        {/* Bottom CTA */}
        <div style={{
          padding: '12px 16px calc(env(safe-area-inset-bottom) + 16px)',
          borderTop: `1px solid ${T.line}`,
          background: '#1A1410',
          display: 'flex', alignItems: 'center', gap: 12,
        }}>
          {qty > 0 ? (
            <div style={{
              display: 'inline-flex', alignItems: 'center',
              height: 56, padding: '0 4px',
              borderRadius: 12,
              background: '#1A1410',
              border: `1px solid #C9A24B`,
              color: '#F4EEDF',
              fontFamily: '"Cinzel", serif',
            }}>
              <button
                type="button"
                onClick={onRemove}
                aria-label={t('remove', lang)}
                style={{
                  width: 48, height: 48, background: 'transparent', border: 'none',
                  color: '#A89580', fontSize: 22, cursor: 'pointer',
                  WebkitTapHighlightColor: 'transparent',
                }}
              >−</button>
              <span style={{ minWidth: 32, textAlign: 'center', fontSize: 16, fontWeight: 600 }}>{qty}</span>
              <button
                type="button"
                onClick={onAdd}
                aria-label={t('add', lang)}
                style={{
                  width: 48, height: 48, background: 'transparent', border: 'none',
                  color: '#E8A33D', fontSize: 22, cursor: 'pointer',
                  WebkitTapHighlightColor: 'transparent',
                }}
              >+</button>
            </div>
          ) : null}

          <button
            type="button"
            onClick={onAdd}
            style={{
              flex: 1,
              height: 56,
              borderRadius: 12,
              background: '#E8A33D',
              color: '#1A1410',
              border: 'none',
              boxShadow: 'inset 0 0 0 1px #C9A24B, 0 12px 28px rgba(232,163,61,.32)',
              fontFamily: '"Cinzel", serif',
              fontWeight: 700,
              fontSize: 14,
              letterSpacing: '.16em',
              textTransform: 'uppercase',
              cursor: 'pointer',
              WebkitTapHighlightColor: 'transparent',
            }}
          >{qty > 0 ? `${t('add', lang)} · ${taka(item.price)}` : `${t('add', lang)} · ${taka(item.price)}`}</button>
        </div>
      </div>
    </div>
  )
}
