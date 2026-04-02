// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_queue_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Service for managing offline request queue

@ProviderFor(offlineQueueService)
final offlineQueueServiceProvider = OfflineQueueServiceProvider._();

/// Service for managing offline request queue

final class OfflineQueueServiceProvider
    extends
        $FunctionalProvider<
          OfflineQueueService,
          OfflineQueueService,
          OfflineQueueService
        >
    with $Provider<OfflineQueueService> {
  /// Service for managing offline request queue
  OfflineQueueServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'offlineQueueServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$offlineQueueServiceHash();

  @$internal
  @override
  $ProviderElement<OfflineQueueService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  OfflineQueueService create(Ref ref) {
    return offlineQueueService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OfflineQueueService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OfflineQueueService>(value),
    );
  }
}

String _$offlineQueueServiceHash() =>
    r'a9b0107719aac86eec22970310820d19eef325ad';
