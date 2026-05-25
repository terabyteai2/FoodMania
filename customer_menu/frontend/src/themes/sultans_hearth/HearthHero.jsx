import React, { useEffect, useRef, useState } from 'react'
import { useTokens, themeAssetPaths } from '../index.jsx'
import StarOrnament from './StarOrnament.jsx'
import { useLang, t, toggleLangUrl } from './i18n.js'

// Detect data-saver / save-data mode.
function isDataSaver() {
  if (typeof navigator === 'undefined') return false
  const c = navigator.connection || navigator.webkitConnection || navigator.mozConnection
  return !!(c && c.saveData)
}

function prefersReducedMotion() {
  if (typeof window === 'undefined') return false
  return window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches
}

export default function HearthHero({ info, onSeeMenu }) {
  const T = useTokens()
  const lang = useLang()
  const heroRef = useRef(null)
  const videoRef = useRef(null)
  const [videoOk, setVideoOk] = useState(false)
  const placeholder = themeAssetPaths(T._slug)

  const posterUrl =
    info?.bannerUrl ||
    (info?.galleryImages && info.galleryImages[0]) ||
    placeholder.placeholderImage
  const videoUrl = info?.videoUrl || placeholder.placeholderVideo

  // Lazy-load video after first paint via IntersectionObserver.
  useEffect(() => {
    if (!videoUrl) return
    if (prefersReducedMotion() || isDataSaver()) return
    if (!heroRef.current) return
    const el = heroRef.current
    let cancelled = false
    const io = new IntersectionObserver(entries => {
      if (cancelled) return
      if (entries.some(e => e.isIntersecting)) {
        setVideoOk(true)
        io.disconnect()
      }
    }, { rootMargin: '0px' })
    io.observe(el)
    return () => { cancelled = true; io.disconnect() }
  }, [videoUrl])

  useEffect(() => {
    if (videoOk && videoRef.current) videoRef.current.play().catch(() => {})
  }, [videoOk])

  const nameEn = info?.restaurantNameEn || info?.restaurantName || 'Restaurant'
  const nameBn = info?.restaurantNameBn
  const initial = (nameEn[0] || 'R').toUpperCase()
  const outletName = info?.outletNameBn && lang === 'bn'
    ? info.outletNameBn
    : (info?.outletName || '')

  function handleSeeMenu(e) {
    e.preventDefault()
    onSeeMenu && onSeeMenu()
  }

  return (
    <section
      ref={heroRef}
      style={{
        position: 'relative',
        width: '100%',
        height: '100svh',
        minHeight: 560,
        overflow: 'hidden',
        background: T.bg,
        color: T.ink,
      }}
    >
      {/* Generated candlelit backdrop — always rendered. If a real
          poster image loads on top, this is hidden underneath; if the
          poster 404s, this remains visible. */}
      <div aria-hidden="true" style={{
        position: 'absolute', inset: 0,
        background: `
          radial-gradient(80% 55% at 50% 38%, rgba(232,163,61,.18) 0%, transparent 60%),
          radial-gradient(60% 40% at 50% 80%, rgba(226,107,44,.20) 0%, transparent 70%),
          ${T.bg}
        `,
      }} />
      <div aria-hidden="true" style={{
        position: 'absolute', inset: 0, opacity: 0.10,
        backgroundImage: `repeating-linear-gradient(45deg, ${T.amber} 0 1px, transparent 1px 24px),
                          repeating-linear-gradient(-45deg, ${T.amber} 0 1px, transparent 1px 24px)`,
      }} />

      {/* Poster (LCP). If the file 404s, onError hides it and the
          generated backdrop above shows through. */}
      {posterUrl && (
        <img
          src={posterUrl}
          alt=""
          loading="eager"
          fetchpriority="high"
          decoding="async"
          aria-hidden="true"
          width={1080}
          height={1920}
          onError={e => { e.currentTarget.style.display = 'none' }}
          style={{
            position: 'absolute', inset: 0,
            width: '100%', height: '100%',
            objectFit: 'cover',
          }}
        />
      )}

      {/* Lazy video */}
      {videoOk && videoUrl && (
        <video
          ref={videoRef}
          src={videoUrl}
          poster={posterUrl || undefined}
          muted
          autoPlay
          loop
          playsInline
          preload="metadata"
          aria-hidden="true"
          onError={() => setVideoOk(false)}
          style={{
            position: 'absolute', inset: 0,
            width: '100%', height: '100%',
            objectFit: 'cover',
          }}
        />
      )}

      {/* Dark vignette + bottom gradient */}
      <div aria-hidden="true" style={{
        position: 'absolute', inset: 0,
        background: `radial-gradient(120% 80% at 50% 50%, rgba(0,0,0,0) 35%, rgba(0,0,0,.72) 100%)`,
      }} />
      <div aria-hidden="true" style={{
        position: 'absolute', inset: 0,
        background: 'linear-gradient(180deg, rgba(0,0,0,0) 50%, rgba(0,0,0,.88) 100%)',
      }} />

      {/* Language toggle (top-right) */}
      <a
        href={toggleLangUrl(lang)}
        style={{
          position: 'absolute', top: 'calc(env(safe-area-inset-top) + 16px)', right: 16,
          zIndex: 4,
          minWidth: 48, minHeight: 48,
          display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
          padding: '0 14px',
          borderRadius: 22,
          background: 'rgba(26,20,16,.55)',
          color: T.amber,
          border: `1px solid ${T.line}`,
          fontFamily: lang === 'bn' ? '"Hind Siliguri", system-ui, sans-serif' : T.display,
          fontSize: 13, letterSpacing: '.12em',
          textDecoration: 'none',
          backdropFilter: 'blur(6px)',
          WebkitBackdropFilter: 'blur(6px)',
          WebkitTapHighlightColor: 'transparent',
        }}
      >
        {t('langToggle', lang)}
      </a>

      {/* Content */}
      <div style={{
        position: 'absolute', inset: 0, zIndex: 3,
        display: 'flex', flexDirection: 'column', alignItems: 'center',
        padding: '0 24px',
        paddingTop: 'calc(env(safe-area-inset-top) + 64px)',
        paddingBottom: 'calc(env(safe-area-inset-bottom) + 24px)',
      }}>
        {/* Top spacer to push medallion roughly into upper third */}
        <div style={{ height: 'min(8vh, 60px)' }} />

        {/* Medallion */}
        <div style={{
          position: 'relative',
          width: 72, height: 72,
          borderRadius: 36,
          background: '#2A1F1A',
          border: `1.5px solid #C9A24B`,
          display: 'grid', placeItems: 'center',
          boxShadow: '0 12px 36px rgba(0,0,0,.55), inset 0 0 24px rgba(201,162,75,.18)',
          marginBottom: 18,
        }}>
          {/* Faint star behind initial */}
          <div style={{ position: 'absolute', inset: 0, display: 'grid', placeItems: 'center', opacity: .55 }}>
            <StarOrnament size={56} stroke="#4A3A2E" strokeWidth={1} withDot={false} />
          </div>
          <span style={{
            position: 'relative',
            fontFamily: '"Cinzel", serif',
            fontWeight: 600,
            fontSize: 34, lineHeight: 1,
            color: '#E8A33D',
            letterSpacing: '.04em',
            textShadow: '0 2px 10px rgba(0,0,0,.6)',
          }}>{initial}</span>
        </div>

        {/* Brand name (stacked en + bn) */}
        <h1 style={{
          margin: 0,
          fontFamily: '"Cinzel", serif',
          fontWeight: 600,
          fontSize: 'clamp(32px, 9vw, 44px)',
          color: '#E8A33D',
          letterSpacing: '.08em',
          textTransform: 'uppercase',
          textAlign: 'center',
          lineHeight: 1.05,
          textShadow: '0 2px 12px rgba(0,0,0,.7)',
        }}>{nameEn}</h1>

        {nameBn && (
          <div style={{
            marginTop: 6,
            fontFamily: '"Hind Siliguri", system-ui, sans-serif',
            fontWeight: 600,
            fontSize: 'clamp(19px, 5.4vw, 26px)',
            color: '#E8A33D',
            opacity: .92,
            textAlign: 'center',
            lineHeight: 1.1,
          }}>{nameBn}</div>
        )}

        {/* Tagline / outlet name */}
        {outletName && (
          <div style={{
            marginTop: 12,
            fontFamily: lang === 'bn'
              ? '"Hind Siliguri", system-ui, sans-serif'
              : '"Cormorant Garamond", serif',
            fontStyle: lang === 'bn' ? 'normal' : 'italic',
            fontSize: 14,
            color: '#A89580',
            letterSpacing: '.05em',
            textAlign: 'center',
          }}>{outletName}</div>
        )}

        {/* Spacer pushes CTA to ~24% from bottom */}
        <div style={{ flex: 1 }} />

        {/* Star divider above CTA */}
        <div style={{ marginBottom: 18, opacity: .9 }}>
          <StarOrnament size={22} stroke="#C9A24B" />
        </div>

        {/* CTA — rectangular, NOT pill */}
        <button
          type="button"
          onClick={handleSeeMenu}
          style={{
            width: '100%',
            maxWidth: 460,
            height: 56,
            borderRadius: 12,
            background: '#E8A33D',
            color: '#1A1410',
            border: 'none',
            boxShadow: 'inset 0 0 0 1px #C9A24B, 0 14px 38px rgba(232,163,61,.32)',
            fontFamily: '"Cinzel", serif',
            fontWeight: 700,
            fontSize: 15,
            letterSpacing: '.18em',
            textTransform: 'uppercase',
            cursor: 'pointer',
            WebkitTapHighlightColor: 'transparent',
            display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 10,
            marginBottom: 'calc(8svh)',
          }}
        >
          <span>{t('seeMenu', lang)}</span>
          <span aria-hidden="true" style={{ fontSize: 18, lineHeight: 1 }}>↓</span>
        </button>
      </div>
    </section>
  )
}
