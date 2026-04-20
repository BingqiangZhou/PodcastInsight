import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:personal_ai_assistant/core/constants/app_durations.dart';
import 'package:personal_ai_assistant/core/constants/app_radius.dart';
import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:personal_ai_assistant/core/constants/breakpoints.dart';
import 'package:personal_ai_assistant/core/platform/platform_helper.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive.dart';
import 'package:personal_ai_assistant/core/widgets/custom_adaptive_navigation.dart';

/// StatusBadge - 状态徽章
class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.label, super.key, this.icon, this.color});

  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resolvedColor = color ?? scheme.primary;

    return Semantics(
      label: label,
      container: true,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: context.spacing.smMd, vertical: context.spacing.xsSm),
        decoration: BoxDecoration(
          color: resolvedColor.withValues(alpha: 0.1),
          borderRadius: AppRadius.smRadius,
          border: Border.all(color: resolvedColor.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: resolvedColor),
              SizedBox(width: context.spacing.xs),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: resolvedColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// AppSectionHeader - 区块标题
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    required this.title, super.key,
    this.subtitle,
    this.trailing,
    this.hideTitle = false,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool hideTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!hideTitle) Text(title, style: theme.textTheme.titleLarge),
              if (subtitle != null) ...[
                if (!hideTitle) SizedBox(height: context.spacing.xs),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[SizedBox(width: context.spacing.md), trailing!],
      ],
    );
  }
}

const double kCompactHeaderContentHeight = 44;
const double kCompactHeaderItemGap = AppSpacing.md;
const EdgeInsets kCompactHeaderPanelPadding = EdgeInsets.fromLTRB(
  AppSpacing.md,
  AppSpacing.md,
  AppSpacing.md,
  AppSpacing.md,
);

enum HeaderCapsuleActionButtonDensity { regular, compact, iconOnly }

/// HeaderCapsuleActionButtonStyle - 头部胶囊按钮样式
enum HeaderCapsuleActionButtonStyle {
  /// Primary tinted style with colored background and border
  primaryTinted,
  /// Neutral surface style matching discover page (surfaceContainerHighest, no border)
  surfaceNeutral,
}

/// HeaderCapsuleActionButton - 头部胶囊按钮
class HeaderCapsuleActionButton extends StatelessWidget {
  const HeaderCapsuleActionButton({
    required this.icon, required this.onPressed, super.key,
    this.tooltip,
    this.label,
    this.trailingIcon,
    this.padding,
    this.circular = false,
    this.density = HeaderCapsuleActionButtonDensity.regular,
    this.isLoading = false,
    this.style = HeaderCapsuleActionButtonStyle.surfaceNeutral,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Widget? label;
  final IconData? trailingIcon;
  final EdgeInsetsGeometry? padding;
  final bool circular;
  final HeaderCapsuleActionButtonDensity density;
  final bool isLoading;
  final HeaderCapsuleActionButtonStyle style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasLabel = label != null;
    final hidesLabel = density == HeaderCapsuleActionButtonDensity.iconOnly;
    final showLabel = hasLabel && !hidesLabel;
    final showTrailing = trailingIcon != null && !hidesLabel;
    final iconOnlyCircular = circular || hidesLabel;
    final isDisabled = onPressed == null || isLoading;

    // Style-specific colors
    final isSurfaceNeutral = style == HeaderCapsuleActionButtonStyle.surfaceNeutral;

    // Dark mode uses higher alpha for better visibility (primaryTinted only)
    final bgAlpha = isDisabled
        ? (isDark ? 0.08 : 0.06)
        : (isDark ? 0.14 : 0.1);
    final borderAlpha = isDisabled
        ? (isDark ? 0.16 : 0.12)
        : (isDark ? 0.24 : 0.2);

    final resolvedIconSize = switch (density) {
      HeaderCapsuleActionButtonDensity.regular => 18.0,
      HeaderCapsuleActionButtonDensity.compact => 16.0,
      HeaderCapsuleActionButtonDensity.iconOnly => 18.0,
    };

    final resolvedPadding = padding ??
        switch (density) {
          HeaderCapsuleActionButtonDensity.regular =>
            iconOnlyCircular
                ? EdgeInsets.zero
                : EdgeInsets.symmetric(
                    horizontal: showLabel ? context.spacing.smMd : context.spacing.md,
                    vertical: showLabel ? context.spacing.smMd : context.spacing.smMd,
                  ),
          HeaderCapsuleActionButtonDensity.compact =>
            iconOnlyCircular
                ? EdgeInsets.zero
                : EdgeInsets.symmetric(
                    horizontal: showLabel ? context.spacing.smMd : context.spacing.smMd,
                    vertical: showLabel ? context.spacing.sm : context.spacing.smMd,
                  ),
          HeaderCapsuleActionButtonDensity.iconOnly => EdgeInsets.zero,
        };

    final iconOnlySize = switch (density) {
      HeaderCapsuleActionButtonDensity.regular => 40.0,
      HeaderCapsuleActionButtonDensity.compact => 36.0,
      HeaderCapsuleActionButtonDensity.iconOnly => 36.0,
    };

    // Border radius: pill shape for surfaceNeutral, fixed for primaryTinted
    final borderRadius = isSurfaceNeutral
        ? (iconOnlyCircular ? iconOnlySize / 2 : AppRadius.chip)
        : appThemeOf(context).buttonRadius;

    final button = Material(
      color: isSurfaceNeutral
          ? theme.colorScheme.surfaceContainerHighest
          : theme.colorScheme.primary.withValues(alpha: bgAlpha),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        side: isSurfaceNeutral
          ? BorderSide.none
          : BorderSide(
            color: theme.colorScheme.primary.withValues(alpha: borderAlpha),
          ),
      ),
      child: AdaptiveInkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: isLoading ? null : onPressed,
        child: ConstrainedBox(
          constraints: iconOnlyCircular
              ? BoxConstraints.tightFor(
                  width: iconOnlySize,
                  height: iconOnlySize,
                )
              : const BoxConstraints(),
          child: Center(
            child: Padding(
              padding: resolvedPadding,
              child: isLoading
                  ? SizedBox(
                      width: resolvedIconSize,
                      height: resolvedIconSize,
                      child: Theme(
                        data: theme.copyWith(
                          colorScheme: theme.colorScheme.copyWith(
                            primary: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        child: const CircularProgressIndicator.adaptive(
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          size: resolvedIconSize,
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: isDisabled ? 0.5 : 1,
                          ),
                        ),
                        if (showLabel) ...[
                          SizedBox(width: context.spacing.sm),
                          DefaultTextStyle(
                            style: (theme.textTheme.labelMedium ?? const TextStyle()).copyWith(
                              fontSize: density == HeaderCapsuleActionButtonDensity.compact
                                  ? 12
                                  : null,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: isDisabled ? 0.5 : 1,
                              ),
                            ),
                            child: label!,
                          ),
                        ],
                        if (showTrailing) ...[
                          SizedBox(width: showLabel ? 5 : 0),
                          Icon(
                            trailingIcon,
                            size: density == HeaderCapsuleActionButtonDensity.compact ? 14 : 16,
                            color: theme.colorScheme.onSurfaceVariant.withValues(
                              alpha: isDisabled ? 0.5 : 1,
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );

    final semanticsLabel = tooltip;
    final wrapped = Semantics(
      button: true,
      enabled: onPressed != null && !isLoading,
      label: semanticsLabel,
      child: button,
    );

    final tooltipText = tooltip;
    if (tooltipText == null || tooltipText.trim().isEmpty) {
      return wrapped;
    }

    return Tooltip(message: tooltipText, child: wrapped);
  }
}

/// SurfacePanel - Surface panel with container decoration
///
/// Uses Container with BoxDecoration for panels.
/// Includes a subtle fade-in + slide-up entrance animation on first build.
class SurfacePanel extends StatefulWidget {
  const SurfacePanel({
    required this.child, super.key,
    this.padding,
    this.margin,
    this.borderRadius,
    this.backgroundColor,
    this.showBorder = true,
    this.showShadow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? borderRadius;
  final Color? backgroundColor;
  final bool showBorder;
  final bool showShadow;

  @override
  State<SurfacePanel> createState() => _SurfacePanelState();
}

class _SurfacePanelState extends State<SurfacePanel> {
  bool _hasAnimated = false;

  @override
  Widget build(BuildContext context) {
    final extension = appThemeOf(context);
    final radius = widget.borderRadius ?? extension.cardRadius;
    final isMobile = Breakpoints.isMobile(MediaQuery.sizeOf(context).width);
    final effectivePadding = widget.padding ??
        EdgeInsets.all(isMobile ? AppSpacing.sm : AppSpacing.md);

    final panel = Container(
      margin: widget.margin,
      padding: effectivePadding,
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.15),
        ),
      ),
      child: widget.child,
    );

    // Only play entrance animation once
    if (_hasAnimated) return panel;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppDurations.entranceNormal,
      curve: Curves.easeOutCubic,
      onEnd: () => _hasAnimated = true,
      builder: (context, value, child) {
        final opacity = value.clamp(0.0, 1.0);
        final offset = (1.0 - value) * 8.0;
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, offset),
            child: child,
          ),
        );
      },
      child: panel,
    );
  }
}


/// CompactHeaderPanel - 紧凑头部面板
///
/// @deprecated Use [AdaptiveSliverAppBar] instead.
/// This widget will be removed in a future version.
@Deprecated('Use AdaptiveSliverAppBar instead')
class CompactHeaderPanel extends StatelessWidget {
  const CompactHeaderPanel({
    required this.title, super.key,
    this.leading,
    this.trailing,
  });

  final String title;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extension = appThemeOf(context);

    return SurfacePanel(
      key: key,
      padding: kCompactHeaderPanelPadding,
      borderRadius: extension.cardRadius,
      child: SizedBox(
        height: kCompactHeaderContentHeight,
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: kCompactHeaderItemGap),
            ],
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineMedium,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: kCompactHeaderItemGap),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

/// HeroHeader - 英雄头部
///
/// Staggered fade-in entrance for eyebrow (0ms), title (50ms), subtitle (100ms).
class HeroHeader extends StatefulWidget {
  const HeroHeader({
    required this.title, required this.subtitle, super.key,
    this.eyebrow,
    this.leading,
    this.trailing,
    this.badges = const <Widget>[],
  });

  final String title;
  final String subtitle;
  final String? eyebrow;
  final Widget? leading;
  final Widget? trailing;
  final List<Widget> badges;

  @override
  State<HeroHeader> createState() => _HeroHeaderState();
}

class _HeroHeaderState extends State<HeroHeader> {
  bool _animated = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eyebrowText = widget.eyebrow;
    final hasEyebrow = eyebrowText != null && eyebrowText.trim().isNotEmpty;
    final hasSubtitle = widget.subtitle.trim().isNotEmpty;
    final compactHeader = !hasEyebrow && !hasSubtitle && widget.badges.isEmpty;

    if (compactHeader) {
      return CompactHeaderPanel(
        key: widget.key,
        title: widget.title,
        leading: widget.leading,
        trailing: widget.trailing,
      );
    }

    final extension = appThemeOf(context);

    return SizedBox(
      key: widget.key,
      child: SurfacePanel(
        padding: EdgeInsets.fromLTRB(context.spacing.md, context.spacing.md, context.spacing.md, context.spacing.md),
        borderRadius: extension.cardRadius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.leading != null) ...[
                  widget.leading!,
                  SizedBox(width: context.spacing.smMd),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasEyebrow) ...[
                        _StaggeredFadeIn(
                          delay: Duration.zero,
                          animated: _animated,
                          onDone: () {},
                          child: Text(
                            eyebrowText,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        SizedBox(height: context.spacing.xs),
                      ],
                      _StaggeredFadeIn(
                        delay: AppDurations.staggerQuick,
                        animated: _animated,
                        onDone: () {},
                        child: Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.displaySmall,
                        ),
                      ),
                      if (hasSubtitle) ...[
                        SizedBox(height: context.spacing.xs),
                        _StaggeredFadeIn(
                          delay: AppDurations.staggerNormal,
                          animated: _animated,
                          onDone: () {
                            if (!_animated) _animated = true;
                          },
                          child: Text(
                            widget.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (widget.trailing != null) ...[
                  SizedBox(width: context.spacing.smMd),
                  Align(alignment: Alignment.topCenter, child: widget.trailing),
                ],
              ],
            ),
            if (widget.badges.isNotEmpty) ...[
              SizedBox(height: context.spacing.sm),
              Wrap(spacing: context.spacing.sm, runSpacing: context.spacing.sm, children: widget.badges),
            ],
          ],
        ),
      ),
    );
  }
}

/// Staggered fade-in helper for HeroHeader text elements.
///
/// Animates opacity 0 -> 1 with a vertical slide (8px -> 0) over 200ms
/// after an optional [delay]. Only plays once; subsequent builds render
/// the child directly when [animated] is true.
class _StaggeredFadeIn extends StatefulWidget {
  const _StaggeredFadeIn({
    required this.delay,
    required this.animated,
    required this.onDone,
    required this.child,
  });

  final Duration delay;
  final bool animated;
  final VoidCallback onDone;
  final Widget child;

  @override
  State<_StaggeredFadeIn> createState() => _StaggeredFadeInState();
}

class _StaggeredFadeInState extends State<_StaggeredFadeIn> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    if (!widget.animated) {
      Future.delayed(widget.delay, () {
        if (mounted) setState(() => _visible = true);
      });
    } else {
      _visible = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_visible && widget.animated) return widget.child;

    return AnimatedOpacity(
      opacity: _visible ? 1.0 : 0.0,
      duration: AppDurations.entranceNormal,
      curve: Curves.easeOutCubic,
      onEnd: () {
        if (_visible) widget.onDone();
      },
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 0.02),
        duration: AppDurations.entranceNormal,
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// AppEmptyState - 空状态
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    required this.icon, required this.title, super.key,
    this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: SurfacePanel(
        padding: EdgeInsets.all(context.spacing.xxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 36, color: scheme.primary),
              ),
              SizedBox(height: context.spacing.mdLg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (subtitle != null) ...[
                SizedBox(height: context.spacing.smMd),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (action != null) ...[SizedBox(height: context.spacing.lg), action!],
            ],
          ),
        ),
      ),
    );
  }
}

/// ContentShell - 内容页面壳
class ContentShell extends StatelessWidget {
  const ContentShell({
    required this.title, required this.subtitle, required this.child, super.key,
    this.eyebrow,
    this.leading,
    this.trailing,
    this.badges = const <Widget>[],
    this.headerSpacing = AppSpacing.smMd,
    this.maxWidth,
    this.roundedViewport = false,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final String? eyebrow;
  final Widget? leading;
  final Widget? trailing;
  final List<Widget> badges;
  final double headerSpacing;
  final double? maxWidth;
  final bool roundedViewport;

  @override
  Widget build(BuildContext context) {
    final extension = appThemeOf(context);

    // Unified layout: HeroHeader + Column for consistent rounded corners
    return Material(
      color: Colors.transparent,
      child: _ShellViewport(
          enabled: roundedViewport,
          clipKey: const Key('content_shell_viewport_clip'),
          borderRadius: extension.cardRadius,
          child: ResponsiveContainer(
            maxWidth: maxWidth ?? extension.contentMaxWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HeroHeader(
                  eyebrow: eyebrow,
                  title: title,
                  subtitle: subtitle,
                  leading: leading,
                  trailing: trailing,
                  badges: badges,
                ),
                SizedBox(height: headerSpacing),
                Expanded(child: child),
              ],
            ),
          ),
        ),
    );
  }
}

/// ProfileShell - 个人资料页面壳
class ProfileShell extends StatelessWidget {
  const ProfileShell({
    required this.title, required this.subtitle, required this.summary, required this.child, super.key,
    this.trailing,
    this.badges = const <Widget>[],
    this.roundedViewport = false,
  });

  final String title;
  final String subtitle;
  final Widget summary;
  final Widget child;
  final Widget? trailing;
  final List<Widget> badges;
  final bool roundedViewport;

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    final showSummary = summary is! SizedBox;
    final topSectionSpacing = isMobile ? context.spacing.lg : context.spacing.md;
    final extension = appThemeOf(context);

    // Apple (iOS/macOS): Use CupertinoSliverNavigationBar for native large-title feel
    if (PlatformHelper.isApple(context)) {
      final slivers = <Widget>[
        CupertinoSliverNavigationBar(
          largeTitle: Text(title),
          trailing: trailing,
          backgroundColor:
              CupertinoColors.systemBackground.withValues(alpha: 0.85),
        ),
        if (showSummary) ...[
          SliverToBoxAdapter(child: SizedBox(height: topSectionSpacing)),
          SliverToBoxAdapter(child: summary),
          SliverToBoxAdapter(child: SizedBox(height: context.spacing.md)),
        ],
        if (!showSummary)
          SliverToBoxAdapter(child: SizedBox(height: topSectionSpacing)),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(bottom: context.spacing.xl),
            child: child,
          ),
        ),
        const SliverPadding(
          padding: EdgeInsets.only(bottom: 120),
        ),
      ];

      return Material(
        color: Colors.transparent,
        child: _ShellViewport(
          enabled: roundedViewport,
          clipKey: const Key('profile_shell_viewport_clip'),
          borderRadius: extension.cardRadius,
          child: ResponsiveContainer(
            child: CustomScrollView(slivers: slivers),
          ),
        ),
      );
    }

    // Android/desktop: existing HeroHeader + Column layout
    return Material(
      color: Colors.transparent,
      child: _ShellViewport(
          enabled: roundedViewport,
          clipKey: const Key('profile_shell_viewport_clip'),
          borderRadius: extension.cardRadius,
          child: ResponsiveContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HeroHeader(
                  key: const Key('profile_hero_header'),
                  title: title,
                  subtitle: subtitle,
                  trailing: trailing,
                  badges: badges,
                ),
                if (showSummary) ...[
                  SizedBox(height: topSectionSpacing),
                  summary,
                  SizedBox(height: context.spacing.md),
                ],
                if (!showSummary) SizedBox(height: topSectionSpacing),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(bottom: context.spacing.xl),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }
}

class _ShellViewport extends StatelessWidget {
  const _ShellViewport({
    required this.child,
    required this.enabled,
    required this.borderRadius,
    this.clipKey,
  });

  final Widget child;
  final bool enabled;
  final double borderRadius;
  final Key? clipKey;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return child;
    }

    return ClipRRect(
      key: clipKey,
      borderRadius: BorderRadius.circular(borderRadius),
      child: child,
    );
  }
}

/// AuthShell - 认证页面壳
class AuthShell extends StatelessWidget {
  const AuthShell({
    required this.title, required this.subtitle, required this.child, super.key,
    this.header,
    this.footer,
    this.titleWidget,
    this.backgroundColor,
    this.showBorder = true,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? header;
  final Widget? footer;
  final Widget? titleWidget;
  final Color? backgroundColor;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final extension = appThemeOf(context);
    final width = MediaQuery.sizeOf(context).width;

    return Material(
      color: Colors.transparent,
      child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: width < Breakpoints.medium ? context.spacing.lg : context.spacing.xl,
                vertical: context.spacing.lg,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  children: [
                    if (header != null) ...[
                      header!,
                      SizedBox(height: context.spacing.md),
                    ],
                    SurfacePanel(
                      padding: EdgeInsets.fromLTRB(context.spacing.lg, context.spacing.lg, context.spacing.lg, context.spacing.lg),
                      borderRadius: extension.cardRadius,
                      backgroundColor: backgroundColor,
                      showBorder: showBorder,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (titleWidget != null)
                            titleWidget!
                          else
                            Text(
                              title,
                              style: Theme.of(context).textTheme.displaySmall,
                            ),
                          if (subtitle.isNotEmpty) ...[
                            SizedBox(height: context.spacing.smMd),
                            Text(
                              subtitle,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                          SizedBox(height: context.spacing.lg),
                          child,
                        ],
                      ),
                    ),
                    if (footer != null) ...[
                      SizedBox(height: context.spacing.mdLg),
                      footer!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
    );
  }
}

