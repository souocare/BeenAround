import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/login_repository.dart';
import 'login_state.dart';

class LoginCubit extends Cubit<LoginState> {
  LoginCubit({required this._repository}) : super(const LoginState());

  final LoginRepository _repository;

  Future<void> submit({required String login, required String password}) async {
    if (state.isSubmitting || state.phase == LoginPhase.success) {
      return;
    }

    final normalizedLogin = login.trim();

    if (normalizedLogin.isEmpty ||
        normalizedLogin.length > 320 ||
        password.isEmpty ||
        password.length > 1024) {
      emit(
        const LoginState(
          phase: LoginPhase.failure,
          failure: LoginFailure.invalidCredentials,
        ),
      );
      return;
    }

    emit(const LoginState(phase: LoginPhase.submitting));

    try {
      final result = await _repository.login(
        login: normalizedLogin,
        password: password,
      );

      if (isClosed) return;

      emit(LoginState(phase: LoginPhase.success, result: result));
    } on LoginException catch (error) {
      if (isClosed) return;

      emit(LoginState(phase: LoginPhase.failure, failure: error.failure));
    } catch (_) {
      if (isClosed) return;

      emit(
        const LoginState(
          phase: LoginPhase.failure,
          failure: LoginFailure.unexpected,
        ),
      );
    }
  }

  void sessionPersistenceFailed() {
    if (isClosed || state.phase != LoginPhase.success) return;

    emit(
      const LoginState(
        phase: LoginPhase.failure,
        failure: LoginFailure.unexpected,
      ),
    );
  }
}
