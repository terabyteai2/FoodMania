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

function categorySlug(name) {
  return 'cat-' + String(name || '').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '')
}

function groupItems(items) {
  const order = []
  const byCat = {}
  const bnMap = {}
  for (const it of items || []) {
    const cat = it.categoryEn || it.category || 'General'
    if (!byCat[cat]) { byCat[cat] = []; order.push(cat) }
    byCat[cat].push(it)
    if (!bnMap[cat] && it.categoryBn) bnMap[cat] = it.categoryBn
  }
  return { order, byCat, bnMap }
}

function langFont(lang, fallback) {
  return lang === 'bn' ? '"Hind Siliguri", system-ui, sans-serif' : fallback
}

function spiceLevelFor(item) {
  if (typeof item?.spiceLevel === 'number') return Math.max(0, Math.min(3, item.spiceLevel))
  const tags = []
  if (Array.isArray(item?.tags)) tags.push(...item.tags)
  if (typeof item?.tag === 'string') tags.push(item.tag)
  for (const raw of tags) {
    const s = String(raw).toLowerCase().trim()
    const m = s.match(/^spice[:=](\d)/)
    if (m) return Math.max(0, Math.min(3, parseInt(m[1], 10)))
    if (s === 'mild') return 1
    if (s === 'spicy' || s === 'hot') return 2
    if (s === 'extra hot' || s === 'extra-hot' || s === 'fiery') return 3
  }
  return 0
}

function tagFor(item, words) {
  const tags = []
  if (Array.isArray(item?.tags)) tags.push(...item.tags)
  if (typeof item?.tag === 'string') tags.push(item.tag)
  const allowed = new Set(words.map(w => w.toLowerCase()))
  return tags.map(String).find(tag => allowed.has(tag.toLowerCase().trim()))
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
          <div style={{ fontSize: 12, fontWeight: 700, letterSpacing: '.14em', textTransform: 'uppercase' }}>{t('loading', 'en')}</div>
        </div>
      </div>
    )
  }

  function Error({ message }) {
    return (
      <div style={{ minHeight: '100svh', display: 'grid', placeItems: 'center', padding: 24, background: C.bg, color: C.ink, fontFamily: C.body }}>
        <p style={{ maxWidth: 320, textAlign: 'center', color: C.accent, fontFamily: C.heading, fontSize: 22 }}>{message}</p>
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
      <section ref={heroRef} style={{ position: 'relative', minHeight: 560, height: '100svh', overflow: 'hidden', background: C.bg, color: C.heroText }}>
        <div aria-hidden="true" style={{ position: 'absolute', inset: 0, background: C.fallbackBg }} />
        {posterUrl && (
          <img src={posterUrl} alt="" loading="eager" fetchpriority="high" decoding="async" onError={e => { e.currentTarget.style.display = 'none' }}
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
          minWidth: 48, height: 44, borderRadius: C.langRadius, display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
          padding: '0 14px', background: C.langBg, color: C.langColor, border: `1px solid ${C.line}`,
          fontFamily: langFont(lang, C.body), fontSize: 13, fontWeight: 700, textDecoration: 'none',
          backdropFilter: 'blur(8px)', WebkitBackdropFilter: 'blur(8px)',
        }}>{t('langToggle', lang)}</a>
        {info?.logoUrl && (
          <img src={info.logoUrl} alt="" aria-hidden="true" style={{
            position: 'absolute', top: 'calc(env(safe-area-inset-top) + 16px)', left: 16, zIndex: 4,
            width: 54, height: 54, objectFit: 'cover', borderRadius: C.langRadius,
            background: C.langBg, border: `1px solid ${C.line}`, boxShadow: '0 8px 28px rgba(0,0,0,.28)',
          }} />
        )}
        <div style={{
          position: 'absolute', inset: 0, zIndex: 3, display: 'flex', flexDirection: 'column', alignItems: 'center',
          padding: 'calc(env(safe-area-inset-top) + 72px) 24px calc(env(safe-area-inset-bottom) + 26px)', textAlign: 'center',
        }}>
          <div style={{ height: 'min(10vh, 76px)' }} />
          <h1 style={{
            margin: 0, maxWidth: 520, fontFamily: langFont(lang, C.brand), fontSize: C.brandSize,
            fontWeight: C.brandWeight, color: C.heroTitle, letterSpacing: C.brandSpacing,
            textTransform: C.brandTransform, lineHeight: 1.02, textShadow: C.titleShadow,
          }}>{name}</h1>
          {nameBn && <div style={{ marginTop: 8, fontFamily: '"Hind Siliguri", system-ui, sans-serif', fontSize: 'clamp(18px, 5vw, 24px)', color: C.heroTitle }}>{nameBn}</div>}
          <div style={{ flex: 1 }} />
          <button type="button" onClick={onSeeMenu} style={{
            width: '100%', maxWidth: 460, height: C.ctaHeight, borderRadius: C.ctaRadius,
            background: C.ctaBg, color: C.ctaColor, border: C.ctaBorder || 'none', boxShadow: C.ctaShadow,
            fontFamily: langFont(lang, C.ctaFont), fontSize: C.ctaSize, fontWeight: 800, letterSpacing: C.ctaSpacing,
            textTransform: 'uppercase', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 12, cursor: 'pointer',
          }}>
            <span>{t('seeMenu', lang)}</span><span aria-hidden="true">→</span>
          </button>
        </div>
      </section>
    )
  }

  function CategoryNav({ categories, categoryBnMap = {}, active, onPick, visible }) {
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
        position: 'sticky', top: 0, zIndex: 20, background: C.navBg, borderBottom: C.navBorder,
        transform: visible ? 'translateY(0)' : 'translateY(-100%)', transition: 'transform .22s ease',
        paddingTop: 'env(safe-area-inset-top)', backdropFilter: 'blur(9px)', WebkitBackdropFilter: 'blur(9px)',
      }}>
        <div ref={trackRef} style={{ display: 'flex', gap: C.navGap, padding: C.navPadding, overflowX: 'auto', scrollbarWidth: 'none' }}>
          {categories.map(cat => {
            const isActive = cat === active
            const labelEn = cat === 'All' ? t('all', 'en') : cat
            const labelBn = cat === 'All' ? t('all', 'bn') : (categoryBnMap[cat] || labelEn)
            const label = lang === 'bn' ? labelBn : labelEn
            return (
              <button key={cat} ref={el => { chipRefs.current[cat] = el }} type="button" aria-pressed={isActive} onClick={() => onPick(cat)}
                className={isActive && C.navPulse ? 'template-nav-pulse' : undefined}
                style={{
                  flex: '0 0 auto', minHeight: C.navHeight, padding: C.navItemPadding, borderRadius: C.navRadius,
                  background: isActive ? C.navActiveBg : C.navInactiveBg, color: isActive ? C.navActiveText : C.navInactiveText,
                  border: isActive ? C.navActiveBorder : C.navInactiveBorder, borderBottom: isActive ? C.navActiveUnderline : C.navInactiveUnderline,
                  fontFamily: langFont(lang, C.navFont), fontSize: C.navFontSize, fontWeight: C.navWeight, letterSpacing: lang === 'bn' ? 0 : C.navTracking,
                  textTransform: lang === 'bn' ? 'none' : C.navTransform, cursor: 'pointer', whiteSpace: 'nowrap',
                }}>{label}</button>
            )
          })}
        </div>
      </div>
    )
  }

  function SectionDivider() {
    if (C.divider === 'dash') return <div aria-hidden="true" style={{ margin: '30px auto 16px', borderTop: `2px dashed ${C.accent}`, maxWidth: 220 }} />
    if (C.divider === 'dot') return <div aria-hidden="true" style={{ width: 6, height: 6, margin: '32px auto 18px', borderRadius: 3, background: C.accent }} />
    return <div aria-hidden="true" style={{ display: 'flex', alignItems: 'center', gap: 10, margin: '32px auto 18px', maxWidth: 260 }}>
      <span style={{ flex: 1, height: 1, background: C.line }} /><span style={{ width: 8, height: 8, borderRadius: 4, background: C.secondary }} /><span style={{ flex: 1, height: 1, background: C.line }} />
    </div>
  }

  function CategoryHeader({ name, nameBn }) {
    const lang = useLang()
    const display = lang === 'bn' ? (nameBn || name) : name
    return (
      <header style={{ textAlign: C.headerAlign, margin: '0 0 16px' }}>
        <SectionDivider />
        {C.kicker && <div style={{ fontFamily: langFont(lang, C.body), fontSize: C.kickerSize, fontWeight: 800, letterSpacing: lang === 'bn' ? 0 : C.kickerTracking, textTransform: 'uppercase', color: C.kickerColor }}>{C.kicker}</div>}
        <h2 style={{
          display: C.headerUnderline ? 'inline-block' : 'block', margin: C.kicker ? '5px 0 0' : 0,
          paddingBottom: C.headerUnderline ? 8 : 0, borderBottom: C.headerUnderline, fontFamily: langFont(lang, C.heading),
          fontSize: C.categorySize, fontStyle: C.categoryItalic && lang !== 'bn' ? 'italic' : 'normal',
          fontWeight: C.categoryWeight, letterSpacing: lang === 'bn' ? 0 : C.categoryTracking, textTransform: lang === 'bn' ? 'none' : C.categoryTransform, color: C.categoryColor,
        }}>{display}</h2>
      </header>
    )
  }

  function SpiceDots({ level }) {
    if (!level) return null
    return <span aria-label={`Spice level ${level} of 3`} style={{ display: 'inline-flex', gap: 3, alignItems: 'center' }}>
      {[1, 2, 3].map(i => <span key={i} style={{ width: 5, height: 5, borderRadius: 3, background: C.spiceColor, opacity: i <= level ? 1 : .25 }} />)}
    </span>
  }

  function ItemCard({ item, qty, onAdd, onRemove, onOpenDetail }) {
    const lang = useLang()
    const primaryName = pick(item, 'name', lang) || item.nameEn || item.name || item.nameBn
    const secondaryName = lang === 'bn'
      ? (item.nameEn || item.name || '')
      : (item.nameBn || '')
    const description = pick(item, 'description', lang)
    const badge = tagFor(item, C.badges)
    const spice = C.showSpice ? spiceLevelFor(item) : 0
    const hasImage = !!item.imageUrl
    return (
      <article tabIndex={0} className={C.cardLift ? 'template-card-lift fade-up' : 'fade-up'} onClick={onOpenDetail}
        onKeyDown={e => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); onOpenDetail?.() } }}
        style={{
          display: 'grid', gridTemplateColumns: `${C.imageSize}px 1fr`, gap: 12, padding: C.cardPadding,
          background: C.surface, border: `1px solid ${C.line}`, borderRadius: C.cardRadius, cursor: 'pointer',
          boxShadow: C.cardShadow || 'none', transition: 'transform .18s ease, box-shadow .18s ease', outline: 'none',
        }}>
        <div style={{
          width: C.imageSize, height: C.imageSize, borderRadius: C.imageRadius, overflow: 'hidden', background: C.imageBg, position: 'relative',
          ...(hasImage ? { backgroundImage: `url(${item.imageUrl})`, backgroundSize: 'cover', backgroundPosition: 'center' } : {}),
        }}>
          {!hasImage && <MenuFallbackIcon item={item} size={30} />}
        </div>
        <div style={{ minWidth: 0, display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}>
          <div style={{ minWidth: 0 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
              <h3 style={{
                margin: 0, fontFamily: langFont(lang, C.itemNameFont), fontSize: C.itemNameSize, fontWeight: C.itemNameWeight,
                color: C.itemNameColor, lineHeight: 1.18, overflow: 'hidden', textOverflow: 'ellipsis',
                textTransform: lang === 'bn' ? 'none' : C.itemNameTransform,
              }}>{primaryName}</h3>
              {badge && <span style={{ padding: C.badgePadding, borderRadius: 999, background: C.badgeBg, color: C.badgeText, fontFamily: langFont(lang, C.badgeFont), fontSize: 10, fontWeight: 800, textTransform: 'uppercase' }}>{badge}</span>}
              <SpiceDots level={spice} />
            </div>
            {secondaryName && secondaryName !== primaryName && <div style={{ marginTop: 2, fontFamily: '"Hind Siliguri", system-ui, sans-serif', fontSize: C.bnSize, color: C.muted, lineHeight: 1.25, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{secondaryName}</div>}
            {description && <p style={{ margin: '6px 0 0', fontFamily: langFont(lang, C.body), fontSize: 13, lineHeight: 1.38, color: C.muted, display: '-webkit-box', WebkitLineClamp: C.descLines, WebkitBoxOrient: 'vertical', overflow: 'hidden' }}>{description}</p>}
          </div>
          <div style={{ marginTop: 9, display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8 }}>
            <div style={{ fontFamily: C.priceFont, fontSize: C.priceSize, fontWeight: 800, color: C.priceColor, whiteSpace: 'nowrap' }}>{taka(item.price)}</div>
            <div onClick={e => e.stopPropagation()}>
              {qty === 0 ? (
                <button type="button" onClick={onAdd} aria-label={`${t('add', lang)} ${primaryName}`} style={{
                  width: C.addSize, height: C.addSize, borderRadius: C.addRadius, border: 'none', background: C.addBg, color: C.addText,
                  fontSize: 22, lineHeight: 1, fontWeight: 800, display: 'grid', placeItems: 'center', cursor: 'pointer',
                }}>+</button>
              ) : (
                <div style={{ display: 'inline-flex', alignItems: 'center', height: C.addSize, borderRadius: C.addRadius, border: `1px solid ${C.line}`, background: C.qtyBg, color: C.ink, fontFamily: C.body }}>
                  <button type="button" onClick={onRemove} aria-label={t('remove', lang)} style={{ width: 32, height: C.addSize, border: 'none', background: 'transparent', color: C.muted, fontSize: 18 }}>-</button>
                  <span style={{ minWidth: 22, textAlign: 'center', fontWeight: 800 }}>{qty}</span>
                  <button type="button" onClick={onAdd} aria-label={t('add', lang)} style={{ width: 32, height: C.addSize, border: 'none', background: 'transparent', color: C.accent, fontSize: 18 }}>+</button>
                </div>
              )}
            </div>
          </div>
        </div>
      </article>
    )
  }

  const Menu = forwardRef(function Menu({ itemsByCategory, categoryOrder, categoryBnMap, cart, onAdd, onRemove, onOpenDetail, hasFloatingCart }, ref) {
    const lang = useLang()
    return (
      <section id="menu" ref={ref} style={{ background: C.bg, minHeight: '60vh', padding: '0 16px', paddingBottom: hasFloatingCart ? 'calc(env(safe-area-inset-bottom) + 110px)' : 'calc(env(safe-area-inset-bottom) + 40px)', scrollMarginTop: NAV_HEIGHT }}>
        {categoryOrder.length === 0 ? (
          <div style={{ padding: '80px 20px', textAlign: 'center', color: C.muted, fontFamily: langFont(lang, C.body) }}>{t('noItems', lang)}</div>
        ) : categoryOrder.map(cat => {
          const items = itemsByCategory[cat] || []
          if (!items.length) return null
          return (
            <div key={cat} id={categorySlug(cat)} data-template-category={cat} style={{ scrollMarginTop: 82 }}>
              <CategoryHeader name={cat} nameBn={categoryBnMap[cat]} />
              <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                {items.map(item => <ItemCard key={item.id} item={item} qty={cart[item.id] || 0} onAdd={() => onAdd(item.id)} onRemove={() => onRemove(item.id)} onOpenDetail={() => onOpenDetail(item)} />)}
              </div>
            </div>
          )
        })}
      </section>
    )
  })

  function FloatingCart({ count, total, onTap }) {
    const lang = useLang()
    if (count <= 0) return null
    return (
      <button type="button" onClick={onTap} aria-label={`${t('yourOrder', lang)} · ${count} · ${taka(total)}`} className="template-cart-pop" style={{
        position: 'fixed', right: 18, bottom: 'calc(env(safe-area-inset-bottom) + 18px)', zIndex: 40,
        minHeight: 56, padding: '0 18px', borderRadius: C.floatRadius, border: C.floatBorder || 'none', background: C.floatBg, color: C.floatText,
        display: 'inline-flex', alignItems: 'center', gap: 12, fontFamily: langFont(lang, C.ctaFont), fontWeight: 800, fontSize: 14, textTransform: 'uppercase',
        boxShadow: C.floatShadow,
      }}>
        <span style={{ minWidth: 26, height: 26, borderRadius: C.countRadius, background: C.countBg, color: C.countText, display: 'grid', placeItems: 'center', fontFamily: '"Hind Siliguri", system-ui, sans-serif' }}>{count}</span>
        <span>{t('yourOrder', lang)}</span>
        <span style={{ paddingLeft: 10, borderLeft: `1px solid ${C.floatDivider}` }}>{taka(total)}</span>
      </button>
    )
  }

  function Storefront({ info, items, cart, onAdd, onRemove, onOpenCart, onOpenDetail, initialView = 'hero' }) {
    const heroRef = useRef(null)
    const menuRef = useRef(null)
    const sectionRefs = useRef({})
    const [navVisible, setNavVisible] = useState(false)
    const [active, setActive] = useState('All')
    const { order, byCat, bnMap } = useMemo(() => groupItems(items || []), [items])
    const categories = useMemo(() => ['All', ...order], [order])
    const itemsByCategory = useMemo(() => ({ All: items || [], ...byCat }), [items, byCat])

    useEffect(() => {
      if (initialView === 'menu' && menuRef.current) {
        window.scrollTo({ top: menuRef.current.offsetTop - NAV_HEIGHT, behavior: 'auto' })
        setNavVisible(true)
      }
    }, [])
    useEffect(() => {
      if (!heroRef.current) return
      const io = new IntersectionObserver(([entry]) => setNavVisible(!entry.isIntersecting), { threshold: 0, rootMargin: '0px 0px -90% 0px' })
      io.observe(heroRef.current)
      return () => io.disconnect()
    }, [])
    useEffect(() => {
      if (!menuRef.current) return
      const nodes = menuRef.current.querySelectorAll('[data-template-category]')
      const map = {}
      nodes.forEach(n => { map[n.dataset.templateCategory] = n })
      sectionRefs.current = map
      const io = new IntersectionObserver(entries => {
        const visible = entries.filter(e => e.isIntersecting)
        if (!visible.length) return
        visible.sort((a, b) => b.intersectionRatio - a.intersectionRatio)
        const cat = visible[0].target.dataset.templateCategory
        if (cat) setActive(cat)
      }, { rootMargin: `-${NAV_HEIGHT + 12}px 0px -70% 0px`, threshold: [0, .25, .5, 1] })
      nodes.forEach(n => io.observe(n))
      return () => io.disconnect()
    }, [order.length])

    function pickCategory(cat) {
      setActive(cat)
      smoothScrollTo(cat === 'All' ? menuRef.current : sectionRefs.current[cat], NAV_HEIGHT - 4)
    }

    const count = cartCount(cart)
    const total = cartTotal(cart, items || [])
    return (
      <div style={{ background: C.bg, color: C.ink, minHeight: '100svh', fontFamily: C.body }}>
        <div ref={heroRef}><Hero info={info} onSeeMenu={() => smoothScrollTo(menuRef.current, NAV_HEIGHT - 4)} /></div>
        <CategoryNav categories={categories} categoryBnMap={bnMap} active={active} onPick={pickCategory} visible={navVisible} />
        <Menu ref={menuRef} itemsByCategory={itemsByCategory} categoryOrder={order} categoryBnMap={bnMap} cart={cart} onAdd={onAdd} onRemove={onRemove} onOpenDetail={onOpenDetail} hasFloatingCart={count > 0} />
        <FloatingCart count={count} total={total} onTap={onOpenCart} />
      </div>
    )
  }

  function Field({ label, value, onChange, type = 'text', autoComplete, multiline }) {
    const lang = useLang()
    const common = {
      width: '100%', background: C.inputBg, color: C.ink, border: `1px solid ${C.line}`, borderRadius: C.inputRadius,
      fontFamily: langFont(lang, C.body), fontSize: 15, outline: 'none',
    }
    return (
      <label style={{ display: 'block' }}>
        <div style={{ marginBottom: 6, color: C.labelColor, fontFamily: langFont(lang, C.body), fontSize: 11, fontWeight: 800, letterSpacing: lang === 'bn' ? 0 : '.12em', textTransform: 'uppercase' }}>{label}</div>
        {multiline ? (
          <textarea rows={3} value={value} onChange={e => onChange(e.target.value)} style={{ ...common, padding: '12px 14px', resize: 'vertical' }} />
        ) : (
          <input type={type} autoComplete={autoComplete} value={value} onChange={e => onChange(e.target.value)} style={{ ...common, height: 48, padding: '0 14px' }} />
        )}
      </label>
    )
  }

  function Cart({ cart, items, note, onNote, delivery, onDelivery, onAdd, onRemove, onBack, onPlace, submitting, info, outletId }) {
    const lang = useLang()
    const [geo, setGeo] = useState({ status: 'idle', address: '', error: '' })
    const mountedRef = useRef(true)
    const addressRef = useRef(delivery.address)
    useEffect(() => { addressRef.current = delivery.address }, [delivery.address])
    useEffect(() => {
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
    }, [outletId, onDelivery])

    const cartItems = Object.entries(cart).map(([id, qty]) => {
      const item = items.find(i => i.id === id)
      return item ? { ...item, qty } : null
    }).filter(Boolean)
    const total = cartTotal(cart, items)
    const deliveryReady = delivery.name.trim() && delivery.address.trim() && delivery.mobile.trim().length >= 7
    return (
      <div style={{ minHeight: '100svh', background: C.bg, color: C.ink, fontFamily: C.body }}>
        <header style={{ position: 'sticky', top: 0, zIndex: 10, padding: 'calc(env(safe-area-inset-top) + 14px) 16px 14px', display: 'flex', gap: 12, alignItems: 'center', background: C.bg, borderBottom: `1px solid ${C.line}` }}>
          <button type="button" onClick={onBack} aria-label={t('back', lang)} style={{ width: 44, height: 44, borderRadius: C.backRadius, background: C.surface, border: `1px solid ${C.line}`, color: C.ink, fontSize: 20 }}>←</button>
          <div style={{ minWidth: 0 }}>
            <h1 style={{ margin: 0, fontFamily: langFont(lang, C.heading), fontSize: 20, color: C.accent, letterSpacing: lang === 'bn' ? 0 : C.cartTitleTracking, textTransform: lang === 'bn' ? 'none' : 'uppercase' }}>{t('yourOrder', lang)}</h1>
            {info?.restaurantName && <div style={{ marginTop: 2, color: C.muted, fontSize: 13, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{info.restaurantName}{info.outletName ? ` · ${info.outletName}` : ''}</div>}
          </div>
        </header>
        <div style={{ padding: '12px 16px calc(env(safe-area-inset-bottom) + 200px)' }}>
          {cartItems.length === 0 ? (
            <div style={{ padding: '60px 20px', textAlign: 'center', color: C.muted }}>{t('noItems', lang)}</div>
          ) : (
            <ul style={{ listStyle: 'none', margin: 0, padding: 0 }}>
              {cartItems.map(item => (
                <li key={item.id} style={{ display: 'grid', gridTemplateColumns: '52px 1fr auto', gap: 12, alignItems: 'center', padding: '12px 0', borderBottom: `1px solid ${C.line}` }}>
                  <div style={{ width: 52, height: 52, borderRadius: C.imageRadius, background: C.surface, backgroundImage: item.imageUrl ? `url(${item.imageUrl})` : undefined, backgroundSize: 'cover', backgroundPosition: 'center' }} />
                  <div style={{ minWidth: 0 }}>
                    <div style={{ fontFamily: langFont(lang, C.itemNameFont), color: C.ink, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{pick(item, 'name', lang) || item.name}</div>
                    <div style={{ marginTop: 6, display: 'inline-flex', alignItems: 'center', height: 32, borderRadius: C.addRadius, border: `1px solid ${C.line}`, background: C.surface }}>
                      <button type="button" onClick={() => onRemove(item.id)} style={{ width: 32, height: 32, background: 'transparent', border: 'none', color: C.muted }}>-</button>
                      <span style={{ minWidth: 20, textAlign: 'center', fontWeight: 800 }}>{item.qty}</span>
                      <button type="button" onClick={() => onAdd(item.id)} style={{ width: 32, height: 32, background: 'transparent', border: 'none', color: C.accent }}>+</button>
                    </div>
                  </div>
                  <div style={{ fontFamily: C.priceFont, color: C.priceColor, fontWeight: 800 }}>{taka(item.price * item.qty)}</div>
                </li>
              ))}
            </ul>
          )}
          <section style={{ marginTop: 24 }}>
            <CategoryHeader name={t('yourDetails', lang)} />
            <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
              <Field label={t('name', lang)} value={delivery.name} onChange={v => onDelivery(d => ({ ...d, name: v }))} autoComplete="name" />
              <Field label={t('mobile', lang)} value={delivery.mobile} onChange={v => onDelivery(d => ({ ...d, mobile: v }))} type="tel" autoComplete="tel" />
              <Field label={t('address', lang)} value={delivery.address} onChange={v => onDelivery(d => ({ ...d, address: v }))} autoComplete="street-address" multiline />
              {geo.status === 'locating' || geo.status === 'geocoding' ? <div style={{ fontSize: 12, color: C.muted }}>{t('detectingAddress', lang)}</div> : null}
              {geo.status === 'ready' && geo.address && geo.address !== delivery.address ? (
                <button type="button" onClick={() => onDelivery(d => ({ ...d, address: geo.address }))} style={{ alignSelf: 'flex-start', padding: '8px 12px', borderRadius: C.navRadius, border: `1px solid ${C.accent}`, background: 'transparent', color: C.accent, fontFamily: C.body }}>{t('useDetected', lang)}</button>
              ) : null}
              <Field label={t('note', lang)} value={note} onChange={onNote} multiline />
            </div>
          </section>
        </div>
        <footer style={{ position: 'fixed', left: 0, right: 0, bottom: 0, zIndex: 20, background: C.footerBg, borderTop: `1px solid ${C.line}`, padding: '12px 16px calc(env(safe-area-inset-bottom) + 12px)', boxShadow: C.footerShadow }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10, color: C.muted, fontWeight: 800, textTransform: 'uppercase', letterSpacing: '.12em', fontSize: 12 }}>
            <span>{t('total', lang)}</span><span style={{ color: C.priceColor, fontFamily: C.priceFont, fontSize: 22 }}>{taka(total)}</span>
          </div>
          <button type="button" onClick={onPlace} disabled={!deliveryReady || submitting || cartItems.length === 0} style={{
            width: '100%', height: 56, borderRadius: C.ctaRadius, border: C.ctaBorder || 'none',
            background: (!deliveryReady || cartItems.length === 0) ? C.disabledBg : C.ctaBg, color: C.ctaColor,
            fontFamily: langFont(lang, C.ctaFont), fontWeight: 800, letterSpacing: C.ctaSpacing, textTransform: 'uppercase', opacity: submitting ? .7 : 1,
          }}>{submitting ? t('placingOrder', lang) : t('placeOrder', lang)}</button>
        </footer>
      </div>
    )
  }

  function ItemSheet({ item, qty, onAdd, onRemove, onClose }) {
    const lang = useLang()
    const media = buildMedia(item)
    const current = media[0]
    const primaryName = pick(item, 'name', lang) || item.nameEn || item.name || item.nameBn
    const secondaryName = lang === 'bn'
      ? (item.nameEn || item.name || '')
      : (item.nameBn || '')
    const description = pick(item, 'description', lang)
    const videoRef = useRef(null)
    useEffect(() => {
      function onKey(e) { if (e.key === 'Escape') onClose() }
      window.addEventListener('keydown', onKey)
      return () => window.removeEventListener('keydown', onKey)
    }, [onClose])
    useEffect(() => { if (videoRef.current) videoRef.current.play().catch(() => {}) }, [item?.id])
    if (!item) return null
    return (
      <div className="fade-in" role="dialog" aria-modal="true" onClick={e => { if (e.target === e.currentTarget) onClose() }} style={{ position: 'fixed', inset: 0, zIndex: 50, background: 'rgba(0,0,0,.62)', display: 'flex', alignItems: 'flex-end', backdropFilter: 'blur(4px)' }}>
        <div className="slide-up" style={{ width: '100%', maxHeight: '92svh', overflow: 'hidden', display: 'flex', flexDirection: 'column', background: C.bg, color: C.ink, borderTopLeftRadius: 22, borderTopRightRadius: 22, border: `1px solid ${C.line}`, borderBottom: 'none' }}>
          <div style={{ position: 'relative', height: 240, background: C.surface, flexShrink: 0, ...(current?.type === 'image' ? { backgroundImage: `url(${current.url})`, backgroundSize: 'cover', backgroundPosition: 'center' } : {}) }}>
            {current?.type === 'video' && <video ref={videoRef} src={current.url} autoPlay muted loop playsInline style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover' }} />}
            {!current && <MenuFallbackIcon item={item} size={62} />}
            <div aria-hidden="true" style={{ position: 'absolute', inset: 0, background: C.sheetMediaOverlay }} />
            <button type="button" onClick={onClose} aria-label={t('back', lang)} style={{ position: 'absolute', top: 12, right: 12, width: 40, height: 40, borderRadius: 20, border: `1px solid ${C.line}`, background: C.surface, color: C.ink, fontSize: 18 }}>×</button>
          </div>
          <div style={{ padding: '20px 22px 24px', overflowY: 'auto', flex: 1 }}>
            <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', gap: 12 }}>
              <h2 style={{ margin: 0, fontFamily: langFont(lang, C.heading), fontSize: 27, fontStyle: C.categoryItalic && lang !== 'bn' ? 'italic' : 'normal', color: C.ink, lineHeight: 1.15 }}>{primaryName}</h2>
              <div style={{ fontFamily: C.priceFont, color: C.priceColor, fontWeight: 800, fontSize: 22 }}>{taka(item.price)}</div>
            </div>
            {secondaryName && secondaryName !== primaryName && <div style={{ marginTop: 5, color: C.muted, fontFamily: '"Hind Siliguri", system-ui, sans-serif', fontSize: 16 }}>{secondaryName}</div>}
            {description && <p style={{ margin: '18px 0 0', color: C.muted, fontFamily: langFont(lang, C.body), fontSize: 15, lineHeight: 1.55 }}>{description}</p>}
          </div>
          <footer style={{ display: 'flex', gap: 12, padding: '12px 16px calc(env(safe-area-inset-bottom) + 16px)', borderTop: `1px solid ${C.line}`, background: C.footerBg }}>
            {qty > 0 && <div style={{ display: 'inline-flex', alignItems: 'center', height: 56, borderRadius: C.ctaRadius, border: `1px solid ${C.line}`, background: C.surface }}>
              <button type="button" onClick={onRemove} style={{ width: 48, height: 54, border: 'none', background: 'transparent', color: C.muted, fontSize: 22 }}>-</button>
              <span style={{ minWidth: 30, textAlign: 'center', fontWeight: 800 }}>{qty}</span>
              <button type="button" onClick={onAdd} style={{ width: 48, height: 54, border: 'none', background: 'transparent', color: C.accent, fontSize: 22 }}>+</button>
            </div>}
            <button type="button" onClick={onAdd} style={{ flex: 1, height: 56, borderRadius: C.ctaRadius, border: C.ctaBorder || 'none', background: C.ctaBg, color: C.ctaColor, fontFamily: langFont(lang, C.ctaFont), fontWeight: 800, letterSpacing: C.ctaSpacing, textTransform: 'uppercase' }}>{t('add', lang)} · {taka(item.price)}</button>
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
        <main style={{ flex: 1, padding: 'calc(env(safe-area-inset-top) + 42px) 20px 24px', overflowY: 'auto', textAlign: 'center' }}>
          <div style={{ margin: '0 auto 18px', width: 58, height: 58, borderRadius: C.successRadius, display: 'grid', placeItems: 'center', background: C.ctaBg, color: C.ctaColor, fontFamily: C.heading, fontSize: 28, fontWeight: 800 }}>✓</div>
          <h1 style={{ margin: 0, fontFamily: langFont(lang, C.heading), fontSize: 28, color: C.accent, letterSpacing: lang === 'bn' ? 0 : C.cartTitleTracking, textTransform: lang === 'bn' ? 'none' : 'uppercase' }}>{t('orderConfirmed', lang)}</h1>
          <section style={{ marginTop: 22, padding: '22px 18px', background: C.surface, border: `1px solid ${C.line}`, borderRadius: C.cardRadius }}>
            <div style={{ color: C.muted, fontSize: 11, fontWeight: 800, letterSpacing: '.16em', textTransform: 'uppercase' }}>{t('orderNumber', lang)}</div>
            {order?.serialNumber != null && <div style={{ marginTop: 5, fontFamily: C.priceFont, color: C.priceColor, fontSize: 58, fontWeight: 800, lineHeight: 1 }}>#{order.serialNumber}</div>}
            <div style={{ display: 'flex', justifyContent: 'center', gap: 30, marginTop: 20 }}>
              <div><div style={{ color: C.muted, fontSize: 11 }}>{lang === 'bn' ? 'আইটেম' : 'Items'}</div><strong>{totalItems}</strong></div>
              <div><div style={{ color: C.muted, fontSize: 11 }}>{t('total', lang)}</div><strong style={{ color: C.priceColor }}>{taka(order?.total || 0)}</strong></div>
            </div>
          </section>
          {order && <button type="button" onClick={() => generateReceipt(order, info, cartItems)} style={{ marginTop: 18, width: '100%', height: 52, borderRadius: C.ctaRadius, border: `1px solid ${C.accent}`, background: 'transparent', color: C.ink, fontFamily: C.body, fontWeight: 800, textTransform: 'uppercase', letterSpacing: '.08em' }}>{lang === 'bn' ? 'রিসিট ডাউনলোড' : 'Download Receipt'}</button>}
        </main>
        <footer style={{ padding: '12px 18px calc(env(safe-area-inset-bottom) + 16px)', borderTop: `1px solid ${C.line}`, background: C.footerBg }}>
          <button type="button" onClick={onBack} style={{ width: '100%', height: 56, borderRadius: C.ctaRadius, border: C.ctaBorder || 'none', background: C.ctaBg, color: C.ctaColor, fontFamily: langFont(lang, C.ctaFont), fontWeight: 800, letterSpacing: C.ctaSpacing, textTransform: 'uppercase' }}>{t('backToMenu', lang)} →</button>
        </footer>
      </div>
    )
  }

  return { Storefront, ItemSheet, Cart, Success, Loading, Error }
}

const INTER = '"Inter", system-ui, sans-serif'
export const brickOverrides = makeOverrides({
  slug: 'brick',
  bg: '#F4EBDC', surface: '#FFFFFF', accent: '#E89A4A', secondary: '#E8B547', ink: '#2A2420', muted: '#6B5E4F', line: '#D9CCB5',
  brand: '"Anton", sans-serif', heading: '"Bebas Neue", sans-serif', body: INTER, heroText: '#fff', heroTitle: '#fff', heroSub: 'rgba(255,255,255,.8)',
  fallbackBg: 'linear-gradient(135deg, #F4EBDC 0%, #E8B547 55%, #C9583A 100%)', heroOverlay: 'linear-gradient(180deg, rgba(0,0,0,0) 45%, rgba(0,0,0,.6) 100%)',
  medallionBg: '#2A2420', medallionText: '#E8B547', medallionBorder: '2px solid #E8B547', medallionShadow: '0 12px 26px rgba(42,36,32,.22)',
  brandSize: 'clamp(40px, 12vw, 56px)', brandWeight: 400, brandSpacing: '-.02em', brandTransform: 'uppercase', titleShadow: '0 2px 16px rgba(0,0,0,.55)', taglineItalic: false,
  ctaBg: '#E89A4A', ctaColor: '#2A2420', ctaBorder: 'none', ctaShadow: '0 14px 32px rgba(232,154,74,.36)', ctaRadius: 28, ctaHeight: 56, ctaFont: '"Anton", sans-serif', ctaSize: 16, ctaSpacing: '.03em',
  langRadius: 22, langBg: 'rgba(255,255,255,.72)', langColor: '#2A2420', navBg: 'rgba(244,235,220,.94)', navBorder: '1px solid #D9CCB5', navGap: 8, navPadding: '12px 16px', navHeight: 40, navItemPadding: '0 18px', navRadius: 22,
  navActiveBg: '#2A2420', navInactiveBg: '#FFFFFF', navActiveText: '#E8B547', navInactiveText: '#2A2420', navActiveBorder: '1px solid #2A2420', navInactiveBorder: '1px solid #D9CCB5', navActiveUnderline: 'none', navInactiveUnderline: 'none',
  navFont: INTER, navFontSize: 12, navWeight: 800, navTracking: '.06em', navTransform: 'uppercase',
  divider: 'dash', headerAlign: 'left', headerUnderline: '2px solid #E89A4A', kicker: '', categorySize: 28, categoryItalic: false, categoryWeight: 400, categoryTracking: '.08em', categoryTransform: 'uppercase', categoryColor: '#2A2420',
  cardPadding: 12, cardRadius: 16, cardLift: true, imageSize: 100, imageRadius: 12, imageBg: '#F4EBDC', itemNameFont: '"Bebas Neue", sans-serif', itemNameSize: 18, itemNameWeight: 400, itemNameColor: '#2A2420', itemNameTransform: 'uppercase', bnSize: 14, descLines: 2,
  priceFont: '"Anton", sans-serif', priceSize: 18, priceColor: '#C9583A', addSize: 40, addRadius: 20, addBg: '#E89A4A', addText: '#2A2420', qtyBg: '#F4EBDC',
  badges: ['Popular', "Chef's pick"], badgeBg: '#E8B547', badgeText: '#2A2420', badgeFont: '"Anton", sans-serif', badgePadding: '3px 8px', showSpice: false, spiceColor: '#C9583A',
  floatRadius: 28, floatBg: '#2A2420', floatText: '#E8B547', floatBorder: 'none', floatShadow: '0 16px 34px rgba(42,36,32,.28)', countRadius: 13, countBg: '#E8B547', countText: '#2A2420', floatDivider: 'rgba(232,181,71,.45)',
  inputBg: '#FFFFFF', inputRadius: 12, labelColor: '#C9583A', footerBg: '#FFFFFF', footerShadow: '0 -10px 24px rgba(42,36,32,.12)', disabledBg: '#D9CCB5', backRadius: 22, cartTitleTracking: '.06em', sheetMediaOverlay: 'linear-gradient(180deg, transparent 30%, rgba(42,36,32,.55) 100%)', successRadius: 29,
})

export const lanternOverrides = makeOverrides({
  slug: 'lantern',
  bg: '#14181A', surface: '#1F2628', accent: '#E8744A', secondary: '#5FB8C4', ink: '#EDE8DD', muted: '#8A9095', line: '#2A3235',
  brand: '"Bodoni Moda", serif', heading: '"Bodoni Moda", serif', body: INTER, heroText: '#EDE8DD', heroTitle: '#EDE8DD', heroSub: '#8A9095',
  fallbackBg: 'radial-gradient(80% 50% at 70% 30%, rgba(95,184,196,.22), transparent 60%), radial-gradient(70% 60% at 30% 75%, rgba(232,116,74,.22), transparent 68%), #14181A', heroOverlay: 'linear-gradient(180deg, rgba(0,0,0,0) 45%, rgba(20,24,26,.9) 100%)',
  medallionBg: '#1F2628', medallionText: '#E8744A', medallionBorder: '1px solid #5FB8C4', medallionShadow: '0 0 28px rgba(232,116,74,.24)',
  brandSize: 'clamp(38px, 10vw, 48px)', brandWeight: 600, brandSpacing: '-.01em', brandTransform: 'none', titleShadow: '0 2px 18px rgba(0,0,0,.6)', taglineItalic: true,
  ctaBg: '#E8744A', ctaColor: '#14181A', ctaBorder: 'none', ctaShadow: '0 12px 28px rgba(232,116,74,.24)', ctaRadius: 12, ctaHeight: 52, ctaFont: INTER, ctaSize: 15, ctaSpacing: '.08em',
  langRadius: 12, langBg: 'rgba(31,38,40,.74)', langColor: '#5FB8C4', navBg: 'rgba(20,24,26,.94)', navBorder: '1px solid #2A3235', navGap: 18, navPadding: '12px 16px', navHeight: 38, navItemPadding: '0 2px', navRadius: 0,
  navActiveBg: 'transparent', navInactiveBg: 'transparent', navActiveText: '#EDE8DD', navInactiveText: '#8A9095', navActiveBorder: 'none', navInactiveBorder: 'none', navActiveUnderline: '2px solid #E8744A', navInactiveUnderline: '2px solid transparent',
  navFont: INTER, navFontSize: 12, navWeight: 800, navTracking: '.08em', navTransform: 'uppercase', navPulse: true,
  divider: 'rule-dot', headerAlign: 'left', headerUnderline: '', kicker: 'Menu', kickerSize: 12, kickerTracking: '.12em', kickerColor: '#5FB8C4', categorySize: 26, categoryItalic: false, categoryWeight: 600, categoryTracking: '0', categoryTransform: 'none', categoryColor: '#EDE8DD',
  cardPadding: 8, cardRadius: 8, cardLift: false, imageSize: 96, imageRadius: 8, imageBg: '#14181A', itemNameFont: '"Bodoni Moda", serif', itemNameSize: 17, itemNameWeight: 600, itemNameColor: '#EDE8DD', itemNameTransform: 'none', bnSize: 13, descLines: 2,
  priceFont: INTER, priceSize: 16, priceColor: '#E8744A', addSize: 36, addRadius: 6, addBg: '#2F5D4F', addText: '#EDE8DD', qtyBg: '#14181A',
  badges: [], badgeBg: '#5FB8C4', badgeText: '#14181A', badgeFont: INTER, badgePadding: '3px 8px', showSpice: true, spiceColor: '#E8744A',
  floatRadius: 12, floatBg: '#E8744A', floatText: '#14181A', floatBorder: 'none', floatShadow: '0 16px 34px rgba(232,116,74,.24)', countRadius: 4, countBg: '#14181A', countText: '#E8744A', floatDivider: 'rgba(20,24,26,.35)',
  inputBg: '#1F2628', inputRadius: 8, labelColor: '#5FB8C4', footerBg: '#1F2628', footerShadow: '0 -10px 28px rgba(0,0,0,.32)', disabledBg: '#2A3235', backRadius: 8, cartTitleTracking: '.08em', sheetMediaOverlay: 'linear-gradient(180deg, transparent 30%, rgba(20,24,26,.78) 100%)', successRadius: 10,
})

export const marbleOverrides = makeOverrides({
  slug: 'marble',
  bg: '#FBF8F2', surface: '#FFFFFF', accent: '#B89556', secondary: '#9DAE94', ink: '#3B2A1F', muted: '#6B5E50', line: '#E8E0D2',
  brand: '"Fraunces", serif', heading: '"Fraunces", serif', body: INTER, heroText: '#3B2A1F', heroTitle: '#3B2A1F', heroSub: '#6B5E50',
  fallbackBg: 'linear-gradient(145deg, #FFFFFF 0%, #FBF8F2 50%, #E8C8B8 100%)', heroOverlay: 'linear-gradient(180deg, rgba(251,248,242,0) 40%, rgba(251,248,242,.95) 100%)',
  medallionBg: '#FFFFFF', medallionText: '#3B2A1F', medallionBorder: '1px solid #B89556', medallionShadow: '0 10px 24px rgba(59,42,31,.14)',
  brandSize: 'clamp(38px, 10vw, 48px)', brandWeight: 650, brandSpacing: '0', brandTransform: 'none', titleShadow: 'none', taglineItalic: true,
  ctaBg: '#3B2A1F', ctaColor: '#FBF8F2', ctaBorder: 'none', ctaShadow: 'none', ctaRadius: 8, ctaHeight: 52, ctaFont: '"Fraunces", serif', ctaSize: 15, ctaSpacing: '0',
  langRadius: 8, langBg: 'rgba(255,255,255,.74)', langColor: '#3B2A1F', navBg: 'rgba(251,248,242,.94)', navBorder: '1px solid #E8E0D2', navGap: 20, navPadding: '12px 16px', navHeight: 36, navItemPadding: '0 2px', navRadius: 0,
  navActiveBg: 'transparent', navInactiveBg: 'transparent', navActiveText: '#3B2A1F', navInactiveText: '#6B5E50', navActiveBorder: 'none', navInactiveBorder: 'none', navActiveUnderline: '1px solid #B89556', navInactiveUnderline: '1px solid transparent',
  navFont: INTER, navFontSize: 12, navWeight: 700, navTracking: '.04em', navTransform: 'none',
  divider: 'dot', headerAlign: 'left', headerUnderline: '1px solid #B89556', kicker: 'Selection', kickerSize: 11, kickerTracking: '.16em', kickerColor: '#B89556', categorySize: 28, categoryItalic: true, categoryWeight: 600, categoryTracking: '0', categoryTransform: 'none', categoryColor: '#3B2A1F',
  cardPadding: 10, cardRadius: 12, cardLift: false, cardShadow: 'none', imageSize: 80, imageRadius: 10, imageBg: '#F2EDE3', itemNameFont: '"Fraunces", serif', itemNameSize: 16, itemNameWeight: 600, itemNameColor: '#3B2A1F', itemNameTransform: 'none', bnSize: 13, descLines: 3,
  priceFont: '"Fraunces", serif', priceSize: 15, priceColor: '#3B2A1F', addSize: 32, addRadius: 16, addBg: '#3B2A1F', addText: '#FBF8F2', qtyBg: '#FBF8F2',
  badges: ['New', 'Seasonal'], badgeBg: '#E8C8B8', badgeText: '#3B2A1F', badgeFont: INTER, badgePadding: '3px 8px', showSpice: false, spiceColor: '#B89556',
  floatRadius: 8, floatBg: '#3B2A1F', floatText: '#FBF8F2', floatBorder: '1px solid #B89556', floatShadow: '0 14px 28px rgba(59,42,31,.18)', countRadius: 4, countBg: '#FBF8F2', countText: '#3B2A1F', floatDivider: 'rgba(251,248,242,.35)',
  inputBg: '#FFFFFF', inputRadius: 10, labelColor: '#B89556', footerBg: '#FFFFFF', footerShadow: '0 -8px 20px rgba(59,42,31,.08)', disabledBg: '#E8E0D2', backRadius: 8, cartTitleTracking: '0', sheetMediaOverlay: 'linear-gradient(180deg, transparent 35%, rgba(251,248,242,.72) 100%)', successRadius: 29,
})
