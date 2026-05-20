# Render Deploy Guide — Rastarant Backend

এই guide টা follow করলে FastAPI backend + PostgreSQL + Cloudflare R2 (file storage) production এ চলে যাবে।

---

## কী কী লাগবে

- GitHub account (repo already: `terabyteai2/FoodMania`)
- Render account → https://render.com (signup free, GitHub login)
- Cloudflare account → https://dash.cloudflare.com (R2 এর জন্য, free)

---

## Step 1 — Code push করো

Latest code (storage abstraction + render.yaml) push:

```bash
cd /home/moon-ahmed/rastarant
git add -A
git commit -m "Add Render deploy config and R2 storage backend"
git push
```

---

## Step 2 — Render এ Blueprint deploy

1. https://dashboard.render.com/blueprints এ যাও
2. **"New Blueprint Instance"** click করো
3. GitHub connect করো → repo select: **FoodMania**
4. Branch: `main` (বা `Moon-backend` — যেটায় তুমি কাজ করছ)
5. Render automatically `render.yaml` detect করবে
6. **"Apply"** click করো

এটা automatically তৈরি করবে:
- ✅ `rastarant-db` — PostgreSQL database (free tier)
- ✅ `rastarant-api` — FastAPI web service

Database প্রথম provision হতে ~2 min, web service deploy হতে ~5 min।

---

## Step 3 — Cloudflare R2 setup (uploads এর জন্য)

### 3a. R2 bucket create
1. https://dash.cloudflare.com → **R2** → **Create bucket**
2. Bucket name: `rastarant-uploads`
3. Location: APAC (Asia)
4. Create

### 3b. Public access enable
1. Bucket → **Settings** → **Public access** → **Allow Access**
2. **R2.dev subdomain** enable করো → একটা URL দেবে যেমন: `https://pub-xxxxxxxxxxxx.r2.dev`
3. এই URL টা save করো (পরে env এ লাগবে)

### 3c. API token তৈরি
1. R2 dashboard → **Manage R2 API Tokens** (top right)
2. **Create API token**
3. Permissions: **Object Read & Write**
4. Bucket: শুধু `rastarant-uploads` select করো
5. Create → Copy:
   - **Access Key ID**
   - **Secret Access Key**
   - **Endpoint** (something like `https://<accountid>.r2.cloudflarestorage.com`)

### 3d. CORS configure (frontend থেকে fetch হবে)
Bucket → **Settings** → **CORS Policy** → Add:
```json
[
  {
    "AllowedOrigins": ["*"],
    "AllowedMethods": ["GET", "PUT", "POST"],
    "AllowedHeaders": ["*"],
    "MaxAgeSeconds": 3600
  }
]
```

---

## Step 4 — Render এ env vars set করো

Render dashboard → `rastarant-api` → **Environment** → **Add Environment Variable**:

| Key | Value |
|-----|-------|
| `R2_ENDPOINT` | `https://<accountid>.r2.cloudflarestorage.com` |
| `R2_ACCESS_KEY_ID` | (Step 3c থেকে) |
| `R2_SECRET_ACCESS_KEY` | (Step 3c থেকে) |
| `R2_BUCKET` | `rastarant-uploads` |
| `R2_PUBLIC_BASE_URL` | `https://pub-xxxxxxxxxxxx.r2.dev` |
| `BASE_URL` | `https://rastarant-api.onrender.com` (deploy এর পরে actual URL দেখে set করো) |

Save করলে service automatically redeploy হবে।

---

## Step 5 — Verify

Deploy complete হলে:

```bash
# Health check
curl https://rastarant-api.onrender.com/health

# API docs
open https://rastarant-api.onrender.com/docs
```

Expected: `{"data":{"status":"ok",...}}`

---

## Step 6 — Flutter app এ backend URL update

`Restuarent_POS_Admin_APP/lib/src/core/constants/cloud_defaults.dart` এ Render URL set করো (যদি hardcoded থাকে):
```dart
const cloudBaseUrl = "https://rastarant-api.onrender.com";
```

---

## ⚠️ Free Tier limitations

- **Web Service:** 15 min idle হলে sleep → প্রথম request slow (~30 sec cold start)
- **Postgres:** 90 দিন পর expire → upgrade না করলে data হারাবে
- **Bandwidth:** 100 GB/month outbound (R2 থেকে egress free)

Production এ গেলে minimum upgrade:
- Postgres: `Basic-256MB` ($7/mo)
- Web Service: `Starter` ($7/mo, always-on)

---

## Troubleshooting

**"connection refused" / postgres errors:**
- `DATABASE_URL` correctly inject হয়েছে কিনা check করো (Environment tab এ দেখো)
- Database `Available` status এ আছে কিনা

**Uploads work করে কিন্তু URL ভেঙে যাচ্ছে:**
- `R2_PUBLIC_BASE_URL` ঠিক আছে কিনা (trailing slash থাকা যাবে না)
- Bucket public access enabled কিনা

**Build fail হচ্ছে:**
- Render logs দেখো → সাধারণত missing dep বা Python version mismatch
- `render.yaml` এ `PYTHON_VERSION` change করতে পারো

**Sleep থেকে wake up slow:**
- UptimeRobot এর মতো service দিয়ে প্রতি 10 min এ `/health` ping করো (workaround)
- বা Starter plan এ upgrade করো
