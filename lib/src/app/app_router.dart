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
      GoRoute(
        path: AppRoutes.categories,
        builder: (context, state) => const PlaceholderScreen(
            title: 'Categories', arrivesIn: 'Module 10'),
      ),
      GoRoute(
        path: AppRoutes.search,
        builder: (context, state) =>
            const PlaceholderScreen(title: 'Search', arrivesIn: 'Module 10'),
      ),
      GoRoute(
        path: AppRoutes.cart,
        builder: (context, state) =>
            const PlaceholderScreen(title: 'Your cart', arrivesIn: 'Module 13'),
      ),
      GoRoute(
        path: AppRoutes.category,
        builder: (context, state) => PlaceholderScreen(
          title: 'Category ${state.pathParameters['id']}',
          arrivesIn: 'Module 10',
        ),
      ),
      GoRoute(
        path: AppRoutes.service,
        builder: (context, state) => PlaceholderScreen(
          title: 'Service ${state.pathParameters['id']}',
          arrivesIn: 'Module 11',
        ),
      ),

      // Booking flow — guarded: no draft yet, so each step bounces home (the
      // pattern; the real draft check lands with the store in Modules 11–13).
      GoRoute(
        path: AppRoutes.bookingLocation,
        redirect: _bookingDraftGuard,
        builder: (context, state) =>
            const PlaceholderScreen(title: 'Location', arrivesIn: 'Module 12'),
      ),
      GoRoute(
        path: AppRoutes.bookingSchedule,
        redirect: _bookingDraftGuard,
        builder: (context, state) =>
            const PlaceholderScreen(title: 'Schedule', arrivesIn: 'Module 12'),
      ),
      GoRoute(
        path: AppRoutes.bookingReview,
        redirect: _bookingDraftGuard,
        builder: (context, state) => const PlaceholderScreen(
            title: 'Review booking', arrivesIn: 'Module 13'),
      ),

      GoRoute(
        path: AppRoutes.checkout,
        builder: (context, state) =>
            const PlaceholderScreen(title: 'Checkout', arrivesIn: 'Module 14'),
      ),
      GoRoute(
        path: AppRoutes.checkoutSuccess,
        builder: (context, state) =>
            const PlaceholderScreen(title: 'Confirmed', arrivesIn: 'Module 14'),
      ),
      GoRoute(
        path: AppRoutes.checkoutFailure,
        builder: (context, state) => const PlaceholderScreen(
            title: 'Payment failed', arrivesIn: 'Module 14'),
      ),
      GoRoute(
        path: AppRoutes.orders,
        builder: (context, state) => const PlaceholderScreen(
            title: 'My bookings', arrivesIn: 'Module 15'),
      ),
      GoRoute(
        path: AppRoutes.order,
        builder: (context, state) => PlaceholderScreen(
          title: 'Booking ${state.pathParameters['id']}',
          arrivesIn: 'Module 15',
        ),
      ),
    ],
  );
});

/// The auth boundary. Returns a path to redirect to, or null to allow the route.
String? _authGuard(Ref ref, GoRouterState state) {
  final session = ref.read(sessionProvider);
  final location = state.matchedLocation;
  final onSplash = location == AppRoutes.splash;

  // Still restoring the saved session — hold on the splash.
  if (session.isRestoring) return onSplash ? null : AppRoutes.splash;

  final onAuthRoute = AppRoutes.authRoutes.contains(location);

  if (!session.isSignedIn) {
    // Signed out: only auth routes are reachable; everything else bounces to login.
    return onAuthRoute ? null : AppRoutes.signIn;
  }

  // Signed in: auth routes and the (now-finished) splash bounce to Home.
  if (onAuthRoute || onSplash) return AppRoutes.home;
  return null;
}

/// A booking step needs its draft data; with no draft store yet, bounce home.
String? _bookingDraftGuard(BuildContext context, GoRouterState state) {
  // TODO(Modules 11–13): allow when the draft holds what this step needs (e.g. a
  // chosen service for /booking/location), mirroring RN's per-screen Redirect.
  return AppRoutes.home;
}
