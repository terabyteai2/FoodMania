import { useEffect, useState } from 'react'

function readLang() {
  if (typeof window === 'undefined') return 'en'
  const p = new URLSearchParams(window.location.search)
  return p.get('lang') === 'bn' ? 'bn' : 'en'
}

export function useLang() {
  const [lang, setLang] = useState(readLang)
  useEffect(() => {
    function onPop() { setLang(readLang()) }
    window.addEventListener('popstate', onPop)
    return () => window.removeEventListener('popstate', onPop)
  }, [])
  return lang
}

export function toggleLangUrl(lang) {
  if (typeof window === 'undefined') return '#'
  const url = new URL(window.location.href)
  if (lang === 'bn') url.searchParams.set('lang', 'en')
  else url.searchParams.set('lang', 'bn')
  return url.pathname + '?' + url.searchParams.toString()
}

export function pick(item, field, lang) {
  if (!item) return ''
  if (lang === 'bn' && item[`${field}Bn`]) return item[`${field}Bn`]
  return item[`${field}En`] || item[field] || ''
}

const STRINGS = {
  seeMenu:        { en: 'See the Menu',      bn: 'মেনু দেখুন' },
  menu:           { en: 'Menu',               bn: 'মেনু' },
  all:            { en: 'All',                bn: 'সব' },
  yourOrder:      { en: 'Your Order',         bn: 'আপনার অর্ডার' },
  orderSummary:   { en: 'Order Summary',      bn: 'অর্ডার সারসংক্ষেপ' },
  placeOrder:     { en: 'Place Order',        bn: 'অর্ডার দিন' },
  placingOrder:   { en: 'Placing Order…',     bn: 'অর্ডার দেওয়া হচ্ছে…' },
  total:          { en: 'Total',              bn: 'মোট' },
  noItems:        { en: 'No items available', bn: 'কোনো আইটেম নেই' },
  back:           { en: 'Back',               bn: 'পেছনে' },
  backToMenu:     { en: 'Back to Menu',       bn: 'মেনুতে ফিরুন' },
  yourDetails:    { en: 'Your Details',       bn: 'আপনার তথ্য' },
  name:           { en: 'Name',               bn: 'নাম' },
  mobile:         { en: 'Mobile Number',      bn: 'মোবাইল নম্বর' },
  address:        { en: 'Delivery Address',   bn: 'ডেলিভারি ঠিকানা' },
  note:           { en: 'Special Instructions (optional)', bn: 'বিশেষ নির্দেশনা (ঐচ্ছিক)' },
  add:            { en: 'Add',                bn: 'যোগ' },
  remove:         { en: 'Remove',             bn: 'বাদ' },
  orderConfirmed: { en: 'Order Confirmed',    bn: 'অর্ডার নিশ্চিত' },
  orderNumber:    { en: 'Order Number',       bn: 'অর্ডার নম্বর' },
  loading:        { en: 'Loading',            bn: 'লোড হচ্ছে' },
  langToggle:     { en: 'বাংলা',              bn: 'EN' },
  qty:            { en: 'Qty',                bn: 'পরিমাণ' },
  item:           { en: 'Item',               bn: 'আইটেম' },
  amount:         { en: 'Amount',             bn: 'মূল্য' },
  detectingAddress: { en: 'Detecting address…', bn: 'ঠিকানা শনাক্ত হচ্ছে…' },
  useDetected:      { en: 'Use detected address', bn: 'শনাক্ত ঠিকানা ব্যবহার করুন' },
  retry:            { en: 'Retry',              bn: 'আবার চেষ্টা' },
  addToOrder:       { en: 'Add to Order',       bn: 'অর্ডারে যোগ করুন' },
  choose:           { en: 'Choose',             bn: 'বেছে নিন' },
  optionalExtras:   { en: 'Optional Extras',    bn: 'অতিরিক্ত (ঐচ্ছিক)' },
  pinOnMap:         { en: 'Pin on map',         bn: 'মানচিত্রে পিন করুন' },
  confirmLocation:  { en: 'Confirm location',   bn: 'অবস্থান নিশ্চিত করুন' },
  detectingLocation:{ en: 'Finding your location…', bn: 'অবস্থান খোঁজা হচ্ছে…' },
}

export function t(key, lang) {
  const entry = STRINGS[key]
  if (!entry) return key
  return entry[lang] || entry.en
}
