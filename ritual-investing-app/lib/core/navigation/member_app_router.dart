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
}) {
  final access = resourceAccess ?? (_, _) => false;
  return StatefulShellRoute.indexedStack(
    restorationScopeId: 'member-shell',
    branches: [
      buildRitualBranch(container: runtime, resourceAccess: access),
      buildDiscoverBranch(container: runtime, resourceAccess: access),
      buildCovenBranch(container: runtime, resourceAccess: access),
      buildYouBranch(container: runtime, onLogout: onLogout),
    ],
    builder: (context, state, navigationShell) =>
        AppShell(navigationShell: navigationShell),
  );
}
