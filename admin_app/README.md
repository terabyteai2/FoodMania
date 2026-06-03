# REs Cloud Admin

Flutter Restaurant POS Admin app for cloud menu, order, sync, and realtime
management through Supabase Edge Functions.

## Multi-Restaurant Flow

This APK is built for selling to many restaurants. On first launch, each
restaurant first completes the bKash sandbox activation gate. After the backend
verifies the payment, the restaurant enters only its restaurant and outlet name.
The app calls `POST /tenants/bootstrap`, creates a separate cloud
restaurant/outlet identity, and stores a private device token internally.
Restaurant owners do not manually paste Supabase keys, API keys, IP addresses,
or ports.

First launch flow:

```txt
Splash -> bKash Sandbox Payment -> Restaurant Setup -> Dashboard
```

## Run

```sh
flutter pub get
flutter run
```

On Linux workstations where Flutter is installed as a Snap, use the host
toolchain launcher to avoid mixing Snap GLib libraries with host GStreamer:

```sh
./tool/run_linux_debug.sh
```

## Android Release

Create a private upload keystore first:

```sh
keytool -genkey -v -keystore android/app/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
cp android/key.properties.example android/key.properties
```

Then edit `android/key.properties` with the same passwords used in `keytool`.
Never commit `android/key.properties` or `.jks` files.

Build Play Store app bundle:

```sh
flutter build appbundle --release
```

Build release APK:

```sh
flutter build apk --release
```

Build POS-terminal release APK:

```sh
tool/build_terminal_apk.sh
```

The terminal APK targets Android 5.1/API 22 for older SUNMI, iMin, and PAX POS
devices. Normal Android builds keep Flutter's default minSdk; only terminal
builds use the lower SDK floor and compatible AndroidX dependency pins. The
helper copies the result to `build/app/outputs/flutter-apk/app-terminal-release.apk`.

The Flutter POS ships with compile‑defaults targeting **`backend/.env`**: **`POS_CLOUD_API_URL`** (HTTPS ngrok base, optional override).

Defaults mirror **`NGROK_STATIC_DOMAIN`** (`POS_NGROK_DOMAIN`; fallback hostname **`kiwi-equator-banknote.ngrok-free.dev`**):

```
embedded HTTPS api URL → POS_CLOUD_API_URL if non‑empty else → https://${POS_NGROK_DOMAIN}
```

All REST calls (and WebSockets to ngrok hosts) send **`ngrok-skip-browser-warning`** so the ngrok HTML interstitial does not appear (which otherwise breaks JSON parsing).

```sh
flutter run \
  --dart-define=POS_NGROK_DOMAIN=my-tunnel.ngrok-free.app \
  --dart-define=POS_CLOUD_API_URL=https://my-tunnel.ngrok-free.app
```

**Sign‑in checklist when using ngrok:**

1. Run the API with a tunnel: **`cd ../backend && bash start_ngrok.sh`** and wait until the log shows **`Public URL (ngrok): https://…`** (if it failed, fix `NGROK_AUTHTOKEN` / `NGROK_STATIC_DOMAIN` in `backend/.env`).
2. **`POS_NGROK_DOMAIN` / `POS_CLOUD_API_URL` must match your reserved hostname** in `.env` (`NGROK_STATIC_DOMAIN`). The fallback `kiwi-equator-banknote.ngrok-free.dev` only works if that is *your* reserved domain.
3. **Staff**: enter the same **`https://…`** base (no trailing slash) under **Restaurant server URL**.

For internal testing without the bKash gate:

```sh
flutter run --dart-define=POS_REQUIRE_BKASH_GATE=false
```

To change the sandbox activation amount at build time:

```sh
flutter build apk --release \
  --dart-define=POS_BKASH_SANDBOX_AMOUNT=10
```

Google manager/staff sign-in needs a Web OAuth client ID so Android can return
an ID token for the backend to verify. The app has the current project client ID
built in, but you can override it for another Google Cloud project:

```sh
flutter build apk --release \
  --dart-define=POS_GOOGLE_WEB_CLIENT_ID=your-web-client-id.apps.googleusercontent.com
```

The app reads Supabase Realtime config from `GET /health`, so no manual Device
token/API key is required in Settings. The private device token is issued by the
backend during the first restaurant setup.

## Cloud

Cloud API:

```txt
https://vnhxfvtpkgykatvbrczn.supabase.co/functions/v1/pos-api
```

First-run setup endpoint:

```txt
POST /tenants/bootstrap
```

bKash sandbox payment endpoints are handled by the same Supabase Edge Function:

```txt
POST /payments/bkash/create
GET /payments/bkash/:paymentId/status
POST /payments/bkash/:paymentId/verify
GET /payments/bkash/callback
```

bKash app key, app secret, username, and password must be configured as
Supabase Function secrets in the backend repo. They are not stored in the APK.

Sandbox checkout test values:

```txt
Wallet: 01770618575
OTP: 123456
PIN: 12121
```

Do not hardcode a generated bKash checkout URL in the app. Each activation
payment must receive a fresh `bkashURL` from the backend after merchant sandbox
credentials are configured.

Menu images selected from the Admin gallery are uploaded to Supabase Storage and
saved as public HTTPS URLs on menu items, so customer web menus can render them
directly.

Cloud realtime uses Supabase Realtime Broadcast topic:

```txt
pos:outlet:<outletId>
```

Customer websites should call the cloud API directly; this app no longer hosts a
local LAN HTTP/WebSocket server.


Note- linux run-cd /home/moon-ahmed/rastarant/admin_app
./tool/run_linux_debug.sh
