---
name: "Claude Code Subagent System"
description: "Personal AI Assistant - Multi-agent collaboration system"
version: "2.0.0"
---

# Personal AI Assistant - Claude Code Subagent System (Product-Driven Development)

## 系统概述

这是一个为Personal AI Assistant项目设计的Claude Code subagent系统，**采用产品驱动开发模式（Product-Driven Development）**，包含7个专业工程师角色，由产品经理主导，支持并行开发和协作完成项目任务。

**🚨 重要更新（v2.0.0）**：
- ✅ 强化了产品经理的核心领导地位
- ✅ 增加了强制性工作流程验证
- ✅ 添加了流程违规检测和处理机制
- ✅ 实现了自动化检查和验证脚本

## 目录结构

```
.claude/agents/
├── README.md                           # 本文件（已更新）
├── agents.json                         # Agent配置文件（已优化）
├── roles/                             # Agent角色定义
│   ├── product-manager.md             # 产品经理（核心领导者）
│   ├── architect.md                   # 架构师角色
│   ├── backend-dev.md                 # 后端工程师角色
│   ├── frontend-dev.md               # 前端工程师角色
│   ├── mobile-dev.md                  # 移动端工程师角色
│   ├── test-engineer.md              # 测试工程师角色
│   └── devops-engineer.md            # DevOps工程师角色
├── workflows/                         # 工作流程定义
│   ├── product-driven-development.md  # 产品驱动开发流程（主要流程）
│   ├── feature-development.md        # 功能开发流程
│   ├── bug-fix.md                     # Bug修复流程
│   └── architecture-review.md         # 架构评审流程
├── templates/                         # 模板和检查清单（新增）
│   ├── workflow-validation-checklist.md # 工作流程验证检查清单
│   └── product-manager-workflow-guide.md # 产品经理工作指导
├── scripts/                          # 自动化脚本（新增）
│   └── workflow-violation-handler.sh  # 流程违规处理脚本
├── prompts/               # 系统提示词
│   ├── base-prompt.md     # 共享知识基础
│   └── domain-context.md  # 领域上下文
├── coordination/          # 协调机制
│   ├── task-board.md      # 任务跟踪系统
│   └── communication.md   # 通信协议
├── config/               # 配置文件
│   └── base-agent.md     # 基础代理配置
└── README.md            # 本文件
```

## 角色说明

### 1. 软件架构师 (Architect) 🏛️
- **专业领域**: 系统设计、DDD架构、技术决策
- **主要职责**: 确保架构的可扩展性、可维护性和一致性
- **核心技能**: Python、TypeScript、系统设计、API设计

### 2. 后端开发工程师 (Backend Developer) ⚙️
- **专业领域**: FastAPI/Python实现、API开发
- **主要职责**: 构建健壮、可扩展的后端服务
- **核心技能**: FastAPI、SQLAlchemy、PostgreSQL、Redis、异步编程

### 3. 前端桌面开发工程师 (Frontend Desktop Developer) 🖥️
- **专业领域**: Flutter桌面/Web开发
- **主要职责**: 实现响应式UI、跨平台兼容性
- **核心技能**: Flutter、Dart、Riverpod、Web技术

### 4. 移动端开发工程师 (Mobile Developer) 📱
- **专业领域**: Flutter iOS/Android开发
- **主要职责**: 创建高性能、用户友好的移动应用
- **核心技能**: Flutter、Dart、移动UI/UX、设备集成

### 5. 需求分析师 (Requirements Analyst) 📋
- **专业领域**: 需求收集、用户故事编写、验收标准定义
- **主要职责**: 确保需求清晰、完整、可测试
- **核心技能**: 业务分析、文档编写、用户故事地图

### 6. 测试工程师 (Test Engineer) 🧪
- **专业领域**: 质量保证、测试自动化
- **主要职责**: 确保产品质量、建立测试策略
- **核心技能**: pytest、Flutter测试、性能测试、CI/CD测试

### 7. 运维工程师 (DevOps Engineer) ⚙️
- **专业领域**: 部署、基础设施、CI/CD
- **主要职责**: 确保系统稳定运行、自动化部署
- **核心技能**: Docker、Kubernetes、GitHub Actions、监控

## 工作流程

### 1. 功能开发流程 (Feature Development)
- **触发条件**: 新功能需求、Sprint规划
- **参与角色**: 所有7个角色
- **预计时长**: 2-3周
- **主要阶段**:
  1. 需求分析与设计
  2. 开发规划
  3. 并行开发
  4. 集成与测试
  5. 部署与发布

### 2. Bug修复流程 (Bug Fix)
- **触发条件**: Bug报告、测试失败、生产问题
- **参与角色**: 测试、开发、运维、架构师
- **预计时长**: 1-5天
- **优先级**: P0-Critical, P1-High, P2-Medium, P3-Low

### 3. 架构评审流程 (Architecture Review)
- **触发条件**: 重大设计决策、API设计完成
- **参与角色**: 架构师、各开发角色、测试、运维
- **预计时长**: 2-4小时
- **评审类型**: 战略、技术、实现、安全

## 使用方法

### 1. 激活特定角色
```bash
# 通过Claude Code命令激活角色
/role architect        # 激活架构师
/role backend-dev      # 激活后端开发
/role frontend-dev     # 激活前端开发
```

### 2. 启动工作流
```bash
# 启动功能开发流程
/workflow feature-development

# 启动Bug修复流程
/workflow bug-fix

# 启动架构评审
/workflow architecture-review
```

### 3. 任务分配
```bash
# 分配任务给特定角色
/assign backend-dev "实现用户认证API"
/assign test-engineer "编写API测试用例"
```

## 协作机制

### 1. 任务看板
- 所有任务集中跟踪
- 优先级和状态管理
- 负责人明确分配
- 进度实时更新

### 2. 通信协议
- 实时通信：Slack/Teams频道
- 异步通信：邮件和文档
- 结构化数据：JSON消息格式
- 紧急响应：P0级问题15分钟内响应

### 3. 知识共享
- 统一的知识库
- 架构决策记录(ADR)
- 最佳实践文档
- 经验教训总结

## 配置说明

### agents.json
系统的核心配置文件，包含：
- 所有角色的注册信息
- 工作流定义
- 提示词配置
- 协调机制设置
- 系统参数

### 基础配置 (base-agent.md)
定义了所有角色的：
- 共享能力
- 通用约束
- 错误处理协议
- 质量标准
- 沟通规范

## 最佳实践

### 1. 角色协作
- 每个角色专注自己的专业领域
- 主动分享信息和知识
- 及时响应其他角色的请求
- 尊重最终决策

### 2. 文档管理
- 所有决策必须文档化
- 代码变更要有注释
- API文档自动生成
- 定期更新知识库

### 3. 质量保证
- 代码必须经过评审
- 测试覆盖率达到要求
- 性能指标持续监控
- 安全扫描定期执行

## 故障排除

### 常见问题

1. **角色未激活**
   - 检查agents.json配置
   - 确认角色文件存在
   - 验证YAML格式

2. **工作流无法启动**
   - 检查工作流文件路径
   - 验证参与者配置
   - 确认触发条件

3. **任务分配失败**
   - 检查任务看板状态
   - 验证角色可用性
   - 确认任务格式

### 日志位置
- 系统日志：`.claude/logs/system.log`
- 角色日志：`.claude/logs/roles/`
- 工作流日志：`.claude/logs/workflows/`

## 扩展指南

### 添加新角色
1. 创建角色文件 `.claude/agents/roles/new-role.md`
2. 添加YAML front matter
3. 定义职责和能力
4. 更新agents.json注册

### 创建新工作流
1. 创建工作流文件 `.claude/agents/workflows/new-workflow.md`
2. 定义阶段和参与者
3. 配置触发条件
4. 更新agents.json

### 自定义协调机制
1. 修改 `.claude/agents/coordination/`
2. 更新通信协议
3. 调整任务看板
4. 测试集成效果

## 版本历史

- v1.0.0 - 初始版本，包含7个角色和3个工作流
- 支持并行开发和协作机制
- 完整的文档和最佳实践

## 联系支持

如有问题或建议，请：
1. 查看本README文档
2. 检查相关角色配置文件
3. 查看日志文件
4. 提交Issue或PR