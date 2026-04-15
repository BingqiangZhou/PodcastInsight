# Monochrome Glass — 全局去色设计方案

**日期:** 2026-04-15
**状态:** 已批准
**范围:** 全应用视觉风格统一

## 概述

将 Stella 应用的视觉风格从"彩色渐变 + 玻璃拟态"统一为"纯灰玻璃 (Monochrome Glass)"。所有彩色渐变和多彩品牌色替换为灰色调表面，仅保留 Indigo (#5856D6) 作为交互元素的点缀色。

## 动机

- 当前迷你播放器 dock 使用 6 种彩色渐变（coral/violet/cyan/gold/rose/sky），视觉上过于花哨
- 背景光晕使用多种深色调（靛蓝/青/紫），与"不彩色"的设计意图不符
- AI 对话气泡使用黄色和粉色，与整体深色调不协调
- 全应用统一为非彩色风格，提升视觉一致性

## 设计决策

### 1. 背景光晕 (GlassBackground)

**当前:** 3 个彩色径向渐变光晕（深靛蓝 `#1a1040`、深青 `#0f2030`、深紫 `#201020`），按 `podcast`/`home`/`neutral` 三种主题区分。

**改为:** 统一灰色调微光，不再区分主题变体。

| 元素 | Dark Mode | Light Mode |
|------|-----------|------------|
| 光晕 1 | `#1a1a24` @ 6% | `#e0e0e0` @ 15% |
| 光晕 2 | `#181818` @ 6% | `#d8d8dc` @ 15% |
| 光晕 3 | `#1c1c20` @ 6% | `#e4e4e4` @ 15% |

- 保留光晕位置和模糊效果
- `GlassBackgroundTheme` 枚举保留但所有变体使用相同颜色

### 2. 迷你播放器 Dock

**当前:** 基于播客标题 hash 从 6 种彩色渐变中选择背景色，白色文字/图标硬编码。

**改为:** 使用 `SurfaceCard` card tier 风格。

- 填充: 白色 6% (`0x0FFFFFFF`) + 边框: 白色 8% (`0x14FFFFFF`)
- 文字/图标: 使用 `colorScheme.onSurface`（替代硬编码 `Colors.white`）
- 进度条: 主色调 Indigo (`colorScheme.primary`)
- 圆角: 保持 28（药丸形）
- 移除 `podcastGradientColors` 在迷你播放器中的使用
- 移除 `_MiniPlayPauseButton` 中的硬编码白色

### 3. AI 对话气泡

**当前:** 用户气泡黄色 (`#FFCC00`)，助手气泡粉色 (`#FF2D55`)，AI Chip 橙色 (`#FF9500`)。

**改为:** Indigo 色调统一。

| 元素 | 改前 | 改后 |
|------|------|------|
| 用户气泡 | `#FFCC00` (Yellow) | `colorScheme.primary` (Indigo) |
| 用户气泡文字 | 深色 | `colorScheme.onPrimary` (白) |
| 助手气泡 | `#FF2D55` (Pink) | SurfaceCard card tier 风格 |
| 助手气泡文字 | 白/深色 | `colorScheme.onSurface` |
| AI Chip | `#FF9500` (Orange) | `colorScheme.primary` (Indigo) |

### 4. 播客标识色 (Podcast Gradients)

**当前:** 6 种彩色渐变（coral, violet, cyan, gold, rose, sky），用于播客封面占位等。

**改为:** 统一灰色渐变。

| 模式 | 渐变色 |
|------|--------|
| Dark | `#2a2a2e` → `#3a3a40` |
| Light | `#e0e0e0` → `#d0d0d0` |

- 不再基于播客 hash 选择颜色
- 所有播客使用相同的灰色渐变

### 5. 品牌色精简

**保留:**
- `AppColors.primary` (Indigo `#5856D6`) — 所有交互元素：进度条、开关、选中态、FAB、链接

**降级（仅语义场景）:**
- `AppColors.warmAccent` (Orange `#FF9500`) — 仅用于警告/提醒/错误等语义场景
- `AppColors.coralAccent` (Pink `#FF2D55`) — 不再主动使用，保留 token 定义
- `AppColors.tertiary` (Green `#34C759`) — 不再主动使用，保留 token 定义

**移除:**
- AI 专用的 `aiUserBubble`、`aiAssistantBubble`、`aiChip` 颜色 token（改用主题色）

## 影响的文件

### 主题/设计系统
- `frontend/lib/core/theme/app_colors.dart` — 更新颜色 token
- `frontend/lib/core/glass/glass_background.dart` — 灰色光晕
- `frontend/lib/core/glass/glass_container.dart` — 确认使用 GlassTokens

### 播放器
- `frontend/lib/features/podcast/presentation/widgets/podcast_bottom_player_layouts.dart` — 迷你 dock 去色
- `frontend/lib/features/podcast/presentation/widgets/podcast_bottom_player_controls.dart` — 移除硬编码白色

### AI 对话
- AI 相关气泡组件 — 更新颜色为 Indigo/Surface

### 播客
- 使用 `podcastGradientColors` 的组件 — 替换为灰色渐变

## 不在范围内

- 不改变布局/结构
- 不改变字体系统
- 不改变组件层级（GlassContainer/SurfaceCard 的使用场景不变）
- Light mode 遵循相同的去色逻辑，但不需要额外设计

## 验证标准

1. 应用启动后，任何页面不应出现彩色渐变（Indigo 点缀除外）
2. 迷你播放器 dock 与页面卡片视觉统一（无彩色背景）
3. AI 对话使用 Indigo/SurfaceCard 风格（无黄/粉气泡）
4. 背景光晕为灰色调，不带有明显色彩倾向
5. 所有文字使用主题色（`onSurface`/`onPrimary`），无硬编码颜色
