import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:personal_ai_assistant/core/constants/breakpoints.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_en.dart';
import 'package:personal_ai_assistant/core/widgets/app_shells.dart';
import 'package:personal_ai_assistant/core/widgets/top_floating_notice.dart';
import 'package:personal_ai_assistant/shared/widgets/loading_widget.dart';

import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/transcription_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/summary_providers.dart';
import 'package:personal_ai_assistant/core/services/download_provider.dart';
import 'package:personal_ai_assistant/features/podcast/core/utils/html_sanitizer.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/audio_player_state_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_transcription_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/transcript_display_widget.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/shownotes_display_widget.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/transcription_status_widget.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/ai_summary_control_widget.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/summary_display_widget.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/conversation_chat_widget.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/podcast_image_widget.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/scrollable_content_wrapper.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/services/content_image_share_service.dart';
import 'package:personal_ai_assistant/core/utils/app_logger.dart' as logger;
import 'package:personal_ai_assistant/core/utils/time_formatter.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/shared/episode_card_utils.dart';

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
  static const double _wideLayoutBreakpoint = 1040.0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedTabIndex = 0; // 0 = Shownotes, 1 = Transcript, 2 = Summary
  ProviderSubscription<AsyncValue<PodcastTranscriptionResponse?>>?
  _transcriptionNoticeSubscription;
  bool _hasTrackedEpisodeView = false;
  bool _isAddingToQueue = false;
  String _selectedSummaryText = '';

  // Sticky header animation
  final PageController _pageController = PageController();
  final ValueNotifier<double> _scrollOffset = ValueNotifier(0.0);
  final ValueNotifier<bool> _showScrollToTopButton = ValueNotifier(false);
  final ValueNotifier<bool> _isHeaderExpandedNotifier = ValueNotifier(true);
  int _episodeUpdateVersion = 0;
  static const double _headerScrollThreshold =
      50.0; // Header starts fading after 50px scroll
  static const double _autoCollapseScrollDeltaThreshold = 6.0;
  static const double _scrollToTopFixedLift = 56.0;
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
    _isHeaderExpandedNotifier.dispose();
    super.dispose();
  }

  void _bindTranscriptionNoticeListener() {
    _transcriptionNoticeSubscription?.close();
    _transcriptionNoticeSubscription = ref
        .listenManual<AsyncValue<PodcastTranscriptionResponse?>>(
          transcriptionProvider(widget.episodeId),
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

  void _updateHeaderStateForTab(int tabIndex) {
    _showScrollToTopButton.value = false;
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
      // Automatically check/start transcription if missing
      await ref
          .read(transcriptionProvider(widget.episodeId).notifier)
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

    if (MediaQuery.sizeOf(context).width >= Breakpoints.medium) {
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
    if (_isHeaderExpandedNotifier.value != isExpanded) {
      _isHeaderExpandedNotifier.value = isExpanded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final episodeDetailAsync = ref.watch(
      episodeDetailProvider(widget.episodeId),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final episodeDetail = episodeDetailAsync.asData?.value;
        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: Colors.transparent,
          endDrawerEnableOpenDragGesture: false,
          endDrawer: episodeDetail == null
              ? null
              : _buildChatDrawer(episodeDetail),
          body: episodeDetailAsync.when(
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
        );
      },
    );
  }

  @override
  void didUpdateWidget(PodcastEpisodeDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Check if episodeId has changed
    if (oldWidget.episodeId != widget.episodeId) {
      _episodeUpdateVersion++;
      final currentVersion = _episodeUpdateVersion;

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
      // No manual provider release needed - family.autoDispose handles cleanup

      // Reload data for the new episode
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Check version and mounted state to prevent race conditions
        if (!mounted || _episodeUpdateVersion != currentVersion) {
          logger.AppLogger.debug(
            '[Playback] Skipping post-frame callback (version mismatch or unmounted)',
          );
          return;
        }
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
    final screenSize = MediaQuery.sizeOf(context);
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
    _isHeaderExpandedNotifier.value = true;

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

}
