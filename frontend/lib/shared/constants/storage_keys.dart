/// Shared storage key constants used across features.
///
/// Centralizes keys that are referenced by multiple features to prevent
/// duplication and ensure consistency.
library;

/// Storage key prefix for persisting last playback snapshot.
///
/// Used by podcast playback (to save/restore) and auth (to clear on logout).
const String kLastPlaybackSnapshotStorageKeyPrefix =
    'podcast_last_playback_snapshot_v1';
