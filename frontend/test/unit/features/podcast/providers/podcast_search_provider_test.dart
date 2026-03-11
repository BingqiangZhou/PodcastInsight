import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/storage/local_storage_service.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_search_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/services/itunes_search_service.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_search_provider.dart';

void main() {
  test('search debounce collapses rapid podcast queries into one request', () {
    fakeAsync((async) {
      final service = _FakeITunesSearchService();
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(
            _MockLocalStorageService(),
          ),
          iTunesSearchServiceProvider.overrideWithValue(service),
        ],
      );
      final subscription = container.listen(
        podcastSearchProvider,
        (previous, next) {},
        fireImmediately: true,
      );
      addTearDown(() {
        subscription.close();
        container.dispose();
      });

      final notifier = container.read(podcastSearchProvider.notifier);
      notifier.searchPodcasts('flutter');

      async.elapse(const Duration(milliseconds: 200));
      async.flushMicrotasks();
      expect(service.podcastSearchCallCount, 0);

      notifier.searchPodcasts('flutter riverpod');
      async.elapse(const Duration(milliseconds: 399));
      async.flushMicrotasks();
      expect(service.podcastSearchCallCount, 0);

      async.elapse(const Duration(milliseconds: 1));
      async.flushMicrotasks();

      expect(service.podcastSearchCallCount, 1);
      expect(container.read(podcastSearchProvider).currentQuery, 'flutter riverpod');
    });
  });
}

class _FakeITunesSearchService extends ITunesSearchService {
  int podcastSearchCallCount = 0;

  @override
  Future<ITunesSearchResponse> searchPodcasts({
    required String term,
    PodcastCountry country = PodcastCountry.china,
    int limit = 25,
  }) async {
    podcastSearchCallCount += 1;
    return const ITunesSearchResponse(resultCount: 0, results: []);
  }
}

class _MockLocalStorageService implements LocalStorageService {
  final Map<String, dynamic> _storage = {};

  @override
  Future<void> saveString(String key, String value) async => _storage[key] = value;

  @override
  Future<String?> getString(String key) async => _storage[key] as String?;

  @override
  Future<void> saveBool(String key, bool value) async => _storage[key] = value;

  @override
  Future<bool?> getBool(String key) async => _storage[key] as bool?;

  @override
  Future<void> saveInt(String key, int value) async => _storage[key] = value;

  @override
  Future<int?> getInt(String key) async => _storage[key] as int?;

  @override
  Future<void> saveDouble(String key, double value) async => _storage[key] = value;

  @override
  Future<double?> getDouble(String key) async => _storage[key] as double?;

  @override
  Future<void> saveStringList(String key, List<String> value) async =>
      _storage[key] = value;

  @override
  Future<List<String>?> getStringList(String key) async =>
      _storage[key] as List<String>?;

  @override
  Future<void> save<T>(String key, T value) async => _storage[key] = value;

  @override
  Future<T?> get<T>(String key) async => _storage[key] as T?;

  @override
  Future<void> remove(String key) async => _storage.remove(key);

  @override
  Future<void> clear() async => _storage.clear();

  @override
  Future<bool> containsKey(String key) async => _storage.containsKey(key);

  @override
  Future<void> cacheData(String key, dynamic data, {Duration? expiration}) async {
    _storage[key] = data;
  }

  @override
  Future<T?> getCachedData<T>(String key) async => _storage[key] as T?;

  @override
  Future<void> clearExpiredCache() async {}

  @override
  Future<void> saveApiBaseUrl(String url) async => _storage['api_base_url'] = url;

  @override
  Future<String?> getApiBaseUrl() async => _storage['api_base_url'] as String?;

  @override
  Future<void> saveServerBaseUrl(String url) async =>
      _storage['server_base_url'] = url;

  @override
  Future<String?> getServerBaseUrl() async =>
      _storage['server_base_url'] as String?;
}
