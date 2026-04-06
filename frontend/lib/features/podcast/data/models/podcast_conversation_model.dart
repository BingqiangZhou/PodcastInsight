import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'podcast_conversation_model.g.dart';

/// 对话消息角色
enum ConversationRole {
  @JsonValue('user')
  user,
  @JsonValue('assistant')
  assistant,
}

/// 对话会话模型
@JsonSerializable()
class ConversationSession extends Equatable {

  const ConversationSession({
    required this.id,
    required this.episodeId,
    required this.title,
    required this.createdAt, this.messageCount = 0,
    this.updatedAt,
  });

  factory ConversationSession.fromJson(Map<String, dynamic> json) =>
      _$ConversationSessionFromJson(json);
  final int id;
  @JsonKey(name: 'episode_id')
  final int episodeId;
  final String title;
  @JsonKey(name: 'message_count')
  final int messageCount;
  @JsonKey(name: 'created_at')
  final String createdAt;
  @JsonKey(name: 'updated_at')
  final String? updatedAt;

  Map<String, dynamic> toJson() => _$ConversationSessionToJson(this);

  @override
  List<Object?> get props => [
        id,
        episodeId,
        title,
        messageCount,
        createdAt,
        updatedAt,
      ];
}

/// 对话会话列表响应
@JsonSerializable()
class ConversationSessionListResponse extends Equatable {

  const ConversationSessionListResponse({
    required this.sessions,
    required this.total,
  });

  factory ConversationSessionListResponse.fromJson(Map<String, dynamic> json) =>
      _$ConversationSessionListResponseFromJson(json);
  final List<ConversationSession> sessions;
  final int total;

  Map<String, dynamic> toJson() => _$ConversationSessionListResponseToJson(this);

  @override
  List<Object?> get props => [sessions, total];
}

/// 对话消息模型
@JsonSerializable()
class PodcastConversationMessage extends Equatable {

  const PodcastConversationMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.conversationTurn,
    required this.createdAt,
    this.parentMessageId,
  });

  factory PodcastConversationMessage.fromJson(Map<String, dynamic> json) =>
      _$PodcastConversationMessageFromJson(json);
  final int id;
  final String role; // 'user' or 'assistant'
  final String content;
  @JsonKey(name: 'conversation_turn')
  final int conversationTurn;
  @JsonKey(name: 'created_at')
  final String createdAt;
  @JsonKey(name: 'parent_message_id')
  final int? parentMessageId;

  Map<String, dynamic> toJson() => _$PodcastConversationMessageToJson(this);

  /// 获取角色枚举
  ConversationRole get conversationRole {
    switch (role.toLowerCase()) {
      case 'user':
        return ConversationRole.user;
      case 'assistant':
        return ConversationRole.assistant;
      default:
        return ConversationRole.user;
    }
  }

  /// 是否为用户消息
  bool get isUser => conversationRole == ConversationRole.user;

  /// 是否为AI助手消息
  bool get isAssistant => conversationRole == ConversationRole.assistant;

  @override
  List<Object?> get props => [
        id,
        role,
        content,
        conversationTurn,
        createdAt,
        parentMessageId,
      ];
}

/// 发送对话消息请求
@JsonSerializable()
class PodcastConversationSendRequest extends Equatable {

  const PodcastConversationSendRequest({
    required this.message,
    this.modelName,
    this.sessionId,
  });

  factory PodcastConversationSendRequest.fromJson(Map<String, dynamic> json) =>
      _$PodcastConversationSendRequestFromJson(json);
  final String message;
  @JsonKey(name: 'model_name')
  final String? modelName;
  @JsonKey(name: 'session_id')
  final int? sessionId;

  Map<String, dynamic> toJson() => _$PodcastConversationSendRequestToJson(this);

  @override
  List<Object?> get props => [message, modelName, sessionId];
}

/// 发送对话消息响应
@JsonSerializable()
class PodcastConversationSendResponse extends Equatable {

  const PodcastConversationSendResponse({
    required this.id,
    required this.role,
    required this.content,
    required this.conversationTurn,
    required this.createdAt, this.processingTime,
  });

  factory PodcastConversationSendResponse.fromJson(Map<String, dynamic> json) =>
      _$PodcastConversationSendResponseFromJson(json);
  final int id;
  final String role;
  final String content;
  @JsonKey(name: 'conversation_turn')
  final int conversationTurn;
  @JsonKey(name: 'processing_time')
  final double? processingTime;
  @JsonKey(name: 'created_at')
  final String createdAt;

  Map<String, dynamic> toJson() => _$PodcastConversationSendResponseToJson(this);

  /// 转换为消息模型
  PodcastConversationMessage toMessage() {
    return PodcastConversationMessage(
      id: id,
      role: role,
      content: content,
      conversationTurn: conversationTurn,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        role,
        content,
        conversationTurn,
        processingTime,
        createdAt,
      ];
}

/// 对话历史响应
@JsonSerializable()
class PodcastConversationHistoryResponse extends Equatable {

  const PodcastConversationHistoryResponse({
    required this.episodeId,
    required this.messages, required this.total, this.sessionId,
  });

  factory PodcastConversationHistoryResponse.fromJson(Map<String, dynamic> json) =>
      _$PodcastConversationHistoryResponseFromJson(json);
  @JsonKey(name: 'episode_id')
  final int episodeId;
  @JsonKey(name: 'session_id')
  final int? sessionId;
  final List<PodcastConversationMessage> messages;
  final int total;

  Map<String, dynamic> toJson() => _$PodcastConversationHistoryResponseToJson(this);

  @override
  List<Object?> get props => [episodeId, sessionId, messages, total];
}

/// 清除对话历史响应
@JsonSerializable()
class PodcastConversationClearResponse extends Equatable {

  const PodcastConversationClearResponse({
    required this.episodeId,
    required this.deletedCount, this.sessionId,
  });

  factory PodcastConversationClearResponse.fromJson(Map<String, dynamic> json) =>
      _$PodcastConversationClearResponseFromJson(json);
  @JsonKey(name: 'episode_id')
  final int episodeId;
  @JsonKey(name: 'session_id')
  final int? sessionId;
  @JsonKey(name: 'deleted_count')
  final int deletedCount;

  Map<String, dynamic> toJson() => _$PodcastConversationClearResponseToJson(this);

  @override
  List<Object?> get props => [episodeId, sessionId, deletedCount];
}
