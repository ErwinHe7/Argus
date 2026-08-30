import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/bootstrap/dependency_container.dart';
import '../core/bootstrap/member_bootstrap.dart';
import '../core/navigation/app_router.dart';
import '../core/navigation/member_routes.dart';
import 'theme/app_theme.dart';

class RitualInvestingApp extends StatefulWidget {
  const RitualInvestingApp({
    super.key,
    required this.container,
    this.resourceAccess,
    this.bootstrapOnStart = true,
    this.allowSelfServiceSignup = true,
  });

  final DependencyContainer container;
  final MemberResourceAccess? resourceAccess;
  final bool bootstrapOnStart;
  final bool allowSelfServiceSignup;

  @override
  State<RitualInvestingApp> createState() => _RitualInvestingAppState();
}

class _RitualInvestingAppState extends State<RitualInvestingApp> {
  late final GoRouter _router = createAppRouter(
    container: widget.container,
    resourceAccess: widget.resourceAccess,
    allowSelfServiceSignup: widget.allowSelfServiceSignup,
  );

  @override
  void initState() {
    super.initState();
    if (widget.bootstrapOnStart) {
      unawaited(widget.container.bootstrap());
    }
  }

  ThemeMode get _themeMode {
    return switch (widget.container.memberBootstrap?.themePreference) {
      MemberThemePreference.light => ThemeMode.light,
      MemberThemePreference.dark => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.container,
    builder: (context, _) => MaterialApp.router(
      debugShowCheckedModeBanner: false,
      restorationScopeId: 'ritual-investing-app',
      title: 'Ritual Investing',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode,
      routerConfig: _router,
    ),
  );

  @override
  void dispose() {
    _router.dispose();
    widget.container.dispose();
    super.dispose();
  }
}
