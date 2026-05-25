import React from 'react'
import { useTokens } from '../index.jsx'
import { generateReceipt, taka } from '../../App.jsx'
import StarOrnament, { StarDivider } from './StarOrnament.jsx'
import { useLang, t, pick } from './i18n.js'

export default function HearthSuccess({ order, info, cartItems, onBack }) {
  const T = useTokens()
  const lang = useLang()
  const totalItems = (cartItems || []).reduce((s, i) => s + (i.qty || 0), 0)

  return (
    <div style={{
      minHeight: '100svh',
      background: '#1A1410',
      color: '#F4EEDF',
      display: 'flex', flexDirection: 'column',
      fontFamily: '"Cormorant Garamond", serif',
    }}>
      <div style={{ flex: 1, overflowY: 'auto', padding: 'calc(env(safe-area-inset-top) + 40px) 20px 20px' }}>
        {/* Ornament + title */}
        <div style={{
          textAlign: 'center',
          background: `radial-gradient(120% 60% at 50% 0%, rgba(232,163,61,.16) 0%, transparent 70%)`,
          padding: '20px 0 28px',
          borderRadius: 16,
        }}>
          <div style={{ display: 'inline-flex', marginBottom: 12 }}>
            <StarOrnament size={36} stroke="#E8A33D" />
          </div>
          <h1 style={{
            margin: 0,
            fontFamily: lang === 'bn'
              ? '"Hind Siliguri", system-ui, sans-serif'
              : '"Cinzel", serif',
            fontWeight: 700,
            fontSize: 26,
            letterSpacing: lang === 'bn' ? '.02em' : '.22em',
            textTransform: lang === 'bn' ? 'none' : 'uppercase',
            color: '#E8A33D',
            textShadow: '0 1px 0 rgba(0,0,0,.5)',
          }}>{t('orderConfirmed', lang)}</h1>
          <div style={{
            marginTop: 8,
            fontStyle: 'italic',
            fontSize: 14, color: '#A89580',
          }}>
            {lang === 'bn' ? 'আপনার অর্ডার প্রস্তুত হচ্ছে।' : 'Your order is being prepared with care.'}
          </div>
        </div>

        {/* Order card */}
        <section style={{
          marginTop: 18,
          padding: '22px 20px',
          background: '#2A1F1A',
          border: `1px solid ${T.line}`,
          borderRadius: 16,
          textAlign: 'center',
          position: 'relative',
        }}>
          <div aria-hidden="true" style={{
            position: 'absolute', inset: 8, borderRadius: 12,
            boxShadow: 'inset 0 0 0 1px rgba(201,162,75,.28)',
            pointerEvents: 'none',
          }} />
          <div style={{
            fontFamily: lang === 'bn'
              ? '"Hind Siliguri", system-ui, sans-serif'
              : '"Cinzel", serif',
            fontSize: 11, letterSpacing: '.3em',
            textTransform: lang === 'bn' ? 'none' : 'uppercase',
            color: '#A89580',
          }}>{t('orderNumber', lang)}</div>
          {order?.serialNumber != null && (
            <div style={{
              marginTop: 4,
              fontFamily: '"Cinzel", serif',
              fontWeight: 700,
              fontSize: 64, lineHeight: 1,
              color: '#E8A33D',
              letterSpacing: '.02em',
            }}>#{order.serialNumber}</div>
          )}

          <div style={{ margin: '16px 0 12px' }}><StarDivider /></div>

          <div style={{
            display: 'flex', justifyContent: 'space-around', alignItems: 'flex-start', gap: 12,
          }}>
            <div>
              <div style={{
                fontFamily: '"Cinzel", serif',
                fontSize: 10, letterSpacing: '.24em',
                textTransform: 'uppercase',
                color: '#A89580',
              }}>{lang === 'bn' ? 'আইটেম' : 'Items'}</div>
              <div style={{
                marginTop: 4,
                fontFamily: '"Cinzel", serif',
                fontSize: 22, color: '#F4EEDF', fontWeight: 600,
              }}>{totalItems}</div>
            </div>
            <div style={{ width: 1, background: T.line, alignSelf: 'stretch' }} />
            <div>
              <div style={{
                fontFamily: '"Cinzel", serif',
                fontSize: 10, letterSpacing: '.24em',
                textTransform: 'uppercase',
                color: '#A89580',
              }}>{t('total', lang)}</div>
              <div style={{
                marginTop: 4,
                fontFamily: '"Cinzel", serif',
                fontSize: 22, color: '#E8A33D', fontWeight: 700,
                whiteSpace: 'nowrap',
              }}>{taka(order?.total || 0)}</div>
            </div>
          </div>
        </section>

        {info?.restaurantName && (
          <div style={{
            marginTop: 18, textAlign: 'center',
            fontStyle: 'italic',
            fontFamily: '"Cormorant Garamond", serif',
            fontSize: 14, color: '#A89580',
          }}>
            {info.restaurantName}{info.outletName ? ` · ${info.outletName}` : ''}
          </div>
        )}

        {/* Receipt */}
        {order && (
          <div style={{ marginTop: 22 }}>
            <button
              type="button"
              onClick={() => generateReceipt(order, info, cartItems)}
              style={{
                width: '100%',
                minHeight: 52,
                padding: '0 16px',
                background: 'transparent',
                color: '#F4EEDF',
                border: `1px solid #C9A24B`,
                borderRadius: 12,
                fontFamily: '"Cinzel", serif',
                fontSize: 13,
                letterSpacing: '.18em',
                textTransform: 'uppercase',
                cursor: 'pointer',
                display: 'flex', justifyContent: 'space-between', alignItems: 'center',
                WebkitTapHighlightColor: 'transparent',
              }}
            >
              <span style={{ display: 'inline-flex', alignItems: 'center', gap: 10 }}>
                <span style={{ fontSize: 16 }}>↓</span>
                <span>{lang === 'bn' ? 'রিসিট ডাউনলোড' : 'Download Receipt'}</span>
              </span>
              <span style={{ fontSize: 11, color: '#A89580', letterSpacing: '.2em' }}>PDF</span>
            </button>
          </div>
        )}
      </div>

      {/* Footer CTA */}
      <footer style={{
        flexShrink: 0,
        padding: '12px 18px calc(env(safe-area-inset-bottom) + 16px)',
        borderTop: `1px solid ${T.line}`,
        background: '#1A1410',
      }}>
        <button
          type="button"
          onClick={onBack}
          style={{
            width: '100%',
            height: 56,
            borderRadius: 12,
            background: '#E8A33D',
            color: '#1A1410',
            border: 'none',
            boxShadow: 'inset 0 0 0 1px #C9A24B, 0 14px 38px rgba(232,163,61,.32)',
            fontFamily: '"Cinzel", serif',
            fontWeight: 700,
            fontSize: 14,
            letterSpacing: '.18em',
            textTransform: 'uppercase',
            cursor: 'pointer',
            display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 10,
            WebkitTapHighlightColor: 'transparent',
          }}
        >
          <span>{t('backToMenu', lang)}</span>
          <span aria-hidden="true" style={{ fontSize: 18 }}>→</span>
        </button>
      </footer>
    </div>
  )
}
