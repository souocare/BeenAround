import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/first_run_setup_repository.dart';
import 'first_run_setup_state.dart';

class FirstRunSetupCubit extends Cubit<FirstRunSetupState> {
  FirstRunSetupCubit({required FirstRunSetupRepository repository})
    : _repository = repository,
      super(const FirstRunSetupState());

  final FirstRunSetupRepository _repository;

  Future<void> submit({
    required String displayName,
    required String username,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    if (state.isSubmitting || state.phase == FirstRunSetupPhase.success) {
      return;
    }

    final normalizedName = displayName.trim();
    final normalizedUsername = username.trim().toLowerCase();
    final normalizedEmail = email.trim();

    final usernamePattern = RegExp(r'^[a-z0-9_]{3,32}$');

    if (normalizedName.isEmpty ||
        normalizedName.length > 100 ||
        !usernamePattern.hasMatch(normalizedUsername) ||
        normalizedEmail.length > 320 ||
        (normalizedEmail.isNotEmpty && !_isValidEmail(normalizedEmail)) ||
        password.length < 12 ||
        password.length > 1024 ||
        password != confirmPassword) {
      emit(
        const FirstRunSetupState(
          phase: FirstRunSetupPhase.failure,
          failure: FirstRunSetupFailure.validation,
        ),
      );
      return;
    }

    emit(const FirstRunSetupState(phase: FirstRunSetupPhase.submitting));

    try {
      await _repository.createAdministrator(
        FirstRunSetupRequest(
          displayName: normalizedName,
          username: normalizedUsername,
          email: normalizedEmail.isEmpty ? null : normalizedEmail,
          password: password,
        ),
      );

      if (isClosed) return;

      emit(const FirstRunSetupState(phase: FirstRunSetupPhase.success));
    } on FirstRunSetupException catch (error) {
      if (isClosed) return;

      emit(
        FirstRunSetupState(
          phase: FirstRunSetupPhase.failure,
          failure: error.failure,
        ),
      );
    } catch (_) {
      if (isClosed) return;

      emit(
        const FirstRunSetupState(
          phase: FirstRunSetupPhase.failure,
          failure: FirstRunSetupFailure.unexpected,
        ),
      );
    }
  }

  bool _isValidEmail(String email) {
    final at = email.lastIndexOf('@');

    if (at <= 0 || at == email.length - 1) return false;

    final domain = email.substring(at + 1);
    final dot = domain.lastIndexOf('.');

    return dot > 0 && dot < domain.length - 1;
  }
}
