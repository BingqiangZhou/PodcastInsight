import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_ai_assistant/features/auth/presentation/pages/login_page.dart';
import 'package:personal_ai_assistant/features/auth/presentation/pages/register_page.dart';
import 'package:personal_ai_assistant/features/auth/presentation/widgets/password_text_field.dart';
import 'package:personal_ai_assistant/shared/widgets/custom_text_field.dart';

import '../test_helpers.dart';

GoRouter _router(String initialLocation) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
    ],
  );
}

void main() {
  group('Simple Auth Widget Tests', () {
    testWidgets('Login page renders correctly', (tester) async {
      await tester.pumpWidget(testAppWithRouter(router: _router('/login')));
      await tester.pumpAndSettle();

      // Verify key UI elements exist
      expect(find.byType(CustomTextField), findsWidgets);
      expect(find.byType(PasswordTextField), findsWidgets);
      expect(find.text('Sign In'), findsWidgets);
    });

    testWidgets('Register page renders correctly', (tester) async {
      await tester.pumpWidget(testAppWithRouter(router: _router('/register')));
      await tester.pumpAndSettle();

      // Verify key UI elements exist
      expect(find.byType(CustomTextField), findsWidgets);
      expect(find.byType(PasswordTextField), findsWidgets);
      expect(find.text('Create Account'), findsWidgets);
    });

    testWidgets('Login page has email and password fields', (tester) async {
      await tester.pumpWidget(testAppWithRouter(router: _router('/login')));
      await tester.pumpAndSettle();

      // Find form fields by type
      final textFields = find.byType(CustomTextField);
      final passwordFields = find.byType(PasswordTextField);

      // Verify at least one of each exists
      expect(textFields, findsWidgets);
      expect(passwordFields, findsWidgets);
    });

    testWidgets('Register page has multiple fields', (tester) async {
      await tester.pumpWidget(testAppWithRouter(router: _router('/register')));
      await tester.pumpAndSettle();

      // Find form fields by type
      final textFields = find.byType(CustomTextField);
      final passwordFields = find.byType(PasswordTextField);

      // Verify fields exist
      expect(textFields, findsWidgets);
      expect(passwordFields, findsWidgets);
    });

    testWidgets('Password visibility toggle works', (tester) async {
      await tester.pumpWidget(testAppWithRouter(router: _router('/login')));
      await tester.pumpAndSettle();

      // Find and toggle password visibility
      final toggleButton = find.byIcon(Icons.visibility_off);
      expect(toggleButton, findsOneWidget);

      await tapAndSettle(tester, toggleButton);
      expect(find.byIcon(Icons.visibility), findsOneWidget);
    });
  });
}
