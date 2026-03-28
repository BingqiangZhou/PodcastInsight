# Personal AI Assistant

[![Version](https://img.shields.io/badge/version-0.34.1-blue)](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.34.1)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Python](https://img.shields.io/badge/python-3.11+-blue)](https://www.python.org/)
[![Dart](https://img.shields.io/badge/dart-3.8+-cyan)](https://dart.dev/)
[![Docker](https://img.shields.io/badge/docker-supported-blue)](https://www.docker.com/)

一个可扩展的私人 AI 助手，集成了播客订阅、音频播放和 AI 功能。旨在通过本地化部署和 AI 能力，打造个人化的信息处理中心。

**当前版本: [v0.34.1](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.34.1)** (2026-03-28)

## 更新日志

📋 **[CHANGELOG.md](CHANGELOG.md)** - 查看完整的版本更新历史和新功能说明

## 功能特性

### 用户认证与会话
- 邮箱注册登录，JWT 双 Token 机制
- 多设备会话管理，查看设备信息和 IP
- 基于邮件的密码重置

### 播客管理
- RSS Feed 订阅，自动解析播客元数据
- 可配置的自动抓取频率（每小时/每日/每周）
- 批量创建、删除订阅
- 分类管理、OPML 导入导出
- 懒加载分页、多维度筛选、全文搜索

### 音频播放
- 基于 audioplayers 的完整播放器
- 播放/暂停、快进/快退、进度条拖动
- 后台播放，系统锁屏媒体控制
- 播放进度记录和恢复

### 播放增强
- 播放队列管理（添加、重新排序、自动推进）
- 播放历史追踪，断点续播
- 个性化播放速度（每用户、每订阅独立）
- 收听统计（时长、播放次数）

### AI 功能
- 音频转录（支持 OpenAI Whisper）
- AI 摘要生成
- AI 对话（与 AI 讨论单集内容，多会话支持）
- 转录调度（为新单集自动调度转录）
- 批量转录

### AI 模型配置
- 多供应商支持（OpenAI、Anthropic、DeepSeek 等）
- API Key 加密存储（RSA + Fernet）
- 连接测试和使用统计

### 管理面板
- 仪表盘、系统统计
- 订阅管理、API 密钥管理
- 用户审计日志、系统设置

### 用户界面
- Material 3 设计
- 自适应布局（桌面/平板/移动端）
- 中英文国际化

## 技术架构

### 后端 (Python FastAPI)
- **框架**: FastAPI + Uvicorn/Gunicorn
- **包管理**: uv
- **数据库**: PostgreSQL 15 + SQLAlchemy 2.0 (Async)
- **缓存/消息队列**: Redis 7
- **异步任务**: Celery 5.x + Celery Beat
- **数据迁移**: Alembic
- **架构**: DDD (Domain-Driven Design)

```
backend/app/
├── bootstrap/      # 应用初始化（路由注册、生命周期、缓存预热）
├── core/           # 核心基础设施（配置、安全、数据库、中间件、可观测性）
├── shared/         # 共享层（schemas、utils、constants）
├── domains/        # 领域层（user、subscription、podcast、ai、admin）
└── contexts/       # DDD 限界上下文（content、ingestion、playback）[重构中]
```

### 前端 (Flutter)
- **框架**: Flutter (Dart 3.8+)
- **UI**: Material 3 Design System
- **状态管理**: Riverpod 3.x
- **路由**: GoRouter (StatefulShellRoute)
- **网络**: Dio + Retrofit
- **本地存储**: SharedPreferences + flutter_secure_storage
- **音频**: audioplayers + audio_service
- **平台**: Android, iOS, Windows, Linux, macOS, Web

```
frontend/lib/
├── core/           # 核心层（app、network、router、storage、theme、localization）
├── shared/         # 共享层（models、themes、widgets）
└── features/       # 功能模块
    ├── auth/       # 认证（data/domain/presentation）
    ├── home/       # 主页
    ├── podcast/    # 播客（core/data/presentation）
    ├── profile/    # 个人中心
    ├── settings/   # 设置
    └── splash/     # 启动页
```

## 快速开始

### 前置要求
- Docker & Docker Compose（运行 PostgreSQL、Redis）
- Python 3.11+
- uv（包管理）
- Flutter (Dart 3.8+)

### 1. 启动基础设施

```bash
cd docker
docker compose up -d --build
```

### 2. 后端开发

```bash
cd backend

# 配置环境变量
cp .env.example .env

# 安装依赖
uv sync --extra dev

# 运行数据库迁移
uv run alembic upgrade head

# 启动 API 服务
uv run uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

API 文档: http://localhost:8000/docs

### 3. 前端运行

```bash
cd frontend
flutter pub get
flutter run
```

## 文档导航

| 文档 | 说明 |
|------|------|
| [CHANGELOG.md](CHANGELOG.md) | 版本更新日志 |
| [CLAUDE.md](CLAUDE.md) | Claude Code 开发规范 |
| [AGENTS.md](AGENTS.md) | AI Agent 协作规范 |
| [docs/FEATURES.md](docs/FEATURES.md) | 功能特性详细说明 |
| [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) | 部署指南 |
| [backend/README.md](backend/README.md) | 后端开发指南 |
| [frontend/README.md](frontend/README.md) | Flutter 开发指南 |
| [backend/docs/AUTHENTICATION.md](backend/docs/AUTHENTICATION.md) | 认证系统说明 |
| [specs/](specs/) | 功能规格说明 |

## 测试要求

### 后端测试
```bash
cd docker && docker-compose build backend
cd backend && uv run ruff check .
uv run pytest
```

### 前端测试
```bash
flutter test test/widget/
```

## 项目结构

```
personal-ai-assistant/
├── backend/          # FastAPI 后端
├── frontend/         # Flutter 前端
├── docker/           # Docker 配置 (7 个服务)
├── docs/             # 详细文档
├── specs/            # 功能规格
├── scripts/          # 工具脚本
├── data/             # 密钥存储
├── CLAUDE.md         # 开发规范
├── AGENTS.md         # AI Agent 协作规范
├── CHANGELOG.md      # 更新日志
├── cliff.toml        # Changelog 生成配置
└── README.md         # 项目说明
```

## 许可证

MIT License
