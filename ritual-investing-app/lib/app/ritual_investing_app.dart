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
  late GoRouter _router;
  late String _navigationSignature;
  String? _pendingMemberPath;
  bool _routerRefreshScheduled = false;

  @override
  void initState() {
    super.initState();
    _navigationSignature = _signature;
    _router = _createRouter();
    widget.container.addListener(_scheduleRouterRefresh);
    if (widget.bootstrapOnStart) {
      unawaited(widget.container.bootstrap());
    }
  }

  String get _signature {
    final policy = MemberNavigationPolicy.fromBootstrap(
      widget.container.memberBootstrap,
    );
    return '${policy.capabilityVersion}:'
        '${policy.isAuthoritative}:'
        '${policy.branches.map((branch) => branch.name).join(',')}';
  }

  GoRouter _createRouter({String? initialLocation}) => createAppRouter(
    container: widget.container,
    resourceAccess: widget.resourceAccess,
    allowSelfServiceSignup: widget.allowSelfServiceSignup,
    initialLocation: initialLocation,
    readPendingMemberPath: () => _pendingMemberPath,
    writePendingMemberPath: (value) => _pendingMemberPath = value,
  );

  void _scheduleRouterRefresh() {
    if (_routerRefreshScheduled || _signature == _navigationSignature) return;
    _routerRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _routerRefreshScheduled = false;
      if (!mounted || _signature == _navigationSignature) return;
      final oldRouter = _router;
      final policy = MemberNavigationPolicy.fromBootstrap(
        widget.container.memberBootstrap,
      );
      final current = oldRouter.state.uri.toString();
      final replacement = policy.redirectFor(oldRouter.state.uri.path);
      _navigationSignature = _signature;
      setState(() {
        _router = _createRouter(initialLocation: replacement ?? current);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => oldRouter.dispose());
    });
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
      title: 'Leo',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode,
      routerConfig: _router,
    ),
  );

  @override
  void dispose() {
    widget.container.removeListener(_scheduleRouterRefresh);
    _router.dispose();
    widget.container.dispose();
    super.dispose();
  }
}
