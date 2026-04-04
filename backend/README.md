# Personal AI Assistant - 后端

FastAPI 后端服务，提供播客订阅、AI 转录、用户认证等功能。

## 技术栈

| 技术 | 说明 |
|------|------|
| FastAPI | 异步 Web 框架 |
| SQLAlchemy | 异步 ORM |
| PostgreSQL | 关系型数据库 |
| Redis | 缓存和消息队列 |
| Celery | 异步任务队列 |
| Alembic | 数据库迁移 |
| uv | 包管理器 |

## 快速开始

### 1. 安装依赖

```bash
cd backend
uv sync --extra dev
```

### 2. 配置环境变量

```bash
# 复制环境变量模板
cp .env.example .env

# 编辑 .env 文件，设置数据库连接、密钥等
```

必须配置：
- `DATABASE_URL` - PostgreSQL 连接字符串
- `REDIS_URL` - Redis 连接字符串
- `SECRET_KEY` - JWT 密钥

### 3. 运行数据库迁移

```bash
uv run alembic upgrade head
```

### 4. 启动服务

```bash
# API 服务
uv run uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

API 文档: http://localhost:8000/docs

## Celery 任务

### 启动 Worker

```bash
# 核心队列 (订阅同步、AI 生成、维护)
uv run celery -A app.core.celery_app:celery_app worker --loglevel=info -Q subscription_sync,ai_generation,maintenance

# 转录队列
uv run celery -A app.core.celery_app:celery_app worker --loglevel=info -Q transcription
```

### 启动调度器

```bash
uv run celery -A app.core.celery_app:celery_app beat --loglevel=info
```

## 代码质量

### 代码检查

```bash
# 代码检查
uv run ruff check .

# 代码格式化
uv run ruff format .
```

### 运行测试

```bash
# 所有测试
uv run pytest

# 指定目录
uv run pytest tests/podcast/
```

## Docker 验证

所有后端测试必须在 Docker 中运行：

```bash
# 启动 Docker 服务
cd docker
docker-compose up -d

# 验证服务
docker-compose ps
curl http://localhost:8000/api/v1/health
```

验证 Celery 服务：
- `celery_worker_core` - 核心队列
- `celery_worker_transcription` - 转录队列
- `celery_beat` - 任务调度

## 项目结构

```
backend/
├── app/
│   ├── core/           # 核心基础设施
│   │   ├── config/    # 配置管理
│   │   ├── security/  # 安全认证
│   │   ├── database/  # 数据库连接
│   │   ├── redis/    # Redis 客户端
│   │   ├── celery/   # Celery 配置
│   │   └── exceptions/ # 异常处理
│   ├── domains/        # 业务领域
│   │   ├── user/     # 用户认证
│   │   ├── podcast/  # 播客管理
│   │   ├── assistant/ # AI 对话
│   │   ├── admin/    # 管理面板
│   │   └── ai/       # AI 模型
│   └── shared/        # 共享层
├── alembic/           # 数据库迁移
├── tests/             # 测试文件
├── pyproject.toml     # 项目配置
└── uv.lock           # 依赖锁定
```

## API 说明

- API 前缀: `/api/v1`
- 管理面板: `/api/v1/admin/*`
- 认证: `/api/v1/auth/*`
- 播客订阅: `/api/v1/podcasts/subscriptions/*`
- 播客单集: `/api/v1/podcasts/episodes/*`

## 相关文档

- [环境变量配置](README-ENV.md)
- [认证系统说明](docs/AUTHENTICATION.md)
- [部署指南](../docs/DEPLOYMENT.md)
