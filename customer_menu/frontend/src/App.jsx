import React, { useEffect, useRef, useState } from 'react'
import {
  ThemeProvider,
  useTokens,
  resolveTheme,
  resolveOverrides,
  themeAssetPaths,
  DEFAULT_THEME_SLUG,
} from './themes'

const API_BASE = ''
const MENU_REFRESH_MS = 5000
const GOOGLE_MAPS_API_KEY = import.meta.env.VITE_GOOGLE_MAPS_API_KEY || 'AIzaSyARB64Gh6KXFDjL_rZMqAGFlfNNGcuBWKw'
let googleMapsLoadPromise = null

// ── PDF receipt generator ─────────────────────────────────────────────────────
function pdfTk(n) { return 'Tk ' + Math.round(n).toLocaleString() }

export async function generateReceipt(order, info, cartItems) {
  const { jsPDF } = await import('jspdf')
  const doc = new jsPDF({ unit: 'pt', format: 'a5' })
  const W = doc.internal.pageSize.getWidth()
  let y = 44

  doc.setFont('helvetica', 'bold')
  doc.setFontSize(20)
  doc.setTextColor(0, 0, 0)
  doc.text(info?.restaurantName || 'Restaurant', W / 2, y, { align: 'center' }); y += 24

  if (info?.outletName) {
    doc.setFont('helvetica', 'normal')
    doc.setFontSize(10)
    doc.setTextColor(100, 100, 100)
    doc.text(info.outletName, W / 2, y, { align: 'center' }); y += 16
  }

  doc.setFont('helvetica', 'normal')
  doc.setFontSize(9)
  doc.setTextColor(140, 140, 140)
  doc.text(new Date().toLocaleString('en-BD'), W / 2, y, { align: 'center' }); y += 22
  doc.setTextColor(0, 0, 0)

  doc.setDrawColor(255, 106, 61)
  doc.setLineWidth(0.75)
  doc.line(30, y, W - 30, y); y += 18

  doc.setFont('helvetica', 'bold')
  doc.setFontSize(8)
  doc.setTextColor(140, 140, 140)
  doc.text('ORDER NUMBER', W / 2, y, { align: 'center' }); y += 6

  doc.setFontSize(44)
  doc.setTextColor(255, 181, 71)
  doc.text(`#${order.serialNumber}`, W / 2, y + 34, { align: 'center' }); y += 50
  doc.setTextColor(0, 0, 0)
  doc.line(30, y, W - 30, y); y += 20

  doc.setFont('helvetica', 'bold')
  doc.setFontSize(8)
  doc.setTextColor(140, 140, 140)
  doc.text('ITEM', 30, y)
  doc.text('QTY', W / 2, y, { align: 'center' })
  doc.text('AMOUNT', W - 30, y, { align: 'right' })
  y += 4
  doc.setLineWidth(0.3)
  doc.setDrawColor(200, 200, 200)
  doc.line(30, y, W - 30, y); y += 12
  doc.setTextColor(0, 0, 0)

  doc.setFontSize(10)
  for (const item of cartItems) {
    doc.setFont('helvetica', 'normal')
    const nameLines = doc.splitTextToSize(item.name, W / 2 - 10)
    doc.text(nameLines, 30, y)
    doc.setTextColor(80, 80, 80)
    doc.text(`x${item.qty}`, W / 2, y, { align: 'center' })
    doc.setFont('helvetica', 'bold')
    doc.setTextColor(0, 0, 0)
    doc.text(pdfTk(item.price * item.qty), W - 30, y, { align: 'right' })
    if (item.qty > 1) {
      doc.setFont('helvetica', 'normal')
      doc.setFontSize(8)
      doc.setTextColor(160, 160, 160)
      doc.text(`${pdfTk(item.price)} each`, W - 30, y + 11, { align: 'right' })
      doc.setFontSize(10)
    }
    y += nameLines.length > 1 ? nameLines.length * 13 + 6 : 20
    doc.setTextColor(0, 0, 0)
  }

  if (order.notes) {
    y += 4
    doc.setFont('helvetica', 'italic')
    doc.setFontSize(9)
    doc.setTextColor(120, 120, 120)
    const noteLines = doc.splitTextToSize(`Note: ${order.notes}`, W - 60)
    doc.text(noteLines, 30, y); y += noteLines.length * 13 + 4
    doc.setTextColor(0, 0, 0)
  }

  y += 4
  doc.setLineWidth(0.75)
  doc.setDrawColor(255, 106, 61)
  doc.line(30, y, W - 30, y); y += 16
  doc.setFont('helvetica', 'bold')
  doc.setFontSize(13)
  doc.text('Total', 30, y)
  doc.setTextColor(255, 181, 71)
  doc.text(pdfTk(order.total), W - 30, y, { align: 'right' }); y += 30
  doc.setTextColor(0, 0, 0)

  doc.setLineWidth(0.3)
  doc.setDrawColor(220, 220, 220)
  doc.line(30, y, W - 30, y); y += 14
  doc.setFont('helvetica', 'italic')
  doc.setFontSize(9)
  doc.setTextColor(160, 160, 160)
  doc.text('Thank you for dining with us!', W / 2, y, { align: 'center' }); y += 13
  doc.setFontSize(7)
  doc.text(`Order ID: ${order.orderId?.slice(0, 12) ?? ''}`, W / 2, y, { align: 'center' })

  doc.save(`receipt-${order.serialNumber ?? order.orderId?.slice(0, 8) ?? 'order'}.pdf`)
}

// ── Theme ─────────────────────────────────────────────────────────────────────
// Module-level fallback tokens used only by the menu-icon constants below
// (which are evaluated at import time, before any React tree exists). Every
// component grabs its live theme tokens via `useTokens()` at render time.
const T_FALLBACK = {
  amber: '#ffb547',
  display: '"Anton", "Bebas Neue", "Inter Tight", system-ui, sans-serif',
}

const MENU_ICON_STYLES = {
  pizza:    { glyph: '🍕', color: '#e65a3c', bg: 'rgba(230,90,60,.18)' },
  burger:   { glyph: '☰', color: '#f0a51c', bg: 'rgba(240,165,28,.18)' },
  biryani:  { glyph: '◉', color: '#e28714', bg: 'rgba(226,135,20,.20)' },
  rice:     { glyph: '◌', color: '#7a6b2d', bg: 'rgba(122,107,45,.22)' },
  curry:    { glyph: '◒', color: '#e28714', bg: 'rgba(226,135,20,.18)' },
  soup:     { glyph: '∪', color: '#e65a3c', bg: 'rgba(230,90,60,.16)' },
  vegetable:{ glyph: '✦', color: '#3d7a5a', bg: 'rgba(61,122,90,.20)' },
  noodle:   { glyph: '≈', color: '#c54862', bg: 'rgba(197,72,98,.18)' },
  bread:    { glyph: '▱', color: '#8a5a32', bg: 'rgba(138,90,50,.22)' },
  chicken:  { glyph: '◔', color: '#e65a3c', bg: 'rgba(230,90,60,.18)' },
  fish:     { glyph: '◇', color: '#2f7ea8', bg: 'rgba(47,126,168,.18)' },
  beef:     { glyph: '◆', color: '#8a5a32', bg: 'rgba(138,90,50,.22)' },
  snack:    { glyph: '✚', color: '#f0a51c', bg: 'rgba(240,165,28,.18)' },
  fruit:    { glyph: '●', color: '#c54862', bg: 'rgba(197,72,98,.18)' },
  dessert:  { glyph: '✸', color: '#c54862', bg: 'rgba(197,72,98,.18)' },
  drink:    { glyph: '▯', color: '#2e9b79', bg: 'rgba(46,155,121,.18)' },
  coffee:   { glyph: '☕', color: '#8a5a32', bg: 'rgba(138,90,50,.22)' },
  tea:      { glyph: '◡', color: '#7a6b2d', bg: 'rgba(122,107,45,.22)' },
  breakfast:{ glyph: '◐', color: '#f0a51c', bg: 'rgba(240,165,28,.18)' },
  set_meal: { glyph: '▦', color: '#e28714', bg: 'rgba(226,135,20,.18)' },
  general:  { glyph: '✦', color: T_FALLBACK.amber, bg: 'rgba(255,181,71,.14)' },
}

export function inferIconKey(item) {
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

export function iconStyleFor(item) {
  return MENU_ICON_STYLES[inferIconKey(item)] || MENU_ICON_STYLES.general
}

export function MenuFallbackIcon({ item, size = 32 }) {
  const T = useTokens()
  const style = iconStyleFor(item)
  return (
    <div style={{
      position: 'absolute', inset: 0, display: 'grid', placeItems: 'center',
      background: style.bg,
    }}>
      <span style={{
        color: style.color, fontSize: size, fontFamily: T.display,
        lineHeight: 1, fontWeight: 800, opacity: .95,
      }}>{style.glyph}</span>
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
function getRouteContext() {
  const host = window.location.hostname.toLowerCase()
  const rootDomain = 'quickbytes.buzz'
  const p = new URLSearchParams(window.location.search)
  const parts = window.location.pathname.split('/').filter(Boolean)
  const tableIdx = parts.indexOf('tableorder')
  const tableNo = tableIdx !== -1 && parts[tableIdx + 1]
    ? decodeURIComponent(parts[tableIdx + 1]).trim()
    : ''
  const tableMode = tableNo.length > 0
  if (host.endsWith(`.${rootDomain}`)) {
    const subdomain = host.slice(0, -rootDomain.length - 1).split('.')[0]
    if (subdomain && subdomain !== 'www') {
      return { outletId: subdomain, tableNo, tableMode }
    }
  }

  if (p.get('demo') === '1') return { outletId: '__demo__', tableNo, tableMode }
  if (p.get('outlet')) return { outletId: p.get('outlet'), tableNo, tableMode }
  const idx = parts.indexOf('menu')
  if (idx !== -1 && parts[idx + 1]) {
    return { outletId: parts[idx + 1], tableNo, tableMode }
  }
  return { outletId: parts[parts.length - 1] || null, tableNo, tableMode }
}

function getOutletId() {
  return getRouteContext().outletId
}

export function cartTotal(cart, items) {
  return Object.entries(cart).reduce((sum, [id, qty]) => {
    const item = items.find(i => i.id === id)
    return sum + (item ? item.price * qty : 0)
  }, 0)
}
export function cartCount(cart) { return Object.values(cart).reduce((s, q) => s + q, 0) }
export function taka(n) { return '৳' + Math.round(n).toLocaleString('en-BD') }

export function localizedItemName(item, lang = 'en') {
  if (lang === 'bn' && item?.nameBn) return item.nameBn
  return item?.nameEn || item?.name || item?.nameBn || 'Item'
}

export function buildMedia(item) {
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
  try {
    body = await res.json()
  } catch {
    // Keep the clearer status error below.
  }
  if (!res.ok) {
    throw new Error(body?.detail || body?.error || `${res.status} ${res.statusText}: ${path}`)
  }
  return unwrapApi(body)
}

export function loadGoogleMapsApi() {
  if (typeof window === 'undefined') {
    return Promise.reject(new Error('Maps can only load in a browser.'))
  }
  if (window.google?.maps?.importLibrary) {
    return Promise.resolve(window.google.maps)
  }
  if (!GOOGLE_MAPS_API_KEY) {
    return Promise.reject(new Error('Google Maps key is missing.'))
  }
  if (googleMapsLoadPromise) return googleMapsLoadPromise

  googleMapsLoadPromise = new Promise((resolve, reject) => {
    const existing = document.querySelector('script[data-rastarant-google-maps="true"]')
    const callback = `__rastarantGoogleMapsLoaded_${Date.now()}`
    const cleanup = () => {
      try { delete window[callback] } catch { window[callback] = undefined }
    }

    window[callback] = () => {
      cleanup()
      if (window.google?.maps?.importLibrary) resolve(window.google.maps)
      else {
        googleMapsLoadPromise = null
        reject(new Error('Google Maps did not finish loading.'))
      }
    }

    if (existing) {
      existing.addEventListener('load', () => {
        cleanup()
        if (window.google?.maps?.importLibrary) resolve(window.google.maps)
        else {
          googleMapsLoadPromise = null
          reject(new Error('Google Maps did not finish loading.'))
        }
      }, { once: true })
      existing.addEventListener('error', () => {
        cleanup()
        googleMapsLoadPromise = null
        existing.remove()
        reject(new Error('Could not load Google Maps.'))
      }, { once: true })
      return
    }

    const params = new URLSearchParams({
      key: GOOGLE_MAPS_API_KEY,
      v: 'weekly',
      loading: 'async',
      auth_referrer_policy: 'origin',
      callback,
    })
    const script = document.createElement('script')
    script.src = `https://maps.googleapis.com/maps/api/js?${params.toString()}`
    script.async = true
    script.defer = true
    script.dataset.rastarantGoogleMaps = 'true'
    script.onerror = () => {
      cleanup()
      googleMapsLoadPromise = null
      script.remove()
      reject(new Error('Could not load Google Maps.'))
    }
    document.head.appendChild(script)
  })

  return googleMapsLoadPromise
}

export function getBrowserPosition() {
  if (!navigator.geolocation) {
    console.info('[QB-CUSTOMER-GEO] geolocation unavailable')
    return Promise.reject(new Error('Location is not available in this browser.'))
  }
  console.info('[QB-CUSTOMER-GEO] browser location request started')
  return new Promise((resolve, reject) => {
    navigator.geolocation.getCurrentPosition(
      position => {
        const result = {
          lat: position.coords.latitude,
          lng: position.coords.longitude,
        }
        console.info('[QB-CUSTOMER-GEO] browser location success', result)
        resolve(result)
      },
      error => {
        const denied = error.code === error.PERMISSION_DENIED
        console.info('[QB-CUSTOMER-GEO] browser location failed', {
          code: error.code,
          message: error.message,
        })
        reject(new Error(denied ? 'Location permission was denied.' : 'Could not detect your location.'))
      },
      { enableHighAccuracy: true, timeout: 12000, maximumAge: 300000 },
    )
  })
}

export async function reverseGeocodePosition(position, outletId) {
  if (!outletId || outletId === '__demo__') {
    console.info('[QB-CUSTOMER-GEO] reverse geocode skipped', { outletId })
    throw new Error('Address lookup is not available for this menu.')
  }
  console.info('[QB-CUSTOMER-GEO] reverse geocode request', { outletId, position })
  const res = await fetch(`${API_BASE}/customer/${encodeURIComponent(outletId)}/geocode/reverse`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    cache: 'no-store',
    body: JSON.stringify(position),
  })
  let body = null
  try {
    body = await res.json()
  } catch {
    // Keep the clearer status error below.
  }
  if (!res.ok) {
    console.info('[QB-CUSTOMER-GEO] reverse geocode failed', { status: res.status, body })
    throw new Error(body?.detail || body?.error || 'Could not detect address.')
  }
  const data = body?.ok === true ? body.data : body?.data ?? body
  const address = data?.address?.trim()
  if (!address) throw new Error('No address found near this location.')
  console.info('[QB-CUSTOMER-GEO] reverse geocode success', { address })
  return address
}

// ═══════════════════════════════════════════════════════════════════════════════
export default function App() {
  const routeContext = getRouteContext()
  const outletId = routeContext.outletId
  const tableNo = routeContext.tableNo
  const isTableOrder = routeContext.tableMode
  const [phase, setPhase]       = useState('loading')
  const [info, setInfo]         = useState(null)
  const [items, setItems]       = useState([])
  const [cart, setCart]         = useState({})
  const [activeCategory, setCat]= useState('All')
  const [note, setNote]         = useState('')
  const [delivery, setDelivery] = useState({ name: '', address: '', mobile: '' })
  const [submitting, setSub]    = useState(false)
  const [errorMsg, setErr]      = useState('')
  const [orderRef, setOrderRef] = useState(null)
  const [lightbox, setLightbox] = useState(null)
  const [lastCart, setLastCart] = useState([])

  useEffect(() => {
    if (!outletId) { setPhase('error'); setErr('Invalid menu link.'); return }
    if (outletId === '__demo__') {
      const params = new URLSearchParams(window.location.search)
      const themeOverride = params.get('theme')
      setInfo(themeOverride ? { ...DEMO_INFO, menuTheme: themeOverride } : DEMO_INFO)
      setItems(DEMO_ITEMS)
      setPhase('welcome')
      return
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
        setPhase(current => (current === 'loading' || current === 'error') ? 'welcome' : current)
      } catch (e) {
        if (cancelled || silent) return
        setPhase('error')
        setErr(e.message || 'Could not load menu.')
      }
    }

    refresh(false)
    const timer = window.setInterval(() => refresh(true), MENU_REFRESH_MS)
    const onVisible = () => {
      if (document.visibilityState === 'visible') refresh(true)
    }
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

  async function placeOrder() {
    setSub(true)
    if (outletId === '__demo__') {
      await new Promise(r => setTimeout(r, 800))
      const demoCartItems = Object.entries(cart).map(([id, qty]) => {
        const item = items.find(i => i.id === id)
        return { name: item.name, qty, price: item.price }
      })
      setLastCart(demoCartItems)
      setOrderRef({ serialNumber: Math.floor(Math.random() * 90) + 10, total: cartTotal(cart, items), orderId: 'demo-order-001', notes: note || null })
      setPhase('success')
      setSub(false)
      return
    }
    try {
      const lang = new URLSearchParams(window.location.search).get('lang') === 'bn'
        ? 'bn'
        : 'en'
      const orderItems = Object.entries(cart).map(([id, qty]) => {
        const item = items.find(i => i.id === id)
        return {
          menuItemId: id,
          name: localizedItemName(item, lang),
          qty,
          price: item.price,
        }
      })
      const payload = isTableOrder
        ? {
            items: orderItems,
            orderType: 'dine_in',
            tableNo,
          }
        : {
            items: orderItems,
            note: note || null,
            orderType: 'delivery',
            customerName: delivery.name.trim(),
            deliveryAddress: delivery.address.trim(),
            mobileNumber: delivery.mobile.trim(),
          }
      const res = await fetch(`${API_BASE}/customer/${outletId}/orders`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data.detail || data.error || 'Order failed')
      const orderData = unwrapApi(data)
      setLastCart(Object.entries(cart).map(([id, qty]) => {
        const item = items.find(i => i.id === id)
        return { name: localizedItemName(item, lang), qty, price: item.price }
      }))
      setOrderRef(orderData)
      setPhase('success')
    } catch (e) { alert(e.message || 'Could not place order.') }
    finally { setSub(false) }
  }

  const themeSlug = info?.menuTheme || DEFAULT_THEME_SLUG
  const overrides = resolveOverrides(themeSlug)

  let body
  if (phase === 'loading') {
    body = overrides ? <overrides.Loading /> : <LoadingScreen />
  } else if (phase === 'error') {
    body = overrides
      ? <overrides.Error message={errorMsg} />
      : <ErrorScreen message={errorMsg} />
  } else if (phase === 'success') {
    const onBack = () => {
      setCart({}); setLastCart([]); setNote('')
      setDelivery({ name: '', address: '', mobile: '' })
      setPhase('menu')
    }
    body = overrides
      ? <overrides.Success order={orderRef} info={info} cartItems={lastCart} onBack={onBack} />
      : <SuccessScreen order={orderRef} info={info} cartItems={lastCart} onBack={onBack} />
  } else if (phase === 'cart') {
    body = overrides ? (
      <overrides.Cart
        cart={cart} items={items} note={note} onNote={setNote}
        delivery={delivery} onDelivery={setDelivery}
        onAdd={add} onRemove={rem} onBack={() => setPhase('menu')}
        onPlace={placeOrder} submitting={submitting} info={info} outletId={outletId}
        isTableOrder={isTableOrder} tableNo={tableNo}
      />
    ) : (
      <CartScreen cart={cart} items={items} note={note} onNote={setNote}
        delivery={delivery} onDelivery={setDelivery}
        onAdd={add} onRemove={rem} onBack={() => setPhase('menu')}
        onPlace={placeOrder} submitting={submitting} info={info} outletId={outletId}
        isTableOrder={isTableOrder} tableNo={tableNo} />
    )
  } else if (overrides) {
    // For themes that ship a single-page Storefront (e.g. Hearth),
    // 'welcome' and 'menu' phases both render the same scrollable
    // surface — the only difference is whether to land at the menu
    // anchor on mount.
    body = (
      <>
        <overrides.Storefront
          info={info} items={items} cart={cart}
          onAdd={add} onRemove={rem}
          onOpenCart={() => setPhase('cart')}
          onOpenDetail={item => setLightbox({ item })}
          initialView={phase === 'menu' ? 'menu' : 'hero'}
        />
        {lightbox && (
          <overrides.ItemSheet
            item={lightbox.item}
            qty={cart[lightbox.item.id] || 0}
            onAdd={() => add(lightbox.item.id)}
            onRemove={() => rem(lightbox.item.id)}
            onClose={() => setLightbox(null)}
          />
        )}
      </>
    )
  } else if (phase === 'welcome') {
    body = <WelcomeScreen info={info} onEnter={() => setPhase('menu')} />
  } else {
    body = (
      <>
        <MenuScreen
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

  return <ThemeProvider slug={themeSlug}>{body}</ThemeProvider>
}

// ═══════════════════════════════════════════════════════════════════════════════
function LoadingScreen() {
  const T = useTokens()
  return (
    <div style={{
      minHeight: '100vh', display: 'flex', flexDirection: 'column',
      alignItems: 'center', justifyContent: 'center',
      background: T.bg, padding: 24, fontFamily: T.body,
    }}>
      <div style={{
        width: 40, height: 40,
        border: `2px solid rgba(255,243,224,.1)`,
        borderTop: `2px solid ${T.amber}`,
        borderRadius: '50%',
        animation: 'spin .9s linear infinite',
      }} />
      <p style={{ color: T.inkSoft, marginTop: 20, fontWeight: 500, letterSpacing: 2, fontSize: 11, textTransform: 'uppercase' }}>
        Loading…
      </p>
    </div>
  )
}

function ErrorScreen({ message }) {
  const T = useTokens()
  return (
    <div style={{
      minHeight: '100vh', display: 'flex', flexDirection: 'column',
      alignItems: 'center', justifyContent: 'center',
      background: T.bg, padding: 24, fontFamily: T.body,
    }}>
      <div style={{ fontSize: 42, marginBottom: 16 }}>🍽️</div>
      <p style={{ color: T.amber, fontFamily: T.display, fontSize: 18, textAlign: 'center', padding: '0 32px' }}>
        {message}
      </p>
    </div>
  )
}

// ── Welcome Screen ────────────────────────────────────────────────────────────
function WelcomeScreen({ info, onEnter }) {
  const T = useTokens()
  const videoRef = useRef(null)
  const [slide, setSlide] = useState(0)
  const touchX = useRef(null)
  const gallery = info?.galleryImages || []
  const hasVideo = !!info?.videoUrl
  const hasGallery = !hasVideo && gallery.length > 0
  const hasBanner = !hasVideo && !hasGallery && !!info?.bannerUrl
  const hasMedia = hasVideo || hasGallery || hasBanner
  // Per-theme placeholder paths reserved for future use; the actual asset
  // files live under public/themes/<slug>/ and are dropped in by the owner.
  // eslint-disable-next-line no-unused-vars
  const _placeholderAssets = themeAssetPaths(T._slug)

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
      style={{ width: '100%', minHeight: '100vh', position: 'relative', overflow: 'hidden', background: T.bg, fontFamily: T.body }}
      onTouchStart={hasGallery ? onTouchStart : undefined}
      onTouchEnd={hasGallery ? onTouchEnd : undefined}
    >
      {/* Background media */}
      {hasVideo ? (
        <video ref={videoRef} src={info.videoUrl} autoPlay muted loop playsInline preload="metadata"
          style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover' }} />
      ) : hasGallery ? (
        gallery.map((url, i) => (
          <img key={url} src={url} alt="" loading="lazy" style={{
            position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover',
            opacity: i === slide ? 1 : 0, transition: 'opacity 0.7s ease',
          }} />
        ))
      ) : hasBanner ? (
        <img src={info.bannerUrl} alt="" loading="lazy"
          style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover' }} />
      ) : (
        <>
          <div style={{
            position: 'absolute', inset: 0,
            background: `repeating-linear-gradient(135deg,
              rgba(255,243,224,.04) 0 12px,
              rgba(255,243,224,.08) 12px 24px)`,
          }} />
          <div style={{
            position: 'absolute', inset: 0,
            background: 'radial-gradient(80% 50% at 50% 35%, rgba(255,181,71,.10) 0%, transparent 60%)',
          }} />
        </>
      )}

      {/* Gradient overlay */}
      <div style={{
        position: 'absolute', inset: 0,
        background: hasMedia
          ? 'linear-gradient(180deg, rgba(28,20,16,.55) 0%, rgba(28,20,16,.25) 40%, rgba(28,20,16,.88) 100%)'
          : 'transparent',
      }} />

      {/* Centered content */}
      <div style={{
        position: 'relative', minHeight: '100vh',
        display: 'flex', flexDirection: 'column',
        alignItems: 'center', justifyContent: 'center',
        padding: '60px 28px', textAlign: 'center',
      }}>
        {/* Logo mark */}
        <div style={{
          width: 96, height: 96, borderRadius: 48,
          background: 'rgba(28,20,16,.65)', border: `1.5px solid ${T.amber}`,
          display: 'grid', placeItems: 'center',
          fontFamily: T.display, fontSize: 56, color: T.amber, lineHeight: 1,
          boxShadow: '0 12px 40px rgba(255,181,71,.2)',
        }}>
          {info?.restaurantName?.[0]?.toUpperCase() || 'R'}
        </div>

        {/* Restaurant name */}
        <div style={{
          fontFamily: T.display, fontSize: 60, color: '#fff', marginTop: 24, lineHeight: .9,
          textTransform: 'uppercase', letterSpacing: '-.015em',
          textShadow: '0 2px 20px rgba(0,0,0,.5)',
        }}>{info?.restaurantName || 'Restaurant'}</div>

        {/* Outlet subtitle */}
        {info?.outletName && (
          <div style={{ marginTop: 8, fontSize: 13, color: T.inkSoft, letterSpacing: '.05em' }}>
            {info.outletName}
          </div>
        )}

        {/* CTA button */}
        <button
          style={{
            marginTop: 40, padding: '14px 30px',
            background: T.ember, color: '#1a0c08', border: 'none', borderRadius: 12,
            fontFamily: T.display, fontSize: 20, fontWeight: 700, textTransform: 'uppercase',
            cursor: 'pointer', letterSpacing: '.04em',
            display: 'flex', alignItems: 'center', gap: 10,
            boxShadow: '0 14px 30px rgba(255,106,61,.4)',
            WebkitTapHighlightColor: 'transparent',
          }}
          onClick={onEnter}
        >
          <span>See the Menu</span>
          <span style={{ fontSize: 22, lineHeight: 1 }}>→</span>
        </button>

        {/* Gallery dots */}
        {hasGallery && gallery.length > 1 && (
          <div style={{ display: 'flex', gap: 6, marginTop: 20 }}>
            {gallery.map((_, i) => (
              <div key={i} onClick={() => setSlide(i)} style={{
                width: i === slide ? 18 : 6, height: 6, borderRadius: 3,
                background: i === slide ? T.amber : 'rgba(255,181,71,.35)',
                transition: 'all 0.3s', cursor: 'pointer',
              }} />
            ))}
          </div>
        )}
      </div>
    </div>
  )
}

// ── Menu Screen ───────────────────────────────────────────────────────────────
function MenuScreen({ info, items, allItems, cart, categories, activeCategory, onCategory, onAdd, onRemove, onOpenCart, onOpenDetail }) {
  const T = useTokens()
  const count = cartCount(cart)
  const total = cartTotal(cart, allItems)

  return (
    <div style={{ minHeight: '100vh', background: T.bg, display: 'flex', flexDirection: 'column', fontFamily: T.body }}>
      {/* Short hero */}
      <MenuHero info={info} />

      {/* Category tabs */}
      <div style={{
        display: 'flex', padding: '14px 18px 0',
        overflowX: 'auto', scrollbarWidth: 'none', WebkitOverflowScrolling: 'touch',
        background: T.bg, flexShrink: 0,
        borderBottom: `1px solid ${T.line}`,
      }}>
        {categories.map(cat => {
          const active = cat === activeCategory
          return (
            <button key={cat}
              onClick={() => onCategory(cat)}
              style={{
                flex: '0 0 auto', padding: '0 0 12px', marginRight: 20,
                background: 'transparent', border: 'none', cursor: 'pointer',
                fontFamily: T.display, fontSize: 17, fontWeight: 700,
                textTransform: 'uppercase', letterSpacing: '.01em',
                color: active ? T.amber : T.inkSoft,
                borderBottom: active ? `2.5px solid ${T.ember}` : '2.5px solid transparent',
                transition: 'color .15s',
                WebkitTapHighlightColor: 'transparent',
                whiteSpace: 'nowrap',
              }}>
              {cat === 'All' ? 'All' : cat}
            </button>
          )
        })}
      </div>

      {/* 2-col grid */}
      <div style={{
        padding: '9px 12px',
        paddingBottom: count > 0 ? 110 : 24,
        display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10,
        flex: 1,
        alignContent: 'start',
      }}>
        {items.length === 0 ? (
          <div style={{
            gridColumn: '1 / -1', textAlign: 'center',
            color: T.inkSoft, padding: '60px 0', fontStyle: 'italic',
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

      {/* Cart bar */}
      {count > 0 && (
        <div className="slide-up" onClick={onOpenCart} style={{
          position: 'fixed', left: 18, right: 18, bottom: 18, zIndex: 30,
          background: T.ember, color: '#1a0c08', padding: '13px 18px', borderRadius: 14,
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          boxShadow: '0 14px 30px rgba(255,106,61,.45)',
          fontFamily: T.display, textTransform: 'uppercase', letterSpacing: '.02em',
          cursor: 'pointer',
          WebkitTapHighlightColor: 'transparent',
        }}>
          <span style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <span style={{
              width: 26, height: 26, borderRadius: 13, background: '#1a0c08', color: T.amber,
              display: 'grid', placeItems: 'center', fontSize: 13, fontWeight: 700,
              fontFamily: T.body, flexShrink: 0,
            }}>{count}</span>
            <span style={{ fontSize: 18, fontWeight: 700 }}>ORDER</span>
          </span>
          <span style={{ fontSize: 18, fontWeight: 700 }}>{taka(total)} →</span>
        </div>
      )}
    </div>
  )
}

// ── Menu Hero (short, inside menu page) ───────────────────────────────────────
function MenuHero({ info }) {
  const T = useTokens()
  const videoRef = useRef(null)
  const [slide, setSlide] = useState(0)
  const gallery = info?.galleryImages || []
  const hasGallery = gallery.length > 0
  const hasVideo = !hasGallery && !!info?.videoUrl

  useEffect(() => {
    if (!hasGallery || gallery.length < 2) return
    const id = setInterval(() => setSlide(i => (i + 1) % gallery.length), 4000)
    return () => clearInterval(id)
  }, [hasGallery, gallery.length])

  useEffect(() => {
    if (videoRef.current) videoRef.current.play().catch(() => {})
  }, [info?.videoUrl])

  return (
    <div style={{ position: 'relative', height: 200, flexShrink: 0, background: T.bgWarm, overflow: 'hidden' }}>
      {hasVideo ? (
        <video ref={videoRef} src={info.videoUrl} autoPlay muted loop playsInline preload="metadata"
          style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover' }} />
      ) : hasGallery ? (
        gallery.map((url, i) => (
          <img key={url} src={url} alt="" loading="lazy" style={{
            position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover',
            opacity: i === slide ? 1 : 0, transition: 'opacity 0.7s ease',
          }} />
        ))
      ) : info?.bannerUrl ? (
        <img src={info.bannerUrl} alt="" loading="lazy"
          style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover' }} />
      ) : null}

      {/* Gradient overlay */}
      <div style={{
        position: 'absolute', inset: 0,
        background: 'linear-gradient(180deg, rgba(28,20,16,.65) 0%, rgba(28,20,16,.1) 40%, rgba(28,20,16,.92) 100%)',
      }} />

      {/* Top bar */}
      <div style={{
        position: 'absolute', top: 52, left: 0, right: 0,
        display: 'flex', justifyContent: 'space-between', padding: '0 18px',
        alignItems: 'center',
      }}>
        <div style={{ fontSize: 11, letterSpacing: '.3em', color: T.amber, fontFamily: T.body, fontWeight: 600 }}>
          {info?.restaurantName?.toUpperCase() || 'MENU'}
        </div>
        {info?.outletName && (
          <div style={{ fontSize: 11, color: T.inkSoft, fontFamily: T.body }}>{info.outletName}</div>
        )}
      </div>

      {/* Bottom: big name */}
      <div style={{ position: 'absolute', left: 18, right: 18, bottom: 16 }}>
        <div style={{
          fontFamily: T.display, fontSize: 42, lineHeight: .88,
          textTransform: 'uppercase', letterSpacing: '-.01em',
          color: '#fff', fontWeight: 800,
          textShadow: '0 2px 12px rgba(0,0,0,.5)',
        }}>{info?.restaurantName || 'Menu'}</div>
      </div>
    </div>
  )
}

// ── Menu Card (2-col grid) ────────────────────────────────────────────────────
function MenuCard({ item, qty, onAdd, onRemove, onOpenDetail, delay }) {
  const T = useTokens()
  const lang = new URLSearchParams(window.location.search).get('lang') === 'bn' ? 'bn' : 'en'
  const hasImage = !!item.imageUrl
  const displayName = localizedItemName(item, lang)
  const description = lang === 'bn' && item.descriptionBn ? item.descriptionBn : item.description

  return (
    <div
      className="fade-up"
      style={{
        background: T.bgCard, borderRadius: 14, overflow: 'hidden',
        border: `1px solid ${T.line}`,
        display: 'flex', flexDirection: 'column',
        minHeight: 0,
        animationDelay: `${Math.min(delay * 0.04, 0.3)}s`,
        cursor: 'pointer',
        WebkitTapHighlightColor: 'transparent',
      }}
      onClick={onOpenDetail}
    >
      {/* Image area */}
      <div style={{
        width: '100%', aspectRatio: '1.28 / 1', maxHeight: 92, position: 'relative',
        background: T.bgWarm,
        ...(hasImage ? {
          backgroundImage: `url(${item.imageUrl})`,
          backgroundSize: 'cover', backgroundPosition: 'center',
        } : {}),
        flexShrink: 0,
      }}>
        {!hasImage && <MenuFallbackIcon item={item} size={32} />}
        {item.tag && (
          <span style={{
            position: 'absolute', top: 7, left: 7,
            padding: '2px 7px', background: 'rgba(28,20,16,.82)', backdropFilter: 'blur(4px)',
            color: T.amber, fontSize: 9, letterSpacing: '.14em', borderRadius: 3, fontWeight: 700,
            whiteSpace: 'nowrap', fontFamily: T.body,
          }}>★ {item.tag.toUpperCase()}</span>
        )}
        {item.videoUrl && (
          <div style={{
            position: 'absolute', top: 7, left: item.tag ? undefined : 7,
            right: 7, bottom: undefined,
            width: 22, height: 22, borderRadius: 11,
            background: 'rgba(28,20,16,.75)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <svg width="10" height="10" viewBox="0 0 10 10" fill="none">
              <polygon points="2,1 9,5 2,9" fill={T.amber}/>
            </svg>
          </div>
        )}
        {/* Add / qty control */}
        <div style={{ position: 'absolute', top: 7, right: 7 }}
          onClick={e => e.stopPropagation()}>
          {qty === 0 ? (
            <button onClick={onAdd} style={{
              width: 28, height: 28, borderRadius: 14, border: 'none',
              background: T.ember, color: '#1a0c08', fontSize: 20, lineHeight: 1,
              cursor: 'pointer', fontWeight: 700, display: 'grid', placeItems: 'center',
              WebkitTapHighlightColor: 'transparent',
            }}>+</button>
          ) : (
            <div style={{
              display: 'flex', alignItems: 'center',
              background: 'rgba(28,20,16,.88)', borderRadius: 8,
              border: `1px solid ${T.line}`, height: 28,
              fontFamily: T.display, fontSize: 13,
            }}>
              <span onClick={onRemove} style={{ padding: '0 7px', cursor: 'pointer', color: T.inkSoft, lineHeight: '28px' }}>−</span>
              <span style={{ padding: '0 2px', color: '#fff', fontWeight: 700, lineHeight: '28px' }}>{qty}</span>
              <span onClick={onAdd} style={{ padding: '0 7px', cursor: 'pointer', color: T.amber, lineHeight: '28px' }}>+</span>
            </div>
          )}
        </div>
      </div>

      {/* Info */}
      <div style={{ padding: '8px 9px 9px', display: 'flex', flexDirection: 'column', flex: 1, minHeight: 70 }}>
        <div style={{
          fontFamily: T.display, fontSize: 14, fontWeight: 700, lineHeight: 1.05,
          textTransform: 'uppercase', color: '#fff',
          overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
        }}>{displayName}</div>
        {description && (
          <div style={{
            fontSize: 10, color: T.inkSoft, marginTop: 3,
            overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
          }}>{description}</div>
        )}
        <div style={{ flex: 1 }} />
        <div style={{
          fontFamily: T.display, fontSize: 15, color: T.amber, marginTop: 5,
        }}>{taka(item.price)}</div>
      </div>
    </div>
  )
}

// ── Item Detail Sheet ─────────────────────────────────────────────────────────
function ItemDetailSheet({ item, qty, onAdd, onRemove, onClose }) {
  const T = useTokens()
  const lang = new URLSearchParams(window.location.search).get('lang') === 'bn' ? 'bn' : 'en'
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

  const displayName = localizedItemName(item, lang)
  const description = lang === 'bn' && item.descriptionBn ? item.descriptionBn : item.description

  return (
    <div
      className="fade-in"
      style={{
        position: 'fixed', inset: 0, zIndex: 50,
        background: 'rgba(0,0,0,.6)',
        display: 'flex', alignItems: 'flex-end',
        backdropFilter: 'blur(3px)',
      }}
      onClick={e => { if (e.target === e.currentTarget) onClose() }}
    >
      <div
        className="slide-up"
        style={{
          width: '100%', maxHeight: '90vh',
          background: T.bg,
          borderTopLeftRadius: 22, borderTopRightRadius: 22,
          boxShadow: '0 -20px 50px rgba(0,0,0,.5)',
          display: 'flex', flexDirection: 'column', overflow: 'hidden',
          border: `1px solid ${T.line}`, borderBottom: 'none',
        }}
      >
        {/* Photo header */}
        <div style={{
          height: 200, position: 'relative', flexShrink: 0,
          background: T.bgCard,
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
            position: 'absolute', inset: 0,
            borderTopLeftRadius: 22, borderTopRightRadius: 22,
            background: 'linear-gradient(180deg, rgba(28,20,16,.45) 0%, transparent 40%, rgba(28,20,16,.95) 100%)',
          }} />
          {/* Drag handle */}
          <div style={{
            position: 'absolute', top: 10, left: '50%', transform: 'translateX(-50%)',
            width: 44, height: 4, borderRadius: 2, background: 'rgba(255,255,255,.4)',
          }} />
          {/* Close */}
          <button onClick={onClose} style={{
            position: 'absolute', top: 14, right: 14,
            width: 32, height: 32, borderRadius: 16,
            background: 'rgba(28,20,16,.75)',
            color: '#fff', border: 'none', fontSize: 16, cursor: 'pointer',
            display: 'grid', placeItems: 'center',
            WebkitTapHighlightColor: 'transparent',
          }}>✕</button>
          {!current && <MenuFallbackIcon item={item} size={54} />}
        </div>

        {/* Scrolling body */}
        <div style={{ flex: 1, overflowY: 'auto', padding: '16px 20px 4px' }}>
          <div style={{
            fontFamily: T.display, fontSize: 26, lineHeight: .92, textTransform: 'uppercase',
            color: '#fff', fontWeight: 800, letterSpacing: '-.01em',
          }}>{displayName}</div>
          {description && (
            <div style={{ marginTop: 10, fontSize: 13, color: T.inkSoft, lineHeight: 1.55 }}>
              {description}
            </div>
          )}
          <div style={{
            fontFamily: T.display, fontSize: 22, color: T.amber, marginTop: 10, letterSpacing: '-.01em',
          }}>{taka(item.price)}</div>
          <div style={{ height: 80 }} />
        </div>

        {/* Bottom add bar */}
        <div style={{
          padding: '14px 18px 30px',
          borderTop: `1px solid ${T.line}`,
          background: T.bg, flexShrink: 0,
          display: 'flex', gap: 10, alignItems: 'center',
        }}>
          {qty === 0 ? (
            <button onClick={onAdd} style={{
              flex: 1, height: 50, background: T.ember, color: '#1a0c08', border: 'none', borderRadius: 12,
              fontFamily: T.display, fontSize: 16, fontWeight: 700, textTransform: 'uppercase',
              cursor: 'pointer', letterSpacing: '.02em',
              display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '0 16px',
              WebkitTapHighlightColor: 'transparent',
            }}>
              <span>Add to Order · যোগ করুন</span>
              <span>{taka(item.price)}</span>
            </button>
          ) : (
            <>
              <div style={{
                display: 'flex', alignItems: 'center', height: 50,
                border: `1px solid ${T.line}`, borderRadius: 12,
                fontFamily: T.display, fontSize: 18, flexShrink: 0,
              }}>
                <span onClick={onRemove} style={{ padding: '0 14px', color: T.inkSoft, cursor: 'pointer', fontSize: 22 }}>−</span>
                <span style={{ padding: '0 4px', color: '#fff', fontWeight: 700 }}>{qty}</span>
                <span onClick={onAdd} style={{ padding: '0 14px', color: T.amber, cursor: 'pointer', fontSize: 22 }}>+</span>
              </div>
              <button onClick={onAdd} style={{
                flex: 1, height: 50, background: T.ember, color: '#1a0c08', border: 'none', borderRadius: 12,
                fontFamily: T.display, fontSize: 15, fontWeight: 700, textTransform: 'uppercase',
                cursor: 'pointer', letterSpacing: '.02em',
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
function CartScreen({ cart, items, note, onNote, delivery, onDelivery, onAdd, onRemove, onBack, onPlace, submitting, info, outletId, isTableOrder = false, tableNo = '' }) {
  const T = useTokens()
  const lang = new URLSearchParams(window.location.search).get('lang') === 'bn' ? 'bn' : 'en'
  const cartItems = Object.entries(cart)
    .map(([id, qty]) => ({ ...items.find(i => i.id === id), qty }))
    .filter(Boolean)
  const total = cartTotal(cart, items)
  const deliveryReady = isTableOrder || (delivery.name.trim() && delivery.address.trim() && delivery.mobile.trim().length >= 7)
  const [geo, setGeo] = useState({ status: 'idle', address: '', position: null, error: '' })
  const mountedRef = useRef(true)
  const addressRef = useRef(delivery.address)

  useEffect(() => {
    addressRef.current = delivery.address
  }, [delivery.address])

  useEffect(() => {
    mountedRef.current = true
    if (!isTableOrder) detectAddress()
    return () => { mountedRef.current = false }
  }, [isTableOrder])

  function setGeoIfMounted(next) {
    if (!mountedRef.current) return
    if (typeof next === 'function') setGeo(next)
    else setGeo(next)
  }

  async function detectAddress() {
    if (!outletId || outletId === '__demo__') {
      setGeoIfMounted({
        status: 'error',
        address: '',
        position: null,
        error: 'Address lookup is not available for this menu.',
      })
      return
    }
    setGeoIfMounted(current => ({ ...current, status: 'locating', error: '' }))
    try {
      const position = await getBrowserPosition()
      setGeoIfMounted({ status: 'geocoding', address: '', position, error: '' })
      const address = await reverseGeocodePosition(position, outletId)
      if (!mountedRef.current) return
      setGeo({ status: 'ready', address, position, error: '' })
      if (!addressRef.current.trim()) {
        onDelivery(current => ({ ...current, address }))
      }
    } catch (error) {
      setGeoIfMounted(current => ({
        ...current,
        status: 'error',
        error: error.message || 'Could not detect address.',
      }))
    }
  }

  return (
    <div style={{ minHeight: '100vh', background: T.bg, display: 'flex', flexDirection: 'column', fontFamily: T.body }}>
      {/* Header */}
      <div style={{
        padding: '54px 20px 14px', borderBottom: `1px solid ${T.line}`, flexShrink: 0,
        display: 'flex', alignItems: 'center', gap: 12,
        background: T.bg, position: 'sticky', top: 0, zIndex: 10,
      }}>
        <button onClick={onBack} style={{
          width: 36, height: 36, borderRadius: 18, flexShrink: 0,
          background: 'rgba(255,243,224,.06)', color: T.ink, border: 'none',
          fontSize: 18, cursor: 'pointer', display: 'grid', placeItems: 'center',
          WebkitTapHighlightColor: 'transparent',
        }}>←</button>
        <div style={{ minWidth: 0 }}>
          <div style={{
            fontFamily: T.display, fontSize: 26, textTransform: 'uppercase',
            color: '#fff', lineHeight: 1, letterSpacing: '-.005em',
          }}>Your Order</div>
          {info?.restaurantName && (
            <div style={{ fontSize: 11, color: T.inkSoft, marginTop: 3 }}>
              {info.restaurantName}{info.outletName ? ` · ${info.outletName}` : ''}
            </div>
          )}
        </div>
      </div>

      {/* Items */}
      <div style={{ flex: 1, overflowY: 'auto', padding: '6px 20px 180px' }}>
        {cartItems.map((item, i) => (
          <div key={item.id} className="fade-up" style={{
            padding: '14px 0',
            borderBottom: i === cartItems.length - 1 ? 'none' : `1px solid ${T.line}`,
            display: 'flex', gap: 12, alignItems: 'flex-start',
            animationDelay: `${i * 0.05}s`,
          }}>
            <div style={{
              width: 56, height: 56, borderRadius: 10, flexShrink: 0,
              backgroundColor: T.bgCard, position: 'relative', overflow: 'hidden',
              ...(item.imageUrl ? {
                backgroundImage: `url(${item.imageUrl})`,
                backgroundSize: 'cover', backgroundPosition: 'center',
              } : {}),
            }}>
              {!item.imageUrl && <MenuFallbackIcon item={item} size={24} />}
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{
                fontFamily: T.display, fontSize: 16, textTransform: 'uppercase',
                color: '#fff', fontWeight: 700, lineHeight: 1.1,
              }}>{localizedItemName(item, lang)}</div>
              <div style={{ fontSize: 11, color: T.inkSoft, marginTop: 2 }}>{taka(item.price)} each</div>
              <div style={{ marginTop: 8, display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                <div style={{
                  display: 'flex', alignItems: 'center',
                  border: `1px solid ${T.line}`, borderRadius: 8, height: 28,
                  fontFamily: T.display, fontSize: 14,
                }}>
                  <span onClick={() => onRemove(item.id)} style={{ padding: '0 10px', cursor: 'pointer', color: T.inkSoft }}>−</span>
                  <span style={{ padding: '0 2px', color: '#fff', fontWeight: 700 }}>{item.qty}</span>
                  <span onClick={() => onAdd(item.id)} style={{ padding: '0 10px', cursor: 'pointer', color: T.amber }}>+</span>
                </div>
                <div style={{ fontFamily: T.display, fontSize: 17, color: T.amber, whiteSpace: 'nowrap' }}>
                  {taka(item.price * item.qty)}
                </div>
              </div>
            </div>
          </div>
        ))}

        {/* Divider */}
        <div style={{ height: 1, background: T.line, margin: '12px 0' }} />

        {isTableOrder ? (
          <div style={{
            margin: '14px 0 16px',
            padding: '14px 16px',
            border: `1px solid ${T.line}`,
            borderRadius: 12,
            background: 'rgba(255,181,71,.10)',
            color: T.amber,
            fontFamily: T.display,
            textTransform: 'uppercase',
            letterSpacing: '.08em',
          }}>Table {tableNo}</div>
        ) : (
          <>
            <div style={{ marginTop: 4, marginBottom: 16 }}>
              <div style={{
                fontFamily: T.display, fontSize: 13, color: T.amber,
                letterSpacing: '.16em', textTransform: 'uppercase', marginBottom: 8,
              }}>Delivery Details</div>
            </div>
            <div style={{ marginBottom: 16, display: 'flex', flexDirection: 'column', gap: 10 }}>
              <input
                type="text"
                placeholder="Full name"
                value={delivery.name}
                onChange={e => onDelivery({ ...delivery, name: e.target.value })}
                style={{
                  width: '100%', padding: '12px 14px', borderRadius: 10,
                  border: `1px solid ${T.line}`, background: T.bgCard, color: T.ink,
                  fontSize: 14, fontFamily: T.body, outline: 'none',
                }}
              />
              <AddressAssistSection
                geo={geo}
                currentAddress={delivery.address}
                onRetry={detectAddress}
                onUseAddress={() => onDelivery({ ...delivery, address: geo.address })}
              />
              <textarea
                placeholder="Delivery address"
                rows={2}
                value={delivery.address}
                onChange={e => onDelivery({ ...delivery, address: e.target.value })}
                style={{
                  width: '100%', padding: '12px 14px', borderRadius: 10,
                  border: `1px solid ${T.line}`, background: T.bgCard, color: T.ink,
                  fontSize: 14, fontFamily: T.body, resize: 'none', outline: 'none',
                }}
              />
              <input
                type="tel"
                inputMode="tel"
                placeholder="Mobile number"
                value={delivery.mobile}
                onChange={e => onDelivery({ ...delivery, mobile: e.target.value })}
                style={{
                  width: '100%', padding: '12px 14px', borderRadius: 10,
                  border: `1px solid ${T.line}`, background: T.bgCard, color: T.ink,
                  fontSize: 14, fontFamily: T.body, outline: 'none',
                }}
              />
            </div>
            <div style={{ marginTop: 4 }}>
              <div style={{
                fontFamily: T.display, fontSize: 13, color: T.amber,
                letterSpacing: '.16em', textTransform: 'uppercase', marginBottom: 8,
              }}>Note for kitchen</div>
              <textarea
                style={{
                  width: '100%', padding: '12px 14px', borderRadius: 10,
                  border: `1px solid ${T.line}`, background: T.bgCard, color: T.ink,
                  fontSize: 13, fontFamily: T.body, resize: 'none', outline: 'none',
                }}
                placeholder="e.g. no onion, extra spicy · বিশেষ নির্দেশনা"
                value={note}
                onChange={e => onNote(e.target.value)}
                rows={3}
              />
            </div>
          </>
        )}

        {/* Total */}
        <div style={{ marginTop: 12, padding: '14px 0', borderTop: `1px solid ${T.line}` }}>
          <div style={{
            display: 'flex', justifyContent: 'space-between', alignItems: 'baseline',
            fontFamily: T.display, textTransform: 'uppercase',
          }}>
            <span style={{ fontSize: 18, color: '#fff' }}>Total · মোট</span>
            <span style={{ fontSize: 22, color: T.amber, whiteSpace: 'nowrap' }}>{taka(total)}</span>
          </div>
        </div>
      </div>

      {/* Footer */}
      <div style={{
        position: 'fixed', bottom: 0, left: 0, right: 0,
        padding: '12px 18px 30px',
        borderTop: `1px solid ${T.line}`, background: T.bg, flexShrink: 0,
      }}>
        <button
          style={{
            width: '100%', padding: '15px 16px', borderRadius: 14,
            background: T.ember, color: '#1a0c08', border: 'none',
            fontFamily: T.display, fontSize: 18, textTransform: 'uppercase',
            cursor: 'pointer', letterSpacing: '.04em', fontWeight: 700,
            boxShadow: '0 14px 30px rgba(255,106,61,.35)',
            opacity: (submitting || !deliveryReady) ? 0.5 : 1,
            display: 'flex', justifyContent: 'center', alignItems: 'center', gap: 10,
            WebkitTapHighlightColor: 'transparent',
          }}
          disabled={submitting || !deliveryReady}
          onClick={onPlace}
        >
          {submitting ? 'Placing Order…' : <>Place Order · অর্ডার করুন <span style={{ fontSize: 20 }}>→</span></>}
        </button>
      </div>
    </div>
  )
}

function AddressAssistSection({ geo, currentAddress, onRetry, onUseAddress }) {
  const T = useTokens()
  const isLoading = geo.status === 'locating' || geo.status === 'geocoding'
  const hasAddress = geo.status === 'ready' && geo.address
  const hasError = geo.status === 'error'
  const addressMatches = hasAddress && currentAddress.trim() === geo.address.trim()
  const title = hasAddress ? 'Check delivery address' : isLoading ? 'Finding delivery address' : 'Delivery location'
  const message = hasAddress
    ? geo.address
    : hasError
    ? geo.error
    : geo.status === 'geocoding'
    ? 'Checking the closest street address...'
    : 'Waiting for location permission...'

  return (
    <div style={{
      border: `1px solid ${hasError ? 'rgba(255,106,61,.35)' : T.line}`,
      background: 'rgba(255,243,224,.045)',
      borderRadius: 10,
      overflow: 'hidden',
    }}>
      <div style={{
        padding: 10,
        display: 'flex',
        alignItems: 'flex-start',
        gap: 10,
      }}>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{
            fontFamily: T.display,
            fontSize: 13,
            color: hasError ? T.ember : T.amber,
            textTransform: 'uppercase',
            letterSpacing: '.08em',
            lineHeight: 1.1,
          }}>{title}</div>
          <div style={{
            marginTop: 5,
            color: hasError ? 'rgba(255,166,145,.95)' : T.inkSoft,
            fontSize: 12,
            lineHeight: 1.35,
          }}>{message}</div>
        </div>
        <button
          type="button"
          onClick={onRetry}
          disabled={isLoading}
          style={{
            border: `1px solid ${T.line}`,
            background: isLoading ? 'rgba(255,243,224,.04)' : 'rgba(255,243,224,.08)',
            color: isLoading ? T.inkFaint : T.ink,
            borderRadius: 8,
            padding: '7px 10px',
            fontSize: 12,
            fontFamily: T.body,
            cursor: isLoading ? 'default' : 'pointer',
            whiteSpace: 'nowrap',
          }}
        >
          {isLoading ? 'Checking' : hasError ? 'Retry' : 'Refresh'}
        </button>
      </div>
      {geo.position && (
        <AddressMapPreview position={geo.position} />
      )}
      {hasAddress && !addressMatches && (
        <button
          type="button"
          onClick={onUseAddress}
          style={{
            width: '100%',
            border: 'none',
            borderTop: `1px solid ${T.line}`,
            background: 'rgba(255,181,71,.12)',
            color: T.amber,
            padding: '10px 12px',
            fontFamily: T.display,
            fontSize: 13,
            textTransform: 'uppercase',
            letterSpacing: '.08em',
            cursor: 'pointer',
          }}
        >
          Use detected address
        </button>
      )}
    </div>
  )
}

function AddressMapPreview({ position }) {
  const T = useTokens()
  const mapRef = useRef(null)
  const [failed, setFailed] = useState(false)

  useEffect(() => {
    let cancelled = false
    setFailed(false)

    async function renderMap() {
      try {
        await loadGoogleMapsApi()
        const { Map } = await window.google.maps.importLibrary('maps')
        if (cancelled || !mapRef.current) return
        new Map(mapRef.current, {
          center: position,
          zoom: 17,
          disableDefaultUI: true,
          gestureHandling: 'none',
          keyboardShortcuts: false,
          clickableIcons: false,
        })
      } catch {
        if (!cancelled) setFailed(true)
      }
    }

    renderMap()
    return () => { cancelled = true }
  }, [position.lat, position.lng])

  return (
    <div style={{
      height: 118,
      position: 'relative',
      borderTop: `1px solid ${T.line}`,
      background: T.bgWarm,
      overflow: 'hidden',
    }}>
      {failed ? (
        <div style={{
          height: '100%',
          display: 'grid',
          placeItems: 'center',
          color: T.inkFaint,
          fontSize: 12,
        }}>Map preview unavailable</div>
      ) : (
        <>
          <div ref={mapRef} style={{ height: '100%', width: '100%' }} />
          <div style={{
            position: 'absolute',
            left: '50%',
            top: '50%',
            width: 16,
            height: 16,
            borderRadius: 999,
            background: T.ember,
            border: '2px solid #fff',
            boxShadow: '0 6px 18px rgba(0,0,0,.35)',
            transform: 'translate(-50%, -50%)',
            pointerEvents: 'none',
          }} />
        </>
      )}
    </div>
  )
}

// ── Success Screen ────────────────────────────────────────────────────────────
function SuccessScreen({ order, info, cartItems, onBack }) {
  const T = useTokens()
  const totalItems = cartItems.reduce((s, i) => s + i.qty, 0)

  return (
    <div style={{ minHeight: '100vh', background: T.bg, display: 'flex', flexDirection: 'column', fontFamily: T.body }}>
      <div style={{ flex: 1, overflowY: 'auto', display: 'flex', flexDirection: 'column' }}>
        {/* Hero check */}
        <div style={{
          paddingTop: 90, paddingBottom: 24,
          background: 'radial-gradient(140% 100% at 50% 0%, rgba(255,106,61,.22) 0%, transparent 60%)',
          textAlign: 'center',
        }}>
          <div style={{
            width: 84, height: 84, borderRadius: 42, margin: '0 auto',
            background: T.ember, color: '#1a0c08',
            display: 'grid', placeItems: 'center', fontSize: 42,
            boxShadow: '0 12px 40px rgba(255,106,61,.5)',
          }}>✓</div>
          <div style={{
            fontFamily: T.display, fontSize: 38, textTransform: 'uppercase',
            color: '#fff', marginTop: 18, lineHeight: .95, letterSpacing: '-.01em',
          }}>Order Placed</div>
          <div style={{ marginTop: 8, fontSize: 12, color: T.inkSoft, letterSpacing: '.18em' }}>
            ORDER PLACED · অর্ডার গৃহীত
          </div>
        </div>

        {/* Order number card */}
        <div style={{ padding: '8px 22px 0' }}>
          <div style={{
            padding: '22px 20px 24px', borderRadius: 18,
            background: T.bgCard, border: `1px solid ${T.line}`,
            textAlign: 'center',
          }}>
            <div style={{ fontSize: 10, color: T.inkSoft, letterSpacing: '.3em' }}>ORDER NUMBER</div>
            {order?.serialNumber != null && (
              <div style={{
                fontFamily: T.display, fontSize: 56, color: T.amber, lineHeight: 1,
                marginTop: 6, letterSpacing: '-.01em',
              }}>#{order.serialNumber}</div>
            )}
            <div style={{
              marginTop: 14, paddingTop: 14, borderTop: `1px dashed ${T.line}`,
              display: 'flex', justifyContent: 'space-around', alignItems: 'flex-start', gap: 12,
            }}>
              <div>
                <div style={{ fontSize: 10, color: T.inkSoft, letterSpacing: '.18em' }}>ITEMS</div>
                <div style={{ fontFamily: T.display, fontSize: 22, color: '#fff', marginTop: 3 }}>{totalItems}</div>
              </div>
              <div style={{ width: 1, alignSelf: 'stretch', background: T.line }} />
              <div>
                <div style={{ fontSize: 10, color: T.inkSoft, letterSpacing: '.18em' }}>TOTAL</div>
                <div style={{
                  fontFamily: T.display, fontSize: 22, color: T.amber, marginTop: 3, whiteSpace: 'nowrap',
                }}>{taka(order?.total || 0)}</div>
              </div>
            </div>
          </div>
        </div>

        {info?.restaurantName && (
          <div style={{ padding: '14px 28px 0', textAlign: 'center' }}>
            <div style={{ fontSize: 11, color: T.inkSoft, letterSpacing: '.1em', textTransform: 'uppercase' }}>
              {info.restaurantName}{info.outletName ? ` · ${info.outletName}` : ''}
            </div>
          </div>
        )}

        <div style={{ padding: '16px 28px 12px', textAlign: 'center' }}>
          <div style={{ fontSize: 13, color: T.inkSoft, lineHeight: 1.55 }}>
            Your order is being prepared.<br/>
            Please wait. · অপেক্ষা করুন।
          </div>
        </div>

        <div style={{ flex: 1 }} />

        {/* Download receipt */}
        <div style={{ padding: '8px 18px 16px' }}>
          <button
            style={{
              width: '100%', padding: '14px 16px', borderRadius: 14,
              background: 'rgba(255,243,224,.06)', color: T.ink, border: `1px solid ${T.line}`,
              fontFamily: T.display, fontSize: 15, textTransform: 'uppercase', cursor: 'pointer',
              letterSpacing: '.04em',
              display: 'flex', justifyContent: 'space-between', alignItems: 'center',
              WebkitTapHighlightColor: 'transparent',
            }}
            onClick={() => generateReceipt(order, info, cartItems)}
          >
            <span style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
              <span style={{ fontSize: 18 }}>↓</span>
              <span>Download Receipt · রিসিট</span>
            </span>
            <span style={{ fontSize: 11, color: T.inkSoft, letterSpacing: '.16em' }}>PDF</span>
          </button>
        </div>
      </div>

      {/* Footer CTA */}
      <div style={{
        flexShrink: 0, padding: '12px 18px 30px',
        borderTop: `1px solid ${T.line}`, background: T.bg,
      }}>
        <button
          style={{
            width: '100%', padding: '15px 16px', borderRadius: 14,
            background: T.ember, color: '#1a0c08', border: 'none',
            fontFamily: T.display, fontSize: 18, textTransform: 'uppercase',
            cursor: 'pointer', letterSpacing: '.04em', fontWeight: 700,
            boxShadow: '0 14px 30px rgba(255,106,61,.35)',
            display: 'flex', justifyContent: 'center', alignItems: 'center', gap: 10,
            WebkitTapHighlightColor: 'transparent',
          }}
          onClick={onBack}
        >
          <span>Order Again</span>
          <span style={{ fontSize: 20 }}>→</span>
        </button>
      </div>
    </div>
  )
}
