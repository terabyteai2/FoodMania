import React, { useEffect, useState } from 'react'
import { useTokens } from '../index.jsx'
import { useLang, t, pick } from './i18n.js'

const COLOR_BG    = '#1A1410'
const COLOR_SURF  = '#2A1F1A'
const COLOR_GOLD  = '#C9A24B'
const COLOR_SAFF  = '#E8A33D'
const COLOR_IVORY = '#F4EEDF'
const COLOR_MUTED = '#A89580'
const COLOR_LINE  = '#4A3A2E'
const COLOR_DARK  = '#1A1410'

export default function HearthModifierSheet({ item, onClose, onAddWithMods }) {
  const T = useTokens()
  const lang = useLang()
  const name = pick(item, 'name', lang) || item.nameEn || item.name || ''

  const hasOptions = item.options && item.options.length > 0
  const hasAddons  = item.addons  && item.addons.length  > 0

  const [selectedOption, setSelectedOption] = useState(
    hasOptions ? item.options[0] : null,
  )
  const [selectedAddons, setSelectedAddons] = useState([])
  const [qty, setQty] = useState(1)

  const optionDelta   = selectedOption?.priceDelta ?? 0
  const addonTotal    = selectedAddons.reduce((s, a) => s + a.price, 0)
  const effectivePrice = item.price + optionDelta + addonTotal
  const lineTotal      = effectivePrice * qty

  // Close on Escape
  useEffect(() => {
    const onKey = e => { if (e.key === 'Escape') onClose() }
    document.addEventListener('keydown', onKey)
    return () => document.removeEventListener('keydown', onKey)
  }, [onClose])

  // Prevent body scroll while open
  useEffect(() => {
    const prev = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    return () => { document.body.style.overflow = prev }
  }, [])

  function toggleAddon(addon) {
    setSelectedAddons(prev =>
      prev.some(a => a.label === addon.label)
        ? prev.filter(a => a.label !== addon.label)
        : [...prev, addon],
    )
  }

  function handleAdd() {
    onAddWithMods(item, {
      option: selectedOption,
      addons: selectedAddons,
      qty,
      effectivePrice,
    })
    onClose()
  }

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-label={name}
      style={{
        position: 'fixed', inset: 0, zIndex: 200,
        display: 'flex', flexDirection: 'column', justifyContent: 'flex-end',
      }}
    >
      {/* Scrim */}
      <div
        aria-hidden="true"
        onClick={onClose}
        style={{
          position: 'absolute', inset: 0,
          background: 'rgba(10,8,6,.72)',
          backdropFilter: 'blur(2px)',
          WebkitBackdropFilter: 'blur(2px)',
        }}
      />

      {/* Sheet */}
      <div style={{
        position: 'relative', zIndex: 1,
        background: COLOR_SURF,
        borderRadius: '16px 16px 0 0',
        borderTop: `1px solid ${COLOR_LINE}`,
        maxHeight: '90svh',
        display: 'flex', flexDirection: 'column',
        boxShadow: '0 -18px 44px rgba(0,0,0,.55)',
      }}>
        {/* Grab handle */}
        <div aria-hidden="true" style={{
          width: 38, height: 4, borderRadius: 2,
          background: COLOR_LINE,
          margin: '10px auto 0',
          flexShrink: 0,
        }} />

        {/* Scrollable body */}
        <div style={{ overflowY: 'auto', padding: '14px 20px 8px', flex: 1 }}>

          {/* Item name + base price */}
          <div style={{ marginBottom: 18, textAlign: 'center' }}>
            <div style={{
              fontFamily: '"Cormorant Garamond", serif',
              fontStyle: 'italic',
              fontSize: 21,
              color: COLOR_IVORY,
              lineHeight: 1.2,
            }}>{name}</div>
            <div style={{
              marginTop: 6,
              fontFamily: '"Cinzel", serif',
              fontWeight: 600,
              fontSize: 16,
              color: COLOR_SAFF,
            }}>
              <span style={{ fontSize: 12, marginRight: 1, opacity: .85 }}>৳</span>
              {Math.round(effectivePrice).toLocaleString('en-BD')}
            </div>
          </div>

          {/* Options (single-select) */}
          {hasOptions && (
            <div style={{ marginBottom: 20 }}>
              <div style={{
                fontFamily: '"Cinzel", serif',
                fontSize: 11,
                letterSpacing: '.18em',
                textTransform: 'uppercase',
                color: COLOR_GOLD,
                marginBottom: 10,
              }}>{t('choose', lang)}</div>
              <div style={{
                display: 'flex',
                flexWrap: 'wrap',
                gap: 8,
              }}>
                {item.options.map(opt => {
                  const active = selectedOption?.label === opt.label
                  return (
                    <button
                      key={opt.label}
                      type="button"
                      onClick={() => setSelectedOption(opt)}
                      style={{
                        padding: '8px 16px',
                        borderRadius: 8,
                        border: `1px solid ${active ? COLOR_SAFF : COLOR_LINE}`,
                        background: active ? 'rgba(232,163,61,.18)' : 'transparent',
                        color: active ? COLOR_SAFF : COLOR_MUTED,
                        fontFamily: '"Cinzel", serif',
                        fontWeight: active ? 700 : 400,
                        fontSize: 13,
                        cursor: 'pointer',
                        WebkitTapHighlightColor: 'transparent',
                        transition: 'border-color .12s, color .12s',
                      }}
                    >
                      {opt.label}
                      {opt.priceDelta !== 0 && (
                        <span style={{ marginLeft: 6, fontSize: 11, opacity: .8 }}>
                          {opt.priceDelta > 0 ? '+' : ''}৳{Math.round(opt.priceDelta)}
                        </span>
                      )}
                    </button>
                  )
                })}
              </div>
            </div>
          )}

          {/* Addons (multi-select) */}
          {hasAddons && (
            <div style={{ marginBottom: 20 }}>
              <div style={{
                fontFamily: '"Cinzel", serif',
                fontSize: 11,
                letterSpacing: '.18em',
                textTransform: 'uppercase',
                color: COLOR_GOLD,
                marginBottom: 10,
              }}>{t('optionalExtras', lang)}</div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                {item.addons.map(addon => {
                  const checked = selectedAddons.some(a => a.label === addon.label)
                  return (
                    <label
                      key={addon.label}
                      style={{
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'space-between',
                        padding: '10px 12px',
                        borderRadius: 8,
                        border: `1px solid ${checked ? COLOR_GOLD : COLOR_LINE}`,
                        background: checked ? 'rgba(201,162,75,.10)' : 'transparent',
                        cursor: 'pointer',
                        WebkitTapHighlightColor: 'transparent',
                      }}
                    >
                      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                        {/* Checkbox visual */}
                        <div style={{
                          width: 18, height: 18,
                          borderRadius: 4,
                          border: `1.5px solid ${checked ? COLOR_SAFF : COLOR_LINE}`,
                          background: checked ? COLOR_SAFF : 'transparent',
                          display: 'grid', placeItems: 'center',
                          flexShrink: 0,
                        }}>
                          {checked && (
                            <svg width="10" height="8" viewBox="0 0 10 8" fill="none">
                              <path d="M1 4l3 3 5-6" stroke={COLOR_DARK} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
                            </svg>
                          )}
                        </div>
                        <span style={{
                          fontFamily: '"Cormorant Garamond", serif',
                          fontSize: 15,
                          color: checked ? COLOR_IVORY : COLOR_MUTED,
                        }}>{addon.label}</span>
                      </div>
                      <span style={{
                        fontFamily: '"Cinzel", serif',
                        fontSize: 13,
                        color: COLOR_SAFF,
                        whiteSpace: 'nowrap',
                      }}>+৳{Math.round(addon.price)}</span>
                      <input
                        type="checkbox"
                        checked={checked}
                        onChange={() => toggleAddon(addon)}
                        style={{ position: 'absolute', opacity: 0, pointerEvents: 'none' }}
                      />
                    </label>
                  )
                })}
              </div>
            </div>
          )}

          {/* Qty stepper */}
          <div style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: 16,
            marginBottom: 8,
          }}>
            <button
              type="button"
              onClick={() => setQty(q => Math.max(1, q - 1))}
              disabled={qty <= 1}
              style={{
                width: 38, height: 38, borderRadius: 8,
                border: `1px solid ${COLOR_LINE}`,
                background: 'transparent',
                color: qty <= 1 ? COLOR_LINE : COLOR_MUTED,
                fontSize: 20, cursor: qty <= 1 ? 'not-allowed' : 'pointer',
                display: 'grid', placeItems: 'center',
                WebkitTapHighlightColor: 'transparent',
              }}
            >−</button>
            <span style={{
              fontFamily: '"Cinzel", serif',
              fontSize: 20, fontWeight: 700,
              color: COLOR_IVORY,
              minWidth: 28, textAlign: 'center',
            }}>{qty}</span>
            <button
              type="button"
              onClick={() => setQty(q => q + 1)}
              style={{
                width: 38, height: 38, borderRadius: 8,
                border: `1px solid ${COLOR_GOLD}`,
                background: 'transparent',
                color: COLOR_SAFF,
                fontSize: 20, cursor: 'pointer',
                display: 'grid', placeItems: 'center',
                WebkitTapHighlightColor: 'transparent',
              }}
            >+</button>
          </div>
        </div>

        {/* Sticky CTA */}
        <div style={{
          padding: '12px 20px calc(env(safe-area-inset-bottom) + 16px)',
          borderTop: `1px solid ${COLOR_LINE}`,
          background: COLOR_SURF,
          flexShrink: 0,
        }}>
          <button
            type="button"
            onClick={handleAdd}
            style={{
              width: '100%',
              height: 56,
              borderRadius: 12,
              background: COLOR_SAFF,
              color: COLOR_DARK,
              border: 'none',
              boxShadow: 'inset 0 0 0 1px #C9A24B, 0 14px 38px rgba(232,163,61,.32)',
              fontFamily: '"Cinzel", serif',
              fontWeight: 700,
              fontSize: 14,
              letterSpacing: '.14em',
              textTransform: 'uppercase',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: 10,
              WebkitTapHighlightColor: 'transparent',
            }}
          >
            <span>{t('addToOrder', lang)}</span>
            <span style={{ opacity: .75 }}>·</span>
            <span>
              <span style={{ fontSize: 11, marginRight: 1 }}>৳</span>
              {Math.round(lineTotal).toLocaleString('en-BD')}
            </span>
          </button>
        </div>
      </div>
    </div>
  )
}
