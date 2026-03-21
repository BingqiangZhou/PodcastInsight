import 'dart:ui';

import 'package:flutter/material.dart';

import '../constants/breakpoints.dart';
import '../theme/app_colors.dart';
import '../utils/performance_utils.dart';
import 'custom_adaptive_navigation.dart';

/// Get the Arctic Garden theme extension from context
MindriverThemeExtension arcticThemeOf(BuildContext context) {
  return Theme.of(context).extension<MindriverThemeExtension>() ??
      (Theme.of(context).brightness == Brightness.dark
          ? MindriverThemeExtension.dark
          : MindriverThemeExtension.light);
}

/// ArcticPageBackdrop - 北极花园页面背景
///
/// 提供渐变背景和极光光晕效果
class ArcticPageBackdrop extends StatelessWidget {
  const ArcticPageBackdrop({super.key, this.paddingTop = 0});

  final double paddingTop;

  @override
  Widget build(BuildContext context) {
    final tokens = arcticThemeOf(context);
    final enableOrbs = DevicePerformance.enableComplexAnimations;

    return DecoratedBox(
      decoration: BoxDecoration(gradient: tokens.shellGradient),
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Primary aurora glow - 始终显示
            Positioned(
              top: paddingTop - 60,
              left: -20,
              child: _Orb(
                size: 200,
                color: tokens.auroraGlow.withValues(alpha: 0.2),
              ),
            ),
            // Secondary orbs - 仅在高端设备
            if (enableOrbs) ...[
              Positioned(
                top: paddingTop + 60,
                right: -40,
                child: _Orb(
                  size: 180,
                  color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.1),
                ),
              ),
              Positioned(
                bottom: -80,
                left: 30,
                child: _Orb(
                  size: 220,
                  color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.08),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [color, color.withValues(alpha: 0)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// GlassPanel - 玻璃面板组件
///
/// 提供毛玻璃效果的容器
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.borderRadius,
    this.backgroundColor,
    this.showHighlight = true,
    this.enableBlur,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double? borderRadius;
  final Color? backgroundColor;
  final bool showHighlight;
  final bool? enableBlur;

  @override
  Widget build(BuildContext context) {
    final tokens = arcticThemeOf(context);
    final radius = borderRadius ?? tokens.cardRadius;
    final shouldEnableBlur = enableBlur ?? DevicePerformance.enableGlassmorphism;

    return RepaintBoundary(
      child: Container(
        margin: margin,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: tokens.glassShadow,
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: shouldEnableBlur
              ? BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: _buildGlassContent(tokens, radius),
                )
              : _buildGlassContent(tokens, radius),
        ),
      ),
    );
  }

  Widget _buildGlassContent(MindriverThemeExtension tokens, double radius) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? tokens.glassSurface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: tokens.glassBorder),
        gradient: showHighlight
            ? LinearGradient(
                colors: [
                  tokens.glassHighlight.withValues(alpha: 0.1),
                  Colors.transparent,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
      ),
      padding: padding,
      child: child,
    );
  }
}

/// StatusBadge - 状态徽章
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, this.icon, this.color});

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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: resolvedColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: resolvedColor.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: resolvedColor),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: resolvedColor,
                fontWeight: FontWeight.w600,
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
    super.key,
    required this.title,
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
                if (!hideTitle) const SizedBox(height: 5),
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
        if (trailing != null) ...[const SizedBox(width: 16), trailing!],
      ],
    );
  }
}

const double kCompactHeaderContentHeight = 44;
const double kCompactHeaderItemGap = 14;
const EdgeInsets kCompactHeaderPanelPadding = EdgeInsets.fromLTRB(
  20,
  20,
  20,
  18,
);

enum HeaderCapsuleActionButtonDensity { regular, compact, iconOnly }

/// HeaderCapsuleActionButton - 头部胶囊按钮
class HeaderCapsuleActionButton extends StatelessWidget {
  const HeaderCapsuleActionButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.label,
    this.trailingIcon,
    this.padding,
    this.circular = false,
    this.density = HeaderCapsuleActionButtonDensity.regular,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Widget? label;
  final IconData? trailingIcon;
  final EdgeInsetsGeometry? padding;
  final bool circular;
  final HeaderCapsuleActionButtonDensity density;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasLabel = label != null;
    final hidesLabel = density == HeaderCapsuleActionButtonDensity.iconOnly;
    final showLabel = hasLabel && !hidesLabel;
    final showTrailing = trailingIcon != null && !hidesLabel;
    final iconOnlyCircular = circular || hidesLabel;

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
                    horizontal: showLabel ? 12 : 14,
                    vertical: showLabel ? 10 : 12,
                  ),
          HeaderCapsuleActionButtonDensity.compact =>
            iconOnlyCircular
                ? EdgeInsets.zero
                : EdgeInsets.symmetric(
                    horizontal: showLabel ? 10 : 12,
                    vertical: showLabel ? 8 : 10,
                  ),
          HeaderCapsuleActionButtonDensity.iconOnly => EdgeInsets.zero,
        };

    final iconOnlySize = switch (density) {
      HeaderCapsuleActionButtonDensity.regular => 42.0,
      HeaderCapsuleActionButtonDensity.compact => 38.0,
      HeaderCapsuleActionButtonDensity.iconOnly => 38.0,
    };

    final button = Material(
      color: theme.colorScheme.primary.withValues(
        alpha: onPressed == null ? 0.06 : 0.1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(
          color: theme.colorScheme.primary.withValues(
            alpha: onPressed == null ? 0.12 : 0.2,
          ),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: resolvedIconSize,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: onPressed == null ? 0.5 : 1,
                    ),
                  ),
                  if (showLabel) ...[
                    const SizedBox(width: 6),
                    DefaultTextStyle(
                      style: theme.textTheme.labelMedium!.copyWith(
                        fontSize: density == HeaderCapsuleActionButtonDensity.compact
                            ? 12
                            : null,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: onPressed == null ? 0.5 : 1,
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
                        alpha: onPressed == null ? 0.5 : 1,
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
      enabled: onPressed != null,
      label: semanticsLabel,
      child: button,
    );

    if (tooltip == null || tooltip!.trim().isEmpty) {
      return wrapped;
    }

    return Tooltip(message: tooltip!, child: wrapped);
  }
}

/// CompactHeaderPanel - 紧凑头部面板
class CompactHeaderPanel extends StatelessWidget {
  const CompactHeaderPanel({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
  });

  final String title;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = arcticThemeOf(context);

    return GlassPanel(
      key: key,
      padding: kCompactHeaderPanelPadding,
      borderRadius: tokens.panelRadius,
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
class HeroHeader extends StatelessWidget {
  const HeroHeader({
    super.key,
    required this.title,
    required this.subtitle,
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasEyebrow = eyebrow != null && eyebrow!.trim().isNotEmpty;
    final hasSubtitle = subtitle.trim().isNotEmpty;
    final compactHeader = !hasEyebrow && !hasSubtitle && badges.isEmpty;

    if (compactHeader) {
      return CompactHeaderPanel(
        key: key,
        title: title,
        leading: leading,
        trailing: trailing,
      );
    }

    final tokens = arcticThemeOf(context);

    return SizedBox(
      key: key,
      child: GlassPanel(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        borderRadius: tokens.panelRadius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 12)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasEyebrow) ...[
                        Text(
                          eyebrow!,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 5),
                      ],
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.headlineSmall,
                      ),
                      if (hasSubtitle) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 12),
                  Align(alignment: Alignment.topCenter, child: trailing!),
                ],
              ],
            ),
            if (badges.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: badges),
            ],
          ],
        ),
      ),
    );
  }
}

/// AppEmptyState - 空状态
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
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
      child: GlassPanel(
        padding: const EdgeInsets.all(32),
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
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 10),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (action != null) ...[const SizedBox(height: 24), action!],
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
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.eyebrow,
    this.leading,
    this.trailing,
    this.badges = const <Widget>[],
    this.headerSpacing = 10,
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
    final tokens = arcticThemeOf(context);

    return Material(
      color: Colors.transparent,
      child: _ShellViewport(
        enabled: roundedViewport,
        clipKey: const Key('content_shell_viewport_clip'),
        borderRadius: tokens.panelRadius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ArcticPageBackdrop(),
            ResponsiveContainer(
              maxWidth: maxWidth ?? tokens.contentMaxWidth,
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
          ],
        ),
      ),
    );
  }
}

/// ProfileShell - 个人资料页面壳
class ProfileShell extends StatelessWidget {
  const ProfileShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.summary,
    required this.child,
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
    final topSectionSpacing = isMobile ? 24.0 : 14.0;
    final tokens = arcticThemeOf(context);

    return Material(
      color: Colors.transparent,
      child: _ShellViewport(
        enabled: roundedViewport,
        clipKey: const Key('profile_shell_viewport_clip'),
        borderRadius: tokens.panelRadius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ArcticPageBackdrop(),
            ResponsiveContainer(
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
                    const SizedBox(height: 14),
                  ],
                  if (!showSummary) SizedBox(height: topSectionSpacing),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 28),
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.header,
    this.footer,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? header;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final tokens = arcticThemeOf(context);
    final width = MediaQuery.of(context).size.width;

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ArcticPageBackdrop(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: width < AppBreakpoints.medium ? 24 : 36,
                  vertical: 28,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    children: [
                      if (header != null) ...[
                        header!,
                        const SizedBox(height: 20),
                      ],
                      GlassPanel(
                        padding: const EdgeInsets.fromLTRB(32, 32, 32, 32),
                        borderRadius: tokens.panelRadius,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              title,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              subtitle,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 28),
                            child,
                          ],
                        ),
                      ),
                      if (footer != null) ...[
                        const SizedBox(height: 20),
                        footer!,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Legacy compatibility
typedef AppPageBackdrop = ArcticPageBackdrop;

/// Legacy function for backwards compatibility
MindriverThemeExtension mindriverThemeOf(BuildContext context) => arcticThemeOf(context);
