// lib/src/features/auth/screens/sign_up_screen.dart — signup UI + logic. Dart port
// of the RN `SignUpScreen`.
//
// validateSignUp() checks the fields on submit and fills each field's error;
// SessionController.signUp() creates the account in the mock backend and signs in.
// On success the session flips to signedIn and the app gate reveals Home — no
// explicit navigation here. No email-verification step (the mock has no email), so
// this is a single form.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../auth_validation.dart';
import '../mock_auth_api.dart';
import '../session_controller.dart';
import '../widgets/auth_shell.dart';
import '../widgets/form_error_banner.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  /// Go to the login screen.
  final VoidCallback onLogin;

  const SignUpScreen({super.key, required this.onLogin});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _showPassword = false;
  bool _submitting = false;
  String? _formError;
  SignUpErrors _errors = const SignUpErrors();

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final errors = validateSignUp(
      fullName: _fullName.text,
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
      await ref.read(sessionProvider.notifier).signUp(
            fullName: _fullName.text,
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
        const AppText('Create your account', variant: AppTextVariant.h2),
        const SizedBox(height: AppSpacing.xs),
        const AppText('Book trusted care in just a few taps.',
            color: AppTextColor.muted),
        const SizedBox(height: AppSpacing.xl),

        if (_formError != null) ...[
          FormErrorBanner(message: _formError!),
          const SizedBox(height: AppSpacing.md),
        ],

        AppTextField(
          label: 'Full name',
          hintText: 'Jane Doe',
          controller: _fullName,
          errorText: _errors.fullName,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.md),
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
          label: 'Password',
          hintText: 'At least $kMinPasswordLength characters',
          controller: _password,
          errorText: _errors.password,
          obscureText: !_showPassword,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'Confirm password',
          hintText: 'Re-enter your password',
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
          label: 'Create account',
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
            const AppText('Already have an account? ',
                color: AppTextColor.muted),
            AuthLink('Log in', onTap: widget.onLogin),
          ],
        ),
      ],
    );
  }
}
