import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/bootstrap/app_runtime.dart';
import '../../core/navigation/member_routes.dart';
import '../intentions/presentation/member_scenario_screen.dart';
import '../notifications/presentation/notification_screen.dart';
import '../orders/presentation/brokerage_order_screen.dart';
import '../portfolio/presentation/brokerage_portfolio_screen.dart';
import '../privacy/presentation/privacy_screen.dart';
import 'presentation/profile_screen.dart';

StatefulShellBranch buildYouBranch({
  required AppRuntime container,
  Future<void> Function()? onLogout,
  bool restorationEnabled = true,
}) => StatefulShellBranch(
  restorationScopeId: restorationEnabled
      ? '${MemberRoutes.you.name}-branch'
      : null,
  routes: [
    GoRoute(
      path: MemberRoutes.you.path,
      name: MemberRoutes.you.name,
      builder: (context, state) =>
          _YouBranchRoot(container: container, showAccount: onLogout != null),
      routes: [
        _portfolioRoute(container),
        ..._memberScenarioRoutes(container),
        ..._brokerageOrderRoutes(container),
        ..._settingsRoutes(container, onLogout),
      ],
    ),
  ],
);

GoRoute _portfolioRoute(AppRuntime container) => GoRoute(
  path: MemberRoutes.portfolio.relativeResourcePath!,
  name: MemberRoutes.portfolio.name,
  redirect: (context, state) {
    final accountId = state.pathParameters['stableId'];
    return container.hasBrokeragePortfolio &&
            accountId != null &&
            MemberRoutes.isStableId(accountId)
        ? null
        : MemberRoutes.you.path;
  },
  builder: (context, state) {
    final accountId = state.pathParameters['stableId']!;
    return BrokeragePortfolioScreen(
      key: ValueKey('brokerage-portfolio-$accountId'),
      accountId: accountId,
      connectionController: container.brokerageConnectionController,
      portfolioController: container.brokeragePortfolioController,
      onOpenAccount: (id) =>
          context.pushReplacement(MemberRoutes.portfolio.location(id)),
      onOpenOrders: container.hasBrokerageOrders
          ? () => context.push(MemberRoutes.portfolioOrdersLocation(accountId))
          : null,
    );
  },
);

List<RouteBase> _memberScenarioRoutes(AppRuntime container) => [
  GoRoute(
    path: 'intentions',
    redirect: (context, state) =>
        container.hasMemberScenarios ? null : MemberRoutes.you.path,
    builder: (context, state) => MemberScenariosScreen(
      key: const ValueKey('member-intentions'),
      controller: container.memberScenarioController,
      onOpenIntention: (id) =>
          context.push(MemberRoutes.memberIntentionLocation(id)),
    ),
  ),
  GoRoute(
    path: 'intentions/:intentionId',
    redirect: (context, state) =>
        container.hasMemberScenarios &&
            MemberRoutes.isUuid(state.pathParameters['intentionId'] ?? '')
        ? null
        : MemberRoutes.you.path,
    builder: (context, state) => MemberScenariosScreen(
      key: ValueKey('member-intention-${state.pathParameters['intentionId']}'),
      intentionId: state.pathParameters['intentionId']!,
      controller: container.memberScenarioController,
      onOpenRun: (id) => context.push(
        MemberRoutes.memberFutureMirrorRunLocation(
          state.pathParameters['intentionId']!,
          id,
        ),
      ),
    ),
  ),
  GoRoute(
    path: 'intentions/:intentionId/future-mirror',
    redirect: (context, state) =>
        container.hasMemberScenarios &&
            MemberRoutes.isUuid(state.pathParameters['intentionId'] ?? '')
        ? null
        : MemberRoutes.you.path,
    builder: (context, state) => MemberScenariosScreen(
      key: ValueKey(
        'member-future-mirror-${state.pathParameters['intentionId']}',
      ),
      intentionId: state.pathParameters['intentionId']!,
      controller: container.memberScenarioController,
    ),
  ),
  GoRoute(
    path: 'intentions/:intentionId/future-mirror/:runId',
    redirect: (context, state) =>
        container.hasMemberScenarios &&
            MemberRoutes.isUuid(state.pathParameters['intentionId'] ?? '') &&
            MemberRoutes.isUuid(state.pathParameters['runId'] ?? '')
        ? null
        : MemberRoutes.you.path,
    builder: (context, state) => MemberScenariosScreen(
      key: ValueKey('member-future-mirror-${state.pathParameters['runId']}'),
      intentionId: state.pathParameters['intentionId']!,
      runId: state.pathParameters['runId']!,
      controller: container.memberScenarioController,
    ),
  ),
];

List<RouteBase> _brokerageOrderRoutes(AppRuntime container) => [
  GoRoute(
    path: 'portfolios/:portfolioId/orders',
    redirect: (context, state) =>
        _validBrokerageOrderRoute(
          container,
          state.pathParameters['portfolioId'],
        )
        ? null
        : MemberRoutes.you.path,
    builder: (context, state) {
      final accountId = state.pathParameters['portfolioId']!;
      final instrumentId = state.uri.queryParameters['asset_id'];
      final symbol = state.uri.queryParameters['symbol'];
      return BrokerageOrderScreen(
        key: ValueKey(
          'webull-orders-$accountId-${instrumentId ?? 'positions'}',
        ),
        accountId: accountId,
        controller: container.brokerageOrderController,
        portfolioController: container.brokeragePortfolioController,
        preselectedInstrumentId:
            instrumentId != null && MemberRoutes.isStableId(instrumentId)
            ? instrumentId
            : null,
        preselectedSymbol: symbol?.trim().isNotEmpty == true ? symbol : null,
        onOpenOrder: (orderId) => context.push(
          MemberRoutes.portfolioOrderLocation(accountId, orderId),
        ),
      );
    },
  ),
  GoRoute(
    path: 'portfolios/:portfolioId/orders/:orderId',
    redirect: (context, state) =>
        _validBrokerageOrderRoute(
              container,
              state.pathParameters['portfolioId'],
            ) &&
            MemberRoutes.isStableId(state.pathParameters['orderId'] ?? '')
        ? null
        : MemberRoutes.you.path,
    builder: (context, state) => BrokerageOrderDetailScreen(
      key: ValueKey(
        'webull-order-${state.pathParameters['portfolioId']}-'
        '${state.pathParameters['orderId']}',
      ),
      accountId: state.pathParameters['portfolioId']!,
      orderId: state.pathParameters['orderId']!,
      controller: container.brokerageOrderController,
    ),
  ),
];

List<RouteBase> _settingsRoutes(
  AppRuntime container,
  Future<void> Function()? onLogout,
) => [
  GoRoute(
    path: 'investing',
    builder: (context, state) => InvestingProfileScreen(
      controller: container.profileController,
      onSave: container.updateMemberInvestor,
    ),
  ),
  GoRoute(
    path: 'gospel-preferences',
    builder: (context, state) => RitualPreferencesScreen(
      controller: container.profileController,
      onSave: container.updateMemberPreferences,
    ),
  ),
  GoRoute(
    path: 'astrology',
    builder: (context, state) => AstrologySettingsScreen(
      controller: container.profileController,
      onEnable: container.updateMemberAstrology,
      onDelete: container.deleteMemberAstrology,
    ),
  ),
  GoRoute(
    path: 'policies',
    builder: (context, state) => PolicyStatusScreen(
      controller: container.profileController,
      onboardingComplete:
          container.memberBootstrap?.onboarding.isComplete ?? false,
    ),
  ),
  if (onLogout != null)
    GoRoute(
      path: 'account',
      builder: (context, state) => AccountSettingsScreen(onLogout: onLogout),
    ),
  GoRoute(
    path: 'privacy',
    redirect: (context, state) =>
        container.hasPrivacyControls ? null : MemberRoutes.you.path,
    builder: (context, state) =>
        PrivacySettingsScreen(controller: container.privacyController),
  ),
  GoRoute(
    path: 'notifications',
    redirect: (context, state) =>
        container.hasBriefingsAndNotifications ? null : MemberRoutes.you.path,
    builder: (context, state) => NotificationsScreen(
      controller: container.notificationController,
      onOpenDestination: (destination) => context.push(destination.location),
      onOpenPreferences: () =>
          context.push(MemberRoutes.youNotificationPreferencesPath),
    ),
  ),
  GoRoute(
    path: 'notification-preferences',
    redirect: (context, state) =>
        container.hasBriefingsAndNotifications ? null : MemberRoutes.you.path,
    builder: (context, state) => NotificationPreferencesScreen(
      controller: container.notificationController,
    ),
  ),
];

class _YouBranchRoot extends StatefulWidget {
  const _YouBranchRoot({required this.container, required this.showAccount});

  final AppRuntime container;
  final bool showAccount;

  @override
  State<_YouBranchRoot> createState() => _YouBranchRootState();
}

class _YouBranchRootState extends State<_YouBranchRoot> {
  @override
  void initState() {
    super.initState();
    widget.container.ensureBranchLoaded(MemberBranch.you);
  }

  @override
  Widget build(BuildContext context) => ProfileScreen(
    controller: widget.container.profileController,
    brokerageConnectionController: widget.container.hasBrokeragePortfolio
        ? widget.container.brokerageConnectionController
        : null,
    brokeragePortfolioController: widget.container.hasBrokeragePortfolio
        ? widget.container.brokeragePortfolioController
        : null,
    onOpenInvesting: () => context.push(MemberRoutes.youInvestingPath),
    onOpenRitualPreferences: () =>
        context.push(MemberRoutes.youRitualPreferencesPath),
    onOpenAstrology: () => context.push(MemberRoutes.youAstrologyPath),
    onOpenPolicies: () => context.push(MemberRoutes.youPoliciesPath),
    onOpenAccount: widget.showAccount
        ? () => context.push(MemberRoutes.youAccountPath)
        : null,
    onOpenNotifications: widget.container.hasBriefingsAndNotifications
        ? () => context.push(MemberRoutes.youNotificationsPath)
        : null,
    onOpenPrivacy: widget.container.hasPrivacyControls
        ? () => context.push(MemberRoutes.youPrivacyPath)
        : null,
    onOpenIntentions: widget.container.hasMemberScenarios
        ? () => context.push(MemberRoutes.youIntentionsPath)
        : null,
    onOpenPortfolio: (id) => context.push(MemberRoutes.portfolio.location(id)),
  );
}

bool _validBrokerageOrderRoute(AppRuntime container, String? accountId) =>
    container.hasBrokerageOrders &&
    accountId != null &&
    MemberRoutes.isStableId(accountId) &&
    container.brokerageConnectionController.snapshot.activeAccountId ==
        accountId;
