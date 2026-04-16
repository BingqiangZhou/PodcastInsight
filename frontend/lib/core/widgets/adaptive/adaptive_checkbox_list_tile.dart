import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:personal_ai_assistant/core/platform/platform_helper.dart';

/// Adaptive checkbox list tile.
///
/// iOS: [CupertinoListTile] with a trailing [CupertinoCheckbox].
/// Android: Material [CheckboxListTile].
class AdaptiveCheckboxListTile extends StatelessWidget {
  const AdaptiveCheckboxListTile({
    required this.title,
    super.key,
    this.subtitle,
    this.value,
    this.onChanged,
    this.contentPadding,
  });

  final Widget title;
  final Widget? subtitle;
  final bool? value;
  final ValueChanged<bool?>? onChanged;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    if (PlatformHelper.isIOS(context)) {
      final cupertinoTile = CupertinoListTile(
        title: DefaultTextStyle(
          style: CupertinoTheme.of(context).textTheme.textStyle,
          child: title,
        ),
        subtitle: subtitle,
        trailing: CupertinoCheckbox(
          value: value ?? false,
          onChanged: onChanged,
          activeColor: CupertinoColors.systemGreen.resolveFrom(context),
        ),
        onTap: () => onChanged?.call(!(value ?? false)),
      );

      if (contentPadding != null) {
        return Padding(
          padding: contentPadding!,
          child: cupertinoTile,
        );
      }
      return cupertinoTile;
    }

    return CheckboxListTile(
      title: title,
      subtitle: subtitle,
      value: value,
      onChanged: onChanged,
      contentPadding: contentPadding,
      controlAffinity: ListTileControlAffinity.trailing,
    );
  }
}
