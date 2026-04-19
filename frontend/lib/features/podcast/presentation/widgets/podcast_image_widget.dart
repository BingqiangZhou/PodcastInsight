import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:personal_ai_assistant/core/constants/app_durations.dart';
import 'package:personal_ai_assistant/core/services/app_cache_service.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/core/utils/app_logger.dart' as logger;

/// Podcast image widget with retry/fallback handling.
class PodcastImageWidget extends StatefulWidget {

  const PodcastImageWidget({
    required this.imageUrl, required this.width, required this.height, super.key,
    this.fallbackImageUrl,
    this.fit = BoxFit.cover,
    this.iconColor,
    this.iconSize,
  });
  final String? imageUrl;
  final String? fallbackImageUrl;
  final double width;
  final double height;
  final BoxFit fit;
  final Color? iconColor;
  final double? iconSize;

  @override
  State<PodcastImageWidget> createState() => _PodcastImageWidgetState();
}

class _PodcastImageWidgetState extends State<PodcastImageWidget> {
  int _retryCount = 0;
  bool _useFallback = false;
  String? _currentImageUrl;
  String? _precacheUrl;
  String? _precacheKey;
  int? _precacheWidth;
  int? _precacheHeight;

  @override
  void initState() {
    super.initState();
    _syncCurrentImage(resetRetry: true);
  }

  @override
  void didUpdateWidget(covariant PodcastImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.fallbackImageUrl != widget.fallbackImageUrl) {
      _syncCurrentImage(resetRetry: true);
    }
  }

  void _syncCurrentImage({required bool resetRetry}) {
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) {
      _currentImageUrl = widget.fallbackImageUrl;
      _useFallback = widget.fallbackImageUrl != null;
    } else {
      _currentImageUrl = widget.imageUrl;
      _useFallback = false;
    }
    if (resetRetry) {
      _retryCount = 0;
    }
  }

  void _maybePrecache(String url, String cacheKey, int? width, int? height) {
    if (_precacheUrl == url &&
        _precacheKey == cacheKey &&
        _precacheWidth == width &&
        _precacheHeight == height) {
      return;
    }

    _precacheUrl = url;
    _precacheKey = cacheKey;
    _precacheWidth = width;
    _precacheHeight = height;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final baseProvider = CachedNetworkImageProvider(
        url,
        cacheKey: cacheKey,
        cacheManager: AppMediaCacheManager.instance,
      );

      final ImageProvider provider;
      if (width != null && height != null && width > 0 && height > 0) {
        provider = ResizeImage(baseProvider, width: width, height: height);
      } else {
        provider = baseProvider;
      }

      precacheImage(
        provider,
        context,
        onError: (error, stackTrace) {
          // Prevent async precache failures from surfacing as FlutterError.
          logger.AppLogger.debug('Failed to precache image: $error');
        },
      );
    });
  }

  bool _isForbiddenError(Object? error) {
    if (error == null) {
      return false;
    }
    final message = error.toString();
    return message.contains('statusCode: 403') ||
        message.contains('status code of 403') ||
        message.contains('Invalid statusCode: 403');
  }

  void _handleImageError([Object? error]) {
    final forbidden = _isForbiddenError(error);
    logger.AppLogger.debug(
      'Failed to load image: ${widget.imageUrl} (attempt ${_retryCount + 1}, forbidden=$forbidden)',
    );

    if (_useFallback &&
        widget.fallbackImageUrl != null &&
        _currentImageUrl == widget.fallbackImageUrl) {
      setState(() {
        _currentImageUrl = null;
      });
      return;
    }

    if (forbidden) {
      if (widget.fallbackImageUrl != null && !_useFallback) {
        setState(() {
          _useFallback = true;
          _currentImageUrl = widget.fallbackImageUrl;
          _retryCount = 0;
        });
      } else {
        setState(() {
          _useFallback = true;
          _currentImageUrl = null;
        });
      }
      return;
    }

    if (_retryCount < 2 && !_useFallback && widget.imageUrl != null) {
      setState(() {
        _retryCount++;
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final separator = widget.imageUrl!.contains('?') ? '&' : '?';
        _currentImageUrl = '${widget.imageUrl}$separator$timestamp';
      });
      return;
    }

    if (widget.fallbackImageUrl != null && !_useFallback) {
      setState(() {
        _useFallback = true;
        _currentImageUrl = widget.fallbackImageUrl;
        _retryCount = 0;
      });
      return;
    }

    setState(() {
      _useFallback = true;
      _currentImageUrl = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extension = appThemeOf(context);
    final iconColor = widget.iconColor ?? theme.colorScheme.onSurfaceVariant;
    final iconSize = widget.iconSize ?? (widget.width * 0.6);

    if (_currentImageUrl == null || _currentImageUrl!.isEmpty) {
      return _buildIconPlaceholder(iconColor, iconSize, extension.buttonRadius);
    }

    final stableCacheKey =
        (_useFallback ? widget.fallbackImageUrl : widget.imageUrl) ??
        _currentImageUrl!;

    final dpr = MediaQuery.of(context).devicePixelRatio;
    final cacheWidth = (widget.width * dpr).round();
    final cacheHeight = (widget.height * dpr).round();

    _maybePrecache(_currentImageUrl!, stableCacheKey, cacheWidth, cacheHeight);

    final baseProvider = CachedNetworkImageProvider(
      _currentImageUrl!,
      cacheKey: stableCacheKey,
      cacheManager: AppMediaCacheManager.instance,
    );

    final ImageProvider provider;
    if (cacheWidth > 0 && cacheHeight > 0) {
      provider = ResizeImage(
        baseProvider,
        width: cacheWidth,
        height: cacheHeight,
      );
    } else {
      provider = baseProvider;
    }

    return RepaintBoundary(
      child: Image(
        image: provider,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        gaplessPlayback: true,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(extension.buttonRadius),
            ),
            child: Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.4, end: 1),
                duration: AppDurations.shimmerPulse,
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value.clamp(0.0, 1.0),
                    child: child,
                  );
                },
                child: Icon(
                  Icons.podcasts,
                  size: iconSize * 0.6,
                  color: theme.colorScheme.onSurfaceVariant
                      .withValues(alpha: 0.6),
                ),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _handleImageError(error);
            }
          });

          if (_retryCount > 0 || _useFallback) {
            return Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(extension.buttonRadius),
              ),
              child: Icon(
                Icons.refresh,
                size: iconSize * 0.5,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            );
          }

          return SizedBox(width: widget.width, height: widget.height);
        },
      ),
    );
  }

  Widget _buildIconPlaceholder(Color color, double size, double radius) {
    return RepaintBoundary(
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Icon(
          Icons.podcasts,
          size: size,
          color: color.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}
