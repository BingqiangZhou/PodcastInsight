# Personal AI Assistant

[![Version](https://img.shields.io/badge/version-0.51.0-blue)](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.51.0)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Python](https://img.shields.io/badge/python-3.11+-blue)](https://www.python.org/)
[![Dart](https://img.shields.io/badge/dart-3.8+-cyan)](https://dart.dev/)
[![Docker](https://img.shields.io/badge/docker-supported-blue)](https://www.docker.com/)

一个可扩展的私人 AI 助手，集成了播客订阅、音频播放和 AI 功能。旨在通过本地化部署和 AI 能力，打造个人化的信息处理中心。

**当前版本: [v0.51.0](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.51.0)** (2026-04-21)

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
- 独立认证体系（2FA、CSRF 保护、服务端渲染 HTML）

### 发现与浏览
- Apple Podcasts 排行榜浏览
- 分类浏览、国家/地区选择
- 搜索与排行榜双标签页
- 响应式网格布局

### 离线与下载
- 离线连接状态感知（ConnectivityProvider）
- 后台下载管理（Drift SQLite 持久化）
- 下载列表页面

### 平台集成
- macOS Spotlight 索引
- Android/iOS 主屏幕 Widget
- 6 平台支持：Android, iOS, Web, macOS, Windows, Linux

### 用户界面
- Material 3 设计，中英文国际化
- 14 个 `.adaptive()` 自适应控件（Cupertino/Material 自动切换）
- CustomAdaptiveNavigation（非 flutter_adaptive_scaffold）
- 响应式断点：mobile <600 | tablet 600-1200 | desktop >=1200
- 骨架屏加载、平台感知页面过渡动画

## 技术架构

### 后端 (Python FastAPI)
- **框架**: FastAPI + Uvicorn/Gunicorn
- **包管理**: uv
- **数据库**: PostgreSQL 15 + SQLAlchemy 2.0 (Async)
- **缓存/消息队列**: Redis 7
- **异步任务**: Celery 5.x + Celery Beat（default + transcription 双队列）
- **数据迁移**: Alembic（23 个迁移文件）
- **架构**: DDD (Domain-Driven Design)

```
backend/app/
├── bootstrap/      # 应用初始化（路由注册、生命周期、缓存预热）
├── core/           # 核心基础设施（配置、安全、数据库、中间件、可观测性）
├── shared/         # 共享层（repository helpers, schemas, retry_utils, time_utils）
├── http/           # HTTP 辅助（错误处理、路由装饰器）
├── admin/          # 管理面板（独立认证、2FA、CSRF、服务端渲染）
└── domains/        # 领域层
    ├── user/           # 用户认证、会话管理、密码重置
    ├── subscription/   # 播客订阅管理、OPML 导入导出
    ├── podcast/        # 播客元数据、剧集、播放队列、转录、摘要
    ├── ai/             # AI 模型配置、供应商管理、文本生成
    ├── media/          # 音频转录（Whisper）、任务调度
    └── content/        # 日报、高亮、摘要、对话（预留）
```

### 前端 (Flutter)
- **框架**: Flutter (Dart 3.8+)
- **UI**: Material 3 Design System + CupertinoTheme
- **状态管理**: Riverpod 3.x
- **路由**: GoRouter (StatefulShellRoute)
- **网络**: Dio + Retrofit（ETag 缓存、Token 刷新、重试）
- **本地数据库**: Drift (SQLite) — 下载、播放进度、剧集缓存
- **本地存储**: SharedPreferences + flutter_secure_storage
- **代码生成**: build_runner（@riverpod, @JsonSerializable, @RestApi, Drift）
- **音频**: audioplayers + audio_service
- **平台**: Android, iOS, Windows, Linux, macOS, Web

```
frontend/lib/
├── core/           # 核心层
│   ├── app/              # 应用入口配置
│   ├── constants/        # AppSpacing, AppRadius, AppDurations, Breakpoints, ScrollConstants
│   ├── database/         # Drift ORM（AppDatabase, DownloadDao, PlaybackDao, EpisodeCacheDao）
│   ├── events/           # 事件总线（ServerConfigEvents）
│   ├── localization/     # 国际化（中/英 ARB）
│   ├── network/          # Dio 客户端（ETag 缓存、Token 刷新、重试）
│   ├── offline/          # ConnectivityProvider（离线感知）
│   ├── platform/         # 平台适配（页面过渡、自适应控件、触觉反馈）
│   ├── providers/        # 全局 Providers
│   ├── router/           # GoRouter 路由配置
│   ├── services/         # 缓存、更新检查、下载、Home Widget、Spotlight
│   ├── storage/          # SharedPreferences + SecureStorage
│   ├── theme/            # AppTheme, AppColors (design tokens), CupertinoTheme
│   ├── utils/            # AppLogger, Debounce, URL 规范化, 资源清理
│   └── widgets/          # 通用组件
│       ├── adaptive/     # 14 个 .adaptive() 自适应控件
│       └── ...           # CustomAdaptiveNavigation, 对话框, 骨架屏
├── shared/         # 共享层
│   ├── models/           # PaginatedState, GitHubRelease
│   └── widgets/          # EmptyState, Loading, Skeleton, SettingsSectionCard
└── features/       # 功能模块
    ├── auth/             # 认证（data/domain/presentation 三层架构）
    ├── home/             # 主页（StatefulShellRoute 外壳）
    ├── podcast/          # 播客（最大模块，core/data/presentation）
    │   └── presentation/widgets/discover/  # 排行榜、分类浏览
    ├── profile/          # 个人中心（订阅、历史、缓存管理子页面）
    ├── settings/         # 设置（外观、更新检查）
    └── splash/           # 启动页
```

## 快速开始

### 前置要求
- Docker & Docker Compose（运行 PostgreSQL、Redis）
- Python 3.11+
- uv（包管理）
- Flutter (Dart 3.8+)

### 1. 启动基础设施

6 个 Docker 服务：postgres (PostgreSQL 15)、redis (Redis 7)、backend (FastAPI)、celery_worker (异步任务)、celery_beat (定时调度)、nginx (反向代理 + SSL)。

```bash
cd docker
docker compose up -d --build
```

详细部署指南: [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) | [docker/README.md](docker/README.md)

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

## CI/CD

GitHub Actions 自动化发布流程（`.github/workflows/release.yml`）：

- **触发**: 推送 `v*.*.*` 标签或手动触发
- **构建**: 7 个 Job — 准备版本、Android (APK)、Windows、Linux、macOS (DMG)、iOS (IPA)
- **发布**: 自动创建 GitHub Release，附带各平台构建产物

## 文档导航

| 文档 | 说明 |
|------|------|
| [CHANGELOG.md](CHANGELOG.md) | 版本更新日志 |
| [CLAUDE.md](CLAUDE.md) | Claude Code 开发规范 |
| [AGENTS.md](AGENTS.md) | AI Agent 协作规范 |
| [docs/FEATURES.md](docs/FEATURES.md) | 功能特性详细说明 |
| [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) | 部署指南 |
| [docs/ANDROID_SIGNING.md](docs/ANDROID_SIGNING.md) | Android 签名配置 |
| [docs/GITHUB_ACTIONS_GUIDE.md](docs/GITHUB_ACTIONS_GUIDE.md) | GitHub Actions 使用指南 |
| [docs/RELEASE_QUICK_REF.md](docs/RELEASE_QUICK_REF.md) | 发布快速参考 |
| [backend/README.md](backend/README.md) | 后端开发指南 |
| [frontend/README.md](frontend/README.md) | Flutter 开发指南 |
| [specs/](specs/) | 功能规格说明 |

## 测试

### 后端测试（51 个测试文件）
```bash
cd docker && docker compose build backend
cd backend && uv run ruff check .
uv run pytest
```
测试组织：`tests/core/`（安全、日志、Redis）、`tests/podcast/`（18 文件）、`tests/tasks/`（5 文件）、`tests/integration/`（完整流程）、`tests/admin/`（3 文件）

### 前端测试（95 个测试文件）
```bash
flutter test                          # 全部测试
flutter test test/unit/               # 单元测试（~50 文件）
flutter test test/widget/             # Widget 测试（~36 文件）
flutter test test/integration/        # 集成测试（2 文件）
```

## 项目结构

```
personal-ai-assistant/
├── backend/          # FastAPI 后端（256 Python 源文件，51 测试文件）
├── frontend/         # Flutter 前端（242 Dart 源文件，95 测试文件）
├── docker/           # Docker 配置（6 服务 + Nginx + SSL）
├── docs/             # 详细文档 + superpowers 技能规范
├── specs/            # 功能规格（completed / active）
├── scripts/          # 工具脚本（init.sql, test_auth_api.sh, verify-optimizations.sh）
├── data/             # 密钥存储
├── .claude/          # Claude Code 配置（agents, commands, skills）
├── .github/          # GitHub Actions（release.yml）
├── CLAUDE.md         # Claude Code 开发规范
├── AGENTS.md         # AI Agent 协作规范
├── CHANGELOG.md      # 更新日志（git-cliff 生成）
├── cliff.toml        # Changelog 生成配置
└── README.md         # 项目说明
```

## 许可证

MIT License
