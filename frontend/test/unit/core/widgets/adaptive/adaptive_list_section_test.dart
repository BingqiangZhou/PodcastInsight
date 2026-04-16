import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive_list_section.dart';

void main() {
  group('AdaptiveListSection', () {
    Widget _buildTestWidget({
      TargetPlatform platform = TargetPlatform.android,
      List<Widget>? children,
      String? footer,
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
          body: AdaptiveListSection(
            header: 'Section Header',
            footer: footer,
            children: children ?? [Text('Item 1'), Text('Item 2')],
          ),
        ),
      );
    }

    testWidgets('renders Material Card on Android', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(platform: TargetPlatform.android),
      );
      expect(find.byType(Card), findsOneWidget);
      expect(find.text('Section Header'), findsOneWidget);
      expect(find.text('Item 1'), findsOneWidget);
    });

    testWidgets('renders CupertinoListSection on iOS', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(platform: TargetPlatform.iOS),
      );
      expect(find.byType(CupertinoListSection), findsOneWidget);
      expect(find.text('Section Header'), findsOneWidget);
    });

    testWidgets('renders footer when provided', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(footer: 'Footer text'),
      );
      expect(find.text('Footer text'), findsOneWidget);
    });
  });
}
