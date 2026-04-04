import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal_ai_assistant/core/constants/app_constants.dart';
import 'package:personal_ai_assistant/core/storage/local_storage_service.dart';

/// Pre-loaded at startup with the value from SharedPreferences.
/// Override this provider in main() with the value read during initialization.
final initialOnboardingCompletedProvider = Provider<bool>((ref) {
  throw UnimplementedError(
    'initialOnboardingCompletedProvider must be overridden',
  );
});

/// Mutable state for whether onboarding has been completed.
/// Updated when the user finishes the onboarding flow.
final onboardingCompletedProvider =
    NotifierProvider<OnboardingCompletedNotifier, bool>(
  OnboardingCompletedNotifier.new,
);

class OnboardingCompletedNotifier extends Notifier<bool> {
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  @override
  bool build() {
    // Initialize from the pre-loaded value
    return ref.read(initialOnboardingCompletedProvider);
  }

  Future<void> complete() async {
    await _storage.saveBool(AppConstants.hasCompletedOnboardingKey, true);
    state = true;
  }
}
