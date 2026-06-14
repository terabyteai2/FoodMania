import 'mapbox-gl/dist/mapbox-gl.css'
import mapboxgl from 'mapbox-gl'
import React, { useEffect, useRef, useState } from 'react'
import { useTokens } from '../index.jsx'
import {
  cartTotal,
  taka,
  getBrowserPosition,
  reverseGeocodePosition,
  MAPBOX_TOKEN,
} from '../../App.jsx'
import { StarDivider } from './StarOrnament.jsx'
import { useLang, t, pick } from './i18n.js'

const COLOR_BG     = '#1A1410'
const COLOR_SURF   = '#2A1F1A'
const COLOR_GOLD   = '#C9A24B'
const COLOR_SAFF   = '#E8A33D'
const COLOR_IVORY  = '#F4EEDF'
const COLOR_MUTED  = '#A89580'
const COLOR_LINE   = '#4A3A2E'

// Default center for map if GPS is denied (Dhaka city center)
const DHAKA = { lng: 90.4125, lat: 23.8103 }

function Field({ label, value, onChange, type = 'text', autoComplete, placeholder, lang, multiline }) {
  const id = `f-${label}`.replace(/\s+/g, '-').toLowerCase()
  const labelFont = lang === 'bn'
    ? '"Hind Siliguri", system-ui, sans-serif'
    : '"Cinzel", serif'
  const baseFont = lang === 'bn'
    ? '"Hind Siliguri", system-ui, sans-serif'
    : '"Cormorant Garamond", serif'
  return (
    <label htmlFor={id} style={{ display: 'block' }}>
      <div style={{
        fontFamily: labelFont,
        fontSize: 11, letterSpacing: lang === 'bn' ? '.02em' : '.18em',
        textTransform: lang === 'bn' ? 'none' : 'uppercase',
        color: COLOR_GOLD,
        marginBottom: 6,
      }}>{label}</div>
      {multiline ? (
        <textarea
          id={id}
          value={value}
          onChange={e => onChange(e.target.value)}
          placeholder={placeholder || ''}
          rows={3}
          style={{
            width: '100%',
            padding: '12px 14px',
            background: COLOR_SURF,
            color: COLOR_IVORY,
            border: `1px solid ${COLOR_LINE}`,
            borderRadius: 10,
            fontFamily: baseFont,
            fontSize: 16,
            outline: 'none',
            resize: 'vertical',
          }}
          onFocus={e => { e.currentTarget.style.borderColor = COLOR_GOLD }}
          onBlur={e => { e.currentTarget.style.borderColor = COLOR_LINE }}
        />
      ) : (
        <input
          id={id}
          type={type}
          autoComplete={autoComplete}
          value={value}
          onChange={e => onChange(e.target.value)}
          placeholder={placeholder || ''}
          style={{
            width: '100%',
            height: 48,
            padding: '0 14px',
            background: COLOR_SURF,
            color: COLOR_IVORY,
            border: `1px solid ${COLOR_LINE}`,
            borderRadius: 10,
            fontFamily: baseFont,
            fontSize: 16,
            outline: 'none',
          }}
          onFocus={e => { e.currentTarget.style.borderColor = COLOR_GOLD }}
          onBlur={e => { e.currentTarget.style.borderColor = COLOR_LINE }}
        />
      )}
    </label>
  )
}

// ── Mapbox location picker sheet ───────────────────────────────────────────────
function MapboxPicker({ initialPosition, onConfirm, onClose }) {
  const lang = useLang()
  const mapContainerRef = useRef(null)
  const mapRef = useRef(null)
  const [addressPreview, setAddressPreview] = useState('')
  const [geocoding, setGeocoding] = useState(false)
  const geocodeTimerRef = useRef(null)

  async function geocodeCenter(lng, lat) {
    if (!MAPBOX_TOKEN) return
    setGeocoding(true)
    try {
      const res = await fetch(
        `https://api.mapbox.com/geocoding/v5/mapbox.places/${lng},${lat}.json` +
        `?access_token=${MAPBOX_TOKEN}&types=address,place&language=en&limit=1`,
      )
      const data = await res.json()
      const place = data?.features?.[0]?.place_name || ''
      setAddressPreview(place)
    } catch {
      setAddressPreview('')
    } finally {
      setGeocoding(false)
    }
  }

  useEffect(() => {
    if (!MAPBOX_TOKEN || !mapContainerRef.current) return
    let cancelled = false

    mapboxgl.accessToken = MAPBOX_TOKEN
    const center = initialPosition
      ? [initialPosition.lng, initialPosition.lat]
      : [DHAKA.lng, DHAKA.lat]

    const map = new mapboxgl.Map({
      container: mapContainerRef.current,
      style: 'mapbox://styles/mapbox/dark-v11',
      center,
      zoom: 15,
      attributionControl: false,
    })
    mapRef.current = map

    map.on('moveend', () => {
      if (cancelled) return
      const c = map.getCenter()
      clearTimeout(geocodeTimerRef.current)
      geocodeTimerRef.current = setTimeout(() => geocodeCenter(c.lng, c.lat), 400)
    })

    // Initial geocode for starting position
    geocodeCenter(center[0], center[1])

    return () => {
      cancelled = true
      clearTimeout(geocodeTimerRef.current)
      mapRef.current?.remove()
      mapRef.current = null
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  // Close on Escape
  useEffect(() => {
    const onKey = e => { if (e.key === 'Escape') onClose() }
    document.addEventListener('keydown', onKey)
    return () => document.removeEventListener('keydown', onKey)
  }, [onClose])

  function handleConfirm() {
    if (addressPreview) onConfirm(addressPreview)
    else if (mapRef.current) {
      const c = mapRef.current.getCenter()
      onConfirm(`${c.lat.toFixed(5)}, ${c.lng.toFixed(5)}`)
    }
    onClose()
  }

  return (
    <div style={{
      position: 'fixed', inset: 0, zIndex: 300,
      display: 'flex', flexDirection: 'column',
      background: COLOR_BG,
    }}>
      {/* Header */}
      <div style={{
        display: 'flex', alignItems: 'center', gap: 10,
        padding: 'calc(env(safe-area-inset-top) + 12px) 16px 12px',
        borderBottom: `1px solid ${COLOR_LINE}`,
        background: COLOR_BG,
        flexShrink: 0,
      }}>
        <button
          type="button"
          onClick={onClose}
          style={{
            width: 40, height: 40, borderRadius: 20,
            background: 'transparent', border: `1px solid ${COLOR_LINE}`,
            color: COLOR_IVORY, fontSize: 18, cursor: 'pointer',
            display: 'grid', placeItems: 'center',
            WebkitTapHighlightColor: 'transparent',
          }}
        >←</button>
        <span style={{
          fontFamily: '"Cinzel", serif',
          fontSize: 13,
          letterSpacing: '.18em',
          textTransform: 'uppercase',
          color: COLOR_SAFF,
        }}>{t('pinOnMap', lang)}</span>
      </div>

      {/* Map fills the rest */}
      <div style={{ flex: 1, position: 'relative', overflow: 'hidden' }}>
        <div ref={mapContainerRef} style={{ width: '100%', height: '100%' }} />

        {/* Fixed center crosshair pin */}
        <div aria-hidden="true" style={{
          position: 'absolute',
          left: '50%', top: '50%',
          transform: 'translate(-50%, -100%)',
          pointerEvents: 'none',
          zIndex: 10,
        }}>
          {/* Pin body */}
          <div style={{
            width: 28, height: 28, borderRadius: 14,
            background: COLOR_SAFF,
            border: '3px solid #fff',
            boxShadow: '0 4px 14px rgba(0,0,0,.5)',
            position: 'relative',
          }}>
            <div style={{
              width: 8, height: 8, borderRadius: 4,
              background: COLOR_BG,
              position: 'absolute',
              left: '50%', top: '50%',
              transform: 'translate(-50%, -50%)',
            }} />
          </div>
          {/* Pin tail */}
          <div style={{
            width: 0, height: 0,
            borderLeft: '6px solid transparent',
            borderRight: '6px solid transparent',
            borderTop: `10px solid ${COLOR_SAFF}`,
            margin: '0 auto',
          }} />
        </div>
      </div>

      {/* Address preview + confirm */}
      <div style={{
        padding: '14px 16px calc(env(safe-area-inset-bottom) + 16px)',
        borderTop: `1px solid ${COLOR_LINE}`,
        background: COLOR_SURF,
        flexShrink: 0,
      }}>
        <div style={{
          fontSize: 13,
          color: geocoding ? COLOR_MUTED : COLOR_IVORY,
          fontFamily: '"Cormorant Garamond", serif',
          fontStyle: 'italic',
          minHeight: 18,
          marginBottom: 14,
          lineHeight: 1.4,
        }}>
          {geocoding
            ? t('detectingAddress', lang)
            : addressPreview || '…'}
        </div>
        <button
          type="button"
          onClick={handleConfirm}
          disabled={geocoding && !addressPreview}
          style={{
            width: '100%',
            height: 52,
            borderRadius: 12,
            background: COLOR_SAFF,
            color: COLOR_BG,
            border: 'none',
            fontFamily: '"Cinzel", serif',
            fontWeight: 700,
            fontSize: 14,
            letterSpacing: '.14em',
            textTransform: 'uppercase',
            cursor: 'pointer',
            opacity: (geocoding && !addressPreview) ? .5 : 1,
            WebkitTapHighlightColor: 'transparent',
          }}
        >{t('confirmLocation', lang)}</button>
      </div>
    </div>
  )
}

// ── Main HearthCart ────────────────────────────────────────────────────────────
export default function HearthCart({
  cart, cartExtras, items, note, onNote,
  delivery, onDelivery,
  onAdd, onRemove, onBack, onPlace,
  submitting, info, outletId, isTableOrder = false, tableNo = '',
}) {
  const T = useTokens()
  const lang = useLang()

  // Build cart items, resolving modifier variant keys via cartExtras
  const cartItems = Object.entries(cart)
    .map(([key, qty]) => {
      const extra = cartExtras?.[key]
      const baseItem = extra
        ? items.find(i => i.id === extra.baseId)
        : items.find(i => i.id === key)
      if (!baseItem) return null
      return {
        ...baseItem,
        cartKey: key,
        qty,
        effectivePrice: extra?.price ?? baseItem.price,
        modsLabel: extra?.modsLabel || '',
      }
    })
    .filter(Boolean)

  const total = cartTotal(cart, items, cartExtras)
  const deliveryReady = isTableOrder ||
    (delivery.name.trim() &&
     delivery.address.trim() &&
     delivery.mobile.trim().length >= 7)

  const [geo, setGeo] = useState({ status: 'idle', address: '', error: '' })
  const [showPicker, setShowPicker] = useState(false)
  const mountedRef = useRef(true)
  const addressRef = useRef(delivery.address)
  useEffect(() => { addressRef.current = delivery.address }, [delivery.address])

  useEffect(() => {
    mountedRef.current = true
    if (!isTableOrder) detectAddress()
    return () => { mountedRef.current = false }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isTableOrder])

  async function detectAddress() {
    if (!outletId || outletId === '__demo__') {
      if (!mountedRef.current) return
      setGeo({ status: 'error', address: '', error: 'unavailable' })
      return
    }
    if (!mountedRef.current) return
    setGeo(g => ({ ...g, status: 'locating', error: '' }))
    try {
      const position = await getBrowserPosition()
      if (!mountedRef.current) return
      setGeo({ status: 'geocoding', address: '', error: '' })
      const address = await reverseGeocodePosition(position, outletId)
      if (!mountedRef.current) return
      setGeo({ status: 'ready', address, error: '' })
      if (!addressRef.current.trim()) {
        onDelivery(current => ({ ...current, address }))
      }
    } catch (e) {
      if (!mountedRef.current) return
      setGeo(g => ({ ...g, status: 'error', error: e.message || 'failed' }))
    }
  }

  function handlePickerConfirm(address) {
    onDelivery(d => ({ ...d, address }))
    setGeo(g => ({ ...g, address, status: 'ready' }))
  }

  const restaurantName = info?.restaurantName || ''
  const outletName = info?.outletName || ''

  return (
    <>
      {showPicker && (
        <MapboxPicker
          initialPosition={null}
          onConfirm={handlePickerConfirm}
          onClose={() => setShowPicker(false)}
        />
      )}

      <div style={{
        minHeight: '100svh',
        background: COLOR_BG,
        color: COLOR_IVORY,
        display: 'flex', flexDirection: 'column',
        fontFamily: '"Cormorant Garamond", serif',
      }}>
        {/* Header */}
        <header style={{
          position: 'sticky', top: 0, zIndex: 10,
          background: COLOR_BG,
          borderBottom: `1px solid ${COLOR_LINE}`,
          padding: 'calc(env(safe-area-inset-top) + 14px) 16px 14px',
          display: 'flex', alignItems: 'center', gap: 12,
        }}>
          <button
            type="button"
            onClick={onBack}
            aria-label={t('back', lang)}
            style={{
              width: 44, height: 44, borderRadius: 22,
              background: 'transparent',
              border: `1px solid ${COLOR_LINE}`,
              color: COLOR_IVORY,
              fontSize: 20, cursor: 'pointer',
              display: 'grid', placeItems: 'center',
              WebkitTapHighlightColor: 'transparent',
            }}
          >←</button>
          <div style={{ minWidth: 0, flex: 1 }}>
            <div style={{
              display: 'flex', alignItems: 'center', gap: 10,
              marginBottom: 2,
            }}>
              <span style={{ width: 16, height: 1, background: COLOR_GOLD }} />
              <h1 style={{
                margin: 0,
                fontFamily: lang === 'bn'
                  ? '"Hind Siliguri", system-ui, sans-serif'
                  : '"Cinzel", serif',
                fontWeight: 700,
                fontSize: 16,
                letterSpacing: lang === 'bn' ? '.02em' : '.24em',
                textTransform: lang === 'bn' ? 'none' : 'uppercase',
                color: COLOR_SAFF,
              }}>{t('yourOrder', lang)}</h1>
              <span style={{ width: 16, height: 1, background: COLOR_GOLD }} />
            </div>
            {restaurantName && (
              <div style={{
                fontFamily: '"Cormorant Garamond", serif',
                fontStyle: 'italic',
                fontSize: 13,
                color: COLOR_MUTED,
                overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
              }}>
                {restaurantName}{outletName ? ` · ${outletName}` : ''}
              </div>
            )}
          </div>
        </header>

        {/* Scroll body */}
        <div style={{
          flex: 1, overflowY: 'auto',
          padding: '8px 16px calc(env(safe-area-inset-bottom) + 200px)',
        }}>
          {/* Items list */}
          {cartItems.length === 0 ? (
            <div style={{
              textAlign: 'center', padding: '60px 20px',
              color: COLOR_MUTED, fontStyle: 'italic',
            }}>{t('noItems', lang)}</div>
          ) : (
            <ul style={{ listStyle: 'none', margin: 0, padding: '6px 0 0' }}>
              {cartItems.map((item, i) => {
                const primaryName = pick(item, 'name', lang) || item.nameEn || item.name || item.nameBn
                const secondaryName = lang === 'bn'
                  ? (item.nameEn || item.name || '')
                  : (item.nameBn || '')
                return (
                  <li
                    key={item.cartKey}
                    className="fade-up"
                    style={{
                      padding: '14px 0',
                      borderBottom: i === cartItems.length - 1 ? 'none' : `1px solid ${COLOR_LINE}`,
                      display: 'grid',
                      gridTemplateColumns: '56px 1fr auto',
                      gap: 12, alignItems: 'center',
                      animationDelay: `${Math.min(i * 0.04, 0.2)}s`,
                    }}
                  >
                    <div style={{
                      width: 56, height: 56, borderRadius: 8,
                      background: COLOR_SURF, position: 'relative',
                      ...(item.imageUrl ? {
                        backgroundImage: `url(${item.imageUrl})`,
                        backgroundSize: 'cover', backgroundPosition: 'center',
                      } : {}),
                    }}>
                      <div aria-hidden="true" style={{
                        position: 'absolute', inset: 0, borderRadius: 8,
                        boxShadow: 'inset 0 0 0 1px rgba(201,162,75,.18)',
                      }} />
                    </div>
                    <div style={{ minWidth: 0 }}>
                      <div style={{
                        fontFamily: '"Cormorant Garamond", serif',
                        fontStyle: 'italic',
                        fontSize: 16, lineHeight: 1.2,
                        color: COLOR_IVORY,
                        overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
                      }}>{primaryName}</div>
                      {secondaryName && secondaryName !== primaryName && (
                        <div style={{
                          fontFamily: '"Hind Siliguri", system-ui, sans-serif',
                          fontSize: 13, color: COLOR_MUTED,
                          overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
                        }}>{secondaryName}</div>
                      )}
                      {item.modsLabel && (
                        <div style={{
                          fontFamily: '"Cormorant Garamond", serif',
                          fontSize: 12, color: COLOR_GOLD,
                          marginTop: 1,
                          overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
                        }}>{item.modsLabel}</div>
                      )}
                      <div style={{
                        marginTop: 6,
                        display: 'inline-flex', alignItems: 'center',
                        height: 32, borderRadius: 16,
                        border: `1px solid ${COLOR_LINE}`,
                        background: COLOR_SURF,
                      }}>
                        <button
                          type="button"
                          onClick={() => onRemove(item.cartKey)}
                          aria-label={t('remove', lang)}
                          style={{
                            width: 32, height: 32, background: 'transparent', border: 'none',
                            color: COLOR_MUTED, fontSize: 16, cursor: 'pointer',
                            WebkitTapHighlightColor: 'transparent',
                          }}
                        >−</button>
                        <span style={{
                          minWidth: 20, textAlign: 'center', fontSize: 14,
                          fontFamily: '"Cinzel", serif', color: COLOR_IVORY,
                        }}>{item.qty}</span>
                        <button
                          type="button"
                          onClick={() => onAdd(item.cartKey)}
                          aria-label={t('add', lang)}
                          style={{
                            width: 32, height: 32, background: 'transparent', border: 'none',
                            color: COLOR_SAFF, fontSize: 16, cursor: 'pointer',
                            WebkitTapHighlightColor: 'transparent',
                          }}
                        >+</button>
                      </div>
                    </div>
                    <div style={{
                      fontFamily: '"Cinzel", serif',
                      fontWeight: 600,
                      fontSize: 16,
                      color: COLOR_SAFF,
                      whiteSpace: 'nowrap',
                    }}>
                      <span style={{ fontSize: 12, marginRight: 1, opacity: .85 }}>৳</span>
                      {Math.round(item.effectivePrice * item.qty).toLocaleString('en-BD')}
                    </div>
                  </li>
                )
              })}
            </ul>
          )}

          <div style={{ margin: '20px 0 6px' }}><StarDivider /></div>

          {isTableOrder ? (
            <section style={{
              marginTop: 12,
              padding: '14px 16px',
              border: `1px solid ${COLOR_LINE}`,
              borderRadius: 12,
              color: COLOR_SAFF,
              background: 'rgba(201,162,75,.10)',
              fontFamily: lang === 'bn'
                ? '"Hind Siliguri", system-ui, sans-serif'
                : '"Cinzel", serif',
              textTransform: lang === 'bn' ? 'none' : 'uppercase',
              letterSpacing: lang === 'bn' ? '.02em' : '.16em',
              textAlign: 'center',
            }}>
              {lang === 'bn' ? `টেবিল ${tableNo}` : `Table ${tableNo}`}
            </section>
          ) : (
            <section style={{ marginTop: 10 }}>
              <h2 style={{
                margin: '0 0 14px',
                fontFamily: lang === 'bn'
                  ? '"Hind Siliguri", system-ui, sans-serif'
                  : '"Cinzel", serif',
                fontWeight: 600,
                fontSize: 14,
                letterSpacing: lang === 'bn' ? '.02em' : '.22em',
                textTransform: lang === 'bn' ? 'none' : 'uppercase',
                color: COLOR_GOLD,
                textAlign: 'center',
              }}>{t('yourDetails', lang)}</h2>

              <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
                <Field
                  lang={lang}
                  label={t('name', lang)}
                  value={delivery.name}
                  onChange={v => onDelivery(d => ({ ...d, name: v }))}
                  autoComplete="name"
                />
                <Field
                  lang={lang}
                  label={t('mobile', lang)}
                  value={delivery.mobile}
                  onChange={v => onDelivery(d => ({ ...d, mobile: v }))}
                  type="tel"
                  autoComplete="tel"
                />

                {/* Address field + map pin button */}
                <div>
                  <div style={{
                    fontFamily: lang === 'bn'
                      ? '"Hind Siliguri", system-ui, sans-serif'
                      : '"Cinzel", serif',
                    fontSize: 11, letterSpacing: lang === 'bn' ? '.02em' : '.18em',
                    textTransform: lang === 'bn' ? 'none' : 'uppercase',
                    color: COLOR_GOLD,
                    marginBottom: 6,
                  }}>{t('address', lang)}</div>
                  <div style={{ position: 'relative' }}>
                    <textarea
                      value={delivery.address}
                      onChange={e => onDelivery(d => ({ ...d, address: e.target.value }))}
                      autoComplete="street-address"
                      placeholder=""
                      rows={3}
                      style={{
                        width: '100%',
                        padding: '12px 46px 12px 14px',
                        background: COLOR_SURF,
                        color: COLOR_IVORY,
                        border: `1px solid ${COLOR_LINE}`,
                        borderRadius: 10,
                        fontFamily: lang === 'bn'
                          ? '"Hind Siliguri", system-ui, sans-serif'
                          : '"Cormorant Garamond", serif',
                        fontSize: 16,
                        outline: 'none',
                        resize: 'vertical',
                      }}
                      onFocus={e => { e.currentTarget.style.borderColor = COLOR_GOLD }}
                      onBlur={e => { e.currentTarget.style.borderColor = COLOR_LINE }}
                    />
                    {/* Pin on map button */}
                    {MAPBOX_TOKEN && (
                      <button
                        type="button"
                        onClick={() => setShowPicker(true)}
                        title={t('pinOnMap', lang)}
                        style={{
                          position: 'absolute',
                          top: 10, right: 10,
                          width: 30, height: 30,
                          borderRadius: 8,
                          background: 'rgba(201,162,75,.18)',
                          border: `1px solid ${COLOR_GOLD}`,
                          color: COLOR_SAFF,
                          cursor: 'pointer',
                          display: 'grid', placeItems: 'center',
                          WebkitTapHighlightColor: 'transparent',
                        }}
                      >
                        <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
                          <circle cx="7" cy="6" r="3" stroke="currentColor" strokeWidth="1.5"/>
                          <path d="M7 14C7 14 2 9.5 2 6a5 5 0 0 1 10 0c0 3.5-5 8-5 8z" stroke="currentColor" strokeWidth="1.5" fill="none"/>
                        </svg>
                      </button>
                    )}
                  </div>

                  {/* GPS status / use-detected button */}
                  {(geo.status === 'locating' || geo.status === 'geocoding') ? (
                    <div style={{
                      fontSize: 12, color: COLOR_MUTED,
                      fontStyle: 'italic', marginTop: 6,
                    }}>{t('detectingAddress', lang)}</div>
                  ) : geo.status === 'ready' && geo.address && geo.address !== delivery.address ? (
                    <button
                      type="button"
                      onClick={() => onDelivery(d => ({ ...d, address: geo.address }))}
                      style={{
                        marginTop: 6, alignSelf: 'flex-start',
                        background: 'transparent', border: `1px solid ${COLOR_GOLD}`,
                        color: COLOR_SAFF, padding: '6px 12px', borderRadius: 14,
                        fontFamily: '"Cinzel", serif', fontSize: 11,
                        letterSpacing: '.14em', textTransform: 'uppercase',
                        cursor: 'pointer',
                        WebkitTapHighlightColor: 'transparent',
                      }}
                    >{t('useDetected', lang)}</button>
                  ) : null}
                </div>

                <Field
                  lang={lang}
                  label={t('note', lang)}
                  value={note}
                  onChange={onNote}
                  multiline
                />
              </div>
            </section>
          )}
        </div>

        {/* Sticky bottom total + place order */}
        <div style={{
          position: 'fixed', left: 0, right: 0, bottom: 0,
          zIndex: 20,
          background: COLOR_SURF,
          borderTop: `1px solid ${COLOR_GOLD}55`,
          padding: '12px 16px calc(env(safe-area-inset-bottom) + 12px)',
          boxShadow: '0 -10px 30px rgba(0,0,0,.45)',
        }}>
          <div style={{
            display: 'flex', alignItems: 'center', justifyContent: 'space-between',
            marginBottom: 10,
          }}>
            <span style={{
              fontFamily: lang === 'bn'
                ? '"Hind Siliguri", system-ui, sans-serif'
                : '"Cinzel", serif',
              fontWeight: 600,
              fontSize: 12, letterSpacing: '.22em',
              textTransform: lang === 'bn' ? 'none' : 'uppercase',
              color: COLOR_MUTED,
            }}>{t('total', lang)}</span>
            <span style={{
              fontFamily: '"Cinzel", serif',
              fontWeight: 700,
              fontSize: 22,
              color: COLOR_SAFF,
            }}>
              <span style={{ fontSize: 14, marginRight: 2, opacity: .85 }}>৳</span>
              {Math.round(total).toLocaleString('en-BD')}
            </span>
          </div>
          <button
            type="button"
            onClick={onPlace}
            disabled={!deliveryReady || submitting || cartItems.length === 0}
            style={{
              width: '100%',
              height: 56,
              borderRadius: 12,
              background: (!deliveryReady || cartItems.length === 0) ? '#5a4a36' : COLOR_SAFF,
              color: COLOR_BG,
              border: 'none',
              boxShadow: (!deliveryReady || cartItems.length === 0)
                ? 'none'
                : 'inset 0 0 0 1px #C9A24B, 0 14px 38px rgba(232,163,61,.32)',
              fontFamily: '"Cinzel", serif',
              fontWeight: 700,
              fontSize: 14,
              letterSpacing: '.18em',
              textTransform: 'uppercase',
              cursor: (!deliveryReady || cartItems.length === 0 || submitting) ? 'not-allowed' : 'pointer',
              opacity: submitting ? .7 : 1,
              WebkitTapHighlightColor: 'transparent',
            }}
          >{submitting ? t('placingOrder', lang) : t('placeOrder', lang)}</button>
        </div>
      </div>
    </>
  )
}
