import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/constants/app_radius.dart';
import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:personal_ai_assistant/core/constants/breakpoints.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/platform/platform_helper.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/core/theme/app_theme.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/constants/podcast_ui_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Duration _kBottomAccessoryPaddingTransition = Duration(milliseconds: 220);

class CustomAdaptiveNavigation extends ConsumerStatefulWidget {
  const CustomAdaptiveNavigation({
    required this.destinations, required this.selectedIndex, required this.onDestinationSelected, super.key,
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
  ConsumerState<CustomAdaptiveNavigation> createState() => _CustomAdaptiveNavigationState();
}

class _CustomAdaptiveNavigationState extends ConsumerState<CustomAdaptiveNavigation> {
  late final ValueNotifier<bool> _sidebarExpanded;

  static const String _sidebarExpandedKey = 'sidebar_expanded';

  @override
  void initState() {
    super.initState();
    // Initialize sidebar state from SharedPreferences
    _sidebarExpanded = ValueNotifier<bool>(widget.desktopNavExpanded);
    // ignore: discarded_futures
    _loadSidebarState();
  }

  Future<void> _loadSidebarState() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool(_sidebarExpandedKey);
    if (saved != null) {
      _sidebarExpanded.value = saved;
    }
  }

  Future<void> _toggleSidebar() async {
    _sidebarExpanded.value = !_sidebarExpanded.value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sidebarExpandedKey, _sidebarExpanded.value);
  }

  @override
  void didUpdateWidget(covariant CustomAdaptiveNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync with external state changes if needed
    if (oldWidget.desktopNavExpanded != widget.desktopNavExpanded) {
      _sidebarExpanded.value = widget.desktopNavExpanded;
    }
  }

  @override
  void dispose() {
    _sidebarExpanded.dispose();
    super.dispose();
  }

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
        return _buildDesktopLayout(context);
      },
    );
  }

  Widget _buildMobileLayout(BuildContext context, double width) {
    final safeAreaBottom = MediaQuery.viewPaddingOf(context).bottom;
    final dockBottomPadding = safeAreaBottom > 0.0
        ? safeAreaBottom
        : kPodcastGlobalPlayerMobileViewportPadding;
    final dockReserve =
        dockBottomPadding +
        kPodcastGlobalPlayerMobileDockHeight +
        kPodcastGlobalPlayerMobileDockGap;
    final accessoryBodyPadding = widget.bottomAccessory != null
        ? widget.bottomAccessoryBodyPadding
        : 0.0;
    final totalBottomReserve = dockReserve + accessoryBodyPadding + widget.globalOverlayBodyPadding;
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      appBar: widget.appBar,
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
                  child: widget.body ?? const SizedBox.shrink(),
                ),
              ),
              if (widget.floatingActionButton != null)
                Positioned(
                  right: AppSpacing.mdLg,
                  bottom: accessoryBodyPadding + widget.globalOverlayBodyPadding + 108,
                  child: widget.floatingActionButton!,
                ),
              if (widget.bottomAccessory != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: dockReserve,
                  child: widget.bottomAccessory!,
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
      appBar: widget.appBar,
      body: Row(
        children: [
          SizedBox(
            width: 72,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xs, AppSpacing.md, AppSpacing.xs, AppSpacing.md),
              child: _CleanSidebar(
                expanded: false,
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.md),
                    _buildBrandLogoBadge(context),
                    const SizedBox(height: AppSpacing.md),
                    ..._buildNavigationItems(context, compact: true),
                    const Spacer(),
                    if (widget.destinations.isNotEmpty)
                      _buildProfileNavigationItem(context, compact: true),
                    const SizedBox(height: AppSpacing.smMd),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.smMd),
          Expanded(
            child: _buildContentStack(
              bottomPadding:
                  widget.globalOverlayBodyPadding +
                  (widget.bottomAccessory != null ? widget.bottomAccessoryBodyPadding : 0),
              fabBottom:
                  widget.globalOverlayBodyPadding +
                  (widget.bottomAccessory != null ? widget.bottomAccessoryBodyPadding : 0) +
                  AppSpacing.xl,
            ),
          ),
          const SizedBox(width: AppSpacing.smMd),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: widget.appBar,
      body: Row(
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: _sidebarExpanded,
            builder: (context, expanded, child) {
              return RepaintBoundary(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: expanded ? 240 : 72),
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  builder: (context, animatedWidth, child) {
                    final showCompact = animatedWidth < 120;
                    return SizedBox(
                      key: const ValueKey('desktop_navigation_sidebar'),
                      width: animatedWidth,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(showCompact ? AppSpacing.xs : AppSpacing.smMd, AppSpacing.md, showCompact ? AppSpacing.xs : AppSpacing.smMd, AppSpacing.md),
                        child: _CleanSidebar(
                          expanded: expanded,
                          child: showCompact
                              ? _buildDesktopCollapsedSidebar(context)
                              : _buildDesktopExpandedSidebar(context),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, AppSpacing.md, AppSpacing.md, AppSpacing.md),
              child: _buildContentStack(
                bottomPadding:
                    widget.globalOverlayBodyPadding +
                    (widget.bottomAccessory != null ? widget.bottomAccessoryBodyPadding : 0),
                fabBottom:
                    widget.globalOverlayBodyPadding +
                    (widget.bottomAccessory != null ? widget.bottomAccessoryBodyPadding : 0) +
                    AppSpacing.xl,
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
            child: widget.body ?? const SizedBox.shrink(),
          ),
        ),
        if (widget.floatingActionButton != null)
          Positioned(
            right: AppSpacing.mdLg,
            bottom: fabBottom,
            child: widget.floatingActionButton!,
          ),
        if (widget.bottomAccessory != null)
          Positioned(left: 0, right: 0, bottom: 0, child: widget.bottomAccessory!),
      ],
    );
  }

  Widget _buildDesktopExpandedSidebar(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.smMd, AppSpacing.smMd, AppSpacing.smMd, AppSpacing.sm),
          child: Row(
            children: [
              _buildBrandLogoBadge(context),
              const SizedBox(width: AppSpacing.smMd),
              Expanded(
                child: Text(
                  l10n.sidebarAppTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                onPressed: _toggleSidebar,
                tooltip: l10n.sidebarCollapseMenu,
                icon: const Icon(Icons.chevron_left),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ..._buildNavigationItems(context, compact: false),
        const Spacer(),
        if (widget.destinations.isNotEmpty)
          _buildProfileNavigationItem(context, compact: false),
      ],
    );
  }

  Widget _buildDesktopCollapsedSidebar(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        const SizedBox(height: AppSpacing.smMd),
        _buildBrandLogoBadge(context),
        IconButton(
          onPressed: _toggleSidebar,
          tooltip: l10n.sidebarExpandMenu,
          icon: const Icon(Icons.chevron_right),
        ),
        const SizedBox(height: AppSpacing.sm),
        ..._buildNavigationItems(context, compact: true),
        const Spacer(),
        if (widget.destinations.isNotEmpty)
          _buildProfileNavigationItem(context, compact: true),
      ],
    );
  }

  Widget _buildBrandLogoBadge(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: ClipRRect(
        borderRadius: AppRadius.smRadius,
        child: Image.asset('assets/icons/Logo3.png', fit: BoxFit.contain),
      ),
    );
  }

  List<Widget> _buildNavigationItems(
    BuildContext context, {
    required bool compact,
  }) {
    if (widget.destinations.length <= 1) {
      return const <Widget>[];
    }

    final items = <Widget>[];
    for (var index = 0; index < widget.destinations.length - 1; index++) {
      final destination = widget.destinations[index];
      final isSelected = index == widget.selectedIndex;
      items.add(
        _buildNavItem(
          context,
          destination,
          isSelected,
          compact,
          () => widget.onDestinationSelected?.call(index),
        ),
      );
    }
    return items;
  }

  Widget _buildProfileNavigationItem(
    BuildContext context, {
    required bool compact,
  }) {
    final profileIndex = widget.destinations.length - 1;
    final destination = widget.destinations[profileIndex];
    final isSelected = profileIndex == widget.selectedIndex;
    return _buildNavItem(
      context,
      destination,
      isSelected,
      compact,
      () => widget.onDestinationSelected?.call(profileIndex),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    NavigationDestination destination,
    bool isSelected,
    bool compact,
    VoidCallback onTap,
  ) {
    if (compact) {
      return _buildCompactNavItem(
        context,
        destination,
        isSelected,
        onTap,
      );
    }
    return _buildExpandedNavItem(
      context,
      destination,
      isSelected,
      onTap,
    );
  }

  Widget _buildCompactNavItem(
    BuildContext context,
    NavigationDestination destination,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final extension = appThemeOf(context);
    return Semantics(
      button: true,
      selected: isSelected,
      label: destination.label,
      child: Tooltip(
        message: destination.label,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
          child: _NavInkWell(
            onTap: onTap,
            borderRadius: extension.navItemRadius,
            isSelected: isSelected,
            child: AnimatedScale(
              scale: isSelected ? 1.05 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: Container(
                width: 44,
                height: 44,
                decoration: _buildNavDecoration(isSelected: isSelected, context: context),
                child: Center(
                  child: IconTheme(
                    data: const IconThemeData(size: 20),
                    child: isSelected
                        ? (destination.selectedIcon ?? destination.icon)
                        : destination.icon,
                  ),
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
    final extension = appThemeOf(context);

    return Semantics(
      button: true,
      selected: isSelected,
      label: destination.label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.smMd, vertical: AppSpacing.xs),
        child: _NavInkWell(
          onTap: onTap,
          borderRadius: extension.navItemRadius,
          isSelected: isSelected,
          child: AnimatedScale(
            scale: isSelected ? 1.02 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: _buildNavDecoration(isSelected: isSelected, context: context),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: isSelected
                        ? (destination.selectedIcon ?? destination.icon)
                        : destination.icon,
                  ),
                  const SizedBox(width: AppSpacing.smMd),
                  Expanded(
                    child: Text(
                      destination.label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: isSelected
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: isSelected ? FontWeight.w700 : null,
                      ),
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

  BoxDecoration _buildNavDecoration({
    required bool isSelected,
    required BuildContext context,
  }) {
    final extension = appThemeOf(context);
    if (isSelected) {
      // Gradient background for active state
      return BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.violetColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(extension.navItemRadius),
      );
    }
    return BoxDecoration(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(extension.navItemRadius),
    );
  }

  Widget _buildMobileNavBar(BuildContext context) {
    if (PlatformHelper.isIOS(context)) {
      return _buildIOSMobileNavBar(context);
    }
    return SizedBox(
      key: const Key('custom_adaptive_navigation_mobile_nav_bar'),
      height: kPodcastGlobalPlayerMobileDockHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(widget.destinations.length, (index) {
          final destination = widget.destinations[index];
          final isSelected = index == widget.selectedIndex;
          return Expanded(
            child: _buildMobileNavItem(
              context,
              destination,
              isSelected,
              () => widget.onDestinationSelected?.call(index),
            ),
          );
        }),
      ),
    );
  }

  /// iOS-style bottom navigation (CupertinoTabBar aesthetic).
  /// Uses system icon colors instead of gradient background.
  Widget _buildIOSMobileNavBar(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: kPodcastGlobalPlayerMobileDockHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(widget.destinations.length, (index) {
          final destination = widget.destinations[index];
          final isSelected = index == widget.selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => widget.onDestinationSelected?.call(index),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconTheme(
                      data: IconThemeData(
                        size: 22,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      child: isSelected
                          ? (destination.selectedIcon ?? destination.icon)
                          : destination.icon,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      destination.label,
                      style: AppTheme.navLabel(
                        isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                        weight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
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
    return Semantics(
      button: true,
      selected: isSelected,
      label: destination.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.mdLgRadius,
          splashColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
          highlightColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
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
                      horizontal: AppSpacing.md,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: AppColors.violetColors,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isSelected ? null : Colors.transparent,
                      borderRadius: AppRadius.mdLgRadius,
                    ),
                    child: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    isSelected ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
                    BlendMode.srcIn,
                  ),
                  child: isSelected
                      ? (destination.selectedIcon ?? destination.icon)
                      : destination.icon,
                ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  destination.label,
                  style: AppTheme.navLabel(
                    isSelected ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurfaceVariant,
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
    required this.child, super.key,
    this.alignment,
    this.maxWidth,
    this.padding,
  });

  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry? alignment;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final tokens = Theme.of(context).extension<AppThemeExtension>() ??
        (Theme.of(context).brightness == Brightness.dark
            ? AppThemeExtension.dark
            : AppThemeExtension.light);

    final topPadding = MediaQuery.viewPaddingOf(context).top;
    final resolvedPadding = padding ??
        EdgeInsets.fromLTRB(
          width < Breakpoints.medium ? AppSpacing.md : AppSpacing.lg,
          (width < Breakpoints.medium ? AppSpacing.smMd : AppSpacing.mdLg) + topPadding,
          width < Breakpoints.medium ? AppSpacing.md : AppSpacing.lg,
          0,
        );
    final resolvedMaxWidth = maxWidth ??
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

/// Arc+Linear style sidebar with theme-aware surface
class _CleanSidebar extends StatelessWidget {
  const _CleanSidebar({required this.child, required this.expanded});

  final Widget child;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurfaceVariant,
        borderRadius: expanded
            ? const BorderRadius.horizontal(right: Radius.circular(AppRadius.lg))
            : AppRadius.lgXlRadius,
      ),
      child: child,
    );
  }
}

/// Nav item ink well with hover effect
class _NavInkWell extends StatefulWidget {
  const _NavInkWell({
    required this.borderRadius,
    required this.child,
    required this.isSelected,
    required this.onTap,
  });

  final VoidCallback onTap;
  final double borderRadius;
  final bool isSelected;
  final Widget child;

  @override
  State<_NavInkWell> createState() => _NavInkWellState();
}

class _NavInkWellState extends State<_NavInkWell> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlayColor = isDark ? Colors.white : Colors.black;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        splashColor: overlayColor.withValues(alpha: 0.12),
        highlightColor: overlayColor.withValues(alpha: 0.08),
        hoverColor: Colors.transparent, // We handle hover manually
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: _isHovered && !widget.isSelected
                ? overlayColor.withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Arc+Linear style dock with theme-aware surface + blur
class _CleanDock extends StatelessWidget {
  const _CleanDock({required this.child, required this.width, super.key});

  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    return SizedBox(
      width: width,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: surfaceColor.withValues(alpha: 0.9),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
