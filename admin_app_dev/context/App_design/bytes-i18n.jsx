/* ============================================================
   Quick Bytes POS — bilingual strings (EN / বাংলা)
   Strict separation: each key has an EN + BN variant. t(lang,key)
   falls back to EN, then the key itself. Localizes nav, titles,
   and high-traffic action labels — the surfaces a non-English
   manager touches most.
   ============================================================ */
const STRINGS = {
  en: {
    // nav
    'nav.menu': 'Menu', 'nav.tables': 'Tables', 'nav.orders': 'Orders', 'nav.stock': 'Stock',
    'nav.more': 'More', 'nav.analytics': 'Analytics', 'nav.tower': 'Live', 
    // titles
    'title.orders': 'Orders', 'title.tables': 'Tables', 'title.stock': 'Stock', 'title.menu': 'Menu',
    'title.more': 'More', 'title.analytics': 'Analytics', 'title.tower': 'Control Tower', 'title.messages': 'Messages',
    'title.settings': 'Settings', 'title.staff': 'Staff', 'title.audit': 'Audit trail',
    // actions
    'act.accept': 'Accept', 'act.stockin': 'Stock in', 'act.count': 'Count', 'act.finishCount': 'Finish count',
    'act.addInv': 'Add to inventory', 'act.scanBill': 'Scan bill', 'act.scan': 'Scan', 'act.newOrder': 'New order',
    'act.printKOT': 'Print KOT', 'act.printBill': 'Print Bill', 'act.done': 'Done', 'act.review': 'Review',
    'act.confirmPrint': 'Confirm & print', 'act.continue': 'Continue', 'act.save': 'Save', 'act.invite': 'Invite staff',
    // roles
    'role.owner': 'Owner', 'role.manager': 'Manager', 'role.waiter': 'Waiter', 'role.viewingAs': 'Viewing as',
    // misc
    'word.ongoing': 'Ongoing', 'word.completed': 'Completed', 'word.pending': 'Pending', 'word.items': 'items',
    'word.search': 'Search orders…', 'word.advanced': 'Advanced', 'word.low': 'Low', 'word.out': 'Out',
    'word.delivery': 'Delivery', 'word.dinein': 'Dine-in', 'word.parcel': 'Parcel', 'word.notifications': 'Notifications',
    'word.markRead': 'Mark all read', 'word.noNotifs': 'You’re all caught up',
  },
  bn: {
    'nav.menu': 'মেনু', 'nav.tables': 'টেবিল', 'nav.orders': 'অর্ডার', 'nav.stock': 'স্টক',
    'nav.more': 'আরও', 'nav.analytics': 'বিশ্লেষণ', 'nav.tower': 'লাইভ',
    'title.orders': 'অর্ডার', 'title.tables': 'টেবিল', 'title.stock': 'স্টক', 'title.menu': 'মেনু',
    'title.more': 'আরও', 'title.analytics': 'বিশ্লেষণ', 'title.tower': 'কন্ট্রোল টাওয়ার', 'title.messages': 'মেসেজ',
    'title.settings': 'সেটিংস', 'title.staff': 'স্টাফ', 'title.audit': 'অডিট লগ',
    'act.accept': 'গ্রহণ করুন', 'act.stockin': 'স্টক ইন', 'act.count': 'গণনা', 'act.finishCount': 'গণনা শেষ',
    'act.addInv': 'স্টকে যোগ করুন', 'act.scanBill': 'বিল স্ক্যান', 'act.scan': 'স্ক্যান', 'act.newOrder': 'নতুন অর্ডার',
    'act.printKOT': 'KOT প্রিন্ট', 'act.printBill': 'বিল প্রিন্ট', 'act.done': 'সম্পন্ন', 'act.review': 'রিভিউ',
    'act.confirmPrint': 'নিশ্চিত ও প্রিন্ট', 'act.continue': 'এগিয়ে যান', 'act.save': 'সেভ', 'act.invite': 'স্টাফ আমন্ত্রণ',
    'role.owner': 'মালিক', 'role.manager': 'ম্যানেজার', 'role.waiter': 'ওয়েটার', 'role.viewingAs': 'দেখছেন',
    'word.ongoing': 'চলমান', 'word.completed': 'সম্পন্ন', 'word.pending': 'অপেক্ষমাণ', 'word.items': 'আইটেম',
    'word.search': 'অর্ডার খুঁজুন…', 'word.advanced': 'অ্যাডভান্সড', 'word.low': 'কম', 'word.out': 'শেষ',
    'word.delivery': 'ডেলিভারি', 'word.dinein': 'ডাইন-ইন', 'word.parcel': 'পার্সেল', 'word.notifications': 'নোটিফিকেশন',
    'word.markRead': 'সব পঠিত করুন', 'word.noNotifs': 'সব দেখা হয়ে গেছে',
  },
};
function makeT(lang) { const d = STRINGS[lang] || STRINGS.en; return (key) => d[key] || STRINGS.en[key] || key; }

Object.assign(window, { STRINGS, makeT });
