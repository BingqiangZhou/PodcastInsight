import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_ai_assistant/core/database/app_database.dart';
import 'package:personal_ai_assistant/core/constants/app_durations.dart';
import 'package:personal_ai_assistant/core/constants/app_radius.dart';
import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:personal_ai_assistant/core/constants/breakpoints.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_en.dart';
import 'package:personal_ai_assistant/core/platform/adaptive_app_bar.dart';
import 'package:personal_ai_assistant/core/platform/adaptive_haptic.dart';
import 'package:personal_ai_assistant/core/services/adaptive_share.dart';
import 'package:personal_ai_assistant/core/services/download_provider.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/core/utils/app_logger.dart' as logger;
import 'package:personal_ai_assistant/core/utils/time_formatter.dart';
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive_segmented_control.dart';
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive.dart';
import 'package:personal_ai_assistant/core/widgets/app_shells.dart';
import 'package:personal_ai_assistant/core/widgets/top_floating_notice.dart';
import 'package:personal_ai_assistant/features/podcast/core/utils/html_sanitizer.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/audio_player_state_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_transcription_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_episodes_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_highlights_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_playback_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/conversation_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/ai_summary_control_widget.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/conversation_chat_widget.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/podcast_image_widget.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/scrollable_content_wrapper.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/shared/episode_card_utils.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/shownotes_display_widget.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/summary_display_widget.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/transcript_display_widget.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/transcription_status_widget.dart';
import 'package:personal_ai_assistant/shared/widgets/loading_widget.dart';
import 'package:url_launcher/url_launcher.dart';

part 'podcast_episode_detail_page_content.dart';
part 'podcast_episode_detail_page_header.dart';
part 'podcast_episode_detail_page_layout.dart';
part 'podcast_episode_detail_page_tabs.dart';

class PodcastEpisodeDetailPage extends ConsumerStatefulWidget {

  const PodcastEpisodeDetailPage({required this.episodeId, super.key});
  final int episodeId;

  @override
  ConsumerState<PodcastEpisodeDetailPage> createState() =>
      _PodcastEpisodeDetailPageState();
}

class _PodcastEpisodeDetailPageState
    extends ConsumerState<PodcastEpisodeDetailPage> {
  static const double _wideLayoutBreakpoint = Breakpoints.wideLayout;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedTabIndex = 0; // 0 = Shownotes, 1 = Transcript, 2 = Summary
  ProviderSubscription<AsyncValue<PodcastTranscriptionResponse?>>?
  _transcriptionNoticeSubscription;
  bool _hasTrackedEpisodeView = false;
  bool _isAddingToQueue = false;
  String _selectedSummaryText = '';
  bool _summaryUpdateScheduled = false;

  // Sticky header animation
  final PageController _pageController = PageController();
  final ValueNotifier<double> _scrollOffset = ValueNotifier(0);
  final ValueNotifier<bool> _showScrollToTopButton = ValueNotifier(false);
  final ValueNotifier<bool> _isHeaderExpandedNotifier = ValueNotifier(true);
  int _episodeUpdateVersion = 0;
  static const double _headerScrollThreshold =
      50; // Header starts fading after 50px scroll
  static const double _autoCollapseScrollDeltaThreshold = 6;
  static const double _scrollToTopFixedLift = 56;
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

  void _updateHeaderStateForTab() {
    _showScrollToTopButton.value = false;
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

  void _trackEpisodeViewOnce(PodcastEpisodeModel episodeDetail) {
    if (_hasTrackedEpisodeView) {
      return;
    }
    _hasTrackedEpisodeView = true;
    unawaited(_trackEpisodeView(episodeDetail));
  }

  Future<void> _trackEpisodeView(
    PodcastEpisodeModel episodeDetail,
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
          appBar: adaptiveAppBar(
            context,
            titleWidget: Text(episodeDetail?.title ?? ''),
            actions: [
              if (episodeDetail != null)
                IconButton(
                  icon: const Icon(Icons.auto_awesome_outlined),
                  tooltip: (AppLocalizations.of(context) ?? AppLocalizationsEn()).podcast_tab_chat,
                  onPressed: _openChatDrawer,
                ),
            ],
          ),
          endDrawerEnableOpenDragGesture: false,
          endDrawer: episodeDetail == null
              ? null
              : _buildChatDrawer(episodeDetail),
          body: episodeDetailAsync.when(
            data: (episodeDetail) {
              if (episodeDetail == null) {
                final l10n =
                    AppLocalizations.of(context) ?? AppLocalizationsEn();
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
        '[Playback] Reloading episode data for new episode (no auto-play)',
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
      _selectedSummaryText = '';
      _summaryUpdateScheduled = false;

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
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: AppRadius.lgXlRadius,
        ),
        child: AdaptiveInkWell(
          onTap: _scrollToTop,
          child: SizedBox(
            width: 32,
            height: 32,
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
      case 1: // Transcript
        _transcriptKey.currentState?.scrollToTop();
      case 2: // Summary
        _summaryKey.currentState?.scrollToTop();
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
