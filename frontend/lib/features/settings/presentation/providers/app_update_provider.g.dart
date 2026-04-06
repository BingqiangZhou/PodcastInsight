// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_update_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// App Update Notifier / 应用更新通知器

@ProviderFor(AppUpdate)
final appUpdateProvider = AppUpdateProvider._();

/// App Update Notifier / 应用更新通知器
final class AppUpdateProvider
    extends $NotifierProvider<AppUpdate, AppUpdateState> {
  /// App Update Notifier / 应用更新通知器
  AppUpdateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appUpdateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appUpdateHash();

  @$internal
  @override
  AppUpdate create() => AppUpdate();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppUpdateState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppUpdateState>(value),
    );
  }
}

String _$appUpdateHash() => r'90bca7927d79ecdf1d52f1579e1fe7e75b86b604';

/// App Update Notifier / 应用更新通知器

abstract class _$AppUpdate extends $Notifier<AppUpdateState> {
  AppUpdateState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AppUpdateState, AppUpdateState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AppUpdateState, AppUpdateState>,
              AppUpdateState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Provider for AppUpdateService

@ProviderFor(appUpdateService)
final appUpdateServiceProvider = AppUpdateServiceProvider._();

/// Provider for AppUpdateService

final class AppUpdateServiceProvider
    extends
        $FunctionalProvider<
          AppUpdateService,
          AppUpdateService,
          AppUpdateService
        >
    with $Provider<AppUpdateService> {
  /// Provider for AppUpdateService
  AppUpdateServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appUpdateServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appUpdateServiceHash();

  @$internal
  @override
  $ProviderElement<AppUpdateService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppUpdateService create(Ref ref) {
    return appUpdateService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppUpdateService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppUpdateService>(value),
    );
  }
}

String _$appUpdateServiceHash() => r'eff87092f47ed1f1ad8ff4ed29d60f2c09dd2533';

/// Stream provider that automatically checks for updates on app start
///
/// Usage:
/// ```dart
/// final updateState = ref.watch(autoUpdateCheckProvider);
/// if (updateState.hasUpdate) {
///   ShowUpdateDialog(release: updateState.latestRelease);
/// }
/// ```

@ProviderFor(autoUpdateCheck)
final autoUpdateCheckProvider = AutoUpdateCheckProvider._();

/// Stream provider that automatically checks for updates on app start
///
/// Usage:
/// ```dart
/// final updateState = ref.watch(autoUpdateCheckProvider);
/// if (updateState.hasUpdate) {
///   ShowUpdateDialog(release: updateState.latestRelease);
/// }
/// ```

final class AutoUpdateCheckProvider
    extends
        $FunctionalProvider<
          AsyncValue<AppUpdateState>,
          AppUpdateState,
          FutureOr<AppUpdateState>
        >
    with $FutureModifier<AppUpdateState>, $FutureProvider<AppUpdateState> {
  /// Stream provider that automatically checks for updates on app start
  ///
  /// Usage:
  /// ```dart
  /// final updateState = ref.watch(autoUpdateCheckProvider);
  /// if (updateState.hasUpdate) {
  ///   ShowUpdateDialog(release: updateState.latestRelease);
  /// }
  /// ```
  AutoUpdateCheckProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'autoUpdateCheckProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$autoUpdateCheckHash();

  @$internal
  @override
  $FutureProviderElement<AppUpdateState> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AppUpdateState> create(Ref ref) {
    return autoUpdateCheck(ref);
  }
}

String _$autoUpdateCheckHash() => r'c244b0607140a1b3a94b2ac130947b5353bd62dc';

/// Provider for manual update checking with loading state
///
/// Usage:
/// ```dart
/// ref.read(manualUpdateCheckProvider.notifier).check();
/// final state = ref.watch(manualUpdateCheckProvider);
/// if (state.hasUpdate) { ... }
/// ```

@ProviderFor(ManualUpdateCheck)
final manualUpdateCheckProvider = ManualUpdateCheckProvider._();

/// Provider for manual update checking with loading state
///
/// Usage:
/// ```dart
/// ref.read(manualUpdateCheckProvider.notifier).check();
/// final state = ref.watch(manualUpdateCheckProvider);
/// if (state.hasUpdate) { ... }
/// ```
final class ManualUpdateCheckProvider
    extends $NotifierProvider<ManualUpdateCheck, AppUpdateState> {
  /// Provider for manual update checking with loading state
  ///
  /// Usage:
  /// ```dart
  /// ref.read(manualUpdateCheckProvider.notifier).check();
  /// final state = ref.watch(manualUpdateCheckProvider);
  /// if (state.hasUpdate) { ... }
  /// ```
  ManualUpdateCheckProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'manualUpdateCheckProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$manualUpdateCheckHash();

  @$internal
  @override
  ManualUpdateCheck create() => ManualUpdateCheck();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppUpdateState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppUpdateState>(value),
    );
  }
}

String _$manualUpdateCheckHash() => r'a2bdbf40524b40829c7fee23d5e755ecc193a708';

/// Provider for manual update checking with loading state
///
/// Usage:
/// ```dart
/// ref.read(manualUpdateCheckProvider.notifier).check();
/// final state = ref.watch(manualUpdateCheckProvider);
/// if (state.hasUpdate) { ... }
/// ```

abstract class _$ManualUpdateCheck extends $Notifier<AppUpdateState> {
  AppUpdateState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AppUpdateState, AppUpdateState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AppUpdateState, AppUpdateState>,
              AppUpdateState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
