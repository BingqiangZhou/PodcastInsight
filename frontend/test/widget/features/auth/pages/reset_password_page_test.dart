import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/features/auth/presentation/pages/reset_password_page.dart';
import 'package:personal_ai_assistant/features/auth/presentation/providers/auth_provider.dart';
import 'package:personal_ai_assistant/features/auth/presentation/widgets/password_text_field.dart';

class MockAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    return const AuthState();
  }
}

void main() {
  group('ResetPasswordPage Widget Tests', () {
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

    Widget createTestWidget({String? token}) {
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ResetPasswordPage(token: token),
        ),
      );
    }

    testWidgets('renders without crashing when token is provided',
        (tester) async {
      await tester.pumpWidget(createTestWidget(token: 'valid-token'));
      await tester.pumpAndSettle();

      expect(find.byType(ResetPasswordPage), findsOneWidget);
    });

    testWidgets('shows password fields and reset button', (tester) async {
      await tester.pumpWidget(createTestWidget(token: 'valid-token'));
      await tester.pumpAndSettle();

      // Check for PasswordTextField widgets (password + confirm password)
      expect(find.byType(PasswordTextField), findsNWidgets(2));

      // Check for reset password button
      expect(
          find.byKey(const Key('reset_password_button')), findsOneWidget);
    });

    testWidgets('shows lock icon in header', (tester) async {
      await tester.pumpWidget(createTestWidget(token: 'valid-token'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.lock_open), findsOneWidget);
    });

    testWidgets('shows error dialog when token is null', (tester) async {
      await tester.pumpWidget(createTestWidget(token: null));
      await tester.pumpAndSettle();

      // Should show an error dialog since token is null
      final context = tester.element(find.byType(ResetPasswordPage));
      final l10n = AppLocalizations.of(context)!;

      expect(find.text(l10n.error), findsOneWidget);
    });

    testWidgets('shows password requirement items', (tester) async {
      await tester.pumpWidget(createTestWidget(token: 'valid-token'));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(ResetPasswordPage));
      final l10n = AppLocalizations.of(context)!;

      expect(
          find.text(l10n.auth_password_requirement_min_length), findsOneWidget);
      expect(
          find.text(l10n.auth_password_requirement_uppercase), findsOneWidget);
      expect(
          find.text(l10n.auth_password_requirement_lowercase), findsOneWidget);
      expect(
          find.text(l10n.auth_password_requirement_number), findsOneWidget);
    });
  });
}
