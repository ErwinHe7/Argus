import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/bootstrap/app_runtime.dart';
import '../../core/navigation/member_routes.dart';
import '../entitlements/domain/model.dart';
import '../entitlements/presentation/demo_membership_screen.dart';
import '../future_mirror/presentation/future_mirror_screen.dart';
import '../intentions/presentation/intention_screen.dart';
import '../notifications/presentation/notification_screen.dart';
import '../orders/presentation/order_screen.dart';
import '../portfolio/presentation/portfolio_screen.dart';
import '../privacy/presentation/privacy_screen.dart';
import '../rebalancing/presentation/rebalance_screen.dart';
import '../recurring/presentation/recurring_plan_screen.dart';
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
      builder: (context, state) => _YouBranchRoot(
        container: container,
        showAccount:
            container.presentationPolicy.showsAccount && onLogout != null,
      ),
      routes: [
        _portfolioRoute(container),
        ..._intentionRoutes(container),
        ..._simulatedInvestingRoutes(container),
        ..._settingsRoutes(
          container,
          container.presentationPolicy.showsAccount ? onLogout : null,
        ),
      ],
    ),
  ],
);

GoRoute _portfolioRoute(AppRuntime container) => GoRoute(
  path: MemberRoutes.portfolio.relativeResourcePath!,
  name: MemberRoutes.portfolio.name,
  redirect: (context, state) {
    final stableId = state.pathParameters['stableId'];
    return stableId != null && MemberRoutes.isStableId(stableId)
        ? null
        : MemberRoutes.you.path;
  },
  builder: (context, state) {
    final stableId = state.pathParameters['stableId']!;
    final child = PortfolioScreen(
      key: ValueKey('portfolio-$stableId'),
      portfolioId: stableId,
      portfolioController: container.portfolioController,
      fundingSourceController: container.fundingSourceController,
      contributionController: container.contributionController,
      readOnly: container.presentationPolicy.isDemo,
      onOpenPortfolio: (id) =>
          context.pushReplacement(MemberRoutes.portfolio.location(id)),
      onOpenAsset: container.hasAssetCodex
          ? (id) => context.push(
              MemberRoutes.assetLocation(id, sourceKind: 'direct'),
            )
          : null,
      onOpenOrders: container.hasSimulatedInvesting
          ? () => context.push(MemberRoutes.portfolioOrdersLocation(stableId))
          : null,
      onOpenRecurringPlans: container.hasSimulatedInvesting
          ? () =>
                context.push(MemberRoutes.portfolioRecurringLocation(stableId))
          : null,
      onOpenRebalance: container.hasSimulatedInvesting
          ? () =>
                context.push(MemberRoutes.portfolioRebalanceLocation(stableId))
          : null,
      onOpenIntentions: container.hasIntentionsAndFutureMirror
          ? () =>
                context.push(MemberRoutes.portfolioIntentionsLocation(stableId))
          : null,
    );
    if (!container.hasDemoMembership) return child;
    return DemoCapabilityGate(
      key: ValueKey('demo-portfolio-gate-$stableId'),
      controller: container.entitlementController,
      capability: DemoCapability.demoPortfolio,
      returnLocation: state.uri.path,
      onOpenMembership: () => context.push(
        MemberRoutes.membershipLocation(
          capabilityCode: DemoCapability.demoPortfolio.code,
          returnLocation: state.uri.path,
        ),
      ),
      child: child,
    );
  },
);

List<RouteBase> _intentionRoutes(AppRuntime container) => [
  GoRoute(
    path: 'portfolios/:portfolioId/intentions',
    redirect: (context, state) =>
        _validIntentionsPortfolioRoute(
          container,
          state.pathParameters['portfolioId'],
        )
        ? null
        : MemberRoutes.you.path,
    builder: (context, state) {
      final portfolioId = state.pathParameters['portfolioId']!;
      return IntentionsScreen(
        key: ValueKey('intentions-$portfolioId'),
        portfolioId: portfolioId,
        controller: container.intentionController,
        onOpenIntention: (intentionId) => context.push(
          MemberRoutes.portfolioIntentionLocation(portfolioId, intentionId),
        ),
      );
    },
  ),
  GoRoute(
    path: 'portfolios/:portfolioId/intentions/:intentionId',
    redirect: (context, state) =>
        _validIntentionsPortfolioRoute(
              container,
              state.pathParameters['portfolioId'],
            ) &&
            MemberRoutes.isUuid(state.pathParameters['intentionId'] ?? '')
        ? null
        : MemberRoutes.you.path,
    builder: (context, state) {
      final portfolioId = state.pathParameters['portfolioId']!;
      final intentionId = state.pathParameters['intentionId']!;
      return IntentionDetailScreen(
        key: ValueKey('intention-$portfolioId-$intentionId'),
        portfolioId: portfolioId,
        intentionId: intentionId,
        controller: container.intentionController,
        onOpenFutureMirror: () => context.push(
          MemberRoutes.futureMirrorLocation(portfolioId, intentionId),
        ),
      );
    },
  ),
  GoRoute(
    path: 'portfolios/:portfolioId/intentions/:intentionId/future-mirror',
    redirect: (context, state) =>
        _validIntentionRoute(container, state.pathParameters)
        ? null
        : MemberRoutes.you.path,
    builder: (context, state) {
      final child = FutureMirrorScreen(
        key: ValueKey(
          'future-mirror-${state.pathParameters['portfolioId']}-'
          '${state.pathParameters['intentionId']}',
        ),
        portfolioId: state.pathParameters['portfolioId']!,
        intentionId: state.pathParameters['intentionId']!,
        controller: container.futureMirrorController,
        intentionController: container.intentionController,
        portfolioController: container.portfolioController,
        onOpenRun: (runId) => context.push(
          MemberRoutes.futureMirrorRunLocation(
            state.pathParameters['portfolioId']!,
            state.pathParameters['intentionId']!,
            runId,
          ),
        ),
      );
      if (!container.hasDemoMembership) return child;
      return DemoCapabilityGate(
        key: ValueKey(
          'future-mirror-gate-${state.pathParameters['portfolioId']}-'
          '${state.pathParameters['intentionId']}',
        ),
        controller: container.entitlementController,
        capability: DemoCapability.futureMirror,
        returnLocation: state.uri.path,
        onOpenMembership: () => context.push(
          MemberRoutes.membershipLocation(
            capabilityCode: DemoCapability.futureMirror.code,
            returnLocation: state.uri.path,
          ),
        ),
        child: child,
      );
    },
  ),
  GoRoute(
    path:
        'portfolios/:portfolioId/intentions/:intentionId/future-mirror/:runId',
    redirect: (context, state) =>
        _validIntentionRoute(container, state.pathParameters) &&
            MemberRoutes.isUuid(state.pathParameters['runId'] ?? '')
        ? null
        : MemberRoutes.you.path,
    builder: (context, state) {
      final child = FutureMirrorScreen(
        key: ValueKey(
          'future-mirror-${state.pathParameters['portfolioId']}-'
          '${state.pathParameters['intentionId']}-'
          '${state.pathParameters['runId']}',
        ),
        portfolioId: state.pathParameters['portfolioId']!,
        intentionId: state.pathParameters['intentionId']!,
        initialRunId: state.pathParameters['runId']!,
        controller: container.futureMirrorController,
        intentionController: container.intentionController,
        portfolioController: container.portfolioController,
      );
      if (!container.hasDemoMembership) return child;
      return DemoCapabilityGate(
        key: ValueKey(
          'future-mirror-run-gate-${state.pathParameters['runId']}',
        ),
        controller: container.entitlementController,
        capability: DemoCapability.futureMirror,
        returnLocation: state.uri.path,
        onOpenMembership: () => context.push(
          MemberRoutes.membershipLocation(
            capabilityCode: DemoCapability.futureMirror.code,
            returnLocation: state.uri.path,
          ),
        ),
        child: child,
      );
    },
  ),
];

List<RouteBase> _simulatedInvestingRoutes(AppRuntime container) => [
  GoRoute(
    path: 'portfolios/:portfolioId/orders',
    redirect: (context, state) =>
        _validSimulatedInvestingPortfolioRoute(
          container,
          state.pathParameters['portfolioId'],
        )
        ? null
        : MemberRoutes.you.path,
    builder: (context, state) {
      final portfolioId = state.pathParameters['portfolioId']!;
      final assetId = state.uri.queryParameters['asset_id'];
      final symbol = state.uri.queryParameters['symbol'];
      return OrderScreen(
        key: ValueKey('orders-$portfolioId-${assetId ?? 'holdings'}'),
        portfolioId: portfolioId,
        controller: container.orderController,
        portfolioController: container.portfolioController,
        preselectedAssetId: assetId != null && MemberRoutes.isUuid(assetId)
            ? assetId
            : null,
        preselectedSymbol: symbol != null && symbol.trim().isNotEmpty
            ? symbol
            : null,
        onOpenOrder: (orderId) => context.push(
          MemberRoutes.portfolioOrderLocation(portfolioId, orderId),
        ),
      );
    },
  ),
  GoRoute(
    path: 'portfolios/:portfolioId/orders/:orderId',
    redirect: (context, state) =>
        _validSimulatedInvestingPortfolioRoute(
              container,
              state.pathParameters['portfolioId'],
            ) &&
            MemberRoutes.isStableId(state.pathParameters['orderId'] ?? '')
        ? null
        : MemberRoutes.you.path,
    builder: (context, state) => OrderDetailScreen(
      key: ValueKey(
        'order-${state.pathParameters['portfolioId']}-'
        '${state.pathParameters['orderId']}',
      ),
      portfolioId: state.pathParameters['portfolioId']!,
      orderId: state.pathParameters['orderId']!,
      controller: container.orderController,
    ),
  ),
  GoRoute(
    path: 'portfolios/:portfolioId/recurring',
    redirect: (context, state) =>
        _validSimulatedInvestingPortfolioRoute(
          container,
          state.pathParameters['portfolioId'],
        )
        ? null
        : MemberRoutes.you.path,
    builder: (context, state) {
      final portfolioId = state.pathParameters['portfolioId']!;
      return RecurringPlansScreen(
        key: ValueKey('recurring-$portfolioId'),
        portfolioId: portfolioId,
        controller: container.recurringPlanController,
        portfolioController: container.portfolioController,
        fundingSourceController: container.fundingSourceController,
        onOpenPlan: (planId) => context.push(
          MemberRoutes.portfolioRecurringPlanLocation(portfolioId, planId),
        ),
      );
    },
  ),
  GoRoute(
    path: 'portfolios/:portfolioId/recurring/:planId',
    redirect: (context, state) =>
        _validSimulatedInvestingPortfolioRoute(
              container,
              state.pathParameters['portfolioId'],
            ) &&
            MemberRoutes.isStableId(state.pathParameters['planId'] ?? '')
        ? null
        : MemberRoutes.you.path,
    builder: (context, state) => RecurringPlanDetailScreen(
      key: ValueKey(
        'recurring-${state.pathParameters['portfolioId']}-'
        '${state.pathParameters['planId']}',
      ),
      portfolioId: state.pathParameters['portfolioId']!,
      planId: state.pathParameters['planId']!,
      controller: container.recurringPlanController,
      portfolioController: container.portfolioController,
    ),
  ),
  GoRoute(
    path: 'portfolios/:portfolioId/rebalance',
    redirect: (context, state) =>
        _validSimulatedInvestingPortfolioRoute(
          container,
          state.pathParameters['portfolioId'],
        )
        ? null
        : MemberRoutes.you.path,
    builder: (context, state) => RebalanceScreen(
      key: ValueKey('rebalance-${state.pathParameters['portfolioId']}'),
      portfolioId: state.pathParameters['portfolioId']!,
      controller: container.rebalanceController,
      portfolioController: container.portfolioController,
    ),
  ),
];

List<RouteBase> _settingsRoutes(
  AppRuntime container,
  Future<void> Function()? onLogout,
) => [
  if (container.presentationPolicy.allowsProfileEditing) ...[
    GoRoute(
      path: 'investing',
      builder: (context, state) => InvestingProfileScreen(
        controller: container.profileController,
        onSave: container.updateMemberInvestor,
      ),
    ),
    GoRoute(
      path: 'ritual-preferences',
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
  ],
  if (onLogout != null)
    GoRoute(
      path: 'account',
      builder: (context, state) => AccountSettingsScreen(onLogout: onLogout),
    ),
  GoRoute(
    path: 'privacy',
    redirect: (context, state) =>
        container.hasPrivacyControls ? null : MemberRoutes.you.path,
    builder: (context, state) => PrivacySettingsScreen(
      controller: container.privacyController,
      onOpenDemoReset: () => context.go(MemberRoutes.youDemoResetPath),
    ),
  ),
  GoRoute(
    path: 'demo-reset',
    redirect: (context, state) =>
        container.hasPrivacyControls ? null : MemberRoutes.you.path,
    builder: (context, state) => DemoResetScreen(
      controller: container.privacyController,
      onOpenPrivacy: () => context.go(MemberRoutes.youPrivacyPath),
    ),
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
  GoRoute(
    path: 'membership',
    redirect: (context, state) =>
        container.hasDemoMembership ? null : MemberRoutes.you.path,
    builder: (context, state) {
      final capability = DemoCapability.fromCode(
        state.uri.queryParameters['capability'] ?? '',
      );
      final returnLocation = state.uri.queryParameters['return_to'];
      final validReturn =
          capability != null &&
          returnLocation != null &&
          container.entitlementController.acceptsReturnContext(
            capability,
            returnLocation,
          );
      return MembershipPlansScreen(
        controller: container.entitlementController,
        requestedCapability: validReturn ? capability : null,
        returnLocation: validReturn ? returnLocation : null,
        onOpenCheckout: (checkoutId) =>
            context.push(MemberRoutes.membershipCheckoutLocation(checkoutId)),
      );
    },
    routes: [
      GoRoute(
        path: 'checkout/:checkoutId',
        redirect: (context, state) =>
            container.hasDemoMembership &&
                MemberRoutes.isUuid(state.pathParameters['checkoutId'] ?? '')
            ? null
            : MemberRoutes.youMembershipPath,
        builder: (context, state) => DemoCheckoutScreen(
          key: ValueKey('demo-checkout-${state.pathParameters['checkoutId']}'),
          sessionId: state.pathParameters['checkoutId']!,
          controller: container.entitlementController,
          onReceipt: () => context.pushReplacement(
            MemberRoutes.membershipReceiptLocation(
              state.pathParameters['checkoutId']!,
            ),
          ),
          onCancel: () => context.go(MemberRoutes.youMembershipPath),
        ),
        routes: [
          GoRoute(
            path: 'receipt',
            redirect: (context, state) =>
                container.hasDemoMembership &&
                    MemberRoutes.isUuid(
                      state.pathParameters['checkoutId'] ?? '',
                    )
                ? null
                : MemberRoutes.youMembershipPath,
            builder: (context, state) => DemoMembershipReceiptScreen(
              key: ValueKey(
                'demo-receipt-${state.pathParameters['checkoutId']}',
              ),
              sessionId: state.pathParameters['checkoutId']!,
              controller: container.entitlementController,
              onContinue: context.go,
              onBackToMembership: () =>
                  context.go(MemberRoutes.youMembershipPath),
            ),
          ),
        ],
      ),
    ],
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
    portfolioController: widget.container.portfolioController,
    onOpenInvesting: widget.container.presentationPolicy.allowsProfileEditing
        ? () => context.push(MemberRoutes.youInvestingPath)
        : null,
    onOpenRitualPreferences:
        widget.container.presentationPolicy.allowsProfileEditing
        ? () => context.push(MemberRoutes.youRitualPreferencesPath)
        : null,
    onOpenAstrology: widget.container.presentationPolicy.allowsProfileEditing
        ? () => context.push(MemberRoutes.youAstrologyPath)
        : null,
    onOpenPolicies: widget.container.presentationPolicy.allowsProfileEditing
        ? () => context.push(MemberRoutes.youPoliciesPath)
        : null,
    onOpenAccount: widget.showAccount
        ? () => context.push(MemberRoutes.youAccountPath)
        : null,
    onOpenNotifications: widget.container.hasBriefingsAndNotifications
        ? () => context.push(MemberRoutes.youNotificationsPath)
        : null,
    onOpenMembership: widget.container.hasDemoMembership
        ? () => context.push(MemberRoutes.youMembershipPath)
        : null,
    onOpenPrivacy: widget.container.hasPrivacyControls
        ? () => context.push(MemberRoutes.youPrivacyPath)
        : null,
    onOpenDemoReset: widget.container.hasPrivacyControls
        ? () => context.push(MemberRoutes.youDemoResetPath)
        : null,
    onOpenPortfolio: (id) => context.push(MemberRoutes.portfolio.location(id)),
  );
}

bool _validSimulatedInvestingPortfolioRoute(
  AppRuntime container,
  String? portfolioId,
) =>
    container.hasSimulatedInvesting &&
    portfolioId != null &&
    MemberRoutes.isStableId(portfolioId);

bool _validIntentionsPortfolioRoute(
  AppRuntime container,
  String? portfolioId,
) =>
    container.hasIntentionsAndFutureMirror &&
    portfolioId != null &&
    MemberRoutes.isStableId(portfolioId);

bool _validIntentionRoute(
  AppRuntime container,
  Map<String, String> parameters,
) =>
    _validIntentionsPortfolioRoute(container, parameters['portfolioId']) &&
    MemberRoutes.isUuid(parameters['intentionId'] ?? '');
