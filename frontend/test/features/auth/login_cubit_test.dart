import 'package:beenaround/features/auth/application/login_cubit.dart';
import 'package:beenaround/features/auth/application/login_state.dart';
import 'package:beenaround/features/auth/data/login_repository.dart';
import 'package:beenaround/features/auth/domain/authenticated_user.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeLoginRepository implements LoginRepository {
  String? receivedLogin;
  String? receivedPassword;
  LoginFailure? failure;
  int callCount = 0;

  @override
  Future<LoginResult> login({
    required String login,
    required String password,
  }) async {
    callCount++;
    receivedLogin = login;
    receivedPassword = password;

    if (failure != null) {
      throw LoginException(failure!);
    }

    return const LoginResult(
      user: AuthenticatedUser(
        id: 'user-1',
        username: 'goncalo',
        displayName: 'Gonçalo',
        isAdmin: true,
      ),
    );
  }
}

void main() {
  late FakeLoginRepository repository;
  late LoginCubit cubit;

  setUp(() {
    repository = FakeLoginRepository();
    cubit = LoginCubit(repository: repository);
  });

  tearDown(() async {
    await cubit.close();
  });

  test('logs in with normalized login', () async {
    await cubit.submit(login: '  goncalo  ', password: 'test-password');

    expect(cubit.state.phase, LoginPhase.success);
    expect(repository.receivedLogin, 'goncalo');
    expect(repository.receivedPassword, 'test-password');
  });

  test('rejects empty login', () async {
    await cubit.submit(login: '', password: 'test-password');

    expect(cubit.state.phase, LoginPhase.failure);
    expect(repository.callCount, 0);
  });

  test('rejects empty password', () async {
    await cubit.submit(login: 'goncalo', password: '');

    expect(cubit.state.phase, LoginPhase.failure);
    expect(repository.callCount, 0);
  });

  test('handles invalid credentials', () async {
    repository.failure = LoginFailure.invalidCredentials;

    await cubit.submit(login: 'goncalo', password: 'wrong-password');

    expect(cubit.state.phase, LoginPhase.failure);
    expect(cubit.state.failure, LoginFailure.invalidCredentials);
  });

  test('handles unavailable server', () async {
    repository.failure = LoginFailure.unavailable;

    await cubit.submit(login: 'goncalo', password: 'test-password');

    expect(cubit.state.phase, LoginPhase.failure);
    expect(cubit.state.failure, LoginFailure.unavailable);
  });

  test('prevents repeated login after success', () async {
    await cubit.submit(login: 'goncalo', password: 'test-password');

    await cubit.submit(login: 'goncalo', password: 'test-password');

    expect(repository.callCount, 1);
  });
}
