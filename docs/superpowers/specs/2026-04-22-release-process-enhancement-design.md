# Release Process Enhancement Design

**Date**: 2026-04-22
**Status**: Approved
**Scope**: Enhance release command, CI workflow, and Docker Compose for production-grade releases

## Problem

The current release process lacks several practices common in mature open-source projects like Dify:

- No upgrade guide in release notes
- No release highlights / narrative summary
- Docker image version tags not synchronized with releases
- Single-architecture Docker builds (amd64 only)

## Design

### 1. Release Command (`.claude/commands/release.md`)

The `/release <version>` command flow expands from 5 steps to 7:

```
Step 0: Write Release Highlights
  → Prompt user to input version highlights (1-3 paragraphs)
  → If skipped, auto-extract feat commits as highlights

Step 1: Generate CHANGELOG
  → git-cliff --tag v<version> -o CHANGELOG.md (unchanged)

Step 1.5: Inject Highlights into CHANGELOG
  → Insert Highlights text below the ## header for the version
  → Format: summary paragraph + Highlights bullet list

Step 2: Update version numbers
  → backend/pyproject.toml (unchanged)
  → frontend/package.json (unchanged)

Step 2.5: Update Docker image versions
  → Update image tags in docker/docker-compose.yml for backend and frontend services

Step 3: Create commit
  → chore(release): update version to <version> and generate changelog

Step 4: Push commit (unchanged)

Step 5: Create and push tag (unchanged)
```

#### Highlights format in CHANGELOG.md

Inserted between the `## [X.Y.Z]` header and the first `###` section:

```markdown
> **Highlights**: <one-line summary of what this release delivers>
>
> <1-2 paragraph prose summary of the release theme and key changes>
```

#### Docker Compose image tags

The `docker/docker-compose.yml` backend and frontend services will include both `build` and `image` directives:

```yaml
backend:
  build:
    context: ../backend
    dockerfile: Dockerfile
  image: ghcr.io/bingqiangzhou/podcast-insight/backend:${VERSION:-latest}
  ...

frontend:
  build:
    context: ../frontend
    dockerfile: Dockerfile
  image: ghcr.io/bingqiangzhou/podcast-insight/frontend:${VERSION:-latest}
  ...
```

The `/release` command updates the `image` tag (replaces `${VERSION:-latest}` with the new version) alongside `build`. Users can:
- `docker compose up` — builds locally (uses `build`)
- `VERSION=1.1.0 docker compose up` — pulls pre-built GHCR image (uses `image`)

### 2. Release Workflow (`.github/workflows/release.yml`)

#### Multi-architecture builds

Add QEMU + Buildx for amd64 + arm64:

```yaml
- name: Set up QEMU
  uses: docker/setup-qemu-action@v3

- name: Set up Docker Buildx
  uses: docker/setup-buildx-action@v3
```

Build with `platforms: linux/amd64,linux/arm64`.

#### `latest` tag control

Only stable releases get `latest`:

```yaml
tags: |
  ghcr.io/${{ github.repository }}/backend:${{ needs.prepare-release.outputs.version }}
  type=raw,value=latest,enable=${{ needs.prepare-release.outputs.is_prerelease == 'false' }}
```

#### Upgrade guide injection

After generating the changelog from CHANGELOG.md, append a templated upgrade guide:

```markdown
---

## Upgrade Guide

### Docker Compose Deployment

1. Backup your `docker-compose.yml` and `.env` files
2. Pull the latest images: `docker compose pull`
3. Restart services: `docker compose down && docker compose up -d`

### Source Code Deployment

1. Stop all running services
2. Checkout the new tag: `git checkout vX.Y.Z`
3. Backend: `cd backend && uv sync && uv run alembic upgrade head`
4. Frontend: `cd frontend && pnpm install && pnpm build`
5. Restart all services
```

#### Release creation

Keep `generate_release_notes: true` in `softprops/action-gh-release` to auto-append PR list and new contributors after the manual changelog + upgrade guide.

### 3. Release Notes Template (final structure)

```markdown
## What's New in vX.Y.Z

> **Highlights**: <one-line summary>
>
> <Prose summary of the release>

<git-cliff generated sections: Features, Bug Fixes, etc.>

---

## Upgrade Guide

### Docker Compose Deployment
<steps>

### Source Code Deployment
<steps>

---

<GitHub auto-generated: What's Changed, New Contributors>

**Full Changelog**: https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/PREVIOUS...CURRENT
```

## Files to Modify

| File | Change |
|------|--------|
| `.claude/commands/release.md` | Rewrite: add Highlights step, Docker version sync step |
| `.github/workflows/release.yml` | Rewrite: multi-arch builds, latest tag control, upgrade guide injection |
| `docker/docker-compose.yml` | Add `image` directives to backend/frontend services |

## Out of Scope

- No new tools or dependencies (keep git-cliff, keep existing CI actions)
- No CHANGELOG.md removal (unlike Dify, keep git-cliff managed changelog)
- No separate production docker-compose file (use `image` + `build` in same file)
- No automated release notes editing in CI (highlights written locally via command)
