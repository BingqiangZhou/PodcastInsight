import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import 'app_shells.dart';

/// Base class for styled empty state widgets.
///
/// Provides a consistent design language for empty/error states
/// while allowing customization for different contexts.
class StyledEmptyState extends StatelessWidget {
  const StyledEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.iconColor,
    this.backgroundColor,
    this.iconSize = 64,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  final Color? iconColor;
  final Color? backgroundColor;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resolvedIconColor = iconColor ?? scheme.primary;

    return Center(
      child: GlassPanel(
        padding: const EdgeInsets.all(28),
        backgroundColor: backgroundColor,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: iconSize + 16,
                height: iconSize + 16,
                decoration: BoxDecoration(
                  color: resolvedIconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: iconSize * 0.55, color: resolvedIconColor),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
              if (action != null) ...[const SizedBox(height: 20), action!],
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty state for podcast feed when no episodes are available.
class EmptyFeedState extends StatelessWidget {
  const EmptyFeedState({
    super.key,
    required this.onRefresh,
    this.message,
  });

  final VoidCallback onRefresh;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return StyledEmptyState(
      icon: Icons.rss_feed,
      title: l10n.podcast_no_episodes_found,
      subtitle: message,
      action: FilledButton.icon(
        onPressed: onRefresh,
        icon: const Icon(Icons.refresh),
        label: const Text('Refresh'),
      ),
    );
  }
}

/// Empty state for search results when nothing matches.
class EmptySearchState extends StatelessWidget {
  const EmptySearchState({
    super.key,
    required this.query,
    this.onClear,
  });

  final String query;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return StyledEmptyState(
      icon: Icons.search_off,
      iconColor: scheme.onSurfaceVariant,
      title: 'No results found',
      subtitle: 'No results for "$query"',
      action: onClear != null
          ? TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.clear),
              label: const Text('Clear search'),
            )
          : null,
    );
  }
}

/// Empty state for error scenarios.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.title,
  });

  final String message;
  final VoidCallback? onRetry;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return StyledEmptyState(
      icon: Icons.error_outline,
      iconColor: scheme.error,
      title: title ?? 'Something went wrong',
      subtitle: message,
      action: onRetry != null
          ? FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            )
          : null,
    );
  }
}

/// Empty state for network/connection errors.
class NetworkErrorState extends StatelessWidget {
  const NetworkErrorState({
    super.key,
    this.onRetry,
  });

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return StyledEmptyState(
      icon: Icons.wifi_off,
      iconColor: scheme.error,
      title: 'Connection error',
      subtitle: 'Please check your internet connection and try again',
      action: onRetry != null
          ? FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            )
          : null,
    );
  }
}

/// Empty state for subscription/library when empty.
class EmptyLibraryState extends StatelessWidget {
  const EmptyLibraryState({
    super.key,
    required this.onExplore,
  });

  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final tokens = mindriverThemeOf(context);

    return StyledEmptyState(
      icon: Icons.library_books,
      iconColor: tokens.aiPrimary,
      title: 'Your library is empty',
      subtitle: 'Subscribe to your favorite podcasts to build your library',
      action: FilledButton.icon(
        onPressed: onExplore,
        icon: const Icon(Icons.explore),
        label: const Text('Explore podcasts'),
      ),
    );
  }
}

/// Empty state for history when no items exist.
class EmptyHistoryState extends StatelessWidget {
  const EmptyHistoryState({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return StyledEmptyState(
      icon: Icons.history,
      iconColor: scheme.onSurfaceVariant,
      title: 'No listening history',
      subtitle: 'Episodes you play will appear here',
    );
  }
}

/// Empty state for conversations/AI chat.
class EmptyConversationsState extends StatelessWidget {
  const EmptyConversationsState({
    super.key,
    required this.onStartChat,
  });

  final VoidCallback onStartChat;

  @override
  Widget build(BuildContext context) {
    final tokens = mindriverThemeOf(context);

    return StyledEmptyState(
      icon: Icons.chat_bubble_outline,
      iconColor: tokens.aiPrimary,
      title: 'No conversations yet',
      subtitle: 'Ask questions about podcast episodes to get AI-powered insights',
      action: FilledButton.icon(
        onPressed: onStartChat,
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Start a conversation'),
      ),
    );
  }
}
