import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_ai_assistant/core/app/config/app_config.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/providers/core_providers.dart';
import 'package:personal_ai_assistant/core/widgets/app_shells.dart';
import 'package:personal_ai_assistant/core/widgets/glass_dialog_helper.dart';
import 'package:personal_ai_assistant/core/widgets/top_floating_notice.dart';
import 'package:personal_ai_assistant/features/auth/presentation/providers/auth_provider.dart';
import 'package:personal_ai_assistant/features/auth/presentation/widgets/password_text_field.dart';
import 'package:personal_ai_assistant/shared/widgets/custom_text_field.dart';
import 'package:personal_ai_assistant/shared/widgets/loading_widget.dart';
import 'package:personal_ai_assistant/shared/widgets/server_config_dialog.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _secureStorage = const FlutterSecureStorage();
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    final savedUsername = await _secureStorage.read(
      key: AppConstants.savedUsernameKey,
    );

    if (!mounted) {
      return;
    }

    if (savedUsername != null) {
      setState(() {
        _emailController.text = savedUsername;
        _rememberMe = true;
      });
    }
  }

  Future<void> _login() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    if (_rememberMe) {
      await _secureStorage.write(
        key: AppConstants.savedUsernameKey,
        value: _emailController.text.trim(),
      );
      // Note: password is NOT stored. The auth system's refresh token
      // handles session persistence securely.
    } else {
      await _secureStorage.delete(key: AppConstants.savedUsernameKey);
    }

    if (!mounted) {
      return;
    }

    ref.read(authProvider.notifier).login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      rememberMe: _rememberMe,
    );
  }

  /// Show server configuration dialog (using shared dialog)
  void _showServerConfigDialog() {
    final serverConfig = ref.read(serverConfigProvider);
    showGlassDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ServerConfigDialog(
        initialUrl: serverConfig.serverUrl.isNotEmpty
            ? serverConfig.serverUrl
            : null,
        onSave: () {
          if (!mounted) {
            return;
          }
          setState(() {});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;

    // Listen for auth state changes
    ref.listen<AuthState>(authProvider, (previous, next) {
      // Only navigate if user just became authenticated
      final wasAuthenticated = previous?.isAuthenticated ?? false;
      final isAuthenticated = next.isAuthenticated;

      if (isAuthenticated && !wasAuthenticated) {
        context.go('/feed');
      } else if (next.error != null && next.error != previous?.error) {
        // Only show snackbar for new errors
        if (mounted) {
          showTopFloatingNotice(context, message: next.error!, isError: true);
        }
      }
    });

    return Scaffold(
      body: LoadingOverlay(
        isLoading: isLoading,
        child: AuthShell(
          title: l10n.auth_welcome_back,
          subtitle: '',
          header: Column(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onLongPress: _showServerConfigDialog,
                  borderRadius: BorderRadius.circular(28),
                  child: SizedBox(
                    width: 96,
                    height: 96,
                    child: Image.asset('assets/icons/Logo3.png'),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              StatusBadge(
                label: l10n.auth_brand_name,
                icon: Icons.auto_awesome,
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CustomTextField(
                  controller: _emailController,
                  label: l10n.auth_email,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: const Icon(Icons.email_outlined),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n.auth_enter_email;
                    }
                    // Basic email format: something@something.something
                    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                    if (!emailRegex.hasMatch(value.trim())) {
                      return l10n.auth_enter_valid_email;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                PasswordTextField(
                  controller: _passwordController,
                  label: l10n.auth_password,
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
                    if (value.length < 6) {
                      return l10n.auth_password_too_short;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _rememberMe,
                        activeColor: Theme.of(context).colorScheme.primary,
                        checkColor: Colors.white,
                        side: BorderSide(
                          color: _rememberMe
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.6),
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        l10n.auth_remember_me,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        context.go('/forgot-password');
                      },
                      child: Text(l10n.auth_forgot_password),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    key: const Key('login_button'),
                    onPressed: isLoading ? null : _login,
                    child: isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          )
                        : Text(l10n.auth_login),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        l10n.auth_no_account,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/register'),
                      child: Text(l10n.auth_sign_up),
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
