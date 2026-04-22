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
  created_at: string;
}

// ===== AI Provider Settings =====

export interface AIProvider {
  id: string;
  provider_name: string;
  base_url: string;
  encrypted_api_key: string;
  is_default: boolean;
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
  provider_name: string;
  base_url: string;
  api_key: string;
  is_default?: boolean;
}

export interface UpdateProviderRequest {
  provider_name?: string;
  base_url?: string;
  api_key?: string;
  is_default?: boolean;
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

// ===== Dashboard Types =====

export interface DashboardStats {
  total_podcasts: number;
  tracked_podcasts: number;
  total_episodes: number;
  transcribed_episodes: number;
}
