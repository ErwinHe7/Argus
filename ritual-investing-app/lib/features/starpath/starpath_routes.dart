import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/bootstrap/app_runtime.dart';
import '../../core/navigation/member_routes.dart';

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
  Widget build(BuildContext context) => const Scaffold(
    key: Key('starpath-root'),
    body: SafeArea(
      child: Center(
        child: Text('Starpath is preparing your factual learning path.'),
      ),
    ),
  );
}
