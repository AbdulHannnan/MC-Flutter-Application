# Config — environment

The app is configured with **compile-time** values passed via
`--dart-define-from-file`. Each key is read once in
[`lib/src/config/app_config.dart`](../lib/src/config/app_config.dart) and exposed
as a typed `config` object. Nothing is hardcoded at call sites and nothing
sensitive lives here.

The app talks to **one backend: Supabase** (Auth + RLS-guarded catalog reads + the
booking/technician Edge Functions). There are no backend-selection flags — the only
config is which project to talk to.

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

Then fill in `SUPABASE_URL` + `SUPABASE_ANON_KEY` from Supabase → Project Settings →
API.

## Keys

| Key | Values | Default | Meaning |
|---|---|---|---|
| `APP_ENV` | `development` \| `preview` \| `production` | `development` | Which environment this build represents. |
| `SUPABASE_URL` | URL | *(empty)* | **Supabase** project URL (`https://<ref>.supabase.co`). The whole backend: Auth, catalog reads, and Edge Functions at `<SUPABASE_URL>/functions/v1/<fn>`. The app needs this to reach Supabase. |
| `SUPABASE_ANON_KEY` | string | *(empty)* | Supabase **anon/publishable** key. **Frontend-safe by design** — it only identifies the project at the API gateway; Row-Level Security guards the data. Not a secret. **Never** the `service_role` key. |
| `PUSH_MODE` | `mock` \| `live` | `mock` | `mock` = local notifications only; `live` = attempt remote push token. |

Any value other than the exact expected token falls back to the **safe** value, so
a typo can't silently change behaviour.

> **Server-side-only secrets** — do **not** put these here or ship them to the
> device: the Supabase **`service_role`** key, and any payment/CRM/email provider
> keys. They live on the server (Edge Functions), not in the app. (The Supabase
> **anon** key above is the public exception — it's meant to ship to clients.)

## Running with config

```bash
flutter run -d chrome --dart-define-from-file=config/dev.json
```

The boot screen prints the resolved config so you can confirm the build read it.
