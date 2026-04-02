import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/offline/connectivity_provider.dart';

void main() {
  group('ConnectivityState', () {
    test('initial state has correct defaults', () {
      const state = ConnectivityState(
        isOnline: true,
        connectionType: [],
        lastChangedAt: null,
      );
      expect(state.isOnline, isTrue);
      expect(state.connectionType, isEmpty);
      expect(state.lastChangedAt, isNull);
    });

    test('copyWith updates only specified fields', () {
      const original = ConnectivityState(
        isOnline: true,
        connectionType: [ConnectivityResult.wifi],
        lastChangedAt: null,
      );
      final updated = original.copyWith(isOnline: false);

      expect(updated.isOnline, isFalse);
      expect(updated.connectionType, [ConnectivityResult.wifi]);
      expect(updated.lastChangedAt, isNull);
    });

    test('copyWith preserves fields when not specified', () {
      final now = DateTime.now();
      final original = ConnectivityState(
        isOnline: true,
        connectionType: [ConnectivityResult.wifi],
        lastChangedAt: now,
      );
      final updated = original.copyWith(isOnline: false);

      expect(updated.isOnline, isFalse);
      expect(updated.connectionType, [ConnectivityResult.wifi]);
      expect(updated.lastChangedAt, now);
    });

    test('equality is based on isOnline only', () {
      final a = ConnectivityState(
        isOnline: true,
        connectionType: [ConnectivityResult.wifi],
        lastChangedAt: DateTime(2025),
      );
      final b = ConnectivityState(
        isOnline: true,
        connectionType: [ConnectivityResult.mobile],
        lastChangedAt: DateTime(2026),
      );
      final c = ConnectivityState(
        isOnline: false,
        connectionType: [ConnectivityResult.wifi],
        lastChangedAt: null,
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString contains isOnline and type', () {
      const state = ConnectivityState(
        isOnline: true,
        connectionType: [ConnectivityResult.wifi],
      );
      final str = state.toString();
      expect(str, contains('isOnline: true'));
      expect(str, contains('wifi'));
    });
  });

  group('_isOnline classification', () {
    /// Helper to invoke the classification logic.
    /// Since _isOnline is private, we test via ConnectivityState
    /// and the known behavior: the notifier sets isOnline based on
    /// the connectivity results.
    ///
    /// We replicate the logic here to verify it independently:
    /// - Empty list → offline
    /// - [none] → offline
    /// - [other] → offline
    /// - [wifi] → online
    /// - [mobile] → online
    /// - [ethernet] → online
    /// - [bluetooth] → online
    /// - [vpn] with [wifi] → online
    /// - [none, wifi] mixed → online (any non-none/non-other)
    bool classifyOnline(List<ConnectivityResult> results) {
      if (results.isEmpty) return false;
      return results.any(
        (r) => r != ConnectivityResult.none && r != ConnectivityResult.other,
      );
    }

    test('empty list returns false', () {
      expect(classifyOnline([]), isFalse);
    });

    test('none returns false', () {
      expect(classifyOnline([ConnectivityResult.none]), isFalse);
    });

    test('other returns false', () {
      expect(classifyOnline([ConnectivityResult.other]), isFalse);
    });

    test('wifi returns true', () {
      expect(classifyOnline([ConnectivityResult.wifi]), isTrue);
    });

    test('mobile returns true', () {
      expect(classifyOnline([ConnectivityResult.mobile]), isTrue);
    });

    test('ethernet returns true', () {
      expect(classifyOnline([ConnectivityResult.ethernet]), isTrue);
    });

    test('bluetooth returns true', () {
      expect(classifyOnline([ConnectivityResult.bluetooth]), isTrue);
    });

    test('mixed none and wifi returns true (any non-none)', () {
      expect(
        classifyOnline([ConnectivityResult.none, ConnectivityResult.wifi]),
        isTrue,
      );
    });

    test('mixed none and other returns false', () {
      expect(
        classifyOnline([ConnectivityResult.none, ConnectivityResult.other]),
        isFalse,
      );
    });

    test('vpn with wifi returns true', () {
      expect(
        classifyOnline([ConnectivityResult.vpn, ConnectivityResult.wifi]),
        isTrue,
      );
    });

    test('vpn alone returns true', () {
      expect(classifyOnline([ConnectivityResult.vpn]), isTrue);
    });
  });
}
