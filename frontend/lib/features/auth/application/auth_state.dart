import '../domain/authenticated_user.dart';

enum AuthPhase {
  initial,
  restoring,
  authenticated,
  unauthenticated,
  unavailable,
}

class AuthState {
  const AuthState({this.phase = AuthPhase.initial, this.user});

  final AuthPhase phase;
  final AuthenticatedUser? user;

  bool get isAuthenticated => phase == AuthPhase.authenticated;
}
