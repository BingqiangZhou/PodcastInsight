import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive_button.dart';

void main() {
  group('AdaptiveButton', () {
    Widget _buildTestWidget(
      AdaptiveButtonStyle style, {
      TargetPlatform platform = TargetPlatform.android,
      bool isLoading = false,
      VoidCallback? onPressed,
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
          body: AdaptiveButton(
            style: style,
            isLoading: isLoading,
            onPressed: onPressed ?? () {},
            child: Text('Test'),
          ),
        ),
      );
    }

    testWidgets('renders filled button on Android', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          AdaptiveButtonStyle.filled,
          platform: TargetPlatform.android,
        ),
      );
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.text('Test'), findsOneWidget);
    });

    testWidgets('renders text button on Android', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          AdaptiveButtonStyle.text,
          platform: TargetPlatform.android,
        ),
      );
      expect(find.byType(TextButton), findsOneWidget);
    });

    testWidgets('renders outlined button on Android', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          AdaptiveButtonStyle.outlined,
          platform: TargetPlatform.android,
        ),
      );
      expect(find.byType(OutlinedButton), findsOneWidget);
    });

    testWidgets('renders CupertinoButton on iOS', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          AdaptiveButtonStyle.filled,
          platform: TargetPlatform.iOS,
        ),
      );
      expect(find.byType(CupertinoButton), findsOneWidget);
      expect(find.text('Test'), findsOneWidget);
    });

    testWidgets('shows loading indicator when isLoading is true on iOS', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          AdaptiveButtonStyle.filled,
          platform: TargetPlatform.iOS,
          isLoading: true,
        ),
      );
      // iOS uses CupertinoActivityIndicator directly
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    });

    testWidgets('shows loading indicator when isLoading is true on Android', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          AdaptiveButtonStyle.filled,
          platform: TargetPlatform.android,
          isLoading: true,
        ),
      );
      // Android uses CircularProgressIndicator.adaptive()
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
