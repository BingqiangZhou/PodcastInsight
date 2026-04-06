import 'package:flutter/material.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/constants/podcast_ui_constants.dart';

import 'package:personal_ai_assistant/core/constants/breakpoints.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/core/theme/app_theme.dart';
import 'package:personal_ai_assistant/core/glass/glass_container.dart';
import 'package:personal_ai_assistant/core/glass/glass_tokens.dart';

const Duration _kBottomAccessoryPaddingTransition = Duration(milliseconds: 220);

class CustomAdaptiveNavigation extends StatelessWidget {
  const CustomAdaptiveNavigation({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    this.onDestinationSelected,
    this.body,
    this.floatingActionButton,
    this.appBar,
    this.bottomAccessory,
    this.bottomAccessoryBodyPadding = 60,
    this.globalOverlayBodyPadding = 0,
    this.desktopNavExpanded = true,
    this.onDesktopNavToggle,
  });

  final List<NavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int>? onDestinationSelected;
  final Widget? body;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? appBar;
  final Widget? bottomAccessory;
  final double bottomAccessoryBodyPadding;
  final double globalOverlayBodyPadding;
  final bool desktopNavExpanded;
  final VoidCallback? onDesktopNavToggle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width < Breakpoints.medium) {
          return _buildMobileLayout(context, width);
        }
        if (width < Breakpoints.mediumLarge) {
          return _buildTabletLayout(context);
        }
        return _buildDesktopLayout(context, expanded: desktopNavExpanded);
      },
    );
  }

  Widget _buildMobileLayout(BuildContext context, double width) {
    final safeAreaBottom = MediaQuery.viewPaddingOf(context).bottom;
    final double dockBottomPadding = safeAreaBottom > 0.0
        ? safeAreaBottom
        : kPodcastGlobalPlayerMobileViewportPadding;
    final double dockReserve =
        dockBottomPadding +
        kPodcastGlobalPlayerMobileDockHeight +
        kPodcastGlobalPlayerMobileDockGap;
    final accessoryBodyPadding = bottomAccessory != null
        ? bottomAccessoryBodyPadding
        : 0.0;
    final totalBottomReserve = dockReserve + accessoryBodyPadding + globalOverlayBodyPadding;
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      appBar: appBar,
      body: Stack(
        children: [
          Stack(
            children: [
              RepaintBoundary(
                child: AnimatedPadding(
                  duration: _kBottomAccessoryPaddingTransition,
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.only(
                    bottom: totalBottomReserve,
                  ),
                  child: body ?? const SizedBox.shrink(),
                ),
              ),
              if (floatingActionButton != null)
                Positioned(
                  right: 20,
                  bottom: accessoryBodyPadding + globalOverlayBodyPadding + 108,
                  child: floatingActionButton!,
                ),
              if (bottomAccessory != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: dockReserve,
                  child: bottomAccessory!,
                ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(
                kPodcastGlobalPlayerMobileViewportPadding,
                0,
                kPodcastGlobalPlayerMobileViewportPadding,
                kPodcastGlobalPlayerMobileViewportPadding,
              ),
              child: Align(
                child: _CleanDock(
                  key: const Key('custom_adaptive_navigation_mobile_dock'),
                  width: width < 420
                      ? width - (kPodcastGlobalPlayerMobileViewportPadding * 2)
                      : 396,
                  child: _buildMobileNavBar(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: appBar,
      body: Row(
        children: [
          SizedBox(
            width: 72,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: _CleanSidebar(
                compact: true,
                child: Column(
                  children: [
                    const SizedBox(height: 18),
                    _buildBrandLogoBadge(context),
                    const SizedBox(height: 18),
                    ..._buildNavigationItems(context, compact: true),
                    const Spacer(),
                    if (destinations.isNotEmpty)
                      _buildProfileNavigationItem(context, compact: true),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildContentStack(
              bottomPadding:
                  globalOverlayBodyPadding +
                  (bottomAccessory != null ? bottomAccessoryBodyPadding : 0),
              fabBottom:
                  globalOverlayBodyPadding +
                  (bottomAccessory != null ? bottomAccessoryBodyPadding : 0) +
                  28,
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, {required bool expanded}) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: appBar,
      body: Row(
        children: [
          RepaintBoundary(
            child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: expanded ? 256 : 72),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            builder: (context, animatedWidth, child) {
              final showCompact = animatedWidth < 196;
              return SizedBox(
                key: const ValueKey('desktop_navigation_sidebar'),
                width: animatedWidth,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: _CleanSidebar(
                    compact: showCompact,
                    child: showCompact
                        ? _buildDesktopCollapsedSidebar(context)
                        : _buildDesktopExpandedSidebar(context),
                  ),
                ),
              );
            },
          ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
              child: _buildContentStack(
                bottomPadding:
                    globalOverlayBodyPadding +
                    (bottomAccessory != null ? bottomAccessoryBodyPadding : 0),
                fabBottom:
                    globalOverlayBodyPadding +
                    (bottomAccessory != null ? bottomAccessoryBodyPadding : 0) +
                    28,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentStack({
    required double bottomPadding,
    required double fabBottom,
  }) {
    return Stack(
      children: [
        RepaintBoundary(
          child: AnimatedPadding(
            duration: _kBottomAccessoryPaddingTransition,
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.only(bottom: bottomPadding),
            child: body ?? const SizedBox.shrink(),
          ),
        ),
        if (floatingActionButton != null)
          Positioned(
            right: 20,
            bottom: fabBottom,
            child: floatingActionButton!,
          ),
        if (bottomAccessory != null)
          Positioned(left: 0, right: 0, bottom: 0, child: bottomAccessory!),
      ],
    );
  }

  Widget _buildDesktopExpandedSidebar(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Row(
            children: [
              _buildBrandLogoBadge(context),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.sidebarAppTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                onPressed: onDesktopNavToggle,
                tooltip: l10n.sidebarCollapseMenu,
                icon: const Icon(Icons.chevron_left),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ..._buildNavigationItems(context, compact: false),
        const Spacer(),
        if (destinations.isNotEmpty)
          _buildProfileNavigationItem(context, compact: false),
      ],
    );
  }

  Widget _buildDesktopCollapsedSidebar(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        const SizedBox(height: 10),
        _buildBrandLogoBadge(context),
        IconButton(
          onPressed: onDesktopNavToggle,
          tooltip: l10n.sidebarExpandMenu,
          icon: const Icon(Icons.chevron_right),
        ),
        const SizedBox(height: 8),
        ..._buildNavigationItems(context, compact: true),
        const Spacer(),
        if (destinations.isNotEmpty)
          _buildProfileNavigationItem(context, compact: true),
      ],
    );
  }

  Widget _buildBrandLogoBadge(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset('assets/icons/Logo3.png', fit: BoxFit.contain),
      ),
    );
  }

  List<Widget> _buildNavigationItems(
    BuildContext context, {
    required bool compact,
  }) {
    if (destinations.length <= 1) {
      return const <Widget>[];
    }

    final items = <Widget>[];
    for (var index = 0; index < destinations.length - 1; index++) {
      final destination = destinations[index];
      final isSelected = index == selectedIndex;
      items.add(
        compact
            ? _buildCompactNavItem(
                context,
                destination,
                isSelected,
                () => onDestinationSelected?.call(index),
              )
            : _buildExpandedNavItem(
                context,
                destination,
                isSelected,
                () => onDestinationSelected?.call(index),
              ),
      );
    }
    return items;
  }

  Widget _buildProfileNavigationItem(
    BuildContext context, {
    required bool compact,
  }) {
    final profileIndex = destinations.length - 1;
    final destination = destinations[profileIndex];
    final isSelected = profileIndex == selectedIndex;
    return compact
        ? _buildCompactNavItem(
            context,
            destination,
            isSelected,
            () => onDestinationSelected?.call(profileIndex),
          )
        : _buildExpandedNavItem(
            context,
            destination,
            isSelected,
            () => onDestinationSelected?.call(profileIndex),
          );
  }

  Widget _buildCompactNavItem(
    BuildContext context,
    NavigationDestination destination,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final extension = appThemeOf(context);
    return Semantics(
      button: true,
      selected: isSelected,
      label: destination.label,
      child: Tooltip(
        message: destination.label,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(extension.navItemRadius),
            splashColor: scheme.primary.withValues(alpha: 0.12),
            highlightColor: scheme.primary.withValues(alpha: 0.08),
            hoverColor: scheme.primary.withValues(alpha: 0.05),
          child: AnimatedScale(
            scale: isSelected ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isSelected
                    ? scheme.primary.withValues(alpha: 0.14)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(extension.navItemRadius),
              ),
              child: Center(
                child: isSelected
                    ? (destination.selectedIcon ?? destination.icon)
                    : destination.icon,
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildExpandedNavItem(
    BuildContext context,
    NavigationDestination destination,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final extension = appThemeOf(context);

    return Semantics(
      button: true,
      selected: isSelected,
      label: destination.label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(extension.navItemRadius),
          splashColor: scheme.primary.withValues(alpha: 0.12),
          highlightColor: scheme.primary.withValues(alpha: 0.08),
          hoverColor: scheme.primary.withValues(alpha: 0.05),
          child: AnimatedScale(
            scale: isSelected ? 1.02 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected
                    ? scheme.primary.withValues(alpha: 0.14)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(extension.navItemRadius),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: isSelected
                        ? (destination.selectedIcon ?? destination.icon)
                        : destination.icon,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      destination.label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: isSelected
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant,
                        fontWeight: isSelected ? FontWeight.w700 : null,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.accentWarm,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileNavBar(BuildContext context) {
    return SizedBox(
      key: const Key('custom_adaptive_navigation_mobile_nav_bar'),
      height: kPodcastGlobalPlayerMobileDockHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(destinations.length, (index) {
          final destination = destinations[index];
          final isSelected = index == selectedIndex;
          return Expanded(
            child: _buildMobileNavItem(
              context,
              destination,
              isSelected,
              () => onDestinationSelected?.call(index),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMobileNavItem(
    BuildContext context,
    NavigationDestination destination,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: isSelected,
      label: destination.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: scheme.primary.withValues(alpha: 0.12),
          highlightColor: scheme.primary.withValues(alpha: 0.08),
          hoverColor: scheme.primary.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  scale: isSelected ? 1.05 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? scheme.primary.withValues(alpha: 0.14)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: isSelected
                        ? (destination.selectedIcon ?? destination.icon)
                        : destination.icon,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  destination.label,
                  style: AppTheme.navLabel(
                    isSelected ? scheme.onSurface : scheme.onSurfaceVariant,
                    weight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ResponsiveContainer extends StatelessWidget {
  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
    this.alignment,
  });

  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry? alignment;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final tokens =
        Theme.of(context).extension<AppThemeExtension>() ??
        (Theme.of(context).brightness == Brightness.dark
            ? AppThemeExtension.dark
            : AppThemeExtension.light);

    final topPadding = MediaQuery.viewPaddingOf(context).top;
    final resolvedPadding =
        padding ??
        EdgeInsets.fromLTRB(
          width < Breakpoints.medium ? 16 : 24,
          (width < Breakpoints.medium ? 12 : 20) + topPadding,
          width < Breakpoints.medium ? 16 : 24,
          0,
        );
    final resolvedMaxWidth =
        maxWidth ??
        (width < Breakpoints.medium
            ? width
            : width < 900
            ? 920
            : tokens.contentMaxWidth);

    return Align(
      alignment: alignment ?? Alignment.topCenter,
      child: Padding(
        padding: resolvedPadding,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: resolvedMaxWidth),
          child: child,
        ),
      ),
    );
  }
}

/// Glass sidebar with liquid glass effect
class _CleanSidebar extends StatelessWidget {
  const _CleanSidebar({required this.child, required this.compact});

  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      tier: GlassTier.overlay,
      borderRadius: compact ? 16 : 20,
      child: child,
    );
  }
}

/// Glass dock with liquid glass effect
class _CleanDock extends StatelessWidget {
  const _CleanDock({super.key, required this.child, required this.width});

  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: GlassContainer(
        tier: GlassTier.standard,
        borderRadius: 16,
        child: child,
      ),
    );
  }
}
