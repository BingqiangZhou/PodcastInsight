import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:personal_ai_assistant/core/constants/app_radius.dart';
import 'package:personal_ai_assistant/core/constants/breakpoints.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/localization/locale_provider.dart';
import 'package:personal_ai_assistant/core/theme/font_provider.dart';
import 'package:personal_ai_assistant/core/theme/theme_provider.dart';
import 'package:personal_ai_assistant/core/widgets/app_shells.dart';
import 'package:personal_ai_assistant/core/widgets/app_dialog_helper.dart';
import 'package:personal_ai_assistant/core/widgets/responsive_dialog_helper.dart';
import 'package:personal_ai_assistant/core/widgets/top_floating_notice.dart';
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
      final authState = ref.read(authProvider);
      if (authState.isAuthenticated) {
        // Force refresh after login to ensure fresh data from new server
        ref.read(profileStatsProvider.notifier).load(forceRefresh: true);
      }
      // Load notification preference from storage
      ref.read(notificationPreferenceProvider.notifier).load();
    });
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

    return ProfileShell(
      title: l10n.profile,
      subtitle: '',
      roundedViewport: true,
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
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xlRadius),
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
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
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
        trailing: Switch(
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
        final fontCombo = ref.watch(fontCombinationProvider);
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
          subtitle: l10n.appearance_subtitle(
            themeModeName,
            fontCombo.displayName,
          ),
          onTap: () => context.push('/settings/appearance'),
        );
      },
    );
  }

  // ignore: unused_element
  Widget _buildCard(Widget child) =>
      Card(margin: EdgeInsets.zero, child: child);

  Widget _buildSettingsItem(
    BuildContext context, {
    required IconData icon, required String title, required String subtitle, Key? tileKey,
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
    required Widget Function(BuildContext dialogContext) builder, bool barrierDismissible = true,
  }) {
    return showAppDialog<T>(
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
    final l10n = context.l10n;
    final authState = ref.read(authProvider);
    final user = authState.user;
    _showConstrainedDialog<void>(
      context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.transparent,
          insetPadding: ResponsiveDialogHelper.insetPadding(),
          title: Row(
            children: [
              const Icon(Icons.edit_note),
              const SizedBox(width: 8),
              Text(l10n.profile_edit_profile),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: TextEditingController(text: user?.displayName ?? ''),
                  decoration: InputDecoration(
                    labelText: l10n.profile_name,
                    border: const OutlineInputBorder(),
                  ),
                  enabled: false,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: TextEditingController(text: user?.email ?? ''),
                  decoration: InputDecoration(
                    labelText: l10n.profile_email_field,
                    border: const OutlineInputBorder(),
                  ),
                  enabled: false,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: AppRadius.mdLgRadius,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: Theme.of(dialogContext)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.profile_edit_coming_soon_subtitle,
                          style: Theme.of(dialogContext).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
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

  void _showSecurityDialog(BuildContext context) {
    final l10n = context.l10n;
    _showConstrainedDialog<void>(
      context,
      builder: (dialogContext) {
        final iconColor = ResponsiveDialogHelper.iconColor(dialogContext);
        return AlertDialog(
          backgroundColor: Colors.transparent,
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
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    _showChangePasswordDialog(context);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.fingerprint, color: iconColor),
                  title: Text(l10n.profile_biometric_auth),
                  subtitle: Text(
                    l10n.profile_biometric_coming_soon,
                    style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                      color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: const Switch(
                    value: false,
                    onChanged: null,
                  ),
                ),
                ListTile(
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

  void _showChangePasswordDialog(BuildContext context) {
    final l10n = context.l10n;
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var isChanging = false;

    _showConstrainedDialog<void>(
      context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.transparent,
              insetPadding: ResponsiveDialogHelper.insetPadding(),
              title: Text(l10n.profile_password_change_title),
              content: SizedBox(
                width: double.maxFinite,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: currentPasswordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: l10n.profile_current_password,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock_outline),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return l10n.profile_password_required;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: newPasswordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: l10n.profile_new_password,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return l10n.profile_password_required;
                          }
                          if (value.length < 8) {
                            return l10n.profile_password_min_length;
                          }
                          if (value == currentPasswordController.text) {
                            return l10n.profile_password_same_as_old;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: l10n.profile_confirm_new_password,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return l10n.profile_password_required;
                          }
                          if (value != newPasswordController.text) {
                            return l10n.profile_password_mismatch;
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  style: ResponsiveDialogHelper.actionButtonStyle(dialogContext),
                  onPressed:
                      isChanging ? null : () => Navigator.of(dialogContext).pop(),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: isChanging
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;

                          setDialogState(() => isChanging = true);

                          try {
                            // Use the forgot-password flow since the backend
                            // does not have a dedicated change-password endpoint.
                            final authState = ref.read(authProvider);
                            final userEmail = authState.user?.email;

                            if (userEmail == null) {
                              if (dialogContext.mounted) {
                                setDialogState(() => isChanging = false);
                                Navigator.of(dialogContext).pop();
                                showTopFloatingNotice(
                                  dialogContext,
                                  message: l10n.profile_password_change_failed,
                                );
                              }
                              return;
                            }

                            await ref
                                .read(authProvider.notifier)
                                .forgotPassword(userEmail);

                            if (dialogContext.mounted) {
                              setDialogState(() => isChanging = false);
                              Navigator.of(dialogContext).pop();
                              showTopFloatingNotice(
                                dialogContext,
                                message: l10n.profile_password_reset_email_sent,
                              );
                            }
                          } catch (e) {
                            if (dialogContext.mounted) {
                              setDialogState(() => isChanging = false);
                              Navigator.of(dialogContext).pop();
                              showTopFloatingNotice(
                                dialogContext,
                                message: l10n.profile_password_change_failed,
                              );
                            }
                          }
                        },
                  child: isChanging
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(dialogContext)
                                .colorScheme
                                .onPrimary,
                          ),
                        )
                      : Text(l10n.profile_send_reset_link),
                ),
              ],
            );
          },
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

            return AlertDialog(
              backgroundColor: Colors.transparent,
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
                    onSelectionChanged: (selection) async {
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

  Future<void> _showAboutDialog(BuildContext context) async {
    final l10n = context.l10n;
    final packageInfo = await PackageInfo.fromPlatform();
    if (!context.mounted) return;

    showAppDialog<void>(
      context: context,
      builder: (dialogContext) {
        final iconColor = ResponsiveDialogHelper.iconColor(dialogContext);
        final dialogWidth = ResponsiveDialogHelper.maxWidth(
          dialogContext,
          desktopMaxWidth: 400,
        );
        return AlertDialog(
          backgroundColor: Colors.transparent,
          insetPadding: ResponsiveDialogHelper.insetPadding(),
          title: Row(
            children: [
              Icon(Icons.psychology, size: 48, color: iconColor),
              const SizedBox(width: 12),
              Expanded(child: Text(l10n.appTitle)),
            ],
          ),
          content: SizedBox(
            width: dialogWidth,
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
        return AlertDialog(
          backgroundColor: Colors.transparent,
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
