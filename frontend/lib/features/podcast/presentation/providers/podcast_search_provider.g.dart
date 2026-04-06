// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'podcast_search_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PodcastSearchNotifier)
final podcastSearchProvider = PodcastSearchNotifierProvider._();

final class PodcastSearchNotifierProvider
    extends $NotifierProvider<PodcastSearchNotifier, PodcastSearchState> {
  PodcastSearchNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'podcastSearchProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$podcastSearchNotifierHash();

  @$internal
  @override
  PodcastSearchNotifier create() => PodcastSearchNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PodcastSearchState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PodcastSearchState>(value),
    );
  }
}

String _$podcastSearchNotifierHash() =>
    r'd9550fc6dfcb4389840e316cf9c0f20be56f9c0a';

abstract class _$PodcastSearchNotifier extends $Notifier<PodcastSearchState> {
  PodcastSearchState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<PodcastSearchState, PodcastSearchState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PodcastSearchState, PodcastSearchState>,
              PodcastSearchState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
