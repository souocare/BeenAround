import 'dart:async';

import 'package:beenaround/app/widgets/app_error_state.dart';
import 'package:beenaround/app/widgets/app_loading_state.dart';
import 'package:beenaround/features/auth/domain/authenticated_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/config/server_config.dart';
import '../../../core/network/api_client.dart';
import '../application/auth_cubit.dart';
import '../application/auth_state.dart';
import '../application/login_cubit.dart';
import '../data/login_repository.dart';
import '../data/secure_token_storage.dart';
import '../data/session_repository.dart';
import 'pages/login_page.dart';
import '../../../app/shell/authenticated_app_shell.dart';
import '../../explore/application/explore_cubit.dart';
import '../../explore/data/countries_repository.dart';
import '../../geography/data/city_repository_factory.dart';
import '../../geography/data/city_repository_handle.dart';
import '../../geography/domain/city_repository.dart';
import '../../geography/data/city_repository_factory.dart';
import '../../geography/data/lazy_city_repository.dart';
import '../../geography/domain/city_repository.dart';
import '../../geography/data/remote/api_city_visits_repository.dart';
import '../../geography/domain/city_visits_repository.dart';
import '../../residences/domain/residence_repository.dart';
import '../../residences/data/remote/api_residence_repository.dart';
import '../../wishlist/domain/wishlist_repository.dart';
import '../../wishlist/data/remote/api_wishlist_repository.dart';
import '../../trips/domain/trip_repository.dart';
import '../../trips/data/remote/api_trip_repository.dart';
import '../../trips/domain/trip_association_repository.dart';
import '../../trips/data/remote/api_trip_association_repository.dart';

class AuthenticationDependencies {
  const AuthenticationDependencies({
    required this.loginRepository,
    required this.sessionRepository,
    required this.tokenStorage,
  });

  final LoginRepository loginRepository;
  final SessionRepository sessionRepository;
  final SecureTokenStorage? tokenStorage;
}

typedef AuthenticationDependenciesFactory =
    AuthenticationDependencies Function(
      ApiClient apiClient,
      ServerConfig serverConfig,
      bool isWeb,
    );

class AuthenticationGateway extends StatefulWidget {
  const AuthenticationGateway({
    required this.serverConfig,
    required this.isWeb,
    this.dependenciesFactory,
    super.key,
  });

  final ServerConfig serverConfig;
  final bool isWeb;
  final AuthenticationDependenciesFactory? dependenciesFactory;

  @override
  State<AuthenticationGateway> createState() => _AuthenticationGatewayState();
}

class _AuthenticationGatewayState extends State<AuthenticationGateway> {
  late final ApiClient _apiClient;
  late final AuthCubit _authCubit;
  late final AuthenticationDependencies _dependencies;
  late final LoginCubit _loginCubit;

  @override
  void initState() {
    super.initState();

    _apiClient = ApiClient(serverConfig: widget.serverConfig);

    _dependencies =
        widget.dependenciesFactory?.call(
          _apiClient,
          widget.serverConfig,
          widget.isWeb,
        ) ??
        AuthenticationDependencies(
          loginRepository: ApiLoginRepository(
            apiClient: _apiClient,
            isWeb: widget.isWeb,
          ),
          sessionRepository: ApiSessionRepository(
            apiClient: _apiClient,
            isWeb: widget.isWeb,
          ),
          tokenStorage: widget.isWeb
              ? null
              : FlutterSecureTokenStorage(
                  serverOrigin: widget.serverConfig.baseUrl,
                ),
        );

    _authCubit = AuthCubit(
      sessionRepository: _dependencies.sessionRepository,
      tokenStorage: _dependencies.tokenStorage,
      isWeb: widget.isWeb,
    );

    _loginCubit = LoginCubit(repository: _dependencies.loginRepository);

    _apiClient.configureAuthentication(
      authCubit: _authCubit,
      isWeb: widget.isWeb,
    );

    _authCubit.restoreSession();
  }

  @override
  void dispose() {
    _loginCubit.close();
    _authCubit.close();
    _apiClient.dio.close(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _authCubit,
      child: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) {
          switch (state.phase) {
            case AuthPhase.initial:
            case AuthPhase.restoring:
              return const _AuthenticationLoadingPage();

            case AuthPhase.unauthenticated:
              return BlocProvider.value(
                value: _loginCubit,
                child: LoginPage(onAuthenticated: _acceptLogin),
              );

            case AuthPhase.authenticated:
              final user = state.user;

              if (user == null) {
                return const _AuthenticationLoadingPage();
              }

              return _AuthenticatedSession(
                key: ValueKey(user.id),
                apiClient: _apiClient,
                user: user,
                onLogout: _authCubit.logout,
              );

            case AuthPhase.unavailable:
              return _AuthenticationUnavailablePage(
                onRetry: _authCubit.restoreSession,
              );
          }
        },
      ),
    );
  }

  Future<void> _acceptLogin(LoginResult result) async {
    try {
      await _authCubit.acceptLogin(result);
    } catch (_) {
      if (!mounted) return;

      _loginCubit.sessionPersistenceFailed();
    }
  }
}

class _AuthenticationLoadingPage extends StatelessWidget {
  const _AuthenticationLoadingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: AppLoadingState());
  }
}

class _AuthenticationUnavailablePage extends StatelessWidget {
  const _AuthenticationUnavailablePage({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppErrorState(
        title: 'Unable to restore your session.',
        message: 'Please try again to reconnect to your BeenAround server.',
        icon: Icons.cloud_off_outlined,
        onRetry: onRetry,
      ),
    );
  }
}

class _AuthenticatedSession extends StatefulWidget {
  const _AuthenticatedSession({
    required this.apiClient,
    required this.user,
    required this.onLogout,
    super.key,
  });

  final ApiClient apiClient;
  final AuthenticatedUser user;
  final Future<void> Function() onLogout;

  @override
  State<_AuthenticatedSession> createState() => _AuthenticatedSessionState();
}

class _AuthenticatedSessionState extends State<_AuthenticatedSession> {
  late final LazyCityRepository _cityRepository;

  @override
  void initState() {
    super.initState();

    _cityRepository = LazyCityRepository(
      createHandle: () => createCityRepository(apiClient: widget.apiClient),
    );
  }

  @override
  void dispose() {
    unawaited(_cityRepository.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<CityRepository>.value(value: _cityRepository),
        RepositoryProvider<CityVisitsRepository>(
          create: (_) => ApiCityVisitsRepository(apiClient: widget.apiClient),
        ),
        RepositoryProvider<CountriesRepository>(
          create: (_) => ApiCountriesRepository(apiClient: widget.apiClient),
        ),
        RepositoryProvider<ResidenceRepository>(
          create: (_) => ApiResidenceRepository(apiClient: widget.apiClient),
        ),
        RepositoryProvider<WishlistRepository>(
          create: (_) => ApiWishlistRepository(apiClient: widget.apiClient),
        ),
        RepositoryProvider<TripRepository>(
          create: (_) => ApiTripRepository(apiClient: widget.apiClient),
        ),
        RepositoryProvider<TripRepository>(
          create: (_) => ApiTripRepository(apiClient: widget.apiClient),
        ),

        RepositoryProvider<TripAssociationRepository>(
          create: (_) =>
              ApiTripAssociationRepository(apiClient: widget.apiClient),
        ),
      ],
      child: BlocProvider<ExploreCubit>(
        create: (context) =>
            ExploreCubit(repository: context.read<CountriesRepository>())
              ..load(),
        child: AuthenticatedAppShell(
          user: widget.user,
          onLogout: widget.onLogout,
        ),
      ),
    );
  }
}
