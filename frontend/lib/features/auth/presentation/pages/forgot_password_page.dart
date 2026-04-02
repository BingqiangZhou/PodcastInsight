import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/top_floating_notice.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../providers/auth_provider.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _emailSent = false;
  ProviderSubscription<AuthState>? _authSubscription;

  static const String _fallbackResetPasswordTitle = 'Reset Password';
  static const String _fallbackForgotPasswordTitle = 'Forgot Password';
  static const String _fallbackResetPasswordSubtitle =
      'Enter your email to receive a password reset link.';
  static const String _fallbackEmailLabel = 'Email';
  static const String _fallbackEnterEmail = 'Please enter your email';
  static const String _fallbackEnterValidEmail =
      'Please enter a valid email address';
  static const String _fallbackSendResetLink = 'Send Reset Link';
  static const String _fallbackResetEmailSent = 'Reset email sent';
  static const String _fallbackCheckEmailMessage =
      'Please check your email and click the link to reset your password';
  static const String _fallbackBackToLogin = 'Back to Login';
  static const String _fallbackResendEmail = 'Didn\'t receive the email? Resend';

  @override
  void initState() {
    super.initState();
    _authSubscription = ref.listenManual<AuthState>(authProvider, (
      previous,
      next,
    ) {
      if (!mounted) {
        return;
      }

      final previousLoading = previous?.isLoading ?? false;
      final completedForgotPassword =
          previousLoading &&
          !next.isLoading &&
          next.error == null &&
          (previous?.currentOperation == AuthOperation.forgotPassword ||
              next.currentOperation == AuthOperation.forgotPassword);

      if (completedForgotPassword && !_emailSent) {
        setState(() {
          _emailSent = true;
        });
        return;
      }

      final error = next.error;
      if (error != null && error.isNotEmpty) {
        showTopFloatingNotice(context, message: error, isError: true);
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.close();
    _emailController.dispose();
    super.dispose();
  }

  void _submitForgotPassword() {
    final formState = _formKey.currentState;
    if (formState != null && formState.validate()) {
      ref
          .read(authProvider.notifier)
          .forgotPassword(_emailController.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n?.auth_reset_password ?? _fallbackResetPasswordTitle,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: LoadingOverlay(
          isLoading: isLoading,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),

                  if (!_emailSent) ...[
                    // Icon and title
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              Icons.lock_reset,
                              size: 40,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n?.auth_forgot_password ??
                                _fallbackForgotPasswordTitle,
                            style: Theme.of(context).textTheme.headlineLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n?.auth_reset_password_subtitle ??
                                _fallbackResetPasswordSubtitle,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.7),
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Email field
                    CustomTextField(
                      controller: _emailController,
                      label: l10n?.auth_email ?? _fallbackEmailLabel,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: const Icon(Icons.email_outlined),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return l10n?.auth_enter_email ??
                              _fallbackEnterEmail;
                        }
                        if (!value.contains('@')) {
                          return l10n?.auth_enter_valid_email ??
                              _fallbackEnterValidEmail;
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 32),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        key: const Key('forgot_password_submit_button'),
                        onPressed: isLoading ? null : _submitForgotPassword,
                        child: isLoading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              )
                            : Text(
                                l10n?.auth_send_reset_link ??
                                    _fallbackSendResetLink,
                              ),
                      ),
                    ),
                  ] else ...[
                    // Success message
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.check_circle_outline,
                              size: 40,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n?.auth_reset_email_sent ??
                                _fallbackResetEmailSent,
                            style: Theme.of(context).textTheme.headlineLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n?.auth_reset_email_sent_to(
                                      _emailController.text.trim(),
                                    ) ??
                                'We\'ve sent a password reset link to\n${_emailController.text.trim()}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.7),
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n?.auth_check_email_fallback ??
                                _fallbackCheckEmailMessage,
                            key: const Key('forgot_password_success_message'),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Back to login button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        key: const Key('back_to_login_button'),
                        onPressed: () => context.go('/login'),
                        child: Text(
                          l10n?.auth_back_to_login ?? _fallbackBackToLogin,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Resend email
                    TextButton(
                      key: const Key('resend_email_button'),
                      onPressed: () {
                        setState(() {
                          _emailSent = false;
                        });
                        ref.read(authProvider.notifier).clearError();
                      },
                      child: Text(
                        l10n?.auth_resend_email ?? _fallbackResendEmail,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
