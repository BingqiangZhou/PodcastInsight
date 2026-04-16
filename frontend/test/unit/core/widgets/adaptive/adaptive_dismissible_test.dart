import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive_dismissible.dart';

void main() {
  group('AdaptiveDismissible', () {
    Widget _buildTestWidget({
      TargetPlatform platform = TargetPlatform.android,
      VoidCallback? onDelete,
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
          body: AdaptiveDismissible(
            key: Key('test'),
            onDelete: onDelete ?? () {},
            child: ListTile(title: Text('Swipe me')),
          ),
        ),
      );
    }

    testWidgets('renders Dismissible on both platforms', (tester) async {
      await tester.pumpWidget(_buildTestWidget());
      expect(find.byType(Dismissible), findsOneWidget);
      expect(find.text('Swipe me'), findsOneWidget);
    });

    testWidgets('renders child content correctly', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(platform: TargetPlatform.iOS),
      );
      expect(find.text('Swipe me'), findsOneWidget);
    });
  });
}
