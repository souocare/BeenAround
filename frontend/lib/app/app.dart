import 'package:flutter/material.dart';

import 'theme/app_theme.dart';
import '../features/auth/presentation/pages/auth_placeholder_page.dart';

class BeenAroundApp extends StatelessWidget {
  const BeenAroundApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BeenAround',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: const AuthPlaceholderPage(),
    );
  }
}
