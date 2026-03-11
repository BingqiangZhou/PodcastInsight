import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/app_localizations_en.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/app_shells.dart';
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
    extends ConsumerState<PodcastEpisodeDetailPage>
    with RouteAware {
  static const double _wideLayoutBreakpoint = 1040.0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedTabIndex = 0; // 0 = Shownotes, 1 = Transcript, 2 = Summary
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
  int _headerAnimationVersion = 0;
  ModalRoute<dynamic>? _subscribedRoute;
  static const double _headerScrollThreshold =
      50.0; // Header starts fading after 50px scroll
  static const double _autoCollapseScrollDeltaThreshold = 6.0;
  static const double _scrollToTopFixedLift = 72.0;
  List<ShownotesAnchor> _shownotesAnchors = const <ShownotesAnchor>[];

  // GlobalKeys for accessing child widget states to call scrollToTop
  final GlobalKey<ShownotesDisplayWidgetState> _shownotesKey =
      GlobalKey<ShownotesDisplayWidgetState>();
  final GlobalKey<TranscriptDisplayWidgetState> _transcriptKey =
      GlobalKey<TranscriptDisplayWidgetState>();
  final GlobalKey<ScrollableContentWrapperState> _summaryKey =
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (_subscribedRoute == route) {
      return;
    }

    appRouteObserver.unsubscribe(this);
    _subscribedRoute = route;
    if (route != null) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _playerHostOverrideNotifier.clearOverrideIfMatches(_lastPlayerHostOverride);
    _transcriptionNoticeSubscription?.close();
    _pageController.dispose();
    _scrollOffset.dispose();
    _showScrollToTopButton.dispose();
    super.dispose();
  }

  @override
  void didPushNext() {
    _playerHostOverrideNotifier.clearOverrideIfMatches(_lastPlayerHostOverride);
  }

  @override
  void didPopNext() {
    _lastPlayerHostOverride = null;
    if (mounted) {
      setState(() {});
    }
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

  bool get _isHeaderExpanded {
    return _scrollOffset.value < _headerScrollThreshold;
  }

  bool _shouldHideBottomPlayer({
    required bool isPlayerExpanded,
    required bool hasCurrentEpisode,
  }) {
    return false;
  }

  void _updateHeaderStateForTab(int tabIndex) {
    _showScrollToTopButton.value = false;
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

    if (MediaQuery.sizeOf(context).width >= 600) {
      return;
    }

    final playerUi = ref.read(podcastPlayerUiProvider);
    if (!playerUi.isExpanded) {
      return;
    }

    ref.read(podcastPlayerUiProvider.notifier).collapse();
  }

  void _recordScrollMetrics(ScrollMetrics metrics) {
    if (metrics.axis != Axis.vertical) {
      return;
    }
    final scrollPosition = metrics.pixels;
    if (_scrollOffset.value != scrollPosition) {
      _scrollOffset.value = scrollPosition;
    }
    final shouldShowScrollToTop = scrollPosition > 0;
    if (_showScrollToTopButton.value != shouldShowScrollToTop) {
      _showScrollToTopButton.value = shouldShowScrollToTop;
    }

    final isExpanded = scrollPosition < _headerScrollThreshold;
    if (isExpanded != _isHeaderExpandedState && mounted) {
      setState(() {
        _isHeaderExpandedState = isExpanded;
        _headerAnimationVersion++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final episodeDetailAsync = ref.watch(
      episodeDetailProvider(widget.episodeId),
    );
    final isExpanded = ref.watch(podcastPlayerExpandedProvider);
    final hasCurrentEpisode = ref.watch(
      audioCurrentEpisodeIdProvider.select((episodeId) => episodeId != null),
    );
    final hostLayout = ref.watch(podcastPlayerHostLayoutProvider);
    final hideBottomPlayer = _shouldHideBottomPlayer(
      isPlayerExpanded: isExpanded,
      hasCurrentEpisode: hasCurrentEpisode,
    );
    final playerBottomInset = hasCurrentEpisode && !hideBottomPlayer
        ? resolvePodcastPlayerTotalReservedSpace(context, hostLayout)
        : 0.0;

    _syncPlayerHostOverride(
      PodcastPlayerHostPageOverride(
        routeOwner: PodcastPlayerHostRouteOwner.episodeDetail,
        surfaceContext: PodcastPlayerSurfaceContext.episodeDetail,
        hiddenByPage: hideBottomPlayer,
        contentBottomInset: 54,
        overlayBottomOffset: MediaQuery.sizeOf(context).width >= 600
            ? 10
            : MediaQuery.viewPaddingOf(context).bottom + 8,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: Colors.transparent,
          endDrawerEnableOpenDragGesture: false,
          endDrawer: episodeDetailAsync.asData?.value == null
              ? null
              : _buildChatDrawer(episodeDetailAsync.asData!.value!),
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
              loading: () => _buildPageLoadingState(context),
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
      _shownotesAnchors = const <ShownotesAnchor>[];

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
      case 2: // Summary
        _summaryKey.currentState?.scrollToTop();
        break;
    }
  }

  void _openChatDrawer() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  void _updateShownotesAnchors(List<ShownotesAnchor> anchors) {
    if (listEquals(_shownotesAnchors, anchors)) {
      return;
    }
    if (!mounted) {
      _shownotesAnchors = anchors;
      return;
    }
    setState(() {
      _shownotesAnchors = anchors;
    });
  }

  Future<void> _jumpToShownotesAnchor(ShownotesAnchor anchor) async {
    if (_selectedTabIndex != 0) {
      if (MediaQuery.sizeOf(context).width < _wideLayoutBreakpoint) {
        await _pageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOutCubic,
        );
      }
      if (mounted) {
        setState(() {
          _selectedTabIndex = 0;
        });
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _shownotesKey.currentState?.scrollToAnchor(anchor.id);
    });
  }
}
