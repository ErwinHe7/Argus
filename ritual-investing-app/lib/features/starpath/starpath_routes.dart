import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/bootstrap/app_runtime.dart';
import '../../core/navigation/member_routes.dart';
import 'presentation/starpath_screen.dart';

StatefulShellBranch buildStarpathBranch({
  required AppRuntime container,
  bool restorationEnabled = true,
}) => StatefulShellBranch(
  restorationScopeId: restorationEnabled
      ? '${MemberRoutes.starpath.name}-branch'
      : null,
  routes: [
    GoRoute(
      path: MemberRoutes.starpath.path,
      name: MemberRoutes.starpath.name,
      builder: (context, state) => _StarpathBranchRoot(container: container),
    ),
  ],
);

class _StarpathBranchRoot extends StatefulWidget {
  const _StarpathBranchRoot({required this.container});

  final AppRuntime container;

  @override
  State<_StarpathBranchRoot> createState() => _StarpathBranchRootState();
}

class _StarpathBranchRootState extends State<_StarpathBranchRoot> {
  @override
  void initState() {
    super.initState();
    widget.container.ensureBranchLoaded(MemberBranch.starpath);
  }

  @override
  Widget build(BuildContext context) => StarpathScreen(
    key: const Key('starpath-root'),
    controller: widget.container.starpathController,
  );
}
