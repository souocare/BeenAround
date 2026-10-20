import 'package:beenaround/app/theme/theme_preference_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferencesAsync preferences;
  late ThemePreferenceRepository repository;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();

    preferences = SharedPreferencesAsync();

    repository = ThemePreferenceRepository(preferences: preferences);
  });

  group('ThemePreferenceRepository', () {
    test('defaults to Dark Mode', () async {
      expect(await repository.load(), ThemeMode.dark);
    });

    test('saves and restores Light Mode', () async {
      await repository.save(ThemeMode.light);

      expect(await repository.load(), ThemeMode.light);
    });

    test('saves and restores System Mode', () async {
      await repository.save(ThemeMode.system);

      expect(await repository.load(), ThemeMode.system);
    });

    test('saves and restores Dark Mode', () async {
      await repository.save(ThemeMode.dark);

      expect(await repository.load(), ThemeMode.dark);
    });

    test('overwrites the previous preference', () async {
      await repository.save(ThemeMode.light);
      await repository.save(ThemeMode.system);

      expect(await repository.load(), ThemeMode.system);
    });

    test('persists across repository instances', () async {
      await repository.save(ThemeMode.light);

      final anotherRepository = ThemePreferenceRepository(
        preferences: SharedPreferencesAsync(),
      );

      expect(await anotherRepository.load(), ThemeMode.light);
    });

    test('falls back to Dark Mode for unknown values', () async {
      await preferences.setString('appearance.theme_mode', 'unknown');

      expect(await repository.load(), ThemeMode.dark);
    });
  });
}
