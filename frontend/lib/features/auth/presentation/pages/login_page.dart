import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_ai_assistant/core/app/config/app_config.dart';
import 'package:personal_ai_assistant/core/constants/app_radius.dart';
import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/platform/adaptive_haptic.dart';
import 'package:personal_ai_assistant/core/providers/core_providers.dart';
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive.dart';
import 'package:personal_ai_assistant/core/widgets/app_shells.dart';
import 'package:personal_ai_assistant/core/widgets/app_dialog_helper.dart';
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
    final storage = ref.read(secureStorageProvider);
    final savedUsername = await storage.get(AppConstants.savedUsernameKey);
    final savedPassword = await storage.get(AppConstants.savedPasswordKey);

    if (!mounted) return;

    if (savedUsername != null) {
      setState(() {
        _emailController.text = savedUsername;
        _passwordController.text = savedPassword ?? '';
        _rememberMe = true;
      });
    }
  }

  Future<void> _login() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    try {
      if (_rememberMe) {
        final storage = ref.read(secureStorageProvider);
        await storage.save(AppConstants.savedUsernameKey, _emailController.text.trim());
        await storage.save(AppConstants.savedPasswordKey, _passwordController.text);
      } else {
        final storage = ref.read(secureStorageProvider);
        await storage.remove(AppConstants.savedUsernameKey);
        await storage.remove(AppConstants.savedPasswordKey);
      }
    } catch (_) {
      // Storage failure should not block login.
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
    showAppDialog(
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
    final isLoading = ref.watch(authProvider.select((s) => s.isLoading));

    // Listen for auth state changes
    ref.listen<AuthState>(authProvider, (previous, next) {
      // Only navigate if user just became authenticated
      final wasAuthenticated = previous?.isAuthenticated ?? false;
      final isAuthenticated = next.isAuthenticated;

      if (isAuthenticated && !wasAuthenticated) {
        AdaptiveHaptic.notificationSuccess();
        context.go('/feed');
      } else if (next.error != null && next.error != previous?.error) {
        // Only show snackbar for new errors
        if (mounted) {
          showTopFloatingNotice(context, message: next.error!, isError: true);
        }
      }
    });

    return AdaptiveScaffold(
      child: LoadingOverlay(
        isLoading: isLoading,
        child: AuthShell(
          title: l10n.auth_welcome_back,
          subtitle: '',
          backgroundColor: Colors.transparent,
          showBorder: false,
          titleWidget: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onLongPress: _showServerConfigDialog,
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: Image.asset('assets/icons/Logo3.png'),
                ),
              ),
              SizedBox(width: context.spacing.md),
              Flexible(
                child: Text(
                  l10n.auth_welcome_back,
                  style: Theme.of(context).textTheme.headlineLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CustomTextField(
                  controller: _emailController,
                  label: l10n.auth_email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  prefixIcon: const Icon(Icons.email_outlined),
                  autofillHints: const [AutofillHints.username, AutofillHints.email],
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
                SizedBox(height: context.spacing.md),
                PasswordTextField(
                  controller: _passwordController,
                  label: l10n.auth_password,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
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
                SizedBox(height: context.spacing.md),
                Row(
                  children: [
                    AdaptiveSwitch(
                      value: _rememberMe,
                      semanticLabel: l10n.auth_remember_me,
                      onChanged: (value) async {
                        setState(() {
                          _rememberMe = value;
                        });
                        if (!_rememberMe) {
                          final storage = ref.read(secureStorageProvider);
                          await storage.remove(AppConstants.savedUsernameKey);
                          await storage.remove(AppConstants.savedPasswordKey);
                        }
                      },
                    ),
                    SizedBox(width: context.spacing.sm),
                    Flexible(
                      child: Text(
                        l10n.auth_remember_me,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Spacer(),
                    AdaptiveButton(
                      style: AdaptiveButtonStyle.text,
                      onPressed: () {
                        context.go('/forgot-password');
                      },
                      child: Text(l10n.auth_forgot_password),
                    ),
                  ],
                ),
                SizedBox(height: context.spacing.lg),
                AdaptiveButton(
                  key: const Key('login_button'),
                  style: AdaptiveButtonStyle.filled,
                  onPressed: isLoading ? null : _login,
                  isLoading: isLoading,
                  child: Text(l10n.auth_login),
                ),
                SizedBox(height: context.spacing.mdLg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        l10n.auth_no_account,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    AdaptiveButton(
                      style: AdaptiveButtonStyle.text,
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
      ),
    );
  }
}
