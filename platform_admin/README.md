# Rastarant Platform Admin

Company-facing web panel to manage all restaurants, outlets, subscriptions, and payments.

## Prerequisites

- Backend API running at `http://localhost:8000`
- PostgreSQL with existing Rastarant schema
- Platform admin credentials in `backend/.env`:

```env
PLATFORM_ADMIN_EMAIL=admin@yourcompany.com
PLATFORM_ADMIN_PASSWORD=your-strong-password
```

On first backend startup, if no platform admins exist, one is created from these env vars.

## Local development

**Terminal 1 — API**

```bash
cd backend
./start.sh
```

**Terminal 2 — Platform admin UI**

```bash
cd platform_admin
bash start.sh
```

Open [http://localhost:5174](http://localhost:5174) on your laptop.

### Phone on same Wi‑Fi

1. Start the backend: `cd backend && ./start.sh` (already binds to `0.0.0.0:8000`)
2. Start the UI: `cd platform_admin && bash start.sh`
3. On your phone, open the **Phone URL** printed in the terminal, e.g. `http://192.168.1.42:5174`

API calls from the phone go through the Vite proxy on your laptop, so you do not need to change any env vars.

The Vite dev server proxies `/platform/*` requests to `http://127.0.0.1:8000`.

### Optional: custom API URL

If the API is not on localhost:8000:

```bash
VITE_API_BASE_URL=https://your-api.example.com npm run dev
```

## Pages

| Route | Purpose |
|-------|---------|
| `/` | Dashboard stats, recent outlets & payments |
| `/restaurants` | All restaurants and their outlets |
| `/outlets/:id` | Outlet detail: overview, accounts, subscription, payments, orders |
| `/subscriptions` | All outlet subscriptions |
| `/payments` | Payment audit log (UddoktaPay + bKash) |

## Production build (later)

```bash
cd platform_admin
npm run build
```

Output goes to `platform_admin/dist/`. To serve from the FastAPI app, copy to `backend/platform_dist/` and add a `/platform` SPA route in `main.py` (not wired by default).

## API reference

All endpoints are under `/platform` and require `Authorization: Bearer <platform_token>` except `POST /platform/auth/login`.

See backend OpenAPI docs at `http://localhost:8000/docs` (tag: **platform**).
