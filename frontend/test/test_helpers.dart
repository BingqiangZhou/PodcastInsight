import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';

/// Creates a test-friendly MaterialApp.router with required localizations.
///
/// Use this for widget tests that need routing support.
Widget testAppWithRouter({
  required GoRouter router,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
    ),
  );
}

/// Helper to tap a widget and wait for it to settle.
Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.pumpAndSettle();
  await tester.tap(finder, warnIfMissed: false);
  await tester.pump();
}
