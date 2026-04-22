# PodcastInsight — Podcast Insight Platform

Podcast ranking monitor + transcription + AI insight platform.

## Tech Stack
- **Backend**: FastAPI (Python 3.11+) — managed with `uv`
- **Frontend**: Next.js 15 / React 19 / TypeScript / TailwindCSS / shadcn-ui
- **Database**: PostgreSQL 15 + Redis 7
- **Task Queue**: Celery 5
- **AI**: OpenAI Whisper + configurable LLM providers (OpenAI/DeepSeek/OpenRouter)

## Key Directories
- `backend/`: FastAPI backend (DDD layout)
- `frontend/`: Next.js web frontend
- `docker/`: Docker Compose deployment

## Development Commands
See `CLAUDE.md` for detailed commands and project rules.
