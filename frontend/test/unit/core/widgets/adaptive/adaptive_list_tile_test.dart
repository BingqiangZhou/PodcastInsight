import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive_list_tile.dart';

void main() {
  group('AdaptiveListTile', () {
    Widget _buildTestWidget({
      TargetPlatform platform = TargetPlatform.android,
      Widget? leading,
      Widget? trailing,
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
          body: AdaptiveListTile(
            title: Text('Title'),
            subtitle: Text('Subtitle'),
            leading: leading,
            trailing: trailing,
          ),
        ),
      );
    }

    testWidgets('renders Material ListTile on Android', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(platform: TargetPlatform.android),
      );
      expect(find.byType(ListTile), findsOneWidget);
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Subtitle'), findsOneWidget);
    });

    testWidgets('renders CupertinoListTile on iOS', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(platform: TargetPlatform.iOS),
      );
      expect(find.byType(CupertinoListTile), findsOneWidget);
      expect(find.text('Title'), findsOneWidget);
    });

    testWidgets('renders leading and trailing widgets', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          leading: Icon(Icons.star),
          trailing: Icon(Icons.chevron_right),
        ),
      );
      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });
  });
}
