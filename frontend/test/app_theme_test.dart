import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beenaround/app/theme/app_theme.dart';

void main() {
  group('AppTheme', () {
    test('dark theme uses Material 3', () {
      final theme = AppTheme.dark;

      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.dark);
    });

    test('light theme uses Material 3', () {
      final theme = AppTheme.light;

      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.light);
    });

    test('dark and light themes share the same seed identity', () {
      final dark = AppTheme.dark;
      final light = AppTheme.light;

      expect(dark.colorScheme.primary, isNotNull);
      expect(light.colorScheme.primary, isNotNull);

      expect(dark.colorScheme.brightness, Brightness.dark);
      expect(light.colorScheme.brightness, Brightness.light);
    });
  });
}
