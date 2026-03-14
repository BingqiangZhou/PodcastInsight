import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/app/config/app_config.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/top_floating_notice.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../providers/auth_provider.dart';
import '../widgets/password_text_field.dart';
import '../widgets/password_requirement_item.dart';

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
    final l10n = AppLocalizations.of(context)!;
    if (_formKey.currentState!.validate() && _agreeToTerms) {
      if (_rememberMe) {
        await _secureStorage.write(
          key: AppConstants.savedUsernameKey,
          value: _emailController.text.trim(),
        );
        await _secureStorage.write(
          key: AppConstants.savedPasswordKey,
          value: _passwordController.text,
        );
      } else {
        await _secureStorage.delete(key: AppConstants.savedUsernameKey);
        await _secureStorage.delete(key: AppConstants.savedPasswordKey);
      }

      ref
          .read(authProvider.notifier)
          .register(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            username: _usernameController.text.trim(),
            rememberMe: _rememberMe,
          );
    } else if (!_agreeToTerms) {
      showTopFloatingNotice(
        context,
        message: l10n.auth_agree_terms,
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;

    // Listen for auth state changes
    ref.listen<AuthState>(authProvider, (previous, next) {
      // Only navigate if user just became authenticated
      final wasAuthenticated = previous?.isAuthenticated ?? false;
      final isAuthenticated = next.isAuthenticated;

      if (isAuthenticated && !wasAuthenticated) {
        context.go('/home');
      } else if (next.error != null &&
          next.error != previous?.error &&
          next.fieldErrors == null) {
        // Only show snackbar for new errors without field errors
        if (mounted) {
          showTopFloatingNotice(context, message: next.error!, isError: true);
        }
      }
    });

    return Scaffold(
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
                  const SizedBox(height: 12),

                  // Logo and title
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.person_add,
                            size: 30,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.auth_create_account,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.auth_sign_up_subtitle,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Username field
                  CustomTextField(
                    controller: _usernameController,
                    label: l10n.auth_full_name,
                    prefixIcon: const Icon(Icons.person_outline),
                    onChanged: (value) {
                      _clearFieldErrors();
                      setState(
                        () {},
                      ); // Trigger rebuild to update password requirements
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

                  const SizedBox(height: 12),

                  // Email field
                  CustomTextField(
                    controller: _emailController,
                    label: l10n.auth_email,
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: const Icon(Icons.email_outlined),
                    onChanged: (value) {
                      _clearFieldErrors();
                      setState(
                        () {},
                      ); // Trigger rebuild to update password requirements
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return l10n.auth_enter_email;
                      }
                      if (!value.contains('@')) {
                        return l10n.auth_enter_valid_email;
                      }
                      return null;
                    },
                    errorText: authState.fieldErrors?['email'],
                  ),

                  const SizedBox(height: 12),

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
                          if (!value.contains(RegExp(r'[A-Z]'))) {
                            return l10n.auth_password_requirement_uppercase;
                          }
                          if (!value.contains(RegExp(r'[a-z]'))) {
                            return l10n.auth_password_requirement_lowercase;
                          }
                          if (!value.contains(RegExp(r'[0-9]'))) {
                            return l10n.auth_password_requirement_number;
                          }
                          return null;
                        },
                        errorText: authState.fieldErrors?['password'],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surface.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.outline.withValues(alpha: 0.3),
                          ),
                        ),
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
                            const SizedBox(height: 4),
                            PasswordRequirementItem(
                              text: l10n.auth_password_too_short,
                              isValid: _passwordController.text.length >= 8,
                            ),
                            PasswordRequirementItem(
                              text: l10n.auth_password_req_uppercase_short,
                              isValid: _passwordController.text.contains(
                                RegExp(r'[A-Z]'),
                              ),
                            ),
                            PasswordRequirementItem(
                              text: l10n.auth_password_req_lowercase_short,
                              isValid: _passwordController.text.contains(
                                RegExp(r'[a-z]'),
                              ),
                            ),
                            PasswordRequirementItem(
                              text: l10n.auth_password_req_number_short,
                              isValid: _passwordController.text.contains(
                                RegExp(r'[0-9]'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

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

                  const SizedBox(height: 16),

                  // Remember me checkbox
                  Row(
                    children: [
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
                            await _secureStorage.delete(
                              key: AppConstants.savedPasswordKey,
                            );
                          }
                        },
                      ),
                      Text(l10n.auth_remember_me),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Terms and conditions
                  Row(
                    children: [
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
                            text: 'I agree to the ',
                            style: Theme.of(context).textTheme.bodyMedium,
                            children: [
                              WidgetSpan(
                                child: GestureDetector(
                                  onTap: () {
                                    // TODO: Show terms and conditions
                                  },
                                  child: Text(
                                    l10n.auth_terms_and_conditions,
                                    style: TextStyle(
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
                                    style: TextStyle(
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

                  const SizedBox(height: 24),

                  // Register button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      key: const Key('register_button'),
                      onPressed: isLoading ? null : _register,
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
                          : Text(l10n.auth_create_account),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Sign in link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        l10n.auth_already_have_account,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      GestureDetector(
                        onTap: () => context.go('/login'),
                        child: Text(
                          l10n.auth_sign_in_link,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
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
      ),
    );
  }
}
