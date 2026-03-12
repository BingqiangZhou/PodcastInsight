import 'package:dio/dio.dart';

import '../../../../core/network/exceptions/network_exceptions.dart';
import '../models/podcast_episode_model.dart';
import '../models/podcast_daily_report_model.dart';
import '../models/podcast_playback_model.dart';
import '../models/podcast_queue_model.dart';
import '../models/podcast_subscription_model.dart';
import '../models/podcast_transcription_model.dart';
import '../models/podcast_conversation_model.dart';
import '../models/schedule_config_model.dart';
import '../models/profile_stats_model.dart';
import '../models/playback_history_lite_model.dart';
import '../services/podcast_api_service.dart';

class PodcastRepository {
  final PodcastApiService _apiService;

  PodcastRepository(this._apiService);

  static const String _dailyReportTimezone = 'Asia/Shanghai';
  static const String _dailyReportScheduleTime = '03:30';

  String? _formatDateParam(DateTime? date) {
    if (date == null) {
      return null;
    }
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // === Subscription Management ===

  Future<PodcastSubscriptionModel> addSubscription({
    required String feedUrl,
    List<int>? categoryIds,
  }) async {
    try {
      final request = PodcastSubscriptionCreateRequest(
        feedUrl: feedUrl,
        categoryIds: categoryIds,
      );
      return await _apiService.addSubscription(request);
    } on DioException catch (e) {
      throw NetworkException.fromDioError(e);
    }
  }

  Future<void> addSubscriptionsBatch({
    required List<String> feedUrls,
    List<int>? categoryIds,
  }) async {
    try {
      final requests = feedUrls
          .map(
            (url) => PodcastSubscriptionCreateRequest(
              feedUrl: url,
              categoryIds: categoryIds,
            ),
          )
          .toList();
      await _apiService.addSubscriptionsBatch(requests);
    } on DioException catch (e) {
      throw NetworkException.fromDioError(e);
    }
  }

  Future<PodcastSubscriptionListResponse> listSubscriptions({
    int page = 1,
    int size = 20,
    int? categoryId,
    String? status,
  }) async {
    try {
      return await _apiService.listSubscriptions(
        page,
        size,
        categoryId,
        status,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDioError(e);
    }
  }

  Future<PodcastSubscriptionModel> getSubscription(int subscriptionId) async {
    try {
      return await _apiService.getSubscription(subscriptionId);
    } on DioException catch (e) {
      throw NetworkException.fromDioError(e);
    }
  }

  Future<void> deleteSubscription(int subscriptionId) async {
    try {
      await _apiService.deleteSubscription(subscriptionId);
    } on DioException catch (e) {
      throw NetworkException.fromDioError(e);
    }
  }

  Future<PodcastSubscriptionBulkDeleteResponse> bulkDeleteSubscriptions({
    required List<int> subscriptionIds,
  }) async {
    try {
      final request = PodcastSubscriptionBulkDeleteRequest(
        subscriptionIds: subscriptionIds,
      );
      return await _apiService.bulkDeleteSubscriptions(request);
    } on DioException catch (e) {
      throw NetworkException.fromDioError(e);
    }
  }

  Future<void> refreshSubscription(int subscriptionId) async {
    try {
      await _apiService.refreshSubscription(subscriptionId);
    } on DioException catch (e) {
      throw NetworkException.fromDioError(e);
    }
  }

  Future<ReparseResponse> reparseSubscription(
    int subscriptionId,
    bool forceAll,
  ) async {
    try {
      return await _apiService.reparseSubscription(subscriptionId, forceAll);
    } on DioException catch (e) {
      throw NetworkException.fromDioError(e);
    }
  }

  // === Episode Management ===

  Future<PodcastFeedResponse> getPodcastFeed({
    required int page,
    required int pageSize,
    String? cursor,
  }) async {
    try {
      return await _apiService.getPodcastFeed(page, pageSize, cursor);
    } on DioException catch (e) {
      throw NetworkException.fromDioError(e);
    }
  }

  Future<PodcastDailyReportResponse> getDailyReport({DateTime? date}) async {
    try {
      final dateParam = _formatDateParam(date);
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
      final dateParam = _formatDateParam(date);
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
  }) async {
    try {
      return await _apiService.listEpisodes(
        subscriptionId,
        page,
        size,
        hasSummary,
        isPlayed,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDioError(e);
    }
  }

  Future<PodcastEpisodeDetailResponse> getEpisode(int episodeId) async {
    try {
      return await _apiService.getEpisode(episodeId);
    } on DioException catch (e) {
      throw NetworkException.fromDioError(e);
    }
  }

  Future<PodcastEpisodeListResponse> getPlaybackHistory({
    int page = 1,
    int size = 50,
    String? cursor,
  }) async {
    try {
      return await _apiService.getPlaybackHistory(page, size, cursor);
    } on DioException catch (e) {
      throw NetworkException.fromDioError(e);
    }
  }

  Future<PlaybackHistoryLiteResponse> getPlaybackHistoryLite({
    int page = 1,
    int size = 100,
  }) async {
    try {
      return await _apiService.getPlaybackHistoryLite(page, size);
    } on DioException catch (e) {
      throw NetworkException.fromDioError(e);
    }
  }

  // === Playback Management ===

  Future<PodcastPlaybackStateResponse> updatePlaybackProgress({
    required int episodeId,
    required int position,
    required bool isPlaying,
    double playbackRate = 1.0,
  }) async {
    try {
      final request = PodcastPlaybackUpdateRequest(
        position: position,
        isPlaying: isPlaying,
        playbackRate: playbackRate,
      );
      return await _apiService.updatePlaybackProgress(episodeId, request);
    } on DioException catch (e) {
      throw NetworkException.fromDioError(e);
    }
  }

  Future<PodcastPlaybackStateResponse> getPlaybackState(int episodeId) async {
    try {
      return await _apiService.getPlaybackState(episodeId);
    } on DioException catch (e) {
      throw NetworkException.fromDioError(e);
    }
  }

  Future<PlaybackRateEffectiveResponse> getEffectivePlaybackRate({
    int? subscriptionId,
  }) async {
    try {
      return await _apiService.getEffectivePlaybackRate(subscriptionId);
    } on DioException catch (e) {
      throw NetworkException.fromDioError(e);
    }
  }

  Future<PlaybackRateEffectiveResponse> applyPlaybackRatePreference({
    required double playbackRate,
    required bool applyToSubscription,
    int? subscriptionId,
  }) async {
    try {
      final request = PlaybackRateApplyRequest(
        playbackRate: playbackRate,
        applyToSubscription: applyToSubscription,
        subscriptionId: subscriptionId,
      );
      return await _apiService.applyPlaybackRatePreference(request);
    } on DioException catch (e) {
      throw NetworkException.fromDioError(e);
    }
  }

  // === Queue Management ===

  Future<PodcastQueueModel> getQueue() async {
    try {
      return await _apiService.getQueue();
    } on DioException catch (e) {
      throw NetworkException.fromDioError(e);
    }
  }

  Future<PodcastQueueModel> addQueueItem(int episodeId) async {
    try {
      return await _apiService.addQueueItem(
        PodcastQueueAddItemRequest(episodeId: episodeId),
      );
    } on DioException catch (e) {
      throw NetworkException.fromDioError(e);
    }
  }

  Future<PodcastQueueModel> removeQueueItem(int episodeId) async {
    try {
      return await _apiService.removeQueueItem(episodeId);
    } on DioException catch (e) {
      throw NetworkException.fromDioError(e);
    }
  }

  Future<PodcastQueueModel> reorderQueueItems(List<int> episodeIds) async {
    try {
      return await _apiService.reorderQueueItems(
        PodcastQueueReorderRequest(episodeIds: episodeIds),
      );
    } on DioException catch (e) {
      throw NetworkException.fromDioError(e);
    }
  }

  Future<PodcastQueueModel> setQueueCurrent(int episodeId) async {
    try {
      return await _apiService.setQueueCurrent(
        PodcastQueueSetCurrentRequest(episodeId: episodeId),
      );
    } on DioException catch (e) {
      throw NetworkException.fromDioError(e);
    }
  }

  Future<PodcastQueueModel> activateQueueEpisode(int episodeId) async {
    try {
      return await _apiService.activateQueueEpisode(
        PodcastQueueActivateRequest(episodeId: episodeId),
      );
    } on DioException catch (e) {
      throw NetworkException.fromDioError(e);
    }
  }

  Future<PodcastQueueModel> completeQueueCurrent() async {
    try {
      return await _apiService.completeQueueCurrent(const {});
    } on DioException catch (e) {
      throw NetworkException.fromDioError(e);
    }
  }

  // === Summary Management ===

  Future<PodcastSummaryStartResponse> generateSummary({
    required int episodeId,
    bool forceRegenerate = false,
    bool? useTranscript,
    String? summaryModel,
    String? customPrompt,
  }) async {
    try {
      final request = PodcastSummaryRequest(
        forceRegenerate: forceRegenerate,
        useTranscript: useTranscript,
        summaryModel: summaryModel,
        customPrompt: customPrompt,
      );
      return await _apiService.generateSummary(episodeId, request);
    } on DioException catch (e) {
      throw NetworkException.fromDioError(e);
    }
  }

  Future<List<SummaryModelInfo>> getSummaryModels() async {
    try {
      final response = await _apiService.getSummaryModels();
      return response.models;
    } on DioException catch (e) {
      throw NetworkException.fromDioError(e);
    }
  }

  Future<void> getPendingSummaries() async {
    try {
      await _apiService.getPendingSummaries();
    } on DioException catch (e) {
      throw NetworkException.fromDioError(e);
    }
  }

  // === Search ===

  Future<PodcastEpisodeListResponse> searchPodcasts({
    required String query,
    String searchIn = 'all',
    int page = 1,
    int size = 20,
  }) async {
    try {
      return await _apiService.searchPodcasts(query, searchIn, page, size);
    } on DioException catch (e) {
      throw NetworkException.fromDioError(e);
    }
  }

  // === Statistics ===

  Future<PodcastStatsResponse> getStats() async {
    try {
      return await _apiService.getStats();
    } on DioException catch (e) {
      throw NetworkException.fromDioError(e);
    }
  }

  Future<ProfileStatsModel> getProfileStats() async {
    try {
      return await _apiService.getProfileStats();
    } on DioException catch (e) {
      throw NetworkException.fromDioError(e);
    }
  }

  // === Recommendations ===

  Future<void> getRecommendations({int limit = 10}) async {
    try {
      await _apiService.getRecommendations(limit);
    } on DioException catch (e) {
      throw NetworkException.fromDioError(e);
    }
  }

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
  }) async {
    try {
      final request = PodcastTranscriptionRequest(
        forceRegenerate: forceRegenerate,
        chunkSizeMb: chunkSizeMb,
        transcriptionModel: transcriptionModel,
      );
      return await _apiService.startTranscription(episodeId, request);
    } on DioException catch (e) {
      throw NetworkException.fromDioError(e);
    }
  }

  Future<void> deleteTranscription(int episodeId) async {
    try {
      await _apiService.deleteTranscription(episodeId);
    } on DioException catch (e) {
      throw NetworkException.fromDioError(e);
    }
  }

  // === Conversation Management ===

  Future<ConversationSessionListResponse> getConversationSessions({
    required int episodeId,
  }) async {
    try {
      return await _apiService.getConversationSessions(episodeId);
    } on DioException catch (e) {
      throw NetworkException.fromDioError(e);
    }
  }

  Future<ConversationSession> createConversationSession({
    required int episodeId,
    String? title,
  }) async {
    try {
      return await _apiService.createConversationSession(episodeId, {
        'title': title,
      });
    } on DioException catch (e) {
      throw NetworkException.fromDioError(e);
    }
  }

  Future<PodcastConversationClearResponse> deleteConversationSession({
    required int episodeId,
    required int sessionId,
  }) async {
    try {
      return await _apiService.deleteConversationSession(episodeId, sessionId);
    } on DioException catch (e) {
      throw NetworkException.fromDioError(e);
    }
  }

  Future<PodcastConversationHistoryResponse> getConversationHistory({
    required int episodeId,
    int limit = 50,
    int? sessionId,
  }) async {
    try {
      return await _apiService.getConversationHistory(
        episodeId,
        limit,
        sessionId,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDioError(e);
    }
  }

  Future<PodcastConversationSendResponse> sendConversationMessage({
    required int episodeId,
    required PodcastConversationSendRequest request,
  }) async {
    try {
      return await _apiService.sendConversationMessage(episodeId, request);
    } on DioException catch (e) {
      throw NetworkException.fromDioError(e);
    }
  }

  Future<PodcastConversationClearResponse> clearConversationHistory({
    required int episodeId,
    int? sessionId,
  }) async {
    try {
      return await _apiService.clearConversationHistory(episodeId, sessionId);
    } on DioException catch (e) {
      throw NetworkException.fromDioError(e);
    }
  }

  // === Schedule Management ===

  Future<ScheduleConfigResponse> getSubscriptionSchedule(
    int subscriptionId,
  ) async {
    try {
      return await _apiService.getSubscriptionSchedule(subscriptionId);
    } on DioException catch (e) {
      throw NetworkException.fromDioError(e);
    }
  }

  Future<ScheduleConfigResponse> updateSubscriptionSchedule(
    int subscriptionId,
    ScheduleConfigUpdateRequest request,
  ) async {
    try {
      return await _apiService.updateSubscriptionSchedule(
        subscriptionId,
        request,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDioError(e);
    }
  }

  /// Get all subscription schedules
  Future<List<ScheduleConfigResponse>> getAllSubscriptionSchedules() async {
    try {
      return await _apiService.getAllSubscriptionSchedules();
    } on DioException catch (e) {
      throw NetworkException.fromDioError(e);
    }
  }

  /// Batch update subscription schedules
  Future<List<ScheduleConfigResponse>> batchUpdateSubscriptionSchedules(
    List<int> subscriptionIds,
    ScheduleConfigUpdateRequest request,
  ) async {
    try {
      return await _apiService.batchUpdateSubscriptionSchedules({
        'subscription_ids': subscriptionIds,
        'schedule_data': request.toJson(),
      });
    } on DioException catch (e) {
      throw NetworkException.fromDioError(e);
    }
  }
}
