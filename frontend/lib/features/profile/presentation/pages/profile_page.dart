import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:personal_ai_assistant/core/constants/app_radius.dart';
import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:personal_ai_assistant/core/constants/breakpoints.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/localization/locale_provider.dart';
import 'package:personal_ai_assistant/core/platform/platform_helper.dart';
import 'package:personal_ai_assistant/core/platform/adaptive_haptic.dart';
import 'package:personal_ai_assistant/core/theme/theme_provider.dart';
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive.dart';
import 'package:personal_ai_assistant/core/widgets/app_shells.dart';
import 'package:personal_ai_assistant/core/widgets/app_dialog_helper.dart';
import 'package:personal_ai_assistant/core/widgets/responsive_dialog_helper.dart';
import 'package:personal_ai_assistant/core/widgets/top_floating_notice.dart';
import 'package:personal_ai_assistant/features/auth/domain/models/user.dart';
import 'package:personal_ai_assistant/features/auth/presentation/providers/auth_provider.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/profile/presentation/providers/profile_ui_providers.dart';
import 'package:personal_ai_assistant/features/profile/presentation/widgets/profile_activity_cards.dart';
import 'package:personal_ai_assistant/features/settings/presentation/widgets/update_dialog.dart';
import 'package:personal_ai_assistant/shared/widgets/server_config_dialog.dart';
import 'package:personal_ai_assistant/shared/widgets/settings_section_card.dart';

/// Material Design 3 adaptive profile page
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final authState = ref.read(authProvider);
      if (authState.isAuthenticated) {
        // Force refresh after login to ensure fresh data from new server
        ref.read(profileStatsProvider.notifier).load(forceRefresh: true);
      }
    });
  }

  double _dialogMaxWidth(BuildContext context) {
    return ResponsiveDialogHelper.maxWidth(
      context,
      desktopMaxWidth: 720,
      mobileHorizontalMargin: context.spacing.xs,
    );
  }

  EdgeInsets _dialogInsetPadding(BuildContext context) {
    if (context.isMobile) {
      return EdgeInsets.symmetric(
        horizontal: context.spacing.xs,
        vertical: context.spacing.md,
      );
    }
    return EdgeInsets.all(context.spacing.md);
  }

  EdgeInsetsGeometry _profileCardMargin(BuildContext context) =>
      context.isMobile
      ? EdgeInsets.symmetric(horizontal: context.spacing.xs)
      : EdgeInsets.zero;

  ShapeBorder? _profileCardShape(BuildContext context) {
    if (!context.isMobile) {
      return null;
    }
    return RoundedRectangleBorder(
      borderRadius: AppRadius.mdLgRadius,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final theme = Theme.of(context);
    final compactProfileLayout = MediaQuery.sizeOf(context).height < 700;

    return ContentShell(
      title: l10n.profile,
      subtitle: '',
      roundedViewport: true,
      trailing: _buildUserMenu(context, user, theme, l10n),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: context.spacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ProfileActivityCards(),
            SizedBox(height: compactProfileLayout ? context.spacing.sm : context.spacing.md),
            _buildSettingsContent(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsContent(BuildContext context) {
    final l10n = context.l10n;
    final isMobile = context.isMobile;
    final theme = Theme.of(context);
    final notificationsEnabled = ref.watch(notificationPreferenceProvider);

    final accountItems = <_SettingsItemConfig>[
      _SettingsItemConfig(
        icon: Icons.shield,
        title: l10n.profile_security,
        subtitle: l10n.profile_security_subtitle,
        onTap: () => _showSecurityDialog(context),
      ),
      _SettingsItemConfig(
        icon: Icons.notifications,
        title: l10n.profile_notifications,
        subtitle: l10n.profile_notifications_subtitle,
        trailing: Switch.adaptive(
          key: const Key('profile_notifications_switch'),
          value: notificationsEnabled,
          activeThumbColor: theme.colorScheme.surface,
          inactiveThumbColor: theme.colorScheme.surface,
          activeTrackColor: theme.colorScheme.onSurfaceVariant,
          inactiveTrackColor: theme.colorScheme.onSurfaceVariant.withValues(
            alpha: 0.30,
          ),
          onChanged: (value) {
            ref.read(notificationPreferenceProvider.notifier).setEnabled(value);
          },
        ),
      ),
    ];

    final supportItems = <_SettingsItemConfig>[
      _SettingsItemConfig(
        icon: Icons.dns,
        title: l10n.backend_api_server_config,
        subtitle: l10n.backend_api_url_label,
        onTap: () => _showServerConfigDialog(context),
      ),
      _SettingsItemConfig(
        icon: Icons.cleaning_services,
        title: l10n.profile_cache_management,
        subtitle: l10n.profile_cache_management_subtitle,
        tileKey: const Key('profile_clear_cache_item'),
        onTap: () => context.push('/profile/cache'),
      ),
      _SettingsItemConfig(
        icon: Icons.download,
        title: l10n.profile_downloads,
        subtitle: l10n.profile_downloads_subtitle,
        onTap: () => context.push('/profile/downloads'),
      ),
    ];

    final aboutItems = <_SettingsItemConfig>[
      _SettingsItemConfig(
        icon: Icons.system_update_alt,
        title: l10n.update_check_updates,
        subtitle: l10n.update_auto_check,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showUpdateCheckDialog(context),
      ),
      _SettingsItemConfig(
        icon: Icons.info_outline,
        title: l10n.version,
        subtitle: ref.watch(appVersionProvider),
        trailing: const Icon(Icons.chevron_right),
        tileKey: const Key('profile_version_item'),
        onTap: () => _showAboutDialog(context),
      ),
    ];

    final preferencesSection = SettingsSectionCard(
      title: l10n.preferences,
      cardMargin: _profileCardMargin(context),
      cardShape: _profileCardShape(context),
      children: [
        _buildLanguageSettingsItem(context),
        _buildAppearanceSettingsItem(context),
      ],
    );

    if (isMobile) {
      return Column(
        children: [
          _buildSettingsSectionFromConfigs(
            context,
            l10n.profile_account_settings,
            accountItems,
          ),
          SizedBox(height: context.spacing.lg),
          preferencesSection,
          SizedBox(height: context.spacing.lg),
          _buildSettingsSectionFromConfigs(
            context,
            l10n.profile_support_section,
            supportItems,
          ),
          SizedBox(height: context.spacing.lg),
          _buildSettingsSectionFromConfigs(context, l10n.about, aboutItems),
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSettingsSectionFromConfigs(
                context,
                l10n.profile_account_settings,
                accountItems,
              ),
            ),
            SizedBox(width: context.spacing.lg),
            Expanded(child: preferencesSection),
          ],
        ),
        SizedBox(height: context.spacing.lg),
        _buildSettingsSectionFromConfigs(
          context,
          l10n.profile_support_section,
          supportItems,
        ),
        SizedBox(height: context.spacing.lg),
        _buildSettingsSectionFromConfigs(context, l10n.about, aboutItems),
      ],
    );
  }

  Widget _buildSettingsSectionFromConfigs(
    BuildContext context,
    String title,
    List<_SettingsItemConfig> items,
  ) {
    return SettingsSectionCard(
      title: title,
      cardMargin: _profileCardMargin(context),
      cardShape: _profileCardShape(context),
      children: items
          .map((item) => _buildSettingsItemFromConfig(context, item))
          .toList(),
    );
  }

  Widget _buildSettingsItemFromConfig(
    BuildContext context,
    _SettingsItemConfig item,
  ) {
    return _buildSettingsItem(
      context,
      tileKey: item.tileKey,
      icon: item.icon,
      title: item.title,
      subtitle: item.subtitle,
      trailing: item.trailing,
      onTap: item.onTap,
    );
  }

  Widget _buildLanguageSettingsItem(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final currentCode = ref.watch(localeCodeProvider);
        final l10n = context.l10n;
        final languageName = switch (currentCode) {
          kLanguageSystem => l10n.languageFollowSystem,
          kLanguageChinese => l10n.languageChinese,
          _ => l10n.languageEnglish,
        };

        return _buildSettingsItem(
          context,
          icon: Icons.language,
          title: l10n.language,
          subtitle: languageName,
          onTap: () => _showLanguageDialog(context),
        );
      },
    );
  }

  Widget _buildAppearanceSettingsItem(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final currentCode = ref.watch(themeModeCodeProvider);
        final l10n = context.l10n;
        final themeModeName = switch (currentCode) {
          kThemeModeSystem => l10n.theme_mode_follow_system,
          kThemeModeLight => l10n.theme_mode_light,
          _ => l10n.theme_mode_dark,
        };

        return _buildSettingsItem(
          context,
          icon: Icons.palette_outlined,
          title: l10n.appearance_title,
          subtitle: themeModeName,
          onTap: () => _showAppearanceDialog(context),
        );
      },
    );
  }

  Widget _buildSettingsItem(
    BuildContext context, {
    required IconData icon, required String title, required String subtitle, Key? tileKey,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return AdaptiveListTile(
      key: tileKey,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: trailing,
      onTap: onTap,
    );
  }

  // Does not use showAppDialog because profile dialogs need constrained width,
  // which showAppDialog does not support. See app_dialog_helper.dart.
  Future<T?> _showConstrainedDialog<T>(
    BuildContext context, {
    required Widget Function(BuildContext dialogContext) builder, bool barrierDismissible = true,
  }) {
    if (PlatformHelper.isApple(context)) {
      return showCupertinoDialog<T>(
        context: context,
        barrierDismissible: barrierDismissible,
        builder: (dialogContext) => Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: _dialogMaxWidth(context)),
            child: Material(
              color: Colors.transparent,
              child: builder(dialogContext),
            ),
          ),
        ),
      );
    }
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: _dialogInsetPadding(context),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _dialogMaxWidth(context)),
          child: builder(dialogContext),
        ),
      ),
    );
  }

  Widget _buildDialog({
    required BuildContext dialogContext,
    required Widget title,
    required Widget content,
    required List<Widget> actions,
  }) {
    final isIOS = PlatformHelper.isApple(dialogContext);
    final theme = Theme.of(dialogContext);

    return Container(
      decoration: BoxDecoration(
        color: isIOS
            ? CupertinoColors.systemBackground.resolveFrom(dialogContext)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(isIOS ? 14 : 28),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(context.spacing.lg, isIOS ? AppSpacing.mdLg : AppSpacing.lg, context.spacing.lg, isIOS ? AppSpacing.sm : AppSpacing.md),
            child: Align(
              alignment: isIOS ? Alignment.center : AlignmentDirectional.centerStart,
              child: DefaultTextStyle(
                style: isIOS
                    ? CupertinoTheme.of(dialogContext)
                        .textTheme
                        .textStyle
                        .copyWith(fontSize: theme.textTheme.titleLarge?.fontSize, fontWeight: FontWeight.w600)
                    : theme.textTheme.titleLarge!,
                child: title,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(context.spacing.lg, 0, context.spacing.lg, context.spacing.md),
            child: Align(
              alignment: isIOS ? Alignment.center : AlignmentDirectional.centerStart,
              child: DefaultTextStyle(
                style: isIOS
                    ? CupertinoTheme.of(dialogContext)
                        .textTheme
                        .textStyle
                        .copyWith(fontSize: theme.textTheme.bodyMedium?.fontSize)
                    : theme.textTheme.bodyMedium!,
                child: content,
              ),
            ),
          ),
          if (actions.isNotEmpty) ...[
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
            if (isIOS)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: actions
                      .map((a) => Expanded(child: a))
                      .toList(),
                ),
              )
            else
              Padding(
                padding: EdgeInsets.fromLTRB(context.spacing.md, context.spacing.smMd, context.spacing.md, context.spacing.smMd),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions,
                ),
              ),
          ],
        ],
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    final l10n = context.l10n;
    _showConstrainedDialog<void>(
      context,
      builder: (dialogContext) {
        return _buildDialog(
          dialogContext: dialogContext,
          title: Text(l10n.profile_edit_profile),
          content: Text(l10n.profile_edit_coming_soon_subtitle),
          actions: [
            AdaptiveButton(
              style: AdaptiveButtonStyle.text,
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.ok),
            ),
          ],
        );
      },
    );
  }

  void _showSecurityDialog(BuildContext context) {
    final l10n = context.l10n;
    _showConstrainedDialog<void>(
      context,
      builder: (dialogContext) {
        final iconColor = ResponsiveDialogHelper.iconColor(dialogContext);
        return _buildDialog(
          dialogContext: dialogContext,
          title: Text(l10n.profile_security),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AdaptiveListTile(
                leading: Icon(Icons.password, color: iconColor),
                title: Text(l10n.profile_change_password),
                trailing: Icon(
                  PlatformHelper.isApple(dialogContext)
                      ? CupertinoIcons.chevron_right
                      : Icons.chevron_right,
                  color: iconColor,
                ),
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  _showChangePasswordDialog(context);
                },
              ),
              AdaptiveListTile(
                leading: Icon(Icons.fingerprint, color: iconColor),
                title: Text(l10n.profile_biometric_auth),
                subtitle: Text(
                  l10n.profile_biometric_coming_soon,
                  style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                    color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: const Switch.adaptive(
                  value: false,
                  onChanged: null,
                ),
              ),
              AdaptiveListTile(
                leading: Icon(Icons.phone_android, color: iconColor),
                title: Text(l10n.profile_two_factor_auth),
                subtitle: Text(
                  l10n.profile_two_factor_coming_soon,
                  style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                    color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: const Icon(Icons.schedule, size: 20),
              ),
            ],
          ),
          actions: [
            AdaptiveButton(
              style: AdaptiveButtonStyle.text,
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.close),
            ),
          ],
        );
      },
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final l10n = context.l10n;
    final authState = ref.read(authProvider);
    final userEmail = authState.user?.email;

    _showConstrainedDialog<void>(
      context,
      builder: (dialogContext) {
        return _buildDialog(
          dialogContext: dialogContext,
          title: Text(l10n.profile_password_change_title),
          content: Text(
            userEmail != null
                ? l10n.profile_password_reset_email_description(userEmail)
                : l10n.profile_password_change_failed,
          ),
          actions: [
            AdaptiveButton(
              style: AdaptiveButtonStyle.text,
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
            if (userEmail != null)
              AdaptiveButton(
                style: AdaptiveButtonStyle.filled,
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  try {
                    await ref
                        .read(authProvider.notifier)
                        .forgotPassword(userEmail);
                    if (context.mounted) {
                      final l10n = context.l10n;
                      showTopFloatingNotice(
                        context,
                        message: l10n.profile_password_reset_email_sent,
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      final l10n = context.l10n;
                      showTopFloatingNotice(
                        context,
                        message: l10n.profile_password_change_failed,
                      );
                    }
                  }
                },
                child: Text(l10n.profile_send_reset_link),
              ),
          ],
        );
      },
    );
  }

  void _showLanguageDialog(BuildContext context) {
    _showConstrainedDialog<void>(
      context,
      builder: (dialogContext) {
        return Consumer(
          builder: (dialogContext, ref, _) {
            final currentCode = ref.watch(localeCodeProvider);
            final l10n = dialogContext.l10n;
            final iconColor = ResponsiveDialogHelper.iconColor(dialogContext);

            return _buildDialog(
              dialogContext: dialogContext,
              title: Text(l10n.language),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AdaptiveSegmentedControl<String>(
                    key: const Key('profile_language_segmented_button'),
                    segments: {
                      kLanguageSystem: Text(l10n.languageFollowSystem),
                      kLanguageEnglish: Text(l10n.languageEnglish),
                      kLanguageChinese: Text(l10n.languageChinese),
                    },
                    selected: currentCode,
                    onChanged: (value) async {
                      await ref
                          .read(localeProvider.notifier)
                          .setLanguageCode(value);
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    },
                  ),
                  SizedBox(height: context.spacing.md),
                  Text(
                    l10n.languageFollowSystem,
                    style: Theme.of(
                      dialogContext,
                    ).textTheme.bodySmall?.copyWith(color: iconColor),
                  ),
                ],
              ),
              actions: [
                AdaptiveButton(
                  style: AdaptiveButtonStyle.text,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(l10n.close),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showAboutDialog(BuildContext context) async {
    final l10n = context.l10n;
    final packageInfo = await PackageInfo.fromPlatform();
    if (!context.mounted) return;

    _showConstrainedDialog<void>(
      context,
      builder: (dialogContext) {
        final iconColor = ResponsiveDialogHelper.iconColor(dialogContext);
        return _buildDialog(
          dialogContext: dialogContext,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.psychology, size: 48, color: iconColor),
              SizedBox(width: context.spacing.smMd),
              Flexible(child: Text(l10n.appTitle)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.version_label(packageInfo.version),
                style: Theme.of(
                  dialogContext,
                ).textTheme.bodyLarge?.copyWith(color: iconColor),
              ),
              SizedBox(height: context.spacing.xs),
              Text(
                l10n.build_label(packageInfo.buildNumber),
                style: Theme.of(
                  dialogContext,
                ).textTheme.bodyLarge?.copyWith(color: iconColor),
              ),
              SizedBox(height: context.spacing.sm),
              Text(
                l10n.profile_about_subtitle,
                style: Theme.of(
                  dialogContext,
                ).textTheme.bodyLarge?.copyWith(color: iconColor),
              ),
            ],
          ),
          actions: [
            AdaptiveButton(
              style: AdaptiveButtonStyle.text,
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.ok),
            ),
          ],
        );
      },
    );
  }

  void _showAppearanceDialog(BuildContext context) {
    _showConstrainedDialog<void>(
      context,
      builder: (dialogContext) {
        return Consumer(
          builder: (dialogContext, ref, _) {
            final currentCode = ref.watch(themeModeCodeProvider);
            final l10n = dialogContext.l10n;
            final iconColor = ResponsiveDialogHelper.iconColor(dialogContext);

            return _buildDialog(
              dialogContext: dialogContext,
              title: Text(l10n.appearance_title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AdaptiveSegmentedControl<String>(
                    key: const Key('profile_appearance_segmented_button'),
                    segments: {
                      kThemeModeSystem: Text(l10n.theme_mode_follow_system),
                      kThemeModeLight: Text(l10n.theme_mode_light),
                      kThemeModeDark: Text(l10n.theme_mode_dark),
                    },
                    selected: currentCode,
                    onChanged: (value) async {
                      if (value == currentCode) return;
                      final modeName = switch (value) {
                        kThemeModeSystem => l10n.theme_mode_follow_system,
                        kThemeModeLight => l10n.theme_mode_light,
                        _ => l10n.theme_mode_dark,
                      };
                      await ref
                          .read(themeModeProvider.notifier)
                          .setThemeModeCode(value);
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                        showTopFloatingNotice(
                          context,
                          message: l10n.theme_mode_changed(modeName),
                        );
                      }
                    },
                  ),
                  SizedBox(height: context.spacing.md),
                  Text(
                    l10n.theme_mode_subtitle,
                    style: Theme.of(
                      dialogContext,
                    ).textTheme.bodySmall?.copyWith(color: iconColor),
                  ),
                ],
              ),
              actions: [
                AdaptiveButton(
                  style: AdaptiveButtonStyle.text,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(l10n.close),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showServerConfigDialog(BuildContext context) {
    showAppDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ServerConfigDialog(),
    );
  }

  void _showUpdateCheckDialog(BuildContext context) {
    ManualUpdateCheckDialog.show(context);
  }

  void _showLogoutDialog(BuildContext context) {
    final l10n = context.l10n;
    _showConstrainedDialog<void>(
      context,
      builder: (dialogContext) {
        return _buildDialog(
          dialogContext: dialogContext,
          title: Text(l10n.profile_logout_title),
          content: Text(l10n.profile_logout_message),
          actions: [
            AdaptiveButton(
              style: AdaptiveButtonStyle.text,
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
            AdaptiveButton(
              style: AdaptiveButtonStyle.filled,
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) {
                  final l10n = context.l10n;
                  showTopFloatingNotice(
                    context,
                    message: l10n.profile_logged_out,
                  );
                }
              },
              child: Text(l10n.logout),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUserMenu(
    BuildContext context,
    User? user,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final avatar = CircleAvatar(
      radius: 22,
      backgroundColor: theme.colorScheme.onSurfaceVariant,
      child: Text(
        (user?.displayName ?? l10n.profile_guest_user).characters.firstOrNull?.toUpperCase() ?? '?',
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.surface,
        ),
      ),
    );

    return GestureDetector(
      key: const Key('profile_user_menu_button'),
      onTap: () {
        AdaptiveHaptic.lightImpact();
        _showUserMenu(context, user, l10n);
      },
      child: avatar,
    );
  }

  void _showUserMenu(
    BuildContext context,
    User? user,
    AppLocalizations l10n,
  ) {
    showAdaptiveActionSheet(
      context: context,
      title: Text(user?.displayName ?? l10n.profile_guest_user),
      message: Text(user?.email ?? l10n.profile_please_login),
      actions: [
        AdaptiveActionSheetAction(
          key: const Key('profile_user_menu_item_edit'),
          onPressed: () => _showEditProfileDialog(context),
          child: Text(l10n.profile_edit_profile),
        ),
        AdaptiveActionSheetAction(
          key: const Key('profile_user_menu_item_logout'),
          onPressed: () => _showLogoutDialog(context),
          isDestructive: true,
          child: Text(l10n.logout),
        ),
      ],
      cancelWidget: Text(l10n.cancel),
    );
  }
}

class _SettingsItemConfig {
  const _SettingsItemConfig({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.tileKey,
    this.trailing,
    this.onTap,
  });

  final Key? tileKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
}
