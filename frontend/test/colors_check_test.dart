import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('check M3 colors', () {
    final dark = ThemeData.dark(useMaterial3: true);
    print('dark onSurfaceVariant: ${dark.colorScheme.onSurfaceVariant}');
    print('dark primary: ${dark.colorScheme.primary}');
    print('dark surface: ${dark.colorScheme.surface}');
    final light = ThemeData.light(useMaterial3: true);
    print('light onSurfaceVariant: ${light.colorScheme.onSurfaceVariant}');
    print('light primary: ${light.colorScheme.primary}');
  });
}
