import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_ai_assistant/core/constants/app_radius.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/core/widgets/app_shells.dart';
import 'package:personal_ai_assistant/core/widgets/app_dialog_helper.dart';
import 'package:personal_ai_assistant/core/widgets/top_floating_notice.dart';
import 'package:personal_ai_assistant/features/auth/presentation/providers/auth_provider.dart';
import 'package:personal_ai_assistant/features/auth/presentation/widgets/password_requirement_item.dart';
import 'package:personal_ai_assistant/features/auth/presentation/widgets/password_text_field.dart';
import 'package:personal_ai_assistant/shared/widgets/loading_widget.dart';

class ResetPasswordPage extends ConsumerStatefulWidget {

  const ResetPasswordPage({super.key, this.token});
  final String? token;

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _passwordReset = false;

  @override
  void initState() {
    super.initState();
    // Check if token is provided
    final token = widget.token;
    if (token == null || token.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showErrorDialog(
          context.l10n.auth_invalid_reset_link,
          context,
        );
      });
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showErrorDialog(String message, BuildContext context) {
    final l10n = context.l10n;
    showAppDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        title: Text(l10n.error),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/forgot-password');
            },
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
  }

  void _submitResetPassword() {
    final formState = _formKey.currentState;
    final token = widget.token;
    if (formState == null || !formState.validate()) return;

    if (token == null || token.isEmpty) {
      _showErrorDialog(
        context.l10n.auth_invalid_reset_link,
        context,
      );
      return;
    }

    ref.read(authProvider.notifier).resetPassword(
      token: token,
      newPassword: _passwordController.text,
    );
  }

  bool _hasMinLength(String password) => password.length >= 8;
  bool _hasUppercase(String password) => password.contains(RegExp('[A-Z]'));
  bool _hasLowercase(String password) => password.contains(RegExp('[a-z]'));
  bool _hasNumber(String password) => password.contains(RegExp('[0-9]'));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (!isLoading &&
          !next.isLoading &&
          next.error == null &&
          next.currentOperation == AuthOperation.resetPassword) {
        setState(() {
          _passwordReset = true;
        });
      } else if (next.error case final error?) {
        showTopFloatingNotice(context, message: error, isError: true);
      }
    });

    return Scaffold(
      body: LoadingOverlay(
        isLoading: isLoading,
        child: AuthShell(
          title: _passwordReset
              ? l10n.action_completed
              : l10n.auth_set_new_password,
          subtitle: _passwordReset
              ? l10n.auth_password_reset_success
              : l10n.auth_new_password_instruction,
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
                  color: _passwordReset
                      ? AppColors.accentWarm.withValues(alpha: 0.1)
                      : Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: AppRadius.xlRadius,
                ),
                child: Icon(
                  _passwordReset ? Icons.check_circle_outline : Icons.lock_open,
                  size: 40,
                  color: _passwordReset
                      ? AppColors.accentWarm
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          child: _passwordReset ? _buildSuccessContent(l10n) : _buildFormContent(l10n),
        ),
      ),
    );
  }

  Widget _buildFormContent(AppLocalizations l10n) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Password field
          PasswordTextField(
            controller: _passwordController,
            label: l10n.auth_new_password,
            obscureText: _obscurePassword,
            onToggleVisibility: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return l10n.auth_enter_password;
              }
              if (value.length < 8) {
                return l10n.auth_password_too_short;
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          // Confirm Password field
          PasswordTextField(
            controller: _confirmPasswordController,
            label: l10n.auth_confirm_password,
            obscureText: _obscureConfirmPassword,
            onToggleVisibility: () {
              setState(() {
                _obscureConfirmPassword = !_obscureConfirmPassword;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return l10n.auth_enter_password;
              }
              if (value != _passwordController.text) {
                return l10n.auth_passwords_not_match;
              }
              return null;
            },
          ),

          const SizedBox(height: 24),

          // Password requirements
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _passwordController,
              builder: (context, child) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.auth_password_requirements_title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    PasswordRequirementItem(
                      text: l10n.auth_password_requirement_min_length,
                      isValid: _hasMinLength(_passwordController.text),
                    ),
                    PasswordRequirementItem(
                      text: l10n.auth_password_requirement_uppercase,
                      isValid: _hasUppercase(_passwordController.text),
                    ),
                    PasswordRequirementItem(
                      text: l10n.auth_password_requirement_lowercase,
                      isValid: _hasLowercase(_passwordController.text),
                    ),
                    PasswordRequirementItem(
                      text: l10n.auth_password_requirement_number,
                      isValid: _hasNumber(_passwordController.text),
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 32),

          // Reset button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              key: const Key('reset_password_button'),
              onPressed: _submitResetPassword,
              child: Text(l10n.auth_reset_password),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessContent(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            key: const Key('go_to_login_button'),
            onPressed: () => context.go('/login'),
            child: Text(l10n.auth_back_to_login),
          ),
        ),
      ],
    );
  }
}
