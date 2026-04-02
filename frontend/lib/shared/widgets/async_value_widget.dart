import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/network/exceptions/network_exceptions.dart';

/// A reusable widget for handling AsyncValue states from Riverpod providers.
///
/// This widget provides a consistent way to handle loading, error, and data
/// states for AsyncValue objects, reducing boilerplate in UI code.
///
/// Example usage:
/// ```dart
/// AsyncValueWidget(
///   value: highlightsProvider,
///   builder: (data) => ListView.builder(...),
///   onRetry: () => ref.invalidate(highlightsProvider),
/// )
/// ```
class AsyncValueWidget<T> extends StatelessWidget {
  /// The AsyncValue to observe
  final AsyncValue<T> value;

  /// Builder for successful data state
  final Widget Function(T data) builder;

  /// Widget to show during loading state
  final Widget? loadingWidget;

  /// Builder for error state
  final Widget Function(Object error, StackTrace stack)? errorBuilder;

  /// Whether to skip loading state if there's previous data
  ///
  /// When true, shows previous data while loading instead of loading widget.
  /// Useful for refresh scenarios where you want to keep showing old data.
  final bool skipLoadingWhenData;

  /// Callback invoked when the user taps the retry button in error state.
  ///
  /// When provided, a retry button is shown in the default error widget.
  final VoidCallback? onRetry;

  const AsyncValueWidget({
    super.key,
    required this.value,
    required this.builder,
    this.loadingWidget,
    this.errorBuilder,
    this.skipLoadingWhenData = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    // Skip loading if we have previous data and skipLoadingWhenData is true
    if (value.isLoading && value.hasValue && skipLoadingWhenData) {
      return builder(value.value as T);
    }

    return value.when(
      data: builder,
      loading: () => loadingWidget ?? _defaultLoadingWidget(context),
      error: (error, stack) => errorBuilder != null
          ? errorBuilder!(error, stack)
          : _defaultErrorWidget(context, error, stack),
    );
  }

  Widget _defaultLoadingWidget(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: CircularProgressIndicator(
        color: theme.colorScheme.primary,
      ),
    );
  }

  Widget _defaultErrorWidget(BuildContext context, Object error, StackTrace stack) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final userMessage = _friendlyErrorMessage(context, error);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: theme.colorScheme.error,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.error_occurred,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              userMessage,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              FilledButton.tonal(
                onPressed: onRetry,
                child: Text(l10n.retry),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Maps exception types to user-friendly localized messages.
  /// Uses [NetworkErrorCode] enum for reliable matching instead of
  /// fragile string comparisons. Falls back to a generic message for
  /// unknown error types.
  static String _friendlyErrorMessage(BuildContext context, Object error) {
    final l10n = context.l10n;

    // Prefer enum-based matching when available
    if (error is AppException) {
      final code = error.errorCode;
      if (code != null) {
        return switch (code) {
          NetworkErrorCode.connectionTimeout ||
          NetworkErrorCode.sendTimeout ||
          NetworkErrorCode.receiveTimeout =>
            l10n.error_network_timeout,
          NetworkErrorCode.noConnection => l10n.error_network_no_connection,
          NetworkErrorCode.serverError => l10n.error_server,
          NetworkErrorCode.authExpired => l10n.error_auth,
          NetworkErrorCode.accessDenied => l10n.error_forbidden,
          NetworkErrorCode.notFound => l10n.error_not_found,
          NetworkErrorCode.validation => l10n.error_validation,
          NetworkErrorCode.conflict => l10n.error_network_generic,
          NetworkErrorCode.unknown => l10n.error_network_generic,
        };
      }
    }

    // Fallback: match by exception type (no errorCode set)
    if (error is NetworkException) return l10n.error_network_generic;
    if (error is ServerException) return l10n.error_server;
    if (error is AuthenticationException) return l10n.error_auth;
    if (error is AuthorizationException) return l10n.error_forbidden;
    if (error is NotFoundException) return l10n.error_not_found;
    if (error is ValidationException) return l10n.error_validation;

    // For other errors, show the message but truncate if too long
    final message = error.toString();
    if (message.length > 120) return '${message.substring(0, 120)}...';
    return message;
  }
}

/// A specialized version of AsyncValueWidget for nullable data types.
///
/// This handles the case where T might be null, providing additional
/// empty state handling.
class AsyncValueNullableWidget<T> extends StatelessWidget {
  final AsyncValue<T?> value;
  final Widget Function(T data) builder;
  final Widget? loadingWidget;
  final Widget Function(Object error, StackTrace stack)? errorBuilder;
  final Widget Function()? emptyBuilder;
  final bool skipLoadingWhenData;
  final VoidCallback? onRetry;

  const AsyncValueNullableWidget({
    super.key,
    required this.value,
    required this.builder,
    this.loadingWidget,
    this.errorBuilder,
    this.emptyBuilder,
    this.skipLoadingWhenData = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return AsyncValueWidget<T?>(
      value: value,
      loadingWidget: loadingWidget,
      errorBuilder: errorBuilder,
      skipLoadingWhenData: skipLoadingWhenData,
      onRetry: onRetry,
      builder: (data) {
        if (data == null) {
          return emptyBuilder?.call() ?? _defaultEmptyWidget(context);
        }
        return builder(data);
      },
    );
  }

  Widget _defaultEmptyWidget(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            color: theme.colorScheme.onSurfaceVariant,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'No data available',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
