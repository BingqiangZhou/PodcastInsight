import 'package:flutter/material.dart';

import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/router/app_router.dart';
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive.dart';
import 'package:personal_ai_assistant/core/widgets/adaptive_sheet_helper.dart';

/// Represents the user's sleep timer selection.
class SleepTimerSelection {

  const SleepTimerSelection({
    this.duration,
    this.afterEpisode = false,
    this.cancel = false,
  });

  const SleepTimerSelection.afterEpisode()
    : duration = null,
      afterEpisode = true,
      cancel = false;

  const SleepTimerSelection.cancel()
    : duration = null,
      afterEpisode = false,
      cancel = true;
  /// Duration-based timer (null if after-episode mode).
  final Duration? duration;

  /// If true, stop after the current episode ends.
  final bool afterEpisode;

  /// If true, cancel the current timer.
  final bool cancel;
}

/// Preset durations for the sleep timer.
const _kSleepTimerPresets = [
  Duration(minutes: 5),
  Duration(minutes: 10),
  Duration(minutes: 15),
  Duration(minutes: 30),
  Duration(minutes: 45),
  Duration(minutes: 60),
  Duration(minutes: 90),
];

String _formatPresetDuration(Duration d, BuildContext context) {
  final l10n = context.l10n;
  if (d.inMinutes >= 60) {
    final hours = d.inHours;
    final mins = d.inMinutes.remainder(60);
    return mins > 0
        ? l10n.player_hours_minutes(hours, mins)
        : l10n.player_hours(hours);
  }
  return l10n.player_minutes(d.inMinutes);
}

/// Shows a bottom sheet for selecting a sleep timer option.
Future<SleepTimerSelection?> showSleepTimerSelectorSheet({
  required BuildContext context,
  required bool isTimerActive,
}) {
  final fallbackContext = appNavigatorKey.currentContext;
  final resolvedContext = Navigator.maybeOf(context) != null
      ? context
      : fallbackContext;
  if (resolvedContext == null) {
    return Future<SleepTimerSelection?>.value();
  }

  return showAdaptiveSheet<SleepTimerSelection>(
    context: resolvedContext,
    builder: (context) {
      final l10n = context.l10n;

      return SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.player_sleep_timer_title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.player_sleep_timer_desc,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // Duration presets
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _kSleepTimerPresets.map((preset) {
                    return ActionChip(
                      label: Text(_formatPresetDuration(preset, context)),
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).pop(SleepTimerSelection(duration: preset));
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.smMd),
                const Divider(),
                // After current episode
                AdaptiveListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.stop_circle_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(
                    context.l10n.player_stop_after_episode,
                  ),
                  onTap: () {
                    Navigator.of(
                      context,
                    ).pop(const SleepTimerSelection.afterEpisode());
                  },
                ),
                // Cancel timer (only when active)
                if (isTimerActive) ...[
                  const Divider(),
                  AdaptiveListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.timer_off,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    title: Text(
                      l10n.player_cancel_timer,
                      style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                    ),
                    onTap: () {
                      Navigator.of(
                        context,
                      ).pop(const SleepTimerSelection.cancel());
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}
