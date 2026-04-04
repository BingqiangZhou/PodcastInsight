import 'package:dio/dio.dart';

import 'package:personal_ai_assistant/core/network/exceptions/network_exceptions.dart';
import 'package:personal_ai_assistant/core/utils/time_formatter.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_daily_report_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_playback_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_queue_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_subscription_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_transcription_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_conversation_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/schedule_config_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/profile_stats_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/playback_history_lite_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_highlight_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/services/podcast_api_service.dart';

class PodcastRepository {
  final PodcastApiService _apiService;

  PodcastRepository(this._apiService);

  static const String _dailyReportTimezone = 'Asia/Shanghai';
  static const String _dailyReportScheduleTime = '03:30';

  /// Generic wrapper that converts [DioException] to [NetworkException].
  ///
  /// Eliminates the repetitive try/catch pattern across all API methods.
  Future<T> _apiCall<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw NetworkException.fromDioError(e);
    }
  }

  // === Subscription Management ===

  Future<PodcastSubscriptionModel> addSubscription({
    required String feedUrl,
    List<int>? categoryIds,
  }) =>
      _apiCall(() => _apiService.addSubscription(
            PodcastSubscriptionCreateRequest(
              feedUrl: feedUrl,
              categoryIds: categoryIds,
            ),
          ));

  Future<PodcastSubscriptionListResponse> listSubscriptions({
    int page = 1,
    int size = 20,
    int? categoryId,
    String? status,
  }) =>
      _apiCall(() => _apiService.listSubscriptions(page, size, categoryId, status));

  Future<PodcastSubscriptionModel> getSubscription(int subscriptionId) =>
      _apiCall(() => _apiService.getSubscription(subscriptionId));

  Future<void> deleteSubscription(int subscriptionId) =>
      _apiCall(() => _apiService.deleteSubscription(subscriptionId));

  Future<PodcastSubscriptionBulkDeleteResponse> bulkDeleteSubscriptions({
    required List<int> subscriptionIds,
  }) =>
      _apiCall(() => _apiService.bulkDeleteSubscriptions(
            PodcastSubscriptionBulkDeleteRequest(
              subscriptionIds: subscriptionIds,
            ),
          ));

  Future<void> refreshSubscription(int subscriptionId) =>
      _apiCall(() => _apiService.refreshSubscription(subscriptionId));

  Future<ReparseResponse> reparseSubscription(
    int subscriptionId,
    bool forceAll,
  ) =>
      _apiCall(() => _apiService.reparseSubscription(subscriptionId, forceAll));

  // === Episode Management ===

  Future<PodcastFeedResponse> getPodcastFeed({
    required int page,
    required int pageSize,
    String? cursor,
  }) =>
      _apiCall(() => _apiService.getPodcastFeed(page, pageSize, cursor));

  Future<PodcastDailyReportResponse> getDailyReport({DateTime? date}) async {
    try {
      final dateParam = date != null ? TimeFormatter.formatDate(date) : null;
      return await _apiService.getDailyReport(dateParam);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // Backward compatibility: old backend may not provide daily report API yet.
        return const PodcastDailyReportResponse(
          available: false,
          reportDate: null,
          timezone: _dailyReportTimezone,
          scheduleTimeLocal: _dailyReportScheduleTime,
          generatedAt: null,
          totalItems: 0,
          items: [],
        );
      }
      throw NetworkException.fromDioError(e);
    }
  }

  Future<PodcastDailyReportResponse> generateDailyReport({
    DateTime? date,
    bool rebuild = false,
  }) async {
    try {
      final dateParam = date != null ? TimeFormatter.formatDate(date) : null;
      return await _apiService.generateDailyReport(dateParam, rebuild);
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 404 || statusCode == 405) {
        final fallback = await getDailyReport(date: date);
        if (fallback.available) {
          return fallback;
        }
        throw const NetworkException(
          'Daily report generation is unavailable on the current server',
        );
      }
      final wrappedError = e.error;
      if (wrappedError is AppException) {
        throw wrappedError;
      }
      throw NetworkException.fromDioError(e);
    }
  }

  Future<PodcastDailyReportDatesResponse> getDailyReportDates({
    int page = 1,
    int size = 30,
  }) async {
    try {
      return await _apiService.getDailyReportDates(page, size);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // Backward compatibility: old backend may not provide daily report API yet.
        return PodcastDailyReportDatesResponse(
          dates: const [],
          total: 0,
          page: page,
          size: size,
          pages: 0,
        );
      }
      throw NetworkException.fromDioError(e);
    }
  }

  Future<PodcastEpisodeListResponse> listEpisodes({
    int? subscriptionId,
    int page = 1,
    int size = 20,
    bool? hasSummary,
    bool? isPlayed,
  }) =>
      _apiCall(() => _apiService.listEpisodes(
            subscriptionId,
            page,
            size,
            hasSummary,
            isPlayed,
          ));

  Future<PodcastEpisodeModel> getEpisode(int episodeId) =>
      _apiCall(() => _apiService.getEpisode(episodeId));

  Future<PodcastEpisodeListResponse> getPlaybackHistory({
    int page = 1,
    int size = 50,
    String? cursor,
  }) =>
      _apiCall(() => _apiService.getPlaybackHistory(page, size, cursor));

  Future<PlaybackHistoryLiteResponse> getPlaybackHistoryLite({
    int page = 1,
    int size = 100,
  }) =>
      _apiCall(() => _apiService.getPlaybackHistoryLite(page, size));

  // === Playback Management ===

  Future<PodcastPlaybackStateResponse> updatePlaybackProgress({
    required int episodeId,
    required int position,
    required bool isPlaying,
    double playbackRate = 1.0,
  }) =>
      _apiCall(() => _apiService.updatePlaybackProgress(
            episodeId,
            PodcastPlaybackUpdateRequest(
              position: position,
              isPlaying: isPlaying,
              playbackRate: playbackRate,
            ),
          ));

  Future<PodcastPlaybackStateResponse> getPlaybackState(int episodeId) =>
      _apiCall(() => _apiService.getPlaybackState(episodeId));

  Future<PlaybackRateEffectiveResponse> getEffectivePlaybackRate({
    int? subscriptionId,
  }) =>
      _apiCall(() => _apiService.getEffectivePlaybackRate(subscriptionId));

  Future<PlaybackRateEffectiveResponse> applyPlaybackRatePreference({
    required double playbackRate,
    required bool applyToSubscription,
    int? subscriptionId,
  }) =>
      _apiCall(() => _apiService.applyPlaybackRatePreference(
            PlaybackRateApplyRequest(
              playbackRate: playbackRate,
              applyToSubscription: applyToSubscription,
              subscriptionId: subscriptionId,
            ),
          ));

  // === Queue Management ===

  Future<PodcastQueueModel> getQueue() =>
      _apiCall(() => _apiService.getQueue());

  Future<PodcastQueueModel> addQueueItem(int episodeId) =>
      _apiCall(() => _apiService.addQueueItem(
            PodcastQueueAddItemRequest(episodeId: episodeId),
          ));

  Future<PodcastQueueModel> removeQueueItem(int episodeId) =>
      _apiCall(() => _apiService.removeQueueItem(episodeId));

  Future<PodcastQueueModel> reorderQueueItems(List<int> episodeIds) =>
      _apiCall(() => _apiService.reorderQueueItems(
            PodcastQueueReorderRequest(episodeIds: episodeIds),
          ));

  Future<PodcastQueueModel> setQueueCurrent(int episodeId) =>
      _apiCall(() => _apiService.setQueueCurrent(
            PodcastQueueSetCurrentRequest(episodeId: episodeId),
          ));

  Future<PodcastQueueModel> activateQueueEpisode(int episodeId) =>
      _apiCall(() => _apiService.activateQueueEpisode(
            PodcastQueueActivateRequest(episodeId: episodeId),
          ));

  Future<PodcastQueueModel> completeQueueCurrent() =>
      _apiCall(() => _apiService.completeQueueCurrent(const {}));

  // === Summary Management ===

  Future<PodcastSummaryStartResponse> generateSummary({
    required int episodeId,
    bool forceRegenerate = false,
    bool? useTranscript,
    String? summaryModel,
    String? customPrompt,
  }) =>
      _apiCall(() => _apiService.generateSummary(
            episodeId,
            PodcastSummaryRequest(
              forceRegenerate: forceRegenerate,
              useTranscript: useTranscript,
              summaryModel: summaryModel,
              customPrompt: customPrompt,
            ),
          ));

  Future<List<SummaryModelInfo>> getSummaryModels() =>
      _apiCall(() async => (await _apiService.getSummaryModels()).models);

  Future<void> getPendingSummaries() =>
      _apiCall(() => _apiService.getPendingSummaries());

  // === Search ===

  Future<PodcastEpisodeListResponse> searchPodcasts({
    required String query,
    String searchIn = 'all',
    int page = 1,
    int size = 20,
  }) =>
      _apiCall(() => _apiService.searchPodcasts(query, searchIn, page, size));

  // === Statistics ===

  Future<PodcastStatsResponse> getStats() =>
      _apiCall(() => _apiService.getStats());

  Future<ProfileStatsModel> getProfileStats() =>
      _apiCall(() => _apiService.getProfileStats());

  // === Transcription Management ===

  Future<PodcastTranscriptionResponse?> getTranscription(int episodeId) async {
    try {
      return await _apiService.getTranscription(episodeId);
    } on DioException catch (e) {
      // If transcription not found (404), return null instead of throwing
      if (e.response?.statusCode == 404) {
        return null;
      }
      throw NetworkException.fromDioError(e);
    }
  }

  Future<PodcastTranscriptionResponse> startTranscription(
    int episodeId, {
    bool forceRegenerate = false,
    int? chunkSizeMb,
    String? transcriptionModel,
  }) =>
      _apiCall(() => _apiService.startTranscription(
            episodeId,
            PodcastTranscriptionRequest(
              forceRegenerate: forceRegenerate,
              chunkSizeMb: chunkSizeMb,
              transcriptionModel: transcriptionModel,
            ),
          ));

  Future<void> deleteTranscription(int episodeId) =>
      _apiCall(() => _apiService.deleteTranscription(episodeId));

  // === Conversation Management ===

  Future<ConversationSessionListResponse> getConversationSessions({
    required int episodeId,
  }) =>
      _apiCall(() => _apiService.getConversationSessions(episodeId));

  Future<ConversationSession> createConversationSession({
    required int episodeId,
    String? title,
  }) =>
      _apiCall(() => _apiService.createConversationSession(episodeId, {
            'title': title,
          }));

  Future<PodcastConversationClearResponse> deleteConversationSession({
    required int episodeId,
    required int sessionId,
  }) =>
      _apiCall(() => _apiService.deleteConversationSession(episodeId, sessionId));

  Future<PodcastConversationHistoryResponse> getConversationHistory({
    required int episodeId,
    int limit = 50,
    int? sessionId,
  }) =>
      _apiCall(() => _apiService.getConversationHistory(episodeId, limit, sessionId));

  Future<PodcastConversationSendResponse> sendConversationMessage({
    required int episodeId,
    required PodcastConversationSendRequest request,
  }) =>
      _apiCall(() => _apiService.sendConversationMessage(episodeId, request));

  Future<PodcastConversationClearResponse> clearConversationHistory({
    required int episodeId,
    int? sessionId,
  }) =>
      _apiCall(() => _apiService.clearConversationHistory(episodeId, sessionId));

  // === Schedule Management ===

  Future<ScheduleConfigResponse> getSubscriptionSchedule(
    int subscriptionId,
  ) =>
      _apiCall(() => _apiService.getSubscriptionSchedule(subscriptionId));

  Future<ScheduleConfigResponse> updateSubscriptionSchedule(
    int subscriptionId,
    ScheduleConfigUpdateRequest request,
  ) =>
      _apiCall(() => _apiService.updateSubscriptionSchedule(subscriptionId, request));

  /// Get all subscription schedules
  Future<List<ScheduleConfigResponse>> getAllSubscriptionSchedules() =>
      _apiCall(() => _apiService.getAllSubscriptionSchedules());

  /// Batch update subscription schedules
  Future<List<ScheduleConfigResponse>> batchUpdateSubscriptionSchedules(
    List<int> subscriptionIds,
    ScheduleConfigUpdateRequest request,
  ) =>
      _apiCall(() => _apiService.batchUpdateSubscriptionSchedules({
            'subscription_ids': subscriptionIds,
            'schedule_data': request.toJson(),
          }));

  // === Highlights Management ===

  Future<HighlightsListResponse> getHighlights({
    DateTime? date,
    int page = 1,
    int perPage = 20,
    int? episodeId,
  }) =>
      _apiCall(() => _apiService.getHighlights(
            date != null ? TimeFormatter.formatDate(date) : null,
            page,
            perPage,
            episodeId,
          ));

  Future<HighlightDatesResponse> getHighlightDates() =>
      _apiCall(() => _apiService.getHighlightDates());

  Future<HighlightStatsResponse> getHighlightStats() =>
      _apiCall(() => _apiService.getHighlightStats());

  Future<void> toggleHighlightFavorite(int highlightId) =>
      _apiCall(() => _apiService.toggleHighlightFavorite(highlightId));

  Future<void> deleteHighlight(int highlightId) =>
      _apiCall(() => _apiService.deleteHighlight(highlightId));

  Future<HighlightExtractResponse> extractEpisodeHighlights(int episodeId) =>
      _apiCall(() => _apiService.extractEpisodeHighlights(episodeId));
}
