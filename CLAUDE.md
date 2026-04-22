# PodcastInsight — Podcast Insight Platform v1.0

Podcast ranking monitor + transcription + AI summarization web platform.
Backend: Python/FastAPI/PostgreSQL/Redis/Celery. Frontend: Next.js/React/TailwindCSS/shadcn-ui.

## Architecture Overview

```
podcast-insight/
├── backend/              # Python FastAPI backend (DDD layout)
│   ├── app/
│   │   ├── main.py       # FastAPI app + lifespan
│   │   ├── core/         # Config, database, redis, security, celery
│   │   ├── domains/      # Business domains
│   │   │   ├── podcast/  # Podcast fetching, ranking, episodes
│   │   │   ├── transcription/  # Audio transcription (Whisper)
│   │   │   ├── summary/  # AI summarization
│   │   │   └── settings/ # API key management
│   │   └── shared/       # Cross-domain utilities
│   ├── alembic/          # Database migrations
│   ├── pyproject.toml
│   └── Dockerfile
├── frontend/             # Next.js web frontend
│   ├── src/
│   │   ├── app/          # Next.js App Router pages
│   │   ├── components/   # Shared UI components (shadcn)
│   │   ├── lib/          # Utilities, API client
│   │   └── types/        # TypeScript type definitions
│   ├── package.json
│   └── Dockerfile
├── docker/               # Docker Compose deployment
│   ├── docker-compose.yml
│   └── nginx/
└── CLAUDE.md
```

## Commands

### Backend (Python 3.11+, uses uv — NEVER pip)
```bash
cd backend
uv sync --extra dev                    # Install deps
uv run alembic upgrade head            # Run migrations
uv run uvicorn app.main:app --reload   # Dev server (port 8000)
uv run ruff check .                    # Lint
uv run ruff format .                   # Format
uv run pytest                          # Tests
```

### Frontend (Node 20+, pnpm)
```bash
cd frontend
pnpm install                           # Install deps
pnpm dev                               # Dev server (port 3000)
pnpm build                             # Production build
pnpm lint                              # ESLint
pnpm test                              # Vitest tests
```

### Docker (full-stack)
```bash
cd docker && docker compose up -d      # Start all services
curl http://localhost:8000/api/v1/health
```

## Tech Stack

### Backend
- FastAPI (async web framework)
- SQLAlchemy 2.0 async (asyncpg driver)
- PostgreSQL 15
- Redis 7 (cache + Celery broker)
- Celery 5 (background tasks: podcast sync, transcription, summarization)
- Alembic (migrations)
- Pydantic v2 + pydantic-settings
- aiohttp (async HTTP client)
- feedparser (RSS/podcast feed parsing)
- uv (package manager — NEVER pip)

### Frontend
- Next.js 15 (App Router)
- React 19
- TypeScript 5
- TailwindCSS 4
- shadcn/ui (component library)
- TanStack Query v5 (server state)
- Zustand (client state)
- Lucide icons
- Sonner (toast notifications)

## Core Features (v1.0 MVP)

### 1. Podcast Ranking from xyzrank.com
- Fetch top 1000 podcasts from xyzrank.com public API
- API: `GET https://xyzrank.com/api/podcasts?offset={n}&limit=50`
- Store: name, rank, logo, category, author, RSS feed URL, stats
- Daily sync via Celery beat (store ranking history for trends)

### 2. Episode Monitoring
- Parse RSS feeds via feedparser to get new episodes
- Store: title, audio_url, duration, published date, description
- Periodic check (every 6 hours) for new episodes across all tracked podcasts
- User can configure which podcasts to track (subscribe/favorite)

### 3. Audio Transcription
- Download audio → ffmpeg chunking → OpenAI Whisper API
- Background Celery task with retry logic
- Status tracking: pending → processing → completed/failed
- Configurable Whisper model via settings

### 4. AI Summarization
- Generate episode summaries using configured LLM API
- Support: OpenAI, DeepSeek, OpenRouter, custom OpenAI-compatible endpoints
- Summary includes: key topics, highlights, takeaways
- Background processing with status tracking

### 5. API Key Management
- CRUD for AI provider API keys (encrypted at rest)
- Support multiple providers: OpenAI, DeepSeek, OpenRouter, custom
- Per-provider: API key, base URL, default model, temperature, max tokens
- Test connectivity endpoint
- Frontend settings page for management

### 6. Web Frontend
- Dashboard: podcast rankings, recent episodes, processing status
- Podcast detail: episode list with transcription/summary status
- Episode detail: transcript viewer + summary display
- Settings: API key management, system configuration
- Responsive design (mobile + desktop)

## Database Schema (Key Tables)

```sql
-- Podcasts synced from xyzrank.com
podcasts (id, xyzrank_id, name, rank, logo_url, category, author,
          rss_feed_url, track_count, avg_duration, avg_play_count,
          last_synced_at, is_tracked, created_at, updated_at)

-- Ranking history for trend tracking
podcast_ranking_history (id, podcast_id, rank, avg_play_count, recorded_at)

-- Episodes from RSS feeds
episodes (id, podcast_id, title, description, audio_url, duration,
          published_at, transcript_status, summary_status,
          created_at, updated_at)

-- Transcripts
transcripts (id, episode_id, content, language, word_count,
             model_used, created_at)

-- Summaries
summaries (id, episode_id, content, key_topics, highlights,
           model_used, provider, created_at)

-- AI Provider configs (encrypted API keys)
ai_provider_configs (id, provider_name, base_url, encrypted_api_key,
                     is_default, created_at, updated_at)
ai_model_configs (id, provider_id, model_name, temperature, max_tokens,
                  is_default, created_at)
```

## API Endpoints

```
# Podcasts
GET    /api/v1/podcasts              # List podcasts (paginated, filterable)
GET    /api/v1/podcasts/{id}         # Podcast detail
GET    /api/v1/podcasts/rankings     # Current rankings
POST   /api/v1/podcasts/{id}/track   # Start tracking a podcast
DELETE /api/v1/podcasts/{id}/track   # Stop tracking

# Episodes
GET    /api/v1/episodes              # List episodes (paginated, filterable)
GET    /api/v1/episodes/{id}         # Episode detail with transcript/summary
POST   /api/v1/episodes/{id}/transcribe   # Trigger transcription
POST   /api/v1/episodes/{id}/summarize    # Trigger summarization

# Transcripts
GET    /api/v1/episodes/{id}/transcript   # Get transcript

# Summaries
GET    /api/v1/episodes/{id}/summary      # Get summary

# Settings / API Keys
GET    /api/v1/settings/providers         # List AI providers
POST   /api/v1/settings/providers         # Create provider
PUT    /api/v1/settings/providers/{id}    # Update provider
DELETE /api/v1/settings/providers/{id}    # Delete provider
POST   /api/v1/settings/providers/{id}/test  # Test provider connection

# System
GET    /api/v1/health                    # Health check
POST   /api/v1/sync/rankings             # Trigger manual ranking sync
POST   /api/v1/sync/episodes             # Trigger manual episode sync
```

## Conventions

### Backend
- **uv only** (NEVER pip). **ruff only** for lint/format
- All I/O is async (SQLAlchemy async, aiohttp, redis async)
- DDD structure: domains/{domain}/models.py, schemas.py, repository.py, service.py, routes.py, tasks.py
- Celery queues: `default` (sync tasks), `transcription` (audio processing), `summary` (AI summarization)
- API keys encrypted at rest using Fernet

### Frontend
- Next.js App Router (NOT Pages Router)
- shadcn/ui components (NOT custom UI from scratch)
- TanStack Query for all server state (fetch, cache, invalidate)
- Responsive: mobile-first, desktop >=1024px sidebar layout
- Dark/light mode support

### General
- Conventional Commits: feat:, fix:, refactor:, chore:
- All API endpoints prefixed with /api/v1/

## Gotchas

| Wrong | Correct |
|-------|---------|
| `pip install` | `uv add` or `uv sync` |
| Next.js Pages Router | App Router (app/ directory) |
| Custom CSS components | shadcn/ui components |
| Fetch without TanStack Query | Use useQuery/useMutation |
| Sync DB queries | Async SQLAlchemy sessions |
| Plain text API keys | Fernet encryption at rest |
| Direct audio processing in API | Celery background task |
| Skip Docker setup | Must support docker-compose deployment |

## Deployment

### Docker Compose (4 services)
1. postgres — PostgreSQL 15-alpine
2. redis — Redis 7-alpine
3. backend — FastAPI + Celery worker + Celery beat
4. frontend — Next.js (standalone output)
5. nginx — Reverse proxy (optional, for production)

### Direct Deployment
- Backend: `uv run uvicorn app.main:app` + `celery -A app.core.celery_app worker -B`
- Frontend: `pnpm build && pnpm start` (standandalone output)
- Requires: PostgreSQL 15+, Redis 7+, Node 20+, Python 3.11+
