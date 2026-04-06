import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:personal_ai_assistant/features/auth/presentation/providers/auth_provider.dart';

void main() {
  group('ForgotPasswordPage', () {
    testWidgets('renders with fallback copy without localization delegates', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(_TestAuthNotifier.new),
          ],
          child: const MaterialApp(home: ForgotPasswordPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Forgot Password'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Send Reset Link'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows success state after submit completes', (tester) async {
      final router = GoRouter(
        initialLocation: '/forgot-password',
        routes: [
          GoRoute(
            path: '/forgot-password',
            builder: (context, state) => const ForgotPasswordPage(),
          ),
          GoRoute(
            path: '/login',
            builder: (context, state) =>
                const Scaffold(body: Text('Login Page')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(_TestAuthNotifier.new),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).first,
        'tester@example.com',
      );
      await tester.tap(find.byKey(const Key('forgot_password_submit_button')));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('back_to_login_button')), findsOneWidget);
      expect(
        find.byKey(const Key('forgot_password_success_message')),
        findsOneWidget,
      );
      expect(find.textContaining('tester@example.com'), findsOneWidget);
    });
  });
}

class _TestAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState();

  @override
  Future<void> forgotPassword(String email) async {
    state = state.copyWith(
      isLoading: true,
      clearFieldErrors: true,
      currentOperation: AuthOperation.forgotPassword,
    );
    await Future<void>.microtask(() {});
    state = state.copyWith(
      isLoading: false,
    );
  }

  @override
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}
