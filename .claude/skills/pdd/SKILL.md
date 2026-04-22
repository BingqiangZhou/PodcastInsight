---
name: "pdd"
description: |
  Product-Driven Development workflow - 4-stage PM-led process for business value and user needs.

  Use this skill when:
  - User mentions "PDD", "产品驱动开发", "product-driven development", or "PM-first"
  - User wants to start a feature with business value analysis first
  - User asks for PRD creation or product requirement documentation
  - User requests structured product development with quality gates
  - User mentions "价值评估", "商业价值", or "验收标准"
  - User wants to ensure product-market fit before development

  This skill enforces the PM-first philosophy where the Product Manager analyzes ALL user input before any engineering work begins.
---

# Product-Driven Development (PDD) Workflow

## Core Philosophy

**PM-First**: The Product Manager analyzes ALL user input first. No development begins without PM analysis and PRD creation.

**Business Value Driven**: Every feature must have a clear value proposition. If you can't articulate the value, don't build it.

## Language Policy

| 文档类型 | 默认语言 | 可选 |
|----------|----------|------|
| PRD/需求文档 | 中文 | 英文 (用户指定时) |
| UI/技术实现 | 双语 (中英文) | - |
| 沟通交流 | 匹配用户语言 | - |

## Pre-flight Check

Before starting PDD workflow:
- [ ] `specs/` 目录存在 (如不存在则创建)
- [ ] `specs/templates/` 包含必要模板
- [ ] `CLAUDE.md` 存在且兼容

```bash
# 确保目录存在
mkdir -p specs/active specs/completed specs/templates
```

---

## Development Modes

| 模式 | 适用场景 | 阶段 | PRD模板 |
|------|----------|------|---------|
| **Quick** | 配置更新、UI微调、小改动 | 1, 3, 4 | `quick-prd.md` |
| **Standard** | 新功能、重构、API添加 | 1, 2, 3, 4 | `requirement-template.md` |
| **Full** | 新模块、架构变更、高风险 | 1, 2, 3, 4 + Review | `full-prd.md` |

**自动检测**: 根据功能复杂度自动选择模式。用户可显式指定: "quick mode", "full mode"。

---

## 4-Stage Workflow

### Stage 1: Product Analysis & Requirement Definition
**Owner**: Product Manager

**Actions**:
1. Analyze user needs and business value
2. Create PRD document:
   ```bash
   mkdir -p specs/active/[module-name]
   # Quick: cp .claude/skills/pdd/templates/quick-prd.md specs/active/[module-name]/requirement.md
   # Standard: cp specs/templates/requirement-template.md specs/active/[module-name]/requirement.md
   # Full: cp .claude/skills/pdd/templates/full-prd.md specs/active/[module-name]/requirement.md
   ```
3. Define success metrics (SMART)

**Quality Gate 1**:
- [ ] User pain points defined
- [ ] Business value explicit
- [ ] PRD complete
- [ ] Metrics quantifiable

> 详细指导: `.claude/skills/pdd/references/stage1-analysis.md`

### Stage 2: Feature Planning & Task Assignment
**Owner**: Product Manager (Standard/Full mode only)

**Actions**:
1. Prioritize using Value vs Cost matrix
2. Break down into tasks (0.5-8h each)
3. Assign to roles:
   - Backend → @backend-dev
   - Frontend → @frontend-dev
   - Architecture → @architect
4. Create task tracking:
   ```bash
   cp specs/templates/task-tracking-template.md specs/active/[module-name]/tasks.md
   ```

**Quality Gate 2**:
- [ ] Priorities clear
- [ ] Dependencies identified
- [ ] Timeline feasible
- [ ] Bilingual UI tasks assigned

> 详细指导: `.claude/skills/pdd/references/stage2-planning.md`

### Stage 3: Development Execution
**Owner**: Engineering Team

**Actions**:
1. Implement per PRD requirements
2. Update status:
   ```markdown
   ### [TASK-ID] Task Name
   - **Status**: Todo → In Progress → Review → Done
   - **Progress**: X%
   - **Code**: File locations
   ```

**Quality Gate 3** (risk-adjusted):

| 检查项 | 低风险 | 中风险 | 高风险 |
|--------|--------|--------|--------|
| 测试覆盖率 | ≥60% | ≥80% | ≥95% |
| 代码审查 | 可选 | 必须 | 必须+2人 |
| 安全审计 | 跳过 | 标准 | 完整 |

**Bilingual Implementation**:
- API: `{message_en: str, message_zh: str}`
- Frontend: Support language switching, no hardcoded text

> 详细指导: `.claude/skills/pdd/references/stage3-development.md`

### Stage 4: Product Validation
**Owner**: Product Manager

**Actions**:
1. Verify features match PRD
2. Calculate Value Score:
   ```
   Value Score = (User Value × 0.4) + (Business Value × 0.4) + (Technical Value × 0.2)

   > 8: Continue investing | 5-8: Optimize | < 5: Reconsider
   ```
3. Create verification report:
   ```bash
   cp specs/templates/verification-template.md specs/active/[module-name]/verification.md
   ```
4. Complete or iterate:
   - **Value Met**: `mv specs/active/[module-name] specs/completed/`
   - **Value Not Met**: Return to Stage 2

**Quality Gate 4**:
- [ ] Features verified against PRD
- [ ] Value Score calculated
- [ ] Verification report created
- [ ] Language switching works

> 详细指导: `.claude/skills/pdd/references/stage4-validation.md`

---

## Violation Handling

| Violation | Action |
|-----------|--------|
| Skip PM analysis | Stop, return to Stage 1 |
| No PRD created | Stop, create PRD first |
| Missing quality gate | Stop, complete missing gate |
| Skip final validation | Stop, conduct PM validation |

---

## Quick Reference

### Document Locations
| Document | Location |
|----------|----------|
| Quick PRD | `.claude/skills/pdd/templates/quick-prd.md` |
| Standard PRD | `specs/templates/requirement-template.md` |
| Full PRD | `.claude/skills/pdd/templates/full-prd.md` |
| Task Tracking | `specs/templates/task-tracking-template.md` |
| Verification | `specs/templates/verification-template.md` |
| Active PRDs | `specs/active/[module]/requirement.md` |
| Completed PRDs | `specs/completed/[module]/` |

### Role Assignments
| Task Type | Assigned Role |
|-----------|---------------|
| Backend | @backend-dev |
| Frontend | @frontend-dev |
| Mobile | @mobile-dev |
| Architecture | @architect |
| Testing | @test-engineer |
| DevOps | @devops-engineer |

---

**Remember**: PDD is about building the RIGHT thing, not just building things right. Every feature must justify its existence through clear business value.
