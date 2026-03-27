import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_ai_assistant/core/performance/performance_monitor.dart';

void main() {
  group('PerformanceMonitor', () {
    late PerformanceMonitor monitor;

    setUp(() {
      // Reset the singleton state before each test
      monitor = PerformanceMonitor.instance;
      monitor.clearStats();
      monitor.setEnabled(true);
    });

    tearDown(() {
      monitor.clearStats();
    });

    group('trackWidgetBuild', () {
      test('records widget build statistics', () {
        const widgetName = 'TestWidget';
        const buildTime = Duration(milliseconds: 10);

        monitor.trackWidgetBuild(widgetName, buildTime);

        final stats = monitor.getWidgetStats(widgetName);
        expect(stats, isNotNull);
        expect(stats?.totalBuilds, equals(1));
        expect(stats?.averageBuildTime, equals(buildTime));
      });

      test('logs warning for slow builds (>16ms)', () {
        const widgetName = 'SlowWidget';
        const slowBuildTime = Duration(milliseconds: 20);

        // This should log a warning but not throw
        monitor.trackWidgetBuild(widgetName, slowBuildTime);

        final stats = monitor.getWidgetStats(widgetName);
        expect(stats?.slowBuilds, equals(1));
      });

      test('does not log warning for fast builds (<=16ms)', () {
        const widgetName = 'FastWidget';
        const fastBuildTime = Duration(milliseconds: 5);

        monitor.trackWidgetBuild(widgetName, fastBuildTime);

        final stats = monitor.getWidgetStats(widgetName);
        expect(stats?.slowBuilds, equals(0));
      });

      test('accumulates statistics across multiple builds', () {
        const widgetName = 'MultiBuildWidget';

        monitor.trackWidgetBuild(widgetName, const Duration(milliseconds: 10));
        monitor.trackWidgetBuild(widgetName, const Duration(milliseconds: 20));
        monitor.trackWidgetBuild(widgetName, const Duration(milliseconds: 30));

        final stats = monitor.getWidgetStats(widgetName);
        expect(stats?.totalBuilds, equals(3));
        expect(stats?.averageBuildTime.inMilliseconds, equals(20));
        expect(stats?.maxBuildTime.inMilliseconds, equals(30));
        expect(stats?.slowBuilds, equals(2)); // 20ms and 30ms are slow
      });

      test('returns null for non-existent widget', () {
        final stats = monitor.getWidgetStats('NonExistentWidget');
        expect(stats, isNull);
      });

      test('does not track when disabled', () {
        monitor.setEnabled(false);
        const widgetName = 'DisabledWidget';

        monitor.trackWidgetBuild(widgetName, const Duration(milliseconds: 100));

        final stats = monitor.getWidgetStats(widgetName);
        expect(stats, isNull);
      });
    });

    group('trackProviderRebuild', () {
      test('records provider rebuild statistics', () {
        const providerName = 'testProvider';
        const listenerCount = 5;

        monitor.trackProviderRebuild(providerName, listenerCount);

        final stats = monitor.getProviderStats(providerName);
        expect(stats, isNotNull);
        expect(stats?.totalRebuilds, equals(1));
        expect(stats?.maxListenerCount, equals(listenerCount));
      });

      test('logs warning for high frequency rebuilds (>=10 listeners)', () {
        const providerName = 'highFrequencyProvider';
        const highListenerCount = 15;

        monitor.trackProviderRebuild(providerName, highListenerCount);

        final stats = monitor.getProviderStats(providerName);
        expect(stats?.maxListenerCount, equals(highListenerCount));
      });

      test('accumulates statistics across multiple rebuilds', () {
        const providerName = 'multiRebuildProvider';

        monitor.trackProviderRebuild(providerName, 5);
        monitor.trackProviderRebuild(providerName, 10);
        monitor.trackProviderRebuild(providerName, 15);

        final stats = monitor.getProviderStats(providerName);
        expect(stats?.totalRebuilds, equals(3));
        expect(stats?.maxListenerCount, equals(15));
        expect(stats?.averageListenerCount, equals(10.0));
      });

      test('returns null for non-existent provider', () {
        final stats = monitor.getProviderStats('NonExistentProvider');
        expect(stats, isNull);
      });
    });

    group('getAllWidgetStats', () {
      test('returns all widget statistics', () {
        monitor.trackWidgetBuild('Widget1', const Duration(milliseconds: 10));
        monitor.trackWidgetBuild('Widget2', const Duration(milliseconds: 20));

        final allStats = monitor.getAllWidgetStats();
        expect(allStats.length, equals(2));
        expect(allStats.containsKey('Widget1'), isTrue);
        expect(allStats.containsKey('Widget2'), isTrue);
      });

      test('returns unmodifiable map', () {
        monitor.trackWidgetBuild('Widget1', const Duration(milliseconds: 10));

        final allStats = monitor.getAllWidgetStats();
        expect(() => allStats.clear(), throwsUnsupportedError);
      });
    });

    group('getAllProviderStats', () {
      test('returns all provider statistics', () {
        monitor.trackProviderRebuild('Provider1', 5);
        monitor.trackProviderRebuild('Provider2', 10);

        final allStats = monitor.getAllProviderStats();
        expect(allStats.length, equals(2));
        expect(allStats.containsKey('Provider1'), isTrue);
        expect(allStats.containsKey('Provider2'), isTrue);
      });

      test('returns unmodifiable map', () {
        monitor.trackProviderRebuild('Provider1', 5);

        final allStats = monitor.getAllProviderStats();
        expect(() => allStats.clear(), throwsUnsupportedError);
      });
    });

    group('clearStats', () {
      test('clears all widget and provider statistics', () {
        monitor.trackWidgetBuild('Widget1', const Duration(milliseconds: 10));
        monitor.trackProviderRebuild('Provider1', 5);

        monitor.clearStats();

        expect(monitor.getAllWidgetStats(), isEmpty);
        expect(monitor.getAllProviderStats(), isEmpty);
      });
    });

    group('setEnabled', () {
      test('toggles monitoring state', () {
        monitor.setEnabled(false);
        expect(monitor.isEnabled, isFalse);

        monitor.setEnabled(true);
        expect(monitor.isEnabled, isTrue);
      });

      test('does not track when disabled', () {
        monitor.setEnabled(false);

        monitor.trackWidgetBuild('TestWidget', const Duration(milliseconds: 100));

        expect(monitor.getAllWidgetStats(), isEmpty);
      });
    });

    group('PerformanceMonitorExtension', () {
      test('trackBuild executes function and tracks time', () {
        const widgetName = 'TrackedWidget';
        var executed = false;

        final widget = monitor.trackBuild(widgetName, () {
          executed = true;
          return const Text('Test');
        });

        expect(executed, isTrue);
        expect(widget, isA<Text>());

        final stats = monitor.getWidgetStats(widgetName);
        expect(stats, isNotNull);
        expect(stats?.totalBuilds, equals(1));
      });

      test('trackBuild returns function result without tracking when disabled', () {
        monitor.setEnabled(false);

        final widget = monitor.trackBuild('DisabledWidget', () {
          return const Text('Test');
        });

        expect(widget, isA<Text>());
        expect(monitor.getAllWidgetStats(), isEmpty);
      });
    });
  });

  group('WidgetBuildStats', () {
    test('calculates average build time correctly', () {
      final stats = WidgetBuildStats();

      stats.recordBuild(const Duration(milliseconds: 10));
      stats.recordBuild(const Duration(milliseconds: 20));
      stats.recordBuild(const Duration(milliseconds: 30));

      expect(stats.totalBuilds, equals(3));
      expect(stats.averageBuildTime.inMilliseconds, equals(20));
    });

    test('tracks maximum build time', () {
      final stats = WidgetBuildStats();

      stats.recordBuild(const Duration(milliseconds: 10));
      stats.recordBuild(const Duration(milliseconds: 50));
      stats.recordBuild(const Duration(milliseconds: 20));

      expect(stats.maxBuildTime.inMilliseconds, equals(50));
    });

    test('counts slow builds correctly', () {
      final stats = WidgetBuildStats();

      stats.recordBuild(const Duration(milliseconds: 10));
      stats.recordBuild(const Duration(milliseconds: 20)); // slow
      stats.recordBuild(const Duration(milliseconds: 30)); // slow

      expect(stats.slowBuilds, equals(2));
    });

    test('handles zero builds', () {
      final stats = WidgetBuildStats();

      expect(stats.totalBuilds, equals(0));
      expect(stats.averageBuildTime, equals(Duration.zero));
      expect(stats.maxBuildTime, equals(Duration.zero));
      expect(stats.slowBuilds, equals(0));
    });
  });

  group('ProviderRebuildStats', () {
    test('calculates average listener count correctly', () {
      final stats = ProviderRebuildStats();

      stats.recordRebuild(5);
      stats.recordRebuild(10);
      stats.recordRebuild(15);

      expect(stats.totalRebuilds, equals(3));
      expect(stats.averageListenerCount, equals(10.0));
    });

    test('tracks maximum listener count', () {
      final stats = ProviderRebuildStats();

      stats.recordRebuild(5);
      stats.recordRebuild(20);
      stats.recordRebuild(10);

      expect(stats.maxListenerCount, equals(20));
    });

    test('handles zero rebuilds', () {
      final stats = ProviderRebuildStats();

      expect(stats.totalRebuilds, equals(0));
      expect(stats.averageListenerCount, equals(0.0));
      expect(stats.maxListenerCount, equals(0));
    });
  });
}
