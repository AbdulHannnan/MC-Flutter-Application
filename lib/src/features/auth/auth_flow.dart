// lib/src/features/auth/auth_flow.dart — the signed-out flow: which of the three
// auth screens is shown.
//
// A LIGHTWEIGHT stand-in for real navigation: it swaps between Login / Sign up /
// Forgot-password with simple local state, wiring each screen's navigation
// callbacks. Successful auth needs no navigation here — it flips the session to
// signedIn and the app gate swaps this whole flow out for the protected app.
//
// Module 8 replaces this with the real stack-based navigator + route guards; the
// screens themselves (which take plain callbacks) won't need to change.

import 'package:flutter/material.dart';

import 'screens/forgot_password_screen.dart';
import 'screens/login_screen.dart';
import 'screens/sign_up_screen.dart';

enum _AuthScreen { login, signUp, forgotPassword }

class AuthFlow extends StatefulWidget {
  const AuthFlow({super.key});

  @override
  State<AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<AuthFlow> {
  _AuthScreen _screen = _AuthScreen.login;

  void _go(_AuthScreen screen) => setState(() => _screen = screen);

  @override
  Widget build(BuildContext context) {
    return switch (_screen) {
      _AuthScreen.login => LoginScreen(
          onSignUp: () => _go(_AuthScreen.signUp),
          onForgotPassword: () => _go(_AuthScreen.forgotPassword),
        ),
      _AuthScreen.signUp => SignUpScreen(
          onLogin: () => _go(_AuthScreen.login),
        ),
      _AuthScreen.forgotPassword => ForgotPasswordScreen(
          onBackToLogin: () => _go(_AuthScreen.login),
        ),
    };
  }
}
