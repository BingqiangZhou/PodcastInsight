// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'country_selector_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 国家选择器 Notifier

@ProviderFor(CountrySelectorNotifier)
final countrySelectorProvider = CountrySelectorNotifierProvider._();

/// 国家选择器 Notifier
final class CountrySelectorNotifierProvider
    extends $NotifierProvider<CountrySelectorNotifier, CountrySelectorState> {
  /// 国家选择器 Notifier
  CountrySelectorNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'countrySelectorProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$countrySelectorNotifierHash();

  @$internal
  @override
  CountrySelectorNotifier create() => CountrySelectorNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CountrySelectorState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CountrySelectorState>(value),
    );
  }
}

String _$countrySelectorNotifierHash() =>
    r'a65bbed8ac9754d9ef3b9d9ece51cbc30b9f9902';

/// 国家选择器 Notifier

abstract class _$CountrySelectorNotifier
    extends $Notifier<CountrySelectorState> {
  CountrySelectorState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<CountrySelectorState, CountrySelectorState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CountrySelectorState, CountrySelectorState>,
              CountrySelectorState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
