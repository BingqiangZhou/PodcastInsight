import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:personal_ai_assistant/core/platform/platform_helper.dart';

/// Adaptive switch widget.
///
/// iOS: [CupertinoSwitch] for native iOS toggle appearance.
/// Android: Material [Switch] with `adaptive: true` for Material 3 styling.
class AdaptiveSwitch extends StatelessWidget {
  const AdaptiveSwitch({
    required this.value,
    super.key,
    this.onChanged,
    this.activeColor,
    this.focusNode,
    this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? activeColor;
  final FocusNode? focusNode;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    if (PlatformHelper.isApple(context)) {
      final cupertinoSwitch = CupertinoSwitch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: activeColor ?? Theme.of(context).colorScheme.primary,
        focusNode: focusNode,
      );
      if (semanticLabel != null) {
        return Semantics(
          label: semanticLabel,
          toggled: value,
          child: cupertinoSwitch,
        );
      }
      return cupertinoSwitch;
    }

    final materialSwitch = Switch(
      value: value,
      onChanged: onChanged,
      activeTrackColor: activeColor ?? Theme.of(context).colorScheme.primary,
      focusNode: focusNode,
    );
    if (semanticLabel != null) {
      return Semantics(
        label: semanticLabel,
        toggled: value,
        child: materialSwitch,
      );
    }
    return materialSwitch;
  }
}
