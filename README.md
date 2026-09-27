# Microcare — Flutter App

A Flutter (Android + iOS, currently developed/tested on **Chrome web**) rebuild of the
existing **React Native (Expo)** customer booking app **"Microcare"** — a customer booking
app for an **AC-servicing business in Dubai** (prices in **AED**).

The backend is **FIXED**; only the frontend is being rebuilt. Goal: recreate the same
screens, the same flow, the same look, and the same API calls — faithfully in Flutter/Dart,
using **idiomatic Flutter** underneath (not an imitation of the RN widget tree).

---

## Authoritative source

The pasted "blueprint" placeholder was **not** filled in, so the **real RN source is the
authoritative reference**:

- **RN app (authoritative):** `/Users/abdulhannan/Projects/MC Mobile Application`
  (Expo SDK 54, `expo-router`, `zustand` + `@tanstack/react-query`, `nativewind`).
- When a detail is missing, **do not invent** — read the cited RN file to recover it
  (e.g. `src/types/location.ts`, `src/constants/*`, `src/features/*/screens/*.tsx`), or ask.

Other related repos on this machine (for reference only — the app talks to **none of them
directly** except the booking backend over HTTP):
- `Micocare Booking System` — the fixed booking backend.
- `MC CRM` / `MC` — CRM portal (port 4000). **Never** contacted from the app.

---

## Tech stack (Flutter rebuild)

| Concern | Choice | RN equivalent |
|---|---|---|
| State management | **Riverpod** (`flutter_riverpod`) | `zustand` stores + `react-query` |
| HTTP client | **dio** (15s timeout, interceptors) | `fetch` wrapper in `src/lib/api.ts` |
| Navigation | **go_router** (stack, redirect guards) | `expo-router` (no tabs, no drawer) |
| Package name | `microcare` | `microcare` |

---

## CRITICAL SCOPE — REAL vs MOCK

### REAL backend calls (only these three — public, no auth)
1. `GET /api/services` — all active services with embedded `options[]`.
2. `GET /api/addons?serviceId={id}` — add-ons for a service.
3. `POST /api/bookings/draft` — **must send `source:"app"`** (top-level, lowercase).

### MOCK / local-only (rebuilt as local mocks, same shapes, no server)
- Authentication (login / signup / forgot) — local, persisted.
- Order history + booking detail — local storage.
- Payments — **N-Genius is mocked** (behind a seam for a real drop-in later).
- The map + "use my location".
- The time-slot grid — generated **client-side**, hourly **09:00–16:00**, Dubai wall-clock
  (**NOT** a server call).

### Mock/live config flags (defaults)
| Flag | Default | Meaning |
|---|---|---|
| `CATALOG_MODE` | **live** | `live` = `GET /api/services` + `/api/addons`; `mock` = seed data |
| `BOOKINGS_MODE` | **live** | `live` = `POST /api/bookings/draft`; `mock` = local storage |
| `PAYMENTS_MODE` | **mock** | N-Genius mock vs real SDK |
| `PUSH_MODE` | **mock** | local notifications only vs remote push token |

---

## HARD RULES

1. Recreate the blueprint's screens, navigation, and visual design closely; use **idiomatic
   Flutter** underneath. Match the **experience**, not the RN widget tree.
2. Match the API contract **exactly** — same endpoints, methods, field names, request/response
   shapes. **Do NOT invent or rename fields.**
3. Every booking MUST send `source:"app"` (top-level, lowercase). **NEVER** send prices in the
   booking body (server computes them). **NEVER** send `userId`.
4. **Money:** backend sends major-unit AED strings (`"40.00"`); the app models money as
   **integer minor units (fils)** internally. Convert at the boundary exactly as the RN app
   does. Display as `AED xx.xx`. **Never use floats for money.**
5. **Response envelope:** success = `{ data: <payload> }` → unwrap to inner value. Errors =
   `{ error: "..." }` (or `{ error, details }` on 422). **15s HTTP timeout.**
6. Image URLs arrive as **relative paths** (`"/images/..."`); prepend the configured API origin
   to make them absolute (`assetUrl()` helper).
7. **No DB credentials anywhere.** Talk ONLY to the booking backend over HTTP. Never the CRM
   (4000), never MySQL (3306).
8. Config via a Dart config file / `--dart-define` — **no hardcoded URLs**. Provide an example
   config.
9. Build in **15 modules, ONE at a time**. After each: stop, summarise, explain how to run/test,
   and **WAIT for "next"**. Each module = one git commit.
10. **Ask before assuming.** Restate each module's goal and list questions first.

**Before Module 14** (the booking submit), re-confirm the exact `POST /api/bookings/draft`
body with the user.

---

## Reaching the backend (backend runs on port 5050)

> ⚠️ **Port note:** the RN repo defaults to `:5000`, but this project uses **`:5050`** per the
> app prompt.

| Target | Base URL |
|---|---|
| Real phone (same Wi-Fi) | `http://<PC-LAN-IP>:5050` |
| Android emulator | `http://10.0.2.2:5050` |
| iOS simulator | `http://localhost:5050` |
| **Chrome web (current dev target)** | `http://localhost:5050` |

> ⚠️ **Chrome/CORS:** unlike native apps, Chrome enforces CORS. The three real endpoints must
> send `Access-Control-Allow-Origin` for the Flutter web origin, or the browser blocks them.
> The backend is fixed, so if it doesn't allow web origins we'll use a dev workaround (proxy or
> a dedicated Chrome dev profile). Addressed when the first real call lands (Module 6).

---

## The 15 Modules

- [x] **Module 1 — Project setup & structure** — Flutter project, folder structure, deps
  (dio + Riverpod), analysis/linting. Builds & runs to a placeholder screen. ✅
- [x] **Module 2 — Config & environment** — typed config (API base URL + the four mock/live
  flags) via `--dart-define-from-file`, with a committed example file (`config/example.json`).
  Device-reachability values documented (`config/README.md`). Boot screen + logs print the
  resolved config to confirm the app reads it. ✅
- [x] **Module 3 — HTTP client & error handling** — dio request wrapper (`ApiClient` +
  `apiClientProvider`): `{ data }` unwrap, `{ error }` / 422 `{ error, details }` parsing,
  15s timeout, timeout/network `ApiException` flags, optional Bearer header (unused for now).
  `assetUrl()` helper to absolutize `"/images/..."` paths. ✅
- [x] **Module 4 — Data models** — `Money` (minor units + currency, `fromAed` conversion +
  `format`), `ServiceCategory` (+ synthetic `acServicesCategory`), `ServiceOption`,
  `ServiceAddon`, `Service`, `LatLng`, `BookingLocation`, `TimeSlot`, `CartAddon`, `CartItem`,
  `BookingStatus`, `Booking` in `lib/src/models/` (barrel `models.dart`). Domain-shape
  `toJson`/`fromJson` for local persistence; backend→domain adapters deferred to Module 6. ✅
- [x] **Module 5 — Design system / theming** — tokens in `lib/src/core/theme/` (`AppColors`
  + `AppPalette`, `AppSpacing`, `AppRadii`, `AppFontSizes`/`AppTextStyles`) recreated from the
  RN `src/constants/*`, composed into `AppTheme.light` (`ThemeData`). Primitives in
  `lib/src/core/widgets/`: `AppText`, `AppButton` (5 variants × 3 sizes, loading/disabled),
  `AppCard`, `CategoryChip`, `StatusPill`. Boot screen restyled as a live proof. ✅
- [x] **Module 6 — Services API + catalog data layer** — `GET /api/services` (with embedded
  `options[]`) and `GET /api/addons?serviceId={id}`; on-device category/search filtering;
  caching layer (react-query equivalent). Fabricate the single synthetic "AC Services" category. ✅
- [x] **Module 7 — Auth screens (MOCK)** — Login, Sign up, Forgot-password with exact fields,
  validation (email regex, password ≥ 8, confirm match), show/hide password, LOCAL mock auth
  (persisted). Auth gates the app like the RN `Stack.Protected` groups. ✅
- [] **Module 8 — Navigation & route guards** — stack-based navigator (no tabs, no drawer).
  Two route sets swapped by auth state; deep-link bounce; cold-start splash while restoring the
  session; booking-flow guards that redirect to the step owning missing draft data. ✅
- [ ] **Module 9 — Home / dashboard** — greeting, My-bookings + cart icons (cart with live
  badge), log out, tappable search pill, horizontal Categories strip ("See all"), vertical
  Popular services (top 5 by rating, client-sorted). Wired to the catalog layer.
- [ ] **Module 10 — Browse screens** — All Categories, Category Services (dynamic header =
  category name), Search (debounced 300ms, autofocus, filter chips, result count). Shared
  `ServiceCard`.
- [ ] **Module 11 — Service Detail (booking step 1)** — hero image, name, description,
  single-select option radios (only if options exist), multi-select add-on checkboxes (only if
  add-ons exist), pinned footer running total + Continue. Edit-mode pre-seeding from Review.
  Starts/updates the booking draft. Fetches that service's add-ons.
- [ ] **Module 12 — Booking Location & Schedule (steps 2–3)** — Location: heading, MOCK map
  panel (styled box + 📍), "use my current location" (mock), address field, 12 Dubai-area preset
  chips; Continue disabled until address/area/pin set. Schedule: custom month calendar (past
  days disabled), client-generated hourly slots 09:00–16:00 (taken/past struck-through), summary
  + Continue. Both guard on draft presence.
- [ ] **Module 13 — Review + Cart (step 4 + cart)** — Review: read-back of Service/Where/When
  each with an Edit link that pops to the owning step (restoring state), editable notes, footer
  total, "Add to cart" (outline) + "Pay now" (primary). Pre-payment revalidation against
  `GET /api/services` (slot open? service active? price drift → info banner + auto-apply;
  taken/removed → blocking banner). Cart: line cards (qty stepper, remove, line total), empty
  state, clear all, subtotal, Checkout. Cart persists locally.
- [ ] **Module 14 — Checkout + Payment (MOCK) + Success/Failure** — Checkout: order summary,
  Phone (required) + Email (prefilled, validated), "Pay {amount}"; empty-cart guard. Payment is
  MOCK behind a seam for the real N-Genius package. On mock success → submit each cart line via
  `POST /api/bookings/draft` with `source:"app"` (sequentially, awaited), fire local
  notifications, clear cart+draft → Success screen (references, amount, txn ref, no back button).
  On failure → Failure screen (reason, "cart still saved", Try again / Back to cart).
  **⚠️ Re-confirm the exact POST body with the user before starting this module.**
- [ ] **Module 15 — Orders + Booking Detail (MOCK) + final polish & verify** — My Bookings list
  (local storage, newest first, empty state) and Booking Detail / digital receipt (schedule,
  location, service lines, notes, payment). Final pass: remaining visuals, loading/empty/error
  states everywhere, and VERIFY end-to-end that a Flutter booking lands in `micocare.booking` as
  `source="app"` and shows in the CRM as **App**.

---

## Out of scope (for now — later, separate work)

Real auth/finalize (bookings stay `DRAFT`), real N-Genius payment via its Flutter package, real
order-history/receipt endpoints (`GET /api/bookings[/:id]` don't exist yet), real availability
endpoint, and EAS/store deployment.

---

## Progress log

| Module | Status | Notes |
|---|---|---|
| 1 — Project setup & structure | ✅ Done | Riverpod + dio; feature folders; lints; boots to placeholder; analyze/test/build-web all green |
| 2 — Config & environment | ✅ Done | Typed `config` via `--dart-define-from-file`; `config/example.json` template + `config/README.md`; boot screen prints resolved config; 5 tests + analyze + build-web green |
| 3 — HTTP client & error handling | ✅ Done | dio `ApiClient` + `apiClientProvider` in `lib/src/core/network/`; `{ data }` unwrap, `ApiException` (timeout/network flags, `{ error }`/422 parsing), 15s timeout, Bearer seam, `assetUrl()`; 14 new tests (19 total) + analyze + build-web green |
| 4 — Data models | ✅ Done | Domain models in `lib/src/models/` (barrel `models.dart`): `Money` (int fils, `fromAed`/`format` ported from `aedToMoney`/`formatMoney`), catalog (`Service`/`ServiceOption`/`ServiceAddon`/`ServiceCategory` + synthetic `acServicesCategory`), `TimeSlot`, `LatLng`/`BookingLocation`, `CartItem`/`CartAddon`, `Booking`/`BookingStatus`; domain-shape JSON round-trips. 22 new tests (41 total) + analyze + build-web green |
| 5 — Design system / theming | ✅ Done | Tokens in `lib/src/core/theme/` (colours, type ramp, spacing, radii) from RN `src/constants/*` → `AppTheme.light`; primitives in `lib/src/core/widgets/` (`AppText`, `AppButton`, `AppCard`, `CategoryChip`, `StatusPill`); boot screen restyled as a live proof. 6 new widget tests (47 total) + analyze + build-web green. **Open: `Money.format` follows RN "99.00 AED" (amount-first) vs README rule #4 "AED xx.xx" — confirm before Module 9 UI.** |
| 6 — Services API + catalog data layer | ✅ Done | `lib/src/features/services/`: `CatalogRepository` (port of RN `servicesApi.ts`) — live `GET /api/services` + `GET /api/addons?serviceId=` with backend→domain adapters (`label`→name, `"40.00"`→`Money.fromAed`, cheapest option→`basePrice`, relative image→`assetUrl`, `duration`→0), single synthetic `ac-services` category, `ServiceQuery`, `ServiceNotFoundError`, on-device category/search filtering; full offline **mock seed** (`catalog_mock_data.dart`, 5 categories / 13 services) ported from RN `mockData.ts`. React-query-equivalent **caching providers** (`catalog_providers.dart`): `categories/category/services/service` as keyed `autoDispose` families, `AsyncValue` = the `QueryResult` seam, `ref.invalidate` = refetch, `cacheFor` staleTime (5m), Riverpod-native `retry:` (2 + backoff via `catalogRetryPolicy`, no-retry-404 via `serviceRetryPolicy`). Boot screen wired as a live catalog proof (loading/error/empty/data). 19 new tests (66 total) + analyze + build-web green. |
| 7 — Auth screens (MOCK) | ✅ Done | `lib/src/features/auth/`: session model (`AuthUser`), pure validation (email regex, password ≥ 8, confirm match) ported from RN `validation.ts`; **local persisted mock backend** (`mock_auth_api.dart`) on `shared_preferences` (new dep; plain/non-secure like RN's AsyncStorage) — signUp/signIn/resetPassword/signOut/getCurrentUser, generic "invalid email or password", duplicate-email guard; consolidated **`SessionController`** (`AsyncNotifier<AuthUser?>`) + `sessionProvider` (restore-on-init; `AsyncValue` tri-state = loading/signedOut/signedIn via `SessionX`) replacing RN's zustand store + AuthProvider + 4 flow hooks. Three screens (Login / Sign up / Forgot-password) with exact fields/copy, show/hide password, per-field + banner errors; new reusable `AppTextField` primitive. 18 new tests (84 total; incl. an e2e sign-up→home→log-out flow) + analyze + build-web green. |
| 8 — Navigation & route guards | ✅ Done | `lib/src/app/`: **go_router** (new dep) `routerProvider` (`app_router.dart`) — the analog of RN's expo-router `_layout.tsx`. Full route tree (`app_routes.dart`) mirroring RN 1:1 (`/`, `/sign-in|sign-up|forgot-password`, `/categories`, `/search`, `/cart`, `/category/:id`, `/service/:id`, `/booking/{location,schedule,review}`, `/checkout{,/success,/failure}`, `/orders{,/:id}`, `/about`), with `PlaceholderScreen` stubs for unbuilt routes. **Auth guard** (`redirect` + `refreshListenable` on `sessionProvider`): restoring → `SplashScreen`; signed-out → any protected path bounces to `/sign-in` (deep-link bounce); signed-in → auth routes/splash bounce to `/`. **Booking-flow guard** seam (per-route `redirect`) currently bounces home (no draft yet; real check lands Modules 11–13). Auth screens rewired to navigate via `context.go/push` (Module 7's `AuthFlow` removed); `main.dart` → `MaterialApp.router`; home is a nav-proof stub keeping the catalog card. 4 net-new router tests (88 total) + analyze + build-web green. |
| 9 → 15 | ⏳ Pending | One at a time, awaiting "next" for each |

---

## How to run (Chrome)

```bash
cd "/Users/abdulhannan/Projects/MC Flutter App"
cp config/example.json config/dev.json   # first run only (git-ignored local config)
flutter run -d chrome --dart-define-from-file=config/dev.json
```

Hot-reload with `r`, full restart `R`, quit `q`. (Config is compile-time, so
changing `config/dev.json` needs a full restart, not hot-reload.) See
[`config/README.md`](config/README.md) for every flag and the device-reachability
table.

**Checks:**
```bash
flutter analyze      # lint
flutter test         # unit/widget tests
flutter build web    # production web build
```
