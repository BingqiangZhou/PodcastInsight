/**
 * TanStack Query hooks — re-exports from api.ts
 *
 * All query and mutation hooks are defined in @/lib/api.ts alongside
 * their corresponding API fetcher functions. This file provides a
 * centralized import point for components that prefer importing from
 * a dedicated queries module.
 */

export {
  usePodcasts,
  usePodcast,
  useRankings,
  useTrackPodcast,
  useUntrackPodcast,
  useEpisodes,
  useEpisode,
  useTranscribeEpisode,
  useSummarizeEpisode,
  useTranscript,
  useSummary,
  useProviders,
  useCreateProvider,
  useUpdateProvider,
  useDeleteProvider,
  useTestProvider,
  useCreateModel,
  useUpdateModel,
  useDeleteModel,
  useSyncRankings,
  useSyncEpisodes,
  useDashboardStats,
} from './api';
