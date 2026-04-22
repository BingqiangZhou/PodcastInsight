---
name: "Feature Development Workflow"
emoji: "🚀"
description: "Cross-role collaborative workflow for developing features from requirements to deployment"
type: "workflow"
participants: ["requirements-analyst", "architect", "backend-dev", "frontend-dev", "mobile-dev", "test-engineer", "devops-engineer"]
estimated_duration: "2-3 weeks"
phases: 5
triggers: ["new-feature-request", "sprint-planning"]
outputs: ["implemented-feature", "documentation", "tests", "deployment"]
---

# Feature Development Workflow

## Overview
跨角色功能开发协作流程，确保从需求到交付的整个过程高效且质量可控。

## 参与角色
- **Requirements Analyst** - 需求分析师
- **Architect** - 软件架构师
- **Backend Developer** - 后端开发工程师
- **Frontend Desktop Developer** - 前端桌面开发工程师
- **Mobile Developer** - 移动端开发工程师
- **Test Engineer** - 测试工程师
- **DevOps Engineer** - 运维工程师

## 工作流程阶段

### Phase 1: 需求分析与设计 (Requirements & Design)

#### 1.1 需求收集与分析 (Requirements Analyst)
```markdown
## 交付物
- [ ] Feature需求文档
- [ ] 用户故事和验收标准
- [ ] 功能规格说明
- [ ] 非功能性需求

## 关键活动
1. 与产品负责人对齐需求
2. 编写详细的用户故事
3. 定义清晰的验收标准
4. 识别技术约束和依赖
```

#### 1.2 架构设计 (Architect + Tech Leads)
```markdown
## 交付物
- [ ] 架构设计文档
- [ ] API接口设计
- [ ] 数据模型设计
- [ ] 技术选型说明
- [ ] 实现计划

## 关键活动
1. 评审功能需求
2. 设计系统架构变更
3. 定义API契约
4. 识别架构风险
5. 创建实现路线图
```

### Phase 2: 开发规划 (Development Planning)

#### 2.1 任务分解 (All Roles)
```yaml
# 任务分解示例
feature: "Document Upload and Processing"
tasks:
  backend:
    - task: "Database schema design"
      owner: "Backend Developer"
      effort: "2 days"
      dependencies: []

    - task: "API endpoint implementation"
      owner: "Backend Developer"
      effort: "3 days"
      dependencies: ["Database schema design"]

    - task: "File processing service"
      owner: "Backend Developer"
      effort: "5 days"
      dependencies: ["API endpoint implementation"]

  frontend_desktop:
    - task: "Upload UI component"
      owner: "Frontend Desktop Developer"
      effort: "3 days"
      dependencies: ["API endpoint implementation"]

    - task: "File list management"
      owner: "Frontend Desktop Developer"
      effort: "2 days"
      dependencies: ["Upload UI component"]

  mobile:
    - task: "Mobile upload interface"
      owner: "Mobile Developer"
      effort: "3 days"
      dependencies: ["API endpoint implementation"]

  testing:
    - task: "Test case design"
      owner: "Test Engineer"
      effort: "2 days"
      dependencies: ["API endpoint implementation"]

    - task: "Automated test implementation"
      owner: "Test Engineer"
      effort: "4 days"
      dependencies: ["Test case design"]

  devops:
    - task: "CI/CD pipeline update"
      owner: "DevOps Engineer"
      effort: "1 day"
      dependencies: []
```

#### 2.2 里程碑定义
```markdown
## 开发里程碑
1. **Sprint 1**: 核心后端API完成
   - Database schema
   - File upload endpoint
   - Basic processing service

2. **Sprint 2**: 前端界面完成
   - Desktop upload UI
   - Mobile upload interface
   - Integration testing

3. **Sprint 3**: 完整功能交付
   - All tests passing
   - Documentation complete
   - Production deployment
```

### Phase 3: 并行开发 (Parallel Development)

#### 3.1 后端开发 (Backend Developer)
```python
# 开发顺序
1. 创建数据库模型和迁移
2. 实现核心业务逻辑
3. 开发API端点
4. 编写单元测试
5. 集成测试
```

#### 3.2 前端开发 (Frontend + Mobile Developers)
```dart
// 并行开发策略
1. 基于API契约创建模拟数据
2. 实现UI组件（使用模拟数据）
3. API集成
4. 跨平台适配
5. UI测试
```

#### 3.3 测试开发 (Test Engineer)
```python
// 测试开发时间线
Week 1: 测试用例设计
Week 2: API自动化测试
Week 3: UI自动化测试
Week 4: 集成测试和性能测试
```

### Phase 4: 集成与测试 (Integration & Testing)

#### 4.1 API集成
```markdown
## 集成检查清单
- [ ] API端点功能正常
- [ ] 错误处理完善
- [ ] 性能指标达标
- [ ] 安全验证通过
- [ ] 文档更新
```

#### 4.2 跨平台测试
```markdown
## 测试矩阵
| 平台 | 浏览器/版本 | 测试状态 | 备注 |
|------|-------------|----------|------|
| Windows Desktop | Windows 11 | ✅ | 通过 |
| macOS Desktop | macOS 13 | ✅ | 通过 |
| Linux Desktop | Ubuntu 22.04 | ✅ | 通过 |
| Web | Chrome 120 | ✅ | 通过 |
| Web | Firefox 119 | ✅ | 通过 |
| iOS | iOS 17 | 🔄 | 进行中 |
| Android | Android 14 | 🔄 | 进行中 |
```

### Phase 5: 部署与发布 (Deployment & Release)

#### 5.1 预发布验证
```yaml
# Staging环境检查
staging_validation:
  functional_tests:
    - "All API endpoints working"
    - "File upload successful"
    - "Processing completes correctly"

  performance_tests:
    - "Upload < 5s for 10MB file"
    - "Processing < 30s for typical document"
    - "Memory usage stable"

  security_tests:
    - "File type validation working"
    - "Size limits enforced"
    - "Authentication required"
```

#### 5.2 生产部署 (DevOps Engineer)
```bash
# 部署步骤
1. 创建部署分支
2. 运行完整测试套件
3. 构建生产镜像
4. 部署到staging环境
5. 运行冒烟测试
6. 部署到生产环境
7. 运行健康检查
8. 监控系统状态
```

## 协作机制

### 每日站会
```markdown
## 时间: 每日上午 9:30
## 参与者: 所有开发角色
## 会议内容:
1. 昨天完成的工作
2. 今天计划的任务
3. 遇到的障碍和风险
4. 需要的协助

## 格式:
**角色**:
- ✅ 完成事项
- 🔄 进行事项
- 🚫 阻碍事项
- ❓ 需要帮助
```

### 周度同步
```markdown
## 时间: 每周五下午 3:00
## 参与者: 所有角色
## 议题:
1. 功能开发进度回顾
2. 质量指标 review
3. 风险和问题讨论
4. 下周计划对齐
5. 架构决策评审
```

### 代码评审
```markdown
## 评审原则
- 所有代码必须经过评审
- 至少一个相关角色评审
- 关注点: 功能正确性、性能、安全、可维护性

## 评审检查清单
### 通用
- [ ] 代码符合团队规范
- [ ] 有适当的注释
- [ ] 错误处理完善
- [ ] 日志记录适当

### 后端特定
- [ ] API设计符合RESTful原则
- [ ] 数据库查询优化
- [ ] 异步操作正确处理
- [ ] 安全考虑充分

### 前端特定
- [ ] 组件设计合理
- [ ] 状态管理正确
- [ ] 响应式设计
- [ ] 性能优化
```

## 质量门禁

### Definition of Done
```markdown
## 完成标准
- [ ] 需求验收标准全部满足
- [ ] 代码评审通过
- [ ] 单元测试覆盖率 > 80%
- [ ] 集成测试通过
- [ ] 文档更新完成
- [ ] 性能测试通过
- [ ] 安全扫描通过
- [ ] 生产部署成功
```

### Go/No-Go决策
```markdown
## 发布决策标准
### Go (可以发布)
- 所有关键功能正常
- 性能指标达标
- 安全测试通过
- 无阻塞性bug

### No-Go (不能发布)
- 关键功能未实现
- 性能不达标
- 安全漏洞存在
- 阻塞性bug未修复
```

## 风险管理

### 常见风险和缓解措施
```yaml
技术风险:
  - risk: "API设计变更"
    probability: "Medium"
    impact: "High"
    mitigation: "早期API评审，版本控制"

  - risk: "性能不达标"
    probability: "Medium"
    impact: "Medium"
    mitigation: "早期性能测试，持续监控"

协作风险:
  - risk: "角色间沟通不畅"
    probability: "High"
    impact: "Medium"
    mitigation: "定期同步会，清晰的责任划分"

  - risk: "依赖延期"
    probability: "Medium"
    impact: "High"
    mitigation: "依赖跟踪，备选方案"
```

## 工具和模板

### 任务跟踪模板
```markdown
# Feature 任务板

## To Do
- [ ] 后端API设计
- [ ] 前端组件设计
- [ ] 测试用例编写

## In Progress
- [ ] 数据库实现 (@Backend Developer)
- [ ] 上传UI组件 (@Frontend Developer)

## Review
- [ ] API接口评审
- [ ] 前端代码评审

## Done
- [ ] 需求文档确认
```

### 进度报告模板
```markdown
# 周进度报告

## 本周完成
- 后端: API端点实现 (80%)
- 前端: UI组件完成 (60%)
- 测试: 测试用例设计 (100%)

## 下周计划
- 后端: API集成测试
- 前端: API集成
- 测试: 自动化测试实现

## 风险和问题
- 性能优化需要额外2天
- 移动端适配需要更多测试时间
```

## 最佳实践

1. **并行开发**: 后端API先于前端开发完成
2. **持续集成**: 每个提交都运行自动化测试
3. **早期反馈**: 定期演示和评审
4. **文档同步**: 代码和文档同时更新
5. **质量优先**: 不因时间压力牺牲质量
6. **沟通透明**: 及时分享进度和问题
7. **责任明确**: 每个任务都有明确负责人
8. **持续改进**: 定期回顾和优化流程