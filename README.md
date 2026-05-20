# Rastarant / Foodapp

Multi-tenant Restaurant POS system — Flutter admin app + FastAPI backend + customer menu frontend.

## Repo layout
- `Restuarent_POS_Admin_APP/` — Flutter app (Android / iOS / desktop)
- `backend/` — FastAPI server
- `customer_menu/` — Customer-facing React menu

**Full-stack operator guide (architecture, ENV, payments, deploy, troubleshooting):** see [`README2.md`](./README2.md) (Bangla + technical English).

---

## Setting up on a new PC (after `git clone`)

Some files are intentionally **not** in the repo (signing keys, env vars, PC-specific paths). Recreate them as below.

### 1. Backend (`backend/`)
```bash
cp backend/.env.example backend/.env
# then edit backend/.env with your secrets
cd backend
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
```

### 2. Flutter app (`Restuarent_POS_Admin_APP/`)

**a) `android/local.properties`** — auto-generated on first `flutter pub get` / IDE open. Or create manually:
```properties
sdk.dir=/path/to/Android/Sdk
flutter.sdk=/path/to/flutter
flutter.buildMode=debug
flutter.versionName=1.3.1
flutter.versionCode=2
```

**b) `android/key.properties`** — copy from example:
```bash
cp Restuarent_POS_Admin_APP/android/key.properties.example \
   Restuarent_POS_Admin_APP/android/key.properties
# edit storePassword / keyPassword
```

**c) `android/app/upload-keystore.jks`** — copy this file **manually** (USB / secure cloud) from your other PC. It is NOT in git for security. Using a different keystore = different SHA fingerprint = Play Store / Firebase will reject the build.

**d) Install deps:**
```bash
cd Restuarent_POS_Admin_APP
flutter pub get
```

### 3. Customer menu (`customer_menu/frontend/`)
```bash
cd customer_menu/frontend
npm install
```

---

## Files NEVER committed (security / per-PC)
- `**/.env`
- `**/android/local.properties`
- `**/android/key.properties`
- `**/*.jks`, `**/*.keystore`
- `.idea/`, `node_modules/`, `__pycache__/`, `build/`, `.dart_tool/`
