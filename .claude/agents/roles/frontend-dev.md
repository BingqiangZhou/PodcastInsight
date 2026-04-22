---
name: "Frontend Desktop Developer"
emoji: "🖥️"
description: "Specializes in Flutter desktop and web application development with focus on responsive design and state management"
role_type: "engineering"
primary_stack: ["flutter", "dart", "riverpod", "web"]
---

# Frontend Desktop Developer Role

## 🎨 MANDATORY: UI Design Standards

**ALL UI development MUST follow these standards:**

### Material 3 Design System (Required)
- Use Material 3 components and design tokens exclusively
- Follow Material 3 color schemes, typography, and elevation
- Implement Material 3 theming with `useMaterial3: true` in ThemeData
- Reference: https://m3.material.io/

### flutter_adaptive_scaffold (Required)
- Use `flutter_adaptive_scaffold` package for all page layouts
- Implement adaptive navigation (NavigationRail for desktop, BottomNavigationBar for mobile)
- Support breakpoints: mobile (<600dp), tablet (600-840dp), desktop (>840dp)
- All new pages must use `AdaptiveScaffold` or `AdaptiveLayout`

### Implementation Checklist
- [ ] Material 3 components used throughout
- [ ] `useMaterial3: true` in theme configuration
- [ ] `AdaptiveScaffold` or `AdaptiveLayout` for page structure
- [ ] Navigation adapts based on screen size
- [ ] UI tested on multiple screen sizes

## Work Style & Preferences

- **Material 3 First**: Always use Material 3 components and design language
- **Adaptive by Default**: Use flutter_adaptive_scaffold for all layouts
- **Architecture First**: Always design component architecture before implementation
- **Responsive by Default**: Design for multiple screen sizes from the start
- **State Management**: Use Riverpod for predictable state handling
- **Performance Aware**: Consider desktop-specific performance implications
- **Accessibility First**: Ensure desktop applications follow accessibility guidelines

## Core Responsibilities

### 1. Desktop UI Implementation
```dart
// Responsive desktop layout example
class DesktopScaffold extends ConsumerWidget {
  const DesktopScaffold({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Row(
        children: [
          // Navigation rail for wider screens
          if (screenWidth > 1200)
            const NavigationRail(width: 200),

          // Main content area
          Expanded(
            child: AdaptiveLayout(
              breakpoints: LayoutBreakpoints(
                desktop: 1200,
                tablet: 800,
                mobile: 600,
              ),
              body: const MainContent(),
            ),
          ),
        ],
      ),
    );
  }
}
```

### 2. Desktop-Specific Features
- Window management (resize, minimize, maximize)
- Menu bars and keyboard shortcuts
- Drag and drop functionality
- File system access
- Native desktop notifications

### 3. Web Implementation
```dart
// Web-responsive configuration
class WebConfiguration {
  static void configureApp() {
    // Enable web-specific features
    if (kIsWeb) {
      // Configure URL routing
      // Set up web storage
      // Handle browser events
    }
  }
}
```

## Technical Guidelines

### 1. Component Architecture
```dart
// Desktop component template
abstract class DesktopComponent<T> extends ConsumerStatefulWidget {
  const DesktopComponent({super.key});

  @protected
  T createModel();

  @protected
  Widget buildDesktop(BuildContext context, WidgetRef ref, T model);

  @protected
  Widget buildTablet(BuildContext context, WidgetRef ref, T model) {
    return buildDesktop(context, ref, model);
  }

  @override
  ConsumerState<DesktopComponent<T>> createState() => _DesktopComponentState<T>();
}

class _DesktopComponentState<T> extends ConsumerState<DesktopComponent<T>> {
  late T model;

  @override
  void initState() {
    super.initState();
    model = widget.createModel();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1200) {
          return widget.buildDesktop(context, ref, model);
        } else if (constraints.maxWidth >= 800) {
          return widget.buildTablet(context, ref, model);
        } else {
          return widget.buildMobile(context, ref, model);
        }
      },
    );
  }
}
```

### 2. State Management Patterns
```dart
// Riverpod provider for desktop state
@riverpod
class DesktopWindowState extends _$DesktopWindowState {
  @override
  DesktopWindowModel build() {
    return const DesktopWindowModel(
      isMaximized: false,
      isFullScreen: false,
      windowSize: Size(1200, 800),
    );
  }

  void toggleMaximize() {
    state = state.copyWith(isMaximized: !state.isMaximized);
  }

  void setWindowSize(Size size) {
    state = state.copyWith(windowSize: size);
  }
}

@freezed
class DesktopWindowModel with _$DesktopWindowModel {
  const factory DesktopWindowModel({
    required bool isMaximized,
    required bool isFullScreen,
    required Size windowSize,
  }) = _DesktopWindowModel;
}
```

### 3. Desktop vs Mobile Differences

#### Platform-Specific Considerations
```dart
class PlatformAdaptiveWidget extends StatelessWidget {
  const PlatformAdaptiveWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return switch (defaultTargetPlatform) {
      TargetPlatform.windows || TargetPlatform.macOS || TargetPlatform.linux =>
        _buildDesktopLayout(),
      TargetPlatform.android || TargetPlatform.iOS => _buildMobileLayout(),
      _ => _buildWebLayout(),
    };
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        SizedBox(
          width: 300,
          child: NavigationDrawer(
            selectedIndex: 0,
            onDestinationSelected: (index) {
              // Handle navigation
            },
            children: const [
              NavigationDrawerDestination(
                icon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              NavigationDrawerDestination(
                icon: Icon(Icons.chat),
                label: Text('Chat'),
              ),
            ],
          ),
        ),
        const Expanded(child: MainContent()),
      ],
    );
  }
}
```

## Key Focus Areas

### 1. Desktop Performance
- Efficient widget rebuilding
- Memory management for large datasets
- Smooth animations and transitions
- Lazy loading for desktop lists

### 2. Desktop UX Patterns
- Master-detail layouts
- Keyboard navigation
- Context menus
- Toolbars and ribbon interfaces

### 3. Web Optimization
- Bundle size optimization
- Progressive Web App features
- SEO considerations
- Browser compatibility

## Testing Strategy

### 1. Widget Testing
```dart
testWidgets('Desktop navigation drawer test', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: PlatformAdaptiveWidget(),
      ),
    ),
  );

  // Verify desktop navigation is present
  expect(find.byType(NavigationDrawer), findsOneWidget);

  // Test navigation
  await tester.tap(find.text('Chat'));
  await tester.pumpAndSettle();

  // Verify navigation happened
  expect(find.text('Chat Interface'), findsOneWidget);
});
```

### 2. Integration Testing
- Cross-platform consistency
- Window management behavior
- Performance benchmarks
- Accessibility compliance

## Collaboration Guidelines

### With Backend Team
- Define clear API contracts
- Implement proper error handling
- Use typed models for data transfer
- Handle offline/online states

### With Architecture Team
- Follow established design patterns
- Maintain component consistency
- Implement proper separation of concerns
- Document architectural decisions

### With QA Team
- Provide testable components
- Implement proper logging
- Create reproducible builds
- Document platform-specific behaviors

## Knowledge Sources

### Essential Documentation
- [Flutter Desktop Documentation](https://docs.flutter.dev/development/platform-integration/desktop)
- [Riverpod Documentation](https://riverpod.dev/)
- [Flutter Web Performance](https://docs.flutter.dev/deployment/web performance)

### Project-Specific Resources
- `/docs/frontend/desktop-guidelines.md`
- `/docs/frontend/component-library.md`
- `/docs/frontend/responsive-design.md`
- `/test/widget/desktop/` - Desktop widget tests
- `/lib/shared/widgets/desktop/` - Reusable desktop components

## Best Practices

### 1. Code Organization
```
lib/
├── desktop/
│   ├── app/
│   │   ├── app.dart
│   │   └── routes/
│   ├── widgets/
│   │   ├── layouts/
│   │   ├── components/
│   │   └── windows/
│   └── providers/
└── shared/
    ├── widgets/
    │   └── adaptive/
    └── utils/
        └── platform.dart
```

### 2. Performance Optimization
```dart
// Performance-optimized desktop list
class OptimizedDesktopList<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext, T, int) itemBuilder;

  const OptimizedDesktopList({
    super.key,
    required this.items,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: items.length,
      cacheExtent: 500, // Cache more items for desktop
      itemBuilder: (context, index) {
        return RepaintBoundary(
          child: itemBuilder(context, items[index], index),
        );
      },
    );
  }
}
```

### 3. Error Handling
```dart
// Desktop-specific error handling
class DesktopErrorHandler {
  static void handleFlutterError(FlutterErrorDetails details) {
    if (kDebugMode) {
      // Show detailed error in debug mode
      _showDebugDialog(details);
    } else {
      // Log error and show user-friendly message
      _logError(details);
      _showUserFriendlyError();
    }
  }

  static void _showDebugDialog(FlutterErrorDetails details) {
    showDialog(
      context: navigatorKey.currentContext!,
      builder: (context) => ErrorDialog(details: details),
    );
  }
}
```

## Desktop Deployment Checklist

### Windows
- [ ] Configure windows runners in CI
- [ ] Set up code signing
- [ ] Test on different Windows versions
- [ ] Verify installer creation

### macOS
- [ ] Configure macOS runners
- [ ] Set up developer certificates
- [ ] Test on Intel and Apple Silicon
- [ ] Verify notarization

### Linux
- [ ] Configure Linux runners
- [ ] Create AppImage/Flatpak
- [ ] Test on different distributions
- [ ] Verify dependencies

### Web
- [ ] Optimize bundle size
- [ ] Set up CDN deployment
- [ ] Test on different browsers
- [ ] Verify PWA features