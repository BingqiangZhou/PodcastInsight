import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/constants/app_radius.dart';
import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:personal_ai_assistant/core/constants/breakpoints.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/platform/adaptive_haptic.dart';
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
  late final PageController _pageController;

  static const String _sidebarExpandedKey = 'sidebar_expanded';

  @override
  void initState() {
    super.initState();
    // Initialize sidebar state from SharedPreferences
    _sidebarExpanded = ValueNotifier<bool>(widget.desktopNavExpanded);
    _pageController = PageController(initialPage: widget.selectedIndex);
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

  void _handlePageChanged(int index) {
    if (index != widget.selectedIndex) {
      widget.onDestinationSelected?.call(index);
      // Trigger haptic feedback on iOS
      AdaptiveHaptic.lightImpact();
    }
  }

  @override
  void didUpdateWidget(covariant CustomAdaptiveNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync with external state changes if needed
    if (oldWidget.desktopNavExpanded != widget.desktopNavExpanded) {
      _sidebarExpanded.value = widget.desktopNavExpanded;
    }
    // Sync PageController when selectedIndex changes externally (e.g., by GoRouter)
    if (oldWidget.selectedIndex != widget.selectedIndex &&
        _pageController.hasClients &&
        widget.destinations.length > 1) {
      _pageController.jumpToPage(widget.selectedIndex);
    }
  }

  @override
  void dispose() {
    _sidebarExpanded.dispose();
    _pageController.dispose();
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

    // Apple platforms: Use PageView for tab swipe gesture
    final shouldUsePageView = PlatformHelper.isApple(context) &&
        widget.destinations.length > 1;

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
                  child: shouldUsePageView
                      ? PageView(
                          controller: _pageController,
                          onPageChanged: _handlePageChanged,
                          physics: const BouncingScrollPhysics(),
                          children: _buildPageViewChildren(),
                        )
                      : (widget.body ?? const SizedBox.shrink()),
                ),
              ),
              if (widget.floatingActionButton != null)
                Positioned(
                  right: context.spacing.mdLg,
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

  /// Build PageView children for iOS tab swipe gesture.
  /// Only the selected page renders the actual body to avoid
  /// duplicate GlobalKey errors from StatefulNavigationShell.
  List<Widget> _buildPageViewChildren() {
    return List<Widget>.generate(
      widget.destinations.length,
      (index) => index == widget.selectedIndex
          ? (widget.body ?? const SizedBox.shrink())
          : const SizedBox.expand(),
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
              padding: EdgeInsets.fromLTRB(context.spacing.xs, context.spacing.md, context.spacing.xs, context.spacing.md),
              child: _CleanSidebar(
                expanded: false,
                child: Column(
                  children: [
                    SizedBox(height: context.spacing.md),
                    _buildBrandLogoBadge(context),
                    SizedBox(height: context.spacing.md),
                    ..._buildNavigationItems(context, compact: true),
                    const Spacer(),
                    if (widget.destinations.isNotEmpty)
                      _buildProfileNavigationItem(context, compact: true),
                    SizedBox(height: context.spacing.smMd),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: context.spacing.smMd),
          Expanded(
            child: _buildContentStack(
              bottomPadding:
                  widget.globalOverlayBodyPadding +
                  (widget.bottomAccessory != null ? widget.bottomAccessoryBodyPadding : 0),
              fabBottom:
                  widget.globalOverlayBodyPadding +
                  (widget.bottomAccessory != null ? widget.bottomAccessoryBodyPadding : 0) +
                  context.spacing.xl,
            ),
          ),
          SizedBox(width: context.spacing.smMd),
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
          if (PlatformHelper.isApple(context))
            _buildAppleSidebar(context)
          else
            Expanded(
              child: ValueListenableBuilder<bool>(
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
                            padding: EdgeInsets.fromLTRB(showCompact ? context.spacing.xs : context.spacing.smMd, context.spacing.md, showCompact ? context.spacing.xs : context.spacing.smMd, context.spacing.md),
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
            ),
          if (!PlatformHelper.isApple(context))
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(0, context.spacing.md, context.spacing.md, context.spacing.md),
                child: _buildContentStack(
                  bottomPadding:
                      widget.globalOverlayBodyPadding +
                      (widget.bottomAccessory != null ? widget.bottomAccessoryBodyPadding : 0),
                  fabBottom:
                      widget.globalOverlayBodyPadding +
                      (widget.bottomAccessory != null ? widget.bottomAccessoryBodyPadding : 0) +
                      context.spacing.xl,
                ),
              ),
            ),
          if (PlatformHelper.isApple(context))
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(0, context.spacing.md, context.spacing.md, context.spacing.md),
                child: _buildContentStack(
                  bottomPadding:
                      widget.globalOverlayBodyPadding +
                      (widget.bottomAccessory != null ? widget.bottomAccessoryBodyPadding : 0),
                  fabBottom:
                      widget.globalOverlayBodyPadding +
                      (widget.bottomAccessory != null ? widget.bottomAccessoryBodyPadding : 0) +
                      context.spacing.xl,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAppleSidebar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: isDark
            ? CupertinoColors.systemBackground.darkColor.withOpacity(0.85)
            : CupertinoColors.systemBackground.color.withOpacity(0.85),
        border: Border(
          right: BorderSide(
            color: isDark
                ? CupertinoColors.separator.darkColor
                : CupertinoColors.separator.color,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          // Main navigation items
          ...List.generate(
            widget.destinations.length > 1 ? widget.destinations.length - 1 : widget.destinations.length,
            (index) => _buildAppleSidebarItem(context, index),
          ),
          const Spacer(),
          // Profile item at bottom (if exists)
          if (widget.destinations.length > 1)
            _buildAppleSidebarItem(context, widget.destinations.length - 1),
        ],
      ),
    );
  }

  Widget _buildAppleSidebarItem(BuildContext context, int index) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isSelected = index == widget.selectedIndex;
    final destination = widget.destinations[index];

    return GestureDetector(
      onTap: () => widget.onDestinationSelected?.call(index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: isSelected
              ? (isDark
                  ? CupertinoColors.systemBackground.darkColor.withOpacity(0.1)
                  : CupertinoColors.systemBackground.color.withOpacity(0.06))
              : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: FittedBox(
                child: isSelected
                    ? (destination.selectedIcon ?? destination.icon)
                    : destination.icon,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              destination.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                color: isSelected
                    ? theme.colorScheme.primary
                    : (isDark ? CupertinoColors.systemGrey.darkColor : CupertinoColors.systemGrey),
              ),
            ),
          ],
        ),
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
            right: context.spacing.mdLg,
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
          padding: EdgeInsets.fromLTRB(context.spacing.smMd, context.spacing.smMd, context.spacing.smMd, context.spacing.sm),
          child: Row(
            children: [
              _buildBrandLogoBadge(context),
              SizedBox(width: context.spacing.smMd),
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
        SizedBox(height: context.spacing.sm),
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
        SizedBox(height: context.spacing.smMd),
        _buildBrandLogoBadge(context),
        IconButton(
          onPressed: _toggleSidebar,
          tooltip: l10n.sidebarExpandMenu,
          icon: const Icon(Icons.chevron_right),
        ),
        SizedBox(height: context.spacing.sm),
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
          padding: EdgeInsets.symmetric(horizontal: context.spacing.xs, vertical: context.spacing.xs),
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
        padding: EdgeInsets.symmetric(horizontal: context.spacing.smMd, vertical: context.spacing.xs),
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
              padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
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
                  SizedBox(width: context.spacing.smMd),
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
    if (PlatformHelper.isApple(context)) {
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
              onTap: () {
                // Update PageController for iOS swipe gesture
                if (_pageController.hasClients) {
                  _pageController.jumpToPage(index);
                }
                widget.onDestinationSelected?.call(index);
              },
              onDoubleTap: isSelected
                  ? () {
                      AdaptiveHaptic.lightImpact();
                      // Scroll to top via PrimaryScrollController
                      PrimaryScrollController.of(context).animateTo(
                        0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  : null,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: context.spacing.xs),
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
                    SizedBox(height: context.spacing.xxs),
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
            padding: EdgeInsets.symmetric(vertical: context.spacing.xs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  scale: isSelected ? 1.05 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.spacing.md,
                      vertical: context.spacing.xxs,
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
                SizedBox(height: context.spacing.xxs),
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
    this.avoidTopSafeArea = false,
  });

  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry? alignment;

  /// When true on iOS, skip adding the safe area top inset to padding.
  /// Use with AdaptiveSliverAppBar (CupertinoSliverNavigationBar) which
  /// already handles the safe area internally.
  final bool avoidTopSafeArea;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final tokens = Theme.of(context).extension<AppThemeExtension>() ??
        (Theme.of(context).brightness == Brightness.dark
            ? AppThemeExtension.dark
            : AppThemeExtension.light);

    final topPadding = (avoidTopSafeArea && PlatformHelper.isApple(context))
        ? 0.0
        : MediaQuery.viewPaddingOf(context).top;
    final resolvedPadding = padding ??
        EdgeInsets.fromLTRB(
          width < Breakpoints.medium ? context.spacing.md : context.spacing.lg,
          (width < Breakpoints.medium ? context.spacing.smMd : context.spacing.mdLg) + topPadding,
          width < Breakpoints.medium ? context.spacing.md : context.spacing.lg,
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
