import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_ai_assistant/core/app/config/app_config.dart';
import 'package:personal_ai_assistant/core/constants/app_radius.dart';
import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/platform/adaptive_haptic.dart';
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive.dart';
import 'package:personal_ai_assistant/core/widgets/app_shells.dart';
import 'package:personal_ai_assistant/core/widgets/top_floating_notice.dart';
import 'package:personal_ai_assistant/features/auth/presentation/providers/auth_provider.dart';
import 'package:personal_ai_assistant/features/auth/presentation/widgets/password_requirement_item.dart';
import 'package:personal_ai_assistant/features/auth/presentation/widgets/password_text_field.dart';
import 'package:personal_ai_assistant/shared/widgets/custom_text_field.dart';
import 'package:personal_ai_assistant/shared/widgets/loading_widget.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _secureStorage = const FlutterSecureStorage();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;
  bool _rememberMe = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _clearFieldErrors() {
    ref.read(authProvider.notifier).clearFieldErrors();
  }

  Future<void> _register() async {
    final l10n = context.l10n;
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    if (!_agreeToTerms) {
      showTopFloatingNotice(
        context,
        message: l10n.auth_agree_terms,
        isError: true,
      );
      return;
    }

    if (_rememberMe) {
      await _secureStorage.write(
        key: AppConstants.savedUsernameKey,
        value: _emailController.text.trim(),
      );
    } else {
      await _secureStorage.delete(key: AppConstants.savedUsernameKey);
    }

    ref.read(authProvider.notifier).register(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      username: _usernameController.text.trim(),
      rememberMe: _rememberMe,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;

    // Listen for auth state changes
    ref.listen<AuthState>(authProvider, (previous, next) {
      final wasAuthenticated = previous?.isAuthenticated ?? false;
      final isAuthenticated = next.isAuthenticated;

      if (isAuthenticated && !wasAuthenticated) {
        AdaptiveHaptic.notificationSuccess(context);
        context.go('/feed');
      } else if (next.error != null &&
          next.error != previous?.error &&
          next.fieldErrors == null) {
        if (mounted) {
          showTopFloatingNotice(context, message: next.error!, isError: true);
        }
      }
    });

    return Scaffold(
      body: LoadingOverlay(
        isLoading: isLoading,
        child: AuthShell(
          title: l10n.auth_create_account,
          subtitle: l10n.auth_sign_up_subtitle,
          header: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: AppRadius.xlRadius,
            ),
            child: Icon(
              Icons.person_add,
              size: 30,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Username field
                CustomTextField(
                  controller: _usernameController,
                  label: l10n.auth_full_name,
                  prefixIcon: const Icon(Icons.person_outline),
                  onChanged: (value) {
                    _clearFieldErrors();
                    setState(() {});
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n.auth_enter_name;
                    }
                    if (value.length < 3) {
                      return l10n.validation_too_short;
                    }
                    return null;
                  },
                  errorText: authState.fieldErrors?['username'],
                ),

                const SizedBox(height: AppSpacing.smMd),

                // Email field
                CustomTextField(
                  controller: _emailController,
                  label: l10n.auth_email,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: const Icon(Icons.email_outlined),
                  onChanged: (value) {
                    _clearFieldErrors();
                    setState(() {});
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n.auth_enter_email;
                    }
                    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                    if (!emailRegex.hasMatch(value.trim())) {
                      return l10n.auth_enter_valid_email;
                    }
                    return null;
                  },
                  errorText: authState.fieldErrors?['email'],
                ),

                const SizedBox(height: AppSpacing.smMd),

                // Password field
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PasswordTextField(
                      controller: _passwordController,
                      label: l10n.auth_password,
                      obscureText: _obscurePassword,
                      toggleButtonKey: const Key('password_visibility_toggle'),
                      onToggleVisibility: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                      onChanged: (value) => _clearFieldErrors(),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return l10n.auth_enter_password;
                        }
                        if (value.length < 8) {
                          return l10n.auth_password_too_short;
                        }
                        if (!value.contains(RegExp('[A-Z]'))) {
                          return l10n.auth_password_requirement_uppercase;
                        }
                        if (!value.contains(RegExp('[a-z]'))) {
                          return l10n.auth_password_requirement_lowercase;
                        }
                        if (!value.contains(RegExp('[0-9]'))) {
                          return l10n.auth_password_requirement_number;
                        }
                        return null;
                      },
                      errorText: authState.fieldErrors?['password'],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.15)),
                      ),
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${l10n.auth_password}:',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          PasswordRequirementItem(
                            text: l10n.auth_password_too_short,
                            isValid: _passwordController.text.length >= 8,
                          ),
                          PasswordRequirementItem(
                            text: l10n.auth_password_req_uppercase_short,
                            isValid: _passwordController.text.contains(
                              RegExp('[A-Z]'),
                            ),
                          ),
                          PasswordRequirementItem(
                            text: l10n.auth_password_req_lowercase_short,
                            isValid: _passwordController.text.contains(
                              RegExp('[a-z]'),
                            ),
                          ),
                          PasswordRequirementItem(
                            text: l10n.auth_password_req_number_short,
                            isValid: _passwordController.text.contains(
                              RegExp('[0-9]'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.smMd),

                // Confirm password field
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

                const SizedBox(height: AppSpacing.md),

                // Remember me checkbox
                Row(
                  children: [
                    if (Platform.isIOS)
                      CupertinoSwitch(
                        value: _rememberMe,
                        onChanged: (value) async {
                          setState(() {
                            _rememberMe = value;
                          });
                          if (!_rememberMe) {
                            await _secureStorage.delete(
                              key: AppConstants.savedUsernameKey,
                            );
                          }
                        },
                      )
                    else
                      Checkbox(
                        value: _rememberMe,
                        onChanged: (value) async {
                          setState(() {
                            _rememberMe = value ?? false;
                          });
                          if (!_rememberMe) {
                            await _secureStorage.delete(
                              key: AppConstants.savedUsernameKey,
                            );
                          }
                        },
                      ),
                    Text(l10n.auth_remember_me),
                  ],
                ),

                const SizedBox(height: AppSpacing.sm),

                // Terms and conditions
                Row(
                  children: [
                    if (Platform.isIOS)
                      CupertinoSwitch(
                        value: _agreeToTerms,
                        onChanged: (value) {
                          setState(() {
                            _agreeToTerms = value;
                          });
                        },
                      )
                    else
                      Checkbox(
                        value: _agreeToTerms,
                        onChanged: (value) {
                          setState(() {
                            _agreeToTerms = value ?? false;
                          });
                        },
                      ),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: l10n.auth_agree_prefix,
                          style: Theme.of(context).textTheme.bodyMedium,
                          children: [
                            WidgetSpan(
                              child: GestureDetector(
                                onTap: () {
                                  // TODO: Show terms and conditions
                                },
                                child: Text(
                                  l10n.auth_terms_and_conditions,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        decoration: TextDecoration.underline,
                                      ),
                                ),
                              ),
                            ),
                            TextSpan(text: l10n.auth_and),
                            WidgetSpan(
                              child: GestureDetector(
                                onTap: () {
                                  // TODO: Show privacy policy
                                },
                                child: Text(
                                  l10n.auth_privacy_policy,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        decoration: TextDecoration.underline,
                                      ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),

                // Register button
                AdaptiveButton(
                  key: const Key('register_button'),
                  style: AdaptiveButtonStyle.filled,
                  onPressed: isLoading ? null : _register,
                  isLoading: isLoading,
                  child: Text(l10n.auth_create_account),
                ),

                const SizedBox(height: AppSpacing.md),

                // Sign in link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        l10n.auth_already_have_account,
                        style: Theme.of(context).textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    AdaptiveButton(
                      style: AdaptiveButtonStyle.text,
                      onPressed: () => context.go('/login'),
                      child: Text(
                        l10n.auth_sign_in_link,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
