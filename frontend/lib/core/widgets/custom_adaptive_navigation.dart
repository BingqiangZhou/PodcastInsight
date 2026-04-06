import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:personal_ai_assistant/features/podcast/presentation/constants/podcast_ui_constants.dart';

import 'package:personal_ai_assistant/core/constants/breakpoints.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/core/theme/app_theme.dart';
import 'package:personal_ai_assistant/core/storage/local_storage_service.dart';

const Duration _kBottomAccessoryPaddingTransition = Duration(milliseconds: 220);

class CustomAdaptiveNavigation extends ConsumerStatefulWidget {
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
    final double dockBottomPadding = safeAreaBottom > 0.0
        ? safeAreaBottom
        : kPodcastGlobalPlayerMobileViewportPadding;
    final double dockReserve =
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
                  right: 20,
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
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: _CleanSidebar(
                expanded: false,
                child: Column(
                  children: [
                    const SizedBox(height: 18),
                    _buildBrandLogoBadge(context),
                    const SizedBox(height: 18),
                    ..._buildNavigationItems(context, compact: true),
                    const Spacer(),
                    if (widget.destinations.isNotEmpty)
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
                  widget.globalOverlayBodyPadding +
                  (widget.bottomAccessory != null ? widget.bottomAccessoryBodyPadding : 0),
              fabBottom:
                  widget.globalOverlayBodyPadding +
                  (widget.bottomAccessory != null ? widget.bottomAccessoryBodyPadding : 0) +
                  28,
            ),
          ),
          const SizedBox(width: 12),
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
                  tween: Tween<double>(end: expanded ? 240 : 60),
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  builder: (context, animatedWidth, child) {
                    final showCompact = animatedWidth < 120;
                    return SizedBox(
                      key: const ValueKey('desktop_navigation_sidebar'),
                      width: animatedWidth,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
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
              padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
              child: _buildContentStack(
                bottomPadding:
                    widget.globalOverlayBodyPadding +
                    (widget.bottomAccessory != null ? widget.bottomAccessoryBodyPadding : 0),
                fabBottom:
                    widget.globalOverlayBodyPadding +
                    (widget.bottomAccessory != null ? widget.bottomAccessoryBodyPadding : 0) +
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
            child: widget.body ?? const SizedBox.shrink(),
          ),
        ),
        if (widget.floatingActionButton != null)
          Positioned(
            right: 20,
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
                onPressed: _toggleSidebar,
                tooltip: l10n.sidebarCollapseMenu,
                icon: const Icon(Icons.chevron_left),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ..._buildNavigationItems(context, compact: false),
        const Spacer(),
        _buildPinnedPodcastsSection(context),
        const SizedBox(height: 16),
        if (widget.destinations.isNotEmpty)
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
          onPressed: _toggleSidebar,
          tooltip: l10n.sidebarExpandMenu,
          icon: const Icon(Icons.chevron_right),
        ),
        const SizedBox(height: 8),
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
        borderRadius: BorderRadius.circular(8),
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: _NavInkWell(
            onTap: onTap,
            borderRadius: extension.navItemRadius,
            isSelected: isSelected,
            child: AnimatedScale(
              scale: isSelected ? 1.05 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: Container(
                width: 52,
                height: 52,
                decoration: _buildNavDecoration(isSelected: isSelected, context: context),
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
    final extension = appThemeOf(context);

    return Semantics(
      button: true,
      selected: isSelected,
      label: destination.label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
                  const SizedBox(width: 14),
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
        gradient: LinearGradient(
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

  Widget _buildPinnedPodcastsSection(BuildContext context) {
    // Sample pinned podcasts - in real app, this would come from a provider
    final samplePodcasts = [
      'Tech Talk Daily',
      'Design Matters',
      'AI Frontiers',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            'Pinned',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        const SizedBox(height: 8),
        ...samplePodcasts.map((podcast) => _buildPinnedPodcastItem(context, podcast)),
      ],
    );
  }

  Widget _buildPinnedPodcastItem(BuildContext context, String podcastName) {
    final extension = appThemeOf(context);
    // Deterministically pick a color from the palette based on hash of name
    final colorIndex = podcastName.hashCode % AppColors.podcastGradientColors.length;
    final gradientColors = AppColors.podcastGradientColors[colorIndex];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(extension.navItemRadius),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(extension.navItemRadius),
          ),
          child: Row(
            children: [
              // Gradient color block
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  podcastName,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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

  Widget _buildMobileNavItem(
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
          highlightColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
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
                      gradient: isSelected
                          ? LinearGradient(
                              colors: AppColors.violetColors,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isSelected ? null : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
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

/// Arc+Linear style sidebar with dark surface
class _CleanSidebar extends StatelessWidget {
  const _CleanSidebar({required this.child, required this.expanded});

  final Widget child;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: expanded
            ? BorderRadius.horizontal(right: Radius.circular(14))
            : BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

/// Nav item ink well with hover effect
class _NavInkWell extends StatefulWidget {
  const _NavInkWell({
    required this.onTap,
    required this.borderRadius,
    required this.isSelected,
    required this.child,
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
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        splashColor: Colors.white.withValues(alpha: 0.12),
        highlightColor: Colors.white.withValues(alpha: 0.08),
        hoverColor: Colors.transparent, // We handle hover manually
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: _isHovered && !widget.isSelected
                ? const Color(0x0FFFFFFF) // rgba(255,255,255,0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Arc+Linear style dock with dark surface + blur
class _CleanDock extends StatelessWidget {
  const _CleanDock({super.key, required this.child, required this.width});

  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.darkSurface.withValues(alpha: 0.9),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
