import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive_segmented_control.dart';

void main() {
  group('AdaptiveSegmentedControl', () {
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
          body: AdaptiveSegmentedControl<int>(
            segments: {
              0: Text('All'),
              1: Text('Active'),
              2: Text('Done'),
            },
            selected: 0,
            onChanged: (_) {},
          ),
        ),
      );
    }

    testWidgets('renders SegmentedButton on Android', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(platform: TargetPlatform.android),
      );
      expect(find.byType(SegmentedButton<int>), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
    });

    testWidgets('renders CupertinoSlidingSegmentedControl on iOS', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(platform: TargetPlatform.iOS),
      );
      expect(
        find.byType(CupertinoSlidingSegmentedControl<int>),
        findsOneWidget,
      );
    });

    testWidgets('calls onChanged when segment tapped', (tester) async {
      int? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: AdaptiveSegmentedControl<int>(
              segments: {0: Text('A'), 1: Text('B')},
              selected: 0,
              onChanged: (v) => selected = v,
            ),
          ),
        ),
      );

      await tester.tap(find.text('B'));
      expect(selected, 1);
    });
  });
}
