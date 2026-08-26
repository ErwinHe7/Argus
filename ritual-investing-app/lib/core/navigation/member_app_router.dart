import 'package:go_router/go_router.dart';

import '../../features/coven/coven_routes.dart';
import '../../features/discover/discover_routes.dart';
import '../../features/profile/you_routes.dart';
import '../../features/ritual/ritual_routes.dart';
import '../../features/shell/presentation/app_shell.dart';
import '../bootstrap/app_runtime.dart';
import 'member_routes.dart';

StatefulShellRoute buildMemberShellRoute({
  required AppRuntime runtime,
  MemberResourceAccess? resourceAccess,
  Future<void> Function()? onLogout,
  bool restorationEnabled = true,
}) {
  final access = resourceAccess ?? (_, _) => false;
  return StatefulShellRoute.indexedStack(
    restorationScopeId: restorationEnabled ? 'member-shell' : null,
    branches: [
      buildRitualBranch(
        container: runtime,
        resourceAccess: access,
        restorationEnabled: restorationEnabled,
      ),
      buildDiscoverBranch(
        container: runtime,
        resourceAccess: access,
        restorationEnabled: restorationEnabled,
      ),
      buildCovenBranch(
        container: runtime,
        resourceAccess: access,
        restorationEnabled: restorationEnabled,
      ),
      buildYouBranch(
        container: runtime,
        onLogout: onLogout,
        restorationEnabled: restorationEnabled,
      ),
    ],
    builder: (context, state, navigationShell) =>
        AppShell(navigationShell: navigationShell),
  );
}

GoRouter createMemberOnlyRouter({
  required AppRuntime runtime,
  MemberResourceAccess? resourceAccess,
}) => GoRouter(
  initialLocation: MemberRoutes.ritual.path,
  redirect: (context, state) => runtime.entryGate == MemberEntryGate.member
      ? (state.uri.path == '/' ? MemberRoutes.ritual.path : null)
      : MemberRoutes.ritual.path,
  routes: [
    buildMemberShellRoute(
      runtime: runtime,
      resourceAccess: resourceAccess,
      restorationEnabled: false,
    ),
  ],
);
