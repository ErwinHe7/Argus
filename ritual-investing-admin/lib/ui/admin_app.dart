import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../application/admin_session_controller.dart';
import '../data/admin_gateway.dart';
import '../domain/admin_models.dart';
import 'admin_shell.dart';
import 'workspace_screen.dart';

class AdminApp extends StatefulWidget {
  const AdminApp({
    required this.session,
    required this.gateway,
    this.initialLocation = '/',
    super.key,
  });
  final AdminSessionController session;
  final AdminGateway gateway;
  final String initialLocation;

  @override
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    widget.session.attachGateway(widget.gateway);
    _router = GoRouter(
      initialLocation: widget.initialLocation,
      refreshListenable: widget.session,
      redirect: (context, state) {
        final login = state.matchedLocation == '/login';
        if (!widget.session.isReady) return login ? null : '/login';
        if (login) return _firstAllowed();
        final destination = _destinationFor(state.uri.path);
        if (destination != null &&
            !widget.session.permits(destination.readPermission)) {
          return '/forbidden';
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => _LoginScreen(session: widget.session),
        ),
        GoRoute(
          path: '/forbidden',
          builder: (context, state) => const _ForbiddenScreen(),
        ),
        ShellRoute(
          builder: (context, state, child) => AdminShell(
            session: widget.session,
            currentPath: state.uri.path,
            child: child,
          ),
          routes: [
            GoRoute(path: '/', redirect: (context, state) => _firstAllowed()),
            for (final destination in adminDestinations)
              GoRoute(
                path: destination.route,
                builder: (context, state) => WorkspaceScreen(
                  destination: destination,
                  session: widget.session,
                  gateway: widget.gateway,
                ),
              ),
          ],
        ),
      ],
    );
    widget.session.onNavigate = _router.go;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => widget.session.restore(),
    );
  }

  AdminDestination? _destinationFor(String path) {
    for (final destination in adminDestinations) {
      if (destination.route == path) return destination;
    }
    return null;
  }

  String _firstAllowed() {
    for (final destination in adminDestinations) {
      if (widget.session.permits(destination.readPermission)) {
        return destination.route;
      }
    }
    return '/forbidden';
  }

  @override
  void dispose() {
    widget.session.onNavigate = null;
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Ritual Staff',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff493657),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xfff7f4f0),
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
    ),
    routerConfig: _router,
  );
}

class _LoginScreen extends StatelessWidget {
  const _LoginScreen({required this.session});
  final AdminSessionController session;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield_outlined, size: 48),
                const SizedBox(height: 20),
                Text(
                  'Ritual staff access',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Cloudflare Access and an active Auth0 staff identity are both required.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: session.login,
                  icon: const Icon(Icons.login),
                  label: const Text('Continue with staff identity'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _ForbiddenScreen extends StatelessWidget {
  const _ForbiddenScreen();
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: Text('You do not have access to this workspace.')),
  );
}
