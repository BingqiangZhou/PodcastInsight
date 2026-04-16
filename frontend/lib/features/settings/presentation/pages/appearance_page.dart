import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:personal_ai_assistant/core/constants/breakpoints.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/theme/theme_provider.dart';
import 'package:personal_ai_assistant/core/widgets/app_shells.dart';
import 'package:personal_ai_assistant/core/widgets/responsive_dialog_helper.dart';
import 'package:personal_ai_assistant/core/widgets/top_floating_notice.dart';
import 'package:personal_ai_assistant/shared/widgets/settings_section_card.dart';

/// Appearance settings page with theme mode selection.
class AppearancePage extends ConsumerWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return ProfileShell(
      title: l10n.appearance_title,
      subtitle: '',
      summary: const SizedBox.shrink(),
      trailing: _buildBackButton(context),
      child: SettingsSectionCard(
        title: l10n.appearance_theme_section,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.smMd,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: Text(
              l10n.theme_mode_subtitle,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: _ThemeModeSelector(),
          ),
        ],
      ),
    );
  }

  Widget? _buildBackButton(BuildContext context) {
    final isMobile = context.isMobile;
    if (isMobile) return null;
    return HeaderCapsuleActionButton(
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      icon: Icons.arrow_back_rounded,
      onPressed: () => context.canPop() ? context.pop() : context.go('/'),
      circular: true,
    );
  }
}

/// Theme mode selection with SegmentedButton.
class _ThemeModeSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final currentCode = ref.watch(themeModeCodeProvider);

    return SegmentedButton<String>(
      key: const Key('appearance_theme_segmented_button'),
      style: ResponsiveDialogHelper.segmentedButtonStyle(context),
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
      onSelectionChanged: (selection) async {
        final value = selection.first;
        final modeName = switch (value) {
          kThemeModeSystem => l10n.theme_mode_follow_system,
          kThemeModeLight => l10n.theme_mode_light,
          _ => l10n.theme_mode_dark,
        };
        await ref.read(themeModeProvider.notifier).setThemeModeCode(value);
        if (context.mounted) {
          showTopFloatingNotice(
            context,
            message: l10n.theme_mode_changed(modeName),
          );
        }
      },
    );
  }
}
