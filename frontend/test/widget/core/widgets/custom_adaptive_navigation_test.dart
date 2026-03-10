import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/widgets/custom_adaptive_navigation.dart';

void main() {
  group('CustomAdaptiveNavigation bottomAccessory layout', () {
    testWidgets('desktop: accessory stays in right content area only', (
      tester,
    ) async {
      await _pumpWithSize(
        tester: tester,
        size: const Size(1200, 900),
        child: _buildNavigation(),
      );

      final accessoryRect = tester.getRect(
        find.byKey(const Key('test_bottom_accessory')),
      );

      expect(accessoryRect.left, greaterThan(250));
      expect(accessoryRect.width, lessThan(1200));
      expect(accessoryRect.width, greaterThan(800));
      expect(accessoryRect.bottom, greaterThan(840));
    });

    testWidgets('tablet: accessory stays in right content area only', (
      tester,
    ) async {
      await _pumpWithSize(
        tester: tester,
        size: const Size(800, 900),
        child: _buildNavigation(),
      );

      final accessoryRect = tester.getRect(
        find.byKey(const Key('test_bottom_accessory')),
      );

      expect(accessoryRect.left, greaterThan(70));
      expect(accessoryRect.width, lessThan(800));
      expect(accessoryRect.width, greaterThan(650));
      expect(accessoryRect.bottom, greaterThan(840));
    });

    testWidgets('mobile: accessory remains above navigation bar', (
      tester,
    ) async {
      await _pumpWithSize(
        tester: tester,
        size: const Size(390, 844),
        child: _buildNavigation(),
      );

      final accessoryRect = tester.getRect(
        find.byKey(const Key('test_bottom_accessory')),
      );
      final navRect = tester.getRect(find.byType(NavigationBar));

      expect(accessoryRect.width, closeTo(390, 2));
      expect(accessoryRect.top, lessThan(navRect.top));
      expect(accessoryRect.bottom, lessThanOrEqualTo(navRect.top + 1));
    });

    testWidgets('mobile: bottom backdrop sits beneath accessory and dock', (
      tester,
    ) async {
      await _pumpWithSize(
        tester: tester,
        size: const Size(390, 844),
        child: _buildNavigation(),
      );

      final backdropFinder = find.byKey(
        const Key('custom_adaptive_navigation_bottom_backdrop'),
      );
      expect(backdropFinder, findsOneWidget);

      final backdropRect = tester.getRect(backdropFinder);
      final accessoryRect = tester.getRect(
        find.byKey(const Key('test_bottom_accessory')),
      );
      final navRect = tester.getRect(find.byType(NavigationBar));

      expect(backdropRect.bottom, closeTo(844, 0.1));
      expect(backdropRect.top, lessThan(accessoryRect.top));
      expect(backdropRect.top, lessThan(navRect.top));

      final mobileStack = tester
          .widgetList<Stack>(find.byType(Stack))
          .firstWhere(
            (stack) => stack.children.any(
              (child) =>
                  child is Positioned &&
                  child.child.key ==
                      const Key('custom_adaptive_navigation_bottom_backdrop'),
            ),
          );
      expect(
        mobileStack.children.first,
        isA<Positioned>().having(
          (positioned) => positioned.child.key,
          'child key',
          const Key('custom_adaptive_navigation_bottom_backdrop'),
        ),
      );
    });

    testWidgets('mobile: bottom backdrop still renders without accessory', (
      tester,
    ) async {
      await _pumpWithSize(
        tester: tester,
        size: const Size(390, 844),
        child: _buildNavigation(includeAccessory: false),
      );

      final backdropFinder = find.byKey(
        const Key('custom_adaptive_navigation_bottom_backdrop'),
      );
      expect(backdropFinder, findsOneWidget);
      expect(find.byKey(const Key('test_bottom_accessory')), findsNothing);

      final backdropRect = tester.getRect(backdropFinder);
      final navRect = tester.getRect(find.byType(NavigationBar));

      expect(backdropRect.bottom, closeTo(844, 0.1));
      expect(backdropRect.top, lessThan(navRect.top));
    });
  });

  group('CustomAdaptiveNavigation desktop sidebar toggle', () {
    testWidgets('expanded: shows wide sidebar with title', (tester) async {
      await _pumpWithSize(
        tester: tester,
        size: const Size(1200, 900),
        child: _buildNavigation(desktopNavExpanded: true),
      );

      expect(find.text('AI Assistant'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);

      final sidebarSize = tester.getSize(
        find.byKey(const ValueKey('desktop_navigation_sidebar')),
      );
      expect(sidebarSize.width, closeTo(280, 0.1));
    });

    testWidgets('collapsed: shows narrow sidebar without title', (
      tester,
    ) async {
      await _pumpWithSize(
        tester: tester,
        size: const Size(1200, 900),
        child: _buildNavigation(desktopNavExpanded: false),
      );

      expect(find.text('AI Assistant'), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      final sidebarSize = tester.getSize(
        find.byKey(const ValueKey('desktop_navigation_sidebar')),
      );
      expect(sidebarSize.width, closeTo(80, 0.1));
    });
  });
}

Future<void> _pumpWithSize({
  required WidgetTester tester,
  required Size size,
  required Widget child,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(child);
  await tester.pumpAndSettle();
}

Widget _buildNavigation({
  bool desktopNavExpanded = true,
  bool includeAccessory = true,
}) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: CustomAdaptiveNavigation(
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Feed',
        ),
        NavigationDestination(
          icon: Icon(Icons.podcasts_outlined),
          selectedIcon: Icon(Icons.podcasts),
          label: 'Podcast',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
      selectedIndex: 0,
      desktopNavExpanded: desktopNavExpanded,
      onDesktopNavToggle: () {},
      body: const SizedBox.expand(child: ColoredBox(color: Colors.white)),
      bottomAccessory: includeAccessory
          ? Container(
              key: const Key('test_bottom_accessory'),
              height: 60,
              color: Colors.blue,
            )
          : null,
    ),
  );
}
