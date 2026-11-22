// lib/src/app/screens/splash_screen.dart — the cold-start WELCOME splash.
//
// A branded, animated welcome screen on a deep-blue field: a frosted snowflake
// badge, "Welcome to Microcare", and a tagline, all easing in, then a subtle
// loader. It is the first thing a user sees on app open.
//
// HOW IT STAYS ON SCREEN: the router shows the splash on cold start while the
// saved session restores — but that read is near-instant, so on its own the
// animation would flash past. [splashGateProvider] fixes that: the router's auth
// guard holds EVERY route on this splash until the gate flips true, which happens
// only after the welcome animation has finished playing (see [_WelcomeState]). So
// the animation always plays in full, then the app routes on (Home if signed in,
// otherwise the login screen). The gate is set once for the app's lifetime —
// logging out later does not replay the welcome.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme.dart';

/// Whether the cold-start welcome animation has finished playing. The router's
/// auth guard reads this and keeps the app on the splash until it is true (and
/// the session has restored). Starts false; set once via [SplashGate.complete].
final splashGateProvider = NotifierProvider<SplashGate, bool>(SplashGate.new);

class SplashGate extends Notifier<bool> {
  @override
  bool build() => false;

  /// Mark the welcome animation complete (idempotent — safe to call more than once).
  void complete() {
    if (!state) state = true;
  }
}

/// How long the entrance choreography runs, plus a brief hold on the finished
/// frame before the app routes onward. Total on-screen time ≈ 2.7s.
const Duration _kEntrance = Duration(milliseconds: 2200);
const Duration _kHold = Duration(milliseconds: 500);

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Light status-bar icons over the dark-blue field.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: AppColors.transparent,
        systemNavigationBarColor: AppPalette.blue700,
      ),
      child: const Scaffold(
        backgroundColor: AppPalette.blue600,
        body: _Welcome(),
      ),
    );
  }
}

class _Welcome extends ConsumerStatefulWidget {
  const _Welcome();

  @override
  ConsumerState<_Welcome> createState() => _WelcomeState();
}

class _WelcomeState extends ConsumerState<_Welcome>
    with TickerProviderStateMixin {
  // The entrance: plays once, drives every element's fade/scale/slide.
  late final AnimationController _entrance;
  // The ambient pulse: loops gently behind the badge so the screen feels alive.
  late final AnimationController _ambient;

  @override
  void initState() {
    super.initState();

    _ambient = AnimationController(vsync: this, duration: const Duration(milliseconds: 1900))
      ..repeat(reverse: true);

    _entrance = AnimationController(vsync: this, duration: _kEntrance)
      ..addStatusListener((status) {
        if (status != AnimationStatus.completed) return;
        // Hold the finished frame briefly, then open the gate so the router can
        // route on. The guard disposing this screen afterwards is expected.
        Timer(_kHold, () {
          if (mounted) ref.read(splashGateProvider.notifier).complete();
        });
      })
      ..forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    _ambient.dispose();
    super.dispose();
  }

  // A staggered segment of the entrance, as a 0→1 eased animation.
  Animation<double> _stage(double start, double end, {Curve curve = Curves.easeOut}) {
    return CurvedAnimation(parent: _entrance, curve: Interval(start, end, curve: curve));
  }

  @override
  Widget build(BuildContext context) {
    final badge = _stage(0.0, 0.5, curve: Curves.easeOutBack);
    final welcomeTo = _stage(0.3, 0.62);
    final brand = _stage(0.42, 0.78);
    final tagline = _stage(0.6, 0.9);
    final loader = _stage(0.82, 1.0);

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppPalette.blue500, AppPalette.blue700],
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            // The centre piece: badge + wordmark + tagline.
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _badge(badge),
                  const SizedBox(height: AppSpacing.xl),
                  _fadeSlide(
                    welcomeTo,
                    const Text(
                      'WELCOME TO',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _fadeSlide(
                    brand,
                    const Text(
                      'Microcare',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FadeTransition(
                    opacity: tagline,
                    child: const Text(
                      'AC servicing, booked in minutes',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // A quiet loader pinned near the bottom.
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                child: FadeTransition(
                  opacity: loader,
                  child: const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white70),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The frosted snowflake badge: a soft pulsing halo (ambient) behind a
  /// translucent white circle that scales + fades in (entrance).
  Widget _badge(Animation<double> entrance) {
    return AnimatedBuilder(
      animation: Listenable.merge([entrance, _ambient]),
      builder: (context, _) {
        final t = entrance.value.clamp(0.0, 1.0);
        final pulse = _ambient.value; // 0→1→0
        return Opacity(
          opacity: t,
          child: Transform.scale(
            scale: 0.7 + 0.3 * t,
            child: Container(
              width: 128,
              height: 128,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.10 + 0.14 * pulse),
                    blurRadius: 24 + 16 * pulse,
                    spreadRadius: 2 + 6 * pulse,
                  ),
                ],
              ),
              child: Container(
                width: 92,
                height: 92,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.16),
                ),
                child: const Icon(Icons.ac_unit, size: 52, color: Colors.white),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Fade in while sliding gently up — the entrance motion for the text lines.
  Widget _fadeSlide(Animation<double> anim, Widget child) {
    return AnimatedBuilder(
      animation: anim,
      builder: (context, c) => Opacity(
        opacity: anim.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - anim.value)),
          child: c,
        ),
      ),
      child: child,
    );
  }
}
