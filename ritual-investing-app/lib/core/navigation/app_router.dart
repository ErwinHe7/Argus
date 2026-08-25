import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/coven/presentation/coven_screen.dart';
import '../../features/discover/presentation/discover_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/ritual/presentation/daily_ritual_screen.dart';
import '../../features/shell/presentation/app_shell.dart';
import '../bootstrap/dependency_container.dart';
import 'member_routes.dart';

GoRouter createAppRouter({
  required DependencyContainer container,
  required ValueChanged<Brightness> onToggleTheme,
  MemberResourceAccess? resourceAccess,
}) {
  final access = resourceAccess ?? (_, _) => false;

  GoRoute resourceRoute(MemberRouteDefinition definition) => GoRoute(
    path: definition.relativeResourcePath!,
    name: definition.name,
    redirect: (context, state) {
      final stableId = state.pathParameters['stableId'];
      if (stableId == null ||
          !MemberRoutes.isStableId(stableId) ||
          !access(definition, stableId)) {
        return MemberRoutes.rootFor(definition.branch).path;
      }
      return null;
    },
    builder: (context, state) => _MemberResourceScreen(route: definition),
  );

  StatefulShellBranch branch(
    MemberRouteDefinition root,
    MemberRouteDefinition detail,
  ) => StatefulShellBranch(
    restorationScopeId: '${root.name}-branch',
    routes: [
      GoRoute(
        path: root.path,
        name: root.name,
        builder: (context, state) => _LazyMemberBranch(
          key: ValueKey(root.name),
          branch: root.branch,
          container: container,
          onToggleTheme: onToggleTheme,
        ),
        routes: [resourceRoute(detail)],
      ),
    ],
  );

  return GoRouter(
    initialLocation: '/entry',
    restorationScopeId: 'ritual-investing-router',
    refreshListenable: container,
    redirect: (context, state) {
      final atEntry = state.uri.path == '/entry';
      if (container.entryGate != MemberEntryGate.member) {
        return atEntry ? null : '/entry';
      }
      return atEntry || state.uri.path == '/' ? MemberRoutes.ritual.path : null;
    },
    routes: [
      GoRoute(
        path: '/entry',
        builder: (context, state) => _EntryGate(container: container),
      ),
      StatefulShellRoute.indexedStack(
        restorationScopeId: 'member-shell',
        branches: [
          branch(MemberRoutes.ritual, MemberRoutes.ritualReading),
          branch(MemberRoutes.discover, MemberRoutes.discoverAsset),
          branch(MemberRoutes.coven, MemberRoutes.covenEntry),
          branch(MemberRoutes.you, MemberRoutes.portfolio),
        ],
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
      ),
    ],
  );
}

class _LazyMemberBranch extends StatefulWidget {
  const _LazyMemberBranch({
    super.key,
    required this.branch,
    required this.container,
    required this.onToggleTheme,
  });

  final MemberBranch branch;
  final DependencyContainer container;
  final ValueChanged<Brightness> onToggleTheme;

  @override
  State<_LazyMemberBranch> createState() => _LazyMemberBranchState();
}

class _LazyMemberBranchState extends State<_LazyMemberBranch> {
  @override
  void initState() {
    super.initState();
    widget.container.ensureBranchLoaded(widget.branch);
  }

  @override
  Widget build(BuildContext context) => switch (widget.branch) {
    MemberBranch.ritual => DailyRitualScreen(
      controller: widget.container.dailyRitualController,
      onOpenCoven: () => context.go(MemberRoutes.coven.path),
      onToggleTheme: () => widget.onToggleTheme(Theme.of(context).brightness),
    ),
    MemberBranch.discover => DiscoverScreen(
      controller: widget.container.discoverController,
    ),
    MemberBranch.coven => CovenScreen(
      controller: widget.container.covenController,
    ),
    MemberBranch.you => ProfileScreen(
      controller: widget.container.profileController,
      portfolioController: widget.container.portfolioController,
    ),
  };
}

class _MemberResourceScreen extends StatelessWidget {
  const _MemberResourceScreen({required this.route});

  final MemberRouteDefinition route;

  @override
  Widget build(BuildContext context) => Scaffold(
    key: Key('detail-${route.name}'),
    appBar: AppBar(title: const Text('Member detail')),
    body: const SafeArea(
      child: Center(child: Text('This saved member detail is ready.')),
    ),
  );
}

class _EntryGate extends StatelessWidget {
  const _EntryGate({required this.container});

  final DependencyContainer container;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: container,
    builder: (context, child) => _buildGate(context),
  );

  Widget _buildGate(BuildContext context) {
    final state = container.authController.state;
    final (
      message,
      actionLabel,
      action,
      secondaryLabel,
      secondaryAction,
    ) = switch (container.entryGate) {
      MemberEntryGate.restoring => (
        'Restoring your session',
        null,
        null,
        null,
        null,
      ),
      MemberEntryGate.signedOut => (
        'Sign in to continue your private ritual.',
        'Sign in',
        container.login,
        null,
        null,
      ),
      MemberEntryGate.failure => (
        state.message ?? 'Sign-in is temporarily unavailable.',
        'Retry',
        container.bootstrap,
        state.canLogout ? 'Log out' : null,
        state.canLogout ? container.logout : null,
      ),
      MemberEntryGate.onboarding => (
        'Complete onboarding to continue.',
        null,
        null,
        'Log out',
        container.logout,
      ),
      MemberEntryGate.entitlement => (
        'Demo membership is unavailable for this account.',
        null,
        null,
        'Log out',
        container.logout,
      ),
      MemberEntryGate.member => (null, null, null, null, null),
    };
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (container.entryGate == MemberEntryGate.restoring)
                  const CircularProgressIndicator(),
                if (container.entryGate == MemberEntryGate.restoring)
                  const SizedBox(height: 16),
                if (message != null) Text(message, textAlign: TextAlign.center),
                if (action != null)
                  TextButton(onPressed: action, child: Text(actionLabel!)),
                if (secondaryAction != null)
                  TextButton(
                    onPressed: secondaryAction,
                    child: Text(secondaryLabel!),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
