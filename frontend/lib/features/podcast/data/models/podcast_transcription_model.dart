import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'podcast_transcription_model.g.dart';

/// 转录请求模型
@JsonSerializable()
class PodcastTranscriptionRequest extends Equatable {

  const PodcastTranscriptionRequest({
    required this.forceRegenerate,
    this.chunkSizeMb,
    this.transcriptionModel,
  });

  factory PodcastTranscriptionRequest.fromJson(Map<String, dynamic> json) =>
      _$PodcastTranscriptionRequestFromJson(json);
  final bool forceRegenerate;
  final int? chunkSizeMb;
  final String? transcriptionModel;

  Map<String, dynamic> toJson() => _$PodcastTranscriptionRequestToJson(this);

  @override
  List<Object?> get props => [
        forceRegenerate,
        chunkSizeMb,
        transcriptionModel,
      ];
}


/// 转录状态枚举
enum TranscriptionStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('downloading')
  downloading,
  @JsonValue('converting')
  converting,
  @JsonValue('transcribing')
  transcribing,
  @JsonValue('processing')
  processing,
  @JsonValue('completed')
  completed,
  @JsonValue('failed')
  failed,
}

/// 转录响应模型
@JsonSerializable()
class PodcastTranscriptionResponse extends Equatable {

  const PodcastTranscriptionResponse({
    required this.id,
    required this.episodeId,
    required this.status,
    required this.createdAt, this.transcriptContent,
    this.processedTranscript,
    this.wordCount,
    this.durationSeconds,
    this.processingProgress,
    this.errorMessage,
    this.updatedAt,
    this.completedAt,
    this.debugMessage,
    // AI总结相关
    this.summaryContent,
    this.summaryModelUsed,
    this.summaryWordCount,
    this.summaryProcessingTime,
    this.summaryErrorMessage,
  });

  factory PodcastTranscriptionResponse.fromJson(Map<String, dynamic> json) =>
      _$PodcastTranscriptionResponseFromJson(json);
  final int id;
  @JsonKey(name: 'episode_id')
  final int episodeId;
  final String status;
  @JsonKey(name: 'transcript_content')
  final String? transcriptContent;
  @JsonKey(name: 'processed_transcript')
  final String? processedTranscript;
  @JsonKey(name: 'transcript_word_count')
  final int? wordCount;
  @JsonKey(name: 'duration_seconds')
  final int? durationSeconds;
  @JsonKey(name: 'progress_percentage')
  final double? processingProgress;
  @JsonKey(name: 'error_message')
  final String? errorMessage;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;
  @JsonKey(name: 'completed_at')
  final DateTime? completedAt;

  @JsonKey(name: 'debug_message')
  final String? debugMessage;

  // AI总结相关字段
  @JsonKey(name: 'summary_content')
  final String? summaryContent;
  @JsonKey(name: 'summary_model_used')
  final String? summaryModelUsed;
  @JsonKey(name: 'summary_word_count')
  final int? summaryWordCount;
  @JsonKey(name: 'summary_processing_time')
  final double? summaryProcessingTime;
  @JsonKey(name: 'summary_error_message')
  final String? summaryErrorMessage;

  Map<String, dynamic> toJson() => _$PodcastTranscriptionResponseToJson(this);

  /// 获取转录状态枚举
  TranscriptionStatus get transcriptionStatus {
    switch (status.toLowerCase()) {
      case 'pending':
        return TranscriptionStatus.pending;
      case 'downloading':
        return TranscriptionStatus.downloading;
      case 'converting':
        return TranscriptionStatus.converting;
      case 'transcribing':
        return TranscriptionStatus.transcribing;
      case 'processing':
        return TranscriptionStatus.processing;
      case 'completed':
        return TranscriptionStatus.completed;
      case 'failed':
        return TranscriptionStatus.failed;
      default:
        return TranscriptionStatus.pending;
    }
  }

  /// 是否已完成
  bool get isCompleted => transcriptionStatus == TranscriptionStatus.completed;

  /// 是否失败
  bool get isFailed => transcriptionStatus == TranscriptionStatus.failed;

  /// 是否正在处理中
  bool get isProcessing => [
    TranscriptionStatus.downloading,
    TranscriptionStatus.converting,
    TranscriptionStatus.transcribing,
    TranscriptionStatus.processing,
  ].contains(transcriptionStatus);

  /// 获取显示用的转录内容（优先使用处理后的内容）
  String? get displayContent => processedTranscript ?? transcriptContent;

  /// 获取进度百分比
  double get progressPercentage {
    final progress = processingProgress;
    if (progress != null) {
      return progress.clamp(0.0, 100.0);
    }
    if (isCompleted) return 100;
    if (isFailed) return 0;
    return 0;
  }

  @override
  List<Object?> get props => [
        id,
        episodeId,
        status,
        transcriptContent,
        processedTranscript,
        wordCount,
        durationSeconds,
        processingProgress,
        errorMessage,
        createdAt,
        updatedAt,
        completedAt,
        debugMessage,
        // AI总结相关
        summaryContent,
        summaryModelUsed,
        summaryWordCount,
        summaryProcessingTime,
        summaryErrorMessage,
      ];
}

/// 转录对话段落模型
@JsonSerializable()
class TranscriptDialogueSegment extends Equatable {

  const TranscriptDialogueSegment({
    required this.text, this.speaker,
    this.timestamp,
    this.startTime,
    this.endTime,
    this.confidence,
  });

  factory TranscriptDialogueSegment.fromJson(Map<String, dynamic> json) =>
      _$TranscriptDialogueSegmentFromJson(json);
  @JsonKey(name: 'speaker')
  final String? speaker;
  @JsonKey(name: 'timestamp')
  final String? timestamp;
  @JsonKey(name: 'start_time')
  final double? startTime;
  @JsonKey(name: 'end_time')
  final double? endTime;
  @JsonKey(name: 'text')
  final String text;
  @JsonKey(name: 'confidence')
  final double? confidence;

  Map<String, dynamic> toJson() => _$TranscriptDialogueSegmentToJson(this);

  /// 格式化时间戳
  String get formattedTimestamp {
    final ts = timestamp;
    if (ts != null) return ts;
    final start = startTime;
    if (start != null) {
      final duration = Duration(seconds: start.round());
      final minutes = duration.inMinutes.remainder(60);
      final seconds = duration.inSeconds.remainder(60);
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '';
  }

  @override
  List<Object?> get props => [
        speaker,
        timestamp,
        startTime,
        endTime,
        text,
        confidence,
      ];
}

/// 解析后的转录内容模型
@JsonSerializable()
class ParsedTranscript extends Equatable {

  const ParsedTranscript({
    required this.segments,
    this.summary,
    this.keyTopics,
    this.speakers,
  });

  factory ParsedTranscript.fromJson(Map<String, dynamic> json) =>
      _$ParsedTranscriptFromJson(json);
  @JsonKey(name: 'segments')
  final List<TranscriptDialogueSegment> segments;
  @JsonKey(name: 'summary')
  final String? summary;
  @JsonKey(name: 'key_topics')
  final List<String>? keyTopics;
  @JsonKey(name: 'speakers')
  final List<String>? speakers;

  Map<String, dynamic> toJson() => _$ParsedTranscriptToJson(this);

  @override
  List<Object?> get props => [
        segments,
        summary,
        keyTopics,
        speakers,
      ];
}