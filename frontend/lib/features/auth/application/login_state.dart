import '../data/login_repository.dart';

enum LoginPhase { idle, submitting, success, failure }

class LoginState {
  const LoginState({this.phase = LoginPhase.idle, this.result, this.failure});

  final LoginPhase phase;
  final LoginResult? result;
  final LoginFailure? failure;

  bool get isSubmitting => phase == LoginPhase.submitting;
}
