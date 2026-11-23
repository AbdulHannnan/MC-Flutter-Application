// lib/src/features/auth/screens/forgot_password_screen.dart — reset-password UI.
//
// EMAIL-ONLY reset: the customer enters their account email and we ask the backend
// to send a recovery link, which they complete OUTSIDE the app (Supabase Auth
// cannot set a new password inline from the client). On success the form is
// replaced by a "check your email" confirmation. We never reveal whether the email
// has an account — the same neutral confirmation shows either way.
//
// (The mock backend has nowhere to send mail, so there it's a no-op that still
// shows the confirmation — the flow is identical from the screen's point of view.)

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

  bool _submitting = false;
  bool _sent = false;
  String? _formError;
  ResetRequestErrors _errors = const ResetRequestErrors();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final errors = validateResetRequest(email: _email.text);
    setState(() {
      _errors = errors;
      _formError = null;
    });
    if (errors.hasErrors) return;

    setState(() => _submitting = true);
    try {
      await ref.read(sessionProvider.notifier).sendPasswordReset(
            email: _email.text,
          );
      if (mounted) setState(() => _sent = true);
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
      children: _sent ? _confirmation() : _form(),
    );
  }

  // The email-entry form.
  List<Widget> _form() => [
        const AppText('Reset your password', variant: AppTextVariant.h2),
        const SizedBox(height: AppSpacing.xs),
        const AppText(
          "Enter your account email and we'll send you a link to reset your "
          'password.',
          color: AppTextColor.muted,
        ),
        const SizedBox(height: AppSpacing.xl),

        if (_formError != null) ...[
          FormErrorBanner(message: _formError!),
          const SizedBox(height: AppSpacing.md),
        ],

        AppTextField(
          label: 'Email',
          hintText: 'se.abdulhannan@gmail.com',
          controller: _email,
          errorText: _errors.email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _handleSubmit(),
        ),
        const SizedBox(height: AppSpacing.xl),

        AppButton(
          label: 'Send reset link',
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
      ];

  // The post-submit "check your email" confirmation.
  List<Widget> _confirmation() => [
        const Icon(Icons.mark_email_read_outlined,
            size: 48, color: AppColors.primary),
        const SizedBox(height: AppSpacing.md),
        const AppText('Check your email', variant: AppTextVariant.h2),
        const SizedBox(height: AppSpacing.xs),
        AppText(
          "If an account exists for ${_email.text.trim()}, we've sent a link to "
          'reset your password. Follow it, then come back and sign in.',
          color: AppTextColor.muted,
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: 'Back to log in',
          size: AppButtonSize.lg,
          fullWidth: true,
          onPressed: () => context.go(AppRoutes.signIn),
        ),
      ];
}
