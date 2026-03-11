import 'package:flutter/material.dart';

import '../../../../core/router/app_router.dart';
import '../constants/playback_speed_options.dart';
import '../../../../core/localization/app_localizations.dart';

class PlaybackSpeedSelection {
  final double speed;
  final bool applyToSubscription;

  const PlaybackSpeedSelection({
    required this.speed,
    required this.applyToSubscription,
  });
}

Future<PlaybackSpeedSelection?> showPlaybackSpeedSelectorSheet({
  required BuildContext context,
  required double initialSpeed,
  bool initialApplyToSubscription = false,
}) {
  final fallbackContext = appNavigatorKey.currentContext;
  final resolvedContext = Navigator.maybeOf(context) != null
      ? context
      : fallbackContext;
  if (resolvedContext == null) {
    return Future<PlaybackSpeedSelection?>.value(null);
  }

  return showModalBottomSheet<PlaybackSpeedSelection>(
    context: resolvedContext,
    showDragHandle: true,
    useRootNavigator: true,
    builder: (context) {
      var selectedSpeed = initialSpeed;
      var applyToSubscription = initialApplyToSubscription;
      final theme = Theme.of(context);
      final l10n = AppLocalizations.of(context);

      return StatefulBuilder(
        builder: (context, setState) {
          return SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n?.player_playback_speed_title ?? 'Playback Speed',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: kPlaybackSpeedOptions.map((speed) {
                        return ChoiceChip(
                          label: Text(formatPlaybackSpeed(speed)),
                          selected: (selectedSpeed - speed).abs() < 0.0001,
                          onSelected: (_) {
                            setState(() {
                              selectedSpeed = speed;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: applyToSubscription,
                      onChanged: (checked) {
                        setState(() {
                          applyToSubscription = checked ?? false;
                        });
                      },
                      title: Text(
                        l10n?.player_apply_subscription_only ??
                            'Only apply to current show (current subscription)',
                      ),
                      subtitle: Text(
                        l10n?.player_apply_subscription_subtitle ??
                            'Checked: subscription only; unchecked: global',
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(context).pop(
                            PlaybackSpeedSelection(
                              speed: selectedSpeed,
                              applyToSubscription: applyToSubscription,
                            ),
                          );
                        },
                        child: Text(l10n?.apply_button ?? 'Apply'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
