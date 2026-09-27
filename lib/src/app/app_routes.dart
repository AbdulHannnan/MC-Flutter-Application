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

  /// The auth routes, as a set — used by the guard to tell auth from protected.
  static const Set<String> authRoutes = {signIn, signUp, forgotPassword};
}
