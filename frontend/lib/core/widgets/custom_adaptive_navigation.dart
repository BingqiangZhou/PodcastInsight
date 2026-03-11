import 'dart:ui';

import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../theme/app_colors.dart';

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
        if (width < 600) {
          return _buildMobileLayout(context, width);
        }
        if (width < 840) {
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
        : 12.0;
    // NavigationBar custom height is 60. We add an extra 4 pixels gap between the player and the navigation bar dock.
    final double dockReserve = dockBottomPadding + 60.0 + 4.0;
    final accessoryBodyPadding = bottomAccessory != null
        ? bottomAccessoryBodyPadding
        : 0.0;
    final bottomBackdropHeight =
        dockReserve + accessoryBodyPadding + globalOverlayBodyPadding + 36;
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      appBar: appBar,
      body: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomBackdrop(
              key: const Key('custom_adaptive_navigation_bottom_backdrop'),
              height: bottomBackdropHeight,
            ),
          ),
          Stack(
            children: [
              RepaintBoundary(
                child: AnimatedPadding(
                  duration: _kBottomAccessoryPaddingTransition,
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.only(
                    bottom:
                        accessoryBodyPadding +
                        globalOverlayBodyPadding +
                        dockReserve,
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
              minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Align(
                child: _GlassDock(
                  key: const Key('custom_adaptive_navigation_mobile_dock'),
                  width: width < 420 ? width - 24 : 396,
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
            width: 86,
            child: _GlassSidebar(
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
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: expanded ? 280 : 80),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            builder: (context, animatedWidth, child) {
              final showCompact = animatedWidth < 196;
              return SizedBox(
                key: const ValueKey('desktop_navigation_sidebar'),
                width: animatedWidth,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: _GlassSidebar(
                    compact: showCompact,
                    child: showCompact
                        ? _buildDesktopCollapsedSidebar(context)
                        : _buildDesktopExpandedSidebar(context),
                  ),
                ),
              );
            },
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
    final l10n = AppLocalizations.of(context)!;
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
    final l10n = AppLocalizations.of(context)!;
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
        borderRadius: BorderRadius.circular(10),
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
    return Tooltip(
      message: destination.label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: isSelected
                  ? scheme.primary.withValues(alpha: 0.14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: isSelected
                  ? (destination.selectedIcon ?? destination.icon)
                  : destination.icon,
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? scheme.primary.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
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
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (isSelected)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileNavBar(BuildContext context) {
    return SizedBox(
      key: const Key('custom_adaptive_navigation_mobile_nav_bar'),
      height: 60,
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
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? scheme.primary.withValues(alpha: 0.14)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: isSelected
                    ? (destination.selectedIcon ?? destination.icon)
                    : destination.icon,
              ),
              const SizedBox(height: 2),
              Text(
                destination.label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  height: 1,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? scheme.onSurface
                      : scheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
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
    final width = MediaQuery.of(context).size.width;
    final tokens =
        Theme.of(context).extension<MindriverThemeExtension>() ??
        (Theme.of(context).brightness == Brightness.dark
            ? MindriverThemeExtension.dark
            : MindriverThemeExtension.light);

    final topPadding = MediaQuery.viewPaddingOf(context).top;
    final resolvedPadding =
        padding ??
        EdgeInsets.fromLTRB(
          width < 600 ? 16 : 24,
          (width < 600 ? 12 : 20) + topPadding,
          width < 600 ? 16 : 24,
          0,
        );
    final resolvedMaxWidth =
        maxWidth ??
        (width < 600
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

class _GlassSidebar extends StatelessWidget {
  const _GlassSidebar({required this.child, required this.compact});

  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens =
        theme.extension<MindriverThemeExtension>() ??
        (theme.brightness == Brightness.dark
            ? MindriverThemeExtension.dark
            : MindriverThemeExtension.light);

    return ClipRRect(
      borderRadius: BorderRadius.circular(compact ? 28 : 32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.glassSurfaceStrong.withValues(
              alpha: tokens.navBackdropOpacity,
            ),
            borderRadius: BorderRadius.circular(compact ? 28 : 32),
            border: Border.all(color: tokens.glassBorder),
            boxShadow: [
              BoxShadow(
                color: tokens.glassShadow,
                blurRadius: 30,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlassDock extends StatelessWidget {
  const _GlassDock({super.key, required this.child, required this.width});

  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens =
        theme.extension<MindriverThemeExtension>() ??
        (theme.brightness == Brightness.dark
            ? MindriverThemeExtension.dark
            : MindriverThemeExtension.light);

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: width,
          decoration: BoxDecoration(
            color: tokens.glassSurfaceStrong.withValues(
              alpha: tokens.navBackdropOpacity,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: tokens.glassBorder),
            boxShadow: [
              BoxShadow(
                color: tokens.glassShadow,
                blurRadius: 32,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _BottomBackdrop extends StatelessWidget {
  const _BottomBackdrop({super.key, required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens =
        theme.extension<MindriverThemeExtension>() ??
        (theme.brightness == Brightness.dark
            ? MindriverThemeExtension.dark
            : MindriverThemeExtension.light);
    final baseColor = Color.alphaBlend(
      theme.colorScheme.surface.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.16 : 0.24,
      ),
      theme.scaffoldBackgroundColor,
    );

    return IgnorePointer(
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: baseColor,
                gradient: tokens.shellGradient,
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    baseColor.withValues(alpha: 0),
                    baseColor.withValues(alpha: 0.58),
                    baseColor,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
