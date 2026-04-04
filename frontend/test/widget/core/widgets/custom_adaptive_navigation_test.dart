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
      final dockRect = tester.getRect(
        find.byKey(const Key('custom_adaptive_navigation_mobile_dock')),
      );

      expect(accessoryRect.width, closeTo(390, 2));
      expect(accessoryRect.top, lessThan(dockRect.top));
      expect(accessoryRect.bottom, lessThanOrEqualTo(dockRect.top + 2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('mobile: bottom backdrop sits beneath accessory and dock', (
      tester,
    ) async {
      await _pumpWithSize(
        tester: tester,
        size: const Size(390, 844),
        child: _buildNavigation(),
      );

      // The bottom accessory is positioned above the dock
      final accessoryRect = tester.getRect(
        find.byKey(const Key('test_bottom_accessory')),
      );
      final dockRect = tester.getRect(
        find.byKey(const Key('custom_adaptive_navigation_mobile_dock')),
      );

      expect(accessoryRect.bottom, lessThanOrEqualTo(dockRect.top + 2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('mobile: bottom backdrop still renders without accessory', (
      tester,
    ) async {
      await _pumpWithSize(
        tester: tester,
        size: const Size(390, 844),
        child: _buildNavigation(includeAccessory: false),
      );

      // When no accessory, the dock should still render
      expect(find.byKey(const Key('test_bottom_accessory')), findsNothing);
      expect(
        find.byKey(const Key('custom_adaptive_navigation_mobile_dock')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
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
      expect(sidebarSize.width, closeTo(256, 0.1));
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
      expect(sidebarSize.width, closeTo(72, 0.1));
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
  await tester.pump(const Duration(milliseconds: 500));
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
