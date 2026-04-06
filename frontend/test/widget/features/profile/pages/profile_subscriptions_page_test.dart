import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/widgets/app_shells.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_state_models.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_subscription_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/add_podcast_dialog.dart';
import 'package:personal_ai_assistant/features/profile/presentation/pages/profile_subscriptions_page.dart';

class _TestPodcastSubscriptionNotifier extends PodcastSubscriptionNotifier {
  _TestPodcastSubscriptionNotifier(this._initial);

  final PodcastSubscriptionState _initial;

  @override
  PodcastSubscriptionState build() => _initial;

  @override
  Future<void> loadSubscriptions({
    int page = 1,
    int size = 10,
    int? categoryId,
    String? status,
    bool forceRefresh = false,
  }) async {}

  @override
  Future<void> loadMoreSubscriptions({int? categoryId, String? status}) async {}

  @override
  Future<void> refreshSubscriptions({int? categoryId, String? status}) async {}
}

void main() {
  testWidgets('shows bare loading state without content GlassPanel', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          podcastSubscriptionProvider.overrideWith(
            () => _TestPodcastSubscriptionNotifier(
              const PodcastSubscriptionState(
                hasMore: false,
                isLoading: true,
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: ProfileSubscriptionsPage(),
        ),
      ),
    );

    await tester.pump();

    expect(
      find.byKey(const Key('profile_subscriptions_loading_content')),
      findsOneWidget,
    );
        expect(find.byType(SurfacePanel), findsOneWidget);
  });

  testWidgets('shows empty state when no subscriptions', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          podcastSubscriptionProvider.overrideWith(
            () => _TestPodcastSubscriptionNotifier(
              const PodcastSubscriptionState(
                hasMore: false,
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ProfileSubscriptionsPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final context = tester.element(find.byType(ProfileSubscriptionsPage));
    final l10n = AppLocalizations.of(context)!;
    expect(find.text(l10n.podcast_no_subscriptions), findsOneWidget);
  });

  testWidgets('renders subscription cards from provider state', (
    tester,
  ) async {
    final subscription = PodcastSubscriptionModel(
      id: 1,
      userId: 1,
      title: 'Sample Podcast',
      description: 'A description',
      sourceUrl: 'https://example.com/rss',
      status: 'active',
      fetchInterval: 3600,
      createdAt: DateTime(2024),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          podcastSubscriptionProvider.overrideWith(
            () => _TestPodcastSubscriptionNotifier(
              PodcastSubscriptionState(
                subscriptions: [subscription],
                total: 1,
                hasMore: false,
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ProfileSubscriptionsPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Sample Podcast'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('profile_subscription_card_content_1')),
      findsOneWidget,
    );
  });

  testWidgets('shows add action in app bar and opens dialog', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          podcastSubscriptionProvider.overrideWith(
            () => _TestPodcastSubscriptionNotifier(
              const PodcastSubscriptionState(
                hasMore: false,
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ProfileSubscriptionsPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('profile_subscriptions_action_add')),
      findsOneWidget,
    );
    expect(
      tester.widget<HeaderCapsuleActionButton>(
        find.byKey(const Key('profile_subscriptions_action_add')),
      ),
      isA<HeaderCapsuleActionButton>().having(
        (button) => button.circular,
        'circular',
        isTrue,
      ),
    );

    await tester.tap(find.byKey(const Key('profile_subscriptions_action_add')));
    await tester.pumpAndSettle();
    expect(find.byType(AddPodcastDialog), findsOneWidget);
    Navigator.of(tester.element(find.byType(AddPodcastDialog))).pop();
    await tester.pumpAndSettle();
  });
}
