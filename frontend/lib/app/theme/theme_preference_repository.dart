import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemePreferenceRepository {
  const ThemePreferenceRepository({required this._preferences});

  static const _key = 'appearance.theme_mode';

  final SharedPreferencesAsync _preferences;

  Future<ThemeMode> load() async {
    final stored = await _preferences.getString(_key);

    return switch (stored) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
  }

  Future<void> save(ThemeMode mode) async {
    final value = switch (mode) {
      ThemeMode.dark => 'dark',
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
    };

    await _preferences.setString(_key, value);
  }
}
