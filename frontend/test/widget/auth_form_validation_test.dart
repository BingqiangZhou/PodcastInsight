import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/features/auth/presentation/pages/login_page.dart';
import 'package:personal_ai_assistant/features/auth/presentation/pages/register_page.dart';
import 'package:personal_ai_assistant/shared/widgets/custom_text_field.dart';

const _enLocale = Locale('en');

Finder _customTextFieldByLabel(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is CustomTextField && widget.label == label,
  );
}

Future<void> _pumpAuthPage(WidgetTester tester, Widget home) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: _enLocale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapButtonByKey(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _setTermsAgreed(WidgetTester tester, bool value) async {
  final termsCheckbox = find.byType(Checkbox).last;
  await tester.ensureVisible(termsCheckbox);
  final currentValue = tester.widget<Checkbox>(termsCheckbox).value ?? false;
  if (currentValue != value) {
    await tester.tap(termsCheckbox);
    await tester.pumpAndSettle();
  }
}

void main() {
  group('Auth Form Validation Tests', () {
    testWidgets('Register form should validate email correctly', (
      tester,
    ) async {
      await _pumpAuthPage(tester, const RegisterPage());

      final emailField = _customTextFieldByLabel('Email');
      await _setTermsAgreed(tester, true);

      await tester.enterText(emailField, 'invalid-email');
      await _tapButtonByKey(tester, const Key('register_button'));

      expect(find.text('Please enter a valid email'), findsOneWidget);

      await tester.enterText(emailField, 'test@example.com');
      await _tapButtonByKey(tester, const Key('register_button'));

      expect(find.text('Please enter a valid email'), findsNothing);
    });

    testWidgets('Register form should validate password correctly', (
      tester,
    ) async {
      await _pumpAuthPage(tester, const RegisterPage());

      final passwordField = _customTextFieldByLabel('Password');
      await _setTermsAgreed(tester, true);

      await tester.enterText(passwordField, 'password123');
      await _tapButtonByKey(tester, const Key('register_button'));
      expect(
        find.text('Contain at least one uppercase letter'),
        findsOneWidget,
      );

      await tester.enterText(passwordField, 'PASSWORD123');
      await _tapButtonByKey(tester, const Key('register_button'));
      expect(
        find.text('Contain at least one lowercase letter'),
        findsOneWidget,
      );

      await tester.enterText(passwordField, 'Password');
      await _tapButtonByKey(tester, const Key('register_button'));
      expect(find.text('Contain at least one number'), findsOneWidget);

      await tester.enterText(passwordField, 'Password123');
      await _tapButtonByKey(tester, const Key('register_button'));

      expect(find.text('Contain at least one uppercase letter'), findsNothing);
      expect(find.text('Contain at least one lowercase letter'), findsNothing);
      expect(find.text('Contain at least one number'), findsNothing);
    });

    testWidgets('Register form should validate password confirmation', (
      tester,
    ) async {
      await _pumpAuthPage(tester, const RegisterPage());

      // Fill required fields so validation reaches confirm-password
      await tester.enterText(
        _customTextFieldByLabel('Full Name'),
        'Test User',
      );
      await tester.enterText(
        _customTextFieldByLabel('Email'),
        'test@example.com',
      );

      final passwordField = _customTextFieldByLabel('Password');
      final confirmPasswordField = _customTextFieldByLabel('Confirm Password');
      await _setTermsAgreed(tester, true);

      await tester.enterText(passwordField, 'Password123');
      await tester.enterText(confirmPasswordField, 'DifferentPassword');
      await _tapButtonByKey(tester, const Key('register_button'));
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match'), findsOneWidget);

      await tester.enterText(confirmPasswordField, 'Password123');
      await _tapButtonByKey(tester, const Key('register_button'));
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match'), findsNothing);
    });

    testWidgets('Login form should validate fields', (
      tester,
    ) async {
      await _pumpAuthPage(tester, const LoginPage());

      final emailField = _customTextFieldByLabel('Email');
      final passwordField = _customTextFieldByLabel('Password');

      await _tapButtonByKey(tester, const Key('login_button'));

      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);

      await tester.enterText(emailField, 'invalid-email');
      await _tapButtonByKey(tester, const Key('login_button'));

      expect(find.text('Please enter a valid email'), findsOneWidget);

      await tester.enterText(emailField, 'test@example.com');
      await tester.enterText(passwordField, '123');
      await _tapButtonByKey(tester, const Key('login_button'));

      expect(
        find.text('Password must be at least 8 characters'),
        findsOneWidget,
      );

      await tester.enterText(passwordField, 'validpassword');
      await _tapButtonByKey(tester, const Key('login_button'));

      expect(find.text('Please enter your email'), findsNothing);
      expect(find.text('Please enter your password'), findsNothing);
      expect(find.text('Please enter a valid email'), findsNothing);
      expect(find.text('Password must be at least 8 characters'), findsNothing);
    });

    testWidgets('Should navigate between login and register', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/login',
        routes: [
          GoRoute(
            path: '/login',
            builder: (context, state) => const LoginPage(),
          ),
          GoRoute(
            path: '/register',
            builder: (context, state) => const RegisterPage(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            locale: _enLocale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Dawn's near. Let's begin."), findsOneWidget);
      expect(find.text('Sign In'), findsWidgets);

      final signUpLink = find.text('Sign Up');
      await tester.ensureVisible(signUpLink);
      await tester.tap(signUpLink);
      await tester.pumpAndSettle();

      expect(find.text('Create Account'), findsWidgets);
      expect(find.text('Already have an account?'), findsOneWidget);

      final signInLink = find.text('Sign In').last;
      await tester.ensureVisible(signInLink);
      await tester.tap(signInLink);
      await tester.pumpAndSettle();

      expect(find.text("Dawn's near. Let's begin."), findsOneWidget);
    });

    testWidgets('Should toggle password visibility', (
      tester,
    ) async {
      await _pumpAuthPage(tester, const LoginPage());

      final toggleButton = find.byIcon(Icons.visibility_off);

      expect(toggleButton, findsOneWidget);

      await tester.tap(toggleButton);
      await tester.pump();

      expect(find.byIcon(Icons.visibility), findsOneWidget);
      expect(toggleButton, findsNothing);

      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pump();

      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
      expect(find.byIcon(Icons.visibility), findsNothing);
    });

    testWidgets('Should handle remember me checkbox', (
      tester,
    ) async {
      await _pumpAuthPage(tester, const LoginPage());

      final checkbox = find.byType(Checkbox);
      final initialValue = tester.widget<Checkbox>(checkbox).value ?? false;

      await tester.tap(checkbox);
      await tester.pump();

      expect(tester.widget<Checkbox>(checkbox).value, isNot(initialValue));

      await tester.tap(checkbox);
      await tester.pump();

      expect(tester.widget<Checkbox>(checkbox).value, initialValue);
    });

    testWidgets('Should show terms agreement error', (
      tester,
    ) async {
      await _pumpAuthPage(tester, const RegisterPage());

      await tester.enterText(_customTextFieldByLabel('Full Name'), 'Test');
      await tester.enterText(
        _customTextFieldByLabel('Email'),
        'test@example.com',
      );
      await tester.enterText(
        _customTextFieldByLabel('Password'),
        'Password123',
      );
      await tester.enterText(
        _customTextFieldByLabel('Confirm Password'),
        'Password123',
      );

      await _tapButtonByKey(tester, const Key('register_button'));

      expect(find.text('I agree to the Terms and Conditions'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
