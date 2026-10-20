import 'package:beenaround/features/auth/application/first_run_setup_cubit.dart';
import 'package:beenaround/features/auth/application/first_run_setup_state.dart';
import 'package:beenaround/features/auth/data/first_run_setup_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeFirstRunSetupRepository implements FirstRunSetupRepository {
  FirstRunSetupRequest? lastRequest;
  FirstRunSetupFailure? failure;

  @override
  Future<void> createAdministrator(FirstRunSetupRequest request) async {
    lastRequest = request;

    if (failure != null) {
      throw FirstRunSetupException(failure!);
    }
  }
}

void main() {
  late FakeFirstRunSetupRepository repository;
  late FirstRunSetupCubit cubit;

  setUp(() {
    repository = FakeFirstRunSetupRepository();
    cubit = FirstRunSetupCubit(repository: repository);
  });

  tearDown(() async {
    await cubit.close();
  });

  Future<void> submitValidForm() {
    return cubit.submit(
      displayName: 'Gonçalo',
      username: 'goncalo',
      email: '',
      password: 'a-strong-password',
      confirmPassword: 'a-strong-password',
    );
  }

  test('creates administrator with normalized values', () async {
    await cubit.submit(
      displayName: '  Gonçalo  ',
      username: '  Goncalo  ',
      email: '',
      password: 'a-strong-password',
      confirmPassword: 'a-strong-password',
    );

    expect(cubit.state.phase, FirstRunSetupPhase.success);
    expect(repository.lastRequest?.displayName, 'Gonçalo');
    expect(repository.lastRequest?.username, 'goncalo');
    expect(repository.lastRequest?.email, isNull);
  });

  test('rejects mismatched passwords', () async {
    await cubit.submit(
      displayName: 'Gonçalo',
      username: 'goncalo',
      email: '',
      password: 'a-strong-password',
      confirmPassword: 'different-password',
    );

    expect(cubit.state.phase, FirstRunSetupPhase.failure);
    expect(cubit.state.failure, FirstRunSetupFailure.validation);
    expect(repository.lastRequest, isNull);
  });

  test('handles already completed setup', () async {
    repository.failure = FirstRunSetupFailure.alreadyCompleted;

    await submitValidForm();

    expect(cubit.state.phase, FirstRunSetupPhase.failure);
    expect(cubit.state.failure, FirstRunSetupFailure.alreadyCompleted);
  });

  test('handles unavailable server', () async {
    repository.failure = FirstRunSetupFailure.unavailable;

    await submitValidForm();

    expect(cubit.state.phase, FirstRunSetupPhase.failure);
    expect(cubit.state.failure, FirstRunSetupFailure.unavailable);
  });

  test('does not submit again after success', () async {
    await submitValidForm();

    final previousRequest = repository.lastRequest;

    await submitValidForm();

    expect(repository.lastRequest, same(previousRequest));
  });
}
