import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/features/auth/presentation/pages/login_page.dart';
import 'package:personal_ai_assistant/features/auth/presentation/pages/register_page.dart';
import 'package:personal_ai_assistant/shared/widgets/custom_text_field.dart';
import 'package:personal_ai_assistant/features/auth/presentation/widgets/password_text_field.dart';

import '../test_helpers.dart';

void main() {
  group('Authentication Flow Tests', () {
    testWidgets('Registration page has required fields', (WidgetTester tester) async {
      await tester.pumpWidget(testApp(child: const RegisterPage()));
      await tester.pumpAndSettle();

      // Find all form fields by type
      final textFields = find.byType(CustomTextField);
      final passwordFields = find.byType(PasswordTextField);

      // Verify fields exist
      expect(textFields, findsWidgets);
      expect(passwordFields, findsWidgets);

      // Verify the register button exists
      expect(find.text('Create Account'), findsWidgets);
    });

    testWidgets('Login page has required fields', (WidgetTester tester) async {
      await tester.pumpWidget(testApp(child: const LoginPage()));
      await tester.pumpAndSettle();

      // Find form fields
      final textFields = find.byType(CustomTextField);
      final passwordFields = find.byType(PasswordTextField);

      // Verify fields exist
      expect(textFields, findsWidgets);
      expect(passwordFields, findsWidgets);

      // Verify the login button exists
      expect(find.text('Sign In'), findsWidgets);
    });

    testWidgets('Password visibility toggle', (WidgetTester tester) async {
      await tester.pumpWidget(testApp(child: const LoginPage()));
      await tester.pumpAndSettle();

      final toggleButton = find.byIcon(Icons.visibility_off);

      // Initially should show visibility off icon
      expect(toggleButton, findsOneWidget);

      // Toggle visibility
      await tapAndSettle(tester, toggleButton);

      // Should show visibility icon
      expect(find.byIcon(Icons.visibility), findsOneWidget);

      // Toggle back
      await tapAndSettle(tester, find.byIcon(Icons.visibility));
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    });

    testWidgets('Remember me checkbox functionality', (WidgetTester tester) async {
      await tester.pumpWidget(testApp(child: const LoginPage()));
      await tester.pumpAndSettle();

      final rememberCheckbox = find.byType(Checkbox);

      // Should be unchecked initially
      expect(tester.widget<Checkbox>(rememberCheckbox).value, isFalse);

      // Check the checkbox
      await tapAndSettle(tester, rememberCheckbox);

      expect(tester.widget<Checkbox>(rememberCheckbox).value, isTrue);

      // Uncheck the checkbox
      await tapAndSettle(tester, rememberCheckbox);

      expect(tester.widget<Checkbox>(rememberCheckbox).value, isFalse);
    });

    testWidgets('Register page has terms checkbox', (WidgetTester tester) async {
      await tester.pumpWidget(testApp(child: const RegisterPage()));
      await tester.pumpAndSettle();

      // Find checkboxes (terms checkbox)
      final checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsWidgets);
    });
  });
}
