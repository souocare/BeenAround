import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/config/server_config.dart';
import '../../core/config/server_config_repository.dart';
import '../../features/server_setup/application/server_setup_cubit.dart';
import '../../features/server_setup/application/server_setup_state.dart';
import '../../features/server_setup/presentation/pages/server_setup_page.dart';
import '../../core/network/api_client.dart';
import '../../features/auth/application/first_run_setup_cubit.dart';
import '../../features/auth/data/first_run_setup_repository.dart';
import '../../features/auth/presentation/pages/first_run_setup_page.dart';
import 'app_bootstrap_cubit.dart';
import 'app_bootstrap_state.dart';

class AppBootstrapPage extends StatelessWidget {
  const AppBootstrapPage({
    required this.repository,
    required this.probeFactory,
    required this.isWeb,
    super.key,
  });

  final ServerConfigRepository repository;
  final ServerProbeFactory probeFactory;
  final bool isWeb;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppBootstrapCubit, AppBootstrapState>(
      builder: (context, state) {
        switch (state.phase) {
          case AppBootstrapPhase.initial:
          case AppBootstrapPhase.loading:
          case AppBootstrapPhase.checking:
            return const _BootstrapLoadingPage();

          case AppBootstrapPhase.serverSetup:
            if (isWeb) {
              return const _BootstrapErrorPage(
                title: 'Server configuration unavailable',
                message: 'Unable to determine the BeenAround server.',
              );
            }

            return BlocProvider(
              create: (_) => ServerSetupCubit(
                repository: repository,
                probeFactory: probeFactory,
              ),
              child: BlocListener<ServerSetupCubit, ServerSetupState>(
                listenWhen: (previous, current) =>
                    previous.phase != current.phase &&
                    current.phase == ServerSetupPhase.connected,
                listener: (context, state) {
                  context.read<AppBootstrapCubit>().serverConnected();
                },
                child: const ServerSetupPage(),
              ),
            );

          case AppBootstrapPhase.firstRunSetup:
            final serverConfig = state.serverConfig!;

            return BlocProvider(
              create: (_) => FirstRunSetupCubit(
                repository: ApiFirstRunSetupRepository(
                  apiClient: ApiClient(serverConfig: serverConfig),
                ),
              ),
              child: FirstRunSetupPage(
                onCompleted: () {
                  context.read<AppBootstrapCubit>().administratorCreated();
                },
              ),
            );

          case AppBootstrapPhase.login:
            return _BootstrapDestinationPage(
              title: 'Welcome back',
              message: 'Sign in to continue your travel story.',
              serverConfig: state.serverConfig,
            );

          case AppBootstrapPhase.unavailable:
            return _BootstrapErrorPage(
              title: 'Server unavailable',
              message:
                  'Unable to connect to your BeenAround server. '
                  'Your saved server configuration has been preserved.',
              onRetry: () => context.read<AppBootstrapCubit>().retry(),
              onChangeServer: isWeb
                  ? null
                  : () => context
                        .read<AppBootstrapCubit>()
                        .configureDifferentServer(),
            );

          case AppBootstrapPhase.incompatible:
            return _BootstrapErrorPage(
              title: 'Incompatible server',
              message:
                  'The configured address does not appear to host '
                  'a compatible BeenAround server.',
              onRetry: () => context.read<AppBootstrapCubit>().retry(),
              onChangeServer: isWeb
                  ? null
                  : () => context
                        .read<AppBootstrapCubit>()
                        .configureDifferentServer(),
            );
        }
      },
    );
  }
}

class _BootstrapLoadingPage extends StatelessWidget {
  const _BootstrapLoadingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF111217),
      body: Center(child: CircularProgressIndicator(color: Color(0xFFE63E00))),
    );
  }
}

class _BootstrapDestinationPage extends StatelessWidget {
  const _BootstrapDestinationPage({
    required this.title,
    required this.message,
    required this.serverConfig,
  });

  final String title;
  final String message;
  final ServerConfig? serverConfig;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111217),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.explore_outlined,
                  size: 72,
                  color: Color(0xFFE63E00),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFD3AAA2)),
                ),
                if (serverConfig != null) ...[
                  const SizedBox(height: 24),
                  Text(
                    serverConfig!.baseUrl.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF88888F),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BootstrapErrorPage extends StatelessWidget {
  const _BootstrapErrorPage({
    required this.title,
    required this.message,
    this.onRetry,
    this.onChangeServer,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onChangeServer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111217),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    size: 64,
                    color: Color(0xFFE63E00),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFD3AAA2),
                      height: 1.5,
                    ),
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: onRetry,
                        child: const Text('Try Again'),
                      ),
                    ),
                  ],
                  if (onChangeServer != null) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: onChangeServer,
                      child: const Text('Change Server'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
