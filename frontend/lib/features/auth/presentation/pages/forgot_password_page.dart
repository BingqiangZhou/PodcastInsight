import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/core/widgets/app_shells.dart';
import 'package:personal_ai_assistant/core/widgets/top_floating_notice.dart';
import 'package:personal_ai_assistant/features/auth/presentation/providers/auth_provider.dart';
import 'package:personal_ai_assistant/shared/widgets/custom_text_field.dart';
import 'package:personal_ai_assistant/shared/widgets/loading_widget.dart';

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
  static const String _fallbackResendEmail =
      "Didn't receive the email? Resend";

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

    final forgotTitle =
        l10n?.auth_forgot_password ?? _fallbackForgotPasswordTitle;
    final successTitle =
        l10n?.auth_reset_email_sent ?? _fallbackResetEmailSent;

    return Scaffold(
      body: LoadingOverlay(
        isLoading: isLoading,
        child: AuthShell(
          title: _emailSent ? successTitle : forgotTitle,
          subtitle: _emailSent
              ? l10n?.auth_reset_email_sent_to(
                        _emailController.text.trim(),
                      ) ??
                  "We've sent a password reset link to\n${_emailController.text.trim()}"
              : l10n?.auth_reset_password_subtitle ??
                  _fallbackResetPasswordSubtitle,
          header: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.go('/login'),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _emailSent
                      ? AppColors.accentWarm.withValues(alpha: 0.1)
                      : Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  _emailSent ? Icons.check_circle_outline : Icons.lock_reset,
                  size: 40,
                  color: _emailSent
                      ? AppColors.accentWarm
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          child: _emailSent ? _buildSuccessContent(l10n) : _buildFormContent(l10n),
        ),
      ),
    );
  }

  Widget _buildFormContent(AppLocalizations? l10n) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomTextField(
            controller: _emailController,
            label: l10n?.auth_email ?? _fallbackEmailLabel,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: const Icon(Icons.email_outlined),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return l10n?.auth_enter_email ?? _fallbackEnterEmail;
              }
              if (!value.contains('@')) {
                return l10n?.auth_enter_valid_email ??
                    _fallbackEnterValidEmail;
              }
              return null;
            },
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              key: const Key('forgot_password_submit_button'),
              onPressed: _submitForgotPassword,
              child: Text(
                l10n?.auth_send_reset_link ?? _fallbackSendResetLink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessContent(AppLocalizations? l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n?.auth_check_email_fallback ?? _fallbackCheckEmailMessage,
          key: const Key('forgot_password_success_message'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color:
                    Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
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
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ),
      ],
    );
  }
}
