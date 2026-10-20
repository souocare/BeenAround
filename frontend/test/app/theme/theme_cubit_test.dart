import 'dart:async';

import 'package:beenaround/app/theme/theme_cubit.dart';
import 'package:beenaround/app/theme/theme_preference_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class FakeThemePreferenceRepository extends ThemePreferenceRepository {
  FakeThemePreferenceRepository()
    : super(preferences: SharedPreferencesAsync());

  ThemeMode storedMode = ThemeMode.dark;

  Completer<ThemeMode>? pendingLoad;

  final List<ThemeMode> savedModes = [];
  final List<Completer<void>> pendingSaves = [];

  bool failLoad = false;
  bool failSave = false;

  @override
  Future<ThemeMode> load() async {
    if (pendingLoad != null) {
      return pendingLoad!.future;
    }

    if (failLoad) {
      throw StateError('Storage unavailable');
    }

    return storedMode;
  }

  @override
  Future<void> save(ThemeMode mode) async {
    savedModes.add(mode);

    if (failSave) {
      throw StateError('Storage unavailable');
    }

    if (pendingSaves.isNotEmpty) {
      await pendingSaves.removeAt(0).future;
    }

    storedMode = mode;
  }
}

void main() {
  late FakeThemePreferenceRepository repository;
  late ThemeCubit cubit;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();

    repository = FakeThemePreferenceRepository();
    cubit = ThemeCubit(repository: repository);
  });

  tearDown(() async {
    await cubit.close();
  });

  test('defaults to Dark Mode', () {
    expect(cubit.state, ThemeMode.dark);
  });

  test('loads a saved Light Mode preference', () async {
    repository.storedMode = ThemeMode.light;

    await cubit.initialize();

    expect(cubit.state, ThemeMode.light);
  });

  test('loads a saved System preference', () async {
    repository.storedMode = ThemeMode.system;

    await cubit.initialize();

    expect(cubit.state, ThemeMode.system);
  });

  test('keeps Dark Mode when loading fails', () async {
    repository.failLoad = true;

    await cubit.initialize();

    expect(cubit.state, ThemeMode.dark);
  });

  test('changes the theme immediately', () async {
    final pendingSave = Completer<void>();
    repository.pendingSaves.add(pendingSave);

    final operation = cubit.setThemeMode(ThemeMode.light);

    expect(cubit.state, ThemeMode.light);

    pendingSave.complete();
    await operation;

    expect(repository.storedMode, ThemeMode.light);
  });

  test('persists rapid changes in selection order', () async {
    final firstSave = Completer<void>();
    final secondSave = Completer<void>();

    repository.pendingSaves.addAll([firstSave, secondSave]);

    final lightOperation = cubit.setThemeMode(ThemeMode.light);
    final darkOperation = cubit.setThemeMode(ThemeMode.dark);

    expect(cubit.state, ThemeMode.dark);

    // Allow the first queued save to begin.
    await Future<void>.delayed(Duration.zero);

    expect(repository.savedModes, [ThemeMode.light]);

    firstSave.complete();
    await lightOperation;

    // The second save must start only after the first finishes.
    expect(repository.savedModes, [ThemeMode.light, ThemeMode.dark]);

    secondSave.complete();
    await darkOperation;

    expect(repository.storedMode, ThemeMode.dark);
  });

  test('a delayed load cannot override a newer selection', () async {
    final pendingLoad = Completer<ThemeMode>();
    repository.pendingLoad = pendingLoad;

    final initialization = cubit.initialize();

    await cubit.setThemeMode(ThemeMode.light);

    pendingLoad.complete(ThemeMode.dark);
    await initialization;

    expect(cubit.state, ThemeMode.light);
  });

  test('keeps selected theme when saving fails', () async {
    repository.failSave = true;

    await cubit.setThemeMode(ThemeMode.light);

    expect(cubit.state, ThemeMode.light);
  });

  test('continues saving after a previous failure', () async {
    repository.failSave = true;

    await cubit.setThemeMode(ThemeMode.light);

    repository.failSave = false;

    await cubit.setThemeMode(ThemeMode.system);

    expect(repository.storedMode, ThemeMode.system);
  });
}
