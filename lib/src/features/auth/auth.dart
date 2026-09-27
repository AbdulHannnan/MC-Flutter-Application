// lib/src/features/auth — the auth feature's PUBLIC API (barrel). Dart analog of
// the RN app's `src/features/auth/index.ts`.
//
// Other features and the app shell import auth ONLY from here; the mock backend and
// screen internals stay private to the feature.
//
// Built so far:
//   Module 7 — the session model (AuthUser), pure validation, a LOCAL persisted
//              MOCK backend (mock_auth_api.dart, shared_preferences), the
//              consolidated SessionController + sessionProvider, and the three
//              screens (Login / Sign up / Forgot-password).
//   Module 8 — the screens are wired into the app router (src/app/app_router.dart)
//              behind the auth guard; navigation uses go_router directly.
//
// NOTE: auth runs on a LOCAL MOCK (see mock_auth_api.dart) — NOT secure, for
// development only. The session model is provider-agnostic, so a real provider
// replaces just mock_auth_api.dart + the controller's calls, and screens keep
// working.

export 'auth_user.dart' show AuthUser;
export 'auth_validation.dart'
    show
        kMinPasswordLength,
        SignUpErrors,
        LoginErrors,
        ResetPasswordErrors,
        validateSignUp,
        validateLogin,
        validateResetPassword;
export 'mock_auth_api.dart'
    show MockAuthApi, AuthError, mockAuthApiProvider, kMockAuthLatency;
export 'session_controller.dart'
    show SessionController, sessionProvider, SessionX;
