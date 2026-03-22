-- Database Optimization Migration Scripts
-- Generated: 2026-03-22
-- Purpose: Implement optimizations from database_optimization_report.md
--
-- IMPORTANT: Review and test each migration in staging before production!
-- These scripts should be converted to Alembic migrations for proper versioning.

-- ============================================================================
-- PHASE 1: CRITICAL OPTIMIZATIONS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Migration 1.1: Extract transcript_content to separate table
-- ----------------------------------------------------------------------------
-- ISSUE: Large TEXT column in main table causes query slowdown
-- IMPACT: 50-80% performance improvement for main table queries
-- RISK: Medium - requires data migration and ORM changes

BEGIN;

-- Step 1: Create new table for transcripts
CREATE TABLE podcast_episode_transcripts (
    episode_id INTEGER PRIMARY KEY REFERENCES podcast_episodes(id) ON DELETE CASCADE,
    transcript_content TEXT NOT NULL,
    compressed_content BYTEA,  -- Future: gzip compressed option
    word_count INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Step 2: Create index for quick lookups (optional, since episode_id is PK)
-- No additional index needed - PRIMARY KEY provides lookup

-- Step 3: Migrate existing data in batches (for large datasets)
-- For production with >10k episodes, use batched migration:
INSERT INTO podcast_episode_transcripts (episode_id, transcript_content, word_count)
SELECT
    id,
    transcript_content,
    CASE
        WHEN transcript_content IS NOT NULL THEN
            LENGTH(transcript_content) - LENGTH(REPLACE(transcript_content, ' ', '')) + 1
        ELSE NULL
    END as word_count
FROM podcast_episodes
WHERE transcript_content IS NOT NULL
ON CONFLICT (episode_id) DO NOTHING;  -- Handle any duplicates

-- Step 4: Verify data migration
SELECT
    (SELECT COUNT(*) FROM podcast_episodes WHERE transcript_content IS NOT NULL) as old_count,
    (SELECT COUNT(*) FROM podcast_episode_transcripts) as new_count;

-- Step 5: After verification and code deployment, drop the old column
-- COMMENT OUT THIS SECTION UNTIL ORM IS UPDATED!
-- ALTER TABLE podcast_episodes DROP COLUMN transcript_content;

-- Add comment for documentation
COMMENT ON TABLE podcast_episode_transcripts IS 'Stores full transcript content separately from main episode table for performance optimization';
COMMENT ON COLUMN podcast_episode_transcripts.word_count IS 'Approximate word count for quick filtering and display';

COMMIT;

-- Rollback command (if needed):
-- BEGIN;
-- INSERT INTO podcast_episodes (id, transcript_content)
-- SELECT episode_id, transcript_content FROM podcast_episode_transcripts;
-- DROP TABLE podcast_episode_transcripts;
-- COMMIT;

-- ----------------------------------------------------------------------------
-- Migration 1.2: Add composite index for feed queries
-- ----------------------------------------------------------------------------
-- ISSUE: Missing index for (subscription_id, published_at, id) pattern
-- IMPACT: 40-60% performance improvement for feed queries
-- RISK: Low - index creation is safe

BEGIN;

-- Create composite index covering the most common feed query pattern
CREATE INDEX CONCURRENTLY idx_podcast_episodes_subscription_published
ON podcast_episodes (subscription_id, published_at DESC, id DESC);

-- Verify index creation
SELECT
    schemaname, tablename, indexname, indexdef
FROM pg_indexes
WHERE indexname = 'idx_podcast_episodes_subscription_published';

COMMIT;

-- Rollback command:
-- DROP INDEX CONCURRENTLY idx_podcast_episodes_subscription_published;

-- ----------------------------------------------------------------------------
-- Migration 1.3: Add GIN indexes for full-text search
-- ----------------------------------------------------------------------------
-- ISSUE: ILIKE with leading wildcard cannot use standard indexes
-- IMPACT: 10-100x performance improvement for search queries
-- RISK: Low - requires pg_trgm extension

BEGIN;

-- Enable pg_trgm extension for trigram-based similarity search
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Create GIN indexes for search columns
CREATE INDEX CONCURRENTLY idx_podcast_episodes_title_trgm
ON podcast_episodes USING gin (title gin_trgm_ops);

CREATE INDEX CONCURRENTLY idx_podcast_episodes_description_trgm
ON podcast_episodes USING gin (description gin_trgm_ops);

CREATE INDEX CONCURRENTLY idx_podcast_episodes_ai_summary_trgm
ON podcast_episodes USING gin (ai_summary gin_trgm_ops);

-- Verify indexes
SELECT
    schemaname, tablename, indexname
FROM pg_indexes
WHERE indexname LIKE '%_trgm';

COMMIT;

-- Rollback commands:
-- DROP INDEX CONCURRENTLY idx_podcast_episodes_title_trgm;
-- DROP INDEX CONCURRENTLY idx_podcast_episodes_description_trgm;
-- DROP INDEX CONCURRENTLY idx_podcast_episodes_ai_summary_trgm;

-- ============================================================================
-- PHASE 2: PERFORMANCE TUNING
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Migration 2.1: Add partial indexes for status filtering
-- ----------------------------------------------------------------------------
-- ISSUE: Full indexes include rows that are rarely queried
-- IMPACT: Smaller indexes, faster lookups for common queries
-- RISK: Low

BEGIN;

-- Index for active episodes (most common query)
CREATE INDEX CONCURRENTLY idx_podcast_episodes_active
ON podcast_episodes (subscription_id, published_at DESC)
WHERE status IN ('summarized', 'pending_summary');

-- Index for failed episodes (retry queue)
CREATE INDEX CONCURRENTLY idx_podcast_episodes_failed
ON podcast_episodes (subscription_id, updated_at DESC)
WHERE status = 'summary_failed';

-- Index for episodes with summaries (for summary-only feeds)
CREATE INDEX CONCURRENTLY idx_podcast_episodes_with_summary
ON podcast_episodes (subscription_id, published_at DESC)
WHERE ai_summary IS NOT NULL;

COMMIT;

-- ----------------------------------------------------------------------------
-- Migration 2.2: Create materialized view for user stats
-- ----------------------------------------------------------------------------
-- ISSUE: Stats queries require expensive aggregations
-- IMPACT: 95% performance improvement for stats queries
-- RISK: Medium - requires refresh strategy

BEGIN;

-- Create materialized view for user stats
CREATE MATERIALIZED VIEW mv_user_episode_stats AS
SELECT
    us.user_id,
    COUNT(DISTINCT s.id) AS total_subscriptions,
    COUNT(e.id) AS total_episodes,
    COUNT(e.id) FILTER (WHERE e.ai_summary IS NOT NULL) AS summaries_generated,
    COUNT(e.id) FILTER (WHERE e.ai_summary IS NULL) AS pending_summaries,
    COUNT(DISTINCT ps.episode_id) AS played_episodes,
    COALESCE(SUM(ps.current_position), 0) AS total_playtime_seconds,
    MAX(us.updated_at) AS last_updated
FROM user_subscriptions us
JOIN subscriptions s ON s.id = us.subscription_id AND s.source_type IN ('podcast-rss', 'rss')
LEFT JOIN podcast_episodes e ON e.subscription_id = s.id
LEFT JOIN podcast_playback_states ps ON ps.episode_id = e.id AND ps.user_id = us.user_id
WHERE us.is_archived = false
GROUP BY us.user_id;

-- Create unique index for concurrent refresh
CREATE UNIQUE INDEX idx_mv_user_episode_stats_user_id
ON mv_user_episode_stats (user_id);

-- Add comment
COMMENT ON MATERIALIZED VIEW mv_user_episode_stats IS 'Aggregated statistics for user podcast consumption. Refresh periodically via cron or trigger.';

COMMIT;

-- Refresh strategy (run via cron job every 5-10 minutes):
-- REFRESH MATERIALIZED VIEW CONCURRENTLY mv_user_episode_stats;

-- ----------------------------------------------------------------------------
-- Migration 2.3: Add indexes for transcription task queries
-- ----------------------------------------------------------------------------
-- ISSUE: Missing indexes for common task status queries
-- IMPACT: Faster task processing queries
-- RISK: Low

BEGIN;

-- Composite index for status-based task queries with ordering
CREATE INDEX CONCURRENTLY idx_transcription_tasks_status_created_priority
ON transcription_tasks (status, created_at DESC, id DESC)
WHERE status IN ('pending', 'in_progress');

-- Index for episode-specific task lookups (already exists, but verify)
-- This should already exist from the model definition

COMMIT;

-- ============================================================================
-- PHASE 3: MONITORING & MAINTENANCE
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Migration 3.1: Create monitoring views
-- ----------------------------------------------------------------------------

BEGIN;

-- View for index usage analysis
CREATE OR REPLACE VIEW v_index_usage_stats AS
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan as index_scans,
    idx_tup_read as tuples_read,
    idx_tup_fetch as tuples_fetched,
    pg_size_pretty(pg_relation_size(indexrelid)) as index_size
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY idx_scan ASC;

-- View for table size analysis
CREATE OR REPLACE VIEW v_table_size_stats AS
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS total_size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) AS table_size,
    pg_size_pretty(pg_indexes_size(schemaname||'.'||tablename)) AS indexes_size,
    (SELECT COUNT(*) FROM pg_stat_user_tables t2 WHERE t2.schemaname = t1.schemaname AND t2.tablename = t1.tablename) as index_count
FROM pg_tables t1
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- View for slow query analysis (requires pg_stat_statements)
CREATE OR REPLACE VIEW v_slow_queries AS
SELECT
    query,
    calls,
    total_exec_time / 1000 as total_time_seconds,
    mean_exec_time as avg_time_ms,
    max_exec_time as max_time_ms,
    stddev_exec_time as stddev_time_ms
FROM pg_stat_statements
WHERE query NOT LIKE '%pg_stat_statements%'
ORDER BY mean_exec_time DESC
LIMIT 20;

COMMIT;

-- ----------------------------------------------------------------------------
-- Migration 3.2: Create maintenance functions
-- ----------------------------------------------------------------------------

BEGIN;

-- Function to refresh materialized view with logging
CREATE OR REPLACE FUNCTION refresh_user_stats_mv()
RETURNS void AS $$
BEGIN
    RAISE NOTICE 'Refreshing mv_user_episode_stats at %', NOW();
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_user_episode_stats;
    RAISE NOTICE 'Refresh complete at %', NOW();
END;
$$ LANGUAGE plpgsql;

-- Function to analyze table statistics (run periodically)
CREATE OR REPLACE FUNCTION analyze_podcast_tables()
RETURNS void AS $$
BEGIN
    ANALYZE podcast_episodes;
    ANALYZE podcast_playback_states;
    ANALYZE podcast_queue_items;
    ANALYZE transcription_tasks;
    ANALYZE episode_highlights;
    ANALYZE podcast_daily_report_items;
    RAISE NOTICE 'Table statistics updated at %', NOW();
END;
$$ LANGUAGE plpgsql;

COMMIT;

-- ============================================================================
-- POST-MIGRATION VERIFICATION QUERIES
-- ============================================================================

-- Verify all indexes were created
SELECT
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexname LIKE 'idx_%'
ORDER BY tablename, indexname;

-- Check index sizes
SELECT
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) as size
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
  AND indexname LIKE 'idx_%'
ORDER BY pg_relation_size(indexrelid) DESC;

-- Verify materialized view
SELECT * FROM mv_user_episode_stats LIMIT 10;

-- Check for missing indexes on foreign keys (optional)
SELECT
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema = 'public'
  AND NOT EXISTS (
    SELECT 1 FROM pg_indexes pi
    WHERE pi.tablename = tc.table_name
      AND pi.indexdef LIKE '%' || kcu.column_name || '%'
  );

-- ============================================================================
-- CLEANUP COMMANDS (Use with caution!)
-- ============================================================================

-- Rollback all Phase 1 changes (if needed):
-- BEGIN;
-- ALTER TABLE podcast_episodes ADD COLUMN transcript_content TEXT;
-- INSERT INTO podcast_episodes (id, transcript_content)
-- SELECT episode_id, transcript_content FROM podcast_episode_transcripts;
-- DROP TABLE podcast_episode_transcripts;
-- DROP INDEX CONCURRENTLY idx_podcast_episodes_subscription_published;
-- DROP INDEX CONCURRENTLY idx_podcast_episodes_title_trgm;
-- DROP INDEX CONCURRENTLY idx_podcast_episodes_description_trgm;
-- DROP INDEX CONCURRENTLY idx_podcast_episodes_ai_summary_trgm;
-- COMMIT;

-- Rollback all Phase 2 changes (if needed):
-- BEGIN;
-- DROP INDEX CONCURRENTLY idx_podcast_episodes_active;
-- DROP INDEX CONCURRENTLY idx_podcast_episodes_failed;
-- DROP INDEX CONCURRENTLY idx_podcast_episodes_with_summary;
-- DROP MATERIALIZED VIEW IF EXISTS mv_user_episode_stats;
-- DROP FUNCTION IF EXISTS refresh_user_stats_mv();
-- DROP FUNCTION IF EXISTS analyze_podcast_tables();
-- DROP VIEW IF EXISTS v_index_usage_stats;
-- DROP VIEW IF EXISTS v_table_size_stats;
-- DROP VIEW IF EXISTS v_slow_queries;
-- COMMIT;
