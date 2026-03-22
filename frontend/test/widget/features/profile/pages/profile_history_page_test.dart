import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/widgets/app_shells.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/playback_history_lite_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/constants/podcast_ui_constants.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/podcast_image_widget.dart';
import 'package:personal_ai_assistant/features/profile/presentation/pages/profile_history_page.dart';

void main() {
  testWidgets('shows bare loading state without content GlassPanel', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playbackHistoryLiteProvider.overrideWith(
            () => _LoadingPlaybackHistoryLiteNotifier(),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const ProfileHistoryPage(),
        ),
      ),
    );

    await tester.pump();

    expect(
      find.byKey(const Key('profile_history_loading_content')),
      findsOneWidget,
    );
    expect(find.byType(GlassPanel), findsOneWidget);
  });

  testWidgets('renders history list from lightweight provider', (
    WidgetTester tester,
  ) async {
    final now = DateTime.now();

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playbackHistoryLiteProvider.overrideWith(
            () => _FixedPlaybackHistoryLiteNotifier(
              PlaybackHistoryLiteResponse(
                episodes: [
                  PlaybackHistoryLiteItem(
                    id: 101,
                    subscriptionId: 2,
                    subscriptionTitle: 'Podcast X',
                    subscriptionImageUrl: null,
                    title: 'Episode X',
                    imageUrl: null,
                    audioDuration: 1800,
                    playbackPosition: 120,
                    lastPlayedAt: now,
                    publishedAt: now.subtract(const Duration(days: 1)),
                  ),
                  PlaybackHistoryLiteItem(
                    id: 102,
                    subscriptionId: 3,
                    subscriptionTitle: 'Podcast Y',
                    subscriptionImageUrl: 'https://example.com/sub.png',
                    title: 'Episode Y',
                    imageUrl: 'https://example.com/ep.png',
                    audioDuration: 2400,
                    playbackPosition: 300,
                    lastPlayedAt: now.subtract(const Duration(minutes: 3)),
                    publishedAt: now.subtract(const Duration(days: 2)),
                  ),
                ],
                total: 2,
                page: 1,
                size: 100,
                pages: 1,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ProfileHistoryPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Episode X'), findsOneWidget);
    expect(find.text('Episode Y'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
    expect(find.byType(PodcastImageWidget), findsNWidgets(2));
    expect(find.byIcon(Icons.calendar_today_outlined), findsNWidgets(2));
    expect(find.byIcon(Icons.schedule), findsNWidgets(2));
    expect(
      find.byKey(const Key('profile_history_meta_podcast')),
      findsNWidgets(2),
    );
    expect(find.byKey(const Key('profile_history_meta_row')), findsNWidgets(2));

    final cards = tester.widgetList<Card>(find.byType(Card)).toList();
    expect(cards.length, 2);
    for (final card in cards) {
      expect(card.margin, EdgeInsets.zero);
      expect(card.shape, isA<RoundedRectangleBorder>());
      final shape = card.shape! as RoundedRectangleBorder;
      expect(
        shape.borderRadius,
        BorderRadius.circular(kPodcastRowCardCornerRadius),
      );
      expect(shape.side.style, BorderStyle.none);
      expect(shape.side.width, 0);
    }

    final cardContentFinder = find.byKey(
      const ValueKey('profile_history_card_content_101'),
    );
    expect(cardContentFinder, findsOneWidget);
    final contentRect = tester.getRect(cardContentFinder);
    expect(contentRect.height, closeTo(kPodcastRowCardTargetHeight, 0.01));

    final titleFinder = find.byKey(const ValueKey('profile_history_title_101'));
    expect(titleFinder, findsOneWidget);
    final titleText = tester.widget<Text>(titleFinder);
    expect(titleText.maxLines, 2);

    final titleBoxFinder = find.byKey(
      const ValueKey('profile_history_title_box_101'),
    );
    expect(titleBoxFinder, findsOneWidget);
    final titleBoxRect = tester.getRect(titleBoxFinder);
    expect(titleBoxRect.height, closeTo(38, 0.01));
  });
}

class _FixedPlaybackHistoryLiteNotifier extends PlaybackHistoryLiteNotifier {
  _FixedPlaybackHistoryLiteNotifier(this._value);

  final PlaybackHistoryLiteResponse? _value;

  @override
  FutureOr<PlaybackHistoryLiteResponse?> build() => _value;

  @override
  Future<PlaybackHistoryLiteResponse?> load({bool forceRefresh = false}) async {
    state = AsyncValue.data(_value);
    return _value;
  }
}

class _LoadingPlaybackHistoryLiteNotifier extends PlaybackHistoryLiteNotifier {
  @override
  FutureOr<PlaybackHistoryLiteResponse?> build() => null;

  @override
  Future<PlaybackHistoryLiteResponse?> load({bool forceRefresh = false}) async {
    state = const AsyncValue.loading();
    return null;
  }
}
