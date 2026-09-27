// lib/src/features/auth/screens/forgot_password_screen.dart — reset-password UI.
// Dart port of the RN `ForgotPasswordScreen`.
//
// With no email to send a code to, the flow is a SINGLE form: enter your account
// email and a new password. If that email exists, the mock backend sets the new
// password and signs you in, and the app gate reveals the protected app — no
// explicit navigation here. An unknown email comes back as a banner message.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../auth_validation.dart';
import '../mock_auth_api.dart';
import '../session_controller.dart';
import '../widgets/auth_shell.dart';
import '../widgets/form_error_banner.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _showPassword = false;
  bool _submitting = false;
  String? _formError;
  ResetPasswordErrors _errors = const ResetPasswordErrors();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final errors = validateResetPassword(
      email: _email.text,
      password: _password.text,
      confirmPassword: _confirm.text,
    );
    setState(() {
      _errors = errors;
      _formError = null;
    });
    if (errors.hasErrors) return;

    setState(() => _submitting = true);
    try {
      await ref.read(sessionProvider.notifier).resetPassword(
            email: _email.text,
            password: _password.text,
          );
      // Success: the session flips to signedIn and the gate swaps the screen.
    } on AuthError catch (e) {
      if (mounted) setState(() => _formError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _formError = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      children: [
        const AppText('Reset your password', variant: AppTextVariant.h2),
        const SizedBox(height: AppSpacing.xs),
        const AppText('Enter your account email and choose a new password.',
            color: AppTextColor.muted),
        const SizedBox(height: AppSpacing.xl),

        if (_formError != null) ...[
          FormErrorBanner(message: _formError!),
          const SizedBox(height: AppSpacing.md),
        ],

        AppTextField(
          label: 'Email',
          hintText: 'you@example.com',
          controller: _email,
          errorText: _errors.email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'New password',
          hintText: 'At least $kMinPasswordLength characters',
          controller: _password,
          errorText: _errors.password,
          obscureText: !_showPassword,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'Confirm new password',
          hintText: 'Re-enter your new password',
          controller: _confirm,
          errorText: _errors.confirmPassword,
          obscureText: !_showPassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _handleSubmit(),
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: AuthLink(
            _showPassword ? 'Hide password' : 'Show password',
            onTap: () => setState(() => _showPassword = !_showPassword),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        AppButton(
          label: 'Reset password & sign in',
          size: AppButtonSize.lg,
          fullWidth: true,
          loading: _submitting,
          onPressed: _handleSubmit,
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const AppText('Remembered it? ', color: AppTextColor.muted),
            AuthLink('Back to log in',
                onTap: () => context.go(AppRoutes.signIn)),
          ],
        ),
      ],
    );
  }
}
