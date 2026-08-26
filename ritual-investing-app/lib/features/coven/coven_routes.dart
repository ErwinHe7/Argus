import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/bootstrap/app_runtime.dart';
import '../../core/bootstrap/member_bootstrap.dart';
import '../../core/navigation/member_routes.dart';
import 'application/controller.dart';
import 'presentation/coven_detail_screen.dart';
import 'presentation/coven_screen.dart';

StatefulShellBranch buildCovenBranch({
  required AppRuntime container,
  required MemberResourceAccess resourceAccess,
}) => StatefulShellBranch(
  restorationScopeId: '${MemberRoutes.coven.name}-branch',
  routes: [
    GoRoute(
      path: MemberRoutes.coven.path,
      name: MemberRoutes.coven.name,
      builder: (context, state) => _CovenBranchRoot(container: container),
      routes: [
        GoRoute(
          path: MemberRoutes.covenEntry.relativeResourcePath!,
          name: MemberRoutes.covenEntry.name,
          redirect: (context, state) {
            final stableId = state.pathParameters['stableId'];
            return stableId != null &&
                    MemberRoutes.isUuid(stableId) &&
                    (container.hasMemberResearch ||
                        resourceAccess(MemberRoutes.covenEntry, stableId))
                ? null
                : MemberRoutes.coven.path;
          },
          builder: (context, state) {
            final stableId = state.pathParameters['stableId']!;
            if (!container.hasMemberResearch) {
              return const _CovenResourceFallback();
            }
            return _CovenDetailRoute(
              key: ValueKey('coven-detail-$stableId'),
              container: container,
              entryId: stableId,
            );
          },
        ),
      ],
    ),
  ],
);

class _CovenBranchRoot extends StatefulWidget {
  const _CovenBranchRoot({required this.container});

  final AppRuntime container;

  @override
  State<_CovenBranchRoot> createState() => _CovenBranchRootState();
}

class _CovenBranchRootState extends State<_CovenBranchRoot> {
  @override
  void initState() {
    super.initState();
    widget.container.ensureBranchLoaded(MemberBranch.coven);
  }

  @override
  Widget build(BuildContext context) => CovenScreen(
    controller: widget.container.covenController,
    onOpenEntry: (id) => context.push(MemberRoutes.covenEntry.location(id)),
  );
}

class _CovenDetailRoute extends StatefulWidget {
  const _CovenDetailRoute({
    super.key,
    required this.container,
    required this.entryId,
  });

  final AppRuntime container;
  final String entryId;

  @override
  State<_CovenDetailRoute> createState() => _CovenDetailRouteState();
}

class _CovenDetailRouteState extends State<_CovenDetailRoute> {
  late final CovenDetailController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.container.createCovenDetailController(widget.entryId);
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CovenDetailScreen(
    controller: _controller,
    rowanController: widget.container.optionalRowanController,
    personalization:
        widget.container.memberBootstrap?.personalization ??
        const MemberPersonalization(),
  );
}

class _CovenResourceFallback extends StatelessWidget {
  const _CovenResourceFallback();

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('detail-coven-entry'),
    appBar: AppBar(title: const Text('Member detail')),
    body: const SafeArea(
      child: Center(child: Text('This saved member detail is ready.')),
    ),
  );
}
