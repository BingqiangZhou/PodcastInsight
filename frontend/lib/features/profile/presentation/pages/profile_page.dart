import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:personal_ai_assistant/core/constants/breakpoints.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/localization/locale_provider.dart';
import 'package:personal_ai_assistant/core/theme/theme_provider.dart';
import 'package:personal_ai_assistant/core/widgets/app_shells.dart';
import 'package:personal_ai_assistant/core/widgets/responsive_dialog_helper.dart';
import 'package:personal_ai_assistant/core/widgets/top_floating_notice.dart';
import 'package:personal_ai_assistant/features/settings/presentation/widgets/update_dialog.dart';

import '../widgets/profile_activity_cards.dart';
import '../../../../shared/widgets/server_config_dialog.dart';
import '../../../../shared/widgets/settings_section_card.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../podcast/presentation/providers/podcast_providers.dart';
import '../../../../core/utils/app_logger.dart' as logger;

/// Material Design 3 adaptive profile page
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  bool _notificationsEnabled = true;
  String _appVersion = 'Loading...';
  int _versionTapCount = 0;
  DateTime? _lastVersionTapAt;
  Timer? _versionTapTimer;

  static const Duration _versionTapWindow = Duration(milliseconds: 1200);

  @override
  void initState() {
    super.initState();
    _loadVersion();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(profileStatsProvider.notifier).load(forceRefresh: false);
    });
  }

  @override
  void dispose() {
    _versionTapTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = 'v${packageInfo.version} (${packageInfo.buildNumber})';
        });
      }
    } catch (e) {
      logger.AppLogger.debug('Error loading version: $e');
      if (mounted) {
        setState(() {
          _appVersion = 'Unknown';
        });
      }
    }
  }

  double _dialogMaxWidth(BuildContext context) {
    return ResponsiveDialogHelper.maxWidth(context);
  }

  EdgeInsetsGeometry _profileCardMargin(BuildContext context) =>
      context.isMobile
      ? const EdgeInsets.symmetric(horizontal: 4)
      : EdgeInsets.zero;

  ShapeBorder? _profileCardShape(BuildContext context) {
    if (!context.isMobile) {
      return null;
    }
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide.none,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final theme = Theme.of(context);
    final compactProfileLayout = MediaQuery.of(context).size.height < 700;

    return ProfileShell(
      title: l10n.profile,
      subtitle: '',
      roundedViewport: true,
      badges: const [],
      trailing: PopupMenuButton<String>(
        key: const Key('profile_user_menu_button'),
        onSelected: (value) {
          if (value == 'edit') {
            _showEditProfileDialog(context);
          } else if (value == 'logout') {
            _showLogoutDialog(context);
          }
        },
        offset: const Offset(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        itemBuilder: (context) => [
          PopupMenuItem<String>(
            enabled: false,
            child: Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    user?.displayName ?? l10n.profile_guest_user,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuItem<String>(
            enabled: false,
            child: Row(
              children: [
                Icon(
                  Icons.email_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    user?.email ?? l10n.profile_please_login,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            value: 'edit',
            key: const Key('profile_user_menu_item_edit'),
            child: Row(
              children: [
                const Icon(Icons.edit_note, size: 20),
                const SizedBox(width: 8),
                Text(l10n.profile_edit_profile),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'logout',
            key: const Key('profile_user_menu_item_logout'),
            child: Row(
              children: [
                Icon(
                  Icons.logout,
                  size: 20,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.logout,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ),
          ),
        ],
        child: CircleAvatar(
          radius: 22,
          backgroundColor: theme.colorScheme.onSurfaceVariant,
          child: Text(
            (user?.displayName ?? l10n.profile_guest_user).characters.first
                .toUpperCase(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.surface,
            ),
          ),
        ),
      ),
      summary: const SizedBox.shrink(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProfileActivityCards(),
          SizedBox(height: compactProfileLayout ? 8 : 12),
          _buildSettingsContent(context),
        ],
      ),
    );
  }

  Widget _buildSettingsContent(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isMobile = context.isMobile;
    final theme = Theme.of(context);

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
        trailing: Switch(
          key: const Key('profile_notifications_switch'),
          value: _notificationsEnabled,
          activeThumbColor: theme.colorScheme.surface,
          inactiveThumbColor: theme.colorScheme.surface,
          activeTrackColor: theme.colorScheme.onSurfaceVariant,
          inactiveTrackColor: theme.colorScheme.onSurfaceVariant.withValues(
            alpha: 0.30,
          ),
          onChanged: (value) {
            setState(() {
              _notificationsEnabled = value;
            });
          },
        ),
      ),
    ];

    final supportItems = <_SettingsItemConfig>[
      _SettingsItemConfig(
        icon: Icons.help,
        title: l10n.profile_help_center,
        subtitle: l10n.profile_help_center_subtitle,
        onTap: () => _showHelpDialog(context),
      ),
      _SettingsItemConfig(
        icon: Icons.cleaning_services,
        title: l10n.profile_cache_management,
        subtitle: l10n.profile_cache_management_subtitle,
        tileKey: const Key('profile_clear_cache_item'),
        onTap: () => context.push('/profile/cache'),
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
        subtitle: _getVersionSubtitle(),
        trailing: const Icon(Icons.chevron_right),
        tileKey: const Key('profile_version_item'),
        onTap: () => _handleVersionTap(context),
      ),
    ];

    final preferencesSection = SettingsSectionCard(
      title: l10n.preferences,
      cardMargin: _profileCardMargin(context),
      cardShape: _profileCardShape(context),
      children: [
        _buildLanguageSettingsItem(context),
        _buildThemeSettingsItem(context),
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
          const SizedBox(height: 24),
          preferencesSection,
          const SizedBox(height: 24),
          _buildSettingsSectionFromConfigs(
            context,
            l10n.profile_support_section,
            supportItems,
          ),
          const SizedBox(height: 24),
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
            const SizedBox(width: 16),
            Expanded(child: preferencesSection),
          ],
        ),
        const SizedBox(height: 24),
        _buildSettingsSectionFromConfigs(
          context,
          l10n.profile_support_section,
          supportItems,
        ),
        const SizedBox(height: 24),
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
        final l10n = AppLocalizations.of(context)!;
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

  Widget _buildThemeSettingsItem(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final currentCode = ref.watch(themeModeCodeProvider);
        final l10n = AppLocalizations.of(context)!;
        final themeModeName = switch (currentCode) {
          kThemeModeSystem => l10n.theme_mode_follow_system,
          kThemeModeLight => l10n.theme_mode_light,
          _ => l10n.theme_mode_dark,
        };

        return _buildSettingsItem(
          context,
          icon: Icons.dark_mode,
          title: l10n.theme_mode,
          subtitle: themeModeName,
          onTap: () => _showThemeModeDialog(context),
        );
      },
    );
  }

  // ignore: unused_element
  Widget _buildCard(Widget child) =>
      Card(margin: EdgeInsets.zero, child: child);

  Widget _buildSettingsItem(
    BuildContext context, {
    Key? tileKey,
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      key: tileKey,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Future<T?> _showConstrainedDialog<T>(
    BuildContext context, {
    bool barrierDismissible = true,
    required Widget Function(BuildContext dialogContext) builder,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (dialogContext) => LayoutBuilder(
        builder: (dialogContext, constraints) {
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: _dialogMaxWidth(dialogContext),
            ),
            child: builder(dialogContext),
          );
        },
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    _showConstrainedDialog<void>(
      context,
      builder: (dialogContext) {
        return AlertDialog(
          insetPadding: ResponsiveDialogHelper.insetPadding(),
          title: Text(l10n.profile_edit_profile),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: InputDecoration(
                    labelText: l10n.profile_name,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: InputDecoration(
                    labelText: l10n.profile_email_field,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: InputDecoration(
                    labelText: l10n.profile_bio,
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                showTopFloatingNotice(
                  context,
                  message: l10n.profile_updated_successfully,
                );
              },
              child: Text(l10n.save),
            ),
          ],
        );
      },
    );
  }

  void _showSecurityDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    _showConstrainedDialog<void>(
      context,
      builder: (dialogContext) {
        final iconColor = ResponsiveDialogHelper.iconColor(dialogContext);
        return AlertDialog(
          insetPadding: ResponsiveDialogHelper.insetPadding(),
          title: Text(l10n.profile_security),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.password, color: iconColor),
                  title: Text(l10n.profile_change_password),
                  trailing: Icon(Icons.chevron_right, color: iconColor),
                ),
                ListTile(
                  leading: Icon(Icons.fingerprint, color: iconColor),
                  title: Text(l10n.profile_biometric_auth),
                  trailing: Switch(value: true, onChanged: null),
                ),
                ListTile(
                  leading: Icon(Icons.phone_android, color: iconColor),
                  title: Text(l10n.profile_two_factor_auth),
                  trailing: Icon(Icons.chevron_right, color: iconColor),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              style: ResponsiveDialogHelper.actionButtonStyle(dialogContext),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.close),
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
            final l10n = AppLocalizations.of(dialogContext)!;
            final iconColor = ResponsiveDialogHelper.iconColor(dialogContext);

            return AlertDialog(
              insetPadding: ResponsiveDialogHelper.insetPadding(),
              title: Text(l10n.language),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SegmentedButton<String>(
                    key: const Key('profile_language_segmented_button'),
                    style: ResponsiveDialogHelper.segmentedButtonStyle(
                      dialogContext,
                    ),
                    segments: [
                      ButtonSegment(
                        value: kLanguageSystem,
                        label: Text(l10n.languageFollowSystem),
                        icon: const Icon(Icons.computer),
                      ),
                      ButtonSegment(
                        value: kLanguageEnglish,
                        label: Text(l10n.languageEnglish),
                        icon: const Icon(Icons.language),
                      ),
                      ButtonSegment(
                        value: kLanguageChinese,
                        label: Text(l10n.languageChinese),
                        icon: const Icon(Icons.translate),
                      ),
                    ],
                    selected: {currentCode},
                    onSelectionChanged: (Set<String> selection) async {
                      final value = selection.first;
                      await ref
                          .read(localeProvider.notifier)
                          .setLanguageCode(value);
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.languageFollowSystem,
                    style: Theme.of(
                      dialogContext,
                    ).textTheme.bodySmall?.copyWith(color: iconColor),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  style: ResponsiveDialogHelper.actionButtonStyle(dialogContext),
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

  void _showThemeModeDialog(BuildContext pageContext) {
    _showConstrainedDialog<void>(
      pageContext,
      builder: (dialogContext) {
        return Consumer(
          builder: (dialogContext, ref, _) {
            final currentCode = ref.watch(themeModeCodeProvider);
            final l10n = AppLocalizations.of(dialogContext)!;
            final iconColor = ResponsiveDialogHelper.iconColor(dialogContext);

            return AlertDialog(
              insetPadding: ResponsiveDialogHelper.insetPadding(),
              title: Text(l10n.theme_mode_select_title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SegmentedButton<String>(
                    key: const Key('profile_theme_segmented_button'),
                    style: ResponsiveDialogHelper.segmentedButtonStyle(
                      dialogContext,
                    ),
                    segments: [
                      ButtonSegment(
                        value: kThemeModeSystem,
                        label: Text(l10n.theme_mode_follow_system),
                        icon: const Icon(Icons.brightness_auto),
                      ),
                      ButtonSegment(
                        value: kThemeModeLight,
                        label: Text(l10n.theme_mode_light),
                        icon: const Icon(Icons.light_mode),
                      ),
                      ButtonSegment(
                        value: kThemeModeDark,
                        label: Text(l10n.theme_mode_dark),
                        icon: const Icon(Icons.dark_mode),
                      ),
                    ],
                    selected: {currentCode},
                    onSelectionChanged: (Set<String> selection) async {
                      final value = selection.first;
                      final modeName = switch (value) {
                        kThemeModeSystem => l10n.theme_mode_follow_system,
                        kThemeModeLight => l10n.theme_mode_light,
                        _ => l10n.theme_mode_dark,
                      };
                      await ref
                          .read(themeModeProvider.notifier)
                          .setThemeModeCode(value);
                      if (!dialogContext.mounted) {
                        return;
                      }
                      final noticeMessage = l10n.theme_mode_changed(modeName);
                      Navigator.of(dialogContext).pop();
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        Future<void>.delayed(kThemeAnimationDuration, () {
                          if (!pageContext.mounted) {
                            return;
                          }
                          showTopFloatingNotice(
                            pageContext,
                            message: noticeMessage,
                          );
                        });
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.theme_mode_subtitle,
                    style: Theme.of(
                      dialogContext,
                    ).textTheme.bodySmall?.copyWith(color: iconColor),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  style: ResponsiveDialogHelper.actionButtonStyle(dialogContext),
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

  void _showHelpDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    _showConstrainedDialog<void>(
      context,
      builder: (dialogContext) {
        final iconColor = ResponsiveDialogHelper.iconColor(dialogContext);
        return AlertDialog(
          insetPadding: ResponsiveDialogHelper.insetPadding(),
          title: Text(l10n.profile_help_center),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.book, color: iconColor),
                  title: Text(l10n.profile_user_guide),
                  subtitle: Text(l10n.profile_user_guide_subtitle),
                ),
                ListTile(
                  leading: Icon(Icons.video_library, color: iconColor),
                  title: Text(l10n.profile_video_tutorials),
                  subtitle: Text(l10n.profile_video_tutorials_subtitle),
                ),
                ListTile(
                  leading: Icon(Icons.contact_support, color: iconColor),
                  title: Text(l10n.profile_contact_support),
                  subtitle: Text(l10n.profile_contact_support_subtitle),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              style: ResponsiveDialogHelper.actionButtonStyle(dialogContext),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.close),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAboutDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final packageInfo = await PackageInfo.fromPlatform();
    if (!context.mounted) return;

    _showConstrainedDialog<void>(
      context,
      builder: (dialogContext) {
        final iconColor = ResponsiveDialogHelper.iconColor(dialogContext);
        return AlertDialog(
          insetPadding: ResponsiveDialogHelper.insetPadding(),
          title: Row(
            children: [
              Icon(Icons.psychology, size: 48, color: iconColor),
              const SizedBox(width: 12),
              Expanded(child: Text(l10n.appTitle)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.version_label(packageInfo.version),
                  style: Theme.of(
                    dialogContext,
                  ).textTheme.bodyLarge?.copyWith(color: iconColor),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.build_label(packageInfo.buildNumber),
                  style: Theme.of(
                    dialogContext,
                  ).textTheme.bodyLarge?.copyWith(color: iconColor),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.profile_about_subtitle,
                  style: Theme.of(
                    dialogContext,
                  ).textTheme.bodyLarge?.copyWith(color: iconColor),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              style: ResponsiveDialogHelper.actionButtonStyle(dialogContext),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.ok),
            ),
          ],
        );
      },
    );
  }

  /// Get version subtitle for display
  String _getVersionSubtitle() {
    return _appVersion;
  }

  void _handleVersionTap(BuildContext context) {
    final now = DateTime.now();
    final isWithinWindow =
        _lastVersionTapAt != null &&
        now.difference(_lastVersionTapAt!) <= _versionTapWindow;

    if (!isWithinWindow) {
      _versionTapCount = 0;
    }

    _lastVersionTapAt = now;
    _versionTapCount += 1;
    _versionTapTimer?.cancel();

    if (_versionTapCount >= 5) {
      _resetVersionTapState();
      _showServerConfigDialog(context);
      return;
    }

    _versionTapTimer = Timer(_versionTapWindow, () {
      if (!mounted) return;
      final shouldShowAbout = _versionTapCount == 1;
      _resetVersionTapState();
      if (shouldShowAbout) {
        _showAboutDialog(context);
      }
    });
  }

  void _resetVersionTapState() {
    _versionTapTimer?.cancel();
    _versionTapTimer = null;
    _versionTapCount = 0;
    _lastVersionTapAt = null;
  }

  void _showServerConfigDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ServerConfigDialog(),
    );
  }

  void _showUpdateCheckDialog(BuildContext context) {
    ManualUpdateCheckDialog.show(context);
  }

  void _showLogoutDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    _showConstrainedDialog<void>(
      context,
      builder: (dialogContext) {
        return AlertDialog(
          insetPadding: ResponsiveDialogHelper.insetPadding(),
          title: Text(l10n.profile_logout_title),
          content: Text(l10n.profile_logout_message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) {
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
