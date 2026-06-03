import React, { forwardRef, useEffect, useMemo, useRef, useState } from 'react'
import {
  buildMedia,
  cartCount,
  cartTotal,
  generateReceipt,
  getBrowserPosition,
  MenuFallbackIcon,
  reverseGeocodePosition,
  taka,
} from '../../App.jsx'
import { pick, t, toggleLangUrl, useLang } from '../sultans_hearth/i18n.js'

const NAV_HEIGHT = 64
const INTER = '"Inter", "Hind Siliguri", system-ui, sans-serif'

function themeAssetPaths(slug) {
  const basename = slug === 'sultans_hearth' ? 'hearth' : slug
  return {
    placeholderVideo: `/uploads/template_placeholders/${basename}.mp4`,
    placeholderImage: `/uploads/template_placeholders/${basename}.png`,
  }
}

function prefersReducedMotion() {
  return typeof window !== 'undefined' && window.matchMedia?.('(prefers-reduced-motion: reduce)').matches
}

function isDataSaver() {
  if (typeof navigator === 'undefined') return false
  const c = navigator.connection || navigator.webkitConnection || navigator.mozConnection
  return !!(c && c.saveData)
}

function smoothScrollTo(el, offset = 0) {
  if (!el) return
  const top = el.getBoundingClientRect().top + window.scrollY - offset
  window.scrollTo({ top, behavior: prefersReducedMotion() ? 'auto' : 'smooth' })
}

function groupItems(items) {
  const order = []
  const byCat = {}
  const bnMap = {}
  for (const it of items || []) {
    const cat = it.categoryEn || it.category || 'General'
    if (!byCat[cat]) {
      byCat[cat] = []
      order.push(cat)
    }
    byCat[cat].push(it)
    if (!bnMap[cat] && it.categoryBn) bnMap[cat] = it.categoryBn
  }
  return { order, byCat, bnMap }
}

function langFont(lang, fallback) {
  return lang === 'bn' ? '"Hind Siliguri", system-ui, sans-serif' : fallback
}

function itemName(item, lang) {
  return pick(item, 'name', lang) || item?.nameEn || item?.name || item?.nameBn || 'Item'
}

function alternateName(item, lang) {
  return lang === 'bn'
    ? (item?.nameEn || item?.name || '')
    : (item?.nameBn || '')
}

function itemDescription(item, lang) {
  return pick(item, 'description', lang) || item?.description || ''
}

function findFeatured(items) {
  return (items || []).find(it => it.tag || (Array.isArray(it.tags) && it.tags.length)) ||
    (items || []).find(it => it.imageUrl) ||
    (items || [])[0]
}

function makeOverrides(C) {
  function Loading() {
    return (
      <div style={{ minHeight: '100svh', display: 'grid', placeItems: 'center', background: C.bg, color: C.muted, fontFamily: C.body }}>
        <div style={{ textAlign: 'center' }}>
          <div style={{
            width: 42, height: 42, margin: '0 auto 18px', borderRadius: 24,
            border: `2px solid ${C.line}`, borderTopColor: C.accent, animation: 'spin .9s linear infinite',
          }} />
          <div style={{ fontSize: 12, fontWeight: 800, letterSpacing: '.14em', textTransform: 'uppercase' }}>{t('loading', 'en')}</div>
        </div>
      </div>
    )
  }

  function Error({ message }) {
    return (
      <div style={{ minHeight: '100svh', display: 'grid', placeItems: 'center', padding: 24, background: C.bg, color: C.ink, fontFamily: C.body }}>
        <p style={{ maxWidth: 320, textAlign: 'center', color: C.accent, fontFamily: C.display, fontSize: 22 }}>{message}</p>
      </div>
    )
  }

  function Hero({ info, onSeeMenu }) {
    const lang = useLang()
    const heroRef = useRef(null)
    const videoRef = useRef(null)
    const [videoOk, setVideoOk] = useState(false)
    const assets = themeAssetPaths(C.slug)
    const posterUrl = info?.bannerUrl || info?.galleryImages?.[0] || assets.placeholderImage
    const videoUrl = info?.videoUrl || assets.placeholderVideo
    const name = info?.restaurantNameEn || info?.restaurantName || 'Restaurant'
    const nameBn = info?.restaurantNameBn
    const outlet = info?.outletName || info?.outletNameEn || 'Dine-in menu'

    useEffect(() => {
      if (!videoUrl || prefersReducedMotion() || isDataSaver() || !heroRef.current) return
      const el = heroRef.current
      const io = new IntersectionObserver(entries => {
        if (entries.some(e => e.isIntersecting)) {
          setVideoOk(true)
          io.disconnect()
        }
      })
      io.observe(el)
      return () => io.disconnect()
    }, [videoUrl])

    useEffect(() => {
      if (videoOk && videoRef.current) videoRef.current.play().catch(() => {})
    }, [videoOk])

    return (
      <section ref={heroRef} style={{
        position: 'relative', minHeight: 560, height: '100svh', overflow: 'hidden',
        background: C.bg, color: C.heroText,
      }}>
        <div aria-hidden="true" style={{ position: 'absolute', inset: 0, background: C.heroFallback }} />
        <div aria-hidden="true" style={{ position: 'absolute', inset: 0, opacity: C.heroPatternOpacity, background: C.heroPattern }} />
        {posterUrl && (
          <img src={posterUrl} alt="" loading="eager" fetchpriority="high" decoding="async"
            onError={e => { e.currentTarget.style.display = 'none' }}
            style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover' }} />
        )}
        {videoOk && videoUrl && (
          <video ref={videoRef} src={videoUrl} poster={posterUrl || undefined} muted autoPlay loop playsInline preload="metadata"
            onError={() => setVideoOk(false)}
            style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover' }} />
        )}
        <div aria-hidden="true" style={{ position: 'absolute', inset: 0, background: C.heroOverlay }} />

        <a href={toggleLangUrl(lang)} style={{
          position: 'absolute', top: 'calc(env(safe-area-inset-top) + 16px)', right: 16, zIndex: 4,
          minWidth: 48, height: 44, borderRadius: C.radius, display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
          padding: '0 14px', background: C.glass, color: C.accent, border: `1px solid ${C.line}`,
          fontFamily: langFont(lang, C.body), fontSize: 13, fontWeight: 800, textDecoration: 'none',
          backdropFilter: 'blur(8px)', WebkitBackdropFilter: 'blur(8px)',
        }}>{t('langToggle', lang)}</a>
        {info?.logoUrl && (
          <img src={info.logoUrl} alt="" aria-hidden="true" style={{
            position: 'absolute', top: 'calc(env(safe-area-inset-top) + 16px)', left: 16, zIndex: 4,
            width: 54, height: 54, objectFit: 'cover', borderRadius: C.radius,
            background: C.glass, border: `1px solid ${C.line}`, boxShadow: '0 8px 28px rgba(0,0,0,.28)',
          }} />
        )}

        <div style={{
          position: 'absolute', top: `calc(env(safe-area-inset-top) + ${info?.logoUrl ? 84 : 58}px)`, left: 20, right: 20, zIndex: 3,
          display: 'flex', justifyContent: 'space-between', alignItems: 'center',
          fontFamily: langFont(lang, C.body), fontSize: 11, color: C.heroSoft, letterSpacing: lang === 'bn' ? 0 : '.18em',
          textTransform: lang === 'bn' ? 'none' : 'uppercase',
        }}>
          <span>{outlet}</span>
          <span style={{ color: C.accent }}>Menu</span>
        </div>

        <div style={{
          position: 'absolute', inset: 0, zIndex: 3, display: 'flex', flexDirection: 'column',
          justifyContent: 'center', alignItems: 'center', textAlign: 'center', padding: '0 22px',
        }}>
          <div style={{ fontFamily: langFont(lang, C.body), color: C.accent, fontSize: 10, fontWeight: 800, letterSpacing: lang === 'bn' ? 0 : '.36em', textTransform: lang === 'bn' ? 'none' : 'uppercase', marginBottom: 18 }}>
            {C.heroKicker}
          </div>
          <h1 style={{
            margin: 0, maxWidth: 560, fontFamily: langFont(lang, C.display), fontSize: C.heroTitleSize,
            fontWeight: C.heroWeight, color: C.heroTitle, letterSpacing: lang === 'bn' ? 0 : C.heroTracking,
            lineHeight: C.heroLineHeight, textTransform: lang === 'bn' ? 'none' : C.heroTransform,
            textShadow: C.heroShadow,
          }}>{name}</h1>
          {nameBn && <div style={{ marginTop: 14, color: C.heroSoft, fontFamily: '"Hind Siliguri", system-ui, sans-serif', fontSize: 19 }}>{nameBn}</div>}
          <div aria-hidden="true" style={{ marginTop: 20, width: 58, height: 1, background: C.accent, opacity: .72 }} />
          <p style={{ margin: '18px 0 0', maxWidth: 290, color: C.heroSoft, fontFamily: langFont(lang, C.body), fontSize: 13, lineHeight: 1.55 }}>
            {info?.tagline || info?.description || C.heroLine}
          </p>
        </div>

        <div style={{ position: 'absolute', left: 18, right: 18, bottom: 'calc(env(safe-area-inset-bottom) + 22px)', zIndex: 4 }}>
          <button type="button" onClick={onSeeMenu} style={{
            width: '100%', height: 58, borderRadius: C.radius, border: 'none', cursor: 'pointer',
            background: C.ctaBg, color: C.ctaText, boxShadow: C.ctaShadow,
            fontFamily: langFont(lang, C.display), fontSize: 16, fontWeight: 800,
            letterSpacing: lang === 'bn' ? 0 : C.ctaTracking, textTransform: lang === 'bn' ? 'none' : 'uppercase',
            display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 10,
          }}>
            <span>{t('seeMenu', lang)}</span><span aria-hidden="true">↓</span>
          </button>
        </div>
      </section>
    )
  }

  function CategoryNav({ categories, categoryBnMap, active, onPick }) {
    const lang = useLang()
    const trackRef = useRef(null)
    const chipRefs = useRef({})

    useEffect(() => {
      const el = chipRefs.current[active]
      const track = trackRef.current
      if (!el || !track) return
      const left = el.offsetLeft
      const right = left + el.offsetWidth
      if (left < track.scrollLeft + 16) track.scrollTo({ left: Math.max(0, left - 16), behavior: 'smooth' })
      else if (right > track.scrollLeft + track.clientWidth - 16) track.scrollTo({ left: right - track.clientWidth + 16, behavior: 'smooth' })
    }, [active])

    return (
      <div role="navigation" aria-label="Menu categories" style={{
        position: 'sticky', top: 0, zIndex: 20, margin: '0 -16px',
        background: C.navBg, borderBlock: `1px solid ${C.line}`, backdropFilter: 'blur(10px)', WebkitBackdropFilter: 'blur(10px)',
      }}>
        <div ref={trackRef} style={{ display: 'flex', gap: 16, padding: '14px 16px 10px', overflowX: 'auto', scrollbarWidth: 'none' }}>
          {categories.map(cat => {
            const isActive = cat === active
            const labelEn = cat === 'All' ? t('all', 'en') : cat
            const labelBn = cat === 'All' ? t('all', 'bn') : (categoryBnMap[cat] || labelEn)
            const label = lang === 'bn' ? labelBn : labelEn
            return (
              <button key={cat} ref={el => { chipRefs.current[cat] = el }} type="button" aria-pressed={isActive} onClick={() => onPick(cat)}
                style={{
                  flex: '0 0 auto', padding: '0 0 6px', border: 'none', borderBottom: `2px solid ${isActive ? C.accent2 : 'transparent'}`,
                  background: 'transparent', color: isActive ? C.navActive : C.muted, cursor: 'pointer',
                  fontFamily: langFont(lang, C.display), fontSize: C.navSize, fontWeight: 800,
                  letterSpacing: lang === 'bn' ? 0 : C.navTracking, textTransform: lang === 'bn' ? 'none' : 'uppercase',
                  whiteSpace: 'nowrap',
                }}>{label}</button>
            )
          })}
        </div>
      </div>
    )
  }

  function FeaturedCard({ item, onOpenDetail, onAdd }) {
    const lang = useLang()
    if (!item) return null
    const name = itemName(item, lang)
    const desc = itemDescription(item, lang) || alternateName(item, lang)
    return (
      <article onClick={() => onOpenDetail(item)} style={{
        position: 'relative', minHeight: 152, borderRadius: C.radius, overflow: 'hidden',
        background: C.card, border: `1px solid ${C.line}`, cursor: 'pointer',
      }}>
        {item.imageUrl ? (
          <img src={item.imageUrl} alt="" loading="lazy" style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover' }} />
        ) : (
          <MenuFallbackIcon item={item} size={64} />
        )}
        <div aria-hidden="true" style={{ position: 'absolute', inset: 0, background: C.featureOverlay }} />
        <div style={{ position: 'relative', zIndex: 2, minHeight: 152, padding: 14, display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}>
          <span style={{
            alignSelf: 'flex-start', padding: '4px 8px', borderRadius: 4, background: C.accent2, color: C.accentInk,
            fontFamily: langFont(lang, C.body), fontSize: 9, fontWeight: 900, letterSpacing: lang === 'bn' ? 0 : '.16em',
            textTransform: lang === 'bn' ? 'none' : 'uppercase',
          }}>{C.featureLabel}</span>
          <div>
            <h2 style={{
              margin: 0, maxWidth: '72%', color: C.photoText, fontFamily: langFont(lang, C.display),
              fontSize: 27, lineHeight: .96, fontWeight: 800, textTransform: lang === 'bn' ? 'none' : 'uppercase',
              letterSpacing: lang === 'bn' ? 0 : C.tightTracking,
            }}>{name}</h2>
            <div style={{ marginTop: 8, display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', gap: 12 }}>
              <p style={{ margin: 0, maxWidth: 210, color: C.photoSoft, fontSize: 11, lineHeight: 1.35, fontFamily: langFont(lang, C.body), display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden' }}>{desc}</p>
              <strong style={{ color: C.featurePrice, fontFamily: langFont(lang, C.display), fontSize: 20, whiteSpace: 'nowrap' }}>{taka(item.price)}</strong>
            </div>
          </div>
        </div>
        <button type="button" onClick={e => { e.stopPropagation(); onAdd(item.id) }} aria-label={`${t('add', lang)} ${name}`} style={{
          position: 'absolute', top: 12, right: 12, zIndex: 3, width: 36, height: 36, borderRadius: 18, border: 'none',
          background: C.accent2, color: C.accentInk, fontSize: 22, fontWeight: 900, display: 'grid', placeItems: 'center', cursor: 'pointer',
        }}>+</button>
      </article>
    )
  }

  function ItemCard({ item, qty, onAdd, onRemove, onOpenDetail }) {
    const lang = useLang()
    const name = itemName(item, lang)
    const sub = alternateName(item, lang)
    const badge = item?.tag || (Array.isArray(item?.tags) ? item.tags[0] : '')

    return (
      <article tabIndex={0} className="fade-up" onClick={onOpenDetail}
        onKeyDown={e => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); onOpenDetail?.() } }}
        style={{
          minWidth: 0, background: C.card, color: C.ink, border: `1px solid ${C.line}`, borderRadius: C.radius,
          overflow: 'hidden', boxShadow: C.cardShadow, cursor: 'pointer', display: 'flex', flexDirection: 'column',
        }}>
        <div style={{ position: 'relative', aspectRatio: '1 / .76', minHeight: 104, background: C.imageBg, overflow: 'hidden' }}>
          {item.imageUrl ? (
            <img src={item.imageUrl} alt="" loading="lazy" style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover' }} />
          ) : (
            <MenuFallbackIcon item={item} size={42} />
          )}
          <div aria-hidden="true" style={{ position: 'absolute', inset: 0, background: C.cardImageOverlay }} />
          {badge && (
            <span style={{
              position: 'absolute', left: 8, top: 8, maxWidth: 'calc(100% - 54px)', padding: '3px 7px',
              borderRadius: 4, background: C.badgeBg, color: C.badgeText, fontFamily: langFont(lang, C.body),
              fontSize: 9, fontWeight: 900, letterSpacing: lang === 'bn' ? 0 : '.12em', textTransform: lang === 'bn' ? 'none' : 'uppercase',
              overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
            }}>{badge}</span>
          )}
          <div onClick={e => e.stopPropagation()}>
            {qty === 0 ? (
              <button type="button" onClick={onAdd} aria-label={`${t('add', lang)} ${name}`} style={{
                position: 'absolute', top: 8, right: 8, width: 32, height: 32, borderRadius: 16, border: 'none',
                background: C.accent2, color: C.accentInk, fontSize: 20, fontWeight: 900, display: 'grid', placeItems: 'center', cursor: 'pointer',
              }}>+</button>
            ) : (
              <div style={{
                position: 'absolute', top: 8, right: 8, display: 'inline-flex', alignItems: 'center', height: 32,
                borderRadius: 16, background: C.qtyBg, color: C.ink, border: `1px solid ${C.line}`, overflow: 'hidden',
              }}>
                <button type="button" onClick={onRemove} aria-label={t('remove', lang)} style={{ width: 28, height: 32, border: 'none', background: 'transparent', color: C.muted, fontSize: 17 }}>-</button>
                <span style={{ minWidth: 20, textAlign: 'center', fontWeight: 900, fontSize: 13 }}>{qty}</span>
                <button type="button" onClick={onAdd} aria-label={t('add', lang)} style={{ width: 28, height: 32, border: 'none', background: 'transparent', color: C.accent, fontSize: 17 }}>+</button>
              </div>
            )}
          </div>
        </div>
        <div style={{ padding: '10px 10px 12px', display: 'flex', flexDirection: 'column', flex: 1, minHeight: 112 }}>
          <h3 style={{
            margin: 0, color: C.itemTitle, fontFamily: langFont(lang, C.display), fontSize: C.cardTitleSize,
            fontWeight: 800, lineHeight: 1.05, letterSpacing: lang === 'bn' ? 0 : C.tightTracking,
            textTransform: lang === 'bn' ? 'none' : 'uppercase', display: '-webkit-box', WebkitLineClamp: 2,
            WebkitBoxOrient: 'vertical', overflow: 'hidden',
          }}>{name}</h3>
          {sub && sub !== name && <div style={{ marginTop: 4, color: C.muted, fontFamily: '"Hind Siliguri", system-ui, sans-serif', fontSize: 11, lineHeight: 1.25, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{sub}</div>}
          <div style={{ flex: 1 }} />
          <div style={{ marginTop: 9, color: C.price, fontFamily: langFont(lang, C.display), fontSize: C.cardPriceSize, fontWeight: 900 }}>{taka(item.price)}</div>
        </div>
      </article>
    )
  }

  const Menu = forwardRef(function Menu({ items, byCat, categoryOrder, categoryBnMap, active, onPickCategory, cart, onAdd, onRemove, onOpenDetail, hasFloatingCart }, ref) {
    const lang = useLang()
    const categories = ['All', ...categoryOrder]
    const visibleItems = active === 'All' ? items : (byCat[active] || [])
    const featured = findFeatured(items)
    const activeBn = active === 'All' ? t('all', 'bn') : categoryBnMap[active]
    return (
      <section id="menu" ref={ref} style={{
        background: C.bg, minHeight: '60vh', padding: '16px 16px 0',
        paddingBottom: hasFloatingCart ? 'calc(env(safe-area-inset-bottom) + 104px)' : 'calc(env(safe-area-inset-bottom) + 36px)',
        scrollMarginTop: NAV_HEIGHT,
      }}>
        <FeaturedCard item={featured} onOpenDetail={onOpenDetail} onAdd={onAdd} />
        <CategoryNav categories={categories} categoryBnMap={categoryBnMap} active={active} onPick={onPickCategory} />
        <header style={{ padding: '22px 0 12px', display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', gap: 12 }}>
          <div style={{ minWidth: 0 }}>
            <h2 style={{
              margin: 0, color: C.ink, fontFamily: langFont(lang, C.display), fontSize: 26, lineHeight: 1,
              fontWeight: 800, letterSpacing: lang === 'bn' ? 0 : C.tightTracking, textTransform: lang === 'bn' ? 'none' : 'uppercase',
              overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
            }}>{active === 'All' ? t('all', lang) : (lang === 'bn' ? (activeBn || active) : active)}</h2>
            {lang !== 'bn' && activeBn && <div style={{ marginTop: 4, color: C.muted, fontFamily: '"Hind Siliguri", system-ui, sans-serif', fontSize: 13 }}>{activeBn}</div>}
          </div>
          <span style={{ color: C.muted, fontFamily: langFont(lang, C.body), fontSize: 12, fontWeight: 800, whiteSpace: 'nowrap' }}>{visibleItems.length}</span>
        </header>
        {visibleItems.length === 0 ? (
          <div style={{ padding: '72px 20px', textAlign: 'center', color: C.muted, fontFamily: langFont(lang, C.body) }}>{t('noItems', lang)}</div>
        ) : (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, minmax(0, 1fr))', gap: 12 }}>
            {visibleItems.map(item => (
              <ItemCard key={item.id} item={item} qty={cart[item.id] || 0} onAdd={() => onAdd(item.id)} onRemove={() => onRemove(item.id)} onOpenDetail={() => onOpenDetail(item)} />
            ))}
          </div>
        )}
      </section>
    )
  })

  function FloatingCart({ count, total, onTap }) {
    const lang = useLang()
    if (count <= 0) return null
    return (
      <button type="button" onClick={onTap} aria-label={`${t('yourOrder', lang)} · ${count} · ${taka(total)}`} className="template-cart-pop" style={{
        position: 'fixed', left: 16, right: 16, bottom: 'calc(env(safe-area-inset-bottom) + 16px)', zIndex: 40,
        height: 58, borderRadius: C.radius, border: 'none', background: C.ctaBg, color: C.ctaText,
        display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12, padding: '0 16px',
        fontFamily: langFont(lang, C.display), fontWeight: 900, fontSize: 16, textTransform: lang === 'bn' ? 'none' : 'uppercase',
        letterSpacing: lang === 'bn' ? 0 : C.ctaTracking, boxShadow: C.floatShadow, cursor: 'pointer',
      }}>
        <span style={{ display: 'inline-flex', alignItems: 'center', gap: 10, minWidth: 0 }}>
          <span style={{ width: 28, height: 28, borderRadius: 14, background: C.countBg, color: C.countText, display: 'grid', placeItems: 'center', fontFamily: '"Hind Siliguri", system-ui, sans-serif', fontSize: 13 }}>{count}</span>
          <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{t('yourOrder', lang)}</span>
        </span>
        <span style={{ whiteSpace: 'nowrap' }}>{taka(total)} →</span>
      </button>
    )
  }

  function Storefront({ info, items, cart, onAdd, onRemove, onOpenCart, onOpenDetail, initialView = 'hero' }) {
    const menuRef = useRef(null)
    const { order, byCat, bnMap } = useMemo(() => groupItems(items || []), [items])
    const [active, setActive] = useState('All')
    const count = cartCount(cart)
    const total = cartTotal(cart, items || [])

    useEffect(() => {
      if (initialView === 'menu' && menuRef.current) {
        window.scrollTo({ top: menuRef.current.offsetTop - NAV_HEIGHT, behavior: 'auto' })
      }
    }, [initialView])

    return (
      <div style={{ background: C.bg, color: C.ink, minHeight: '100svh', fontFamily: C.body }}>
        <Hero info={info} onSeeMenu={() => smoothScrollTo(menuRef.current, NAV_HEIGHT - 4)} />
        <Menu
          ref={menuRef}
          items={items || []}
          byCat={byCat}
          categoryOrder={order}
          categoryBnMap={bnMap}
          active={active}
          onPickCategory={setActive}
          cart={cart}
          onAdd={onAdd}
          onRemove={onRemove}
          onOpenDetail={onOpenDetail}
          hasFloatingCart={count > 0}
        />
        <FloatingCart count={count} total={total} onTap={onOpenCart} />
      </div>
    )
  }

  function Field({ label, value, onChange, type = 'text', autoComplete, multiline }) {
    const lang = useLang()
    const common = {
      width: '100%', background: C.inputBg, color: C.ink, border: `1px solid ${C.line}`, borderRadius: C.radius,
      fontFamily: langFont(lang, C.body), fontSize: 15, outline: 'none',
    }
    return (
      <label style={{ display: 'block' }}>
        <div style={{ marginBottom: 6, color: C.accent, fontFamily: langFont(lang, C.body), fontSize: 11, fontWeight: 900, letterSpacing: lang === 'bn' ? 0 : '.12em', textTransform: lang === 'bn' ? 'none' : 'uppercase' }}>{label}</div>
        {multiline ? (
          <textarea rows={3} value={value} onChange={e => onChange(e.target.value)} style={{ ...common, padding: '12px 14px', resize: 'vertical' }} />
        ) : (
          <input type={type} autoComplete={autoComplete} value={value} onChange={e => onChange(e.target.value)} style={{ ...common, height: 48, padding: '0 14px' }} />
        )}
      </label>
    )
  }

  function Cart({ cart, items, note, onNote, delivery, onDelivery, onAdd, onRemove, onBack, onPlace, submitting, info, outletId, isTableOrder, tableNo }) {
    const lang = useLang()
    const [geo, setGeo] = useState({ status: 'idle', address: '', error: '' })
    const mountedRef = useRef(true)
    const addressRef = useRef(delivery.address)
    useEffect(() => { addressRef.current = delivery.address }, [delivery.address])
    useEffect(() => {
      if (isTableOrder) return undefined
      mountedRef.current = true
      async function detectAddress() {
        if (!outletId || outletId === '__demo__') return setGeo({ status: 'error', address: '', error: 'unavailable' })
        setGeo(g => ({ ...g, status: 'locating', error: '' }))
        try {
          const position = await getBrowserPosition()
          if (!mountedRef.current) return
          setGeo({ status: 'geocoding', address: '', error: '' })
          const address = await reverseGeocodePosition(position, outletId)
          if (!mountedRef.current) return
          setGeo({ status: 'ready', address, error: '' })
          if (!addressRef.current.trim()) onDelivery(d => ({ ...d, address }))
        } catch (e) {
          if (mountedRef.current) setGeo({ status: 'error', address: '', error: e.message || 'failed' })
        }
      }
      detectAddress()
      return () => { mountedRef.current = false }
    }, [isTableOrder, outletId, onDelivery])

    const cartItems = Object.entries(cart).map(([id, qty]) => {
      const item = items.find(i => i.id === id)
      return item ? { ...item, qty } : null
    }).filter(Boolean)
    const total = cartTotal(cart, items)
    const deliveryReady = isTableOrder || (delivery.name.trim() && delivery.address.trim() && delivery.mobile.trim().length >= 7)

    return (
      <div style={{ minHeight: '100svh', background: C.bg, color: C.ink, fontFamily: C.body }}>
        <header style={{ position: 'sticky', top: 0, zIndex: 10, padding: 'calc(env(safe-area-inset-top) + 14px) 16px 14px', display: 'flex', gap: 12, alignItems: 'center', background: C.bg, borderBottom: `1px solid ${C.line}` }}>
          <button type="button" onClick={onBack} aria-label={t('back', lang)} style={{ width: 42, height: 42, borderRadius: 21, background: C.card, border: `1px solid ${C.line}`, color: C.ink, fontSize: 20 }}>←</button>
          <div style={{ minWidth: 0 }}>
            <h1 style={{ margin: 0, fontFamily: langFont(lang, C.display), fontSize: 26, color: C.ink, lineHeight: 1, letterSpacing: lang === 'bn' ? 0 : C.tightTracking, textTransform: lang === 'bn' ? 'none' : 'uppercase' }}>{t('yourOrder', lang)}</h1>
            <div style={{ marginTop: 4, color: C.muted, fontSize: 12, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
              {isTableOrder && tableNo ? `Table ${tableNo}` : (info?.restaurantName || '')}
            </div>
          </div>
        </header>

        <main style={{ padding: '10px 18px calc(env(safe-area-inset-bottom) + 178px)' }}>
          {cartItems.length === 0 ? (
            <div style={{ padding: '60px 20px', textAlign: 'center', color: C.muted }}>{t('noItems', lang)}</div>
          ) : (
            <ul style={{ listStyle: 'none', margin: 0, padding: 0 }}>
              {cartItems.map(item => (
                <li key={item.id} style={{ display: 'grid', gridTemplateColumns: '58px 1fr auto', gap: 12, alignItems: 'center', padding: '14px 0', borderBottom: `1px solid ${C.line}` }}>
                  <div style={{ position: 'relative', width: 58, height: 58, borderRadius: C.radius, overflow: 'hidden', background: C.imageBg }}>
                    {item.imageUrl ? <img src={item.imageUrl} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} /> : <MenuFallbackIcon item={item} size={28} />}
                  </div>
                  <div style={{ minWidth: 0 }}>
                    <div style={{ fontFamily: langFont(lang, C.display), color: C.itemTitle, fontWeight: 800, lineHeight: 1.08, textTransform: lang === 'bn' ? 'none' : 'uppercase', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{itemName(item, lang)}</div>
                    <div style={{ marginTop: 8, display: 'inline-flex', alignItems: 'center', height: 30, borderRadius: 15, border: `1px solid ${C.line}`, background: C.qtyBg }}>
                      <button type="button" onClick={() => onRemove(item.id)} style={{ width: 32, height: 30, background: 'transparent', border: 'none', color: C.muted }}>-</button>
                      <span style={{ minWidth: 20, textAlign: 'center', fontWeight: 900 }}>{item.qty}</span>
                      <button type="button" onClick={() => onAdd(item.id)} style={{ width: 32, height: 30, background: 'transparent', border: 'none', color: C.accent }}>+</button>
                    </div>
                  </div>
                  <div style={{ fontFamily: langFont(lang, C.display), color: C.price, fontWeight: 900, whiteSpace: 'nowrap' }}>{taka(item.price * item.qty)}</div>
                </li>
              ))}
            </ul>
          )}

          <section style={{ marginTop: 18, padding: 14, borderRadius: C.radius, border: `1px dashed ${C.line}`, background: C.card }}>
            <Field label={t('note', lang)} value={note} onChange={onNote} multiline />
          </section>

          {!isTableOrder && (
            <section style={{ marginTop: 22 }}>
              <h2 style={{ margin: '0 0 14px', fontFamily: langFont(lang, C.display), fontSize: 24, color: C.ink, textTransform: lang === 'bn' ? 'none' : 'uppercase' }}>{t('yourDetails', lang)}</h2>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
                <Field label={t('name', lang)} value={delivery.name} onChange={v => onDelivery(d => ({ ...d, name: v }))} autoComplete="name" />
                <Field label={t('mobile', lang)} value={delivery.mobile} onChange={v => onDelivery(d => ({ ...d, mobile: v }))} type="tel" autoComplete="tel" />
                <Field label={t('address', lang)} value={delivery.address} onChange={v => onDelivery(d => ({ ...d, address: v }))} autoComplete="street-address" multiline />
                {geo.status === 'locating' || geo.status === 'geocoding' ? <div style={{ fontSize: 12, color: C.muted }}>{t('detectingAddress', lang)}</div> : null}
                {geo.status === 'ready' && geo.address && geo.address !== delivery.address ? (
                  <button type="button" onClick={() => onDelivery(d => ({ ...d, address: geo.address }))} style={{ alignSelf: 'flex-start', padding: '8px 12px', borderRadius: C.radius, border: `1px solid ${C.accent}`, background: 'transparent', color: C.accent, fontFamily: C.body }}>{t('useDetected', lang)}</button>
                ) : null}
              </div>
            </section>
          )}
        </main>

        <footer style={{ position: 'fixed', left: 0, right: 0, bottom: 0, zIndex: 20, background: C.footerBg, borderTop: `1px solid ${C.line}`, padding: '12px 16px calc(env(safe-area-inset-bottom) + 12px)', boxShadow: C.footerShadow }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10, color: C.muted, fontWeight: 900, textTransform: lang === 'bn' ? 'none' : 'uppercase', letterSpacing: lang === 'bn' ? 0 : '.12em', fontSize: 12 }}>
            <span>{t('total', lang)}</span><span style={{ color: C.price, fontFamily: langFont(lang, C.display), fontSize: 22 }}>{taka(total)}</span>
          </div>
          <button type="button" onClick={onPlace} disabled={!deliveryReady || submitting || cartItems.length === 0} style={{
            width: '100%', height: 56, borderRadius: C.radius, border: 'none',
            background: (!deliveryReady || cartItems.length === 0) ? C.disabledBg : C.ctaBg, color: C.ctaText,
            fontFamily: langFont(lang, C.display), fontWeight: 900, letterSpacing: lang === 'bn' ? 0 : C.ctaTracking,
            textTransform: lang === 'bn' ? 'none' : 'uppercase', opacity: submitting ? .7 : 1,
          }}>{submitting ? t('placingOrder', lang) : t('placeOrder', lang)}</button>
        </footer>
      </div>
    )
  }

  function ItemSheet({ item, qty, onAdd, onRemove, onClose }) {
    const lang = useLang()
    const media = buildMedia(item)
    const current = media[0]
    const videoRef = useRef(null)
    useEffect(() => {
      function onKey(e) { if (e.key === 'Escape') onClose() }
      window.addEventListener('keydown', onKey)
      return () => window.removeEventListener('keydown', onKey)
    }, [onClose])
    useEffect(() => { if (videoRef.current) videoRef.current.play().catch(() => {}) }, [item?.id])
    if (!item) return null
    const name = itemName(item, lang)
    const sub = alternateName(item, lang)
    const desc = itemDescription(item, lang)
    return (
      <div className="fade-in" role="dialog" aria-modal="true" onClick={e => { if (e.target === e.currentTarget) onClose() }} style={{ position: 'fixed', inset: 0, zIndex: 50, background: 'rgba(0,0,0,.62)', display: 'flex', alignItems: 'flex-end', backdropFilter: 'blur(4px)' }}>
        <div className="slide-up" style={{ width: '100%', maxHeight: '92svh', overflow: 'hidden', display: 'flex', flexDirection: 'column', background: C.bg, color: C.ink, borderTopLeftRadius: 18, borderTopRightRadius: 18, border: `1px solid ${C.line}`, borderBottom: 'none' }}>
          <div style={{ position: 'relative', height: 238, background: C.imageBg, flexShrink: 0, ...(current?.type === 'image' ? { backgroundImage: `url(${current.url})`, backgroundSize: 'cover', backgroundPosition: 'center' } : {}) }}>
            {current?.type === 'video' && <video ref={videoRef} src={current.url} autoPlay muted loop playsInline style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover' }} />}
            {!current && <MenuFallbackIcon item={item} size={62} />}
            <div aria-hidden="true" style={{ position: 'absolute', inset: 0, background: C.sheetOverlay }} />
            <button type="button" onClick={onClose} aria-label={t('back', lang)} style={{ position: 'absolute', top: 12, right: 12, width: 40, height: 40, borderRadius: 20, border: `1px solid ${C.line}`, background: C.glass, color: C.ink, fontSize: 18 }}>×</button>
          </div>
          <div style={{ padding: '20px 22px 24px', overflowY: 'auto', flex: 1 }}>
            <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', gap: 12 }}>
              <h2 style={{ margin: 0, fontFamily: langFont(lang, C.display), fontSize: 30, fontWeight: 900, color: C.ink, lineHeight: 1, textTransform: lang === 'bn' ? 'none' : 'uppercase' }}>{name}</h2>
              <div style={{ fontFamily: langFont(lang, C.display), color: C.price, fontWeight: 900, fontSize: 22, whiteSpace: 'nowrap' }}>{taka(item.price)}</div>
            </div>
            {sub && sub !== name && <div style={{ marginTop: 6, color: C.muted, fontFamily: '"Hind Siliguri", system-ui, sans-serif', fontSize: 15 }}>{sub}</div>}
            {desc && <p style={{ margin: '18px 0 0', color: C.muted, fontFamily: langFont(lang, C.body), fontSize: 15, lineHeight: 1.55 }}>{desc}</p>}
          </div>
          <footer style={{ display: 'flex', gap: 12, padding: '12px 16px calc(env(safe-area-inset-bottom) + 16px)', borderTop: `1px solid ${C.line}`, background: C.footerBg }}>
            {qty > 0 && <div style={{ display: 'inline-flex', alignItems: 'center', height: 56, borderRadius: C.radius, border: `1px solid ${C.line}`, background: C.card }}>
              <button type="button" onClick={onRemove} style={{ width: 48, height: 54, border: 'none', background: 'transparent', color: C.muted, fontSize: 22 }}>-</button>
              <span style={{ minWidth: 30, textAlign: 'center', fontWeight: 900 }}>{qty}</span>
              <button type="button" onClick={onAdd} style={{ width: 48, height: 54, border: 'none', background: 'transparent', color: C.accent, fontSize: 22 }}>+</button>
            </div>}
            <button type="button" onClick={onAdd} style={{ flex: 1, height: 56, borderRadius: C.radius, border: 'none', background: C.ctaBg, color: C.ctaText, fontFamily: langFont(lang, C.display), fontWeight: 900, letterSpacing: lang === 'bn' ? 0 : C.ctaTracking, textTransform: lang === 'bn' ? 'none' : 'uppercase' }}>{t('add', lang)} · {taka(item.price)}</button>
          </footer>
        </div>
      </div>
    )
  }

  function Success({ order, info, cartItems, onBack }) {
    const lang = useLang()
    const totalItems = (cartItems || []).reduce((sum, item) => sum + (item.qty || 0), 0)
    return (
      <div style={{ minHeight: '100svh', display: 'flex', flexDirection: 'column', background: C.bg, color: C.ink, fontFamily: C.body }}>
        <main style={{ flex: 1, padding: 'calc(env(safe-area-inset-top) + 58px) 20px 24px', overflowY: 'auto', textAlign: 'center' }}>
          <div style={{ width: 82, height: 82, borderRadius: 41, margin: '0 auto', background: C.ctaBg, color: C.ctaText, display: 'grid', placeItems: 'center', fontSize: 42, boxShadow: C.floatShadow }}>✓</div>
          <h1 style={{ margin: '18px 0 0', fontFamily: langFont(lang, C.display), fontSize: 38, lineHeight: .95, color: C.ink, letterSpacing: lang === 'bn' ? 0 : C.tightTracking, textTransform: lang === 'bn' ? 'none' : 'uppercase' }}>{t('orderConfirmed', lang)}</h1>
          <section style={{ marginTop: 24, padding: '22px 18px 24px', background: C.card, border: `1px solid ${C.line}`, borderRadius: C.radius }}>
            <div style={{ color: C.muted, fontSize: 10, fontWeight: 900, letterSpacing: '.22em', textTransform: 'uppercase' }}>{t('orderNumber', lang)}</div>
            {order?.serialNumber != null && <div style={{ marginTop: 8, fontFamily: langFont(lang, C.display), color: C.price, fontSize: 56, fontWeight: 900, lineHeight: 1 }}>#{order.serialNumber}</div>}
            <div style={{ marginTop: 16, paddingTop: 16, borderTop: `1px dashed ${C.line}`, display: 'flex', justifyContent: 'center', gap: 28 }}>
              <div><div style={{ color: C.muted, fontSize: 11 }}>{lang === 'bn' ? 'আইটেম' : 'Items'}</div><strong>{totalItems}</strong></div>
              <div><div style={{ color: C.muted, fontSize: 11 }}>{t('total', lang)}</div><strong style={{ color: C.price }}>{taka(order?.total || 0)}</strong></div>
            </div>
          </section>
          {order && <button type="button" onClick={() => generateReceipt(order, info, cartItems)} style={{ marginTop: 18, width: '100%', height: 52, borderRadius: C.radius, border: `1px solid ${C.line}`, background: C.card, color: C.ink, fontFamily: langFont(lang, C.display), fontWeight: 900, textTransform: lang === 'bn' ? 'none' : 'uppercase', letterSpacing: lang === 'bn' ? 0 : C.ctaTracking }}>{lang === 'bn' ? 'রিসিট ডাউনলোড' : 'Download Receipt'}</button>}
        </main>
        <footer style={{ padding: '12px 18px calc(env(safe-area-inset-bottom) + 16px)', borderTop: `1px solid ${C.line}`, background: C.footerBg }}>
          <button type="button" onClick={onBack} style={{ width: '100%', height: 56, borderRadius: C.radius, border: 'none', background: C.ctaBg, color: C.ctaText, fontFamily: langFont(lang, C.display), fontWeight: 900, letterSpacing: lang === 'bn' ? 0 : C.ctaTracking, textTransform: lang === 'bn' ? 'none' : 'uppercase' }}>{t('backToMenu', lang)} →</button>
        </footer>
      </div>
    )
  }

  return { Storefront, ItemSheet, Cart, Success, Loading, Error }
}

export const sultansHearthOverrides = makeOverrides({
  slug: 'sultans_hearth',
  bg: '#1C1410', card: '#2B1F18', inputBg: '#241914', imageBg: '#201610',
  ink: '#FFF3E0', muted: 'rgba(255,243,224,.64)', line: 'rgba(255,243,224,.12)',
  accent: '#FFB547', accent2: '#FF6A3D', accentInk: '#1A0C08', price: '#FFB547',
  display: '"Anton", "Bebas Neue", "Inter Tight", system-ui, sans-serif', body: '"Hind Siliguri", system-ui, sans-serif',
  heroText: '#FFF3E0', heroTitle: '#FFFFFF', heroSoft: 'rgba(255,243,224,.82)',
  heroFallback: 'radial-gradient(80% 50% at 50% 32%, rgba(255,106,61,.22), transparent 62%), linear-gradient(180deg, #100906 0%, #1C1410 100%)',
  heroPattern: 'repeating-linear-gradient(135deg, rgba(255,243,224,.08) 0 1px, transparent 1px 24px)', heroPatternOpacity: .24,
  heroOverlay: 'linear-gradient(180deg, rgba(12,8,5,.58) 0%, rgba(12,8,5,.18) 36%, rgba(12,8,5,.95) 100%)',
  heroKicker: 'Est. 2019 · Dhaka', heroLine: 'Slow-cooked basmati. Wood-fire ovens. Charcoal grills.',
  heroTitleSize: 'clamp(68px, 20vw, 112px)', heroWeight: 900, heroTracking: '-.025em', heroLineHeight: .82, heroTransform: 'uppercase', heroShadow: '0 6px 30px rgba(0,0,0,.48)',
  ctaBg: '#FF6A3D', ctaText: '#1A0C08', ctaShadow: '0 14px 34px rgba(255,106,61,.36)', ctaTracking: '.04em',
  radius: 8, glass: 'rgba(28,20,16,.62)', navBg: 'rgba(28,20,16,.94)', navActive: '#FFB547', navSize: 22, navTracking: '.01em',
  featureOverlay: 'linear-gradient(90deg, rgba(28,20,16,.94) 0%, rgba(28,20,16,.62) 58%, rgba(28,20,16,.18) 100%)',
  featureLabel: "Tonight's hero", featurePrice: '#FFB547', photoText: '#FFFFFF', photoSoft: 'rgba(255,243,224,.72)',
  cardShadow: 'none', cardImageOverlay: 'linear-gradient(180deg, transparent 46%, rgba(0,0,0,.44) 100%)', badgeBg: 'rgba(26,12,8,.76)', badgeText: '#FFB547',
  itemTitle: '#FFFFFF', cardTitleSize: 16, cardPriceSize: 18, tightTracking: '-.01em',
  qtyBg: '#1A0C08', countBg: '#1A0C08', countText: '#FFB547', floatShadow: '0 14px 30px rgba(255,106,61,.34)',
  footerBg: '#1C1410', footerShadow: '0 -10px 28px rgba(0,0,0,.32)', disabledBg: '#44372F', sheetOverlay: 'linear-gradient(180deg, transparent 34%, rgba(28,20,16,.9) 100%)',
})

export const brickOverrides = makeOverrides({
  slug: 'brick',
  bg: '#F7F2E8', card: '#FFFFFF', inputBg: '#FFFFFF', imageBg: '#EFE4D2',
  ink: '#241B16', muted: '#756656', line: '#D9CBB8',
  accent: '#B9462D', accent2: '#E89A4A', accentInk: '#241B16', price: '#B9462D',
  display: '"Bebas Neue", "Anton", sans-serif', body: INTER,
  heroText: '#FFF7EC', heroTitle: '#FFFFFF', heroSoft: 'rgba(255,247,236,.84)',
  heroFallback: 'radial-gradient(80% 48% at 50% 28%, rgba(232,154,74,.36), transparent 60%), linear-gradient(140deg, #7E2C22 0%, #D78543 58%, #241B16 100%)',
  heroPattern: 'repeating-linear-gradient(90deg, rgba(255,247,236,.08) 0 8px, transparent 8px 16px)', heroPatternOpacity: .34,
  heroOverlay: 'linear-gradient(180deg, rgba(36,27,22,.48) 0%, rgba(36,27,22,.12) 38%, rgba(36,27,22,.9) 100%)',
  heroKicker: 'Hot counter · all day', heroLine: 'Bright plates, grilled edges, and comfort food with a little heat.',
  heroTitleSize: 'clamp(70px, 21vw, 112px)', heroWeight: 400, heroTracking: '-.01em', heroLineHeight: .86, heroTransform: 'uppercase', heroShadow: '0 5px 24px rgba(36,27,22,.42)',
  ctaBg: '#E89A4A', ctaText: '#241B16', ctaShadow: '0 14px 32px rgba(185,70,45,.22)', ctaTracking: '.04em',
  radius: 8, glass: 'rgba(255,247,236,.72)', navBg: 'rgba(247,242,232,.94)', navActive: '#241B16', navSize: 21, navTracking: '.02em',
  featureOverlay: 'linear-gradient(90deg, rgba(36,27,22,.92) 0%, rgba(36,27,22,.5) 58%, rgba(36,27,22,.08) 100%)',
  featureLabel: 'House favorite', featurePrice: '#FFD28C', photoText: '#FFFFFF', photoSoft: 'rgba(255,247,236,.78)',
  cardShadow: '0 1px 0 rgba(36,27,22,.04)', cardImageOverlay: 'linear-gradient(180deg, transparent 48%, rgba(36,27,22,.22) 100%)', badgeBg: '#241B16', badgeText: '#FFD28C',
  itemTitle: '#241B16', cardTitleSize: 19, cardPriceSize: 19, tightTracking: '.01em',
  qtyBg: '#F7F2E8', countBg: '#241B16', countText: '#E89A4A', floatShadow: '0 14px 30px rgba(36,27,22,.24)',
  footerBg: '#FFFFFF', footerShadow: '0 -10px 24px rgba(36,27,22,.1)', disabledBg: '#D9CBB8', sheetOverlay: 'linear-gradient(180deg, transparent 35%, rgba(36,27,22,.66) 100%)',
})

export const lanternOverrides = makeOverrides({
  slug: 'lantern',
  bg: '#111719', card: '#1D2528', inputBg: '#1D2528', imageBg: '#172023',
  ink: '#F0EADF', muted: '#90979A', line: '#2D373A',
  accent: '#62C2C8', accent2: '#E8744A', accentInk: '#111719', price: '#62C2C8',
  display: '"Bodoni Moda", Georgia, serif', body: INTER,
  heroText: '#F0EADF', heroTitle: '#F8F0E5', heroSoft: 'rgba(240,234,223,.74)',
  heroFallback: 'radial-gradient(70% 46% at 68% 30%, rgba(98,194,200,.25), transparent 62%), radial-gradient(68% 52% at 30% 72%, rgba(232,116,74,.23), transparent 68%), #111719',
  heroPattern: 'linear-gradient(90deg, rgba(98,194,200,.18) 1px, transparent 1px), linear-gradient(0deg, rgba(232,116,74,.12) 1px, transparent 1px)', heroPatternOpacity: .18,
  heroOverlay: 'linear-gradient(180deg, rgba(17,23,25,.52) 0%, rgba(17,23,25,.16) 38%, rgba(17,23,25,.96) 100%)',
  heroKicker: 'After dark · kitchen', heroLine: 'Noir dining, brass heat, and plates built for the slow hour.',
  heroTitleSize: 'clamp(58px, 16vw, 92px)', heroWeight: 650, heroTracking: '-.02em', heroLineHeight: .9, heroTransform: 'none', heroShadow: '0 5px 24px rgba(0,0,0,.5)',
  ctaBg: '#E8744A', ctaText: '#111719', ctaShadow: '0 14px 32px rgba(232,116,74,.22)', ctaTracking: '.08em',
  radius: 8, glass: 'rgba(29,37,40,.74)', navBg: 'rgba(17,23,25,.94)', navActive: '#F0EADF', navSize: 20, navTracking: '0',
  featureOverlay: 'linear-gradient(90deg, rgba(17,23,25,.94) 0%, rgba(17,23,25,.58) 58%, rgba(17,23,25,.18) 100%)',
  featureLabel: "Editor's pick", featurePrice: '#62C2C8', photoText: '#FFFFFF', photoSoft: 'rgba(240,234,223,.72)',
  cardShadow: 'none', cardImageOverlay: 'linear-gradient(180deg, transparent 46%, rgba(17,23,25,.42) 100%)', badgeBg: '#62C2C8', badgeText: '#111719',
  itemTitle: '#F0EADF', cardTitleSize: 17, cardPriceSize: 17, tightTracking: '0',
  qtyBg: '#111719', countBg: '#111719', countText: '#E8744A', floatShadow: '0 14px 32px rgba(232,116,74,.22)',
  footerBg: '#1D2528', footerShadow: '0 -10px 28px rgba(0,0,0,.3)', disabledBg: '#2D373A', sheetOverlay: 'linear-gradient(180deg, transparent 35%, rgba(17,23,25,.82) 100%)',
})

export const marbleOverrides = makeOverrides({
  slug: 'marble',
  bg: '#FBF8F2', card: '#FFFFFF', inputBg: '#FFFFFF', imageBg: '#F2EDE3',
  ink: '#382A22', muted: '#706155', line: '#E6DCCB',
  accent: '#B89556', accent2: '#382A22', accentInk: '#FBF8F2', price: '#382A22',
  display: '"Fraunces", Georgia, serif', body: INTER,
  heroText: '#382A22', heroTitle: '#382A22', heroSoft: 'rgba(56,42,34,.72)',
  heroFallback: 'radial-gradient(70% 48% at 50% 32%, rgba(184,149,86,.2), transparent 62%), linear-gradient(145deg, #FFFFFF 0%, #FBF8F2 48%, #E9D6C8 100%)',
  heroPattern: 'radial-gradient(rgba(56,42,34,.14) 1px, transparent 1px)', heroPatternOpacity: .28,
  heroOverlay: 'linear-gradient(180deg, rgba(251,248,242,.14) 0%, rgba(251,248,242,.08) 40%, rgba(251,248,242,.92) 100%)',
  heroKicker: 'Slow kitchen · fresh bake', heroLine: 'Soft light, brass details, seasonal plates, and fresh sweets.',
  heroTitleSize: 'clamp(56px, 15vw, 90px)', heroWeight: 760, heroTracking: '-.025em', heroLineHeight: .92, heroTransform: 'none', heroShadow: 'none',
  ctaBg: '#382A22', ctaText: '#FBF8F2', ctaShadow: '0 14px 30px rgba(56,42,34,.16)', ctaTracking: '0',
  radius: 8, glass: 'rgba(255,255,255,.72)', navBg: 'rgba(251,248,242,.94)', navActive: '#382A22', navSize: 18, navTracking: '0',
  featureOverlay: 'linear-gradient(90deg, rgba(56,42,34,.9) 0%, rgba(56,42,34,.5) 58%, rgba(56,42,34,.1) 100%)',
  featureLabel: 'Seasonal plate', featurePrice: '#E9D6A8', photoText: '#FFFFFF', photoSoft: 'rgba(251,248,242,.78)',
  cardShadow: '0 1px 0 rgba(56,42,34,.04)', cardImageOverlay: 'linear-gradient(180deg, transparent 48%, rgba(56,42,34,.18) 100%)', badgeBg: '#E9D6C8', badgeText: '#382A22',
  itemTitle: '#382A22', cardTitleSize: 16, cardPriceSize: 16, tightTracking: '-.01em',
  qtyBg: '#FBF8F2', countBg: '#FBF8F2', countText: '#382A22', floatShadow: '0 14px 30px rgba(56,42,34,.18)',
  footerBg: '#FFFFFF', footerShadow: '0 -10px 24px rgba(56,42,34,.08)', disabledBg: '#E6DCCB', sheetOverlay: 'linear-gradient(180deg, transparent 35%, rgba(251,248,242,.7) 100%)',
})
