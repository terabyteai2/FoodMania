import React from 'react'
import StarOrnament from './StarOrnament.jsx'
import { useLang, t } from './i18n.js'

export default function HearthLoading() {
  const lang = useLang()
  return (
    <div style={{
      minHeight: '100svh',
      background: '#1A1410',
      color: '#F4EEDF',
      display: 'flex', flexDirection: 'column',
      alignItems: 'center', justifyContent: 'center',
      gap: 18,
      padding: 24,
    }}>
      <StarOrnament size={42} stroke="#C9A24B" spin />
      <div style={{
        fontFamily: lang === 'bn'
          ? '"Hind Siliguri", system-ui, sans-serif'
          : '"Cinzel", serif',
        fontSize: 11,
        letterSpacing: lang === 'bn' ? '.04em' : '.36em',
        textTransform: lang === 'bn' ? 'none' : 'uppercase',
        color: '#A89580',
      }}>{t('loading', lang)}</div>
    </div>
  )
}
