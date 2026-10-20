import 'package:beenaround/app/theme/app_colors.dart';
import 'package:beenaround/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTheme', () {
    test('dark theme uses BeenAround brand colors', () {
      final theme = AppTheme.dark;

      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, AppColors.primary);
      expect(theme.colorScheme.secondary, AppColors.secondary);
      expect(theme.colorScheme.tertiary, AppColors.tertiary);

      expect(theme.scaffoldBackgroundColor, AppColors.darkBackground);
    });

    test('light theme uses accessible brand variants', () {
      final theme = AppTheme.light;

      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, AppColors.lightPrimary);
      expect(theme.colorScheme.secondary, AppColors.lightSecondary);
      expect(theme.colorScheme.tertiary, AppColors.lightTertiary);

      expect(theme.scaffoldBackgroundColor, AppColors.lightBackground);
    });

    test('both themes use Material 3', () {
      expect(AppTheme.dark.useMaterial3, isTrue);
      expect(AppTheme.light.useMaterial3, isTrue);
    });

    test('dark theme provides consistent surface colors', () {
      final scheme = AppTheme.dark.colorScheme;

      expect(scheme.surface, AppColors.darkSurface);
      expect(scheme.surfaceContainerHigh, AppColors.darkSurfaceElevated);
    });

    test('light theme provides consistent surface colors', () {
      final scheme = AppTheme.light.colorScheme;

      expect(scheme.surface, AppColors.lightSurface);
      expect(scheme.surfaceContainerHigh, AppColors.lightSurfaceElevated);
    });
  });
}
