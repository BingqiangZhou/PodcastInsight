import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/storage/local_storage_service.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_search_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/country_selector_provider.dart';

void main() {
  // ── PodcastCountry ────────────────────────────────────────────────

  group('PodcastCountry', () {
    // -- Default values (code, name, flag) --

    group('default values', () {
      test('china has correct code, localizationKey, and flag', () {
        expect(PodcastCountry.china.code, 'cn');
        expect(PodcastCountry.china.localizationKey, 'podcast_country_china');
        expect(PodcastCountry.china.flag, '\u{1F1E8}\u{1F1F3}'); // C+R flag emoji
        expect(PodcastCountry.china.isPopular, isTrue);
      });

      test('usa has correct Code, localizationKey, and flag', () {
        expect(PodcastCountry.usa.code, 'us');
        expect(PodcastCountry.usa.localizationKey, 'podcast_country_usa');
        expect(PodcastCountry.usa.flag, '\u{1F1FA}\u{1F1F8}'); // U+S flag emoji
        expect(PodcastCountry.usa.isPopular, isTrue);
      });

      test('japan has correct code, localizationKey, and flag', () {
        expect(PodcastCountry.japan.code, 'jp');
        expect(PodcastCountry.japan.localizationKey, 'podcast_country_japan');
        expect(PodcastCountry.japan.isPopular, isTrue);
      });

      test('uk has correct code, localizationKey, and flag', () {
        expect(PodcastCountry.uk.code, 'gb');
        expect(PodcastCountry.uk.localizationKey, 'podcast_country_uk');
        expect(PodcastCountry.uk.isPopular, isTrue);
      });

      test('germany has correct code and is popular', () {
        expect(PodcastCountry.germany.code, 'de');
        expect(PodcastCountry.germany.localizationKey, 'podcast_country_germany');
        expect(PodcastCountry.germany.isPopular, isTrue);
      });

      test('non-popular country defaults isPopular to false', () {
        expect(PodcastCountry.france.isPopular, isFalse);
        expect(PodcastCountry.canada.isPopular, isFalse);
        expect(PodcastCountry.australia.isPopular, isFalse);
        expect(PodcastCountry.korea.isPopular, isFalse);
        expect(PodcastCountry.taiwan.isPopular, isFalse);
        expect(PodcastCountry.hongKong.isPopular, isFalse);
        expect(PodcastCountry.india.isPopular, isFalse);
        expect(PodcastCountry.brazil.isPopular, isFalse);
        expect(PodcastCountry.mexico.isPopular, isFalse);
        expect(PodcastCountry.spain.isPopular, isFalse);
        expect(PodcastCountry.italy.isPopular, isFalse);
      });
    });

    // -- Equality --

    group('equality', () {
      test('same enum values are equal', () {
        expect(PodcastCountry.china, equals(PodcastCountry.china));
        expect(PodcastCountry.usa, equals(PodcastCountry.usa));
      });

      test('different enum values are not equal', () {
        expect(PodcastCountry.china, isNot(equals(PodcastCountry.usa)));
        expect(PodcastCountry.uk, isNot(equals(PodcastCountry.germany)));
      });
    });

    // -- values list --

    group('values', () {
      test('contains all 16 countries', () {
        expect(PodcastCountry.values, hasLength(16));
      });

      test('contains every defined country', () {
        expect(
          PodcastCountry.values,
          containsAll([
            PodcastCountry.china,
            PodcastCountry.usa,
            PodcastCountry.japan,
            PodcastCountry.uk,
            PodcastCountry.germany,
            PodcastCountry.france,
            PodcastCountry.canada,
            PodcastCountry.australia,
            PodcastCountry.korea,
            PodcastCountry.taiwan,
            PodcastCountry.hongKong,
            PodcastCountry.india,
            PodcastCountry.brazil,
            PodcastCountry.mexico,
            PodcastCountry.spain,
            PodcastCountry.italy,
          ]),
        );
      });
    });

    // -- popularRegions --

    group('popularRegions', () {
      test('returns only popular countries', () {
        final popular = PodcastCountry.popularRegions;
        for (final country in popular) {
          expect(country.isPopular, isTrue);
        }
      });

      test('contains exactly 5 popular countries', () {
        expect(PodcastCountry.popularRegions, hasLength(5));
      });

      test('contains china, usa, japan, uk, germany', () {
        final popular = PodcastCountry.popularRegions;
        expect(popular, containsAll([
          PodcastCountry.china,
          PodcastCountry.usa,
          PodcastCountry.japan,
          PodcastCountry.uk,
          PodcastCountry.germany,
        ]));
      });

      test('does not contain non-popular countries', () {
        final popular = PodcastCountry.popularRegions;
        expect(popular, isNot(contains(PodcastCountry.france)));
        expect(popular, isNot(contains(PodcastCountry.canada)));
        expect(popular, isNot(contains(PodcastCountry.korea)));
      });
    });

    // -- Common presets --

    group('common preset countries', () {
      test('us has expected values', () {
        expect(PodcastCountry.usa.code, 'us');
        expect(PodcastCountry.usa.flag, isNotEmpty);
      });

      test('cn has expected values', () {
        expect(PodcastCountry.china.code, 'cn');
        expect(PodcastCountry.china.flag, isNotEmpty);
      });

      test('gb has expected values', () {
        expect(PodcastCountry.uk.code, 'gb');
        expect(PodcastCountry.uk.flag, isNotEmpty);
      });

      test('jp has expected values', () {
        expect(PodcastCountry.japan.code, 'jp');
        expect(PodcastCountry.japan.flag, isNotEmpty);
      });

      test('kr has expected values', () {
        expect(PodcastCountry.korea.code, 'kr');
        expect(PodcastCountry.korea.flag, isNotEmpty);
      });

      test('tw has expected values', () {
        expect(PodcastCountry.taiwan.code, 'tw');
        expect(PodcastCountry.taiwan.flag, isNotEmpty);
      });

      test('hk has expected values', () {
        expect(PodcastCountry.hongKong.code, 'hk');
        expect(PodcastCountry.hongKong.flag, isNotEmpty);
      });
    });
  });

  // ── CountrySelectorState ──────────────────────────────────────────

  group('CountrySelectorState', () {
    // -- Default values --

    test('default values with required country', () {
      const state = CountrySelectorState(
        selectedCountry: PodcastCountry.china,
      );
      expect(state.selectedCountry, PodcastCountry.china);
      expect(state.isLoading, isFalse);
    });

    test('can set isLoading to true', () {
      const state = CountrySelectorState(
        selectedCountry: PodcastCountry.usa,
        isLoading: true,
      );
      expect(state.selectedCountry, PodcastCountry.usa);
      expect(state.isLoading, isTrue);
    });

    // -- copyWith --

    group('copyWith', () {
      test('updates selectedCountry', () {
        const original = CountrySelectorState(
          selectedCountry: PodcastCountry.china,
        );
        final updated = original.copyWith(
          selectedCountry: PodcastCountry.usa,
        );

        expect(updated.selectedCountry, PodcastCountry.usa);
        expect(updated.isLoading, isFalse);
      });

      test('updates isLoading', () {
        const original = CountrySelectorState(
          selectedCountry: PodcastCountry.china,
        );
        final updated = original.copyWith(isLoading: true);

        expect(updated.selectedCountry, PodcastCountry.china);
        expect(updated.isLoading, isTrue);
      });

      test('preserves fields when not specified', () {
        const original = CountrySelectorState(
          selectedCountry: PodcastCountry.japan,
          isLoading: true,
        );
        final updated = original.copyWith(
          selectedCountry: PodcastCountry.uk,
        );

        expect(updated.selectedCountry, PodcastCountry.uk);
        expect(updated.isLoading, isTrue);
      });

      test('returns new instance', () {
        const original = CountrySelectorState(
          selectedCountry: PodcastCountry.china,
        );
        final updated = original.copyWith();

        expect(identical(original, updated), isFalse);
        expect(updated.selectedCountry, PodcastCountry.china);
        expect(updated.isLoading, isFalse);
      });

      test('multiple copyWith calls chain correctly', () {
        const state = CountrySelectorState(
          selectedCountry: PodcastCountry.china,
        );
        final step1 = state.copyWith(isLoading: true);
        final step2 = step1.copyWith(selectedCountry: PodcastCountry.france);
        final step3 = step2.copyWith(isLoading: false);

        expect(step3.selectedCountry, PodcastCountry.france);
        expect(step3.isLoading, isFalse);
      });
    });

    // -- Equality --

    group('equality', () {
      test('equal when all fields match', () {
        const a = CountrySelectorState(
          selectedCountry: PodcastCountry.usa,
          isLoading: true,
        );
        const b = CountrySelectorState(
          selectedCountry: PodcastCountry.usa,
          isLoading: true,
        );
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('not equal when selectedCountry differs', () {
        const a = CountrySelectorState(
          selectedCountry: PodcastCountry.china,
        );
        const b = CountrySelectorState(
          selectedCountry: PodcastCountry.usa,
        );
        expect(a, isNot(equals(b)));
      });

      test('not equal when isLoading differs', () {
        const a = CountrySelectorState(
          selectedCountry: PodcastCountry.china,
        );
        const b = CountrySelectorState(
          selectedCountry: PodcastCountry.china,
          isLoading: true,
        );
        expect(a, isNot(equals(b)));
      });
    });
  });

  // ── CountrySelectorNotifier (integration with Riverpod) ──────────

  group('CountrySelectorNotifier', () {
    late ProviderContainer container;
    late _MockLocalStorageService localStorage;

    setUp(() {
      localStorage = _MockLocalStorageService();
      container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(localStorage),
        ],
      );
      addTearDown(() {
        container.dispose();
      });
    });

    // -- Initial state --

    group('initial state', () {
      test('defaults to china', () {
        final state = container.read(countrySelectorProvider);
        expect(state.selectedCountry, PodcastCountry.china);
        expect(state.isLoading, isFalse);
      });
    });

    // -- selectCountry --

    group('selectCountry', () {
      test('updates state to the selected country', () async {
        final notifier = container.read(countrySelectorProvider.notifier);
        await notifier.selectCountry(PodcastCountry.usa);

        final state = container.read(countrySelectorProvider);
        expect(state.selectedCountry, PodcastCountry.usa);
      });

      test('persists country code to local storage', () async {
        final notifier = container.read(countrySelectorProvider.notifier);
        await notifier.selectCountry(PodcastCountry.japan);

        final saved =
            await localStorage.getString('podcast_search_country');
        expect(saved, 'jp');
      });

      test('can switch countries multiple times', () async {
        final notifier = container.read(countrySelectorProvider.notifier);

        await notifier.selectCountry(PodcastCountry.usa);
        expect(
          container.read(countrySelectorProvider).selectedCountry,
          PodcastCountry.usa,
        );

        await notifier.selectCountry(PodcastCountry.germany);
        expect(
          container.read(countrySelectorProvider).selectedCountry,
          PodcastCountry.germany,
        );

        await notifier.selectCountry(PodcastCountry.china);
        expect(
          container.read(countrySelectorProvider).selectedCountry,
          PodcastCountry.china,
        );
      });
    });

    // -- selectedCountry getter --

    group('selectedCountry getter', () {
      test('returns currently selected country', () async {
        final notifier = container.read(countrySelectorProvider.notifier);
        expect(notifier.selectedCountry, PodcastCountry.china);

        await notifier.selectCountry(PodcastCountry.uk);
        expect(notifier.selectedCountry, PodcastCountry.uk);
      });
    });

    // -- Loads saved country from storage --

    group('loads saved country from storage', () {
      test('uses saved country when available', () {
        fakeAsync((async) {
          final presetStorage = _MockLocalStorageService();
          presetStorage.presetString('podcast_search_country', 'jp');

          final testContainer = ProviderContainer(
            overrides: [
              localStorageServiceProvider.overrideWithValue(presetStorage),
            ],
          );

          // Read to trigger build(), which calls _loadSavedCountry
          testContainer.read(countrySelectorProvider);

          // Flush microtasks so the async _loadSavedCountry completes
          async.flushMicrotasks();

          final state = testContainer.read(countrySelectorProvider);
          expect(state.selectedCountry, PodcastCountry.japan);

          testContainer.dispose();
        });
      });

      test('falls back to china when saved code is invalid', () {
        fakeAsync((async) {
          final presetStorage = _MockLocalStorageService();
          presetStorage.presetString('podcast_search_country', 'xx_invalid');

          final testContainer = ProviderContainer(
            overrides: [
              localStorageServiceProvider.overrideWithValue(presetStorage),
            ],
          );

          testContainer.read(countrySelectorProvider);
          async.flushMicrotasks();

          final state = testContainer.read(countrySelectorProvider);
          expect(state.selectedCountry, PodcastCountry.china);

          testContainer.dispose();
        });
      });

      test('falls back to china when no saved preference', () {
        fakeAsync((async) {
          final emptyStorage = _MockLocalStorageService();

          final testContainer = ProviderContainer(
            overrides: [
              localStorageServiceProvider.overrideWithValue(emptyStorage),
            ],
          );

          testContainer.read(countrySelectorProvider);
          async.flushMicrotasks();

          final state = testContainer.read(countrySelectorProvider);
          expect(state.selectedCountry, PodcastCountry.china);

          testContainer.dispose();
        });
      });
    });
  });
}

/// Mock [LocalStorageService] backed by an in-memory map.
class _MockLocalStorageService implements LocalStorageService {
  final Map<String, dynamic> _storage = {};

  void presetString(String key, String value) => _storage[key] = value;

  @override
  Future<void> saveString(String key, String value) async =>
      _storage[key] = value;

  @override
  Future<String?> getString(String key) async => _storage[key] as String?;

  @override
  Future<void> saveBool(String key, bool value) async =>
      _storage[key] = value;

  @override
  Future<bool?> getBool(String key) async => _storage[key] as bool?;

  @override
  Future<void> saveInt(String key, int value) async => _storage[key] = value;

  @override
  Future<int?> getInt(String key) async => _storage[key] as int?;

  @override
  Future<void> saveDouble(String key, double value) async =>
      _storage[key] = value;

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
  Future<void> saveApiBaseUrl(String url) async =>
      _storage['api_base_url'] = url;

  @override
  Future<String?> getApiBaseUrl() async =>
      _storage['api_base_url'] as String?;

  @override
  Future<void> saveServerBaseUrl(String url) async =>
      _storage['server_base_url'] = url;

  @override
  Future<String?> getServerBaseUrl() async =>
      _storage['server_base_url'] as String?;
}
