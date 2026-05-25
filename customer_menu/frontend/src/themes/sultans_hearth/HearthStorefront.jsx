import React, { useEffect, useMemo, useRef, useState } from 'react'
import { useTokens } from '../index.jsx'
import { cartCount, cartTotal } from '../../App.jsx'
import HearthHero from './HearthHero.jsx'
import HearthMenu from './HearthMenu.jsx'
import HearthCategoryNav, { categorySlug } from './HearthCategoryNav.jsx'
import HearthFloatingCart from './HearthFloatingCart.jsx'

const NAV_HEIGHT = 64 // approx height of the sticky category nav

function smoothScrollTo(el, offset = 0) {
  if (!el) return
  const reduced = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches
  const top = el.getBoundingClientRect().top + window.scrollY - offset
  window.scrollTo({ top, behavior: reduced ? 'auto' : 'smooth' })
}

// Group items by their categoryEn (falling back to category), preserving
// first-seen order. Also captures Bangla labels for each category.
function groupItems(items) {
  const order = []
  const byCat = {}
  const bnMap = {}
  for (const it of items) {
    const cat = it.categoryEn || it.category || 'General'
    if (!byCat[cat]) { byCat[cat] = []; order.push(cat) }
    byCat[cat].push(it)
    if (!bnMap[cat] && it.categoryBn) bnMap[cat] = it.categoryBn
  }
  return { order, byCat, bnMap }
}

export default function HearthStorefront({
  info,
  items,
  cart,
  onAdd,
  onRemove,
  onOpenCart,
  onOpenDetail,
  initialView = 'hero',
}) {
  const T = useTokens()
  const heroRef = useRef(null)
  const menuRef = useRef(null)
  const sectionRefs = useRef({})
  const [navVisible, setNavVisible] = useState(false)
  const [active, setActive] = useState('All')
  const { order, byCat, bnMap } = useMemo(() => groupItems(items || []), [items])

  // Build category list with synthetic "All" entry
  const allCategories = useMemo(() => ['All', ...order], [order])
  const itemsByCategory = useMemo(() => ({ All: items || [], ...byCat }), [items, byCat])

  // Auto-scroll to menu if entering at menu view (preserves App phase
  // semantics: the "menu" phase has the user past the welcome step).
  useEffect(() => {
    if (initialView === 'menu' && menuRef.current) {
      // Jump (not smooth) so the initial paint already shows menu.
      window.scrollTo({ top: menuRef.current.offsetTop - NAV_HEIGHT, behavior: 'auto' })
      setNavVisible(true)
    }
    // initialView only matters on mount.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  // Reveal sticky nav once hero leaves the viewport.
  useEffect(() => {
    if (!heroRef.current) return
    const el = heroRef.current
    const io = new IntersectionObserver(
      ([entry]) => setNavVisible(!entry.isIntersecting),
      { threshold: 0, rootMargin: `0px 0px -90% 0px` },
    )
    io.observe(el)
    return () => io.disconnect()
  }, [])

  // Harvest category section elements AND observe them. Combined into
  // one effect so refs are populated before observers attach.
  useEffect(() => {
    if (!menuRef.current) return
    const nodes = menuRef.current.querySelectorAll('[data-hearth-category]')
    if (!nodes.length) {
      sectionRefs.current = {}
      return
    }
    const map = {}
    nodes.forEach(n => { map[n.dataset.hearthCategory] = n })
    sectionRefs.current = map

    const io = new IntersectionObserver(entries => {
      const visible = entries.filter(e => e.isIntersecting)
      if (!visible.length) return
      visible.sort((a, b) => b.intersectionRatio - a.intersectionRatio)
      const cat = visible[0].target.dataset.hearthCategory
      if (cat) setActive(cat)
    }, {
      // Activate a category when its top is within the top quarter of the viewport.
      rootMargin: `-${NAV_HEIGHT + 12}px 0px -70% 0px`,
      threshold: [0, 0.25, 0.5, 1],
    })
    nodes.forEach(n => io.observe(n))
    return () => io.disconnect()
  }, [order.length])

  function handleSeeMenu() {
    smoothScrollTo(menuRef.current, NAV_HEIGHT - 4)
  }

  function handlePickCategory(cat) {
    setActive(cat)
    if (cat === 'All') {
      smoothScrollTo(menuRef.current, NAV_HEIGHT - 4)
      return
    }
    const el = sectionRefs.current[cat]
    if (el) smoothScrollTo(el, NAV_HEIGHT - 4)
  }

  const count = cartCount(cart)
  const total = cartTotal(cart, items || [])

  return (
    <div style={{ background: T.bg, color: T.ink, minHeight: '100svh' }}>
      <div ref={heroRef}>
        <HearthHero info={info} onSeeMenu={handleSeeMenu} />
      </div>

      <HearthCategoryNav
        categories={allCategories}
        categoryBnMap={bnMap}
        active={active}
        onPick={handlePickCategory}
        visible={navVisible}
        topOffset={0}
      />

      <HearthMenu
        ref={menuRef}
        itemsByCategory={itemsByCategory}
        categoryOrder={order}
        categoryBnMap={bnMap}
        cart={cart}
        onAdd={onAdd}
        onRemove={onRemove}
        onOpenDetail={onOpenDetail}
        hasFloatingCart={count > 0}
      />

      <HearthFloatingCart count={count} total={total} onTap={onOpenCart} />
    </div>
  )
}
