import 'package:dio/dio.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/playback_history_lite_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_conversation_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_daily_report_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_highlight_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_playback_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_queue_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_subscription_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_transcription_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/profile_stats_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/schedule_config_model.dart';
import 'package:retrofit/retrofit.dart';

part 'podcast_api_service.g.dart';

@RestApi()
abstract class PodcastApiService {
  factory PodcastApiService(Dio dio, {String baseUrl}) = _PodcastApiService;

  // === Subscription Management ===

  @POST('/podcasts/subscriptions')
  Future<PodcastSubscriptionModel> addSubscription(
    @Body() PodcastSubscriptionCreateRequest request,
  );

  @GET('/podcasts/subscriptions')
  Future<PodcastSubscriptionListResponse> listSubscriptions(
    @Query('page') int page,
    @Query('size') int size,
    @Query('category_id') int? categoryId,
    @Query('status') String? status,
  );

  @GET('/podcasts/subscriptions/{subscriptionId}')
  Future<PodcastSubscriptionModel> getSubscription(
    @Path('subscriptionId') int subscriptionId,
  );

  @DELETE('/podcasts/subscriptions/{subscriptionId}')
  Future<void> deleteSubscription(@Path('subscriptionId') int subscriptionId);

  @POST('/podcasts/subscriptions/bulk-delete')
  Future<PodcastSubscriptionBulkDeleteResponse> bulkDeleteSubscriptions(
    @Body() PodcastSubscriptionBulkDeleteRequest request,
  );

  @POST('/podcasts/subscriptions/{subscriptionId}/refresh')
  Future<void> refreshSubscription(@Path('subscriptionId') int subscriptionId);

  @POST('/podcasts/subscriptions/{subscriptionId}/reparse')
  Future<ReparseResponse> reparseSubscription(
    @Path('subscriptionId') int subscriptionId,
    @Query('force_all') bool forceAll,
  );

  @GET('/podcasts/subscriptions/{subscriptionId}/schedule')
  Future<ScheduleConfigResponse> getSubscriptionSchedule(
    @Path('subscriptionId') int subscriptionId,
  );

  @PATCH('/podcasts/subscriptions/{subscriptionId}/schedule')
  Future<ScheduleConfigResponse> updateSubscriptionSchedule(
    @Path('subscriptionId') int subscriptionId,
    @Body() ScheduleConfigUpdateRequest request,
  );

  // === Episode Management ===

  @GET('/podcasts/episodes/feed')
  Future<PodcastFeedResponse> getPodcastFeed(
    @Query('page') int page,
    @Query('page_size') int pageSize,
    @Query('cursor') String? cursor,
  );

  @GET('/podcasts/reports/daily')
  Future<PodcastDailyReportResponse> getDailyReport(
    @Query('date') String? date,
  );

  @POST('/podcasts/reports/daily/generate')
  Future<PodcastDailyReportResponse> generateDailyReport(
    @Query('date') String? date,
    @Query('rebuild') bool rebuild,
  );

  @GET('/podcasts/reports/daily/dates')
  Future<PodcastDailyReportDatesResponse> getDailyReportDates(
    @Query('page') int page,
    @Query('size') int size,
  );

  @GET('/podcasts/episodes')
  Future<PodcastEpisodeListResponse> listEpisodes(
    @Query('subscription_id') int? subscriptionId,
    @Query('page') int page,
    @Query('size') int size,
    @Query('has_summary') bool? hasSummary,
    @Query('is_played') bool? isPlayed,
  );

  @GET('/podcasts/episodes/history')
  Future<PodcastEpisodeListResponse> getPlaybackHistory(
    @Query('page') int page,
    @Query('size') int size,
    @Query('cursor') String? cursor,
  );

  @GET('/podcasts/episodes/history-lite')
  Future<PlaybackHistoryLiteResponse> getPlaybackHistoryLite(
    @Query('page') int page,
    @Query('size') int size,
  );

  @GET('/podcasts/episodes/{episodeId}')
  Future<PodcastEpisodeModel> getEpisode(
    @Path('episodeId') int episodeId,
  );

  // === Playback Management ===

  @PUT('/podcasts/episodes/{episodeId}/playback')
  Future<PodcastPlaybackStateResponse> updatePlaybackProgress(
    @Path('episodeId') int episodeId,
    @Body() PodcastPlaybackUpdateRequest request,
  );

  @GET('/podcasts/episodes/{episodeId}/playback')
  Future<PodcastPlaybackStateResponse> getPlaybackState(
    @Path('episodeId') int episodeId,
  );

  @GET('/podcasts/playback/rate/effective')
  Future<PlaybackRateEffectiveResponse> getEffectivePlaybackRate(
    @Query('subscription_id') int? subscriptionId,
  );

  @PUT('/podcasts/playback/rate/apply')
  Future<PlaybackRateEffectiveResponse> applyPlaybackRatePreference(
    @Body() PlaybackRateApplyRequest request,
  );

  // === Queue Management ===

  @GET('/podcasts/queue')
  Future<PodcastQueueModel> getQueue();

  @POST('/podcasts/queue/items')
  Future<PodcastQueueModel> addQueueItem(
    @Body() PodcastQueueAddItemRequest request,
  );

  @DELETE('/podcasts/queue/items/{episodeId}')
  Future<PodcastQueueModel> removeQueueItem(@Path('episodeId') int episodeId);

  @PUT('/podcasts/queue/items/reorder')
  Future<PodcastQueueModel> reorderQueueItems(
    @Body() PodcastQueueReorderRequest request,
  );

  @POST('/podcasts/queue/current')
  Future<PodcastQueueModel> setQueueCurrent(
    @Body() PodcastQueueSetCurrentRequest request,
  );

  @POST('/podcasts/queue/activate')
  Future<PodcastQueueModel> activateQueueEpisode(
    @Body() PodcastQueueActivateRequest request,
  );

  @POST('/podcasts/queue/current/complete')
  Future<PodcastQueueModel> completeQueueCurrent(
    @Body() Map<String, dynamic> request,
  );

  // === Summary Management ===

  @POST('/podcasts/episodes/{episodeId}/summary')
  Future<PodcastSummaryStartResponse> generateSummary(
    @Path('episodeId') int episodeId,
    @Body() PodcastSummaryRequest request,
  );

  @GET('/podcasts/summaries/models')
  Future<SummaryModelsResponse> getSummaryModels();

  @GET('/podcasts/summaries/pending')
  Future<SimpleResponse> getPendingSummaries();

  // === Search ===

  @GET('/podcasts/search')
  Future<PodcastEpisodeListResponse> searchPodcasts(
    @Query('q') String query,
    @Query('search_in') String? searchIn,
    @Query('page') int page,
    @Query('size') int size,
  );

  // === Statistics ===

  @GET('/podcasts/stats')
  Future<PodcastStatsResponse> getStats();

  @GET('/podcasts/stats/profile')
  Future<ProfileStatsModel> getProfileStats();

  // === Transcription Management ===

  @GET('/podcasts/episodes/{episodeId}/transcription')
  Future<PodcastTranscriptionResponse> getTranscription(
    @Path('episodeId') int episodeId,
  );

  @POST('/podcasts/episodes/{episodeId}/transcribe')
  Future<PodcastTranscriptionResponse> startTranscription(
    @Path('episodeId') int episodeId,
    @Body() PodcastTranscriptionRequest request,
  );

  @DELETE('/podcasts/episodes/{episodeId}/transcription')
  Future<void> deleteTranscription(@Path('episodeId') int episodeId);

  // === Conversation Management ===

  @GET('/podcasts/episodes/{episodeId}/conversation-sessions')
  Future<ConversationSessionListResponse> getConversationSessions(
    @Path('episodeId') int episodeId,
  );

  @POST('/podcasts/episodes/{episodeId}/conversation-sessions')
  Future<ConversationSession> createConversationSession(
    @Path('episodeId') int episodeId,
    @Body() Map<String, dynamic> body,
  );

  @DELETE('/podcasts/episodes/{episodeId}/conversation-sessions/{sessionId}')
  Future<PodcastConversationClearResponse> deleteConversationSession(
    @Path('episodeId') int episodeId,
    @Path('sessionId') int sessionId,
  );

  @GET('/podcasts/episodes/{episodeId}/conversations')
  Future<PodcastConversationHistoryResponse> getConversationHistory(
    @Path('episodeId') int episodeId,
    @Query('limit') int limit,
    @Query('session_id') int? sessionId,
  );

  @POST('/podcasts/episodes/{episodeId}/conversations')
  Future<PodcastConversationSendResponse> sendConversationMessage(
    @Path('episodeId') int episodeId,
    @Body() PodcastConversationSendRequest request,
  );

  @DELETE('/podcasts/episodes/{episodeId}/conversations')
  Future<PodcastConversationClearResponse> clearConversationHistory(
    @Path('episodeId') int episodeId,
    @Query('session_id') int? sessionId,
  );

  @GET('/podcasts/subscriptions/schedule/all')
  Future<List<ScheduleConfigResponse>> getAllSubscriptionSchedules();

  @POST('/podcasts/subscriptions/schedule/batch-update')
  Future<List<ScheduleConfigResponse>> batchUpdateSubscriptionSchedules(
    @Body() Map<String, dynamic> requestData,
  );

  // === Highlights Management ===

  @GET('/podcasts/highlights')
  Future<HighlightsListResponse> getHighlights(
    @Query('date') String? date,
    @Query('page') int page,
    @Query('per_page') int perPage,
    @Query('episode_id') int? episodeId,
  );

  @GET('/podcasts/highlights/dates')
  Future<HighlightDatesResponse> getHighlightDates();

  @GET('/podcasts/highlights/stats')
  Future<HighlightStatsResponse> getHighlightStats();

  @POST('/podcasts/episodes/{episodeId}/highlights/extract')
  Future<HighlightExtractResponse> extractEpisodeHighlights(
    @Path('episodeId') int episodeId,
  );

  @POST('/podcasts/highlights/{highlightId}/toggle-favorite')
  Future<void> toggleHighlightFavorite(@Path('highlightId') int highlightId);

  @DELETE('/podcasts/highlights/{highlightId}')
  Future<void> deleteHighlight(@Path('highlightId') int highlightId);
}
