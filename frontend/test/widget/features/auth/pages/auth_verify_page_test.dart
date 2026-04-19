import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/features/auth/presentation/pages/auth_verify_page.dart';

/// A mock notifier that avoids creating a real Dio instance.
/// Extends [AuthVerifyNotifier] so Riverpod can use it as an override.
class MockAuthVerifyNotifier extends AuthVerifyNotifier {
  @override
  // The private _VerifyStatus is not accessible from this library, but
  // super.build() returns the initial state without performing network I/O
  // because the Dio instance is only used in the action methods.
  // ignore: unnecessary_override
  build() => super.build();
}

void main() {
  group('AuthVerifyPage Widget Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          authVerifyProvider.overrideWith(MockAuthVerifyNotifier.new),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    Widget createTestWidget() {
      return UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AuthVerifyPage(),
        ),
      );
    }

    testWidgets('renders verification title', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Auth Verification'), findsOneWidget);
    });

    testWidgets('renders initial status message', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Ready to test...'), findsOneWidget);
    });

    testWidgets('renders all four test buttons', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('1. Check Backend Health'), findsOneWidget);
      expect(find.text('2. Register New User'), findsOneWidget);
      expect(find.text('3. Login (Get Tokens)'), findsOneWidget);
      expect(find.text('4. Get User Info (with Token)'), findsOneWidget);
    });

    testWidgets('renders test flow instructions', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Test Flow:'), findsOneWidget);
      expect(
        find.text('1. Must run Backend Docker first (port 8000)'),
        findsOneWidget,
      );
      expect(
        find.text('2. Click "Check Health" to verify connection'),
        findsOneWidget,
      );
      expect(
        find.text('3. Click "Register" to create test user'),
        findsOneWidget,
      );
      expect(
        find.text('4. Click "Login" to get access/refresh tokens'),
        findsOneWidget,
      );
      expect(
        find.text('5. Click "Get User Info" to verify tokens work'),
        findsOneWidget,
      );
      expect(find.text('6. If all pass - Backend is Ready!'), findsOneWidget);
    });

    testWidgets('test buttons are tappable (InkWell)', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // There are 4 _TestButton widgets, each containing an InkWell
      expect(find.byType(InkWell), findsNWidgets(4));
    });

    testWidgets('status text updates reflect provider state',
        (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Initial state should show "Ready to test..."
      expect(find.text('Ready to test...'), findsOneWidget);

      // Manually update the provider state via the notifier
      final notifier = container.read(authVerifyProvider.notifier);
      // Trigger a state change by calling testBackendHealth (will fail
      // because no backend is running, but that's fine – we just verify
      // the UI reacts to state changes).
      notifier.testBackendHealth();
      await tester.pumpAndSettle();

      // After the async call completes, the status message should have
      // changed from the initial "Ready to test..."
      expect(find.text('Ready to test...'), findsNothing);
    });
  });
}
