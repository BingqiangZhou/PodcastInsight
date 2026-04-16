import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive_search_bar.dart';

void main() {
  group('AdaptiveSearchBar', () {
    Widget _buildTestWidget({
      TargetPlatform platform = TargetPlatform.android,
    }) {
      return MaterialApp(
        theme: ThemeData(platform: platform, useMaterial3: true),
        builder: (context, child) {
          return CupertinoTheme(
            data: const CupertinoThemeData(),
            child: child!,
          );
        },
        home: Scaffold(
          body: AdaptiveSearchBar(
            controller: TextEditingController(),
            placeholder: 'Search',
          ),
        ),
      );
    }

    testWidgets('renders Material SearchBar on Android', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(platform: TargetPlatform.android),
      );
      expect(find.byType(SearchBar), findsOneWidget);
    });

    testWidgets('renders CupertinoSearchTextField on iOS', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(platform: TargetPlatform.iOS),
      );
      expect(find.byType(CupertinoSearchTextField), findsOneWidget);
    });
  });
}
