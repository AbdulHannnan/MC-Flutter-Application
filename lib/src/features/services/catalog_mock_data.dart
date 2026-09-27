// lib/src/features/services/catalog_mock_data.dart — the seed CATALOG (Dart port
// of the RN app's `src/features/services/mockData.ts`), AC services (Dubai).
//
// DECISION (mirrors RN): when `CATALOG_MODE=mock` the catalog is served from this
// in-repo, typed seed dataset instead of the backend, so the app + tests run fully
// offline. When the real backend is used (`CATALOG_MODE=live`, the default), only
// the LIVE branch of [CatalogRepository] runs and this file is untouched.
//
// THE BUSINESS: an AC (air-conditioning) services company operating in Dubai — AC
// cleaning, repair, installation, maintenance and duct/air-quality work. Prices are
// in AED (UAE Dirham); durations are whole minutes.
//
// UNLIKE the live backend (which sends major-unit AED *strings* like "40.00" that
// [Money.fromAed] converts), this seed is already in DOMAIN shape: [Money] in fils
// via [_aed], and ready-built [Service]/[ServiceCategory] objects. So the mock
// branch returns these directly with no adapting — the adapters only run on live
// backend data.
//
// THREE WAYS TO PRICE A SERVICE:
//   • OPTIONS  — single-select variants the user picks ONE of (e.g. "1 unit" vs
//     "2 units"), each with its own price/duration. A service with no options is
//     booked as-is at its base price.
//   • ADD-ONS  — multi-select extras added ON TOP (e.g. "Gas top-up"), each adding
//     its own price and optional extra time.

import '../../models/models.dart';

// ── Tiny builders to keep the data below readable ────────────────────────────

/// Money in AED fils: `_aed(12000)` → AED 120.00. (The seed is already in minor
/// units — no string conversion, unlike the live backend.)
Money _aed(int amountMinor) =>
    Money(amountMinor: amountMinor, currency: CurrencyCode.aed);

/// A TOPICAL image that matches the service/category, served by LoremFlickr:
/// [keywords] are comma-separated tags searched on Flickr (e.g.
/// 'air,conditioner,cleaning') so the photo reflects the title; [lock] pins which
/// matching photo is returned so images are stable and each item is distinct.
/// These URLs are already absolute, so `assetUrl()` passes them through unchanged.
ImageRef _img(String keywords, String alt, int lock) => ImageRef(
      uri: 'https://loremflickr.com/600/400/$keywords?lock=$lock',
      alt: alt,
    );

// ── Shared add-ons ───────────────────────────────────────────────────────────
// Defined once and reused across services so the same extra reads consistently.
// (The user multi-selects any of a service's `addons`.)

class _Addons {
  static final antiBacterial = ServiceAddon(
    id: 'addon_anti_bacterial',
    name: 'Anti-bacterial treatment',
    description: 'Sanitising spray on coils and vents to kill mould and bacteria.',
    price: _aed(4000),
    duration: 20,
  );
  static final filterReplace = ServiceAddon(
    id: 'addon_filter_replace',
    name: 'Filter replacement',
    description: 'Supply and fit a fresh compatible filter.',
    price: _aed(3500),
    duration: 10,
  );
  static final deepCoil = ServiceAddon(
    id: 'addon_deep_coil',
    name: 'Deep coil clean',
    description:
        'Chemical wash of the evaporator/condenser coils for better cooling.',
    price: _aed(6000),
    duration: 30,
  );
  static final gasTopUp = ServiceAddon(
    id: 'addon_gas_top_up',
    name: 'Gas top-up',
    description: 'Refrigerant top-up if levels are found low during the visit.',
    price: _aed(9000),
    duration: 30,
  );
  static final emergency = ServiceAddon(
    id: 'addon_emergency',
    name: 'Emergency same-day',
    description: 'Priority scheduling for a technician on the same day.',
    price: _aed(7500),
    // No added on-site time — it's a scheduling upgrade.
  );
  static final removeOldUnit = ServiceAddon(
    id: 'addon_remove_old_unit',
    name: 'Old unit removal & disposal',
    description: 'Uninstall and responsibly dispose of your old AC unit.',
    price: _aed(8000),
    duration: 30,
  );
  static final copperPiping = ServiceAddon(
    id: 'addon_copper_piping',
    name: 'Extra copper piping (up to 3m)',
    description:
        'Additional insulated copper pipe where the run is longer than standard.',
    price: _aed(12000),
    duration: 30,
  );
  static final drainageFlush = ServiceAddon(
    id: 'addon_drainage_flush',
    name: 'Drainage flush',
    description: 'Clear and flush the condensate drain line to stop water leaks.',
    price: _aed(5000),
    duration: 20,
  );
}

// ── Categories ───────────────────────────────────────────────────────────────
// NOTE: these fine-grained categories exist ONLY in mock mode. The live backend
// has no Category entity, so the live branch browses the single synthetic
// [acServicesCategory] instead (see [CatalogRepository]).

final List<ServiceCategory> kMockCategories = [
  ServiceCategory(
    id: 'cat_ac_cleaning',
    name: 'AC Cleaning',
    slug: 'ac-cleaning',
    description: 'Deep-clean your units for cleaner air and better cooling.',
    image: _img('air,conditioner,cleaning',
        'A technician cleaning a split AC unit', 11),
    sortOrder: 1,
  ),
  ServiceCategory(
    id: 'cat_ac_repair',
    name: 'AC Repair',
    slug: 'ac-repair',
    description: 'Fast fixes for cooling, gas, compressor and controls.',
    image: _img(
        'air,conditioner,repair', 'A technician repairing an air conditioner', 12),
    sortOrder: 2,
  ),
  ServiceCategory(
    id: 'cat_ac_install',
    name: 'AC Installation',
    slug: 'ac-installation',
    description: 'Professional installation of split and window units.',
    image: _img('air,conditioner,installation',
        'Installing a new split AC on a wall', 13),
    sortOrder: 3,
  ),
  ServiceCategory(
    id: 'cat_ac_maintenance',
    name: 'AC Maintenance',
    slug: 'ac-maintenance',
    description: 'Tune-ups and annual contracts to keep AC running all summer.',
    image: _img('air,conditioner,maintenance',
        'Servicing an AC outdoor condenser', 14),
    sortOrder: 4,
  ),
  ServiceCategory(
    id: 'cat_ac_duct',
    name: 'Duct & Air Quality',
    slug: 'duct-air-quality',
    description: 'Duct cleaning and sanitisation for healthier indoor air.',
    image: _img('air,duct,ventilation', 'Air duct cleaning in progress', 15),
    sortOrder: 5,
  ),
];

// ── Services ─────────────────────────────────────────────────────────────────
// basePrice is the "from" price shown on cards — the cheapest option. Services
// with no options (`options: []`) are booked as-is at basePrice/duration.

final List<Service> kMockServices = [
  // AC Cleaning ──────────────────────────────────────────────────────────────
  Service(
    id: 'svc_split_clean',
    categoryId: 'cat_ac_cleaning',
    name: 'Split AC Deep Cleaning',
    slug: 'split-ac-deep-cleaning',
    summary: 'Thorough clean of wall-mounted split units.',
    description:
        'Full service clean of split AC units: indoor unit, filters, blower and '
        'drainage, plus the outdoor condenser. Restores airflow and cooling and '
        'cuts dust and odours. Choose how many units you have.',
    image: _img('air,conditioner,cleaning', 'A clean wall-mounted split AC', 21),
    basePrice: _aed(9900),
    duration: 60,
    rating: 4.8,
    ratingCount: 412,
    options: [
      ServiceOption(id: 'opt_split_1', name: '1 unit', price: _aed(9900), duration: 60),
      ServiceOption(id: 'opt_split_2', name: '2 units', price: _aed(17900), duration: 105),
      ServiceOption(id: 'opt_split_3', name: '3+ units', price: _aed(24900), duration: 150),
    ],
    addons: [_Addons.deepCoil, _Addons.antiBacterial, _Addons.filterReplace],
  ),
  Service(
    id: 'svc_window_clean',
    categoryId: 'cat_ac_cleaning',
    name: 'Window AC Cleaning',
    slug: 'window-ac-cleaning',
    summary: 'Clean and de-dust window/through-wall units.',
    description:
        'We remove, clean and refit window AC units — filters, coils and housing '
        '— so they cool efficiently and run quieter.',
    image: _img('window,air,conditioner', 'A window air-conditioning unit', 22),
    basePrice: _aed(7900),
    duration: 50,
    rating: 4.6,
    ratingCount: 138,
    options: [
      ServiceOption(id: 'opt_window_1', name: '1 unit', price: _aed(7900), duration: 50),
      ServiceOption(id: 'opt_window_2', name: '2 units', price: _aed(13900), duration: 90),
    ],
    addons: [_Addons.antiBacterial, _Addons.filterReplace],
  ),
  Service(
    id: 'svc_central_clean',
    categoryId: 'cat_ac_cleaning',
    name: 'Central / Ducted AC Cleaning',
    slug: 'central-ac-cleaning',
    summary: 'Whole-home ducted system clean.',
    description:
        'A complete clean of your central/ducted AC — air handler, grilles and '
        'accessible ductwork — for consistent cooling across every room.',
    image: _img('air,duct,ventilation', 'A ducted AC air handler unit', 23),
    basePrice: _aed(19900),
    duration: 150,
    rating: 4.7,
    ratingCount: 86,
    options: [
      ServiceOption(id: 'opt_central_apt', name: 'Apartment', price: _aed(19900), duration: 150),
      ServiceOption(id: 'opt_central_villa', name: 'Villa', price: _aed(34900), duration: 240),
    ],
    addons: [_Addons.antiBacterial, _Addons.drainageFlush],
  ),

  // AC Repair ──────────────────────────────────────────────────────────────
  Service(
    id: 'svc_not_cooling',
    categoryId: 'cat_ac_repair',
    name: 'AC Not Cooling — Diagnosis',
    slug: 'ac-not-cooling-diagnosis',
    summary: 'A technician finds why your AC won’t cool.',
    description:
        'A qualified technician inspects your unit to diagnose why it isn’t cooling '
        '— gas, airflow, electrical or drainage — and quotes the fix. The call-out '
        'fee is credited against any repair booked.',
    image: _img('air,conditioner,technician', 'A technician checking an AC unit', 24),
    basePrice: _aed(9900),
    duration: 45,
    rating: 4.7,
    ratingCount: 224,
    options: [], // flat call-out — no sub-service choice
    addons: [_Addons.gasTopUp, _Addons.emergency],
  ),
  Service(
    id: 'svc_gas_refill',
    categoryId: 'cat_ac_repair',
    name: 'AC Gas Refill / Recharge',
    slug: 'ac-gas-refill',
    summary: 'Restore refrigerant to cool properly again.',
    description:
        'We check for leaks, then refill your AC’s refrigerant to the correct level '
        'so it cools as it should. Price depends on the system type.',
    image: _img('air,conditioner,repair', 'Refrigerant gauges on an AC unit', 25),
    basePrice: _aed(16900),
    duration: 60,
    rating: 4.6,
    ratingCount: 175,
    options: [
      ServiceOption(id: 'opt_gas_split', name: 'Split AC', price: _aed(16900), duration: 60),
      ServiceOption(id: 'opt_gas_window', name: 'Window AC', price: _aed(14900), duration: 60),
      ServiceOption(id: 'opt_gas_central', name: 'Central AC', price: _aed(29900), duration: 90),
    ],
    addons: [_Addons.emergency],
  ),
  Service(
    id: 'svc_compressor',
    categoryId: 'cat_ac_repair',
    name: 'Compressor Repair',
    slug: 'compressor-repair',
    summary: 'Repair or replace a failing compressor.',
    description:
        'Diagnosis and repair of compressor faults — the heart of your AC. Where a '
        'replacement is needed, parts are quoted before any work proceeds.',
    image: _img('air,conditioner,compressor', 'An AC outdoor compressor unit', 26),
    basePrice: _aed(24900),
    duration: 120,
    rating: 4.5,
    ratingCount: 63,
    options: [],
    addons: [_Addons.gasTopUp, _Addons.emergency],
  ),
  Service(
    id: 'svc_thermostat',
    categoryId: 'cat_ac_repair',
    name: 'Thermostat & Remote Repair',
    slug: 'thermostat-remote-repair',
    summary: 'Fix unresponsive controls and thermostats.',
    description:
        'We diagnose and repair faulty thermostats, control boards and remotes so '
        'your AC responds correctly to the temperature you set.',
    image: _img('thermostat,temperature', 'An AC wall thermostat', 27),
    basePrice: _aed(12900),
    duration: 45,
    rating: 4.6,
    ratingCount: 51,
    options: [],
    addons: [_Addons.emergency],
  ),

  // AC Installation ──────────────────────────────────────────────────────────
  Service(
    id: 'svc_split_install',
    categoryId: 'cat_ac_install',
    name: 'Split AC Installation',
    slug: 'split-ac-installation',
    summary: 'Professional fitting of a new split unit.',
    description:
        'Mounting and full installation of a new split AC (unit supplied by you): '
        'bracket, standard piping, wiring, vacuum and test. Price depends on unit '
        'size.',
    image: _img('air,conditioner,installation', 'A newly installed split AC unit', 28),
    basePrice: _aed(29900),
    duration: 150,
    rating: 4.8,
    ratingCount: 97,
    options: [
      ServiceOption(id: 'opt_install_15', name: 'Up to 1.5 ton', price: _aed(29900), duration: 150),
      ServiceOption(id: 'opt_install_2', name: '2 ton', price: _aed(34900), duration: 180),
      ServiceOption(id: 'opt_install_25', name: '2.5 ton+', price: _aed(39900), duration: 210),
    ],
    addons: [_Addons.copperPiping, _Addons.removeOldUnit],
  ),
  Service(
    id: 'svc_window_install',
    categoryId: 'cat_ac_install',
    name: 'Window AC Installation',
    slug: 'window-ac-installation',
    summary: 'Secure fitting of a window/through-wall unit.',
    description:
        'Safe, sealed installation of a window AC (unit supplied by you), including '
        'bracket support and a weather-tight finish.',
    image: _img('window,air,conditioner', 'A window AC being installed', 29),
    basePrice: _aed(19900),
    duration: 90,
    rating: 4.5,
    ratingCount: 44,
    options: [],
    addons: [_Addons.removeOldUnit],
  ),

  // AC Maintenance ────────────────────────────────────────────────────────────
  Service(
    id: 'svc_tune_up',
    categoryId: 'cat_ac_maintenance',
    name: 'One-Time AC Tune-Up',
    slug: 'ac-tune-up',
    summary: 'A quick health check and service.',
    description:
        'A preventative service: clean filters, check gas pressure and electricals, '
        'clear drainage and test performance — catching issues before summer peaks.',
    image: _img('air,conditioner,technician', 'A technician servicing an AC', 30),
    basePrice: _aed(8900),
    duration: 45,
    rating: 4.7,
    ratingCount: 190,
    options: [
      ServiceOption(id: 'opt_tune_1', name: '1 unit', price: _aed(8900), duration: 45),
      ServiceOption(id: 'opt_tune_2', name: '2 units', price: _aed(15900), duration: 75),
      ServiceOption(id: 'opt_tune_3', name: '3+ units', price: _aed(21900), duration: 120),
    ],
    addons: [_Addons.filterReplace, _Addons.gasTopUp],
  ),
  Service(
    id: 'svc_amc',
    categoryId: 'cat_ac_maintenance',
    name: 'Annual Maintenance Contract',
    slug: 'annual-maintenance-contract',
    summary: 'Scheduled visits across the year.',
    description:
        'A yearly plan of scheduled maintenance visits so your AC is always '
        'summer-ready — priority booking and discounted repairs included. Choose '
        'your plan.',
    image: _img('air,conditioner,maintenance', 'A maintenance service checklist', 31),
    basePrice: _aed(39900),
    duration: 60,
    rating: 4.9,
    ratingCount: 78,
    options: [
      ServiceOption(id: 'opt_amc_2', name: '2 visits / year', price: _aed(39900), duration: 60),
      ServiceOption(id: 'opt_amc_4', name: '4 visits / year', price: _aed(69900), duration: 60),
    ],
    addons: [],
  ),

  // Duct & Air Quality ────────────────────────────────────────────────────────
  Service(
    id: 'svc_duct_clean',
    categoryId: 'cat_ac_duct',
    name: 'Duct Cleaning',
    slug: 'duct-cleaning',
    summary: 'Clear dust and debris from your ductwork.',
    description:
        'Deep cleaning of your AC ducts to remove built-up dust, allergens and '
        'debris — improving airflow and the air you breathe.',
    image: _img('air,duct,cleaning', 'Cleaning inside an air duct', 32),
    basePrice: _aed(24900),
    duration: 180,
    rating: 4.6,
    ratingCount: 59,
    options: [
      ServiceOption(id: 'opt_duct_apt', name: 'Apartment', price: _aed(24900), duration: 180),
      ServiceOption(id: 'opt_duct_villa', name: 'Villa', price: _aed(44900), duration: 300),
    ],
    addons: [_Addons.antiBacterial],
  ),
  Service(
    id: 'svc_duct_sanitize',
    categoryId: 'cat_ac_duct',
    name: 'Duct Sanitisation',
    slug: 'duct-sanitisation',
    summary: 'Antimicrobial treatment for your ducts.',
    description:
        'An antimicrobial fogging treatment through your duct system to kill mould, '
        'bacteria and odours — ideal after a duct clean or a damp season.',
    image: _img('air,duct,sanitisation', 'Air-quality sanitisation equipment', 33),
    basePrice: _aed(17900),
    duration: 90,
    rating: 4.7,
    ratingCount: 33,
    options: [],
    addons: [],
  ),
];
