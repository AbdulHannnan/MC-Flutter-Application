# Config — environment & feature flags (Module 2)

The app is configured with **compile-time** values passed via
`--dart-define-from-file`. Each key is read once in
[`lib/src/config/app_config.dart`](../lib/src/config/app_config.dart) and exposed
as a typed `config` object. Nothing is hardcoded at call sites (rule #8) and
nothing sensitive lives here (rule #7).

This mirrors the RN app's `.env` → `app.config.ts` → `expo-constants` flow.

## Files

| File | Committed? | Purpose |
|---|---|---|
| `example.json` | ✅ yes | Template. Documents every key. Contains no secrets. |
| `dev.json`     | ❌ git-ignored | Your local values. Copy from `example.json`. |

**First run / fresh clone:**

```bash
cp config/example.json config/dev.json   # macOS/Linux
Copy-Item config/example.json config/dev.json   # Windows PowerShell
```

If you skip this, the app still boots on the built-in defaults (below) — the
`--dart-define-from-file` just makes them explicit and overridable.

## Keys

| Key | Values | Default | Meaning |
|---|---|---|---|
| `APP_ENV` | `development` \| `preview` \| `production` | `development` | Which environment this build represents. |
| `API_BASE_URL` | URL | `http://localhost:5050` | Base URL of the **legacy Express booking backend**. The migration fallback — each path moves to Supabase one proven module at a time. Never MySQL (3306), never the CRM (4000). |
| `SUPABASE_URL` | URL | *(empty)* | **Supabase** project URL (`https://<ref>.supabase.co`). Target of the migrated customer auth / catalog / booking-write and technician paths (Edge Functions at `<SUPABASE_URL>/functions/v1/<fn>`). Empty ⇒ Supabase is skipped and the app runs on the Express/mock fallbacks. |
| `SUPABASE_ANON_KEY` | string | *(empty)* | Supabase **anon/public** key. **Frontend-safe by design** — it only identifies the project at the API gateway; Row-Level Security guards the data. Treat it like `API_BASE_URL`, not a secret. **Never** the `service_role` key. |
| `CATALOG_MODE` | `live` \| `mock` | `live` | `live` = the real catalog backend; `mock` = in-repo seed data. |
| `CATALOG_BACKEND` | `express` \| `supabase` | `express` | *(migration)* Which backend serves a **live** catalog: `express` (`GET /api/services` + `/api/addons`) or `supabase` (supabase-js reads of `Service`/`Addon`, RLS-guarded). Only takes effect when Supabase is configured. |
| `AUTH_BACKEND` | `mock` \| `supabase` | `mock` | *(migration)* Customer auth source: `mock` (local, dev-only) or `supabase` (real Supabase Auth email/password). Only takes effect when Supabase is configured. |
| `TECHNICIAN_BACKEND` | `express` \| `supabase` | `express` | *(migration)* Technician (staff) auth source: `express` (`/api/technician/*`) or `supabase` (the `technician` Edge Function). Independent of `AUTH_BACKEND` — technician auth is a parallel custom JWT. Only takes effect when Supabase is configured. |
| `BOOKINGS_MODE` | `live` \| `mock` | `live` | `live` = a real booking backend; `mock` = local storage. |
| `BOOKINGS_BACKEND` | `express` \| `supabase` | `express` | *(migration)* Which backend receives a **live** booking: `express` (`POST /api/bookings/draft`) or `supabase` (create-draft → finalize-booking Edge Functions). **Pair with `AUTH_BACKEND=supabase`** — finalize-booking requires a signed-in Supabase session. Only takes effect when Supabase is configured. |
| `PAYMENTS_MODE` | `mock` \| `live` | `mock` | `mock` = in-repo N-Genius mock; `live` = real SDK + merchant server. |
| `NGENIUS_ENV` | `sandbox` \| `production` | `sandbox` | Which N-Genius environment the `live` payments path targets. |
| `PUSH_MODE` | `mock` \| `live` | `mock` | `mock` = local notifications only; `live` = attempt remote push token. |

Any value other than the exact expected token falls back to the **safe** value
(`mock` for the flags), so a typo can never silently point a build at the wrong
data source.

> **Server-side-only secrets** (rule #7) — do **not** put these here or ship them
> to the device: the Supabase **`service_role`** key, `NGENIUS_API_KEY`,
> `NGENIUS_OUTLET_REF`, `NGENIUS_REALM`, `NGENIUS_WEBHOOK_SECRET`, email/CRM
> provider keys. They live on the server (Edge Functions / merchant backend), not
> in the app. (The Supabase **anon** key above is the public exception — it's
> meant to ship to clients.)

## Reaching the backend (port **5050**)

Set `API_BASE_URL` to match how you're testing:

| Target | `API_BASE_URL` |
|---|---|
| **Chrome web (current dev target)** | `http://localhost:5050` |
| iOS simulator | `http://localhost:5050` |
| Android emulator | `http://10.0.2.2:5050` |
| Real phone (same Wi-Fi) | `http://<YOUR_PC_LAN_IP>:5050` (e.g. `http://192.168.1.20:5050`) |

Do **not** use `localhost` on a physical phone — that points at the phone itself.

## Running with config

```bash
flutter run -d chrome --dart-define-from-file=config/dev.json
```

The boot screen prints the resolved config so you can confirm the build read it.
