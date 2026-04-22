# Release Process Enhancement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enhance the release process with multi-arch Docker builds, release highlights, upgrade guides, and Docker version sync.

**Architecture:** Modify 3 files — docker-compose.yml gets GHCR image directives, release command gets highlights + Docker sync steps, release workflow gets multi-arch + upgrade guide injection.

**Tech Stack:** Docker Buildx + QEMU, GitHub Actions, git-cliff, Claude Code slash commands

---

### Task 1: Add GHCR image directives to docker-compose.yml

**Files:**
- Modify: `docker/docker-compose.yml`

- [ ] **Step 1: Add `image` directives to backend, celery-worker, celery-beat, frontend services**

In `docker/docker-compose.yml`, add an `image` line after each `build` block for the 4 services that use project-built images:

```yaml
# backend service (after build block, before container_name)
backend:
  build:
    context: ../backend
    dockerfile: Dockerfile
  image: ghcr.io/bingqiangzhou/podcast-insight/backend:${VERSION:-latest}

# celery-worker service (after build block, before container_name)
celery-worker:
  build:
    context: ../backend
    dockerfile: Dockerfile
  image: ghcr.io/bingqiangzhou/podcast-insight/backend:${VERSION:-latest}

# celery-beat service (after build block, before container_name)
celery-beat:
  build:
    context: ../backend
    dockerfile: Dockerfile
  image: ghcr.io/bingqiangzhou/podcast-insight/backend:${VERSION:-latest}

# frontend service (after build block, before container_name)
frontend:
  build:
    context: ../frontend
    dockerfile: Dockerfile
  image: ghcr.io/bingqiangzhou/podcast-insight/frontend:${VERSION:-latest}
```

Key points:
- `celery-worker` and `celery-beat` share the `backend` image (same Dockerfile)
- GHCR requires lowercase paths
- `${VERSION:-latest}` defaults to `latest`, overridable via environment variable

- [ ] **Step 2: Verify YAML syntax**

Run: `cd docker && docker compose config`
Expected: No parse errors. Output shows 4 services with `image: ghcr.io/...` lines.

- [ ] **Step 3: Commit**

```bash
git add docker/docker-compose.yml
git commit -m "feat(docker): add GHCR image directives for backend and frontend services

Enable pulling pre-built images from GitHub Container Registry.
celery-worker and celery-beat share the backend image.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 2: Rewrite release command with Highlights and Docker version sync

**Files:**
- Modify: `.claude/commands/release.md`

- [ ] **Step 1: Write the complete new release command**

Replace the entire content of `.claude/commands/release.md` with:

```markdown
---
name: /release
description: 发布新版本 - 编写Highlights、生成CHANGELOG、更新版本号和Docker镜像、创建tag并推送
usage: /release <version>
example: /release 1.1.0
---

# Release Workflow Command

当收到 `/release <版本号>` 命令时，按以下步骤自动执行发布流程：

## 步骤 0: 编写 Release Highlights

向用户询问本次版本的亮点摘要（1-3 段文字），内容应包含：
- 本次发布的一句话核心总结
- 关键新功能、改进或修复的主题叙述

如果用户跳过此步骤（回复 skip 或留空），则自动从 `git log` 中提取自上一个 tag 以来的 `feat:` 类型 commit 作为 highlights 要点。

将用户提供或自动提取的内容保存为变量 `$HIGHLIGHTS`，供后续步骤使用。

## 步骤 1: 生成 CHANGELOG

使用 `git-cliff --tag v<版本号> -o CHANGELOG.md` 生成 CHANGELOG.md。

## 步骤 1.5: 注入 Highlights 到 CHANGELOG

在生成的 CHANGELOG.md 中，找到 `## [版本号]` 标题行，在其下方（第一个 `###` 段落之前）插入 Highlights 内容，格式如下：

```markdown
> **Highlights**: <一句话核心总结>
>
> <1-2 段关于本次发布主题和关键变更的叙述文字>
```

插入完成后，Highlights 块应位于 `## [X.Y.Z]` 和第一个 `### Features` 或 `### Bug Fixes` 之间。

## 步骤 2: 更新版本号

1. 读取 `backend/pyproject.toml` 当前版本
2. 更新 `backend/pyproject.toml` 中的 version 为新版本号
3. 读取 `frontend/package.json` 当前版本
4. 更新 `frontend/package.json` 中的 version 为新版本号

## 步骤 2.5: 更新 Docker 镜像版本

更新 `docker/docker-compose.yml` 中的镜像标签：

1. 在 `backend`、`celery-worker`、`celery-beat` 服务中，将 `image` 行的 `${VERSION:-latest}` 替换为具体版本号：
   ```
   image: ghcr.io/bingqiangzhou/podcast-insight/backend:<版本号>
   ```

2. 在 `frontend` 服务中，同样替换：
   ```
   image: ghcr.io/bingqiangzhou/podcast-insight/frontend:<版本号>
   ```

注意：仅更新本项目构建的 4 个服务。postgres、redis、nginx 使用第三方镜像，不做修改。

## 步骤 3: 创建提交

创建 commit，message 格式为：
```
chore(release): update version to <版本号> and generate changelog
```

## 步骤 4: 推送提交

将提交推送到远程仓库。

## 步骤 5: 创建并推送 Tag

创建 tag（格式: v<版本号>），例如: v1.1.0
推送到远程仓库。

## 验证

推送完成后，执行以下检查确认发布状态正确：

1. 运行 `git log --oneline -1` 确认最新 commit 为本次 release commit
2. 运行 `git tag -l "v<版本号>"` 确认 tag 已创建
3. 读取 `CHANGELOG.md` 前 20 行，确认 Highlights 已注入且位于 `## [版本号]` 下方
4. 读取 `backend/pyproject.toml` 确认版本号已更新
5. 读取 `frontend/package.json` 确认版本号已更新
6. 读取 `docker/docker-compose.yml` 确认 4 个服务的 image 标签已更新为 <版本号>

如果任何验证失败，向用户报告失败项并等待指示。

## 示例

输入: `/release 1.1.0`
- Highlights: 用户输入或自动提取
- backend 版本: 1.0.0 -> 1.1.0
- frontend 版本: 1.0.0 -> 1.1.0
- docker-compose backend image: ghcr.io/bingqiangzhou/podcast-insight/backend:1.1.0
- docker-compose frontend image: ghcr.io/bingqiangzhou/podcast-insight/frontend:1.1.0
- Tag: v1.1.0
- Commit message: `chore(release): update version to 1.1.0 and generate changelog`
```

- [ ] **Step 2: Verify command structure**

Read the file and confirm it contains all 8 steps (0, 1, 1.5, 2, 2.5, 3, 4, 5) plus the verification section.

- [ ] **Step 3: Commit**

```bash
git add .claude/commands/release.md
git commit -m "feat(commands): enhance release command with highlights and docker version sync

Add Step 0 (Release Highlights), Step 1.5 (inject highlights into CHANGELOG),
Step 2.5 (update docker-compose image tags), and post-push verification.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 3: Rewrite release workflow with multi-arch builds, upgrade guide, and latest tag control

**Files:**
- Modify: `.github/workflows/release.yml`

- [ ] **Step 1: Write the complete new release workflow**

Replace the entire content of `.github/workflows/release.yml` with:

```yaml
# PodcastInsight - Release Workflow
# Triggered by pushing tags matching pattern v*.*.* (e.g., v1.0.0)
# Builds multi-arch Docker images (amd64 + arm64) and creates GitHub Release with changelog

name: Release

on:
  push:
    tags:
      - 'v*.*.*'
  workflow_dispatch:

permissions:
  contents: write
  actions: write
  packages: write

jobs:
  # ============================================
  # Job 1: Extract version and generate changelog
  # ============================================
  prepare-release:
    name: Prepare Release
    runs-on: ubuntu-latest
    outputs:
      version: ${{ steps.version.outputs.version }}
      is_prerelease: ${{ steps.version.outputs.is_prerelease }}
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Extract version from tag
        id: version
        run: |
          TAG=${{ github.ref_name }}
          VERSION=${TAG#v}

          echo "version=$VERSION" >> $GITHUB_OUTPUT

          if [[ $VERSION =~ -(alpha|beta|rc|preview)\.? ]]; then
            echo "is_prerelease=true" >> $GITHUB_OUTPUT
          else
            echo "is_prerelease=false" >> $GITHUB_OUTPUT
          fi

          echo "Version: $VERSION"

      - name: Generate changelog from CHANGELOG.md
        run: |
          VERSION="${{ steps.version.outputs.version }}"

          awk -v version="$VERSION" '
            BEGIN { found = 0; printing = 0 }
            /^## \[' version '\]/ { found = 1; printing = 1; next }
            /^## \[/ && found { printing = 0; exit }
            printing { print }
          ' CHANGELOG.md > changelog_content.md

          if [ -s changelog_content.md ]; then
            {
              cat changelog_content.md
              echo ""
              echo "**Release Date:**"
              echo "- $(date -u +'%Y-%m-%d %H:%M:%S %Z (%z)')"
              echo "- $(TZ=Asia/Shanghai date +'%Y-%m-%d %H:%M:%S %Z (%z)')"
            } > changelog.md
            rm changelog_content.md
          else
            {
              echo "## Release v$VERSION"
              echo ""
              echo "**Version not found in CHANGELOG.md.**"
              echo ""
              echo "**Version:** \`$VERSION\`"
              echo "**Release Date:**"
              echo "- $(date -u +'%Y-%m-%d %H:%M:%S %Z (%z)')"
              echo "- $(TZ=Asia/Shanghai date +'%Y-%m-%d %H:%M:%S %Z (%z)')"
            } > changelog.md
          fi

      - name: Append upgrade guide to changelog
        run: |
          {
            echo ""
            echo "---"
            echo ""
            echo "## Upgrade Guide"
            echo ""
            echo "### Docker Compose Deployment"
            echo ""
            echo "1. Backup your \`docker-compose.yml\` and \`.env\` files"
            echo "2. Pull the latest images: \`docker compose pull\`"
            echo "3. Restart services: \`docker compose down && docker compose up -d\`"
            echo ""
            echo "### Source Code Deployment"
            echo ""
            echo "1. Stop all running services"
            echo "2. Checkout the new tag: \`git checkout v${{ steps.version.outputs.version }}\`"
            echo "3. Backend: \`cd backend && uv sync && uv run alembic upgrade head\`"
            echo "4. Frontend: \`cd frontend && pnpm install && pnpm build\`"
            echo "5. Restart all services"
          } >> changelog.md

      - name: Upload changelog artifact
        uses: actions/upload-artifact@v4
        with:
          name: changelog
          path: changelog.md

  # ============================================
  # Job 2: Build and push Docker images
  # ============================================
  build-docker:
    name: Build Docker Images
    needs: prepare-release
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set up QEMU
        uses: docker/setup-qemu-action@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Docker meta for backend
        id: meta-backend
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository }}/backend
          tags: |
            type=raw,value=${{ needs.prepare-release.outputs.version }}
            type=raw,value=latest,enable=${{ needs.prepare-release.outputs.is_prerelease == 'false' }}

      - name: Build and push backend image
        uses: docker/build-push-action@v6
        with:
          context: ./backend
          push: true
          platforms: linux/amd64,linux/arm64
          tags: ${{ steps.meta-backend.outputs.tags }}
          labels: ${{ steps.meta-backend.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: Docker meta for frontend
        id: meta-frontend
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository }}/frontend
          tags: |
            type=raw,value=${{ needs.prepare-release.outputs.version }}
            type=raw,value=latest,enable=${{ needs.prepare-release.outputs.is_prerelease == 'false' }}

      - name: Build and push frontend image
        uses: docker/build-push-action@v6
        with:
          context: ./frontend
          push: true
          platforms: linux/amd64,linux/arm64
          tags: ${{ steps.meta-frontend.outputs.tags }}
          labels: ${{ steps.meta-frontend.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

  # ============================================
  # Job 3: Create GitHub Release
  # ============================================
  create-release:
    name: Create Release
    needs:
      - prepare-release
      - build-docker
    runs-on: ubuntu-latest
    if: |
      needs.prepare-release.result == 'success' &&
      needs.build-docker.result == 'success'

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Download changelog
        uses: actions/download-artifact@v4
        with:
          name: changelog
          path: .

      - name: Create Release
        uses: softprops/action-gh-release@v2
        with:
          tag_name: v${{ needs.prepare-release.outputs.version }}
          name: PodcastInsight v${{ needs.prepare-release.outputs.version }}
          body_path: changelog.md
          draft: false
          prerelease: ${{ needs.prepare-release.outputs.is_prerelease }}
          generate_release_notes: true
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Release Summary
        run: |
          echo "### Release Created Successfully!" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "**Version:** v${{ needs.prepare-release.outputs.version }}" >> $GITHUB_STEP_SUMMARY
          echo "**Prerelease:** ${{ needs.prepare-release.outputs.is_prerelease }}" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "#### Docker Images:" >> $GITHUB_STEP_SUMMARY
          echo "- \`ghcr.io/${{ github.repository }}/backend:${{ needs.prepare-release.outputs.version }}\`" >> $GITHUB_STEP_SUMMARY
          echo "- \`ghcr.io/${{ github.repository }}/frontend:${{ needs.prepare-release.outputs.version }}\`" >> $GITHUB_STEP_SUMMARY
          if [ "${{ needs.prepare-release.outputs.is_prerelease }}" = "false" ]; then
            echo "" >> $GITHUB_STEP_SUMMARY
            echo "#### Also tagged as \`latest\`" >> $GITHUB_STEP_SUMMARY
          fi
```

- [ ] **Step 2: Verify YAML syntax**

Run: `python -c "import yaml; yaml.safe_load(open('.github/workflows/release.yml')); print('YAML valid')"`
Expected: `YAML valid`

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "feat(ci): multi-arch builds, conditional latest tag, upgrade guide in release workflow

- Add QEMU + Buildx for linux/amd64 + linux/arm64 multi-arch Docker builds
- Use docker/metadata-action for conditional latest tag (stable only)
- Inject templated upgrade guide into release notes
- Upgrade build-push-action from v5 to v6
- Add packages:write permission for GHCR push

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```
