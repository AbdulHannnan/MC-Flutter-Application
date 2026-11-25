// lib/src/app/app_router.dart — the app's navigator + route guards. The idiomatic
// Flutter analog of the RN app's `src/app/_layout.tsx` (expo-router Stack with two
// `Stack.Protected` groups).
//
// ONE GoRouter for the whole app, built in a provider so its redirect can read
// `sessionProvider` and it rebuilds when the session changes (`refreshListenable`).
//
// THE GUARD ([_authGuard]) is the declarative replacement for RN's Stack.Protected
// + automatic redirect:
//   • restoring  → hold on the splash (a returning user never flashes login).
//   • signed OUT → only the auth routes are reachable; any other path (a deep link
//                  to /cart, say) bounces to /sign-in.
//   • signed IN  → the auth routes and the splash bounce to Home.
// We never write imperative navigation for auth transitions: change the session
// (log in / log out) and the reachable routes change with it.
//
// BOOKING-FLOW GUARDS ([_bookingDraftGuard]) mirror RN's per-screen
// `if (!service) return <Redirect href="/" />`: a booking step with no draft data
// bounces home. The real draft-presence check wires in with the booking store
// (Modules 11–13); until then there's nothing to book, so the steps bounce.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/sign_up_screen.dart';
import '../features/booking/booking.dart';
import '../features/booking/screens/location_screen.dart';
import '../features/booking/screens/review_screen.dart';
import '../features/booking/screens/schedule_screen.dart';
import '../features/cart/cart.dart';
import '../features/cart/screens/cart_screen.dart';
import '../features/checkout/screens/checkout_failure_screen.dart';
import '../features/checkout/screens/checkout_screen.dart';
import '../features/checkout/screens/checkout_success_screen.dart';
// TEMPORARY — Field Job Portal (see FIELD_PORTAL_REMOVAL.md). Remove at teardown.
import '../features/field_portal/field_portal.dart';
import '../features/orders/screens/order_detail_screen.dart';
import '../features/orders/screens/orders_screen.dart';
import '../features/services/screens/categories_screen.dart';
import '../features/services/screens/category_services_screen.dart';
import '../features/services/screens/search_screen.dart';
import '../features/services/screens/service_detail_screen.dart';
import '../features/technician/screens/technician_home_screen.dart';
import '../features/technician/screens/technician_job_detail_screen.dart';
import '../features/technician/screens/technician_login_screen.dart';
import '../features/technician/technician.dart';
import 'app_routes.dart';
import 'screens/home_screen.dart';
import 'screens/placeholder_screen.dart';
import 'screens/splash_screen.dart';

/// The app-wide router. Screens navigate with `context.go/push`; the redirect
/// enforces the auth boundary. Rebuilt reactively when the session changes.
final routerProvider = Provider<GoRouter>((ref) {
  // Bridge Riverpod → Listenable: bump on every session change so go_router
  // re-evaluates the redirect (e.g. right after sign-in / sign-out).
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  // The technician session is a parallel auth (real backend JWT); re-evaluate the
  // guard when it changes too (technician log in / out).
  ref.listen(technicianSessionProvider, (_, _) => refresh.value++);
  // Also re-evaluate when the cold-start welcome animation finishes, so the
  // guard can release the splash once it has played (see _authGuard).
  ref.listen(splashGateProvider, (_, _) => refresh.value++);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) => _authGuard(ref, state),
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),

      // ── Auth area (reachable only when signed OUT) ──
      GoRoute(
        path: AppRoutes.signIn,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      // Technician login — a parallel public entry (reachable when nobody is
      // signed in); on success the technician session reveals the staff area.
      GoRoute(
        path: AppRoutes.technicianLogin,
        builder: (context, state) => const TechnicianLoginScreen(),
      ),

      // ── Protected area (reachable only when signed IN) ──
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.about,
        builder: (context, state) =>
            const PlaceholderScreen(title: 'About', arrivesIn: 'a later module'),
      ),

      // Technician (staff) area — the guard lets only technician accounts in.
      GoRoute(
        path: AppRoutes.technicianHome,
        builder: (context, state) => const TechnicianHomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.technicianJob,
        builder: (context, state) =>
            TechnicianJobDetailScreen(jobId: state.pathParameters['id']!),
      ),
      // TEMPORARY — Field Job Portal (see FIELD_PORTAL_REMOVAL.md). In the
      // technician area, so the role guard already restricts it to technicians.
      GoRoute(
        path: AppRoutes.fieldPortal,
        builder: (context, state) => const FieldJobPortalScreen(),
      ),
      GoRoute(
        path: AppRoutes.categories,
        builder: (context, state) => const CategoriesScreen(),
      ),
      GoRoute(
        path: AppRoutes.search,
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: AppRoutes.cart,
        builder: (context, state) => const CartScreen(),
      ),
      GoRoute(
        path: AppRoutes.category,
        builder: (context, state) => CategoryServicesScreen(
          categoryId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.service,
        builder: (context, state) => ServiceDetailScreen(
          serviceId: state.pathParameters['id']!,
        ),
      ),

      // Booking flow — each step guards on the draft holding what it needs,
      // redirecting to the step that owns any missing data (mirrors RN's
      // per-screen Redirect). Location + Schedule land with Module 12; the Review
      // screen itself arrives in Module 13.
      GoRoute(
        path: AppRoutes.bookingLocation,
        redirect: (context, state) => _bookingDraftGuard(ref, state),
        builder: (context, state) => const LocationScreen(),
      ),
      GoRoute(
        path: AppRoutes.bookingSchedule,
        redirect: (context, state) => _bookingDraftGuard(ref, state),
        builder: (context, state) => const ScheduleScreen(),
      ),
      GoRoute(
        path: AppRoutes.bookingReview,
        redirect: (context, state) => _bookingDraftGuard(ref, state),
        builder: (context, state) => const ReviewScreen(),
      ),

      GoRoute(
        path: AppRoutes.checkout,
        // Nothing to pay for → send an empty cart back to the cart screen.
        redirect: (context, state) {
          final empty = ref.read(cartProvider).isEmpty;
          return empty ? AppRoutes.cart : null;
        },
        builder: (context, state) => const CheckoutScreen(),
      ),
      GoRoute(
        path: AppRoutes.checkoutSuccess,
        builder: (context, state) => const CheckoutSuccessScreen(),
      ),
      GoRoute(
        path: AppRoutes.checkoutFailure,
        builder: (context, state) => const CheckoutFailureScreen(),
      ),
      GoRoute(
        path: AppRoutes.orders,
        builder: (context, state) => const OrdersScreen(),
      ),
      GoRoute(
        path: AppRoutes.order,
        builder: (context, state) =>
            OrderDetailScreen(bookingId: state.pathParameters['id']!),
      ),
    ],
  );
});

/// The auth boundary. Returns a path to redirect to, or null to allow the route.
///
/// Two PARALLEL auths: the customer session (mock/Clerk) and the technician
/// session (real backend JWT). A signed-in technician takes precedence and gets
/// only the staff area; a signed-in customer gets the customer app; the two
/// experiences never overlap. Nobody signed in → the public auth routes.
String? _authGuard(Ref ref, GoRouterState state) {
  final session = ref.read(sessionProvider);
  final techSession = ref.read(technicianSessionProvider);
  final welcomePlayed = ref.read(splashGateProvider);
  final location = state.matchedLocation;
  final onSplash = location == AppRoutes.splash;

  // Hold on the splash until BOTH sessions have restored AND the cold-start
  // welcome animation has finished playing, so the branded welcome always shows
  // in full on app open instead of flashing past.
  if (session.isRestoring || techSession.isRestoring || !welcomePlayed) {
    return onSplash ? null : AppRoutes.splash;
  }

  final onAuthRoute = AppRoutes.authRoutes.contains(location);
  final onTechnicianRoute = AppRoutes.isTechnicianArea(location);

  // Technician signed in → only the staff area is reachable (auth routes, the
  // splash, and the whole customer app bounce to the tech home).
  if (techSession.isSignedIn) {
    return onTechnicianRoute ? null : AppRoutes.technicianHome;
  }

  // Customer signed in → the customer app; the staff area and auth routes/splash
  // bounce to Home.
  if (session.isSignedIn) {
    if (onTechnicianRoute) return AppRoutes.home;
    if (onAuthRoute || onSplash) return AppRoutes.home;
    return null;
  }

  // Nobody signed in: only the public auth routes are reachable; everything else
  // bounces to the customer login.
  return onAuthRoute ? null : AppRoutes.signIn;
}

/// A booking step needs its draft data. Each step allows only when the draft holds
/// what it requires, otherwise it redirects to the step that owns the missing data
/// (mirrors RN's per-screen `if (!x) return <Redirect .../>`):
///   • location — needs a chosen service (else Home: nothing is being booked).
///   • schedule — needs service + location (else back to the location step).
///   • review   — needs service + location + slot (else back to the owning step).
String? _bookingDraftGuard(Ref ref, GoRouterState state) {
  final draft = ref.read(bookingDraftProvider);
  final location = state.matchedLocation;

  // No service configured → nothing to book; leave the flow entirely.
  if (!draft.hasService) return AppRoutes.home;

  if (location == AppRoutes.bookingSchedule && draft.location == null) {
    return AppRoutes.bookingLocation;
  }
  if (location == AppRoutes.bookingReview) {
    if (draft.location == null) return AppRoutes.bookingLocation;
    if (draft.slot == null) return AppRoutes.bookingSchedule;
  }
  return null;
}
