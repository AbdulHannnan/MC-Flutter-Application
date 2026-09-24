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
| `API_BASE_URL` | URL | `http://localhost:5050` | Base URL of the **booking backend**. The app talks ONLY to this over HTTP — never MySQL (3306), never the CRM (4000). |
| `CATALOG_MODE` | `live` \| `mock` | `live` | `live` = `GET /api/services` + `/api/addons`; `mock` = in-repo seed data. |
| `BOOKINGS_MODE` | `live` \| `mock` | `live` | `live` = `POST /api/bookings/draft`; `mock` = local storage. |
| `PAYMENTS_MODE` | `mock` \| `live` | `mock` | `mock` = in-repo N-Genius mock; `live` = real SDK + merchant server. |
| `NGENIUS_ENV` | `sandbox` \| `production` | `sandbox` | Which N-Genius environment the `live` payments path targets. |
| `PUSH_MODE` | `mock` \| `live` | `mock` | `mock` = local notifications only; `live` = attempt remote push token. |

Any value other than the exact expected token falls back to the **safe** value
(`mock` for the flags), so a typo can never silently point a build at the wrong
data source.

> **Server-side-only secrets** (rule #7) — do **not** put these here or ship them
> to the device: `NGENIUS_API_KEY`, `NGENIUS_OUTLET_REF`, `NGENIUS_REALM`,
> `NGENIUS_WEBHOOK_SECRET`, email/CRM provider keys. They live on the merchant
> backend, not in the app.

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
