import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_ai_assistant/core/constants/app_radius.dart';
import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:personal_ai_assistant/core/constants/app_text_styles.dart';
import 'package:personal_ai_assistant/core/constants/breakpoints.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/platform/adaptive_haptic.dart';
import 'package:personal_ai_assistant/core/platform/platform_helper.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/core/theme/app_theme.dart';
import 'package:personal_ai_assistant/core/utils/app_logger.dart' as logger;
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive.dart';
import 'package:personal_ai_assistant/core/widgets/app_dialog_helper.dart';
import 'package:personal_ai_assistant/core/widgets/custom_adaptive_navigation.dart';
import 'package:personal_ai_assistant/core/widgets/top_floating_notice.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_state_models.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_subscription_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/navigation/podcast_navigation.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/podcast_image_widget.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/simplified_episode_card.dart';
import 'package:personal_ai_assistant/shared/widgets/skeleton_widgets.dart';

part 'podcast_episodes_page_actions.dart';
part 'podcast_episodes_page_view.dart';

class PodcastEpisodesPage extends ConsumerStatefulWidget {

  const PodcastEpisodesPage({
    required this.subscriptionId, super.key,
    this.podcastTitle,
    this.subscription,
  });

  /// Factory for navigation from args
  factory PodcastEpisodesPage.fromArgs(PodcastEpisodesPageArgs args) {
    return PodcastEpisodesPage(
      subscriptionId: args.subscriptionId,
      podcastTitle: args.podcastTitle,
      subscription: args.subscription,
    );
  }

  /// Factory for direct navigation with subscription object
  factory PodcastEpisodesPage.withSubscription(
    PodcastSubscriptionModel subscription,
  ) {
    return PodcastEpisodesPage(
      subscriptionId: subscription.id,
      podcastTitle: subscription.title,
      subscription: subscription,
    );
  }
  final int subscriptionId;
  final String? podcastTitle;
  final PodcastSubscriptionModel? subscription;

  @override
  ConsumerState<PodcastEpisodesPage> createState() =>
      _PodcastEpisodesPageState();
}

class _PodcastEpisodesPageState extends ConsumerState<PodcastEpisodesPage> {
  final ScrollController _scrollController = ScrollController();
  final Set<int> _addingEpisodeIds = <int>{};
  String _selectedFilter = 'all';
  bool _showOnlyWithSummary = false;
  bool _isReparsing = false; // Guard to avoid duplicate reparse requests.
  static const double _desktopEpisodeCardHeight = 160;

  String? get _statusFilter => _selectedFilter == 'played'
      ? 'played'
      : _selectedFilter == 'unplayed'
      ? 'unplayed'
      : null;

  bool? get _hasSummaryFilter => _showOnlyWithSummary ? true : null;

  void _applyViewState(VoidCallback update) {
    setState(update);
  }

  @override
  void initState() {
    super.initState();
    // Load initial episodes
    _loadEpisodesForSubscription();
    _setupInfiniteScrollListener();
  }

  @override
  void didUpdateWidget(PodcastEpisodesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Check if subscriptionId has changed
    if (oldWidget.subscriptionId != widget.subscriptionId) {
      logger.AppLogger.debug(
        '[Episodes] ===== didUpdateWidget: Subscription ID changed =====',
      );
      logger.AppLogger.debug(
        '[Episodes] Old Subscription ID: ${oldWidget.subscriptionId}',
      );
      logger.AppLogger.debug(
        '[Episodes] New Subscription ID: ${widget.subscriptionId}',
      );
      logger.AppLogger.debug(
        '[Episodes] Reloading episodes for new subscription',
      );

      // Reset filters
      _selectedFilter = 'all';
      _showOnlyWithSummary = false;

      // Reload episodes for the new subscription
      _loadEpisodesForSubscription(forceRefresh: true);

      logger.AppLogger.debug('[Episodes] ===== didUpdateWidget complete =====');
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fallbackSubscriptionImageUrl = ref.watch(
      podcastEpisodesProvider.select(
        (state) =>
            state.episodes.isNotEmpty ? state.episodes.first.subscriptionImageUrl : null,
      ),
    );
    final episodesState = ref.watch(podcastEpisodesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Material(
        color: Colors.transparent,
        child: ResponsiveContainer(
          maxWidth: 1480,
          avoidTopSafeArea: true,
          alignment: Alignment.topCenter,
          child: AdaptiveRefreshIndicator.sliver(
            onRefresh: _refreshEpisodes,
            child: const SizedBox.shrink(),
            builder: (context, refreshSliver) {
              return Scrollbar(
                controller: _scrollController,
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    if (refreshSliver != null) refreshSliver,
                    AdaptiveSliverAppBar(
                      title: widget.podcastTitle ?? l10n.podcast_episodes,
                      leading: Padding(
                        padding: EdgeInsetsDirectional.only(start: context.spacing.xs),
                        child: _buildHeaderCover(fallbackSubscriptionImageUrl),
                      ),
                      actions: _buildHeaderActions(l10n),
                    ),
                    SliverToBoxAdapter(
                      child: MediaQuery.sizeOf(context).width >= Breakpoints.compact
                          ? Padding(
                              padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
                              child: _buildFilterChips(),
                            )
                          : const SizedBox.shrink(),
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: context.spacing.sm)),
                    ...episodesState.isLoading && episodesState.episodes.isEmpty
                        ? _buildLoadingSlivers()
                        : episodesState.error != null
                            ? _buildErrorSlivers(episodesState.error!)
                            : episodesState.episodes.isEmpty
                                ? _buildEmptySlivers()
                                : _buildDataSlivers(episodesState),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Loading state slivers.
  List<Widget> _buildLoadingSlivers() {
    return const [
      SliverFillRemaining(
        hasScrollBody: false,
        child: SkeletonCardList(
          itemCount: 6,
          compact: true,
          showDescription: false,
        ),
      ),
    ];
  }

  /// Error state slivers.
  List<Widget> _buildErrorSlivers(Object error) {
    return [
      SliverFillRemaining(
        hasScrollBody: false,
        child: _buildErrorState(error),
      ),
    ];
  }

  /// Empty state slivers.
  List<Widget> _buildEmptySlivers() {
    return [
      SliverFillRemaining(
        hasScrollBody: false,
        child: _buildEmptyState(),
      ),
    ];
  }

  /// Data state slivers with responsive layout.
  List<Widget> _buildDataSlivers(PodcastEpisodesState episodesState) {
    return [
      SliverLayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.crossAxisExtent;
          if (width < Breakpoints.medium) {
            return _buildMobileSlivers(episodesState);
          }
          return _buildDesktopSlivers(episodesState, width);
        },
      ),
    ];
  }
}
