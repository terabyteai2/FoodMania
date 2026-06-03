import React from 'react'
import StarOrnament from './StarOrnament.jsx'
import { useLang } from './i18n.js'

export default function HearthError({ message }) {
  const lang = useLang()
  return (
    <div style={{
      minHeight: '100svh',
      background: '#1A1410',
      color: '#F4EEDF',
      display: 'flex', flexDirection: 'column',
      alignItems: 'center', justifyContent: 'center',
      gap: 20,
      padding: 28,
    }}>
      <div style={{
        position: 'relative',
        padding: '32px 28px',
        maxWidth: 380,
        background: '#2A1F1A',
        border: `1px solid #4A3A2E`,
        borderRadius: 14,
        textAlign: 'center',
      }}>
        <div aria-hidden="true" style={{
          position: 'absolute', inset: 8, borderRadius: 10,
          boxShadow: 'inset 0 0 0 1px rgba(201,162,75,.35)',
          pointerEvents: 'none',
        }} />
        <div style={{ display: 'inline-flex', marginBottom: 16 }}>
          <StarOrnament size={28} stroke="#E8A33D" />
        </div>
        <div style={{
          fontFamily: lang === 'bn'
            ? '"Hind Siliguri", system-ui, sans-serif'
            : '"Cinzel", serif',
          fontWeight: 600,
          fontSize: 14,
          letterSpacing: lang === 'bn' ? '.02em' : '.24em',
          textTransform: lang === 'bn' ? 'none' : 'uppercase',
          color: '#E8A33D',
          marginBottom: 10,
        }}>{lang === 'bn' ? 'কিছু একটা ভুল হয়েছে' : 'Something went wrong'}</div>
        <p style={{
          margin: 0,
          fontFamily: '"Cormorant Garamond", serif',
          fontStyle: 'italic',
          fontSize: 16, lineHeight: 1.5,
          color: '#A89580',
        }}>{message || (lang === 'bn' ? 'অনুগ্রহ করে আবার চেষ্টা করুন।' : 'Please try again in a moment.')}</p>
      </div>
    </div>
  )
}
