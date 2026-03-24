import 'package:flutter/material.dart';

import '../constants/breakpoints.dart';
import '../theme/app_colors.dart';
import 'custom_adaptive_navigation.dart';

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
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: resolvedColor.withValues(alpha: 0.2)),
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
  18,
  18,
  18,
  16,
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
    super.key,
    required this.icon,
    required this.onPressed,
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
      HeaderCapsuleActionButtonDensity.regular => 40.0,
      HeaderCapsuleActionButtonDensity.compact => 36.0,
      HeaderCapsuleActionButtonDensity.iconOnly => 36.0,
    };

    // Border radius: pill shape for surfaceNeutral, fixed 10.0 for primaryTinted
    final borderRadius = isSurfaceNeutral
        ? (iconOnlyCircular ? iconOnlySize / 2 : 18.0)
        : 10.0;

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
      child: InkWell(
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
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.onSurfaceVariant,
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
                          const SizedBox(width: 6),
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

    if (tooltip == null || tooltip!.trim().isEmpty) {
      return wrapped;
    }

    return Tooltip(message: tooltip!, child: wrapped);
  }
}

/// SurfacePanel - 实体面板组件
///
/// 提供纯色背景 + 边框 + 阴影的容器
class SurfacePanel extends StatelessWidget {
  const SurfacePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.borderRadius,
    this.backgroundColor,
    this.showBorder = true,
    this.showShadow = true,
    this.showHighlight = false, // Legacy parameter, no longer used
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double? borderRadius;
  final Color? backgroundColor;
  final bool showBorder;
  final bool showShadow;
  final bool showHighlight; // Legacy parameter, ignored

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final extension = appThemeOf(context);
    final radius = borderRadius ?? extension.cardRadius;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: backgroundColor ?? scheme.surface,
        borderRadius: BorderRadius.circular(radius),
        border: showBorder
            ? Border.all(color: scheme.outlineVariant)
            : null,
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: theme.brightness == Brightness.dark
                      ? Colors.black.withValues(alpha: 0.2)
                      : Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
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
    final extension = appThemeOf(context);

    return SurfacePanel(
      key: key,
      padding: kCompactHeaderPanelPadding,
      borderRadius: extension.panelRadius,
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

    final extension = appThemeOf(context);

    return SizedBox(
      key: key,
      child: SurfacePanel(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        borderRadius: extension.panelRadius,
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
                            fontWeight: FontWeight.w500,
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
      child: SurfacePanel(
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
    final extension = appThemeOf(context);

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _ShellViewport(
        enabled: roundedViewport,
        clipKey: const Key('content_shell_viewport_clip'),
        borderRadius: extension.panelRadius,
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
    final extension = appThemeOf(context);

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _ShellViewport(
        enabled: roundedViewport,
        clipKey: const Key('profile_shell_viewport_clip'),
        borderRadius: extension.panelRadius,
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
    final extension = appThemeOf(context);
    final width = MediaQuery.of(context).size.width;

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
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
                  SurfacePanel(
                    padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
                    borderRadius: extension.panelRadius,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            subtitle,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
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
    );
  }
}

