import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/features/auth/presentation/pages/onboarding_page.dart';
import 'package:personal_ai_assistant/features/auth/presentation/providers/onboarding_provider.dart';

class MockOnboardingCompletedNotifier extends OnboardingCompletedNotifier {
  @override
  bool build() {
    return false;
  }
}

void main() {
  group('OnboardingPage Widget Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          onboardingCompletedProvider
              .overrideWith(MockOnboardingCompletedNotifier.new),
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
          home: OnboardingPage(),
        ),
      );
    }

    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingPage), findsOneWidget);
    });

    testWidgets('shows onboarding content with icons', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // First page should show podcasts icon
      expect(find.byIcon(Icons.podcasts_rounded), findsOneWidget);

      // Should show dot indicators (3 containers for 3 pages)
      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('shows skip button in top bar', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(OnboardingPage));
      final l10n = AppLocalizations.of(context)!;

      expect(find.text(l10n.onboarding_skip), findsOneWidget);
    });

    testWidgets('shows next button in bottom section', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(OnboardingPage));
      final l10n = AppLocalizations.of(context)!;

      // On the first page, the button should say "Next"
      expect(find.text(l10n.onboarding_next), findsOneWidget);
    });

    testWidgets('displays three dot indicators for page count', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // The dot indicators are AnimatedContainer widgets.
      // On page 0, the first dot is active (width 24) and the other two are inactive (width 8).
      final animatedContainers = tester.widgetList<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      // There should be exactly 3 dot indicator containers
      expect(animatedContainers.length, equals(3));
    });
  });
}
