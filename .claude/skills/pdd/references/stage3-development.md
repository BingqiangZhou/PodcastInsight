# Stage 3: 开发执行与状态跟踪

## 概述

**负责人**: 工程团队

**前置条件**: Stage 2完成，任务已分配

**目标**: 按PRD要求实现功能，保持进度透明

---

## 开发规范

### 代码标准

#### 后端 (Python/FastAPI)
- 使用 `ruff` 进行格式化和检查
- 遵循 async/await 模式处理 I/O
- API端点前缀: `/api/v1/`

```bash
# 格式化
ruff format .

# 检查
ruff check .
```

#### 前端 (Flutter)
- Material 3 必需: `useMaterial3: true`
- 使用 AdaptiveScaffoldWrapper
- Widget 测试必需

```bash
# 格式化
dart format .

# 测试
flutter test test/widget/
```

### 国际化实现

#### API双语错误消息
```python
from pydantic import BaseModel

class ErrorResponse(BaseModel):
    message_en: str
    message_zh: str

# 使用示例
raise HTTPException(
    status_code=400,
    detail={
        "message_en": "Invalid input parameter",
        "message_zh": "输入参数无效"
    }
)
```

#### 前端国际化
```dart
// 使用arb文件管理文本
class AppLocalizations {
  static String helloWorld(BuildContext context) {
    return AppLocalizations.of(context)!.helloWorld;
  }
}

// 无硬编码文本
Text(AppLocalizations.helloWorld(context))
```

---

## 状态跟踪

### 状态流转

```
Todo → In Progress → Review → Done
         │              │
         └── Blocked ───┘
```

### 状态定义

| 状态 | 定义 | 条件 |
|------|------|------|
| Todo | 待开始 | 已分配但未开始 |
| In Progress | 进行中 | 正在开发 |
| Review | 评审中 | 开发完成，等待评审 |
| Blocked | 阻塞中 | 遇到阻碍，需要帮助 |
| Done | 已完成 | 通过所有检查 |

### 状态更新格式

```markdown
### [TASK-ID] 任务名称
- **状态**: In Progress
- **进度**: 60%
- **当前**: 实现用户认证逻辑
- **代码**: `backend/app/api/auth.py`
- **PR**: #123
- **下一步**: 编写单元测试
```

---

## 代码审查

### 审查清单

#### 功能正确性
- [ ] 代码实现了PRD要求
- [ ] 边界情况已处理
- [ ] 错误处理完善

#### 代码质量
- [ ] 遵循编码规范
- [ ] 无重复代码
- [ ] 命名清晰有意义
- [ ] 适当的注释

#### 安全性
- [ ] 无SQL注入风险
- [ ] 无XSS漏洞
- [ ] 输入已验证
- [ ] 敏感数据已加密

#### 性能
- [ ] 无N+1查询
- [ ] 适当使用缓存
- [ ] 异步处理正确

#### 测试
- [ ] 单元测试覆盖关键逻辑
- [ ] 集成测试覆盖API
- [ ] 边界情况已测试

---

## 测试要求

### 测试覆盖率标准

| 风险级别 | 覆盖率要求 | 测试类型 |
|----------|------------|----------|
| 低风险 | ≥60% | 单元测试 |
| 中风险 | ≥80% | 单元+集成测试 |
| 高风险 | ≥95% | 单元+集成+E2E测试 |

### 测试类型

#### 单元测试
- 测试单个函数/方法
- Mock外部依赖
- 快速执行

#### 集成测试
- 测试组件间交互
- 使用测试数据库
- 验证API契约

#### Widget测试 (前端必需)
```dart
testWidgets('Page displays correctly', (WidgetTester tester) async {
  await tester.pumpWidget(MyApp());
  expect(find.text('Hello'), findsOneWidget);
});
```

---

## 质量门检查清单

### 代码质量
- [ ] 代码格式化通过 (ruff format)
- [ ] 代码检查无错误 (ruff check)
- [ ] 测试覆盖率达标

### 功能质量
- [ ] 单元测试全部通过
- [ ] 集成测试全部通过
- [ ] 性能符合要求
- [ ] 安全检查通过

### 国际化
- [ ] API返回双语错误消息
- [ ] UI支持语言切换
- [ ] 无硬编码文本
- [ ] 两种语言显示正确

---

## 常见问题

### Q: 测试失败怎么办？
A:
1. 不要跳过测试
2. 分析失败原因
3. 修复代码或更新测试
4. 确保所有测试通过后再提交

### Q: 代码审查意见如何处理？
A:
1. 理解审查意见的意图
2. 如有疑问及时沟通
3. 修改后通知审查者
4. 保持专业和开放态度

### Q: 遇到技术阻塞怎么办？
A:
1. 记录阻塞原因
2. 更新任务状态为 Blocked
3. 寻求帮助或资源
4. 考虑替代方案
