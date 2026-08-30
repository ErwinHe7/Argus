import 'package:go_router/go_router.dart';

import '../../features/coven/coven_routes.dart';
import '../../features/discover/discover_routes.dart';
import '../../features/profile/you_routes.dart';
import '../../features/ritual/ritual_routes.dart';
import '../../features/shell/presentation/app_shell.dart';
import '../../features/starpath/starpath_routes.dart';
import '../bootstrap/app_runtime.dart';
import 'member_routes.dart';

StatefulShellRoute buildMemberShellRoute({
  required AppRuntime runtime,
  MemberResourceAccess? resourceAccess,
  Future<void> Function()? onLogout,
  bool restorationEnabled = true,
  String? assetPackage,
}) {
  final access = resourceAccess ?? (_, _) => false;
  final policy = MemberNavigationPolicy.fromBootstrap(runtime.memberBootstrap);
  return StatefulShellRoute.indexedStack(
    restorationScopeId: restorationEnabled ? 'member-shell' : null,
    branches: [
      for (final branch in policy.branches)
        switch (branch) {
          MemberBranch.ritual => buildRitualBranch(
            container: runtime,
            resourceAccess: access,
            restorationEnabled: restorationEnabled,
            assetPackage: assetPackage,
          ),
          MemberBranch.starpath => buildStarpathBranch(
            container: runtime,
            restorationEnabled: restorationEnabled,
          ),
          MemberBranch.discover => buildDiscoverBranch(
            container: runtime,
            resourceAccess: access,
            restorationEnabled: restorationEnabled,
          ),
          MemberBranch.coven => buildCovenBranch(
            container: runtime,
            resourceAccess: access,
            restorationEnabled: restorationEnabled,
          ),
          MemberBranch.you => buildYouBranch(
            container: runtime,
            onLogout: onLogout,
            restorationEnabled: restorationEnabled,
          ),
        },
    ],
    builder: (context, state, navigationShell) =>
        AppShell(navigationShell: navigationShell, branches: policy.branches),
  );
}

GoRouter createMemberOnlyRouter({
  required AppRuntime runtime,
  MemberResourceAccess? resourceAccess,
  String? assetPackage,
}) => GoRouter(
  initialLocation: MemberRoutes.ritual.path,
  redirect: (context, state) {
    if (runtime.entryGate != MemberEntryGate.member) {
      return MemberRoutes.ritual.path;
    }
    if (state.uri.path == '/') return MemberRoutes.ritual.path;
    return MemberNavigationPolicy.fromBootstrap(runtime.memberBootstrap)
        .redirectFor(state.uri.path);
  },
  routes: [
    buildMemberShellRoute(
      runtime: runtime,
      resourceAccess: resourceAccess,
      restorationEnabled: false,
      assetPackage: assetPackage,
    ),
  ],
);
