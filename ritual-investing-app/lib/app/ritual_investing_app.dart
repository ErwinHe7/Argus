import 'package:flutter/material.dart';

import '../features/shell/presentation/app_shell.dart';
import 'theme/app_theme.dart';

class RitualInvestingApp extends StatefulWidget {
  const RitualInvestingApp({super.key});

  @override
  State<RitualInvestingApp> createState() => _RitualInvestingAppState();
}

class _RitualInvestingAppState extends State<RitualInvestingApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _toggleTheme(Brightness currentBrightness) {
    setState(() {
      _themeMode = currentBrightness == Brightness.dark
          ? ThemeMode.light
          : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ritual Investing',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode,
      home: AppShell(onToggleTheme: _toggleTheme),
    );
  }
}
