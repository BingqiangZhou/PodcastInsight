// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'podcast_conversation_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConversationSession _$ConversationSessionFromJson(Map<String, dynamic> json) =>
    ConversationSession(
      id: (json['id'] as num).toInt(),
      episodeId: (json['episode_id'] as num).toInt(),
      title: json['title'] as String,
      createdAt: json['created_at'] as String,
      messageCount: (json['message_count'] as num?)?.toInt() ?? 0,
      updatedAt: json['updated_at'] as String?,
    );

Map<String, dynamic> _$ConversationSessionToJson(
  ConversationSession instance,
) => <String, dynamic>{
  'id': instance.id,
  'episode_id': instance.episodeId,
  'title': instance.title,
  'message_count': instance.messageCount,
  'created_at': instance.createdAt,
  'updated_at': instance.updatedAt,
};

ConversationSessionListResponse _$ConversationSessionListResponseFromJson(
  Map<String, dynamic> json,
) => ConversationSessionListResponse(
  sessions: (json['sessions'] as List<dynamic>)
      .map((e) => ConversationSession.fromJson(e as Map<String, dynamic>))
      .toList(),
  total: (json['total'] as num).toInt(),
);

Map<String, dynamic> _$ConversationSessionListResponseToJson(
  ConversationSessionListResponse instance,
) => <String, dynamic>{'sessions': instance.sessions, 'total': instance.total};

PodcastConversationMessage _$PodcastConversationMessageFromJson(
  Map<String, dynamic> json,
) => PodcastConversationMessage(
  id: (json['id'] as num).toInt(),
  role: json['role'] as String,
  content: json['content'] as String,
  conversationTurn: (json['conversation_turn'] as num).toInt(),
  createdAt: json['created_at'] as String,
  parentMessageId: (json['parent_message_id'] as num?)?.toInt(),
);

Map<String, dynamic> _$PodcastConversationMessageToJson(
  PodcastConversationMessage instance,
) => <String, dynamic>{
  'id': instance.id,
  'role': instance.role,
  'content': instance.content,
  'conversation_turn': instance.conversationTurn,
  'created_at': instance.createdAt,
  'parent_message_id': instance.parentMessageId,
};

PodcastConversationSendRequest _$PodcastConversationSendRequestFromJson(
  Map<String, dynamic> json,
) => PodcastConversationSendRequest(
  message: json['message'] as String,
  modelName: json['model_name'] as String?,
  sessionId: (json['session_id'] as num?)?.toInt(),
);

Map<String, dynamic> _$PodcastConversationSendRequestToJson(
  PodcastConversationSendRequest instance,
) => <String, dynamic>{
  'message': instance.message,
  'model_name': instance.modelName,
  'session_id': instance.sessionId,
};

PodcastConversationSendResponse _$PodcastConversationSendResponseFromJson(
  Map<String, dynamic> json,
) => PodcastConversationSendResponse(
  id: (json['id'] as num).toInt(),
  role: json['role'] as String,
  content: json['content'] as String,
  conversationTurn: (json['conversation_turn'] as num).toInt(),
  createdAt: json['created_at'] as String,
  processingTime: (json['processing_time'] as num?)?.toDouble(),
);

Map<String, dynamic> _$PodcastConversationSendResponseToJson(
  PodcastConversationSendResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'role': instance.role,
  'content': instance.content,
  'conversation_turn': instance.conversationTurn,
  'processing_time': instance.processingTime,
  'created_at': instance.createdAt,
};

PodcastConversationHistoryResponse _$PodcastConversationHistoryResponseFromJson(
  Map<String, dynamic> json,
) => PodcastConversationHistoryResponse(
  episodeId: (json['episode_id'] as num).toInt(),
  messages: (json['messages'] as List<dynamic>)
      .map(
        (e) => PodcastConversationMessage.fromJson(e as Map<String, dynamic>),
      )
      .toList(),
  total: (json['total'] as num).toInt(),
  sessionId: (json['session_id'] as num?)?.toInt(),
);

Map<String, dynamic> _$PodcastConversationHistoryResponseToJson(
  PodcastConversationHistoryResponse instance,
) => <String, dynamic>{
  'episode_id': instance.episodeId,
  'session_id': instance.sessionId,
  'messages': instance.messages,
  'total': instance.total,
};

PodcastConversationClearResponse _$PodcastConversationClearResponseFromJson(
  Map<String, dynamic> json,
) => PodcastConversationClearResponse(
  episodeId: (json['episode_id'] as num).toInt(),
  deletedCount: (json['deleted_count'] as num).toInt(),
  sessionId: (json['session_id'] as num?)?.toInt(),
);

Map<String, dynamic> _$PodcastConversationClearResponseToJson(
  PodcastConversationClearResponse instance,
) => <String, dynamic>{
  'episode_id': instance.episodeId,
  'session_id': instance.sessionId,
  'deleted_count': instance.deletedCount,
};
