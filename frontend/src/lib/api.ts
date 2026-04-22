import {
  useQuery,
  useMutation,
  useQueryClient,
  type UseQueryOptions,
} from "@tanstack/react-query";
import type {
  Podcast,
  Episode,
  Transcript,
  Summary,
  AIProvider,
  AIModel,
  PaginatedResponse,
  PodcastListParams,
  EpisodeListParams,
  CreateProviderRequest,
  UpdateProviderRequest,
  CreateModelRequest,
  UpdateModelRequest,
  TestProviderResponse,
  SyncResponse,
  DashboardStats,
} from "@/types";

// ===== Base Config =====

const BASE_URL =
  process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000/api/v1";

// ===== Generic Fetcher =====

async function fetcher<T>(
  endpoint: string,
  options?: RequestInit
): Promise<T> {
  const url = `${BASE_URL}${endpoint}`;
  const res = await fetch(url, {
    headers: {
      "Content-Type": "application/json",
      ...options?.headers,
    },
    ...options,
  });

  if (!res.ok) {
    const error = await res.json().catch(() => ({
      detail: `Request failed with status ${res.status}`,
    }));
    throw new Error(error.detail || `Request failed: ${res.status}`);
  }

  return res.json();
}

// ===== Podcast API =====

async function listPodcasts(
  params?: PodcastListParams
): Promise<PaginatedResponse<Podcast>> {
  const searchParams = new URLSearchParams();
  if (params?.page) searchParams.set("page", String(params.page));
  if (params?.page_size) searchParams.set("page_size", String(params.page_size));
  if (params?.search) searchParams.set("search", params.search);
  if (params?.category) searchParams.set("category", params.category);
  if (params?.is_tracked !== undefined)
    searchParams.set("is_tracked", String(params.is_tracked));
  const qs = searchParams.toString();
  return fetcher(`/podcasts${qs ? `?${qs}` : ""}`);
}

async function getPodcast(id: string): Promise<Podcast> {
  return fetcher(`/podcasts/${id}`);
}

async function trackPodcast(id: string): Promise<{ id: string; is_tracked: boolean }> {
  return fetcher(`/podcasts/${id}/track`, { method: "POST" });
}

async function untrackPodcast(id: string): Promise<{ id: string; is_tracked: boolean }> {
  return fetcher(`/podcasts/${id}/track`, { method: "POST" });
}

// ===== Episode API =====

async function listEpisodes(
  params?: EpisodeListParams
): Promise<PaginatedResponse<Episode>> {
  if (params?.podcast_id) {
    const searchParams = new URLSearchParams();
    if (params?.page) searchParams.set("page", String(params.page));
    if (params?.page_size) searchParams.set("page_size", String(params.page_size));
    const qs = searchParams.toString();
    return fetcher(`/podcasts/${params.podcast_id}/episodes${qs ? `?${qs}` : ""}`);
  }
  const searchParams = new URLSearchParams();
  if (params?.page) searchParams.set("page", String(params.page));
  if (params?.page_size) searchParams.set("page_size", String(params.page_size));
  if (params?.transcript_status)
    searchParams.set("transcript_status", params.transcript_status);
  if (params?.summary_status)
    searchParams.set("summary_status", params.summary_status);
  const qs = searchParams.toString();
  return fetcher(`/episodes${qs ? `?${qs}` : ""}`);
}

async function getEpisode(id: string): Promise<Episode> {
  return fetcher(`/episodes/${id}`);
}

async function transcribeEpisode(id: string): Promise<SyncResponse> {
  return fetcher(`/episodes/${id}/transcribe`, { method: "POST" });
}

async function summarizeEpisode(id: string): Promise<SyncResponse> {
  return fetcher(`/episodes/${id}/summarize`, { method: "POST" });
}

// ===== Transcript API =====

async function getTranscript(episodeId: string): Promise<Transcript> {
  return fetcher(`/episodes/${episodeId}/transcript`);
}

// ===== Summary API =====

async function getSummary(episodeId: string): Promise<Summary> {
  return fetcher(`/episodes/${episodeId}/summary`);
}

// ===== Settings API =====

async function listProviders(): Promise<PaginatedResponse<AIProvider>> {
  return fetcher("/settings/providers");
}

async function createProvider(data: CreateProviderRequest): Promise<AIProvider> {
  return fetcher("/settings/providers", {
    method: "POST",
    body: JSON.stringify(data),
  });
}

async function updateProvider(
  id: string,
  data: UpdateProviderRequest
): Promise<AIProvider> {
  return fetcher(`/settings/providers/${id}`, {
    method: "PUT",
    body: JSON.stringify(data),
  });
}

async function deleteProvider(id: string): Promise<void> {
  await fetcher(`/settings/providers/${id}`, { method: "DELETE" });
}

async function testProvider(id: string): Promise<TestProviderResponse> {
  return fetcher(`/settings/providers/${id}/test`, { method: "POST" });
}

async function createModel(
  providerId: string,
  data: CreateModelRequest
): Promise<AIModel> {
  return fetcher(`/settings/providers/${providerId}/models`, {
    method: "POST",
    body: JSON.stringify(data),
  });
}

async function updateModel(
  providerId: string,
  modelId: string,
  data: UpdateModelRequest
): Promise<AIModel> {
  return fetcher(`/settings/providers/${providerId}/models/${modelId}`, {
    method: "PUT",
    body: JSON.stringify(data),
  });
}

async function deleteModel(
  providerId: string,
  modelId: string
): Promise<void> {
  await fetcher(`/settings/providers/${providerId}/models/${modelId}`, {
    method: "DELETE",
  });
}

// ===== Sync API =====

async function syncRankings(): Promise<SyncResponse> {
  return fetcher("/podcasts/sync", { method: "POST" });
}

async function syncEpisodes(): Promise<SyncResponse> {
  return fetcher("/episodes/sync", { method: "POST" });
}

// ===== Dashboard API (composite) =====

async function getDashboardStats(): Promise<DashboardStats> {
  const [podcastsData, trackedData, episodesData] = await Promise.all([
    fetcher<PaginatedResponse<Podcast>>("/podcasts?page_size=1"),
    fetcher<PaginatedResponse<Podcast>>("/podcasts?is_tracked=true&page_size=1"),
    fetcher<PaginatedResponse<Episode>>("/episodes?page_size=1"),
  ]);
  const transcribedData = await fetcher<PaginatedResponse<Episode>>(
    "/episodes?transcript_status=completed&page_size=1"
  );
  return {
    total_podcasts: podcastsData.total,
    tracked_podcasts: trackedData.total,
    total_episodes: episodesData.total,
    transcribed_episodes: transcribedData.total,
  };
}

// ===== TanStack Query Hooks =====

// -- Podcasts --

export function usePodcasts(params?: PodcastListParams) {
  return useQuery({
    queryKey: ["podcasts", params],
    queryFn: () => listPodcasts(params),
  });
}

export function usePodcast(id: string) {
  return useQuery({
    queryKey: ["podcast", id],
    queryFn: () => getPodcast(id),
    enabled: !!id,
  });
}

export function useRankings(page?: number, pageSize?: number) {
  return useQuery({
    queryKey: ["rankings", page, pageSize],
    queryFn: () => listPodcasts({ page, page_size: pageSize }),
  });
}

export function useTrackPodcast() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: trackPodcast,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["podcasts"] });
      queryClient.invalidateQueries({ queryKey: ["podcast"] });
      queryClient.invalidateQueries({ queryKey: ["rankings"] });
      queryClient.invalidateQueries({ queryKey: ["dashboard-stats"] });
    },
  });
}

export function useUntrackPodcast() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: untrackPodcast,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["podcasts"] });
      queryClient.invalidateQueries({ queryKey: ["podcast"] });
      queryClient.invalidateQueries({ queryKey: ["rankings"] });
      queryClient.invalidateQueries({ queryKey: ["dashboard-stats"] });
    },
  });
}

// -- Episodes --

export function useEpisodes(params?: EpisodeListParams) {
  return useQuery({
    queryKey: ["episodes", params],
    queryFn: () => listEpisodes(params),
  });
}

export function useEpisode(id: string) {
  return useQuery({
    queryKey: ["episode", id],
    queryFn: () => getEpisode(id),
    enabled: !!id,
  });
}

export function useTranscribeEpisode() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: transcribeEpisode,
    onSuccess: (_data, episodeId) => {
      queryClient.invalidateQueries({ queryKey: ["episode", episodeId] });
      queryClient.invalidateQueries({ queryKey: ["episodes"] });
    },
  });
}

export function useSummarizeEpisode() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: summarizeEpisode,
    onSuccess: (_data, episodeId) => {
      queryClient.invalidateQueries({ queryKey: ["episode", episodeId] });
      queryClient.invalidateQueries({ queryKey: ["episodes"] });
    },
  });
}

// -- Transcript --

export function useTranscript(
  episodeId: string,
  options?: Partial<UseQueryOptions<Transcript>>
) {
  return useQuery({
    queryKey: ["transcript", episodeId],
    queryFn: () => getTranscript(episodeId),
    enabled: !!episodeId,
    ...options,
  });
}

// -- Summary --

export function useSummary(
  episodeId: string,
  options?: Partial<UseQueryOptions<Summary>>
) {
  return useQuery({
    queryKey: ["summary", episodeId],
    queryFn: () => getSummary(episodeId),
    enabled: !!episodeId,
    ...options,
  });
}

// -- Settings --

export function useProviders() {
  return useQuery({
    queryKey: ["providers"],
    queryFn: listProviders,
  });
}

export function useCreateProvider() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: createProvider,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["providers"] });
    },
  });
}

export function useUpdateProvider() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, data }: { id: string; data: UpdateProviderRequest }) =>
      updateProvider(id, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["providers"] });
    },
  });
}

export function useDeleteProvider() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: deleteProvider,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["providers"] });
    },
  });
}

export function useTestProvider() {
  return useMutation({
    mutationFn: testProvider,
  });
}

export function useCreateModel() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({
      providerId,
      data,
    }: {
      providerId: string;
      data: CreateModelRequest;
    }) => createModel(providerId, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["providers"] });
    },
  });
}

export function useUpdateModel() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({
      providerId,
      modelId,
      data,
    }: {
      providerId: string;
      modelId: string;
      data: UpdateModelRequest;
    }) => updateModel(providerId, modelId, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["providers"] });
    },
  });
}

export function useDeleteModel() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({
      providerId,
      modelId,
    }: {
      providerId: string;
      modelId: string;
    }) => deleteModel(providerId, modelId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["providers"] });
    },
  });
}

// -- Sync --

export function useSyncRankings() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: syncRankings,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["podcasts"] });
      queryClient.invalidateQueries({ queryKey: ["rankings"] });
      queryClient.invalidateQueries({ queryKey: ["dashboard-stats"] });
    },
  });
}

export function useSyncEpisodes() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: syncEpisodes,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["episodes"] });
      queryClient.invalidateQueries({ queryKey: ["dashboard-stats"] });
    },
  });
}

// -- Dashboard --

export function useDashboardStats() {
  return useQuery({
    queryKey: ["dashboard-stats"],
    queryFn: getDashboardStats,
    refetchInterval: 30000,
  });
}
