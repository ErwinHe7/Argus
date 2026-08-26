import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/bootstrap/app_runtime.dart';
import '../../core/bootstrap/member_bootstrap.dart';
import '../../core/navigation/member_routes.dart';
import '../briefings/presentation/briefing_screen.dart';
import '../entitlements/domain/model.dart';
import '../entitlements/presentation/demo_membership_screen.dart';
import 'presentation/daily_ritual_screen.dart';

StatefulShellBranch buildRitualBranch({
  required AppRuntime container,
  required MemberResourceAccess resourceAccess,
  bool restorationEnabled = true,
  String? assetPackage,
}) => StatefulShellBranch(
  restorationScopeId: restorationEnabled
      ? '${MemberRoutes.ritual.name}-branch'
      : null,
  routes: [
    GoRoute(
      path: MemberRoutes.ritual.path,
      name: MemberRoutes.ritual.name,
      builder: (context, state) =>
          _RitualBranchRoot(container: container, assetPackage: assetPackage),
      routes: [
        GoRoute(
          path: MemberRoutes.ritualReading.relativeResourcePath!,
          name: MemberRoutes.ritualReading.name,
          redirect: (context, state) {
            final stableId = state.pathParameters['stableId'];
            return stableId != null &&
                    MemberRoutes.isStableId(stableId) &&
                    resourceAccess(MemberRoutes.ritualReading, stableId)
                ? null
                : MemberRoutes.ritual.path;
          },
          builder: (context, state) => const _RitualReadingScreen(),
        ),
        GoRoute(
          path: 'briefings',
          redirect: (context, state) => container.hasBriefingsAndNotifications
              ? null
              : MemberRoutes.ritual.path,
          builder: (context, state) => BriefingsScreen(
            controller: container.briefingController,
            onOpenBriefing: (briefingId) =>
                context.push(MemberRoutes.briefingLocation(briefingId)),
          ),
        ),
        GoRoute(
          path: 'briefings/:briefingId',
          redirect: (context, state) =>
              container.hasBriefingsAndNotifications &&
                  MemberRoutes.isUuid(state.pathParameters['briefingId'] ?? '')
              ? null
              : MemberRoutes.ritual.path,
          builder: (context, state) => BriefingDetailScreen(
            key: ValueKey('briefing-${state.pathParameters['briefingId']}'),
            briefingId: state.pathParameters['briefingId']!,
            controller: container.briefingController,
            onOpenRitual: () => context.go(MemberRoutes.ritual.path),
            onOpenBriefings: () => context.go(MemberRoutes.ritualBriefingsPath),
          ),
        ),
      ],
    ),
  ],
);

class _RitualBranchRoot extends StatefulWidget {
  const _RitualBranchRoot({required this.container, this.assetPackage});

  final AppRuntime container;
  final String? assetPackage;

  @override
  State<_RitualBranchRoot> createState() => _RitualBranchRootState();
}

class _RitualBranchRootState extends State<_RitualBranchRoot> {
  @override
  void initState() {
    super.initState();
    widget.container.ensureBranchLoaded(MemberBranch.ritual);
  }

  @override
  Widget build(BuildContext context) {
    final child = DailyRitualScreen(
      controller: widget.container.dailyRitualController,
      onOpenCoven: () => context.go(MemberRoutes.coven.path),
      onToggleTheme: widget.container.presentationPolicy.allowsProfileEditing
          ? () => context.go(MemberRoutes.youRitualPreferencesPath)
          : null,
      onOpenSearch: widget.container.optionalSearchController == null
          ? null
          : () => context.push(MemberRoutes.discoverSearchPath),
      onOpenBriefings: widget.container.hasBriefingsAndNotifications
          ? () => context.push(MemberRoutes.ritualBriefingsPath)
          : null,
      onOpenAsset: (id) {
        final assignmentId =
            widget.container.dailyRitualController.state.value?.assignmentId;
        context.push(
          MemberRoutes.assetLocation(
            id,
            sourceKind: 'ritual',
            sourceId: assignmentId,
          ),
        );
      },
      rowanController: widget.container.optionalRowanController,
      personalization:
          widget.container.memberBootstrap?.personalization ??
          const MemberPersonalization(),
      assetPackage: widget.assetPackage,
    );
    if (!widget.container.hasDemoMembership) return child;
    return DemoCapabilityGate(
      key: const ValueKey('daily-ritual-capability-gate'),
      controller: widget.container.entitlementController,
      capability: DemoCapability.dailyRitual,
      returnLocation: MemberRoutes.ritual.path,
      onOpenMembership: () => context.push(
        MemberRoutes.membershipLocation(
          capabilityCode: DemoCapability.dailyRitual.code,
          returnLocation: MemberRoutes.ritual.path,
        ),
      ),
      child: child,
    );
  }
}

class _RitualReadingScreen extends StatelessWidget {
  const _RitualReadingScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
    key: Key('detail-ritual-reading'),
    appBar: _RitualReadingAppBar(),
    body: SafeArea(
      child: Center(child: Text('This saved member detail is ready.')),
    ),
  );
}

class _RitualReadingAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _RitualReadingAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) =>
      AppBar(title: const Text('Member detail'));
}
