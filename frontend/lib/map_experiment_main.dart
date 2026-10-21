import 'package:flutter/material.dart';

import 'app/theme/app_theme.dart';
import 'features/map/presentation/pages/map_experiment_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MapExperimentApp());
}

class MapExperimentApp extends StatelessWidget {
  const MapExperimentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BeenAround — Map Experiment',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: const MapExperimentPage(),
    );
  }
}
