import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:personal_ai_assistant/core/constants/app_radius.dart';
import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:personal_ai_assistant/core/platform/platform_helper.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';

/// Button style variants for [AdaptiveButton].
enum AdaptiveButtonStyle {
  filled,
  text,
  outlined,
}

/// Adaptive button.
///
/// iOS: [CupertinoButton] with appropriate styling.
/// Android: Material [ElevatedButton], [TextButton], or [OutlinedButton].
class AdaptiveButton extends StatelessWidget {
  const AdaptiveButton({
    required this.onPressed,
    required this.child,
    super.key,
    this.style = AdaptiveButtonStyle.filled,
    this.padding,
    this.isLoading = false,
    this.icon,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final AdaptiveButtonStyle style;
  final EdgeInsetsGeometry? padding;
  final bool isLoading;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    if (PlatformHelper.isApple(context)) {
      return _buildCupertino(context);
    }
    return _buildMaterial(context);
  }

  Widget _buildCupertino(BuildContext context) {
    final theme = Theme.of(context);
    Widget effectiveChild = child;

    if (isLoading) {
      effectiveChild = CupertinoActivityIndicator(
        color: style == AdaptiveButtonStyle.filled
            ? CupertinoColors.white
            : theme.colorScheme.primary,
      );
    } else if (icon != null) {
      effectiveChild = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon!,
          SizedBox(width: context.spacing.sm),
          Flexible(child: child),
        ],
      );
    }

    switch (style) {
      case AdaptiveButtonStyle.filled:
        return CupertinoButton(
          onPressed: isLoading ? null : onPressed,
          color: theme.colorScheme.primary,
          padding: padding ??
              EdgeInsets.symmetric(horizontal: context.spacing.md, vertical: context.spacing.smMd),
          child: DefaultTextStyle(
            style: const TextStyle(color: CupertinoColors.white),
            child: effectiveChild,
          ),
        );
      case AdaptiveButtonStyle.text:
        return CupertinoButton(
          onPressed: isLoading ? null : onPressed,
          padding: padding ??
              EdgeInsets.symmetric(horizontal: context.spacing.smMd, vertical: context.spacing.xs),
          child: effectiveChild,
        );
      case AdaptiveButtonStyle.outlined:
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.primary),
            borderRadius: BorderRadius.circular(appThemeOf(context).buttonRadius),
          ),
          child: CupertinoButton(
            onPressed: isLoading ? null : onPressed,
            padding: padding ??
                EdgeInsets.symmetric(horizontal: context.spacing.md, vertical: context.spacing.smMd),
            child: effectiveChild,
          ),
        );
    }
  }

  Widget _buildMaterial(BuildContext context) {
    Widget effectiveChild = child;

    if (isLoading) {
      effectiveChild = SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator.adaptive(
          strokeWidth: 2,
        ),
      );
    } else if (icon != null) {
      effectiveChild = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon!,
          SizedBox(width: context.spacing.sm),
          Flexible(child: child),
        ],
      );
    }

    switch (style) {
      case AdaptiveButtonStyle.filled:
        return ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            padding: padding,
          ),
          child: effectiveChild,
        );
      case AdaptiveButtonStyle.text:
        return TextButton(
          onPressed: isLoading ? null : onPressed,
          style: TextButton.styleFrom(
            padding: padding,
          ),
          child: effectiveChild,
        );
      case AdaptiveButtonStyle.outlined:
        return OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            padding: padding,
          ),
          child: effectiveChild,
        );
    }
  }
}
