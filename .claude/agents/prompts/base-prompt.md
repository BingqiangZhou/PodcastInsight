---
name: "Base Agent Prompt"
description: "Shared knowledge base and project context for all agents"
version: "1.1.0"
language_policy: "bilingual"
---

# PodcastInsight — Base Agent Prompt

## 🌐 Language Policy / 语言政策

**MANDATORY: This project follows a strict bilingual (Chinese/English) policy**

**必须：本项目严格遵循中英文双语政策**

### Core Language Rules / 核心语言规则

1. **Response Language Matching / 回复语言匹配**
   ```yaml
   rule: "MUST respond in the same language as user input"
   中文输入 → 中文回复
   English input → English response
   Mixed input → Match primary language or ask for clarification
   ```

2. **Inter-Agent Communication / Agent 间通信**
   ```yaml
   rule: "Maintain language consistency across workflow"
   Match the language of the original task/request
   Status updates match requirement document language
   ```

3. **Documentation Language / 文档语言**
   ```yaml
   Code comments: Team's primary language
   API docs: English primary, Chinese translations as needed
   User-facing text: Must support both languages
   Error messages: Bilingual format (en + zh)
   ```

### Implementation Standards / 实现标准

#### Backend Error Response Format
```python
class ErrorResponse(BaseModel):
    """Standard bilingual error response / 标准双语错误响应"""
    error_code: str
    message_en: str  # English message / 英文消息
    message_zh: str  # Chinese message / 中文消息
    detail: Optional[str] = None
```

---

## Project Overview

You are working on the **PodcastInsight** project, a podcast ranking monitor + transcription + AI summarization web platform. The system fetches podcast rankings from xyzrank.com, monitors RSS feeds for new episodes, transcribes audio via Whisper, and generates AI-powered summaries.

## Tech Stack Summary

### Backend
- **Framework**: FastAPI (Python 3.11+)
- **Database**: PostgreSQL 15+
- **Caching**: Redis 7+ (cache + Celery broker)
- **Task Queue**: Celery 5 (background tasks)
- **ORM**: SQLAlchemy 2.0 async (asyncpg driver)
- **API Documentation**: OpenAPI/Swagger
- **Package Manager**: uv (NEVER pip)

### Frontend
- **Framework**: Next.js 15 (App Router)
- **Language**: React 19 + TypeScript 5
- **Styling**: TailwindCSS 4
- **Components**: shadcn/ui
- **Server State**: TanStack Query v5
- **Client State**: Zustand
- **Icons**: Lucide
- **Toasts**: Sonner

### Infrastructure
- **Deployment**: Docker Compose (5 services)
- **Reverse Proxy**: nginx (optional, for production)
- **Monitoring**: Structured logging with correlation IDs

### AI/ML
- **Transcription**: OpenAI Whisper API / faster-whisper
- **Summarization**: OpenAI / DeepSeek / OpenRouter (configurable)
- **RSS Parsing**: feedparser

## Architecture: Domain-Driven Design (DDD)

### Core Principles
1. **Ubiquitous Language**: All code uses domain-specific terminology
2. **Bounded Contexts**: Each domain has clear boundaries and interfaces
3. **Domain Entities**: Business logic lives in domain models, not services
4. **Application Services**: Coordinate use cases between domains
5. **Infrastructure Concerns**: Separated from business logic

### Domain Boundaries
- **Podcast**: Fetching, ranking, episode monitoring from xyzrank.com + RSS feeds
- **Transcription**: Audio transcription via Whisper
- **Summary**: AI summarization with configurable LLM providers
- **Settings**: API key management, provider configuration

### Layer Structure (per domain)
```
domains/{domain}/
├── models.py       # SQLAlchemy models
├── schemas.py      # Pydantic schemas
├── repository.py   # Data access layer
├── service.py      # Business logic
├── routes.py       # API endpoints
└── tasks.py        # Celery background tasks
```

## Collaboration Principles

### Inter-Agent Communication
1. **Always clarify ambiguous requirements** before starting work
2. **Document assumptions** when making design decisions
3. **Provide context** for code changes (why, not just what)
4. **Consider cross-domain impacts** when implementing features
5. **Update shared documentation** when domain knowledge changes

### Code Collaboration
1. **Follow existing patterns** and conventions
2. **Create reusable abstractions** for common operations
3. **Write self-documenting code** with clear naming
4. **Include comprehensive tests** for new functionality
5. **Consider performance implications** at scale

### Design Philosophy
- **API-first**: Design interfaces before implementations
- **Event-driven**: Use Celery tasks for async processing
- **Fail gracefully**: Handle errors without leaking details
- **Optimize for maintainability**: Clear code over clever code

## Code Quality Standards

### Python Standards
```python
# Use type hints consistently
async def process_episode(episode_id: UUID) -> Result[Episode, ProcessingError]:
    """Process an episode for transcription."""
    pass

# Follow PEP 8 naming conventions
class PodcastService:
    def __init__(self, repository: PodcastRepository):
        self._repository = repository

    async def sync_rankings(self) -> List[Podcast]:
        return await self._repository.save_all(rankings)
```

### TypeScript Standards
```typescript
// Use strict TypeScript
interface Podcast {
  id: string;
  name: string;
  rank: number;
  logoUrl: string;
  category: string;
}

// Use TanStack Query for server state
const { data, isLoading } = useQuery({
  queryKey: ['podcasts', page],
  queryFn: () => api.getPodcasts(page),
});
```

### API Design Standards
- **RESTful conventions**: GET (read), POST (create), PUT/PATCH (update), DELETE
- **HTTP status codes**: Use semantically correct status codes
- **Error responses**: Consistent error format with error codes
- **Pagination**: Use limit/offset with total count
- **Versioning**: URL-based versioning (/v1/)

### Database Standards
- **Naming**: snake_case for tables/columns, plural for tables
- **Primary Keys**: UUID for all entities
- **Timestamps**: created_at, updated_at on all tables
- **Indexes**: Add based on query patterns

### Testing Standards
- **Unit tests**: 90%+ coverage for business logic
- **Integration tests**: Critical paths through the system
- **Test structure**: Arrange-Act-Assert pattern
- **Test data**: Factories for creating test objects
- **Mocking**: Only for external dependencies

### Security Standards
- **Input validation**: Always validate/sanitize inputs
- **SQL injection**: Use parameterized queries (SQLAlchemy ORM)
- **API keys**: Encrypted at rest using Fernet
- **Sensitive data**: Never log API keys, tokens, or credentials

## Development Workflow

### Before Starting
1. Read the relevant domain documentation
2. Check for existing implementations or patterns
3. Understand the cross-domain impacts
4. Create/update tests as needed

### During Development
1. Write failing tests first (TDD when possible)
2. Implement the minimum viable solution
3. Refactor for clarity and maintainability
4. Add logging at appropriate levels
5. Consider edge cases and error conditions

### Before Completing
1. Run all tests and ensure they pass
2. Check for TODO comments and address them
3. Verify code follows project standards
4. Update documentation if needed
5. Consider if the implementation is testable

## Common Patterns

### Repository Pattern
```python
class PodcastRepository:
    async def save(self, podcast: Podcast) -> Podcast:
        pass

    async def find_by_id(self, id: UUID) -> Optional[Podcast]:
        pass

    async def find_tracked(self) -> List[Podcast]:
        pass
```

### Service Layer Pattern
```python
class PodcastService:
    def __init__(self, repository: PodcastRepository, celery_app: Celery):
        self._repository = repository
        self._celery = celery_app

    async def sync_rankings(self) -> int:
        rankings = await fetch_xyzrank_rankings()
        saved = await self._repository.save_all(rankings)
        return len(saved)
```

### Celery Task Pattern
```python
@celery_app.task(bind=True, max_retries=3)
def transcribe_episode(self, episode_id: str):
    """Background task for audio transcription."""
    try:
        result = transcribe_audio(episode_id)
        update_transcript(episode_id, result)
    except Exception as exc:
        raise self.retry(exc=exc, countdown=60)
```

Remember: You are part of a team of specialized agents. Always consider how your work affects other domains and communicates with other agents through well-defined interfaces.
