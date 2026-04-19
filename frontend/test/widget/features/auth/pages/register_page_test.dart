import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive_switch.dart';
import 'package:personal_ai_assistant/features/auth/presentation/pages/register_page.dart';
import 'package:personal_ai_assistant/features/auth/presentation/providers/auth_provider.dart';

class MockAuthNotifier extends AuthNotifier {
  MockAuthNotifier() : super();

  @override
  AuthState build() {
    return const AuthState();
  }
}

void main() {
  group('RegisterPage Widget Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(MockAuthNotifier.new),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    Widget createTestWidget() {
      return UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RegisterPage(),
        ),
      );
    }

    testWidgets('renders register form with all required fields', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check for register button
      expect(find.byKey(const Key('register_button')), findsOneWidget);

      // Check for text input fields:
      // Username (CustomTextField -> TextFormField), Email (CustomTextField -> TextFormField),
      // Password (PasswordTextField -> CustomTextField -> TextFormField),
      // Confirm Password (PasswordTextField -> CustomTextField -> TextFormField)
      // Total: 4 TextFormField widgets
      expect(find.byType(TextFormField), findsNWidgets(4));

      // Check for adaptive switches: Remember Me + Terms agreement
      expect(find.byType(AdaptiveSwitch), findsNWidgets(2));
    });

    testWidgets('displays header icon and title text', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check for person_add icon in the header container
      expect(find.byIcon(Icons.person_add), findsOneWidget);

      // Check for title text "Create Account" (appears in AuthShell title and button)
      expect(find.text('Create Account'), findsAtLeast(1));

      // Check for subtitle text "Join us to get started"
      expect(find.text('Join us to get started'), findsOneWidget);
    });

    testWidgets('has register button with proper key', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('register_button')), findsOneWidget);
    });

    testWidgets('has terms acceptance switch', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should have 2 AdaptiveSwitch widgets: Remember Me + Terms
      expect(find.byType(AdaptiveSwitch), findsNWidgets(2));

      // Check for Terms and Conditions text (rendered via Text.rich TextSpan)
      expect(find.text('Terms and Conditions'), findsOneWidget);

      // Check for Privacy Policy text (rendered via Text.rich TextSpan)
      expect(find.text('Privacy Policy'), findsOneWidget);
    });

    testWidgets('shows validation errors for empty fields on submit', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Scroll to the register button so it is visible for tapping
      await tester.ensureVisible(find.byKey(const Key('register_button')));
      await tester.pumpAndSettle();

      // Tap register button without filling any fields
      await tester.tap(find.byKey(const Key('register_button')));
      await tester.pumpAndSettle();

      // Check for validation error messages
      expect(find.text('Please enter your name'), findsOneWidget);
      expect(find.text('Please enter your email'), findsOneWidget);
      // "Please enter your password" appears for both password and confirm password fields
      expect(find.text('Please enter your password'), findsNWidgets(2));
    });

    testWidgets('shows validation error for password mismatch', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find text fields by their labels (the label Text widgets above each field)
      final nameField = find.widgetWithText(Column, 'Full Name');
      final emailField = find.widgetWithText(Column, 'Email');
      final passwordField = find.widgetWithText(Column, 'Password');
      final confirmPasswordField = find.widgetWithText(Column, 'Confirm Password');

      // Enter text into each TextFormField (they are descendants of the labeled Columns)
      await tester.enterText(find.descendant(of: nameField, matching: find.byType(TextFormField)).first, 'John');
      await tester.enterText(find.descendant(of: emailField, matching: find.byType(TextFormField)).first, 'test@example.com');
      await tester.enterText(find.descendant(of: passwordField, matching: find.byType(TextFormField)).first, 'Password1');
      await tester.enterText(find.descendant(of: confirmPasswordField, matching: find.byType(TextFormField)).first, 'DifferentPassword1');

      // Scroll to the register button so it is visible for tapping
      await tester.ensureVisible(find.byKey(const Key('register_button')));
      await tester.pumpAndSettle();

      // Tap register button
      await tester.tap(find.byKey(const Key('register_button')));
      await tester.pumpAndSettle();

      // Check for password mismatch error
      expect(find.text('Passwords do not match'), findsOneWidget);
    });

    testWidgets('has sign in link', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check for "Already have an account?" text
      expect(find.text('Already have an account?'), findsOneWidget);

      // Check for "Sign In" link
      expect(find.text('Sign In'), findsOneWidget);
    });

    testWidgets('has remember me switch', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check for "Remember me" text
      expect(find.text('Remember me'), findsOneWidget);
    });
  });
}
