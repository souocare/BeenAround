import 'package:beenaround/app/widgets/app_loading_state.dart';
import 'package:beenaround/features/auth/presentation/authentication_gateway.dart';
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

          case AppBootstrapPhase.authentication:
            final serverConfig = state.serverConfig!;

            return AuthenticationGateway(
              key: ValueKey(serverConfig.baseUrl.toString()),
              serverConfig: serverConfig,
              isWeb: isWeb,
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
    return const Scaffold(body: AppLoadingState());
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.explore_outlined,
                  size: 72,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (serverConfig != null) ...[
                  const SizedBox(height: 24),
                  Text(
                    serverConfig!.baseUrl.toString(),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off_outlined,
                    size: 64,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
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
