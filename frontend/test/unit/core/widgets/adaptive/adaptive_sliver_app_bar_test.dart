import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive_sliver_app_bar.dart';

void main() {
  group('AdaptiveSliverAppBar', () {
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
          body: CustomScrollView(
            slivers: [
              AdaptiveSliverAppBar(title: 'Test Title'),
              const SliverToBoxAdapter(child: SizedBox(height: 800)),
            ],
          ),
        ),
      );
    }

    testWidgets('renders SliverAppBar on Android', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(platform: TargetPlatform.android),
      );
      expect(find.byType(SliverAppBar), findsOneWidget);
      expect(find.text('Test Title'), findsOneWidget);
    });

    testWidgets('renders CupertinoSliverNavigationBar on iOS', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(platform: TargetPlatform.iOS),
      );
      expect(find.byType(CupertinoSliverNavigationBar), findsOneWidget);
    });
  });
}
