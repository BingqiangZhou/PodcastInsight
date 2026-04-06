import 'package:flutter/material.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/router/app_router.dart';
import 'package:personal_ai_assistant/core/utils/app_logger.dart' as logger;
import 'package:personal_ai_assistant/core/widgets/adaptive_sheet_helper.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/constants/playback_speed_options.dart';

typedef PlaybackSpeedSheetInitialSelection = ({
  double speed,
  bool applyToSubscription,
});

class PlaybackSpeedSelection {

  const PlaybackSpeedSelection({
    required this.speed,
    required this.applyToSubscription,
  });
  final double speed;
  final bool applyToSubscription;
}

Future<PlaybackSpeedSelection?> showPlaybackSpeedSelectorSheet({
  required BuildContext context,
  required double initialSpeed,
  bool initialApplyToSubscription = false,
  Future<PlaybackSpeedSheetInitialSelection>? correctedInitialSelection,
  bool allowApplyToSubscription = true,
}) {
  final fallbackContext = appNavigatorKey.currentContext;
  final resolvedContext = Navigator.maybeOf(context) != null
      ? context
      : fallbackContext;
  if (resolvedContext == null) {
    return Future<PlaybackSpeedSelection?>.value();
  }

  return showAdaptiveSheet<PlaybackSpeedSelection>(
    context: resolvedContext,
    builder: (context) => _PlaybackSpeedSelectorSheet(
      initialSpeed: initialSpeed,
      initialApplyToSubscription: initialApplyToSubscription,
      correctedInitialSelection: correctedInitialSelection,
      allowApplyToSubscription: allowApplyToSubscription,
    ),
  );
}

class _PlaybackSpeedSelectorSheet extends StatefulWidget {
  const _PlaybackSpeedSelectorSheet({
    required this.initialSpeed,
    required this.initialApplyToSubscription,
    required this.allowApplyToSubscription,
    this.correctedInitialSelection,
  });

  final double initialSpeed;
  final bool initialApplyToSubscription;
  final Future<PlaybackSpeedSheetInitialSelection>? correctedInitialSelection;
  final bool allowApplyToSubscription;

  @override
  State<_PlaybackSpeedSelectorSheet> createState() =>
      _PlaybackSpeedSelectorSheetState();
}

class _PlaybackSpeedSelectorSheetState
    extends State<_PlaybackSpeedSelectorSheet> {
  late double _selectedSpeed = widget.initialSpeed;
  late bool _applyToSubscription =
      widget.allowApplyToSubscription && widget.initialApplyToSubscription;
  bool _hasUserInteracted = false;

  @override
  void initState() {
    super.initState();
    widget.correctedInitialSelection?.then(_applyCorrectedSelection).catchError(
      (Object error, StackTrace stackTrace) {
        logger.AppLogger.warning(
          '[PlaybackSpeedSheet] Failed to apply corrected initial selection: $error',
        );
      },
    );
  }

  void _applyCorrectedSelection(PlaybackSpeedSheetInitialSelection selection) {
    if (!mounted || _hasUserInteracted) {
      return;
    }
    setState(() {
      _selectedSpeed = selection.speed;
      _applyToSubscription =
          widget.allowApplyToSubscription && selection.applyToSubscription;
    });
  }

  void _selectSpeed(double speed) {
    setState(() {
      _hasUserInteracted = true;
      _selectedSpeed = speed;
    });
  }

  void _toggleApplyToSubscription(bool? checked) {
    setState(() {
      _hasUserInteracted = true;
      _applyToSubscription =
          widget.allowApplyToSubscription && (checked ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

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
                    selected: (_selectedSpeed - speed).abs() < 0.0001,
                    onSelected: (_) => _selectSpeed(speed),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _applyToSubscription,
                onChanged: widget.allowApplyToSubscription
                    ? _toggleApplyToSubscription
                    : null,
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
                        speed: _selectedSpeed,
                        applyToSubscription: _applyToSubscription,
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
  }
}
