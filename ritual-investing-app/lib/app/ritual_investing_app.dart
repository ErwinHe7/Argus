// ignore_for_file: prefer_initializing_formals

import 'package:flutter/material.dart';

import '../features/shell/presentation/app_shell.dart';
import 'theme/app_theme.dart';
import '../core/auth/auth_controller.dart';
import '../core/bootstrap/dependency_container.dart';

class RitualInvestingApp extends StatefulWidget {
  const RitualInvestingApp({super.key, required DependencyContainer container})
    : _container = container;
  const RitualInvestingApp.fixture({super.key}) : _container = null;

  final DependencyContainer? _container;

  @override
  State<RitualInvestingApp> createState() => _RitualInvestingAppState();
}

class _RitualInvestingAppState extends State<RitualInvestingApp> {
  ThemeMode _themeMode = ThemeMode.system;
  late final DependencyContainer _container =
      widget._container ?? DependencyContainer.fixture();

  @override
  void initState() {
    super.initState();
    _container.bootstrap();
  }

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
      home: ListenableBuilder(
        listenable: _container.authController,
        builder: (context, _) =>
            switch (_container.authController.state.phase) {
              AuthPhase.signedIn => AppShell(
                onToggleTheme: _toggleTheme,
                dailyRitualController: _container.dailyRitualController,
                discoverController: _container.discoverController,
                covenController: _container.covenController,
                profileController: _container.profileController,
              ),
              AuthPhase.loading => const _AuthGate.loading(),
              AuthPhase.failure => _AuthGate(
                message:
                    _container.authController.state.message ??
                    'Sign-in is temporarily unavailable.',
                actionLabel: 'Retry',
                onAction: _container.bootstrap,
              ),
              AuthPhase.signedOut => _AuthGate(
                message: 'Sign in to continue your private ritual.',
                actionLabel: 'Sign in',
                onAction: _container.login,
              ),
            },
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  }) : loading = false;
  const _AuthGate.loading()
    : message = 'Restoring your session',
      actionLabel = '',
      onAction = null,
      loading = true;
  final String message;
  final String actionLabel;
  final VoidCallback? onAction;
  final bool loading;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading) const CircularProgressIndicator(),
              if (loading) const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              if (onAction != null)
                TextButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ),
        ),
      ),
    ),
  );
}
