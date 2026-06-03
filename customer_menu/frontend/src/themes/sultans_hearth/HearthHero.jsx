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
	        minHeight: 520,
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

      {info?.logoUrl && (
        <img
          src={info.logoUrl}
          alt=""
          aria-hidden="true"
          style={{
            position: 'absolute',
            top: 'calc(env(safe-area-inset-top) + 16px)',
            left: 16,
            zIndex: 4,
            width: 58,
            height: 58,
            objectFit: 'cover',
            borderRadius: 16,
            border: `1px solid ${T.line}`,
            background: 'rgba(26,20,16,.55)',
            boxShadow: '0 8px 28px rgba(0,0,0,.36)',
          }}
        />
      )}

      {/* Content */}
      <div style={{
        position: 'absolute', inset: 0, zIndex: 3,
        display: 'flex', flexDirection: 'column', alignItems: 'center',
        justifyContent: 'flex-end',
        padding: '0 24px',
        paddingBottom: 'calc(env(safe-area-inset-bottom) + 32px)',
      }}>
        {/* Star divider above CTA */}
        <div style={{ marginBottom: 18, opacity: .9 }}>
          <StarOrnament size={22} stroke="#C9A24B" />
        </div>

        {/* CTA — rectangular, clearly visible, dark shadow for contrast */}
        <button
          type="button"
          onClick={handleSeeMenu}
          style={{
            width: '100%',
            maxWidth: 460,
            height: 58,
            borderRadius: 12,
            background: '#E8A33D',
            color: '#1A1410',
            border: 'none',
            boxShadow: '0 4px 32px rgba(0,0,0,.55), inset 0 0 0 1.5px #C9A24B',
            fontFamily: '"Cinzel", serif',
            fontWeight: 700,
            fontSize: 15,
            letterSpacing: '.18em',
            textTransform: 'uppercase',
            cursor: 'pointer',
            WebkitTapHighlightColor: 'transparent',
            display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 10,
          }}
        >
          <span>{t('seeMenu', lang)}</span>
          <span aria-hidden="true" style={{ fontSize: 18, lineHeight: 1 }}>↓</span>
        </button>
      </div>
    </section>
  )
}
