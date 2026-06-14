import React from 'react'
import { useTokens } from '../index.jsx'
import { MenuFallbackIcon, taka } from '../../App.jsx'
import { useLang, t, pick } from './i18n.js'
import { FlameGlyph } from './StarOrnament.jsx'

// Derive 0..3 spice level from item tags if present (tag like "spice:2"
// or a plain "spicy" tag → 2). Otherwise 0.
function spiceLevelFor(item) {
  const explicit = item?.spiceLevel
  if (typeof explicit === 'number') return Math.max(0, Math.min(3, explicit))
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

function PriceTag({ amount }) {
  return (
    <div style={{
      fontFamily: '"Cinzel", serif',
      fontWeight: 600,
      fontSize: 16,
      color: '#E8A33D',
      letterSpacing: '.02em',
      whiteSpace: 'nowrap',
      lineHeight: 1,
    }}>
      <span style={{ fontSize: 12, marginRight: 1, opacity: .85 }}>৳</span>
      {Math.round(amount).toLocaleString('en-BD')}
    </div>
  )
}

export default function HearthItemCard({ item, qty, onAdd, onRemove, onOpenDetail, onOpenVariants }) {
  const T = useTokens()
  const lang = useLang()
  const primaryName = pick(item, 'name', lang) || item.nameEn || item.name || item.nameBn
  const secondaryName = lang === 'bn'
    ? (item.nameEn || item.name || '')
    : (item.nameBn || '')
  const description = pick(item, 'description', lang)
  const spice = spiceLevelFor(item)
  const hasImage = !!item.imageUrl
  const hasModifiers = !!(item.options?.length || item.addons?.length)

  return (
    <article
      className="hearth-card fade-up"
      tabIndex={0}
      onClick={onOpenDetail}
      onKeyDown={e => {
        if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); onOpenDetail && onOpenDetail() }
      }}
      style={{
        display: 'grid',
        gridTemplateColumns: '56px 1fr',
        gap: 10,
        padding: 8,
        background: '#2A1F1A',
        borderRadius: 12,
        border: `1px solid ${T.line}`,
        cursor: 'pointer',
        WebkitTapHighlightColor: 'transparent',
        outline: 'none',
        transition: 'box-shadow .2s ease',
      }}
    >
      {/* Image square */}
      <div style={{
        width: 56, height: 56, borderRadius: 7, overflow: 'hidden',
        background: '#1A1410', position: 'relative', flexShrink: 0,
        ...(hasImage ? {
          backgroundImage: `url(${item.imageUrl})`,
          backgroundSize: 'cover', backgroundPosition: 'center',
        } : {}),
      }}>
        {!hasImage && <MenuFallbackIcon item={item} size={28} />}
        {/* Subtle inner gold hairline */}
        <div aria-hidden="true" style={{
          position: 'absolute', inset: 0, borderRadius: 7,
          boxShadow: 'inset 0 0 0 1px rgba(201,162,75,.20)',
          pointerEvents: 'none',
        }} />
      </div>

      {/* Content */}
      <div style={{
        display: 'flex', flexDirection: 'column', minWidth: 0,
        justifyContent: 'space-between',
      }}>
        <div style={{ minWidth: 0 }}>
          {/* Name row */}
          <div style={{
            display: 'flex', alignItems: 'baseline', gap: 8,
            flexWrap: 'wrap',
          }}>
            <h3 style={{
              margin: 0,
              fontFamily: lang === 'bn'
                ? '"Hind Siliguri", system-ui, sans-serif'
                : '"Cormorant Garamond", serif',
              fontStyle: lang === 'bn' ? 'normal' : 'italic',
              fontWeight: lang === 'bn' ? 600 : 500,
              fontSize: 17,
              lineHeight: 1.2,
              color: '#F4EEDF',
              minWidth: 0,
              overflow: 'hidden', textOverflow: 'ellipsis',
            }}>{primaryName}</h3>
            {spice > 0 && (
              <span aria-label={`Spice level ${spice} of 3`} style={{
                display: 'inline-flex', alignItems: 'center',
                paddingTop: 2,
              }}>
                {[1, 2, 3].map(i => (
                  <FlameGlyph key={i} size={11} color="#E26B2C" dim={i > spice} />
                ))}
              </span>
            )}
          </div>

          {secondaryName && secondaryName !== primaryName && (
            <div style={{
              marginTop: 2,
              fontFamily: '"Hind Siliguri", system-ui, sans-serif',
              fontSize: 14,
              color: '#A89580',
              lineHeight: 1.25,
              overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
            }}>{secondaryName}</div>
          )}

          {description && (
            <p style={{
              margin: '6px 0 0',
              fontFamily: lang === 'bn'
                ? '"Hind Siliguri", system-ui, sans-serif'
                : '"Cormorant Garamond", serif',
              fontSize: 13, lineHeight: 1.35,
              color: '#A89580',
              display: '-webkit-box',
              WebkitLineClamp: 2,
              WebkitBoxOrient: 'vertical',
              overflow: 'hidden',
            }}>{description}</p>
          )}
        </div>

        {/* Bottom row: price + add */}
        <div style={{
          marginTop: 8,
          display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8,
        }}>
          <PriceTag amount={item.price} />

          <div
            onClick={e => { e.stopPropagation(); e.preventDefault() }}
          >
            {hasModifiers ? (
              /* Items with options/addons: "+" always opens modifier sheet.
                 Show a qty badge when something is already in the cart. */
              <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                {qty > 0 && (
                  <span style={{
                    fontFamily: '"Cinzel", serif',
                    fontSize: 13, fontWeight: 700,
                    color: '#C9A24B',
                  }}>{qty}</span>
                )}
                <button
                  type="button"
                  onClick={() => onOpenVariants && onOpenVariants(item)}
                  aria-label={`${t('choose', lang)} ${primaryName}`}
                  style={{
                    width: 36, height: 36, borderRadius: 18,
                    border: '1.5px solid #C9A24B',
                    background: qty > 0 ? 'rgba(232,163,61,.18)' : 'transparent',
                    color: '#E8A33D',
                    fontSize: 18, lineHeight: 1, fontWeight: 700,
                    display: 'grid', placeItems: 'center',
                    cursor: 'pointer',
                    WebkitTapHighlightColor: 'transparent',
                  }}
                >+</button>
              </div>
            ) : qty === 0 ? (
              <button
                type="button"
                onClick={onAdd}
                aria-label={`${t('add', lang)} ${primaryName}`}
                style={{
                  width: 36, height: 36, borderRadius: 18,
                  border: 'none',
                  background: '#E8A33D',
                  color: '#1A1410',
                  fontSize: 22, lineHeight: 1, fontWeight: 700,
                  display: 'grid', placeItems: 'center',
                  cursor: 'pointer',
                  boxShadow: '0 6px 14px rgba(232,163,61,.35)',
                  WebkitTapHighlightColor: 'transparent',
                }}
              >+</button>
            ) : (
              <div style={{
                display: 'inline-flex', alignItems: 'center',
                height: 36, borderRadius: 18,
                background: '#1A1410',
                border: `1px solid #C9A24B`,
                color: '#F4EEDF',
                fontFamily: '"Cinzel", serif',
                fontWeight: 600,
              }}>
                <button
                  type="button"
                  onClick={onRemove}
                  aria-label={`${t('remove', lang)} ${primaryName}`}
                  style={{
                    width: 32, height: 36,
                    background: 'transparent', border: 'none',
                    color: '#A89580', fontSize: 18, cursor: 'pointer',
                    WebkitTapHighlightColor: 'transparent',
                  }}
                >−</button>
                <span style={{ minWidth: 22, textAlign: 'center', fontSize: 14 }}>{qty}</span>
                <button
                  type="button"
                  onClick={onAdd}
                  aria-label={`${t('add', lang)} ${primaryName}`}
                  style={{
                    width: 32, height: 36,
                    background: 'transparent', border: 'none',
                    color: '#E8A33D', fontSize: 18, cursor: 'pointer',
                    WebkitTapHighlightColor: 'transparent',
                  }}
                >+</button>
              </div>
            )}
          </div>
        </div>
      </div>
    </article>
  )
}
