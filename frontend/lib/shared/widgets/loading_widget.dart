import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class LoadingWidget extends StatelessWidget {
  final double? size;
  final Color? color;
  final double strokeWidth;

  const LoadingWidget({
    super.key,
    this.size,
    this.color,
    this.strokeWidth = 2.5,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedColor =
        color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return SizedBox(
      width: size ?? 24,
      height: size ?? 24,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(resolvedColor),
      ),
    );
  }
}

class LoadingStatusContent extends StatelessWidget {
  const LoadingStatusContent({
    super.key,
    this.title,
    this.subtitle,
    this.spinnerSize = 48,
    this.spinnerStrokeWidth = 2.5,
    this.spinnerColor,
    this.maxWidth = 420,
    this.gapAfterSpinner = 16,
    this.gapAfterTitle = 8,
  });

  final String? title;
  final String? subtitle;
  final double spinnerSize;
  final double spinnerStrokeWidth;
  final Color? spinnerColor;
  final double maxWidth;
  final double gapAfterSpinner;
  final double gapAfterTitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LoadingWidget(
            size: spinnerSize,
            color: spinnerColor ?? scheme.primary,
            strokeWidth: spinnerStrokeWidth,
          ),
          if (title != null) ...[
            SizedBox(height: gapAfterSpinner),
            Text(
              title!,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (subtitle != null) ...[
            SizedBox(height: title != null ? gapAfterTitle : gapAfterSpinner),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class LoadingOverlay extends StatelessWidget {
  final Widget child;
  final bool isLoading;
  final String? loadingText;

  const LoadingOverlay({
    super.key,
    required this.child,
    required this.isLoading,
    this.loadingText,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: scheme.scrim.withValues(alpha: 0.5),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: LoadingStatusContent(
                  key: const Key('loading_overlay_content'),
                  subtitle: loadingText,
                  spinnerSize: 48,
                  spinnerColor: scheme.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class ShimmerLoading extends StatelessWidget {
  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;

  const ShimmerLoading({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resolvedBaseColor = baseColor ?? scheme.surfaceContainerHighest;
    final resolvedHighlightColor =
        highlightColor ?? scheme.surfaceContainerHigh;

    return Shimmer(
      gradient: LinearGradient(
        colors: [resolvedBaseColor, resolvedHighlightColor, resolvedBaseColor],
        stops: const [0.0, 0.5, 1.0],
        begin: const Alignment(-1.0, -0.3),
        end: const Alignment(1.0, 0.3),
      ),
      child: child,
    );
  }
}
