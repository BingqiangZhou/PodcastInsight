import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/app_localizations_en.dart';
import '../../../../core/widgets/top_floating_notice.dart';

import '../providers/podcast_providers.dart';
import '../providers/transcription_providers.dart';
import '../providers/summary_providers.dart';
import '../../data/models/podcast_episode_model.dart';
import '../../data/models/audio_player_state_model.dart';
import '../../data/models/podcast_transcription_model.dart';
import '../widgets/transcript_display_widget.dart';
import '../widgets/shownotes_display_widget.dart';
import '../widgets/transcription_status_widget.dart';
import '../widgets/ai_summary_control_widget.dart';
import '../widgets/conversation_chat_widget.dart';
import '../widgets/podcast_image_widget.dart';
import '../widgets/scrollable_content_wrapper.dart';
import '../services/content_image_share_service.dart';
import '../../../../core/utils/app_logger.dart' as logger;

part 'podcast_episode_detail_page_layout.dart';
part 'podcast_episode_detail_page_header.dart';
part 'podcast_episode_detail_page_tabs.dart';
part 'podcast_episode_detail_page_content.dart';

class PodcastEpisodeDetailPage extends ConsumerStatefulWidget {
  final int episodeId;

  const PodcastEpisodeDetailPage({super.key, required this.episodeId});

  @override
  ConsumerState<PodcastEpisodeDetailPage> createState() =>
      _PodcastEpisodeDetailPageState();
}

class _PodcastEpisodeDetailPageState
    extends ConsumerState<PodcastEpisodeDetailPage> {
  int _selectedTabIndex =
      0; // 0 = Shownotes, 1 = Transcript, 2 = AI Summary, 3 = Conversation
  ProviderSubscription<AsyncValue<PodcastTranscriptionResponse?>>?
  _transcriptionNoticeSubscription;
  bool _hasTrackedEpisodeView = false;
  bool _isAddingToQueue = false;
  String _selectedSummaryText = '';
  PodcastPlayerHostPageOverride? _lastPlayerHostOverride;
  late final PodcastPlayerHostPageOverrideNotifier _playerHostOverrideNotifier;

  // Sticky header animation
  final PageController _pageController = PageController();
  final ValueNotifier<double> _scrollOffset = ValueNotifier(0.0);
  final ValueNotifier<bool> _showScrollToTopButton = ValueNotifier(false);
  bool _isHeaderExpandedState = true;
  static const double _headerScrollThreshold =
      50.0; // Header starts fading after 50px scroll
  static const double _autoCollapseScrollDeltaThreshold = 6.0;
  static const double _scrollToTopFixedLift = 72.0;

  // Scroll to top button
  final Map<int, double> _tabScrollPositions = {
    0: 0.0,
    1: 0.0,
    2: 0.0,
    3: 0.0,
  }; // Track scroll position for each tab
  final Map<int, double> _tabScrollPercentages = {
    0: 0.0,
    1: 0.0,
    2: 0.0,
    3: 0.0,
  }; // Track scroll percentage for each tab
  final Map<int, ScrollController> _tabScrollControllers =
      {}; // ScrollController for each tab

  // GlobalKeys for accessing child widget states to call scrollToTop
  final GlobalKey<ShownotesDisplayWidgetState> _shownotesKey =
      GlobalKey<ShownotesDisplayWidgetState>();
  final GlobalKey<TranscriptDisplayWidgetState> _transcriptKey =
      GlobalKey<TranscriptDisplayWidgetState>();
  final GlobalKey<ScrollableContentWrapperState> _aiSummaryKey =
      GlobalKey<ScrollableContentWrapperState>();
  final GlobalKey<ConversationChatWidgetState> _conversationKey =
      GlobalKey<ConversationChatWidgetState>();

  @override
  void initState() {
    super.initState();
    _playerHostOverrideNotifier = ref.read(
      podcastPlayerHostPageOverrideProvider.notifier,
    );
    // Don't auto-play episode when page loads - user must click play button
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bindTranscriptionNoticeListener();
      _loadTranscriptionStatus();
    });
  }

  @override
  void dispose() {
    _transcriptionNoticeSubscription?.close();
    _pageController.dispose();
    _scrollOffset.dispose();
    _showScrollToTopButton.dispose();
    // Clean up tab scroll controllers
    for (final controller in _tabScrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _bindTranscriptionNoticeListener() {
    _transcriptionNoticeSubscription?.close();
    _transcriptionNoticeSubscription = ref
        .listenManual<AsyncValue<PodcastTranscriptionResponse?>>(
          getTranscriptionProvider(widget.episodeId),
          (previous, next) {
            if (!mounted) {
              return;
            }

            final prevData = previous?.value;
            final nextData = next.value;
            if (nextData == null) {
              return;
            }

            final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();
            if (prevData == null && nextData.isProcessing) {
              showTopFloatingNotice(
                context,
                message: l10n.podcast_transcription_auto_starting,
                extraTopOffset: 72,
              );
              return;
            }

            if (prevData != null &&
                nextData.isProcessing &&
                !prevData.isProcessing) {
              showTopFloatingNotice(
                context,
                message: l10n.podcast_transcription_processing,
                extraTopOffset: 72,
              );
            }
          },
        );
  }

  void _updatePageState(VoidCallback updater) {
    if (!mounted) {
      return;
    }
    setState(updater);
  }

  // Calculate header opacity based on scroll offset
  double get _headerOpacity {
    if (_scrollOffset.value <= 0) return 1.0;
    if (_scrollOffset.value >= _headerScrollThreshold) return 0.0;
    return 1.0 - (_scrollOffset.value / _headerScrollThreshold);
  }

  // Calculate header clipping height based on scroll offset
  double get _headerClipHeight {
    const maxHeaderHeight = 100.0;
    if (_scrollOffset.value <= 0) return maxHeaderHeight;
    if (_scrollOffset.value >= _headerScrollThreshold) return 0.0;
    return maxHeaderHeight * (1 - _scrollOffset.value / _headerScrollThreshold);
  }

  bool get _isHeaderExpanded {
    return _scrollOffset.value < _headerScrollThreshold;
  }

  void _updateHeaderStateForTab(int tabIndex) {
    final nextOffset = tabIndex == 3 ? _headerScrollThreshold : 0.0;
    _scrollOffset.value = nextOffset;
    _isHeaderExpandedState = nextOffset < _headerScrollThreshold;
    _showScrollToTopButton.value = nextOffset > 0;
  }

  void _syncPlayerHostOverride(PodcastPlayerHostPageOverride override) {
    if (_lastPlayerHostOverride == override) {
      return;
    }
    _lastPlayerHostOverride = override;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _playerHostOverrideNotifier.setOverride(override);
    });
  }

  Future<void> _loadAndPlayEpisode() async {
    logger.AppLogger.debug('[Playback] ===== _loadAndPlayEpisode called =====');
    logger.AppLogger.debug('[Playback] widget.episodeId: ${widget.episodeId}');

    try {
      // Wait for episode detail to be loaded
      final episodeDetailAsync = await ref.read(
        episodeDetailProvider(widget.episodeId).future,
      );

      logger.AppLogger.debug(
        '[Playback] Loaded episode detail: ID=${episodeDetailAsync?.id}, Title=${episodeDetailAsync?.title}',
      );

      // Debug: Log itemLink from API response
      if (episodeDetailAsync != null) {
        logger.AppLogger.debug(
          '[API Response] itemLink: ${episodeDetailAsync.itemLink ?? "NULL"}',
        );
      }

      if (episodeDetailAsync != null) {
        // Convert PodcastEpisodeDetailResponse to PodcastEpisodeModel
        final episodeModel = PodcastEpisodeModel(
          id: episodeDetailAsync.id,
          subscriptionId: episodeDetailAsync.subscriptionId,
          subscriptionImageUrl: episodeDetailAsync.subscriptionImageUrl,
          title: episodeDetailAsync.title,
          description: episodeDetailAsync.description,
          audioUrl: episodeDetailAsync.audioUrl,
          audioDuration: episodeDetailAsync.audioDuration,
          audioFileSize: episodeDetailAsync.audioFileSize,
          publishedAt: episodeDetailAsync.publishedAt,
          imageUrl: episodeDetailAsync.imageUrl,
          itemLink: episodeDetailAsync.itemLink,
          transcriptUrl: episodeDetailAsync.transcriptUrl,
          transcriptContent: episodeDetailAsync.transcriptContent,
          aiSummary: episodeDetailAsync.aiSummary,
          summaryVersion: episodeDetailAsync.summaryVersion,
          aiConfidenceScore: episodeDetailAsync.aiConfidenceScore,
          playCount: episodeDetailAsync.playCount,
          lastPlayedAt: episodeDetailAsync.lastPlayedAt,
          season: episodeDetailAsync.season,
          episodeNumber: episodeDetailAsync.episodeNumber,
          explicit: episodeDetailAsync.explicit,
          status: episodeDetailAsync.status,
          metadata: episodeDetailAsync.metadata,
          playbackPosition: episodeDetailAsync.playbackPosition,
          isPlaying: episodeDetailAsync.isPlaying,
          playbackRate: episodeDetailAsync.playbackRate,
          isPlayed: episodeDetailAsync.isPlayed ?? false,
          createdAt: episodeDetailAsync.createdAt,
          updatedAt: episodeDetailAsync.updatedAt,
        );

        logger.AppLogger.debug(
          '[Playback] Auto-playing episode: ${episodeModel.title}',
        );
        await ref
            .read(audioPlayerProvider.notifier)
            .playManagedEpisode(episodeModel);
      }
    } catch (error) {
      logger.AppLogger.debug('[Error] Failed to auto-play episode: $error');
    }
  }

  Future<void> _loadTranscriptionStatus() async {
    try {
      final transcriptionProvider = getTranscriptionProvider(widget.episodeId);
      // Automatically check/start transcription if missing
      await ref
          .read(transcriptionProvider.notifier)
          .checkOrStartTranscription();
    } catch (error) {
      logger.AppLogger.debug(
        '[Error] Failed to load transcription status: $error',
      );
    }
  }

  void _trackEpisodeViewOnce(PodcastEpisodeDetailResponse episodeDetail) {
    if (_hasTrackedEpisodeView) {
      return;
    }
    _hasTrackedEpisodeView = true;
    unawaited(_trackEpisodeView(episodeDetail));
  }

  Future<void> _trackEpisodeView(
    PodcastEpisodeDetailResponse episodeDetail,
  ) async {
    try {
      final repository = ref.read(podcastRepositoryProvider);
      await repository.updatePlaybackProgress(
        episodeId: widget.episodeId,
        position: episodeDetail.playbackPosition ?? 0,
        isPlaying: false,
        playbackRate: episodeDetail.playbackRate,
      );
      ref.invalidate(podcastStatsProvider);
      ref.invalidate(playbackHistoryProvider);
    } catch (error) {
      logger.AppLogger.debug('Failed to track episode view: $error');
    }
  }

  void _handleAutoCollapseOnRead(ScrollNotification scrollNotification) {
    if (scrollNotification is! ScrollUpdateNotification) {
      return;
    }

    if (scrollNotification.metrics.axis != Axis.vertical) {
      return;
    }

    final scrollDelta = scrollNotification.scrollDelta ?? 0.0;
    if (scrollDelta <= _autoCollapseScrollDeltaThreshold) {
      return;
    }

    final playerState = ref.read(audioPlayerProvider);
    if (!playerState.isExpanded) {
      return;
    }

    ref.read(audioPlayerProvider.notifier).setExpanded(false);
  }

  void _recordScrollMetrics(ScrollMetrics metrics) {
    if (metrics.axis != Axis.vertical) {
      return;
    }
    final scrollPosition = metrics.pixels;
    final maxScroll = metrics.maxScrollExtent;
    final scrollPercent = maxScroll > 0 ? (scrollPosition / maxScroll) : 0.0;

    _tabScrollPositions[_selectedTabIndex] = scrollPosition;
    _tabScrollPercentages[_selectedTabIndex] = scrollPercent;
    _scrollOffset.value = scrollPosition;
    _showScrollToTopButton.value = scrollPosition > 0;

    final isExpanded = scrollPosition < _headerScrollThreshold;
    if (isExpanded != _isHeaderExpandedState && mounted) {
      setState(() {
        _isHeaderExpandedState = isExpanded;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final episodeDetailAsync = ref.watch(
      episodeDetailProvider(widget.episodeId),
    );
    final isChatTab = _selectedTabIndex == 3;
    final isTranscriptOrSummaryTab =
        _selectedTabIndex == 1 || _selectedTabIndex == 2;
    final isExpanded = ref.watch(
      audioPlayerProvider.select((state) => state.isExpanded),
    );
    final hasCurrentEpisode = ref.watch(
      audioCurrentEpisodeIdProvider.select((episodeId) => episodeId != null),
    );
    final hostLayout = ref.watch(podcastPlayerHostLayoutProvider);
    final isPlayerCollapsed = !isExpanded;
    final shouldHideOnTranscriptOrSummary =
        isTranscriptOrSummaryTab &&
        isPlayerCollapsed &&
        !_isHeaderExpandedState;
    final hideBottomPlayer = isChatTab || shouldHideOnTranscriptOrSummary;
    final playerBottomInset = hasCurrentEpisode && !hideBottomPlayer
        ? resolvePodcastPlayerTotalReservedSpace(context, hostLayout)
        : 0.0;

    _syncPlayerHostOverride(
      PodcastPlayerHostPageOverride(
        routeOwner: PodcastPlayerHostRouteOwner.episodeDetail,
        hiddenByPage: hideBottomPlayer,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: AnimatedPadding(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.only(bottom: playerBottomInset),
            child: episodeDetailAsync.when(
              data: (episodeDetail) {
                if (episodeDetail == null) {
                  final l10n =
                      (AppLocalizations.of(context) ?? AppLocalizationsEn());
                  return _buildErrorState(
                    context,
                    l10n.podcast_episode_not_found,
                  );
                }
                _trackEpisodeViewOnce(episodeDetail);
                return _buildNewLayout(context, episodeDetail);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _buildErrorState(context, error),
            ),
          ),
        );
      },
    );
  }

  @override
  void didUpdateWidget(PodcastEpisodeDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Check if episodeId has changed
    if (oldWidget.episodeId != widget.episodeId) {
      logger.AppLogger.debug(
        '[Playback] ===== didUpdateWidget: Episode ID changed =====',
      );
      logger.AppLogger.debug(
        '[Playback] Old Episode ID: ${oldWidget.episodeId}',
      );
      logger.AppLogger.debug('[Playback] New Episode ID: ${widget.episodeId}');
      logger.AppLogger.debug(
        '[Playback] Reloading episode data and auto-playing new episode',
      );

      // Invalidate old episode detail provider to force refresh
      logger.AppLogger.debug(
        '[Playback] Invalidating old episode detail provider',
      );
      ref.invalidate(episodeDetailProvider(oldWidget.episodeId));
      _hasTrackedEpisodeView = false;

      // Reset tab selection
      _selectedTabIndex = 0;

      _bindTranscriptionNoticeListener();

      // Reload data for the new episode
      WidgetsBinding.instance.addPostFrameCallback((_) {
        logger.AppLogger.debug(
          '[Playback] Calling _loadAndPlayEpisode for new episode',
        );
        _loadAndPlayEpisode();
        _loadTranscriptionStatus();
      });
      logger.AppLogger.debug('[Playback] ===== didUpdateWidget complete =====');
    }
  }

  // Use actual platform type instead of width breakpoints.
  // Mobile platforms return true, desktop/web-like targets return false.
  bool _isMobilePlatform() {
    switch (Theme.of(context).platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.android:
        return true;
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return false;
    }
  }

  Widget _buildScrollToTopButton() {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;

    final rightMargin = isMobile ? 32.0 : (screenSize.width * 0.1);
    final bottomMargin =
        (isMobile ? (screenSize.height * 0.1) : 32.0) + _scrollToTopFixedLift;

    return Padding(
      key: const Key('podcast_episode_detail_scroll_to_top_button'),
      padding: EdgeInsets.only(right: rightMargin, bottom: bottomMargin),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        child: InkWell(
          onTap: _scrollToTop,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.arrow_upward,
              color: Theme.of(context).colorScheme.onSurface,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }

  void _scrollToTop() {
    // Reset scroll offset to expand header.
    _scrollOffset.value = 0.0;
    _tabScrollPositions[_selectedTabIndex] = 0.0;
    _tabScrollPercentages[_selectedTabIndex] = 0.0;
    _showScrollToTopButton.value = false;
    if (!_isHeaderExpandedState && mounted) {
      setState(() {
        _isHeaderExpandedState = true;
      });
    }

    // Call scrollToTop on the appropriate widget based on the current tab
    switch (_selectedTabIndex) {
      case 0: // Shownotes
        _shownotesKey.currentState?.scrollToTop();
        break;
      case 1: // Transcript
        _transcriptKey.currentState?.scrollToTop();
        break;
      case 2: // AI Summary
        _aiSummaryKey.currentState?.scrollToTop();
        break;
      case 3: // Conversation
        _conversationKey.currentState?.scrollToTop();
        break;
    }
  }
}
