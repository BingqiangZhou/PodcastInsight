import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:personal_ai_assistant/core/platform/platform_helper.dart';

/// Adaptive sliver app bar with large title collapsing.
///
/// iOS: [CupertinoSliverNavigationBar] with large title.
/// Android: Material [SliverAppBar] with theme-consistent styling.
class AdaptiveSliverAppBar extends StatelessWidget {
  const AdaptiveSliverAppBar({
    required this.title,
    super.key,
    this.actions,
    this.leading,
    this.largeTitle = true,
    this.bottom,
    this.backgroundColor,
    this.automaticallyImplyLeading = true,
    this.heroTag,
  });

  /// Page title displayed in the navigation bar.
  final String title;

  /// Action buttons displayed on the trailing side.
  /// iOS: wrapped in Row for CupertinoSliverNavigationBar.trailing.
  /// Android: passed directly to SliverAppBar.actions.
  final List<Widget>? actions;

  /// Optional leading widget (overrides automatic back button).
  final Widget? leading;

  /// Whether to show a large title on iOS. Defaults to true.
  final bool largeTitle;

  /// Optional widget to display below the navigation bar.
  final PreferredSizeWidget? bottom;

  /// Background color. Defaults to semi-transparent on both platforms.
  final Color? backgroundColor;

  /// Whether to automatically imply a leading back button. Defaults to true.
  final bool automaticallyImplyLeading;

  /// Hero tag for Cupertino transition animation.
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    if (PlatformHelper.isIOS(context)) {
      return CupertinoSliverNavigationBar(
        largeTitle: largeTitle ? Text(title) : null,
        middle: largeTitle ? null : Text(title),
        trailing: actions != null && actions!.isNotEmpty
            ? Row(mainAxisSize: MainAxisSize.min, children: actions!)
            : null,
        leading: leading,
        backgroundColor: backgroundColor ??
            CupertinoColors.systemBackground.withValues(alpha: 0.85),
        bottom: bottom,
        automaticallyImplyLeading: automaticallyImplyLeading,
        heroTag: heroTag ?? const _DefaultHeroTag(),
      );
    }

    return SliverAppBar(
      title: Text(title),
      actions: actions,
      leading: leading,
      floating: true,
      snap: true,
      bottom: bottom,
      backgroundColor: backgroundColor,
      automaticallyImplyLeading: automaticallyImplyLeading,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    );
  }
}

class _DefaultHeroTag {
  const _DefaultHeroTag();
}
