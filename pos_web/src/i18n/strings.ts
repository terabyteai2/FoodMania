// EN + বাংলা strings (mirrors admin_app AppStrings pattern: one getter per key).

export type Lang = 'en' | 'bn';

const dict = {
  appName: { en: 'QuickBytes POS', bn: 'QuickBytes POS' },
  tagline: { en: 'Restaurant billing station', bn: 'রেস্টুরেন্ট বিলিং স্টেশন' },
  signIn: { en: 'Sign in', bn: 'সাইন ইন' },
  password: { en: 'Password', bn: 'পাসওয়ার্ড' },
  usernameOrEmail: { en: 'Username or email', bn: 'ইউজারনেম বা ইমেইল' },
  serverId: { en: 'Server ID', bn: 'সার্ভার আইডি' },
  serverIdHint: { en: 'Same Server ID used in the QuickBytes phone app', bn: 'QuickBytes ফোন অ্যাপের সার্ভার আইডি' },
  phoneOtp: { en: 'Phone OTP', bn: 'ফোন OTP' },
  phoneNumber: { en: 'Phone number', bn: 'ফোন নম্বর' },
  sendCode: { en: 'Send code', bn: 'কোড পাঠান' },
  otpCode: { en: '6-digit code', bn: '৬ সংখ্যার কোড' },
  verify: { en: 'Verify & sign in', bn: 'যাচাই করে সাইন ইন' },
  demoLogin: { en: 'Demo login (dev)', bn: 'ডেমো লগইন (ডেভ)' },
  loggingIn: { en: 'Signing in…', bn: 'সাইন ইন হচ্ছে…' },
  noAccountForPhone: {
    en: 'No account found for this phone. Create your restaurant in the QuickBytes phone app first.',
    bn: 'এই ফোনে কোনো অ্যাকাউন্ট নেই। আগে QuickBytes ফোন অ্যাপে রেস্টুরেন্ট তৈরি করুন।',
  },
  logout: { en: 'Log out', bn: 'লগ আউট' },
  newOrder: { en: 'New Order', bn: 'নতুন অর্ডার' },
  billNo: { en: 'Bill No', bn: 'বিল নং' },
  comingSoon: { en: 'Coming in the next build phase', bn: 'পরবর্তী ধাপে আসছে' },
  offline: { en: 'No internet — reconnecting…', bn: 'ইন্টারনেট নেই — পুনরায় সংযোগ হচ্ছে…' },
  subscriptionBlocked: {
    en: 'This outlet does not have an active subscription. Complete payment from the QuickBytes phone app.',
    bn: 'এই আউটলেটের সাবস্ক্রিপশন সক্রিয় নেই। QuickBytes ফোন অ্যাপ থেকে পেমেন্ট সম্পন্ন করুন।',
  },
  refreshAccess: { en: 'Re-check access', bn: 'আবার যাচাই করুন' },
} as const;

export type StringKey = keyof typeof dict;

export function t(key: StringKey, lang: Lang): string {
  return dict[key][lang];
}
