---
name: "Base Agent Prompt"
description: "Shared knowledge base and project context for all agents"
version: "1.0.0"
language_policy: "bilingual"
---

# Personal AI Assistant - Base Agent Prompt

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

#### Frontend i18n Requirements
```dart
// All UI text must be externalized / 所有 UI 文本必须外部化
class AppLocalizations {
  static const Map<String, Map<String, String>> _translations = {
    'en': { /* English translations */ },
    'zh': { /* Chinese translations */ },
  };
}
```

### Validation Checklist / 验证清单
- [ ] Response language matches user input language
- [ ] 回复语言与用户输入语言匹配
- [ ] Error messages include both English and Chinese
- [ ] 错误消息包含中英文
- [ ] User-facing text supports language switching
- [ ] 面向用户的文本支持语言切换

---

## Project Overview

You are working on the **Personal AI Assistant** project, a comprehensive personal knowledge management and AI assistant platform. This project aims to create an intelligent system that helps users organize, retrieve, and interact with their personal knowledge base through natural language conversations and multimedia content.

## Tech Stack Summary

### Backend
- **Framework**: FastAPI (Python 3.11+)
- **Database**: PostgreSQL 15+
- **Caching**: Redis 7+
- **Authentication**: JWT with refresh tokens
- **API Documentation**: OpenAPI/Swagger

### Frontend
- **Framework**: Flutter 3.x
- **State Management**: Provider/Bloc
- **Navigation**: GoRouter
- **Local Storage**: Hive/SQLite

### Infrastructure
- **Deployment**: Docker containers
- **Message Queue**: Redis Pub/Sub
- **File Storage**: Local filesystem (with cloud storage abstraction)
- **Monitoring**: Structured logging with correlation IDs

### AI/ML
- **Embeddings**: OpenAI/Sentence Transformers
- **Vector Database**: pgvector (PostgreSQL extension)
- **LLM Integration**: OpenAI API

## Architecture: Domain-Driven Design (DDD)

### Core Principles
1. **Ubiquitous Language**: All code uses domain-specific terminology
2. **Bounded Contexts**: Each domain has clear boundaries and interfaces
3. **Domain Entities**: Business logic lives in domain models, not services
4. **Application Services**: Coordinate use cases between domains
5. **Infrastructure Concerns**: Separated from business logic

### Layer Structure
```
├── domain/           # Business logic, entities, value objects
├── application/      # Use cases, application services
├── infrastructure/   # External dependencies, persistence
└── presentation/     # API controllers, DTOs
```

### Domain Boundaries
- **User Management**: Authentication, profiles, preferences
- **Subscription**: Billing, plans, access control
- **Knowledge**: Documents, folders, categorization
- **Assistant**: Conversations, AI interactions, context
- **Multimedia**: Images, videos, audio processing

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
- **Event-driven**: Use events for cross-domain communication
- **Fail gracefully**: Handle errors without leaking details
- **Optimize for maintainability**: Clear code over clever code

## Code Quality Standards

### Python Standards
```python
# Use type hints consistently
def process_document(document_id: UUID) -> Result[Document, ProcessingError]:
    """Process a document and return enhanced version."""
    pass

# Follow PEP 8 naming conventions
class DocumentService:
    def __init__(self, repository: DocumentRepository):
        self._repository = repository

    async def create_document(self, data: CreateDocumentDto) -> Document:
        return await self._repository.save(data.to_entity())
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
- **Soft Deletes**: deleted_at instead of physical deletion where appropriate
- **Indexes**: Add based on query patterns

### Testing Standards
- **Unit tests**: 90%+ coverage for business logic
- **Integration tests**: Critical paths through the system
- **Test structure**: Arrange-Act-Assert pattern
- **Test data**: Factories for creating test objects
- **Mocking**: Only for external dependencies

### Security Standards
- **Input validation**: Always validate/sanitize inputs
- **SQL injection**: Use parameterized queries
- **Authentication**: JWT tokens with proper expiration
- **Authorization**: Check permissions at domain boundaries
- **Sensitive data**: Never log passwords, tokens, or PII

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
class DocumentRepository(ABC):
    async def save(self, document: Document) -> Document:
        pass

    async def find_by_id(self, id: UUID) -> Optional[Document]:
        pass

    async def find_by_user(self, user_id: UUID) -> List[Document]:
        pass
```

### Service Layer Pattern
```python
class DocumentService:
    def __init__(self, repository: DocumentRepository, event_bus: EventBus):
        self._repository = repository
        self._event_bus = event_bus

    async def create_document(self, data: CreateDocumentDto) -> Document:
        document = Document.create(data)
        saved = await self._repository.save(document)
        await self._event_bus.publish(DocumentCreated(saved))
        return saved
```

### Error Handling Pattern
```python
class DocumentNotFoundError(Exception):
    pass

async def get_document(document_id: UUID) -> Document:
    document = await repository.find_by_id(document_id)
    if not document:
        raise DocumentNotFoundError(f"Document {document_id} not found")
    return document
```

Remember: You are part of a team of specialized agents. Always consider how your work affects other domains and communicates with other agents through well-defined interfaces.