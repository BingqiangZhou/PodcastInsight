// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'podcast_transcription_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PodcastTranscriptionRequest _$PodcastTranscriptionRequestFromJson(
  Map<String, dynamic> json,
) => PodcastTranscriptionRequest(
  forceRegenerate: json['forceRegenerate'] as bool,
  chunkSizeMb: (json['chunkSizeMb'] as num?)?.toInt(),
  transcriptionModel: json['transcriptionModel'] as String?,
);

Map<String, dynamic> _$PodcastTranscriptionRequestToJson(
  PodcastTranscriptionRequest instance,
) => <String, dynamic>{
  'forceRegenerate': instance.forceRegenerate,
  'chunkSizeMb': instance.chunkSizeMb,
  'transcriptionModel': instance.transcriptionModel,
};

PodcastTranscriptionResponse _$PodcastTranscriptionResponseFromJson(
  Map<String, dynamic> json,
) => PodcastTranscriptionResponse(
  id: (json['id'] as num).toInt(),
  episodeId: (json['episode_id'] as num).toInt(),
  status: json['status'] as String,
  createdAt: DateTime.parse(json['created_at'] as String),
  transcriptContent: json['transcript_content'] as String?,
  processedTranscript: json['processed_transcript'] as String?,
  wordCount: (json['transcript_word_count'] as num?)?.toInt(),
  durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
  processingProgress: (json['progress_percentage'] as num?)?.toDouble(),
  errorMessage: json['error_message'] as String?,
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
  completedAt: json['completed_at'] == null
      ? null
      : DateTime.parse(json['completed_at'] as String),
  debugMessage: json['debug_message'] as String?,
  summaryContent: json['summary_content'] as String?,
  summaryModelUsed: json['summary_model_used'] as String?,
  summaryWordCount: (json['summary_word_count'] as num?)?.toInt(),
  summaryProcessingTime: (json['summary_processing_time'] as num?)?.toDouble(),
  summaryErrorMessage: json['summary_error_message'] as String?,
);

Map<String, dynamic> _$PodcastTranscriptionResponseToJson(
  PodcastTranscriptionResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'episode_id': instance.episodeId,
  'status': instance.status,
  'transcript_content': instance.transcriptContent,
  'processed_transcript': instance.processedTranscript,
  'transcript_word_count': instance.wordCount,
  'duration_seconds': instance.durationSeconds,
  'progress_percentage': instance.processingProgress,
  'error_message': instance.errorMessage,
  'created_at': instance.createdAt.toIso8601String(),
  'updated_at': instance.updatedAt?.toIso8601String(),
  'completed_at': instance.completedAt?.toIso8601String(),
  'debug_message': instance.debugMessage,
  'summary_content': instance.summaryContent,
  'summary_model_used': instance.summaryModelUsed,
  'summary_word_count': instance.summaryWordCount,
  'summary_processing_time': instance.summaryProcessingTime,
  'summary_error_message': instance.summaryErrorMessage,
};

TranscriptDialogueSegment _$TranscriptDialogueSegmentFromJson(
  Map<String, dynamic> json,
) => TranscriptDialogueSegment(
  text: json['text'] as String,
  speaker: json['speaker'] as String?,
  timestamp: json['timestamp'] as String?,
  startTime: (json['start_time'] as num?)?.toDouble(),
  endTime: (json['end_time'] as num?)?.toDouble(),
  confidence: (json['confidence'] as num?)?.toDouble(),
);

Map<String, dynamic> _$TranscriptDialogueSegmentToJson(
  TranscriptDialogueSegment instance,
) => <String, dynamic>{
  'speaker': instance.speaker,
  'timestamp': instance.timestamp,
  'start_time': instance.startTime,
  'end_time': instance.endTime,
  'text': instance.text,
  'confidence': instance.confidence,
};

ParsedTranscript _$ParsedTranscriptFromJson(Map<String, dynamic> json) =>
    ParsedTranscript(
      segments: (json['segments'] as List<dynamic>)
          .map(
            (e) =>
                TranscriptDialogueSegment.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      summary: json['summary'] as String?,
      keyTopics: (json['key_topics'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      speakers: (json['speakers'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$ParsedTranscriptToJson(ParsedTranscript instance) =>
    <String, dynamic>{
      'segments': instance.segments,
      'summary': instance.summary,
      'key_topics': instance.keyTopics,
      'speakers': instance.speakers,
    };
