import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/local_server_config_repository.dart';
import '../core/config/server_config.dart';
import '../core/network/api_client.dart';
import '../core/network/server_probe.dart';
import 'bootstrap/app_bootstrap_cubit.dart';
import 'bootstrap/app_bootstrap_page.dart';
import 'theme/app_theme.dart';
import 'theme/theme_cubit.dart';
import 'theme/theme_preference_repository.dart';

class BeenAroundApp extends StatefulWidget {
  const BeenAroundApp({super.key});

  @override
  State<BeenAroundApp> createState() => _BeenAroundAppState();
}

class _BeenAroundAppState extends State<BeenAroundApp> {
  late final LocalServerConfigRepository _repository;
  late final AppBootstrapCubit _bootstrapCubit;
  late final ThemeCubit _themeCubit;

  @override
  void initState() {
    super.initState();

    final preferences = SharedPreferencesAsync();

    _repository = LocalServerConfigRepository(preferences: preferences);

    _themeCubit = ThemeCubit(
      repository: ThemePreferenceRepository(preferences: preferences),
    )..initialize();

    _bootstrapCubit = AppBootstrapCubit(
      repository: _repository,
      probeFactory: (config) =>
          ServerProbe(apiClient: ApiClient(serverConfig: config)),
      isWeb: kIsWeb,
      webServerConfig: ServerConfig.forWeb(),
    )..initialize();
  }

  @override
  void dispose() {
    _themeCubit.close();
    _bootstrapCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _themeCubit,
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) {
          return MaterialApp(
            title: 'BeenAround',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeMode,
            home: BlocProvider.value(
              value: _bootstrapCubit,
              child: AppBootstrapPage(
                repository: _repository,
                probeFactory: (config) =>
                    ServerProbe(apiClient: ApiClient(serverConfig: config)),
                isWeb: kIsWeb,
              ),
            ),
          );
        },
      ),
    );
  }
}
