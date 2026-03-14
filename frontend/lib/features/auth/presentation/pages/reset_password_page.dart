import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/top_floating_notice.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../providers/auth_provider.dart';
import '../widgets/password_text_field.dart';
import '../widgets/password_requirement_item.dart';

class ResetPasswordPage extends ConsumerStatefulWidget {
  final String? token;

  const ResetPasswordPage({super.key, this.token});

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
    if (widget.token == null || widget.token!.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showErrorDialog(
          'Invalid reset link. Please request a new password reset.',
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
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
    if (_formKey.currentState!.validate()) {
      if (widget.token == null || widget.token!.isEmpty) {
        _showErrorDialog(
          'Invalid reset link. Please request a new password reset.',
          context,
        );
        return;
      }

      ref
          .read(authProvider.notifier)
          .resetPassword(
            token: widget.token!,
            newPassword: _passwordController.text,
          );
    }
  }

  bool _hasMinLength(String password) => password.length >= 8;
  bool _hasUppercase(String password) => password.contains(RegExp(r'[A-Z]'));
  bool _hasLowercase(String password) => password.contains(RegExp(r'[a-z]'));
  bool _hasNumber(String password) => password.contains(RegExp(r'[0-9]'));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (!isLoading &&
          !next.isLoading &&
          next.error == null &&
          next.currentOperation == AuthOperation.resetPassword) {
        // Success - password reset
        setState(() {
          _passwordReset = true;
        });
      } else if (next.error != null) {
        showTopFloatingNotice(context, message: next.error!, isError: true);
      }
    });

    if (_passwordReset) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
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
                    l10n.action_completed,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your password has been successfully reset. You can now login with your new password.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
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
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.auth_reset_password),
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
                            Icons.lock_open,
                            size: 40,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.auth_set_new_password,
                          style: Theme.of(context).textTheme.headlineLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your new password must be different from\nprevious used passwords',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

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
                  AnimatedBuilder(
                    animation: _passwordController,
                    builder: (context, child) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.auth_password_requirements_title,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
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

                  const SizedBox(height: 32),

                  // Reset button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      key: const Key('reset_password_button'),
                      onPressed: isLoading ? null : _submitResetPassword,
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
                          : Text(l10n.auth_reset_password),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
