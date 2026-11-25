// lib/src/app/app_routes.dart — the app's route paths in one place.
//
// The Dart analog of the RN app's expo-router file names (`src/app/*`): every
// screen's URL path as a named constant, so navigation calls and the router
// definition never hardcode a string. Paths mirror the RN routes 1:1.

class AppRoutes {
  const AppRoutes._();

  // Shown only while the saved session is being restored on cold start.
  static const String splash = '/splash';

  // ── Auth area (reachable only when signed OUT) ──
  static const String signIn = '/sign-in';
  static const String signUp = '/sign-up';
  static const String forgotPassword = '/forgot-password';

  // ── Protected area (reachable only when signed IN) ──
  static const String home = '/';
  static const String about = '/about';

  // ── Technician area (real backend JWT auth — separate from customers) ──
  // Staff get their own experience; the customer app (services/booking/cart/…) is
  // off-limits to them, and this area is off-limits to customers. See the router's
  // role-aware guard.
  static const String technicianLogin = '/technician/login';
  static const String technicianHome = '/technician';

  /// Technician job detail — `:id` is the booking/job id. Build with [technicianJobOf].
  static const String technicianJob = '/technician/jobs/:id';
  static String technicianJobOf(String id) => '/technician/jobs/$id';

  /// TEMPORARY — Field Job Portal (see FIELD_PORTAL_REMOVAL.md). Under the
  /// technician area (so [isTechnicianArea] already admits it). Remove this line +
  /// its route at teardown.
  static const String fieldPortal = '/technician/field-portal';

  /// Whether [location] is inside the technician (staff) area — the home or any
  /// `/technician/...` sub-route (jobs, detail), but NOT the public
  /// [technicianLogin]. Used by the guard to admit a signed-in technician and keep
  /// customers out, including the `:id` detail routes a static set can't match.
  static bool isTechnicianArea(String location) =>
      location != technicianLogin &&
      (location == technicianHome || location.startsWith('$technicianHome/'));
  static const String categories = '/categories';
  static const String search = '/search';
  static const String cart = '/cart';

  /// Category services — `:id` is the category id. Build with [categoryOf].
  static const String category = '/category/:id';
  static String categoryOf(String id) => '/category/$id';

  /// Service detail (booking step 1) — `:id` is the service id. Build with [serviceOf].
  static const String service = '/service/:id';
  static String serviceOf(String id) => '/service/$id';

  // Booking flow: service → location → schedule → review → checkout.
  static const String bookingLocation = '/booking/location';
  static const String bookingSchedule = '/booking/schedule';
  static const String bookingReview = '/booking/review';

  static const String checkout = '/checkout';
  static const String checkoutSuccess = '/checkout/success';
  static const String checkoutFailure = '/checkout/failure';

  static const String orders = '/orders';

  /// Booking detail / receipt — `:id` is the booking id. Build with [orderOf].
  static const String order = '/orders/:id';
  static String orderOf(String id) => '/orders/$id';

  /// The public auth routes, as a set — reachable only when NOBODY is signed in
  /// (customer or technician). Includes the technician login as a parallel entry.
  static const Set<String> authRoutes = {
    signIn,
    signUp,
    forgotPassword,
    technicianLogin,
  };
}
