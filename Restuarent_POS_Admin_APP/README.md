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

The Supabase cloud API URL is built into the app by default. To override it for
staging or another project, pass `POS_CLOUD_API_URL`:

```sh
flutter build apk --release \
  --dart-define=POS_CLOUD_API_URL=https://vnhxfvtpkgykatvbrczn.supabase.co/functions/v1/pos-api \
  --dart-define=POS_CLOUD_SYNC_ENABLED=true
```

For internal testing without the bKash gate:

```sh
flutter run --dart-define=POS_REQUIRE_BKASH_GATE=false
```

To change the sandbox activation amount at build time:

```sh
flutter build apk --release \
  --dart-define=POS_BKASH_SANDBOX_AMOUNT=10
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
