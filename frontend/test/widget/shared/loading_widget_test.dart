import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/widgets/app_shells.dart';
import 'package:personal_ai_assistant/shared/widgets/loading_widget.dart';

void main() {
  testWidgets('LoadingOverlay shows bare loading content without GlassPanel', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LoadingOverlay(
            isLoading: true,
            loadingText: 'Signing in...',
            child: SizedBox.expand(),
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Signing in...'), findsOneWidget);
    expect(find.byKey(const Key('loading_overlay_content')), findsOneWidget);
    expect(find.byType(GlassPanel), findsNothing);
  });
}
