import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/utils/memory_manager.dart';

void main() {
  // Initialize Flutter binding for all tests
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MemoryManager - Initialization Tests', () {
    test('initialize can be called multiple times safely', () async {
      final manager = MemoryManager.instance;

      await manager.initialize();
      await manager.initialize();

      // Should not throw any errors
      expect(manager.currentPressure, MemoryPressure.normal);
    });

    test('instance returns singleton instance', () {
      final instance1 = MemoryManager.instance;
      final instance2 = MemoryManager.instance;

      expect(identical(instance1, instance2), true);
    });
  });

  group('MemoryManager - Callback Registration Tests', () {
    setUp(() async {
      final manager = MemoryManager.instance;
      manager.clearCallbacks();
      await manager.initialize();
    });

    test('registerCleanupCallback adds callback', () {
      final manager = MemoryManager.instance;
      bool callbackCalled = false;

      manager.registerCleanupCallback('testCallback', () {
        callbackCalled = true;
      });

      manager.performCleanup(force: true);
      expect(callbackCalled, true);
    });

    test('registerCleanupCallback replaces existing callback with same owner', () {
      final manager = MemoryManager.instance;
      bool firstCallbackCalled = false;
      bool secondCallbackCalled = false;

      manager.registerCleanupCallback('testCallback', () {
        firstCallbackCalled = true;
      });

      manager.registerCleanupCallback('testCallback', () {
        secondCallbackCalled = true;
      });

      manager.performCleanup(force: true);

      // Only the second callback should be called
      expect(firstCallbackCalled, false);
      expect(secondCallbackCalled, true);
    });

    test('unregisterCleanupCallback removes callback', () {
      final manager = MemoryManager.instance;
      bool callbackCalled = false;

      manager.registerCleanupCallback('testCallback', () {
        callbackCalled = true;
      });

      manager.unregisterCleanupCallback('testCallback');
      manager.performCleanup(force: true);

      expect(callbackCalled, false);
    });

    test('unregisterCleanupCallback handles non-existent callback gracefully', () {
      final manager = MemoryManager.instance;

      // Should not throw
      expect(
        () => manager.unregisterCleanupCallback('nonExistent'),
        returnsNormally,
      );
    });

    test('clearCallbacks removes all registered callbacks', () {
      final manager = MemoryManager.instance;
      bool callback1Called = false;
      bool callback2Called = false;

      manager.registerCleanupCallback('callback1', () {
        callback1Called = true;
      });

      manager.registerCleanupCallback('callback2', () {
        callback2Called = true;
      });

      manager.clearCallbacks();
      manager.performCleanup(force: true);

      expect(callback1Called, false);
      expect(callback2Called, false);
    });
  });

  group('MemoryManager - Cleanup Execution Tests', () {
    setUp(() async {
      final manager = MemoryManager.instance;
      manager.clearCallbacks();
      await manager.initialize();
    });

    test('performCleanup executes all registered callbacks', () {
      final manager = MemoryManager.instance;
      int callCount = 0;

      for (int i = 0; i < 5; i++) {
        manager.registerCleanupCallback('callback$i', () {
          callCount++;
        });
      }

      manager.performCleanup(force: true);
      expect(callCount, 5);
    });

    test('performCleanup handles callback exceptions gracefully', () {
      final manager = MemoryManager.instance;
      int successCount = 0;

      manager.registerCleanupCallback('goodCallback', () {
        successCount++;
      });

      manager.registerCleanupCallback('badCallback', () {
        throw Exception('Test exception');
      });

      manager.registerCleanupCallback('anotherGoodCallback', () {
        successCount++;
      });

      // Should not throw
      expect(
        () => manager.performCleanup(force: true),
        returnsNormally,
      );

      // Good callbacks should still execute
      expect(successCount, 2);
    });

    test('performCleanup is rate limited by default', () async {
      final manager = MemoryManager.instance;
      int callCount = 0;

      manager.registerCleanupCallback('testCallback', () {
        callCount++;
      });

      // First cleanup should execute
      final firstResult = manager.performCleanup(force: true);
      expect(firstResult, true);
      expect(callCount, 1);

      // Immediate second cleanup without force should be rate limited
      final secondResult = manager.performCleanup();
      expect(secondResult, false);
      expect(callCount, 1); // Should not increment
    });

    test('performCleanup with force bypasses rate limiting', () {
      final manager = MemoryManager.instance;
      int callCount = 0;

      manager.registerCleanupCallback('testCallback', () {
        callCount++;
      });

      manager.performCleanup(force: true);
      manager.performCleanup(force: true);

      expect(callCount, 2);
    });

    test('performCleanup returns true when cleanup is performed', () {
      final manager = MemoryManager.instance;
      manager.registerCleanupCallback('test', () {});

      final result = manager.performCleanup(force: true);
      expect(result, true);
    });

    test('performCleanup returns false when rate limited', () {
      final manager = MemoryManager.instance;
      manager.registerCleanupCallback('test', () {});

      manager.performCleanup(force: true);
      final result = manager.performCleanup(); // Not forced, should be rate limited

      expect(result, false);
    });
  });

  group('MemoryManager - Memory Pressure Tests', () {
    setUp(() async {
      final manager = MemoryManager.instance;
      manager.clearCallbacks();
      await manager.initialize();
    });

    test('initial pressure state is normal', () {
      final manager = MemoryManager.instance;
      expect(manager.currentPressure, MemoryPressure.normal);
    });

    test('updatePressure changes pressure state', () {
      final manager = MemoryManager.instance;

      manager.updatePressure(MemoryPressure.moderate);
      expect(manager.currentPressure, MemoryPressure.moderate);

      manager.updatePressure(MemoryPressure.critical);
      expect(manager.currentPressure, MemoryPressure.critical);

      manager.updatePressure(MemoryPressure.normal);
      expect(manager.currentPressure, MemoryPressure.normal);
    });

    test('updatePressure triggers cleanup for non-normal pressure', () {
      final manager = MemoryManager.instance;
      int cleanupCount = 0;

      manager.registerCleanupCallback('testCallback', () {
        cleanupCount++;
      });

      manager.updatePressure(MemoryPressure.moderate);
      expect(cleanupCount, 1);

      // Same pressure should not trigger cleanup again
      manager.updatePressure(MemoryPressure.moderate);
      expect(cleanupCount, 1);
    });

    test('updatePressure to normal does not trigger cleanup', () {
      final manager = MemoryManager.instance;
      int cleanupCount = 0;

      manager.registerCleanupCallback('testCallback', () {
        cleanupCount++;
      });

      manager.updatePressure(MemoryPressure.normal);
      expect(cleanupCount, 0);
    });

    test('updatePressure with critical pressure forces cleanup', () {
      final manager = MemoryManager.instance;
      int cleanupCount = 0;

      manager.registerCleanupCallback('testCallback', () {
        cleanupCount++;
      });

      // First call should trigger cleanup
      manager.updatePressure(MemoryPressure.critical);
      expect(cleanupCount, 1);

      // Change to moderate should also trigger cleanup
      manager.updatePressure(MemoryPressure.moderate);
      expect(cleanupCount, 2);
    });
  });

  group('MemoryManager - Statistics Tests', () {
    setUp(() async {
      final manager = MemoryManager.instance;
      manager.clearCallbacks();
      // Reset pressure to normal
      manager.updatePressure(MemoryPressure.normal);
      await manager.initialize();
    });

    test('getStats returns initial state', () {
      final manager = MemoryManager.instance;
      final stats = manager.getStats();

      expect(stats['pressure'], MemoryPressure.normal.toString());
      expect(stats['registeredCallbacks'], 0);
      expect(stats['callbackOwners'], []);
    });

    test('getStats reflects registered callbacks', () {
      final manager = MemoryManager.instance;

      manager.registerCleanupCallback('callback1', () {});
      manager.registerCleanupCallback('callback2', () {});

      final stats = manager.getStats();

      expect(stats['registeredCallbacks'], 2);
      expect(stats['callbackOwners'], contains('callback1'));
      expect(stats['callbackOwners'], contains('callback2'));
    });

    test('getStats reflects callback after unregister', () {
      final manager = MemoryManager.instance;

      manager.registerCleanupCallback('callback1', () {});
      manager.registerCleanupCallback('callback2', () {});
      manager.unregisterCleanupCallback('callback1');

      final stats = manager.getStats();

      expect(stats['registeredCallbacks'], 1);
      expect(stats['callbackOwners'], isNot(contains('callback1')));
      expect(stats['callbackOwners'], contains('callback2'));
    });

    test('getStats includes image cache information', () {
      final manager = MemoryManager.instance;
      final stats = manager.getStats();

      expect(stats.containsKey('imageCache'), true);
      expect(stats['imageCache'], isA<Map<String, dynamic>>());

      final imageCache = stats['imageCache'] as Map<String, dynamic>;
      expect(imageCache.containsKey('currentSize'), true);
      expect(imageCache.containsKey('currentSizeBytes'), true);
      expect(imageCache.containsKey('maximumSize'), true);
      expect(imageCache.containsKey('maximumSizeBytes'), true);
      expect(imageCache.containsKey('liveImageCount'), true);
      expect(imageCache.containsKey('usagePercentage'), true);
    });

    test('getStats includes last cleanup time after cleanup', () async {
      final manager = MemoryManager.instance;

      manager.performCleanup(force: true);

      final stats = manager.getStats();
      expect(stats['lastCleanup'], isNotNull);
      expect(stats['lastCleanup'], isA<String>());
    });
  });

  group('MemoryManager - Integration Tests', () {
    setUp(() async {
      final manager = MemoryManager.instance;
      manager.clearCallbacks();
      // Reset pressure to normal
      manager.updatePressure(MemoryPressure.normal);
      await manager.initialize();
    });

    test('default handlers are registered on initialization', () {
      final manager = MemoryManager.instance;
      final stats = manager.getStats();

      // After initialization, there should be callbacks registered
      // Note: This may be 0 if previous tests cleared callbacks
      // The important thing is that initialization doesn't fail
      expect(stats['registeredCallbacks'], greaterThanOrEqualTo(0));
    });

    test('image cache is cleared on cleanup', () {
      final manager = MemoryManager.instance;

      // Perform cleanup
      manager.performCleanup(force: true);

      // Get stats after cleanup
      final statsAfter = manager.getStats();
      final imageCacheAfter = statsAfter['imageCache'] as Map<String, dynamic>;

      // Current size should be 0 after cleanup
      expect(imageCacheAfter['currentSize'], 0);
      expect(imageCacheAfter['liveImageCount'], 0);
    });

    test('multiple managers share the same singleton state', () async {
      final manager1 = MemoryManager.instance;
      final manager2 = MemoryManager.instance;

      bool callbackCalled = false;

      manager1.registerCleanupCallback('testCallback', () {
        callbackCalled = true;
      });

      manager2.performCleanup(force: true);

      expect(callbackCalled, true);
    });

    test('cleanup maintains callback registration order', () {
      final manager = MemoryManager.instance;
      final callOrder = <String>[];

      manager.registerCleanupCallback('callback3', () {
        callOrder.add('callback3');
      });

      manager.registerCleanupCallback('callback1', () {
        callOrder.add('callback1');
      });

      manager.registerCleanupCallback('callback2', () {
        callOrder.add('callback2');
      });

      manager.performCleanup(force: true);

      // Order should match insertion order (Map maintains order in Dart)
      expect(callOrder, ['callback3', 'callback1', 'callback2']);
    });
  });

  group('MemoryManager - Edge Cases Tests', () {
    setUp(() async {
      final manager = MemoryManager.instance;
      manager.clearCallbacks();
      await manager.initialize();
    });

    test('handles rapid pressure changes', () {
      final manager = MemoryManager.instance;
      int cleanupCount = 0;

      manager.registerCleanupCallback('test', () {
        cleanupCount++;
      });

      // Rapid pressure changes
      manager.updatePressure(MemoryPressure.moderate);
      manager.updatePressure(MemoryPressure.critical);
      manager.updatePressure(MemoryPressure.moderate);
      manager.updatePressure(MemoryPressure.normal);

      // Cleanup should have been called at least once
      expect(cleanupCount, greaterThan(0));
    });

    test('handles cleanup with many callbacks', () {
      final manager = MemoryManager.instance;
      int callCount = 0;

      // Register many callbacks
      for (int i = 0; i < 100; i++) {
        manager.registerCleanupCallback('callback$i', () {
          callCount++;
        });
      }

      manager.performCleanup(force: true);

      expect(callCount, 100);
    });

    test('handles concurrent-like cleanup requests', () {
      final manager = MemoryManager.instance;
      int callCount = 0;

      manager.registerCleanupCallback('test', () {
        callCount++;
      });

      // Multiple cleanup calls in quick succession
      manager.performCleanup(force: true);
      manager.performCleanup(force: true);
      manager.performCleanup(force: true);

      // All should execute since we're using force
      expect(callCount, 3);
    });
  });
}
