import React, { useEffect, useRef, useState } from 'react'

const API_BASE = ''
const MENU_REFRESH_MS = 5000

// ── Theme — Terafoods design tokens (translated from admin_app design_rules.md)
const T = {
  primary:     '#F5C127',
  primaryDark: '#1C1A17',
  primarySoft: '#FEF1C5',
  bg:          '#F7F4EE',
  surface:     '#FFFFFF',
  ink:         '#1C1A17',
  muted:       '#888780',
  line:        '#E8E4DC',
  success:     '#3D7A5A',
  danger:      '#A32D2D',
  body:        'system-ui, -apple-system, "Inter", "Hind Siliguri", sans-serif',
}

// ── PDF receipt generator ─────────────────────────────────────────────────────
function pdfTk(n) { return 'Tk ' + Math.round(n).toLocaleString() }

async function generateReceipt(order, info, cartItems) {
  const { jsPDF } = await import('jspdf')
  const doc = new jsPDF({ unit: 'pt', format: 'a5' })
  const W = doc.internal.pageSize.getWidth()
  let y = 44

  doc.setFont('helvetica', 'bold')
  doc.setFontSize(20)
  doc.setTextColor(28, 26, 23)
  doc.text(info?.restaurantName || 'Restaurant', W / 2, y, { align: 'center' }); y += 24

  if (info?.outletName) {
    doc.setFont('helvetica', 'normal')
    doc.setFontSize(10)
    doc.setTextColor(136, 135, 128)
    doc.text(info.outletName, W / 2, y, { align: 'center' }); y += 16
  }

  doc.setFont('helvetica', 'normal')
  doc.setFontSize(9)
  doc.setTextColor(136, 135, 128)
  doc.text(new Date().toLocaleString('en-BD'), W / 2, y, { align: 'center' }); y += 22
  doc.setTextColor(28, 26, 23)

  doc.setDrawColor(245, 193, 39)
  doc.setLineWidth(0.75)
  doc.line(30, y, W - 30, y); y += 18

  doc.setFont('helvetica', 'bold')
  doc.setFontSize(8)
  doc.setTextColor(136, 135, 128)
  doc.text('ORDER NUMBER', W / 2, y, { align: 'center' }); y += 6

  doc.setFontSize(44)
  doc.setTextColor(245, 193, 39)
  doc.text(`#${order?.serialNumber ?? '-'}`, W / 2, y + 34, { align: 'center' }); y += 50
  doc.setTextColor(28, 26, 23)
  doc.line(30, y, W - 30, y); y += 20

  if (order?.customerName || order?.customerPhone || order?.deliveryAddress) {
    doc.setFont('helvetica', 'bold')
    doc.setFontSize(8)
    doc.setTextColor(136, 135, 128)
    doc.text('DELIVERY TO', 30, y); y += 12
    doc.setFont('helvetica', 'normal')
    doc.setFontSize(10)
    doc.setTextColor(28, 26, 23)
    if (order.customerName)  { doc.text(order.customerName, 30, y); y += 13 }
    if (order.customerPhone) { doc.text(order.customerPhone, 30, y); y += 13 }
    if (order.deliveryAddress) {
      const lines = doc.splitTextToSize(order.deliveryAddress, W - 60)
      doc.text(lines, 30, y); y += lines.length * 13 + 6
    }
    doc.line(30, y, W - 30, y); y += 14
  }

  doc.setFont('helvetica', 'bold')
  doc.setFontSize(8)
  doc.setTextColor(136, 135, 128)
  doc.text('ITEM', 30, y)
  doc.text('QTY', W / 2, y, { align: 'center' })
  doc.text('AMOUNT', W - 30, y, { align: 'right' })
  y += 4
  doc.setLineWidth(0.3)
  doc.setDrawColor(232, 228, 220)
  doc.line(30, y, W - 30, y); y += 12
  doc.setTextColor(28, 26, 23)

  doc.setFontSize(10)
  for (const item of cartItems) {
    doc.setFont('helvetica', 'normal')
    const nameLines = doc.splitTextToSize(item.name, W / 2 - 10)
    doc.text(nameLines, 30, y)
    doc.setTextColor(136, 135, 128)
    doc.text(`x${item.qty}`, W / 2, y, { align: 'center' })
    doc.setFont('helvetica', 'bold')
    doc.setTextColor(28, 26, 23)
    doc.text(pdfTk(item.price * item.qty), W - 30, y, { align: 'right' })
    y += nameLines.length > 1 ? nameLines.length * 13 + 6 : 20
    doc.setTextColor(28, 26, 23)
  }

  if (order?.notes) {
    y += 4
    doc.setFont('helvetica', 'italic')
    doc.setFontSize(9)
    doc.setTextColor(136, 135, 128)
    const noteLines = doc.splitTextToSize(`Note: ${order.notes}`, W - 60)
    doc.text(noteLines, 30, y); y += noteLines.length * 13 + 4
    doc.setTextColor(28, 26, 23)
  }

  y += 4
  doc.setLineWidth(0.75)
  doc.setDrawColor(245, 193, 39)
  doc.line(30, y, W - 30, y); y += 16
  doc.setFont('helvetica', 'bold')
  doc.setFontSize(13)
  doc.text('Total', 30, y)
  doc.setTextColor(28, 26, 23)
  doc.text(pdfTk(order?.total ?? 0), W - 30, y, { align: 'right' }); y += 24
  doc.setFont('helvetica', 'normal')
  doc.setFontSize(9)
  doc.setTextColor(136, 135, 128)
  doc.text('Cash on delivery', 30, y); y += 18

  doc.save(`receipt-${order?.serialNumber ?? order?.orderId?.slice(0, 8) ?? 'order'}.pdf`)
}

// ── Menu icon fallback (food-tone palette — same exception as admin's menu_image_view.dart)
const MENU_ICON_STYLES = {
  pizza:    { glyph: '🍕', color: '#E28714', bg: '#FFF3E0' },
  burger:   { glyph: '☰', color: '#E28714', bg: '#FFF3E0' },
  biryani:  { glyph: '◉', color: '#E28714', bg: '#FFF3E0' },
  rice:     { glyph: '◌', color: '#8a5a32', bg: '#F4ECDF' },
  curry:    { glyph: '◒', color: '#E28714', bg: '#FFF3E0' },
  soup:     { glyph: '∪', color: '#E88060', bg: '#FBE4DB' },
  vegetable:{ glyph: '✦', color: '#3D7A5A', bg: '#EAF4EE' },
  noodle:   { glyph: '≈', color: '#A32D2D', bg: '#FCEBEB' },
  bread:    { glyph: '▱', color: '#8a5a32', bg: '#F4ECDF' },
  chicken:  { glyph: '◔', color: '#E28714', bg: '#FFF3E0' },
  fish:     { glyph: '◇', color: '#2f7ea8', bg: '#E4F0F7' },
  beef:     { glyph: '◆', color: '#8a5a32', bg: '#F4ECDF' },
  snack:    { glyph: '✚', color: '#E28714', bg: '#FFF3E0' },
  fruit:    { glyph: '●', color: '#A32D2D', bg: '#FCEBEB' },
  dessert:  { glyph: '✸', color: '#A32D2D', bg: '#FCEBEB' },
  drink:    { glyph: '▯', color: '#2e9b79', bg: '#E2F3EC' },
  coffee:   { glyph: '☕', color: '#8a5a32', bg: '#F4ECDF' },
  tea:      { glyph: '◡', color: '#8a5a32', bg: '#F4ECDF' },
  breakfast:{ glyph: '◐', color: '#E28714', bg: '#FFF3E0' },
  set_meal: { glyph: '▦', color: '#E28714', bg: '#FFF3E0' },
  general:  { glyph: '✦', color: T.primary, bg: T.primarySoft },
}

function inferIconKey(item) {
  const explicit = String(item?.iconKey || '').trim().toLowerCase()
  if (explicit) return explicit
  const text = `${item?.name || ''} ${item?.category || ''}`.toLowerCase()
  const has = words => words.some(w => text.includes(w))
  if (has(['pizza'])) return 'pizza'
  if (has(['burger', 'sandwich'])) return 'burger'
  if (has(['biryani', 'biriyani', 'kacchi', 'tehari', 'polao', 'পোলাও', 'বিরিয়ানি'])) return 'biryani'
  if (has(['rice', 'fried rice', 'ভাত'])) return 'rice'
  if (has(['curry', 'masala', 'korma', 'bhuna', 'ভুনা', 'কারি'])) return 'curry'
  if (has(['soup'])) return 'soup'
  if (has(['salad', 'veg', 'vegetable', 'সবজি'])) return 'vegetable'
  if (has(['noodle', 'chowmein', 'chow mein'])) return 'noodle'
  if (has(['bread', 'naan', 'paratha', 'রুটি', 'পরোটা'])) return 'bread'
  if (has(['chicken', 'চিকেন', 'মুরগি'])) return 'chicken'
  if (has(['fish', 'prawn', 'shrimp', 'rui', 'ilish', 'মাছ'])) return 'fish'
  if (has(['beef', 'mutton', 'kebab', 'kabab', 'গরু', 'খাসি'])) return 'beef'
  if (has(['snack', 'samosa', 'roll', 'fries', 'singara', 'সমুচা'])) return 'snack'
  if (has(['fruit', 'juice'])) return 'fruit'
  if (has(['dessert', 'sweet', 'cake', 'firni', 'ice cream', 'মিষ্টি'])) return 'dessert'
  if (has(['drink', 'soda', 'lassi', 'borhani', 'beverage', 'পানীয়'])) return 'drink'
  if (has(['coffee'])) return 'coffee'
  if (has(['tea', 'cha', 'চা'])) return 'tea'
  if (has(['breakfast', 'omelet', 'omelette'])) return 'breakfast'
  if (has(['set meal', 'set_menu', 'combo', 'platter', 'থালি'])) return 'set_meal'
  return 'general'
}

function iconStyleFor(item) {
  return MENU_ICON_STYLES[inferIconKey(item)] || MENU_ICON_STYLES.general
}

function MenuFallbackIcon({ item, size = 32 }) {
  const style = iconStyleFor(item)
  return (
    <div style={{
      position: 'absolute', inset: 0, display: 'grid', placeItems: 'center',
      background: style.bg,
    }}>
      <span style={{ color: style.color, fontSize: size, lineHeight: 1, fontWeight: 500 }}>
        {style.glyph}
      </span>
    </div>
  )
}

// ── Demo data ─────────────────────────────────────────────────────────────────
const DEMO_INFO = {
  restaurantName: 'Helium',
  outletName: 'Main Outlet',
  bannerUrl: null,
  galleryImages: [],
  videoUrl: null,
}

const DEMO_ITEMS = [
  { id: 'kacchi',   name: 'Mutton Kacchi Biryani', category: 'Biryani',  price: 450, description: 'Slow-cooked basmati with marinated mutton, potato, saffron and ghee.', tag: "Chef's pick", imageUrl: null, iconKey: 'biryani' },
  { id: 'chickenb', name: 'Chicken Biryani',        category: 'Biryani',  price: 320, description: 'Aromatic basmati layered with spiced chicken thigh.',                  tag: null,          imageUrl: null, iconKey: 'biryani' },
  { id: 'beeft',    name: 'Beef Tehari',             category: 'Mains',   price: 280, description: 'Short-grain rice cooked with tender beef cubes and green chillies.',   tag: null,          imageUrl: null, iconKey: 'beef' },
  { id: 'pizza',    name: 'Margherita Pizza',        category: 'Mains',   price: 1299,description: 'Wood-fired crust, San Marzano tomato, fior di latte, basil.',          tag: 'Popular',     imageUrl: null, iconKey: 'pizza' },
  { id: 'samosa',   name: 'Keema Samosa',            category: 'Snacks',  price: 60,  description: 'Crisp pastry with spiced minced beef. Served with tamarind chutney.',  tag: null,          imageUrl: null, iconKey: 'snack' },
  { id: 'firni',    name: 'Saffron Firni',           category: 'Desserts',price: 120, description: 'Slow-cooked rice pudding with cardamom, saffron and pistachio.',       tag: null,          imageUrl: null, iconKey: 'dessert' },
  { id: 'borhani',  name: 'Borhani',                 category: 'Drinks',  price: 80,  description: 'Spiced yogurt drink with mint and roasted cumin.',                     tag: null,          imageUrl: null, iconKey: 'drink' },
  { id: 'kebab',    name: 'Sheekh Kebab',            category: 'Mains',   price: 240, description: 'Charcoal-grilled minced beef skewers with cumin and onion.',           tag: null,          imageUrl: null, iconKey: 'beef' },
]

// ── Helpers ───────────────────────────────────────────────────────────────────
function getOutletId() {
  const host = window.location.hostname.toLowerCase()
  const rootDomain = 'quickbytes.buzz'
  if (host.endsWith(`.${rootDomain}`)) {
    const subdomain = host.slice(0, -rootDomain.length - 1).split('.')[0]
    if (subdomain && subdomain !== 'www') return subdomain
  }

  const p = new URLSearchParams(window.location.search)
  if (p.get('demo') === '1') return '__demo__'
  if (p.get('outlet')) return p.get('outlet')
  const parts = window.location.pathname.split('/').filter(Boolean)
  const idx = parts.indexOf('menu')
  if (idx !== -1 && parts[idx + 1]) return parts[idx + 1]
  return parts[parts.length - 1] || null
}

function cartTotal(cart, items) {
  return Object.entries(cart).reduce((sum, [id, qty]) => {
    const item = items.find(i => i.id === id)
    return sum + (item ? item.price * qty : 0)
  }, 0)
}
function cartCount(cart) { return Object.values(cart).reduce((s, q) => s + q, 0) }
function taka(n) { return '৳' + Math.round(n).toLocaleString('en-BD') }

function buildMedia(item) {
  const media = []
  if (item.imageUrl) media.push({ type: 'image', url: item.imageUrl })
  if (item.videoUrl) media.push({ type: 'video', url: item.videoUrl })
  return media
}

function unwrapApi(res) {
  if (res?.ok === true) return res.data
  if (res?.error == null && Object.prototype.hasOwnProperty.call(res || {}, 'data')) {
    return res.data
  }
  throw new Error(res?.detail || res?.error || 'Could not load menu')
}

async function loadJson(path) {
  const res = await fetch(`${API_BASE}${path}`, { cache: 'no-store' })
  let body = null
  try { body = await res.json() } catch { /* fall through */ }
  if (!res.ok) {
    throw new Error(body?.detail || body?.error || `${res.status} ${res.statusText}: ${path}`)
  }
  return unwrapApi(body)
}

// ═══════════════════════════════════════════════════════════════════════════════
export default function App() {
  const outletId = getOutletId()
  const [phase, setPhase]       = useState('loading')   // loading | main | cart | success | error
  const [info, setInfo]         = useState(null)
  const [items, setItems]       = useState([])
  const [cart, setCart]         = useState({})
  const [activeCategory, setCat]= useState('All')
  const [note, setNote]         = useState('')
  const [customerName, setName] = useState('')
  const [customerPhone, setPhone] = useState('')
  const [coords, setCoords]     = useState(null)        // { lat, lng, accuracy }
  const [geoStatus, setGeo]     = useState('idle')      // idle | locating | ok | denied | error
  const [submitting, setSub]    = useState(false)
  const [errorMsg, setErr]      = useState('')
  const [orderRef, setOrderRef] = useState(null)
  const [lightbox, setLightbox] = useState(null)
  const [lastCart, setLastCart] = useState([])

  useEffect(() => {
    if (!outletId) { setPhase('error'); setErr('Invalid menu link.'); return }
    if (outletId === '__demo__') {
      setInfo(DEMO_INFO); setItems(DEMO_ITEMS); setPhase('main'); return
    }
    let cancelled = false

    const refresh = async (silent = false) => {
      try {
        const [infoData, menuData] = await Promise.all([
          loadJson(`/customer/${outletId}/info`),
          loadJson(`/customer/${outletId}/menu`),
        ])
        if (cancelled) return
        setInfo(infoData)
        setItems(menuData)
        setCart(current => {
          const liveIds = new Set(menuData.map(item => item.id))
          return Object.fromEntries(Object.entries(current).filter(([id]) => liveIds.has(id)))
        })
        setErr('')
        setPhase(current => (current === 'loading' || current === 'error') ? 'main' : current)
      } catch (e) {
        if (cancelled || silent) return
        setPhase('error')
        setErr(e.message || 'Could not load menu.')
      }
    }

    refresh(false)
    const timer = window.setInterval(() => refresh(true), MENU_REFRESH_MS)
    const onVisible = () => { if (document.visibilityState === 'visible') refresh(true) }
    document.addEventListener('visibilitychange', onVisible)
    return () => {
      cancelled = true
      window.clearInterval(timer)
      document.removeEventListener('visibilitychange', onVisible)
    }
  }, [outletId])

  const categories = ['All', ...new Set(items.map(i => i.category).filter(Boolean))]
  const visible = activeCategory === 'All' ? items : items.filter(i => i.category === activeCategory)

  function add(id) { setCart(c => ({ ...c, [id]: (c[id] || 0) + 1 })) }
  function rem(id) {
    setCart(c => {
      const n = { ...c }
      if ((n[id] || 0) <= 1) delete n[id]; else n[id]--
      return n
    })
  }

  function requestLocation() {
    if (!('geolocation' in navigator)) {
      setGeo('error'); return
    }
    setGeo('locating')
    navigator.geolocation.getCurrentPosition(
      pos => {
        setCoords({ lat: pos.coords.latitude, lng: pos.coords.longitude, accuracy: pos.coords.accuracy })
        setGeo('ok')
      },
      err => {
        setGeo(err.code === err.PERMISSION_DENIED ? 'denied' : 'error')
      },
      { enableHighAccuracy: true, timeout: 15000, maximumAge: 60000 },
    )
  }

  async function placeOrder() {
    setSub(true)
    if (outletId === '__demo__') {
      await new Promise(r => setTimeout(r, 800))
      const demoCartItems = Object.entries(cart).map(([id, qty]) => {
        const item = items.find(i => i.id === id)
        return { name: item.name, qty, price: item.price }
      })
      setLastCart(demoCartItems)
      setOrderRef({
        serialNumber: Math.floor(Math.random() * 90) + 10,
        total: cartTotal(cart, items),
        orderId: 'demo-order-001',
        notes: note || null,
        customerName: customerName.trim(),
        customerPhone: customerPhone.trim(),
        deliveryAddress: coords ? `Lat ${coords.lat.toFixed(5)}, Lng ${coords.lng.toFixed(5)}` : null,
      })
      setPhase('success'); setSub(false)
      return
    }
    try {
      const orderItems = Object.entries(cart).map(([id, qty]) => {
        const item = items.find(i => i.id === id)
        return { menuItemId: id, name: item.name, qty, price: item.price }
      })
      const res = await fetch(`${API_BASE}/customer/${outletId}/orders`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          items: orderItems,
          customerName: customerName.trim(),
          customerPhone: customerPhone.trim(),
          latitude: coords.lat,
          longitude: coords.lng,
          note: note || null,
        }),
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data.detail || data.error || 'Order failed')
      const orderData = unwrapApi(data)
      setLastCart(Object.entries(cart).map(([id, qty]) => {
        const item = items.find(i => i.id === id)
        return { name: item.name, qty, price: item.price }
      }))
      setOrderRef(orderData)
      setPhase('success')
    } catch (e) { alert(e.message || 'Could not place order.') }
    finally { setSub(false) }
  }

  if (phase === 'loading') return <LoadingScreen />
  if (phase === 'error')   return <ErrorScreen message={errorMsg} />
  if (phase === 'success') return (
    <SuccessScreen
      order={orderRef} info={info} cartItems={lastCart}
      onBack={() => {
        setCart({}); setLastCart([]); setNote('')
        setName(''); setPhone(''); setCoords(null); setGeo('idle')
        setPhase('main')
      }}
    />
  )
  if (phase === 'cart') return (
    <CartScreen
      cart={cart} items={items} note={note} onNote={setNote}
      onAdd={add} onRemove={rem} onBack={() => setPhase('main')}
      onPlace={placeOrder} submitting={submitting} info={info}
      customerName={customerName} onName={setName}
      customerPhone={customerPhone} onPhone={setPhone}
      coords={coords} geoStatus={geoStatus} onLocate={requestLocation}
    />
  )

  return (
    <>
      <MainPage
        info={info} items={visible} allItems={items} cart={cart}
        categories={categories} activeCategory={activeCategory}
        onCategory={setCat} onAdd={add} onRemove={rem}
        onOpenCart={() => setPhase('cart')}
        onOpenDetail={item => setLightbox({ item })}
      />
      {lightbox && (
        <ItemDetailSheet
          item={lightbox.item}
          qty={cart[lightbox.item.id] || 0}
          onAdd={() => add(lightbox.item.id)}
          onRemove={() => rem(lightbox.item.id)}
          onClose={() => setLightbox(null)}
        />
      )}
    </>
  )
}

// ═══════════════════════════════════════════════════════════════════════════════
function LoadingScreen() {
  return (
    <div style={{
      minHeight: '100vh', display: 'flex', flexDirection: 'column',
      alignItems: 'center', justifyContent: 'center',
      background: T.bg, padding: 24, fontFamily: T.body,
    }}>
      <div style={{
        width: 40, height: 40,
        border: `0.5px solid ${T.line}`,
        borderTop: `2px solid ${T.primary}`,
        borderRadius: 999,
        animation: 'spin .9s linear infinite',
      }} />
      <p style={{ color: T.muted, marginTop: 20, fontWeight: 500, letterSpacing: 2, fontSize: 11, textTransform: 'uppercase' }}>
        Loading…
      </p>
    </div>
  )
}

function ErrorScreen({ message }) {
  return (
    <div style={{
      minHeight: '100vh', display: 'flex', flexDirection: 'column',
      alignItems: 'center', justifyContent: 'center',
      background: T.bg, padding: 24, fontFamily: T.body,
    }}>
      <div style={{ fontSize: 42, marginBottom: 16 }}>🍽️</div>
      <p style={{ color: T.danger, fontSize: 16, textAlign: 'center', padding: '0 32px', fontWeight: 500 }}>
        {message}
      </p>
    </div>
  )
}

// ── Hero (compact, ~50vh — replaces standalone Welcome screen) ────────────────
function Hero({ info }) {
  const videoRef = useRef(null)
  const [slide, setSlide] = useState(0)
  const touchX = useRef(null)
  const gallery = info?.galleryImages || []
  const hasVideo = !!info?.videoUrl
  const hasGallery = !hasVideo && gallery.length > 0
  const hasBanner = !hasVideo && !hasGallery && !!info?.bannerUrl
  const hasMedia = hasVideo || hasGallery || hasBanner

  useEffect(() => {
    if (!hasGallery || gallery.length < 2) return
    const id = setInterval(() => setSlide(i => (i + 1) % gallery.length), 4000)
    return () => clearInterval(id)
  }, [hasGallery, gallery.length])

  useEffect(() => {
    if (videoRef.current) videoRef.current.play().catch(() => {})
  }, [info?.videoUrl])

  function onTouchStart(e) { touchX.current = e.touches[0].clientX }
  function onTouchEnd(e) {
    if (touchX.current === null || !hasGallery) return
    const dx = e.changedTouches[0].clientX - touchX.current
    if (dx < -48) setSlide(i => (i + 1) % gallery.length)
    if (dx > 48)  setSlide(i => (i - 1 + gallery.length) % gallery.length)
    touchX.current = null
  }

  return (
    <div
      style={{
        width: '100%', height: '50vh', minHeight: 280, maxHeight: 460,
        position: 'relative', overflow: 'hidden',
        background: T.primaryDark, flexShrink: 0,
      }}
      onTouchStart={hasGallery ? onTouchStart : undefined}
      onTouchEnd={hasGallery ? onTouchEnd : undefined}
    >
      {hasVideo ? (
        <video ref={videoRef} src={info.videoUrl} autoPlay muted loop playsInline
          style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover' }} />
      ) : hasGallery ? (
        gallery.map((url, i) => (
          <img key={url} src={url} alt="" style={{
            position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover',
            opacity: i === slide ? 1 : 0, transition: 'opacity 0.7s ease',
          }} />
        ))
      ) : hasBanner ? (
        <img src={info.bannerUrl} alt=""
          style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover' }} />
      ) : (
        <div style={{
          position: 'absolute', inset: 0,
          background: `radial-gradient(120% 80% at 50% 20%, ${T.primary} 0%, ${T.primaryDark} 70%)`,
        }} />
      )}

      <div style={{
        position: 'absolute', inset: 0,
        background: hasMedia
          ? 'linear-gradient(180deg, rgba(28,26,23,.35) 0%, rgba(28,26,23,.15) 45%, rgba(28,26,23,.85) 100%)'
          : 'transparent',
      }} />

      <div style={{
        position: 'relative', height: '100%',
        display: 'flex', flexDirection: 'column', justifyContent: 'flex-end',
        padding: '20px 22px 26px',
      }}>
        <div style={{
          width: 56, height: 56, borderRadius: 999,
          background: T.primary, color: T.primaryDark,
          display: 'grid', placeItems: 'center',
          fontSize: 28, fontWeight: 500, lineHeight: 1,
          marginBottom: 12,
        }}>
          {info?.restaurantName?.[0]?.toUpperCase() || 'R'}
        </div>
        <div style={{
          fontSize: 32, color: T.surface, lineHeight: 1.05, fontWeight: 500,
          letterSpacing: '-.01em',
        }}>{info?.restaurantName || 'Restaurant'}</div>
        {info?.outletName && (
          <div style={{ marginTop: 6, fontSize: 13, color: T.line, fontWeight: 400 }}>
            {info.outletName} · Online delivery
          </div>
        )}
        {hasGallery && gallery.length > 1 && (
          <div style={{ display: 'flex', gap: 6, marginTop: 14 }}>
            {gallery.map((_, i) => (
              <div key={i} onClick={() => setSlide(i)} style={{
                width: i === slide ? 18 : 6, height: 6, borderRadius: 999,
                background: i === slide ? T.primary : 'rgba(247,244,238,.45)',
                transition: 'all 0.3s', cursor: 'pointer',
              }} />
            ))}
          </div>
        )}
      </div>
    </div>
  )
}

// ── Main Page (hero + scrollable menu — single page) ──────────────────────────
function MainPage({ info, items, allItems, cart, categories, activeCategory, onCategory, onAdd, onRemove, onOpenCart, onOpenDetail }) {
  const count = cartCount(cart)
  const total = cartTotal(cart, allItems)

  return (
    <div style={{ minHeight: '100vh', background: T.bg, fontFamily: T.body, color: T.ink }}>
      <Hero info={info} />

      {/* Section header */}
      <div style={{ padding: '20px 16px 6px' }}>
        <div style={{ fontSize: 11, color: T.muted, fontWeight: 500, letterSpacing: '.18em', textTransform: 'uppercase' }}>
          OUR MENU
        </div>
        <div style={{ fontSize: 22, color: T.ink, fontWeight: 500, marginTop: 4, lineHeight: 1.1 }}>
          Browse and order for delivery
        </div>
      </div>

      {/* Category tabs */}
      <div style={{
        display: 'flex', padding: '14px 16px 0',
        overflowX: 'auto', scrollbarWidth: 'none', WebkitOverflowScrolling: 'touch',
        flexShrink: 0,
      }}>
        {categories.map(cat => {
          const active = cat === activeCategory
          return (
            <button key={cat}
              onClick={() => onCategory(cat)}
              style={{
                flex: '0 0 auto', padding: '8px 14px', marginRight: 8, height: 32,
                background: active ? T.primaryDark : T.surface,
                color: active ? T.surface : T.ink,
                border: `0.5px solid ${active ? T.primaryDark : T.line}`,
                borderRadius: 999,
                cursor: 'pointer',
                fontFamily: T.body, fontSize: 13, fontWeight: 500,
                whiteSpace: 'nowrap',
                WebkitTapHighlightColor: 'transparent',
              }}>
              {cat}
            </button>
          )
        })}
      </div>

      {/* 2-col grid */}
      <div style={{
        padding: '14px 12px',
        paddingBottom: count > 0 ? 110 : 32,
        display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10,
        alignContent: 'start',
      }}>
        {items.length === 0 ? (
          <div style={{
            gridColumn: '1 / -1', textAlign: 'center',
            color: T.muted, padding: '60px 0', fontStyle: 'italic', fontWeight: 400,
          }}>
            No items available
          </div>
        ) : (
          items.map((item, i) => (
            <MenuCard
              key={item.id}
              item={item}
              qty={cart[item.id] || 0}
              onAdd={() => onAdd(item.id)}
              onRemove={() => onRemove(item.id)}
              onOpenDetail={() => onOpenDetail(item)}
              delay={i}
            />
          ))
        )}
      </div>

      {count > 0 && (
        <div className="slide-up" onClick={onOpenCart} style={{
          position: 'fixed', left: 16, right: 16, bottom: 16, zIndex: 30,
          background: T.primary, color: T.primaryDark, padding: '14px 18px', borderRadius: 12,
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          boxShadow: '0 4px 8px rgba(28,26,23,.18)',
          cursor: 'pointer', fontWeight: 500,
          WebkitTapHighlightColor: 'transparent',
        }}>
          <span style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <span style={{
              width: 26, height: 26, borderRadius: 999, background: T.primaryDark, color: T.primary,
              display: 'grid', placeItems: 'center', fontSize: 13, fontWeight: 500,
              flexShrink: 0,
            }}>{count}</span>
            <span style={{ fontSize: 15, fontWeight: 500 }}>Checkout</span>
          </span>
          <span style={{ fontSize: 15, fontWeight: 500 }}>{taka(total)} →</span>
        </div>
      )}
    </div>
  )
}

// ── Menu Card (2-col grid) ────────────────────────────────────────────────────
function MenuCard({ item, qty, onAdd, onRemove, onOpenDetail, delay }) {
  const hasImage = !!item.imageUrl
  return (
    <div
      className="fade-up"
      style={{
        background: T.surface, borderRadius: 12, overflow: 'hidden',
        border: `0.5px solid ${T.line}`,
        display: 'flex', flexDirection: 'column',
        minHeight: 0,
        animationDelay: `${Math.min(delay * 0.04, 0.3)}s`,
        cursor: 'pointer',
        WebkitTapHighlightColor: 'transparent',
      }}
      onClick={onOpenDetail}
    >
      <div style={{
        width: '100%', aspectRatio: '1.28 / 1', maxHeight: 110, position: 'relative',
        background: T.bg,
        ...(hasImage ? {
          backgroundImage: `url(${item.imageUrl})`,
          backgroundSize: 'cover', backgroundPosition: 'center',
        } : {}),
        flexShrink: 0,
      }}>
        {!hasImage && <MenuFallbackIcon item={item} size={32} />}
        {item.tag && (
          <span style={{
            position: 'absolute', top: 8, left: 8,
            padding: '3px 8px', background: T.primary, color: T.primaryDark,
            fontSize: 10, letterSpacing: '.12em', borderRadius: 8, fontWeight: 500,
            whiteSpace: 'nowrap', textTransform: 'uppercase',
          }}>★ {item.tag}</span>
        )}
        <div style={{ position: 'absolute', bottom: 8, right: 8 }}
          onClick={e => e.stopPropagation()}>
          {qty === 0 ? (
            <button onClick={onAdd} style={{
              width: 32, height: 32, borderRadius: 999, border: 'none',
              background: T.primary, color: T.primaryDark, fontSize: 20, lineHeight: 1,
              cursor: 'pointer', fontWeight: 500, display: 'grid', placeItems: 'center',
              boxShadow: '0 4px 8px rgba(28,26,23,.18)',
              WebkitTapHighlightColor: 'transparent',
            }}>+</button>
          ) : (
            <div style={{
              display: 'flex', alignItems: 'center',
              background: T.surface, borderRadius: 999,
              border: `0.5px solid ${T.line}`, height: 32,
              fontSize: 13, fontWeight: 500,
            }}>
              <span onClick={onRemove} style={{ padding: '0 10px', cursor: 'pointer', color: T.muted, lineHeight: '32px' }}>−</span>
              <span style={{ padding: '0 2px', color: T.ink, fontWeight: 500, lineHeight: '32px' }}>{qty}</span>
              <span onClick={onAdd} style={{ padding: '0 10px', cursor: 'pointer', color: T.primaryDark, lineHeight: '32px' }}>+</span>
            </div>
          )}
        </div>
      </div>

      <div style={{ padding: '10px 12px 12px', display: 'flex', flexDirection: 'column', flex: 1, minHeight: 72 }}>
        <div style={{
          fontSize: 14, fontWeight: 500, lineHeight: 1.2, color: T.ink,
          overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
        }}>{item.name}</div>
        {item.description && (
          <div style={{
            fontSize: 11, color: T.muted, marginTop: 4, fontWeight: 400,
            overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
          }}>{item.description}</div>
        )}
        <div style={{ flex: 1 }} />
        <div style={{ fontSize: 14, color: T.primaryDark, marginTop: 6, fontWeight: 500 }}>
          {taka(item.price)}
        </div>
      </div>
    </div>
  )
}

// ── Item Detail Sheet ─────────────────────────────────────────────────────────
function ItemDetailSheet({ item, qty, onAdd, onRemove, onClose }) {
  const media = buildMedia(item)
  const videoRef = useRef(null)
  const current = media[0]

  useEffect(() => {
    if (videoRef.current) videoRef.current.play().catch(() => {})
  }, [item.id])

  useEffect(() => {
    function onKey(e) { if (e.key === 'Escape') onClose() }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [onClose])

  return (
    <div
      className="fade-in"
      style={{
        position: 'fixed', inset: 0, zIndex: 50,
        background: 'rgba(28,26,23,.5)',
        display: 'flex', alignItems: 'flex-end',
      }}
      onClick={e => { if (e.target === e.currentTarget) onClose() }}
    >
      <div
        className="slide-up"
        style={{
          width: '100%', maxHeight: '90vh',
          background: T.surface,
          borderTopLeftRadius: 12, borderTopRightRadius: 12,
          boxShadow: '0 0 8px rgba(28,26,23,.20)',
          display: 'flex', flexDirection: 'column', overflow: 'hidden',
          border: `0.5px solid ${T.line}`, borderBottom: 'none',
        }}
      >
        <div style={{
          height: 200, position: 'relative', flexShrink: 0,
          background: T.bg,
          ...(current?.type === 'image' ? {
            backgroundImage: `url(${current.url})`,
            backgroundSize: 'cover', backgroundPosition: 'center',
          } : {}),
        }}>
          {current?.type === 'video' && (
            <video ref={videoRef} src={current.url} autoPlay muted loop playsInline
              style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover' }} />
          )}
          <div style={{
            position: 'absolute', top: 10, left: '50%', transform: 'translateX(-50%)',
            width: 44, height: 4, borderRadius: 999, background: 'rgba(255,255,255,.7)',
          }} />
          <button onClick={onClose} style={{
            position: 'absolute', top: 14, right: 14,
            width: 32, height: 32, borderRadius: 999,
            background: T.surface, color: T.ink, border: `0.5px solid ${T.line}`,
            fontSize: 16, cursor: 'pointer',
            display: 'grid', placeItems: 'center',
            WebkitTapHighlightColor: 'transparent',
          }}>✕</button>
          {!current && <MenuFallbackIcon item={item} size={54} />}
        </div>

        <div style={{ flex: 1, overflowY: 'auto', padding: '18px 20px 8px' }}>
          <div style={{ fontSize: 22, color: T.ink, fontWeight: 500, lineHeight: 1.15 }}>
            {item.name}
          </div>
          {item.description && (
            <div style={{ marginTop: 10, fontSize: 13, color: T.muted, lineHeight: 1.55, fontWeight: 400 }}>
              {item.description}
            </div>
          )}
          <div style={{ fontSize: 18, color: T.primaryDark, marginTop: 12, fontWeight: 500 }}>
            {taka(item.price)}
          </div>
          <div style={{ height: 80 }} />
        </div>

        <div style={{
          padding: '14px 18px 24px',
          borderTop: `0.5px solid ${T.line}`,
          background: T.surface, flexShrink: 0,
          display: 'flex', gap: 10, alignItems: 'center',
        }}>
          {qty === 0 ? (
            <button onClick={onAdd} style={{
              flex: 1, height: 50, background: T.primary, color: T.primaryDark, border: 'none', borderRadius: 12,
              fontSize: 15, fontWeight: 500,
              cursor: 'pointer',
              display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '0 16px',
              WebkitTapHighlightColor: 'transparent',
            }}>
              <span>Add to Order</span>
              <span>{taka(item.price)}</span>
            </button>
          ) : (
            <>
              <div style={{
                display: 'flex', alignItems: 'center', height: 50,
                border: `0.5px solid ${T.line}`, borderRadius: 12,
                fontSize: 16, flexShrink: 0, background: T.surface,
              }}>
                <span onClick={onRemove} style={{ padding: '0 14px', color: T.muted, cursor: 'pointer', fontSize: 22 }}>−</span>
                <span style={{ padding: '0 4px', color: T.ink, fontWeight: 500 }}>{qty}</span>
                <span onClick={onAdd} style={{ padding: '0 14px', color: T.primaryDark, cursor: 'pointer', fontSize: 22 }}>+</span>
              </div>
              <button onClick={onAdd} style={{
                flex: 1, height: 50, background: T.primary, color: T.primaryDark, border: 'none', borderRadius: 12,
                fontSize: 14, fontWeight: 500,
                cursor: 'pointer',
                display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '0 16px',
                WebkitTapHighlightColor: 'transparent',
              }}>
                <span>Add More</span>
                <span>{taka(item.price * (qty + 1))}</span>
              </button>
            </>
          )}
        </div>
      </div>
    </div>
  )
}

// ── Cart Screen ───────────────────────────────────────────────────────────────
function CartScreen({
  cart, items, note, onNote, onAdd, onRemove, onBack, onPlace, submitting, info,
  customerName, onName, customerPhone, onPhone, coords, geoStatus, onLocate,
}) {
  const cartItems = Object.entries(cart)
    .map(([id, qty]) => ({ ...items.find(i => i.id === id), qty }))
    .filter(Boolean)
  const total = cartTotal(cart, items)

  const nameOk = customerName.trim().length > 0
  const phoneOk = customerPhone.trim().length >= 6
  const canPlace = nameOk && phoneOk && !!coords && !submitting

  return (
    <div style={{ minHeight: '100vh', background: T.bg, display: 'flex', flexDirection: 'column', fontFamily: T.body, color: T.ink }}>
      <div style={{
        padding: '50px 16px 14px', borderBottom: `0.5px solid ${T.line}`, flexShrink: 0,
        display: 'flex', alignItems: 'center', gap: 12,
        background: T.surface, position: 'sticky', top: 0, zIndex: 10,
      }}>
        <button onClick={onBack} style={{
          width: 38, height: 38, borderRadius: 999, flexShrink: 0,
          background: T.surface, color: T.ink, border: `0.5px solid ${T.line}`,
          fontSize: 18, cursor: 'pointer', display: 'grid', placeItems: 'center',
          WebkitTapHighlightColor: 'transparent',
        }}>←</button>
        <div style={{ minWidth: 0 }}>
          <div style={{ fontSize: 18, color: T.ink, fontWeight: 500, lineHeight: 1.1 }}>
            Your Order
          </div>
          {info?.restaurantName && (
            <div style={{ fontSize: 11, color: T.muted, marginTop: 3, fontWeight: 400 }}>
              {info.restaurantName}{info.outletName ? ` · ${info.outletName}` : ''}
            </div>
          )}
        </div>
      </div>

      <div style={{ flex: 1, overflowY: 'auto', padding: '6px 16px 180px' }}>
        {cartItems.map((item, i) => (
          <div key={item.id} className="fade-up" style={{
            padding: '14px 0',
            borderBottom: i === cartItems.length - 1 ? 'none' : `0.5px solid ${T.line}`,
            display: 'flex', gap: 12, alignItems: 'flex-start',
            animationDelay: `${i * 0.05}s`,
          }}>
            <div style={{
              width: 56, height: 56, borderRadius: 8, flexShrink: 0,
              backgroundColor: T.surface, position: 'relative', overflow: 'hidden',
              border: `0.5px solid ${T.line}`,
              ...(item.imageUrl ? {
                backgroundImage: `url(${item.imageUrl})`,
                backgroundSize: 'cover', backgroundPosition: 'center',
              } : {}),
            }}>
              {!item.imageUrl && <MenuFallbackIcon item={item} size={24} />}
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 14, color: T.ink, fontWeight: 500, lineHeight: 1.2 }}>
                {item.name}
              </div>
              <div style={{ fontSize: 11, color: T.muted, marginTop: 2, fontWeight: 400 }}>
                {taka(item.price)} each
              </div>
              <div style={{ marginTop: 8, display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                <div style={{
                  display: 'flex', alignItems: 'center',
                  border: `0.5px solid ${T.line}`, borderRadius: 999, height: 28,
                  fontSize: 13, background: T.surface,
                }}>
                  <span onClick={() => onRemove(item.id)} style={{ padding: '0 10px', cursor: 'pointer', color: T.muted }}>−</span>
                  <span style={{ padding: '0 2px', color: T.ink, fontWeight: 500 }}>{item.qty}</span>
                  <span onClick={() => onAdd(item.id)} style={{ padding: '0 10px', cursor: 'pointer', color: T.primaryDark }}>+</span>
                </div>
                <div style={{ fontSize: 14, color: T.primaryDark, whiteSpace: 'nowrap', fontWeight: 500 }}>
                  {taka(item.price * item.qty)}
                </div>
              </div>
            </div>
          </div>
        ))}

        {/* Delivery details */}
        <div style={{
          marginTop: 18, padding: 14, background: T.surface,
          borderRadius: 12, border: `0.5px solid ${T.line}`,
        }}>
          <div style={{ fontSize: 11, color: T.muted, fontWeight: 500, letterSpacing: '.18em', textTransform: 'uppercase' }}>
            Delivery details
          </div>

          <div style={{ marginTop: 12 }}>
            <Label>Name</Label>
            <input
              type="text"
              value={customerName}
              onChange={e => onName(e.target.value)}
              placeholder="Your name"
              style={fieldStyle}
            />
          </div>

          <div style={{ marginTop: 10 }}>
            <Label>Phone</Label>
            <input
              type="tel"
              inputMode="numeric"
              value={customerPhone}
              onChange={e => onPhone(e.target.value)}
              placeholder="01XXXXXXXXX"
              style={fieldStyle}
            />
          </div>

          <div style={{ marginTop: 10 }}>
            <Label>Location</Label>
            <button
              type="button"
              onClick={onLocate}
              disabled={geoStatus === 'locating'}
              style={{
                width: '100%', height: 42, padding: '0 14px',
                background: coords ? T.primarySoft : T.surface,
                color: T.ink, border: `0.5px solid ${coords ? T.primary : T.line}`,
                borderRadius: 12, fontSize: 13, fontWeight: 500, cursor: 'pointer',
                display: 'flex', alignItems: 'center', justifyContent: 'space-between',
                WebkitTapHighlightColor: 'transparent',
              }}>
              <span>📍 {coords ? 'Location captured' : geoStatus === 'locating' ? 'Locating…' : 'Share my location'}</span>
              {coords && (
                <span style={{ fontSize: 11, color: T.muted, fontWeight: 400 }}>
                  ±{Math.round(coords.accuracy)}m
                </span>
              )}
            </button>
            {geoStatus === 'denied' && (
              <div style={{ marginTop: 6, fontSize: 11, color: T.danger, fontWeight: 400 }}>
                Location is required for delivery — please enable permission and retry.
              </div>
            )}
            {geoStatus === 'error' && (
              <div style={{ marginTop: 6, fontSize: 11, color: T.danger, fontWeight: 400 }}>
                Could not get your location. Please retry.
              </div>
            )}
          </div>

          <div style={{ marginTop: 12 }}>
            <Label>Note for kitchen (optional)</Label>
            <textarea
              style={{ ...fieldStyle, minHeight: 64, resize: 'none', fontFamily: T.body }}
              placeholder="e.g. no onion, extra spicy"
              value={note}
              onChange={e => onNote(e.target.value)}
              rows={3}
            />
          </div>

          <div style={{
            marginTop: 12, padding: '8px 10px', borderRadius: 8,
            background: T.bg, border: `0.5px solid ${T.line}`,
            fontSize: 11, color: T.muted, fontWeight: 400,
          }}>
            💵 Payment: Cash on delivery
          </div>
        </div>

        {/* Total */}
        <div style={{ marginTop: 14, padding: '14px 0', borderTop: `0.5px solid ${T.line}` }}>
          <div style={{
            display: 'flex', justifyContent: 'space-between', alignItems: 'baseline',
          }}>
            <span style={{ fontSize: 15, color: T.ink, fontWeight: 500 }}>Total</span>
            <span style={{ fontSize: 20, color: T.primaryDark, whiteSpace: 'nowrap', fontWeight: 500 }}>
              {taka(total)}
            </span>
          </div>
        </div>
      </div>

      <div style={{
        position: 'fixed', bottom: 0, left: 0, right: 0,
        padding: '12px 16px 24px',
        borderTop: `0.5px solid ${T.line}`, background: T.surface, flexShrink: 0,
      }}>
        <button
          style={{
            width: '100%', padding: '15px 16px', borderRadius: 12,
            background: canPlace ? T.primary : T.line,
            color: canPlace ? T.primaryDark : T.muted,
            border: 'none',
            fontSize: 15, fontWeight: 500,
            cursor: canPlace ? 'pointer' : 'not-allowed',
            boxShadow: canPlace ? '0 4px 8px rgba(28,26,23,.18)' : 'none',
            display: 'flex', justifyContent: 'center', alignItems: 'center', gap: 10,
            WebkitTapHighlightColor: 'transparent',
          }}
          disabled={!canPlace}
          onClick={onPlace}
        >
          {submitting ? 'Placing order…' : 'Place order →'}
        </button>
        {!canPlace && !submitting && (
          <div style={{ marginTop: 6, fontSize: 11, color: T.muted, textAlign: 'center', fontWeight: 400 }}>
            Add name, phone, and location to continue.
          </div>
        )}
      </div>
    </div>
  )
}

function Label({ children }) {
  return (
    <div style={{
      fontSize: 11, color: T.muted, fontWeight: 500,
      letterSpacing: '.08em', textTransform: 'uppercase', marginBottom: 6,
    }}>{children}</div>
  )
}

const fieldStyle = {
  width: '100%', padding: '10px 14px', borderRadius: 12,
  border: `0.5px solid ${T.line}`, background: T.surface, color: T.ink,
  fontSize: 14, fontWeight: 400, outline: 'none', boxSizing: 'border-box',
}

// ── Success Screen ────────────────────────────────────────────────────────────
function SuccessScreen({ order, info, cartItems, onBack }) {
  const totalItems = cartItems.reduce((s, i) => s + i.qty, 0)

  return (
    <div style={{ minHeight: '100vh', background: T.bg, display: 'flex', flexDirection: 'column', fontFamily: T.body, color: T.ink }}>
      <div style={{ flex: 1, overflowY: 'auto', display: 'flex', flexDirection: 'column' }}>
        <div style={{
          paddingTop: 70, paddingBottom: 24, textAlign: 'center',
        }}>
          <div style={{
            width: 72, height: 72, borderRadius: 999, margin: '0 auto',
            background: T.primary, color: T.primaryDark,
            display: 'grid', placeItems: 'center', fontSize: 36, fontWeight: 500,
            boxShadow: '0 4px 8px rgba(245,193,39,.4)',
          }}>✓</div>
          <div style={{ fontSize: 24, color: T.ink, marginTop: 16, lineHeight: 1.1, fontWeight: 500 }}>
            Order placed
          </div>
          <div style={{ marginTop: 6, fontSize: 12, color: T.muted, fontWeight: 400 }}>
            We'll deliver to you soon
          </div>
        </div>

        <div style={{ padding: '4px 16px 0' }}>
          <div style={{
            padding: '18px 18px 20px', borderRadius: 12,
            background: T.surface, border: `0.5px solid ${T.line}`,
            textAlign: 'center',
          }}>
            <div style={{ fontSize: 10, color: T.muted, letterSpacing: '.3em', fontWeight: 500 }}>
              ORDER NUMBER
            </div>
            {order?.serialNumber != null && (
              <div style={{ fontSize: 44, color: T.primaryDark, lineHeight: 1, marginTop: 6, fontWeight: 500 }}>
                #{order.serialNumber}
              </div>
            )}
            <div style={{
              marginTop: 14, paddingTop: 14, borderTop: `0.5px dashed ${T.line}`,
              display: 'flex', justifyContent: 'space-around', alignItems: 'flex-start', gap: 12,
            }}>
              <div>
                <div style={{ fontSize: 10, color: T.muted, letterSpacing: '.18em', fontWeight: 500 }}>ITEMS</div>
                <div style={{ fontSize: 20, color: T.ink, marginTop: 3, fontWeight: 500 }}>{totalItems}</div>
              </div>
              <div style={{ width: 1, alignSelf: 'stretch', background: T.line }} />
              <div>
                <div style={{ fontSize: 10, color: T.muted, letterSpacing: '.18em', fontWeight: 500 }}>TOTAL</div>
                <div style={{ fontSize: 20, color: T.primaryDark, marginTop: 3, whiteSpace: 'nowrap', fontWeight: 500 }}>
                  {taka(order?.total || 0)}
                </div>
              </div>
            </div>
          </div>
        </div>

        {order?.deliveryAddress && (
          <div style={{ padding: '12px 16px 0' }}>
            <div style={{
              padding: 14, borderRadius: 12, background: T.surface, border: `0.5px solid ${T.line}`,
            }}>
              <div style={{ fontSize: 10, color: T.muted, letterSpacing: '.18em', fontWeight: 500, textTransform: 'uppercase' }}>
                Delivering to
              </div>
              <div style={{ marginTop: 6, fontSize: 13, color: T.ink, fontWeight: 400, lineHeight: 1.4 }}>
                {order.deliveryAddress}
              </div>
            </div>
          </div>
        )}

        <div style={{ padding: '16px 22px 12px', textAlign: 'center' }}>
          <div style={{ fontSize: 13, color: T.muted, lineHeight: 1.55, fontWeight: 400 }}>
            Your order is being prepared.<br/>
            Cash on delivery — please keep exact change ready.
          </div>
        </div>

        <div style={{ flex: 1 }} />

        <div style={{ padding: '8px 16px 16px' }}>
          <button
            style={{
              width: '100%', padding: '14px 16px', borderRadius: 12,
              background: T.surface, color: T.ink, border: `0.5px solid ${T.line}`,
              fontSize: 14, cursor: 'pointer', fontWeight: 500,
              display: 'flex', justifyContent: 'space-between', alignItems: 'center',
              WebkitTapHighlightColor: 'transparent',
            }}
            onClick={() => generateReceipt(order, info, cartItems)}
          >
            <span style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
              <span style={{ fontSize: 18 }}>↓</span>
              <span>Download receipt</span>
            </span>
            <span style={{ fontSize: 11, color: T.muted, letterSpacing: '.16em', fontWeight: 500 }}>PDF</span>
          </button>
        </div>
      </div>

      <div style={{
        flexShrink: 0, padding: '12px 16px 24px',
        borderTop: `0.5px solid ${T.line}`, background: T.surface,
      }}>
        <button
          style={{
            width: '100%', padding: '15px 16px', borderRadius: 12,
            background: T.primary, color: T.primaryDark, border: 'none',
            fontSize: 15, cursor: 'pointer', fontWeight: 500,
            boxShadow: '0 4px 8px rgba(28,26,23,.18)',
            display: 'flex', justifyContent: 'center', alignItems: 'center', gap: 10,
            WebkitTapHighlightColor: 'transparent',
          }}
          onClick={onBack}
        >
          <span>Order again</span>
          <span style={{ fontSize: 18 }}>→</span>
        </button>
      </div>
    </div>
  )
}
