import React, { forwardRef } from 'react'
import { useTokens } from '../index.jsx'
import HearthItemCard from './HearthItemCard.jsx'
import { StarDivider } from './StarOrnament.jsx'
import { useLang, t } from './i18n.js'
import { categorySlug } from './HearthCategoryNav.jsx'

function CategoryHeader({ name, nameBn }) {
  const lang = useLang()
  const display = lang === 'bn' ? (nameBn || name) : name
  const sub = lang === 'bn' ? '' : (nameBn || '')
  return (
    <header style={{
      display: 'flex', flexDirection: 'column', alignItems: 'center',
      margin: '32px 0 18px',
      gap: 8,
    }}>
      <StarDivider />
      <h2 style={{
        margin: 0,
        fontFamily: lang === 'bn'
          ? '"Hind Siliguri", system-ui, sans-serif'
          : '"Cinzel", serif',
        fontWeight: 600,
        fontSize: 18,
        letterSpacing: lang === 'bn' ? '.02em' : '.3em',
        textTransform: lang === 'bn' ? 'none' : 'uppercase',
        color: '#E8A33D',
        textAlign: 'center',
        textShadow: '0 1px 0 rgba(0,0,0,.4)',
      }}>{display}</h2>
      {sub && (
        <div style={{
          fontFamily: '"Hind Siliguri", system-ui, sans-serif',
          fontSize: 13, color: '#A89580',
        }}>{sub}</div>
      )}
    </header>
  )
}

const HearthMenu = forwardRef(function HearthMenu(
  { itemsByCategory, categoryOrder, categoryBnMap, cart, onAdd, onRemove, onOpenDetail, hasFloatingCart },
  ref,
) {
  const T = useTokens()
  const lang = useLang()
  const noItems = categoryOrder.length === 0

  return (
    <section
      id="menu"
      ref={ref}
      style={{
        position: 'relative',
        background: T.bg,
        padding: '0 16px',
        paddingBottom: hasFloatingCart
          ? 'calc(env(safe-area-inset-bottom) + 110px)'
          : 'calc(env(safe-area-inset-bottom) + 40px)',
        minHeight: '60vh',
        scrollMarginTop: 64,
      }}
    >
      {noItems ? (
        <div style={{
          textAlign: 'center', padding: '80px 20px',
          fontFamily: '"Cormorant Garamond", serif',
          fontStyle: 'italic',
          color: '#A89580',
        }}>{t('noItems', lang)}</div>
      ) : (
        categoryOrder.map(cat => {
          const items = itemsByCategory[cat] || []
          if (!items.length) return null
          return (
            <div
              key={cat}
              id={categorySlug(cat)}
              data-hearth-category={cat}
              style={{ scrollMarginTop: 80 }}
            >
              <CategoryHeader name={cat} nameBn={categoryBnMap[cat]} />
              <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                {items.map((item, i) => (
                  <HearthItemCard
                    key={item.id}
                    item={item}
                    qty={cart[item.id] || 0}
                    onAdd={() => onAdd(item.id)}
                    onRemove={() => onRemove(item.id)}
                    onOpenDetail={() => onOpenDetail(item)}
                  />
                ))}
              </div>
            </div>
          )
        })
      )}
    </section>
  )
})

export default HearthMenu
