# Rastarant / Foodmania — সম্পূর্ণ গাইড (A–Z)

এই ডকুমেন্ট **`rastarant`** রিপোজিটরির জন্য একটি **একস্ট্রিম রেফারেন্স ম্যানুয়াল** — মানুষের অপারেশন ছাড়াও **অন্য কোডিং এজেন্ট / AI** ট্রेनিং বা অনবোর্ডিংয়ের জন্য। ইংরেজিতে টেকনিকাল বিবরণ বেশি, যাতে কপি‑পেস্ট ও টুল সার্চ সহজ থাকে।

**স্কোপ:** রুট ফোল্ডার থেকে প্রতিটি **প্রোডাকশন‑রিলেভ্যান্ট অংশ** (ব্যাকএন্ড, Flutter, ওয়েব ফ্রন্টএন্ড, ডিপ্লয়, সমস্ত ভেরিয়েবল, API ক্যাটালগ, অথ ফ্লো, ফাইল মানচিত্র)। **বিবর্জিত স্বতঃএব:** বিল্ড আউটপুট (`**/build/**`, `**/frontend_dist/assets/**`-এর লম্বা হ্যাশড চাঙ্ক), `node_modules/`, `.venv/`, ছবি/ভিডিও বিটফাইল `backend/uploads/` (শুধু ফোল্ডারের *অর্থ* ব্যাখ্যা করা হয়েছে)।

---

<a id="readme2-agents"></a>

## কোডিং এজেন্ট / AI — এই ফাইল কীভাবে ব্যবহার করবেন

1. **সত্যের উৎস (source of truth):** ইনভেরিয়েন্ট বehavior বুঝতে `backend/config.py`, `backend/main.py`, `Restuarent_POS_Admin_APP/lib/...`, `platform_admin/src/api/client.ts` পড়ুন — এই README টেবিল/মানচিত্র সেগুলোর *সিনোপসিস*।
2. **সিক্রেট:** কখনও `.env`, `deploy/.deploy-secrets`, keystore রিপোতে commit করবেন না। ট্রেনিং ডকে সত্যিকারের API কী/পাসওয়ার্ড লিখবেন না — শুধু কী *নাম* লাগে।
3. **API:** সম্পূর্ণ তালিকা নিচে **§১৯**; ইন্টারঅ্যাক্টিভ স্কিমা `{BASE_URL}/docs` (FastAPI OpenAPI)।
4. **মাল্টি‑টেন্যান্সি:** বেশিরভাগ POS রুট `outlet_id` দিয়ে স্কোপড; কাস্টমার পাবলিক রুট `/customer/{outlet_id}/...`; WebSocket রুম = `outlet_id`।

---

## Table of contents

1. [প্রজেক্ট কী এবং কীসের জন্য](#1-প্রজেক্ট-কী-এবং-কীসের-জন্য)
2. [রিপো ফোল্ডার স্ট্রাকচার](#2-রিপো-ফোল্ডার-স্ট্রাকচার)
3. [আর্কিটেকচার এক নজরে](#3-আর্কিটেকচার-এক-নজরে)
4. [প্রিফ্লাইট চেকলিস্ট](#4-প্রিফ্লাইট-চেকলিস্ট)
5. [Backend (FastAPI) — সম্পূর্ণ](#5-backend-fastapi--সম্পূর্ণ)
6. [`.env` ও environment — সম্পূর্ণ রেফারেন্স](#6-env-ভেরিয়েবল--az-টেবিল)
7. [Flutter POS Admin অ্যাপ](#7-flutter-pos-admin-অ্যাপ)
8. [Customer menu (React)](#8-customer-menu-react)
9. [Platform admin (ওয়েব)](#9-platform-admin-ওয়েব)
10. [পেমেন্ট ও সাবস্ক্রিপশন (UddoktaPay / Paymently)](#10-পেমেন্ট-ও-সাবস্ক্রিপশন)
11. [ngrok ও পাবলিক URL](#11-ngrok-ও-পাবলিক-url)
12. [Google Sign-In (ম্যানেজার / স্টাফ)](#12-google-sign-in)
13. [ডিপ্লয় (VPS)](#13-ডিপ্লয়-vps)
14. [নিরাপত্তা ও কখনও কমিট করবেন না](#14-নিরাপত্তা)
15. [সমস্যা সমাধান (Troubleshooting)](#15-troubleshooting)
16. [কী কী ডক করা হয়নি (সীমা)](#readme2-section-16)
17. [রুট ফোল্ডার — সম্পূর্ণ ইন্ডেক্স](#readme2-root-index)
18. [ব্যাকএন্ড — পাইথন মডিউল মানচিত্র](#readme2-backend-map)
19. [HTTP API — সম্পূর্ণ ক্যাটালগ](#readme2-api-catalog)
20. [ডেটাবেজ মডেল ও অথ](#readme2-db-auth)
21. [Flutter — `lib/` ট্রি ও `--dart-define`](#readme2-flutter-map)
22. [Customer menu ও Platform admin — কনফিগ](#readme2-frontends-config)
23. [স্ক্রিপ্ট, বিল্ড, ডিপ্লয় ম্যাট্রিক্স](#readme2-scripts-matrix)

---

## 1. প্রজেক্ট কী এবং কীসের জন্য

| কম্পোনেন্ট | ভূমিকা |
|------------|--------|
| **Flutter `Restuarent_POS_Admin_APP/`** | রেস্টুরেন্ট ম্যানেজার ও স্টাফের POS: মেনু, অর্ডার, ইনভেন্টরি, সেটিংস, সিঙ্ক, Google লগইন |
| **`backend/`** | FastAPI API, JWT ডিভাইস টোকেন, ওয়েবসকেট রিয়েলটাইম, ফাইল আপলোড (লোকাল বা R2), পেমেন্ট এন্ডপয়েন্ট |
| **`customer_menu/frontend/`** | গ্রাহকের মেনু অর্ডার UI (React / Vite); বিল্ড আউটপুট `backend/frontend_dist/` |
| **`platform_admin/`** | কোম্পানি‑লেভেল প্যানেল: সব আউটলেট, সাবস্ক্রিপশন, পেমেন্ট লগ |
| **`deploy/`** | VPS বুটস্ট্র্যাপ ও রিডিপ্লয় স্ক্রিপ্ট |
| **`render.yaml`** | Render.com ব্লুপ্রিন্ট (Postgres + Python web) |
| **`DEPLOY.md`** | Render + R2 ইন বাংলা স্টেপ‑বাই‑স্টেপ |

মাল্টি‑টেন্যান্ট: প্রতি আউটলেট আলাদা `outlet_id` / `server_id`; Flutter অ্যাপ SQLite টেন্যান্ট‑স্কোপড। `customer_menu/backend/` এই রিপোতে খালি — কাস্টমার UI শুধু **`customer_menu/frontend/`**।

---

## 2. রিপো ফোল্ডার স্ট্রাকচার

```
rastarant/
├── README.md                 # সংক্ষিপ্ত সেটআপ (নতুন PC)
├── README2.md                # এই ফাইল — A–Z + এজেন্ট রেফারেন্স
├── DEPLOY.md                 # Render + R2 গাইড
├── render.yaml               # Render ব্লুপ্রিন্ট
├── .gitignore                # ট্র্যাক ব্যতীত লিস্ট — §১৭ তে আরও
├── backend/                  # Python FastAPI
│   ├── .env                  # লোকাল সিক্রেট (git‑এ থাকে না)
│   ├── .env.example          # টেমপ্লেট
│   ├── main.py               # অ্যাপ এন্ট্রি, ngrok লাইফস্প্যান, SPA মাউন্ট
│   ├── config.py             # pydantic-settings, সব ইনভেরিয়েন্ট
│   ├── database.py           # async engine + create_tables + ছোট migrations
│   ├── models.py             # SQLAlchemy মডেল
│   ├── schemas.py            # Pydantic স্কিমা (API টাইপস)
│   ├── auth.py               # bcrypt, ডিভাইস JWT, প্ল্যাটফর্ম JWT
│   ├── storage.py            # লোকাল ডিস্ক অথবা R2 আপলোড
│   ├── client_api_base.py    # `publicApiBaseUrl` ইনফার (X‑Forwarded‑* হেডার)
│   ├── payment_urls.py       # redirect বেস HTTPS বাছাই
│   ├── uddoktapay_client.py # গেটওয়ে HTTP ক্লায়েন্ট
│   ├── subscription_service.py
│   ├── requirements.txt
│   ├── start.sh               # LAN, ngrok ছাড়া
│   ├── start_ngrok.sh       # ngrok + সাধারণত ফ্রন্টএন্ড বিল্ড ট্রিগার
│   ├── start_cloudflare.sh
│   ├── build_frontend.sh     # customer_menu → frontend_dist
│   ├── routers/               # বিভক্ত রাউট মডিউল — §১৯
│   ├── frontend_dist/         # Vite বিল্ড করা কাস্টমার SPA (+ assets/)
│   └── uploads/               # রানটাইম আপলোড (menu_images, hero_media, …)
├── Restuarent_POS_Admin_APP/  # Flutter monorepo অ্যাপ
├── customer_menu/frontend/    # রিঅ্যাক্ট মেনু সোর্স
├── platform_admin/            # Vite React প্ল্যাটফর্ম UI
└── deploy/                   # VPS (bootstrap/redeploy/README)
```

---

## 3. আর্কিটেকচার এক নজরে

```text
[Flutter POS] --- HTTPS REST + WSS ---> [FastAPI backend] <--> [PostgreSQL]
      |                                           |
      |                                           +--> [uploads/ or Cloudflare R2]
      |
[Customer phone browser] ---> same-origin /customer/* + /uploads ---> React SPA (frontend_dist)
      SPA route also: GET /menu/* -> index.html (hash router style path)

[Platform admin browser] ---> Vite proxy /platform --> FastAPI OR direct VITE_API_BASE_URL

[UddoktaPay / Paymently] <--- checkout + verify ---> backend /payments/uddokta/*
```

---

## 4. প্রিফ্লাইট চেকলিস্ট

- **PostgreSQL** চালু; `DATABASE_URL` এর মান যেন `postgresql+asyncpg://...` বা সাধারণ `postgresql://` (কোড auto `+asyncpg` যোগ করতে পারে) — বিস্তারিত §৬
- **`backend/.env`** — `cp .env.example .env` করে পূরণ
- Python **3.10+** (Render ব্লুপ্রিন্ট 3.11.9 ব্যবহার করে)
- Flutter **SDK** — `Restuarent_POS_Admin_APP/pubspec.yaml` এর `environment.sdk`
- Node **18+** — customer menu ও `platform_admin`
- **ফ্রন্ট বিল্ড:** কাস্টমার মেনু সার্ভ করতে চাইলে `backend/frontend_dist/` আপডেট (`bash build_frontend.sh`)
- **সিক্রেট** কমিট করবেন না

---

## 5. Backend (FastAPI) — সম্পূর্ণ

### চালানো

| স্ক্রিপ্ট / কমান্ড | উদ্দেশ্য |
|---------------------|----------|
| `bash start.sh` | LAN IP + পোর্ট 8000; ngrok অফ; `BASE_URL` লোকাল হিসেবে সেট |
| `bash start_ngrok.sh` | pyngrok টানেল; সফল হলে `settings.BASE_URL` পাবলিক HTTPS |
| `python main.py` | `uvicorn main:app` — `PORT` env (ডিফল্ট 8000); `RENDER` env সেট থাকলে `reload=False` |
| `uvicorn main:app --host 0.0.0.0 --port $PORT` | প্রড (Render `startCommand`) |

API ডক: `{BASE_URL}/docs`  
হেলথ: `{BASE_URL}/health`

### প্রধান রাউটার (high level)

- **health** — স্ট্যাটাস  
- **tenants** — `POST /tenants/bootstrap`  
- **admin** — লগইন, Google, স্টাফ CRUD  
- **devices** — ডিভাইস রেজিস্টার  
- **menu, orders** — আউটলেট‑স্কোপড  
- **payments** — bKash স্টাব + UddoktaPay  
- **ws** — `WebSocket /ws/{outlet_id}?token=...`  
- **customer** — পাবলিক কাস্টমার JSON API  
- **platform** — `/platform/*` Bearer (প্ল্যাটফর্ম অ্যাডমিন)  

সম্পূর্ণ পাথ তালিকা **§১৯**।

### স্ট্যাটিক ও মেনু SPA

- `/uploads` — স্ট্যাটিক ফাইল সার্ভ (`StaticFiles` → `uploads` ডিরেক্টরি)  
- `/assets/*` — Vite বিল্ড JS/CSS (যদি `frontend_dist/assets` থাকে)  
- `GET /menu/{full_path:path}` — সবসময় `frontend_dist/index.html` (কাস্টমার SPA)  
- `GET /` — বিল্ড থাকলে `index.html`, নইলে redirect `/docs`  

### `publicApiBaseUrl` (স্টাফ সিঙ্ক URL)

`client_api_base.client_visible_api_base(request)` — `X-Forwarded-Proto`, `X-Forwarded-Host`, অথবা `Host` থেকে ক্লায়েন্ট‑দৃশ্য বেস URL। Flutter স্টাফ ফ্লো একই HTTPS হোস্ট ব্যবহার করা উচিত।

---

## 6. `.env` ও environment — সম্পূর্ণ রেফারেন্স

**লোডিং:** `backend/config.py` → `class Settings(BaseSettings)` with `env_file=".env"`, `extra="ignore"`. অর্থাৎ `.env` এ অতিরিক্ত কী থাকলে ক্রাশ হবে না।

**প্রসেস‑লেভেল (main.py এ সরাসরি, `config.py` এ নেই):**

| Variable | ডিফল্ট / অর্থ |
|----------|----------------|
| `PORT` | `8000` — `main.py` `os.environ.get("PORT", 8000)` |
| `RENDER` | যেকোনো truthy থাকলে `uvicorn` `reload=False` (ক্লাউড ডিপ্লয়) |

### ব্যাকএন্ড `Settings` টেবিল (`.env` কী = ফিল্ড নাম)

| Variable | টাইপ | কোডে ডিফল্ট | বাধ্যতা | ভূমিকা |
|----------|------|-------------|---------|--------|
| `DATABASE_URL` | `str` | `postgresql+asyncpg://postgres:password@localhost/rastarant` | প্রডে হ্যাঁ | async SQLAlchemy engine; `postgres://` বা `postgresql://` এলে `+asyncpg` যোগ হয় |
| `SECRET_KEY` | `str` | `change-me` | হ্যাঁ | JWT সাইন (ডিভাইস + প্ল্যাটফর্ম); bcrypt আলাদা |
| `IMAGES_DIR` | `str` | `./uploads/menu_images` | না | মেনু ইমেজ লোকাল পাথ; startup এ `makedirs` |
| `HERO_MEDIA_DIR` | `str` | `./uploads/hero_media` | না | আউটলেট হিরো মিডিয়া রুট; সাবফোল্ডারে `video/`, `images/` |
| `OUTLET_IMAGES_DIR` | `str` | `./uploads/outlet_images` | না | লেগাসি আউটলেট ইমেজ |
| `OUTLET_VIDEOS_DIR` | `str` | `./uploads/outlet_videos` | না | লেগাসি ভিডিও |
| `VIDEO_MAX_BYTES` | `int` | `52428800` (50MB) | না | আপলোড সীমা |
| `BASE_URL` | `str` | `http://localhost:8000` | গুরুত্বপূর্ণ | পাবলিক API বেস; ngrok সফল হলে স্টার্টআপে ওভাররাইড; redirect / লিংক তৈরি |
| `GOOGLE_CLIENT_IDS` | `str` | `""` | Google লগইনের জন্য | কমা‑সেপারেটেড OAuth client IDs (Web/Android ইত্যাদি) |
| `NGROK_AUTHTOKEN` | `str` | `""` | ngrok দরকার হলে | pyngrok |
| `NGROK_STATIC_DOMAIN` | `str` | `""` | স্ট্যাটিক ডোমেইনে | hostname বা `https://...`; `payment_urls.payment_callback_base()` এ অগ্রাধিকার |
| `R2_ENDPOINT` | `str` | `""` | R2 চালু করতে সব R2 কী লাগে | S3‑সম 호환 endpoint |
| `R2_ACCESS_KEY_ID` | `str` | `""` | ↑ | |
| `R2_SECRET_ACCESS_KEY` | `str` | `""` | ↑ | |
| `R2_BUCKET` | `str` | `""` | ↑ | বাকেট নাম |
| `R2_PUBLIC_BASE_URL` | `str` | `""` | পাবলিক URL দিতে | যেমন `https://pub-....r2.dev` |
| `PORT` | `int` | `8000` | না | pydantic‑এ আছে; তবে **main entry** আসলে `os.environ.PORT` ব্যবহার করে — Render এ `$PORT` সেট করুন |
| `UDDOKTAPAY_BASE_URL` | `str` | `""` | চেকআউটে হ্যাঁ (অথবা ডিফল্ট) | **শুধু গেটওয়ে রুট** — শেষে `/api` দেবেন না (`uddoktapay_client` পাথ লাগায়) |
| `UDDOKTAPAY_API_KEY` | `str` | `""` | সার্ভার‑সাইড চেকআউটের জন্য | ক্লায়েন্ট APK তে দেয়া যাবে না |
| `UDDOKTAPAY_SANDBOX` | `bool` | `false` | না | `true` হলে বেস ডিফল্ট `sandbox.uddoktapay.com`; খালি `UDDOKTAPAY_BASE_URL` এর সাথে `resolved_uddokta_base_url()` ব্যবহার |
| `PLATFORM_ADMIN_EMAIL` | `str` | `""` | প্রথম সীড জন্য সুপারিশ | ডিবি তে প্ল্যাটফর্ম অ্যাডমিন নেই থাকলে তৈরি |
| `PLATFORM_ADMIN_PASSWORD` | `str` | `""` | ↑ | bcrypt hash সংরক্ষিত |

### Uddokta বেস URL রিসল্যুশন

`config.resolved_uddokta_base_url()`:

- যদি `UDDOKTAPAY_BASE_URL.strip()` খালি না → সেটাই (ট্রেলিং `/api` কোডে স্ট্রিপ/নর্মালাইজ হতে পারে — ক্লায়েন্টে ডাবল `/api/api` এড়াতে শুধু রুট হোস্ট দিন)
- খালি হলে: `UDDOKTAPAY_SANDBOX` true → `https://sandbox.uddoktapay.com`, নইলে `https://pay.uddoktapay.com`

### টেমপ্লেট ফাইল

| File | উদ্দেশ্য |
|------|----------|
| `backend/.env.example` | মানুষ/এজেন্টের জন্য কপি‑পেস্ট টেমপ্লেট (ngrok/Uddokta/প্ল্যাটফর্ম নোট সহ) |

---

## 7. Flutter POS Admin অ্যাপ

পাথ: `Restuarent_POS_Admin_APP/`

### রান

```bash
cd Restuarent_POS_Admin_APP
flutter pub get
flutter run
```

### ক্লাউড API URL (`lib/src/core/constants/cloud_defaults.dart`)

- **`POS_NGROK_DOMAIN`** — শুধু হোস্ট; খালি `POS_CLOUD_API_URL` হলে `https://<host>`  
- **`POS_CLOUD_API_URL`** — পূর্ণ বেস (no trailing slash)  
- ডিফল্ট ngrok হোস্ট কম্পাইল‑টাইমে বান্ডেল (রিপোর স্যাম্পল); প্রোডে `--dart-define` দিয়ে বদলান  
- **`ngrok-skip-browser-warning: true`** — REST ও WS কলে ngrok ফ্রি টিয়ার ইন্টারস্টিশিয়াল এড়াতে  

### ব্যবহারকারী ফ্লো সংক্ষেপে

- **ম্যানেজার** — বুটস্ট্র্যাপ / লগইন / Google; সেটিংস এ Cloud sync URL টেস্ট  
- **স্টাফ** — `mode_intro_screen` এ **Restaurant server URL** ফিল্ড; `publicApiBaseUrl` মিল রাখতে হবে  
- **subscription_checkout_flow** — WebView / Uddokta রিটার্ন  

সম্পূর্ণ **`--dart-define`** তালিকা **§২১**।

---

## 8. Customer menu (React)

- সোর্স: `customer_menu/frontend/`  
- **`App.jsx` এ `API_BASE = ''`** — ব্রাউজারে **একই ওরিজিন** থেকে ফেচ (`/customer/...`, `/uploads/...`). অর্থাৎ সাধারণত FastAPI ডোমেইনে SPA সার্ভ করতে হয়।  
- বিল্ড: `backend/build_frontend.sh` → `backend/frontend_dist/`  
- রেন্ডার ডিপ্লয়ে সাধারণত ব্যাকএন্ডই মেনু সার্ভ করে (`GET /menu/...`)

---

## 9. Platform admin (ওয়েব)

- পাথ: `platform_admin/`  
- `bash start.sh` → `5174` LAN URL প্রিন্ট  
- ডেভ：**Vite প্রক্সি** `vite.config.ts` এ `/platform` → `http://127.0.0.1:8000`  
- ঐচ্ছিক env: **`VITE_API_BASE_URL`** — ফুল ব্যাকএন্ড বেজ (যেমন ক্লাউড); না দিলে ভ্যারিয়েবল খালি → fetch রিলেটিভ  
- লগইন: `POST /platform/auth/login` — ক্রিডেনশিয়াল `PLATFORM_ADMIN_*` থেকে সীড  
- আরও: `platform_admin/README.md`

---

## 10. পেমেন্ট ও সাবস্ক্রিপশন

- **ব্যাকএন্ড:** `POST /payments/uddokta/create`, `verify`, `status`, `return`, `cancel`, `webhook` — বিস্তারিত §১৯  
- **Flutter:** `subscription_checkout_flow.dart`, `bkash_payment_gate_screen.dart`, `PaymentDefaults`  
- **Redirect বেস:** `payment_urls.py` — `NGROK_STATIC_DOMAIN` সেট থাকলে সেটা; নইলে `BASE_URL`  
- **সতর্কতা:** লাইভ পেমেন্টে পাবলিক **HTTPS** (ngrok বা ডোমেইন); LAN IP ব্লক হতে পারে  

---

## 11. ngrok ও পাবলিক URL

1. `.env`: `NGROK_AUTHTOKEN`, `NGROK_STATIC_DOMAIN`  
2. `bash start_ngrok.sh` — টানেল চালু হলে `BASE_URL` আপডেট  
3. Flutter `POS_NGROK_DOMAIN` / `POS_CLOUD_API_URL` **একই হোস্ট** ধরে রাখুন  
4. ngrok ব্রাউজার ওয়ার্নিং: অ্যাপে হেডার ইতিমধ্যে যোগ — পুরনো বিল্ড এড়ান  

---

## 12. Google Sign-In

- ব্যাকএন্ড: `GOOGLE_CLIENT_IDS`  
- Flutter: `POS_GOOGLE_WEB_CLIENT_ID` (`google_auth_defaults.dart`)  
- অ্যান্ড্রয়েড SHA‑1 Firebase/Google Cloud এ রেজিস্টার  
- লগইন রেস্পন্সে **`publicApiBaseUrl`** — স্টাফ সিঙ্ক URL  

---

## 13. ডিপ্লয় VPS

- **`deploy/bootstrap_vps.sh`**, **`deploy/redeploy.sh`**, **`deploy/README.md`**  
- **`DEPLOY.md`** — Render path  
- প্রড:**`BASE_URL`** পাবলিক `https://...`  

---

## 14. নিরাপত্তা

**কখনও git‑এ যাবে না:** `.env`, `**/key.properties`, `*.jks`, `deploy/.deploy-secrets*`, আসল API কী  

**রেন্ডার `render.yaml`:** `SECRET_KEY` generate, R2 কী ম্যানুয়াল  

---

## 15. Troubleshooting

| সমস্যা | সমাধান |
|--------|--------|
| Flutter JSON পার্স/ngrok HTML | `ngrok-skip-browser-warning` — নতুন বিল্ড |
| `/api/api/...` ডাবল পাথ | `UDDOKTAPAY_BASE_URL` এ নিচে `/api` দেবেন না |
| Staff API URL | ম্যানেজার সেটিংসের `https` বেসের সাথে মিল |
| WebSocket 4001 | JWT `sub` ≠ `outlet_id` বা টোকেন মেয়াদ |
| `uddokta_redirect_warning` | পাবলিক HTTPS সেট করুন (`NGROK_STATIC_DOMAIN` বা `BASE_URL`) |
| Render sleep | ফ্রি প্ল্যান — কোল্ড স্টার্ট লেটেন্স; আপগ্রেড করে always‑on |

---

<a id="readme2-root-index"></a>

## ১৭. রুট ফোল্ডার — সম্পূর্ণ ইন্ডেক্স

| পাথ | বর্ণনা |
|------|--------|
| `.git/` | গিট মেটADATA |
| `.idea/` | JetBrains IDE (ঐচ্ছিক, লোকাল) |
| `.agents/`, `.claude/`, `.codex/` | টুল‑নির্দিষ্ট চ্যাট/এজেন্ট ডেটা — **প্রোডাক্ট নয়** |
| `.gitignore` | রুট লেভেল ইগনোয়ার নিয়ম (`node_modules`, `__pycache__`, `deploy/.deploy-secrets`, ওসি জাঙ্ক) |
| `README.md` | হিউম্যান কুইকস্টার্ট |
| `README2.md` | এই নথি |
| `DEPLOY.md` | Render+R2 ডিপ্লয় ডক বাংলা |
| `render.yaml` | Render ব্লুপ্রিন্ট — সার্ভিসে `DATABASE_URL`, `BASE_URL`, R2 খালি sync:false |
| `backend/` | API — সম্পূর্ণ §৫, §৬, §১৮, §১৯ |
| `Restuarent_POS_Admin_APP/` | Flutter — §৭, §২১ ; `android/`, `ios/`, `windows/`, `linux/`, `macos/` প্ল্যাটফর্ম স্টাব |
| `customer_menu/` | `frontend/` = সোর্স; `backend/` খালি/placeholder থাকতে পারে |
| `platform_admin/` | Vite টাইপস্ক্রিপ্ট SPA |
| `deploy/` | VPS স্ক্রিপ্ট ও README |

এক্সট্রা ডিজাইন/মক যেমন `Restuarent_POS_Admin_APP/Terafoods (2)/` থাকলে সেগুলো ডিজাইন অ্যাসেট — ওয়ার্কিং ফ্লো POS ব্যাকএন্ডের সাথে বাধ্যতামূলক নয়।

---

<a id="readme2-backend-map"></a>

## ১৮. ব্যাকএন্ড — পাইথন মডিউল মানচিত্র (`backend/`)

| ফাইল | দায়িত্ব |
|------|----------|
| `main.py` | FastAPI অ্যাপ, CORS, স্ট্যাটিক মাউন্ট, ngrok টানেল, SPA routes, global exception → 500 JSON |
| `config.py` | `Settings`, Uddokta বেজ রিসল্ভার, DB URL নর্মালাইজ |
| `database.py` | async engine/sessions; `create_tables`; লাইটওয়ेट `ALTER`/সীড |
| `models.py` | SQLAlchemy ORM টেবিল |
| `schemas.py` | Pydantic অনুরোধ/রেস্পন্স মডেল |
| `auth.py` | bcrypt, ডিভাইস JWT (−১ বছর টাইপ টোকেন), প্ল্যাটফর্ম JWT (৮ ঘণ্টা), `Depends` ওয়েল |
| `storage.py` | `use_r2()` — সব R2 কী পূর্ণ হলে R2, নইলে লোকাল `uploads/` |
| `client_api_base.py` | `client_visible_api_base` — reverse proxy সচেতন পাবলিক বেস |
| `payment_urls.py` | `payment_callback_base`, লোকাল URL সতর্কতা |
| `uddoktapay_client.py` | চেকআউট/ভেরিফাই HTTP |
| `subscription_service.py` | সাবস্ক্রিপশন বিজনেস লজিক (প্ল্যাটফর্ম/আউটলেট) |
| `build_frontend.sh` | NPM ইনস্টল + `customer_menu/frontend` বিল্ড |
| `start.sh` / `start_ngrok.sh` / `start_cloudflare.sh` | লোকাল ডিভ সুবিধা |
| `routers/admin.py` | ম্যানেজার অ্যাকাউন্ট, লগইন, Google |
| `routers/tenants.py` | রেস্টুরেন্ট+আউটলेट বুটস্ট্র্যাপ |
| `routers/devices.py` | ডিভাইস রেজিস্ট্রেশন |
| `routers/menu.py` | মেনু CRUD ও মিডিয়া আপলোড; WS broadcast ট্রিগার |
| `routers/orders.py` | অর্ডার CRUD ও স্ট্যাটাস |
| `routers/customer.py` | পাবলিক মেনু, অর্ডার প্লেইস, ইনফো |
| `routers/payments.py` | bKash ও Uddokta রুট |
| `routers/platform.py` | গ্লোবাল অ্যাডমিন রিপোর্টিং ও CRUD |
| `routers/ws.py` | আউটলেট রুম WebSocket ও ping |
| `routers/health.py` | `/health` |
| `requirements.txt` | পাই ডিপেন্ডেন্সি |
| `frontend_dist/` | বিল্ড আউটপুট স্ট্যাটিক |
| `uploads/` | রানটাইম আপলোড (সাধারণত গিট ট্র্যাক করা হয় না) |

---

<a id="readme2-api-catalog"></a>

## ১৯. HTTP API — সম্পূর্ণ ক্যাটালগ

নিচের পাথ সব **`main.py`** এ রেজিস্টার্ড রাউটের উপর ভিত্তি করে। এর বাইরে ডায়নামিক `GET /menu/*` SPA। প্ল্যাটফর্ম ট্যাগ ডকএ **platform**।

### পাবলিক / ডিভাইস টোকেন ছাড়া

| Method | Path | নোট |
|--------|------|-----|
| GET | `/health` | লোড ও স্ট্যাটাস |
| POST | `/tenants/bootstrap` | নতুন রেস্টুরেন্ট+আউটলেট+ম্যানেজার |
| POST | `/admin/login` | JSON লগইন |
| POST | `/admin/google/start-or-login` | Google id_token ফ্লো |
| POST | `/admin/create` | ম্যানেজার তৈরি (প্রথম অনবোর্ড ফ্লো) |
| POST | `/devices/register` | বডির শনাক্তকরণ → ডিভাইস JWT |

### ডিভাইস JWT লাগা রুট (সাধারণত হেডার `Authorization: Bearer <token>` — বিস্তারিত `{BASE_URL}/docs`)

#### অ্যাডমিন অ্যাকাউন্ট (`/admin/...`)

| Method | Path |
|--------|------|
| GET | `/admin/me` |
| GET | `/admin/staff` |
| POST | `/admin/staff` |
| PATCH | `/admin/staff/{account_id}` |

#### মেনু ও মিডিয়া (`/outlets/...`)

| Method | Path |
|--------|------|
| GET | `/outlets/{outlet_id}/menu` |
| POST | `/outlets/{outlet_id}/menu` |
| PATCH | `/outlets/{outlet_id}/menu/{item_id}` |
| DELETE | `/outlets/{outlet_id}/menu/{item_id}` |
| POST | `/outlets/{outlet_id}/menu/images` |
| POST | `/outlets/{outlet_id}/images` |
| DELETE | `/outlets/{outlet_id}/images/{index}` |
| POST | `/outlets/{outlet_id}/video` |
| PATCH | `/outlets/{outlet_id}/media` |

#### অর্ডার (`/outlets/.../orders`)

| Method | Path |
|--------|------|
| GET | `/outlets/{outlet_id}/orders` |
| POST | `/outlets/{outlet_id}/orders` |
| PATCH | `/outlets/{outlet_id}/orders/{order_id}/status` |

### কাস্টমার (পাবলিক JSON; আউটলেট আইডি ইন পাথ)

| Method | Path |
|--------|------|
| GET | `/customer/{outlet_id}/menu` |
| GET | `/customer/{outlet_id}/info` |
| POST | `/customer/{outlet_id}/orders` |

### পেমেন্ট

| Method | Path |
|--------|------|
| GET | `/payments/config` |
| POST | `/payments/bkash/create` |
| POST | `/payments/bkash/{payment_id}/verify` |
| GET | `/payments/bkash/{payment_id}/status` |
| POST | `/payments/uddokta/create` |
| POST | `/payments/uddokta/{payment_id}/verify` |
| GET | `/payments/uddokta/{payment_id}/status` |
| GET | `/payments/uddokta/return` |
| GET | `/payments/uddokta/cancel` |
| POST | `/payments/uddokta/webhook` |

### প্ল্যাটফর্ম অ্যাডমিন (`/platform`; Bearer প্ল্যাটফর্ম JWT; লগইন ছাড়া শুধু `POST /platform/auth/login`)

| Method | Path |
|--------|------|
| POST | `/platform/auth/login` |
| GET | `/platform/auth/me` |
| GET | `/platform/stats` |
| GET | `/platform/restaurants` |
| GET | `/platform/restaurants/{restaurant_id}` |
| GET | `/platform/outlets` |
| GET | `/platform/outlets/{outlet_id}` |
| PATCH | `/platform/outlets/{outlet_id}` |
| GET | `/platform/outlets/{outlet_id}/accounts` |
| PATCH | `/platform/accounts/{account_id}` |
| GET | `/platform/subscriptions` |
| POST | `/platform/outlets/{outlet_id}/subscription` |
| GET | `/platform/payments` |
| GET | `/platform/outlets/{outlet_id}/orders` |
| GET | `/platform/outlets/{outlet_id}/customer-info` |
| GET | `/platform/system/config` |

### WebSocket

| URL pattern | নোট |
|-------------|-----|
| `GET ws://HOST/ws/{outlet_id}?token=` | ডিভাইস JWT কোয়েরি বা উপযুক্ত উপায়; `payload.sub == outlet_id` |

---

<a id="readme2-db-auth"></a>

## ২০. ডেটাবেজ মডেল ও অথ

### ORM টেবিল (`models.py`)

| Model | টেবিল | মূল ক্ষেত্রসমূহ |
|-------|-------|----------------|
| Restaurant | `restaurants` | `name` |
| Outlet | `outlets` | `restaurant_id`, `name`, `server_id`, `gallery_images` JSONB |
| AdminAccount | `admin_accounts` | `outlet_id`, `email`, `username`, `password_hash?`, `role`, `google_sub?`, `auth_provider` |
| Device | `devices` | ডিভাইস রেজিস্ট্রি |
| MenuItem | `menu_items` | মূল্য, চিত্র URL, ভার্সন, মোছা |
| Order | `orders` | আইটেম অ্যারে JSONB, serialized no. |
| PlatformAdmin | `platform_admins` | গ্লোবাল ওয়েব লগইন |
| OutletSubscription | `outlet_subscriptions` | পরিকল্পনা, মেয়াদ, সেশন সংযোগ |
| BkashSession | `bkash_sessions` | স্টাব পেমেন্ট |
| UddoktaPaySession | `uddoktapay_sessions` | ট্রানজ্যাকশন ট্র্যাকিং |

### JWT

- **ডিভাইস:** `create_device_token(outlet_id, account_id?)` — `auth.py` এ `TOKEN_EXPIRE_DAYS = 365`; HS256; `SECRET_KEY`  
- **প্ল্যাটফর্ম:** `create_platform_token` — `PLATFORM_TOKEN_EXPIRE_HOURS`; payload এ `type: platform`  

### সীডিং

- `database.py` এর `seed_platform_admin()` — ডিবি খালি হলে `PLATFORM_ADMIN_EMAIL`/`PASSWORD`

---

<a id="readme2-flutter-map"></a>

## ২১. Flutter — `lib/` ট্রি ও `--dart-define`

### ডিরেক্টরি মানচিত্র (`Restuarent_POS_Admin_APP/lib/`)

```
lib/
├── main.dart
└── src/
    ├── app.dart / app_controller.dart / app_scope.dart
    ├── core/
    │   ├── constants/cloud_defaults.dart, payment_defaults.dart, google_auth_defaults.dart
    │   ├── theme/app_theme.dart
    │   ├── localization/app_strings.dart
    │   └── widgets/   … UI উপাদান
    ├── features/
    │   ├── splash/ …
    │   ├── setup/tenant_setup_screen.dart
    │   ├── dashboard/dashboard_screen.dart
    │   ├── menu/menu_management_screen.dart
    │   ├── orders/orders_screen.dart
    │   ├── inventory/inventory_screen.dart
    │   ├── settings/, reports/, payments/, sync/
    └── models/, services/ … স্থানীয় ডেটা ও ক্লাউড ক্লায়েন্ট
```

### সমস্ত সংজ্ঞায়িত **`--dart-define`** (এই রিপো সোর্স হতে)

| Define | ডিফল্ট | ব্যবহার |
|--------|--------|---------|
| `POS_NGROK_DOMAIN` | `kiwi-equator-banknote.ngrok-free.app` | হোস্টনেম (বা স্কিম সহ যদি দেওয়া হয়) |
| `POS_CLOUD_API_URL` | `''` | পূর্ণ HTTPS বেজ |
| `POS_CLOUD_SYNC_ENABLED` | `false` | `bool.fromEnvironment` — ফোর্স অন সিন্ক গেট |
| `POS_REQUIRE_BKASH_GATE` | `true` | বিকাশ গেট |
| `POS_BKASH_SANDBOX_AMOUNT` | `'10'` | ডেমো পরিমাণ স্ট্রিং |
| `POS_BKASH_DEMO_MODE` | `false` | রিয়েল গেট ছাড়া ডায়ালগ |
| `POS_USE_UDDOKTAPAY` | `true` | Uddokta চেকআউট ফ্লাগ |
| `POS_GOOGLE_WEB_CLIENT_ID` | built‑in ডিফল্ট স্ট্রিং | Google ID টোকেন এর জন্য Web ক্লায়েন্ট |

### মূল সার্ভিস ফাইল (সংক্ষিপ্ত)

- `cloud_api_service.dart` — REST + ngrok হেডার  
- `cloud_realtime_service.dart` — WebSocket + ngrok হেডার  
- `local_database_service.dart` — SQLite টেন্যান্স ক্যাশে  
- `sync_service.dart` — ক্লায়েন্ট ও সার্ভারের মধ্যে সিঙ্ক  
- `printer_service.dart` — হার্ডওয়্যার প্রিন্ট  
- `system_notification_service.dart` — ডেস্কটপ / অ্যান্ড্রয়েড নোটিফিকেশন

---

<a id="readme2-frontends-config"></a>

## ২২. Customer menu ও Platform admin — কনফিগ

### Customer (`customer_menu/frontend`)

| বিষয় | বিবরণ |
|-------|-------|
| `API_BASE` | সোর্সে `''` — ফ্রন্ট রিলেটিভ URL দিয়ে FastAPI এর সাথে কথা বলে |
| আউটলেট আইডি | সাধারণত ক্যুয়েরি `?outlet=`; ডেভ ডেমো `__demo__` |
| বিল্ড | `npm install` ও `npm run build` করে `vite` আউটপুট `backend`-এ রুট স্ক্রিপ্ট টেনে আনয়ন |

### Platform admin (`platform_admin`)

| বিষয় | বিবরণ |
|-------|-------|
| `VITE_API_BASE_URL` | ঐচ্ছিক — সম্পূর্ণ API ওরজিন যেমন `https://api.example.com`; খালি থাকলে ফেচ একই ওরিজিন (relative) |
| ডেভ প্রক্সি | `/platform` → `localhost:8000` |
| অথ স্টোর | `sessionStorage` key `platform_token` (`client.ts`) |

---

<a id="readme2-scripts-matrix"></a>

## ২৩. স্ক্রিপ্ট, বিল্ড, ডিপ্লয় ম্যাট্রিক্স

| টাস্ক | আদেশ |
|-------|-------|
| ব্যাকএন্ড venv ও চালাতে | রুট ডক ও `Requirements` টেবিল `README.md` |
| ফ্রন্ট মেনু বিল্ড করে সার্ব করতে | `cd backend && bash build_frontend.sh` |
| ngrok দিয়ে টোফোন টেস্ট | `backend/start_ngrok.sh` এবং `.env` ngrok টোকেন |
| প্ল্যাটফর্ম অ্যুআই | `cd platform_admin && bash start.sh` |
| ফ্লাটার ডেভ বিল্ড | `flutter run --dart-define=POS_CLOUD_API_URL=...` ইত্যাদি |
| Render | ড্যাশবোর্ড ও `render.yaml` — `DATABASE_URL`, `BASE_URL=https://*.onrender.com`, R2 টোপলফ তে ম্যানুয়াল |
| VPS | `deploy/bootstrap_vps.sh` / `redeploy.sh` — সিক্রেট `deploy/.deploy-secrets` |

---

## দ্রুত রেফারেন্স — সংক্ষেপ টোকেট এন্ডপয়েন্ট

| Method | Path | টোকেন / নিরাপত্তা টিপস |
|--------|------|-----------------------|
| GET | `/health` | নাই |
| POST | `/tenants/bootstrap` | আংশিক সুরক্ষা ডিজাইন উপর নির্ভর |
| POST | `/admin/login` | পাবলিক |
| POST | `/platform/auth/login` | পাবলিক (প্ল্যাটফর্ম) |
| GET/POST | `/payments/*` ও POS রুট | ভেরিয়েস বিশ্লেষণ §১৯ |

OpenAPI: **`{BASE_URL}/docs`**

---

<a id="readme2-section-16"></a>

## ১৬. কী কী ডক করা হয়নি (স্পষ্ট সীমা)

| টপিক | এই README2 এর অবস্থা |
|-------|-----------------------|
| **প্রতিটি অ্যাসেট বাইট / প্রতিটি জেনেটেড ফাইল** | ডক করা নয় — খুচরা ট্র্যাশ বা হ্যাশ চাঙ্ক অর্থহীন ট্রেনিংয়ের জন্য |
| **`android/` / `ios/` আদ্যন্ত বাইনারি তারা** | কেবল ডিভ পথ ও সাইনিং ডক অন্য README তে সংক্ষেপিত |
| **`node_modules/` `.venv/`** | পুনর্বিন্যাসযোগ্য; শুধু টুলচেইন চেকলিস্ট করুন |
| **লাইভ অপারেটর ডাটাবেজ ব্যাকআপ** | এই ফাইলে নেই — আপনার নিজের ব্যাকআপ পলিসি |
| **ফুল legal/compliance থিম** | পেমেন্ট প্রসেসারের SLA আলাদাভাবে পড়ুন |

**ফাইল সংখ্যা গণনা (ডিবাগ):** পুরো গাছ খুচরা ডক এর চেয়ে টুল ভালো — `find rastarant -type f \( -path '*/node_modules/*' -o … \) -prune -false -o -type f | wc -l`

---

*শেষ আপডেট: রুট টু এন্ড `rastarant` এর জন্য এজেন্ট‑ফ্রেন্ডলি সম্পূর্ণতার দিকে টানা। এন্ডপয়েন্ট/সেটিংস পরিবর্তন হলে `config.py`, `main.py`, `routers/`, ও OpenAPI `/docs` সাথে সিঙ্ক করুন।*
