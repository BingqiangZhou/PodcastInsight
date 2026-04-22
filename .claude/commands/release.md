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
   image: ghcr.io/bingqiangzhou/personal-ai-assistant/backend:<版本号>
   ```

2. 在 `frontend` 服务中，同样替换：
   ```
   image: ghcr.io/bingqiangzhou/personal-ai-assistant/frontend:<版本号>
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
- docker-compose backend image: ghcr.io/bingqiangzhou/personal-ai-assistant/backend:1.1.0
- docker-compose frontend image: ghcr.io/bingqiangzhou/personal-ai-assistant/frontend:1.1.0
- Tag: v1.1.0
- Commit message: `chore(release): update version to 1.1.0 and generate changelog`
