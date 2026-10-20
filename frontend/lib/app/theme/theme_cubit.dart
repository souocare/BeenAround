import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'theme_preference_repository.dart';

class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit({required this._repository}) : super(ThemeMode.dark);

  final ThemePreferenceRepository _repository;

  int _generation = 0;

  Future<void> _pendingSave = Future<void>.value();

  Future<void> initialize() async {
    final generation = ++_generation;

    try {
      final mode = await _repository.load();

      if (isClosed || generation != _generation) {
        return;
      }

      emit(mode);
    } catch (_) {
      // Keep Dark Mode when local preferences cannot be loaded.
    }
  }

  Future<void> setThemeMode(ThemeMode mode) {
    if (isClosed) {
      return Future<void>.value();
    }

    ++_generation;

    emit(mode);

    final save = _pendingSave.then((_) async {
      try {
        await _repository.save(mode);
      } catch (_) {
        // Keep the selected appearance active for this session.
      }
    });

    _pendingSave = save;

    return save;
  }
}
