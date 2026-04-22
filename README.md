# PodDigest — 播客知识中心

PodDigest 是一个全栈播客知识管理平台，集成播客排行榜监控、音频转写、AI 摘要生成等功能，帮助你从播客内容中高效提取和管理知识。

## 功能特性

- **播客排行榜** — 从 xyzrank.com 同步 Top 1000 中文播客排行榜，支持订阅追踪
- **单集监控** — 通过 RSS Feed 自动发现和同步新单集，每 6 小时检查更新
- **音频转写** — 基于 faster-whisper 的本地 GPU 加速转写，支持批量处理
- **AI 摘要** — 支持 OpenAI / DeepSeek / OpenRouter 等多种 LLM 提供商，自动生成关键话题和要点摘要
- **API 密钥管理** — 加密存储多个 AI 提供商配置，前端可视化管理
- **响应式界面** — 移动端优先的中文界面，支持深色/浅色主题切换

## 技术栈

### 后端
- **Python 3.11+** / FastAPI (异步 Web 框架)
- **PostgreSQL 15** / SQLAlchemy 2.0 (异步 ORM)
- **Redis 7** (缓存 + Celery Broker)
- **Celery 5** (后台任务队列：转写、摘要、排行榜同步)
- **faster-whisper** (本地 GPU 加速音频转写，支持 CUDA)
- **Fernet** (API 密钥加密存储)

### 前端
- **Next.js 16** / React 19 / TypeScript (App Router)
- **TailwindCSS 4** / shadcn/ui (组件库)
- **TanStack Query v5** (服务端状态管理)
- **Zustand** (客户端状态管理)

### 基础设施
- **Docker Compose** 一键部署 (6 服务)
- **Nginx** 生产环境反向代理
- **Alembic** 数据库迁移

## 快速开始

### 前置要求

- Python 3.11+
- Node.js 20+ & pnpm
- PostgreSQL 15+
- Redis 7+
- NVIDIA GPU + CUDA (转写加速，可选)
- [uv](https://docs.astral.sh/uv/) Python 包管理器

### 1. 克隆项目

```bash
git clone https://github.com/your-username/personal-ai-assistant.git
cd personal-ai-assistant
```

### 2. 配置环境变量

```bash
cp .env.example .env
```

编辑 `.env` 文件，至少需要配置：

```env
# 数据库
DATABASE_URL=postgresql+asyncpg://poddigest:poddigest@localhost:5432/poddigest

# API 密钥加密密钥 (生成方式见下方)
ENCRYPTION_KEY=

# AI 提供商 (在设置页面配置也可)
OPENAI_API_KEY=
```

生成加密密钥：

```bash
python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
```

### 3. 启动后端

```bash
cd backend

# 安装依赖
uv sync --extra dev

# 运行数据库迁移
uv run alembic upgrade head

# 启动开发服务器 (端口 8000)
uv run uvicorn app.main:app --reload

# 启动 Celery Worker (新终端)
uv run celery -A app.core.celery_app worker -Q default,transcription,summary --loglevel=info

# 启动 Celery Beat 定时任务 (新终端)
uv run celery -A app.core.celery_app beat --loglevel=info
```

### 4. 启动前端

```bash
cd frontend

# 安装依赖
pnpm install

# 启动开发服务器 (端口 3000)
pnpm dev
```

访问 http://localhost:3000 即可使用。

## Docker 部署

使用 Docker Compose 一键启动全部服务：

```bash
cd docker

# 启动所有服务 (开发环境)
docker compose up -d

# 生产环境 (包含 Nginx 反向代理)
docker compose --profile production up -d

# 检查服务状态
curl http://localhost:8000/api/v1/health
```

Docker Compose 包含以下服务：

| 服务 | 说明 | 端口 |
|------|------|------|
| postgres | PostgreSQL 15 | 5432 |
| redis | Redis 7 | 6379 |
| backend | FastAPI API 服务 | 8000 |
| celery-worker | Celery 后台任务处理 | — |
| celery-beat | Celery 定时调度 | — |
| frontend | Next.js Web 界面 | 3000 |
| nginx | 反向代理 (仅生产环境) | 80 |

## 项目结构

```
personal-ai-assistant/
├── backend/                      # Python 后端 (DDD 架构)
│   ├── app/
│   │   ├── main.py               # FastAPI 应用入口
│   │   ├── core/                 # 基础设施：配置、数据库、Redis、Celery
│   │   ├── domains/              # 业务领域
│   │   │   ├── podcast/          # 播客排行榜与单集管理
│   │   │   ├── transcription/    # 音频转写 (Whisper)
│   │   │   ├── summary/          # AI 摘要生成
│   │   │   └── settings/         # AI 提供商配置管理
│   │   └── shared/               # 跨领域工具
│   ├── alembic/                  # 数据库迁移
│   ├── data/                     # 音频文件 & Whisper 模型存储
│   └── pyproject.toml
├── frontend/                     # Next.js 前端
│   ├── src/
│   │   ├── app/                  # App Router 页面
│   │   ├── components/           # UI 组件 (shadcn/ui)
│   │   ├── lib/                  # API 客户端、工具函数
│   │   └── types/                # TypeScript 类型定义
│   └── package.json
├── docker/                       # Docker Compose 部署
│   ├── docker-compose.yml
│   └── nginx/                    # Nginx 配置
└── .env.example                  # 环境变量模板
```

## API 概览

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/v1/health` | 健康检查 |
| GET | `/api/v1/podcasts` | 播客列表 (分页、筛选) |
| GET | `/api/v1/podcasts/{id}` | 播客详情 |
| POST | `/api/v1/podcasts/{id}/track` | 订阅追踪 |
| GET | `/api/v1/episodes` | 单集列表 |
| GET | `/api/v1/episodes/{id}` | 单集详情 (含转写/摘要) |
| POST | `/api/v1/episodes/{id}/transcribe` | 触发转写 |
| POST | `/api/v1/episodes/{id}/summarize` | 触发摘要 |
| GET | `/api/v1/settings/providers` | AI 提供商列表 |
| POST | `/api/v1/settings/providers` | 新增提供商 |
| POST | `/api/v1/settings/providers/{id}/test` | 测试连接 |
| POST | `/api/v1/sync/rankings` | 手动同步排行榜 |
| POST | `/api/v1/sync/episodes` | 手动同步单集 |

## 开发指南

### 后端开发

```bash
cd backend
uv run ruff check .      # 代码检查
uv run ruff format .     # 代码格式化
uv run pytest            # 运行测试
```

### 前端开发

```bash
cd frontend
pnpm lint                # ESLint 检查
pnpm test                # Vitest 测试
pnpm build               # 生产构建
```

### 注意事项

- 后端使用 **uv** 管理依赖，不要使用 pip
- 前端使用 **App Router**，不是 Pages Router
- UI 组件使用 **shadcn/ui**，不要从零编写
- 数据查询使用 **TanStack Query**，不要直接 fetch
- API 密钥使用 **Fernet 加密** 存储，不要明文保存
- 音频处理等耗时任务通过 **Celery** 异步执行

## License

MIT
