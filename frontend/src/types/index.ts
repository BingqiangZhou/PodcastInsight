// ===== Enums =====

export enum TranscriptStatus {
  Pending = "pending",
  Processing = "processing",
  Completed = "completed",
  Failed = "failed",
}

export enum SummaryStatus {
  Pending = "pending",
  Processing = "processing",
  Completed = "completed",
  Failed = "failed",
}

// ===== Core Models =====

export interface Podcast {
  id: string;
  xyzrank_id: string;
  name: string;
  rank: number;
  logo_url: string | null;
  category: string | null;
  author: string | null;
  rss_feed_url: string | null;
  track_count: number | null;
  avg_duration: number | null;
  avg_play_count: number | null;
  last_synced_at: string | null;
  is_tracked: boolean;
  priority: number;
  created_at: string;
  updated_at: string;
}

export interface PodcastRanking {
  id: string;
  podcast_id: string;
  rank: number;
  avg_play_count: number | null;
  recorded_at: string;
  podcast?: Podcast;
}

export interface Episode {
  id: string;
  podcast_id: string;
  title: string;
  description: string | null;
  audio_url: string | null;
  duration: number | null;
  published_at: string | null;
  transcript_status: TranscriptStatus | null;
  summary_status: SummaryStatus | null;
  created_at: string;
  updated_at: string;
  podcast?: Podcast;
}

export interface TranscriptSegment {
  start: number;
  end: number;
  text: string;
}

export interface Transcript {
  id: string;
  episode_id: string;
  content: string;
  language: string | null;
  word_count: number | null;
  char_count: number | null;
  processing_duration_sec: number | null;
  rating: number | null;
  model_used: string | null;
  segments: TranscriptSegment[] | null;
  created_at: string;
}

export interface Summary {
  id: string;
  episode_id: string;
  content: string;
  key_topics: string[];
  highlights: string[];
  model_used: string | null;
  provider: string | null;
  prompt_version_id: string | null;
  quality_score: number | null;
  rating: number | null;
  feedback: string | null;
  processing_duration_sec: number | null;
  created_at: string;
}

// ===== AI Provider Settings =====

export interface AIProvider {
  id: string;
  name: string;
  provider_type: string;
  base_url: string;
  is_active: boolean;
  created_at: string;
  updated_at: string;
  models?: AIModel[];
}

export interface AIModel {
  id: string;
  provider_id: string;
  model_name: string;
  temperature: number;
  max_tokens: number;
  is_default: boolean;
  created_at: string;
}

export interface PromptTemplate {
  id: string;
  name: string;
  content: string;
  version: number;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

// ===== API Types =====

export interface PaginatedResponse<T> {
  items: T[];
  total: number;
  page: number;
  page_size: number;
  total_pages: number;
}

export interface ApiError {
  detail: string;
  status_code?: number;
}

// ===== Request/Response Types =====

export interface PodcastListParams {
  page?: number;
  page_size?: number;
  search?: string;
  category?: string;
  is_tracked?: boolean;
}

export interface EpisodeListParams {
  page?: number;
  page_size?: number;
  search?: string;
  podcast_id?: string;
  transcript_status?: TranscriptStatus;
  summary_status?: SummaryStatus;
}

export interface CreateProviderRequest {
  name: string;
  provider_type: string;
  base_url: string;
  api_key: string;
  is_active?: boolean;
}

export interface UpdateProviderRequest {
  name?: string;
  provider_type?: string;
  base_url?: string;
  api_key?: string;
  is_active?: boolean;
}

export interface CreateModelRequest {
  model_name: string;
  temperature?: number;
  max_tokens?: number;
  is_default?: boolean;
}

export interface UpdateModelRequest {
  model_name?: string;
  temperature?: number;
  max_tokens?: number;
  is_default?: boolean;
}

export interface TestProviderResponse {
  success: boolean;
  message: string;
}

export interface SyncResponse {
  message: string;
  task_id?: string;
}

export interface FeedbackRequest {
  rating: number;
  feedback?: string;
}

export interface BatchRequest {
  episode_ids?: string[];
  filter_status?: string;
  force?: boolean;
}

export interface CreatePromptRequest {
  name: string;
  content: string;
}

// ===== Dashboard Types =====

export interface DashboardStats {
  total_podcasts: number;
  tracked_podcasts: number;
  total_episodes: number;
  transcribed_episodes: number;
}

export interface ProductionDayTrend {
  date: string;
  transcribed: number;
  summarized: number;
}

export interface ProductionStats {
  total_episodes: number;
  transcribed: number;
  summarized: number;
  transcription_success_rate: number | null;
  summary_success_rate: number | null;
  avg_transcription_duration_sec: number | null;
  avg_summary_duration_sec: number | null;
  last_7_days: ProductionDayTrend[];
  pipeline: PipelineStats;
}

export interface PipelineStats {
  transcription_pending: number;
  transcription_processing: number;
  transcription_completed: number;
  transcription_failed: number;
  summary_pending: number;
  summary_processing: number;
  summary_completed: number;
  summary_failed: number;
}
