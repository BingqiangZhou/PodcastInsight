# iOS 优化与双平台分化实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 按 Apple HIG 规范全面升级 iOS 体验，实现双平台组件形态完全分化（Cupertino vs Material），色彩统一。

**Architecture:** 分层替换策略 — 从核心 Adaptive 组件工厂开始，逐层替换到页面级。所有平台判断封装在 Adaptive 组件内部，页面层不直接写平台分支代码。

**Tech Stack:** Flutter 3.8+, Dart, Cupertino widgets, Material 3, Riverpod, GoRouter, share_plus, home_widget

---

## 阶段总览

| 阶段 | 名称 | 依赖 | 可并行 |
|------|------|------|--------|
| Phase 1 | 核心架构层 | 无 | 否（基础层） |
| Phase 2 | 视觉/交互体验层 | Phase 1 | 与 Phase 3/4/5 并行 |
| Phase 3 | 手势与导航层 | Phase 1 | 与 Phase 2/4/5 并行 |
| Phase 4 | 性能优化层 | Phase 1 | 与 Phase 2/3/5 并行 |
| Phase 5 | 平台集成层 | Phase 1 | 与 Phase 2/3/4 并行 |

**Team 分工建议：**
- Agent A: Phase 1 → Phase 2（核心 + 视觉）
- Agent B: Phase 3（手势与导航）
- Agent C: Phase 4 + Phase 5（性能 + 平台集成）

---

## Phase 1: 核心架构层

### Task 1.1: 统一 AppThemeExtension 色彩

**Files:**
- Modify: `frontend/lib/core/theme/app_colors.dart` (lines 299-406, AppThemeExtension variants)
- Modify: `frontend/lib/core/theme/app_theme.dart` (lines 165-174, extension selection logic)

**目标：** 移除 AppThemeExtension 中的 iOS/Android 颜色分支，两端共享同一 color scheme。仅保留形态差异（圆角大小、阴影有无）。

- [ ] **Step 1:** 修改 `AppThemeExtension.lightIOS` 和 `AppThemeExtension.darkIOS`：保留 iOS 形态参数（大圆角、零阴影），但颜色值改为与 `AppThemeExtension.light`/`dark` 完全一致
- [ ] **Step 2:** 修改 `app_theme.dart` 中的 extension 选择逻辑（line 172-174），简化为只基于 brightness 选择，不再基于 platform 选择 extension
- [ ] **Step 3:** 运行 `cd frontend && flutter test` 确认无回归
- [ ] **Step 4:** Commit: `refactor(theme): unify color scheme across platforms, keep form factor differences`

### Task 1.2: 创建 AdaptiveHaptic 工具类

**Files:**
- Create: `frontend/lib/core/platform/adaptive_haptic.dart`
- Test: `frontend/test/unit/core/platform/adaptive_haptic_test.dart`

**目标：** 封装平台感知的触觉反馈，iOS 用 HapticFeedback，Android 跳过或使用轻震动。

- [ ] **Step 1:** 创建 `AdaptiveHaptic` 静态工具类

```dart
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class AdaptiveHaptic {
  static void lightImpact(BuildContext context) {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      HapticFeedback.lightImpact();
    }
  }

  static void mediumImpact(BuildContext context) {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      HapticFeedback.mediumImpact();
    }
  }

  static void selectionClick(BuildContext context) {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      HapticFeedback.selectionClick();
    }
  }

  static void notificationSuccess(BuildContext context) {
    // iOS only — no Android equivalent
    if (!kIsWeb && Platform.isIOS) {
      // Use method channel for UINotificationFeedbackTypeSuccess
      // Fallback to mediumImpact on Android
      HapticFeedback.mediumImpact();
    }
  }
}
```

- [ ] **Step 2:** 编写单元测试
- [ ] **Step 3:** 运行测试确认通过
- [ ] **Step 4:** Commit: `feat(platform): add AdaptiveHaptic utility for platform-aware haptic feedback`

### Task 1.3: 创建 AdaptiveListSection 组件

**Files:**
- Create: `frontend/lib/core/widgets/adaptive/adaptive_list_section.dart`
- Create: `frontend/lib/core/widgets/adaptive/adaptive_list_tile.dart`
- Create: `frontend/lib/core/widgets/adaptive/adaptive_button.dart`
- Create: `frontend/lib/core/widgets/adaptive/adaptive_text_field.dart`
- Create: `frontend/lib/core/widgets/adaptive/adaptive_search_bar.dart`
- Create: `frontend/lib/core/widgets/adaptive/adaptive_sliver_app_bar.dart`
- Create: `frontend/lib/core/widgets/adaptive/adaptive_segmented_control.dart`
- Test: `frontend/test/unit/core/widgets/adaptive/` (每个组件一个测试文件)

**目标：** 创建 8 个 Adaptive 组件，每个组件内部根据 `PlatformHelper.isIOS()` 切换 Cupertino / Material 实现。

- [ ] **Step 1:** 创建 `frontend/lib/core/widgets/adaptive/` 目录和 barrel export 文件 `adaptive.dart`

- [ ] **Step 2:** 创建 `AdaptiveListSection` — iOS 用 `CupertinoListSection`，Android 用 `Card` 包裹 `Column`

```dart
class AdaptiveListSection extends StatelessWidget {
  final String? header;
  final String? footer;
  final List<Widget> children;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    if (PlatformHelper.isIOS(context)) {
      return CupertinoListSection.insetGrouped(
        header: header != null ? Text(header!) : null,
        footer: footer != null ? Text(footer!) : null,
        margin: margin,
        children: children,
      );
    }
    // Android: Card wrapper
    return Card(
      margin: margin ?? EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null)
            Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(header!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
          ...children,
          if (footer != null)
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Text(footer!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3:** 创建 `AdaptiveListTile` — iOS 用 `CupertinoListTile`，Android 用 Material `ListTile`

- [ ] **Step 4:** 创建 `AdaptiveButton` — iOS 用 `CupertinoButton`，Android 用 `ElevatedButton`/`TextButton`/`OutlinedButton`（通过 enum 参数选择样式）

- [ ] **Step 5:** 创建 `AdaptiveTextField` — iOS 用 `CupertinoTextField`（底部边框样式），Android 用 Material `TextField`（outlined 样式）

- [ ] **Step 6:** 创建 `AdaptiveSearchBar` — iOS 用 `CupertinoSearchTextField`，Android 用 Material `SearchBar`

- [ ] **Step 7:** 创建 `AdaptiveSliverAppBar` — iOS 用 `CupertinoSliverNavigationBar`，Android 用 Material `SliverAppBar`

```dart
class AdaptiveSliverAppBar extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Widget? leading;
  final bool largeTitle;
  // ... other params

  @override
  Widget build(BuildContext context) {
    if (PlatformHelper.isIOS(context)) {
      return CupertinoSliverNavigationBar(
        largeTitle: largeTitle ? Text(title) : null,
        middle: largeTitle ? null : Text(title),
        trailing: trailing,
        leading: leading,
        // Cupertino uses stretch/blur behavior
      );
    }
    return SliverAppBar(
      title: Text(title),
      actions: trailing != null ? [trailing!] : null,
      leading: leading,
      floating: true,
      snap: true,
    );
  }
}
```

- [ ] **Step 8:** 创建 `AdaptiveSegmentedControl` — iOS 用 `CupertinoSlidingSegmentedControl`，Android 用 `SegmentedButton`

- [ ] **Step 9:** 编写每个组件的单元测试
- [ ] **Step 10:** 运行 `cd frontend && flutter test` 确认全部通过
- [ ] **Step 11:** Commit: `feat(adaptive): add core adaptive widget factory components`

---

## Phase 2: 视觉/交互体验层

### Task 2.1: Profile 页面 iOS 适配（优先级最高）

**Files:**
- Modify: `frontend/lib/features/profile/presentation/pages/profile_page.dart`
- Modify: `frontend/lib/features/profile/presentation/widgets/settings_section_card.dart`（如果存在）
- Test: `frontend/test/widget/features/profile/`

**目标：** Profile 页面是 iOS 适配需求最高的页面（PopupMenuButton → ActionSheet, ListTile → CupertinoListTile, 5+ AlertDialog）。

- [ ] **Step 1:** 替换 `PopupMenuButton` → iOS 使用 `CupertinoActionSheet`（通过 `showCupertinoModalPopup`）
- [ ] **Step 2:** 替换 `ListTile` 组 → `AdaptiveListSection` + `AdaptiveListTile`
- [ ] **Step 3:** 替换 `Switch.adaptive()` 保留（已经是 adaptive）
- [ ] **Step 4:** 替换 `SegmentedButton` → `AdaptiveSegmentedControl`
- [ ] **Step 5:** 替换未使用 `.adaptive()` 的 `AlertDialog` → 已有 `.adaptive()` 的保留
- [ ] **Step 6:** 替换 `TextFormField`/`TextField` → `AdaptiveTextField`
- [ ] **Step 7:** 在关键交互点添加 `AdaptiveHaptic` 反馈
- [ ] **Step 8:** 运行 widget 测试
- [ ] **Step 9:** Commit: `feat(profile): adapt profile page for iOS with Cupertino components`

### Task 2.2: Auth 页面群 iOS 适配

**Files:**
- Modify: `frontend/lib/features/auth/presentation/pages/login_page.dart`
- Modify: `frontend/lib/features/auth/presentation/pages/register_page.dart`
- Modify: `frontend/lib/features/auth/presentation/pages/forgot_password_page.dart`
- Modify: `frontend/lib/features/auth/presentation/pages/reset_password_page.dart`
- Modify: `frontend/lib/features/auth/presentation/pages/onboarding_page.dart`
- Test: `frontend/test/widget/features/auth/`

- [ ] **Step 1:** 替换 `Checkbox` → iOS 使用 `CupertinoSwitch`，Android 保留 `Checkbox`
- [ ] **Step 2:** 替换 `FilledButton` → `AdaptiveButton.filled`
- [ ] **Step 3:** 替换 `TextButton` → `AdaptiveButton.text`
- [ ] **Step 4:** 替换 `OutlinedButton` → `AdaptiveButton.outlined`
- [ ] **Step 5:** 替换 `CustomTextField`/`PasswordTextField` → `AdaptiveTextField`（或在其内部添加平台分支）
- [ ] **Step 6:** 在登录/注册成功时添加 `AdaptiveHaptic.notificationSuccess`
- [ ] **Step 7:** Onboarding PageView 使用 `BouncingScrollPhysics`（iOS）
- [ ] **Step 8:** 运行测试
- [ ] **Step 9:** Commit: `feat(auth): adapt auth pages for iOS with Cupertino components`

### Task 2.3: Podcast 页面群 iOS 适配

**Files:**
- Modify: `frontend/lib/features/podcast/presentation/pages/podcast_episodes_page.dart`
- Modify: `frontend/lib/features/podcast/presentation/pages/podcast_episode_detail_page.dart` + part files
- Modify: `frontend/lib/features/podcast/presentation/pages/podcast_list_page.dart`
- Modify: `frontend/lib/features/podcast/presentation/pages/podcast_feed_page.dart`
- Modify: `frontend/lib/features/podcast/presentation/pages/podcast_downloads_page.dart`
- Modify: `frontend/lib/features/podcast/presentation/pages/podcast_daily_report_page.dart`
- Modify: `frontend/lib/features/podcast/presentation/pages/podcast_highlights_page.dart`
- Test: `frontend/test/widget/features/podcast/`

**优先级排序：** episodes_page > episode_detail > list_page > feed_page > downloads > daily_report > highlights

- [ ] **Step 1:** `podcast_episodes_page.dart` — 替换 `FilterChip` → iOS 使用 pill-shaped 按钮；`PopupMenuButton` → `CupertinoActionSheet`；`SegmentedButton` → `AdaptiveSegmentedControl`；`CheckboxListTile` → `CupertinoListTile` + `CupertinoSwitch`
- [ ] **Step 2:** `podcast_episode_detail_page.dart` — 自定义 tab bar → iOS 使用 `CupertinoSlidingSegmentedControl`；`PageView` 确认使用 `BouncingScrollPhysics`
- [ ] **Step 3:** `podcast_list_page.dart` — 搜索输入 → `AdaptiveSearchBar`；分类 chips 保持（无原生 iOS 等价物）
- [ ] **Step 4:** `podcast_feed_page.dart` — `RefreshIndicator` 已自动适配 iOS；卡片布局保持
- [ ] **Step 5:** `podcast_downloads_page.dart` — `Dismissible` 确认 iOS 风格滑动删除；`LinearProgressIndicator` → iOS 保持（无原生等价物）
- [ ] **Step 6:** `podcast_daily_report_page.dart` + `podcast_highlights_page.dart` — `Scrollbar` → iOS 隐藏；`TableCalendar` 保持（第三方组件）
- [ ] **Step 7:** 在播放/暂停/下载操作时添加 `AdaptiveHaptic.mediumImpact`
- [ ] **Step 8:** 运行测试
- [ ] **Step 9:** Commit: `feat(podcast): adapt podcast pages for iOS with Cupertino components`

### Task 2.4: 其他页面 iOS 适配

**Files:**
- Modify: `frontend/lib/features/profile/presentation/pages/profile_history_page.dart`
- Modify: `frontend/lib/features/profile/presentation/pages/profile_subscriptions_page.dart`
- Modify: `frontend/lib/features/profile/presentation/pages/profile_cache_management_page.dart`
- Modify: `frontend/lib/features/settings/presentation/pages/appearance_page.dart`
- Modify: `frontend/lib/features/profile/presentation/widgets/settings_section_card.dart`（如果存在，改为使用 AdaptiveListSection）

- [ ] **Step 1:** `SettingsSectionCard` → `AdaptiveListSection`（如果存在，这是多个页面共用的组件，改一处影响多处）
- [ ] **Step 2:** `profile_cache_management_page.dart` — 列表 + 确认对话框适配
- [ ] **Step 3:** `profile_history_page.dart` + `profile_subscriptions_page.dart` — RefreshIndicator 已适配，列表项使用 `AdaptiveListTile`
- [ ] **Step 4:** `appearance_page.dart` — `SegmentedButton` → `AdaptiveSegmentedControl`
- [ ] **Step 5:** 运行测试
- [ ] **Step 6:** Commit: `feat(profile): adapt remaining profile and settings pages for iOS`

---

## Phase 3: 手势与导航层

### Task 3.1: Tab 左右滑动切换

**Files:**
- Modify: `frontend/lib/core/widgets/custom_adaptive_navigation.dart` (858 lines)
- Modify: `frontend/lib/features/home/presentation/pages/home_page.dart`
- Test: `frontend/test/widget/core/widgets/custom_adaptive_navigation_test.dart`

**目标：** iOS 移动端底部 Tab 支持左右滑动切换相邻 Tab。

- [ ] **Step 1:** 在 `CustomAdaptiveNavigation` 的 iOS 移动端路径中，将 Tab 内容区域包裹在 `PageView` 中
- [ ] **Step 2:** `PageView` 的 `onPageChanged` 回调触发 `onDestinationSelected`
- [ ] **Step 3:** Tab 切换时调用 `AdaptiveHaptic.lightImpact`
- [ ] **Step 4:** 确保与 `GoRouter` 的嵌套路由不冲突
- [ ] **Step 5:** 运行测试
- [ ] **Step 6:** Commit: `feat(navigation): add iOS tab swipe gesture with PageView`

### Task 3.2: Tab 双击回到顶部

**Files:**
- Modify: `frontend/lib/core/widgets/custom_adaptive_navigation.dart`
- Test: `frontend/test/widget/core/widgets/custom_adaptive_navigation_test.dart`

- [ ] **Step 1:** 在底部导航项的 `GestureDetector` 上添加 `onDoubleTap` 回调
- [ ] **Step 2:** 当双击当前选中的 Tab 时，发送一个 `ScrollController.animateTo(0)` 事件（通过 Riverpod provider 或 callback）
- [ ] **Step 3:** 双击时触发 `AdaptiveHaptic.lightImpact`
- [ ] **Step 4:** 运行测试
- [ ] **Step 5:** Commit: `feat(navigation): add iOS double-tap tab to scroll to top`

### Task 3.3: iOS 列表滑动手势

**Files:**
- Create: `frontend/lib/core/widgets/adaptive/adaptive_dismissible.dart`
- Modify: `frontend/lib/features/podcast/presentation/pages/podcast_downloads_page.dart`
- Modify: `frontend/lib/features/podcast/presentation/widgets/` — 列表项组件
- Test: `frontend/test/unit/core/widgets/adaptive/adaptive_dismissible_test.dart`

**目标：** iOS 使用原生风格滑动操作（左滑删除/更多，右滑收藏），Android 保持 Dismissible 或 PopupMenu。

- [ ] **Step 1:** 创建 `AdaptiveDismissible` 组件：

```dart
class AdaptiveDismissible extends StatelessWidget {
  final Widget child;
  final VoidCallback onDelete;
  final VoidCallback? onSecondaryAction;
  final VoidCallback? onFavorite;
  final Key key;

  @override
  Widget build(BuildContext context) {
    if (PlatformHelper.isIOS(context)) {
      // Use CupertinoSwipeAction pattern:
      // Wrap in Dismissible with styled background buttons
      // Left swipe: red delete background
      // Right swipe: blue favorite background
    }
    // Android: Material Dismissible
    return Dismissible(
      key: key,
      background: Container(color: Colors.red, child: Icon(Icons.delete)),
      onDismissed: (_) => onDelete(),
      child: child,
    );
  }
}
```

- [ ] **Step 2:** 在 `podcast_downloads_page.dart` 中替换 `Dismissible` → `AdaptiveDismissible`
- [ ] **Step 3:** 在播客列表项中添加可选的滑动收藏功能
- [ ] **Step 4:** 运行测试
- [ ] **Step 5:** Commit: `feat(interaction): add adaptive dismissible with iOS swipe actions`

### Task 3.4: CupertinoSliverNavigationBar 大标题折叠

**Files:**
- Modify: `frontend/lib/core/widgets/adaptive/adaptive_sliver_app_bar.dart`（Phase 1 已创建）
- Modify: `frontend/lib/features/podcast/presentation/pages/podcast_list_page.dart`
- Modify: `frontend/lib/features/podcast/presentation/pages/podcast_feed_page.dart`
- Modify: `frontend/lib/features/profile/presentation/pages/profile_page.dart`

**目标：** 主列表页面（Discover、Feed、Profile）在 iOS 上使用 `CupertinoSliverNavigationBar` 大标题折叠效果。

- [ ] **Step 1:** 在 `AdaptiveSliverAppBar` 中完善 `CupertinoSliverNavigationBar` 的实现，确保大标题正确折叠
- [ ] **Step 2:** 修改 `podcast_list_page.dart` — 替换 `ContentShell` 的 AppBar → `AdaptiveSliverAppBar`（iOS 大标题 "Discover"）
- [ ] **Step 3:** 修改 `podcast_feed_page.dart` — 替换为 `AdaptiveSliverAppBar`（iOS 大标题 "Library"）
- [ ] **Step 4:** 修改 `profile_page.dart` — 替换为 `AdaptiveSliverAppBar`（iOS 大标题 "Profile"）
- [ ] **Step 5:** 运行测试
- [ ] **Step 6:** Commit: `feat(navigation): add CupertinoSliverNavigationBar large title collapsing`

---

## Phase 4: 性能优化层

### Task 4.1: 图片缓存优化

**Files:**
- Modify: `frontend/lib/core/network/` — Dio 缓存配置（如果涉及图片）
- Modify: `frontend/lib/features/podcast/presentation/widgets/` — 所有使用 CachedNetworkImage 的地方
- Test: `frontend/test/unit/`

- [ ] **Step 1:** 配置 CachedNetworkImage 内存缓存上限 100MB，磁盘缓存 200MB
- [ ] **Step 2:** 列表缩略图使用 `ResizeImage` 限制解码尺寸为 200x200
- [ ] **Step 3:** 详情页加载原图
- [ ] **Step 4:** 预加载可视区域外 ±2 项缩略图（通过 `ScrollController` 监听 + `precacheImage`）
- [ ] **Step 5:** 运行测试
- [ ] **Step 6:** Commit: `perf(images): optimize image caching with size limits and prefetching`

### Task 4.2: Widget 重建优化

**Files:**
- Modify: `frontend/lib/features/podcast/presentation/widgets/` — 列表项组件
- Modify: `frontend/lib/features/podcast/presentation/pages/podcast_feed_page.dart`
- Modify: `frontend/lib/features/podcast/presentation/pages/podcast_episodes_page.dart`

- [ ] **Step 1:** 审查所有 `ConsumerWidget` / `ConsumerStatefulWidget`，将 `ref.watch` 替换为 `ref.watch(...select())` 进行精确订阅
- [ ] **Step 2:** 列表项使用稳定的 `ValueKey(episodeId)` 而非 `ValueKey(index)`
- [ ] **Step 3:** 在播放器控件区域添加 `RepaintBoundary` 隔离重绘
- [ ] **Step 4:** 确保所有列表项的 `const` 构造函数正确使用
- [ ] **Step 5:** 运行测试
- [ ] **Step 6:** Commit: `perf(widgets): optimize rebuilds with Selector, stable keys, and RepaintBoundary`

### Task 4.3: Sliver 与列表滚动优化

**Files:**
- Modify: `frontend/lib/features/podcast/presentation/pages/podcast_feed_page.dart`
- Modify: `frontend/lib/features/podcast/presentation/pages/podcast_episodes_page.dart`
- Modify: `frontend/lib/features/podcast/presentation/widgets/scrollable_content_wrapper.dart`

- [ ] **Step 1:** 确认 iOS 使用 `BouncingScrollPhysics()`，Android 使用 `ClampingScrollPhysics()`
- [ ] **Step 2:** 使用 `SliverPersistentHeader` 替代 StickyHeader 做分组头
- [ ] **Step 3:** 避免嵌套 `NestedScrollView` 过深（超过 2 层时重构）
- [ ] **Step 4:** `AutomaticKeepAliveClientMixin` 保持 Tab 页状态
- [ ] **Step 5:** 运行测试
- [ ] **Step 6:** Commit: `perf(scroll): optimize sliver layout and scroll physics`

### Task 4.4: 内存管理优化

**Files:**
- Modify: `frontend/lib/core/services/` — 下载管理、缓存管理
- Modify: 各页面的 `dispose()` 方法

- [ ] **Step 1:** 审查所有页面的 `dispose()` 方法，确保取消 stream 订阅、释放 controller
- [ ] **Step 2:** 后台播放时释放封面大图内存（通过 `WidgetsBindingObserver.didChangeAppLifecycleState`）
- [ ] **Step 3:** 音频预加载上限 5MB
- [ ] **Step 4:** 运行测试
- [ ] **Step 5:** Commit: `perf(memory): improve lifecycle management and resource cleanup`

---

## Phase 5: 平台集成层

### Task 5.1: Haptic Feedback 集成

**Files:**
- Modify: `frontend/lib/core/widgets/custom_adaptive_navigation.dart`（Tab 切换）
- Modify: 所有已适配页面的关键交互点

- [ ] **Step 1:** Tab 切换 → `AdaptiveHaptic.lightImpact`（已在 Task 3.1 中集成）
- [ ] **Step 2:** 列表项点击 → `AdaptiveHaptic.lightImpact`
- [ ] **Step 3:** 点赞/收藏 → `AdaptiveHaptic.mediumImpact`
- [ ] **Step 4:** 下载完成 → `AdaptiveHaptic.mediumImpact`
- [ ] **Step 5:** 登录/注册成功 → `AdaptiveHaptic.notificationSuccess`
- [ ] **Step 6:** Slider 滑动 → `AdaptiveHaptic.selectionClick`
- [ ] **Step 7:** 运行测试
- [ ] **Step 8:** Commit: `feat(haptics): integrate adaptive haptic feedback across key interactions`

### Task 5.2: 分享功能集成

**Files:**
- Add dependency: `share_plus` to `frontend/pubspec.yaml`
- Create: `frontend/lib/core/services/adaptive_share.dart`
- Modify: `frontend/lib/features/podcast/presentation/pages/podcast_episode_detail_page.dart`（分享按钮）
- Test: `frontend/test/unit/core/services/adaptive_share_test.dart`

- [ ] **Step 1:** 添加 `share_plus` 依赖到 `pubspec.yaml`
- [ ] **Step 2:** 创建 `AdaptiveShare` 封装：

```dart
import 'package:share_plus/share_plus.dart';

class AdaptiveShare {
  static Future<void> shareText(String text, {BuildContext? context}) {
    return Share.share(text);
  }

  static Future<void> shareEpisode({
    required String title,
    required String url,
    BuildContext? context,
  }) {
    return Share.share('$title\n$url');
  }
}
```

- [ ] **Step 3:** 在 `podcast_episode_detail_page.dart` 中集成分享按钮
- [ ] **Step 4:** 在播客列表项的长按/更多菜单中添加分享选项
- [ ] **Step 5:** 运行 `flutter pub get` 和测试
- [ ] **Step 6:** Commit: `feat(share): integrate share_plus for native share sheet`

### Task 5.3: 推送通知集成 (P1)

**Files:**
- Add dependency: `flutter_local_notifications` to `frontend/pubspec.yaml`
- Create: `frontend/lib/core/services/notification_service.dart`
- Modify: `frontend/lib/core/app/app.dart`（初始化）
- Modify: `frontend/ios/Runner/Info.plist`（通知权限）
- Test: `frontend/test/unit/core/services/notification_service_test.dart`

- [ ] **Step 1:** 添加 `flutter_local_notifications` 依赖
- [ ] **Step 2:** 创建 `NotificationService` 封装（初始化、请求权限、显示通知、点击处理）
- [ ] **Step 3:** iOS `Info.plist` 添加通知权限描述
- [ ] **Step 4:** 在 `app.dart` 中初始化 `NotificationService`
- [ ] **Step 5:** 在新单集通知、下载完成等场景集成
- [ ] **Step 6:** 运行测试
- [ ] **Step 7:** Commit: `feat(notifications): add flutter_local_notifications integration`

### Task 5.4: 主屏 Widget 集成 (P1)

**Files:**
- Add dependency: `home_widget` to `frontend/pubspec.yaml`
- Create: `frontend/lib/core/services/home_widget_service.dart`
- Create: `frontend/ios/Widget/` — WidgetKit SwiftUI 文件
- Create: `frontend/android/app/src/main/java/.../GlanceWidget.kt`
- Test: `frontend/test/unit/core/services/home_widget_service_test.dart`

- [ ] **Step 1:** 添加 `home_widget` 依赖
- [ ] **Step 2:** 创建 `HomeWidgetService` 封装（更新数据、注册回调）
- [ ] **Step 3:** 创建 iOS WidgetKit Widget（Small: 正在播放；Medium: 最近更新）
- [ ] **Step 4:** 创建 Android GlanceWidget
- [ ] **Step 5:** 在播放状态变化、新单集到达时更新 Widget 数据
- [ ] **Step 6:** Widget 点击打开对应页面（deep link）
- [ ] **Step 7:** 运行测试
- [ ] **Step 8:** Commit: `feat(widgets): add home screen widget support with home_widget`

### Task 5.5: Siri 快捷指令 + Spotlight 索引 (P2, 可选)

**Files:**
- Create: `frontend/lib/core/services/spotlight_service.dart`
- Modify: `frontend/ios/Runner/` — Siri Intents 配置

- [ ] **Step 1:** 评估 `flutter_siri_suggestion` 或直接 MethodChannel 实现
- [ ] **Step 2:** 创建 `SpotlightService` 用于索引播客/单集到 Spotlight
- [ ] **Step 3:** 注册 Siri 快捷指令（播放、搜索）
- [ ] **Step 4:** Commit: `feat(platform): add Siri shortcuts and Spotlight indexing`

---

## 现有基础设施（直接复用，不重建）

| 组件 | 文件 | 状态 |
|------|------|------|
| `PlatformHelper` | `core/platform/platform_helper.dart` | ✅ 直接复用 |
| `AppTheme` iOS 分支 | `core/theme/app_theme.dart` | ✅ 复用 + 简化色彩分支 |
| `CupertinoTheme` 包装 | `core/app/app.dart` | ✅ 直接复用 |
| `adaptivePageTransition` | `core/platform/adaptive_page_route.dart` | ✅ 直接复用 |
| `showAdaptiveSheet` | `core/widgets/adaptive_sheet_helper.dart` | ✅ 直接复用 |
| `showAppDialog` / `showAppConfirmationDialog` | `core/widgets/app_dialog_helper.dart` | ✅ 直接复用 |
| `adaptiveAppBar` | `core/platform/adaptive_app_bar.dart` | ⚠️ 逐步替换为 AdaptiveSliverAppBar |
| `TopFloatingNotice` | `core/widgets/top_floating_notice.dart` | ✅ 直接复用 |
| `.adaptive()` 构造函数 | 50+ 处 | ✅ 直接复用 |
| `_CleanDock` iOS 路径 | `core/widgets/custom_adaptive_navigation.dart` | ⚠️ 增强手势 |

---

## 验收标准

每个 Phase 完成后需确认：
1. `cd frontend && flutter test` 全部通过
2. `cd frontend && dart run build_runner build` 无错误（如果改了 @riverpod/@JsonSerializable 文件）
3. iOS 模拟器上手动验证关键页面
4. Android 模拟器上确认无回归
