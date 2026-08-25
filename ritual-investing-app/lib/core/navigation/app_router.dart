import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/coven/presentation/coven_screen.dart';
import '../../features/briefings/presentation/briefing_screen.dart';
import '../../features/coven/application/controller.dart';
import '../../features/coven/presentation/coven_detail_screen.dart';
import '../../features/circles/application/controller.dart';
import '../../features/circles/domain/model.dart';
import '../../features/circles/presentation/circle_template_screen.dart';
import '../../features/circles/presentation/private_circle_detail_screen.dart';
import '../../features/circles/presentation/private_circles_screen.dart';
import '../../features/creators/application/controller.dart';
import '../../features/creators/presentation/creator_detail_screen.dart';
import '../../features/asset_codex/application/controller.dart';
import '../../features/asset_codex/domain/model.dart';
import '../../features/asset_codex/presentation/asset_codex_screen.dart';
import '../../features/discover/presentation/discover_screen.dart';
import '../../features/discover/domain/model.dart';
import '../../features/entitlements/domain/model.dart';
import '../../features/entitlements/presentation/demo_membership_screen.dart';
import '../../features/future_mirror/presentation/future_mirror_screen.dart';
import '../../features/grimoires/application/controller.dart';
import '../../features/grimoires/presentation/grimoire_detail_screen.dart';
import '../../features/intentions/presentation/intention_screen.dart';
import '../../features/onboarding/application/onboarding_controller.dart';
import '../../features/onboarding/presentation/onboarding_flow.dart';
import '../../features/notifications/presentation/notification_screen.dart';
import '../../features/orders/presentation/order_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/portfolio/presentation/portfolio_screen.dart';
import '../../features/rebalancing/presentation/rebalance_screen.dart';
import '../../features/recurring/presentation/recurring_plan_screen.dart';
import '../../features/ritual/presentation/daily_ritual_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/shell/presentation/app_shell.dart';
import '../bootstrap/dependency_container.dart';
import '../bootstrap/entry_coordinator.dart';
import '../bootstrap/member_bootstrap.dart';
import 'member_routes.dart';

GoRouter createAppRouter({
  required DependencyContainer container,
  MemberResourceAccess? resourceAccess,
}) {
  final access = resourceAccess ?? (_, _) => false;

  GoRoute resourceRoute(MemberRouteDefinition definition) => GoRoute(
    path: definition.relativeResourcePath!,
    name: definition.name,
    redirect: (context, state) {
      final stableId = state.pathParameters['stableId'];
      final requiresUuid =
          definition == MemberRoutes.discoverAsset ||
          definition == MemberRoutes.discoverGrimoire ||
          definition == MemberRoutes.discoverCircleTemplate ||
          definition == MemberRoutes.discoverCreator ||
          definition == MemberRoutes.discoverCircle ||
          definition == MemberRoutes.covenEntry;
      final available = switch (definition) {
        MemberRoutes.discoverAsset => container.hasAssetCodex,
        MemberRoutes.discoverGrimoire ||
        MemberRoutes.discoverCircleTemplate ||
        MemberRoutes.discoverCreator ||
        MemberRoutes.discoverCircle ||
        MemberRoutes.covenEntry => container.hasU5Research,
        MemberRoutes.portfolio => true,
        _ => false,
      };
      if (stableId == null ||
          !MemberRoutes.isStableId(stableId) ||
          (requiresUuid && !MemberRoutes.isUuid(stableId)) ||
          (!available && !access(definition, stableId))) {
        return MemberRoutes.rootFor(definition.branch).path;
      }
      return null;
    },
    builder: (context, state) {
      final stableId = state.pathParameters['stableId']!;
      if (definition == MemberRoutes.discoverAsset && container.hasAssetCodex) {
        final source = _assetSource(state.uri.queryParameters);
        return _AssetCodexRoute(
          key: ValueKey(
            'asset-codex-$stableId-${source.kind.name}-'
            '${source.resourceId ?? 'none'}',
          ),
          container: container,
          assetId: stableId,
          source: source,
        );
      }
      if (definition == MemberRoutes.portfolio) {
        final child = PortfolioScreen(
          key: ValueKey('portfolio-$stableId'),
          portfolioId: stableId,
          portfolioController: container.portfolioController,
          fundingSourceController: container.fundingSourceController,
          contributionController: container.contributionController,
          onOpenPortfolio: (id) =>
              context.pushReplacement(MemberRoutes.portfolio.location(id)),
          onOpenAsset: container.hasAssetCodex
              ? (id) => context.push(
                  MemberRoutes.assetLocation(id, sourceKind: 'direct'),
                )
              : null,
          onOpenOrders: container.hasU7
              ? () =>
                    context.push(MemberRoutes.portfolioOrdersLocation(stableId))
              : null,
          onOpenRecurringPlans: container.hasU7
              ? () => context.push(
                  MemberRoutes.portfolioRecurringLocation(stableId),
                )
              : null,
          onOpenRebalance: container.hasU7
              ? () => context.push(
                  MemberRoutes.portfolioRebalanceLocation(stableId),
                )
              : null,
          onOpenIntentions: container.hasU8
              ? () => context.push(
                  MemberRoutes.portfolioIntentionsLocation(stableId),
                )
              : null,
        );
        if (!container.hasU10) return child;
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
      }
      if (container.hasU5Research) {
        if (definition == MemberRoutes.covenEntry) {
          return _CovenDetailRoute(
            key: ValueKey('coven-detail-$stableId'),
            container: container,
            entryId: stableId,
          );
        }
        if (definition == MemberRoutes.discoverGrimoire) {
          return _GrimoireRoute(
            key: ValueKey('grimoire-detail-$stableId'),
            container: container,
            grimoireId: stableId,
          );
        }
        if (definition == MemberRoutes.discoverCircleTemplate) {
          return _CircleTemplateRoute(
            key: ValueKey('circle-template-detail-$stableId'),
            container: container,
            templateId: stableId,
          );
        }
        if (definition == MemberRoutes.discoverCreator) {
          return _CreatorRoute(
            key: ValueKey('creator-detail-$stableId'),
            container: container,
            creatorId: stableId,
          );
        }
        if (definition == MemberRoutes.discoverCircle) {
          return _PrivateCircleRoute(
            key: ValueKey('private-circle-detail-$stableId'),
            container: container,
            circleId: stableId,
          );
        }
      }
      return _MemberResourceScreen(route: definition);
    },
  );

  StatefulShellBranch branch(
    MemberRouteDefinition root,
    MemberRouteDefinition detail,
  ) {
    final childRoutes = <RouteBase>[resourceRoute(detail)];
    if (root.branch == MemberBranch.ritual) {
      childRoutes.addAll([
        GoRoute(
          path: 'briefings',
          redirect: (context, state) =>
              container.hasU9 ? null : MemberRoutes.ritual.path,
          builder: (context, state) => BriefingsScreen(
            controller: container.briefingController,
            onOpenBriefing: (briefingId) =>
                context.push(MemberRoutes.briefingLocation(briefingId)),
          ),
        ),
        GoRoute(
          path: 'briefings/:briefingId',
          redirect: (context, state) =>
              container.hasU9 &&
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
      ]);
    }
    if (root.branch == MemberBranch.you) {
      childRoutes.addAll([
        GoRoute(
          path: 'portfolios/:portfolioId/intentions',
          redirect: (context, state) =>
              _validU8PortfolioRoute(
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
                MemberRoutes.portfolioIntentionLocation(
                  portfolioId,
                  intentionId,
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: 'portfolios/:portfolioId/intentions/:intentionId',
          redirect: (context, state) =>
              _validU8PortfolioRoute(
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
              _validU8IntentionRoute(container, state.pathParameters)
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
            if (!container.hasU10) return child;
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
          path: 'portfolios/:portfolioId/intentions/:intentionId/future-mirror/:runId',
          redirect: (context, state) =>
              _validU8IntentionRoute(container, state.pathParameters) &&
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
            if (!container.hasU10) return child;
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
        GoRoute(
          path: 'portfolios/:portfolioId/orders',
          redirect: (context, state) =>
              _validU7PortfolioRoute(
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
              preselectedAssetId:
                  assetId != null && MemberRoutes.isUuid(assetId)
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
              _validU7PortfolioRoute(
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
              _validU7PortfolioRoute(
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
                MemberRoutes.portfolioRecurringPlanLocation(
                  portfolioId,
                  planId,
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: 'portfolios/:portfolioId/recurring/:planId',
          redirect: (context, state) =>
              _validU7PortfolioRoute(
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
              _validU7PortfolioRoute(
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
        GoRoute(
          path: 'account',
          builder: (context, state) =>
              AccountSettingsScreen(onLogout: container.logout),
        ),
        GoRoute(
          path: 'notifications',
          redirect: (context, state) =>
              container.hasU9 ? null : MemberRoutes.you.path,
          builder: (context, state) => NotificationsScreen(
            controller: container.notificationController,
            onOpenDestination: (destination) =>
                context.push(destination.location),
            onOpenPreferences: () =>
                context.push(MemberRoutes.youNotificationPreferencesPath),
          ),
        ),
        GoRoute(
          path: 'notification-preferences',
          redirect: (context, state) =>
              container.hasU9 ? null : MemberRoutes.you.path,
          builder: (context, state) => NotificationPreferencesScreen(
            controller: container.notificationController,
          ),
        ),
        GoRoute(
          path: 'membership',
          redirect: (context, state) =>
              container.hasU10 ? null : MemberRoutes.you.path,
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
              onOpenCheckout: (checkoutId) => context.push(
                MemberRoutes.membershipCheckoutLocation(checkoutId),
              ),
            );
          },
          routes: [
            GoRoute(
              path: 'checkout/:checkoutId',
              redirect: (context, state) =>
                  container.hasU10 &&
                      MemberRoutes.isUuid(
                        state.pathParameters['checkoutId'] ?? '',
                      )
                  ? null
                  : MemberRoutes.youMembershipPath,
              builder: (context, state) => DemoCheckoutScreen(
                key: ValueKey(
                  'demo-checkout-${state.pathParameters['checkoutId']}',
                ),
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
                      container.hasU10 &&
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
      ]);
    }
    if (root.branch == MemberBranch.discover) {
      childRoutes.addAll([
        resourceRoute(MemberRoutes.discoverGrimoire),
        resourceRoute(MemberRoutes.discoverCircleTemplate),
        resourceRoute(MemberRoutes.discoverCreator),
        resourceRoute(MemberRoutes.discoverCircle),
      ]);
      childRoutes.add(
        GoRoute(
          path: 'circles',
          name: 'discover-private-circles',
          redirect: (context, state) =>
              container.hasU5Research ? null : MemberRoutes.discover.path,
          builder: (context, state) =>
              _PrivateCirclesRoute(container: container),
        ),
      );
      final searchController = container.optionalSearchController;
      if (searchController != null) {
        childRoutes.add(
          GoRoute(
            path: 'search',
            builder: (context, state) => SearchScreen(
              controller: searchController,
              onOpenAsset: (id) => context.push(
                MemberRoutes.assetLocation(id, sourceKind: 'search'),
              ),
            ),
          ),
        );
      }
    }
    return StatefulShellBranch(
      restorationScopeId: '${root.name}-branch',
      routes: [
        GoRoute(
          path: root.path,
          name: root.name,
          builder: (context, state) => _LazyMemberBranch(
            key: ValueKey(root.name),
            branch: root.branch,
            container: container,
          ),
          routes: childRoutes,
        ),
      ],
    );
  }

  return GoRouter(
    initialLocation: container.entryCoordinator == null ? '/entry' : '/welcome',
    restorationScopeId: 'ritual-investing-router',
    refreshListenable: container,
    redirect: (context, state) {
      final coordinator = container.entryCoordinator;
      if (coordinator != null) {
        final path = state.uri.path;
        final isOnboarding = path.startsWith('/onboarding/');
        final stepName = path.startsWith('/onboarding/')
            ? path.substring('/onboarding/'.length)
            : null;
        final isQuestionnaire =
            _questionStep(stepName) != null || path == '/onboarding/review';
        final isEntry = path == '/welcome' || path == '/entry' || isOnboarding;
        return switch (coordinator.state.destination) {
          EntryDestination.restoring ||
          EntryDestination.finalizing => path == '/entry' ? null : '/entry',
          EntryDestination.welcome => path == '/welcome' ? null : '/welcome',
          EntryDestination.questionnaire =>
            isQuestionnaire ? null : '/onboarding/experience',
          EntryDestination.review =>
            path == '/onboarding/review' ? null : '/onboarding/review',
          EntryDestination.reconcile =>
            path == '/onboarding/reconcile' ? null : '/onboarding/reconcile',
          EntryDestination.authenticatedRecovery =>
            path == '/onboarding/recovery' ? null : '/onboarding/recovery',
          EntryDestination.entitlementBlocked ||
          EntryDestination.failure => path == '/entry' ? null : '/entry',
          EntryDestination.shell =>
            isEntry || path == '/' ? MemberRoutes.ritual.path : null,
        };
      }
      final atEntry = state.uri.path == '/entry';
      if (container.entryGate != MemberEntryGate.member) {
        return atEntry ? null : '/entry';
      }
      return atEntry || state.uri.path == '/' ? MemberRoutes.ritual.path : null;
    },
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (context, state) => WelcomeScreen(
          onGetStarted: () =>
              _runUiAction(context, container.beginQuestionnaire),
          onSignIn: () => _runUiAction(context, container.login),
        ),
      ),
      GoRoute(
        path: '/onboarding/review',
        builder: (context, state) => OnboardingReviewScreen(
          controller: container.onboardingController,
          onEdit: (step) => context.push('/onboarding/${step.name}'),
          onBack: () {
            final previous =
                container.onboardingController.draft.astrologyEnabled == true
                ? OnboardingStep.birthDate
                : OnboardingStep.astrologyOptIn;
            container.onboardingController.goTo(previous);
            context.go('/onboarding/${previous.name}');
          },
          onCreateAccount: () => _runUiAction(context, container.createAccount),
          onDraftChanged: (draft) => _runUiAction(
            context,
            () => container.persistOnboardingDraft(draft),
          ),
          persistenceMessage: container.entryCoordinator?.state.message,
          onRetryPersistence: () => _runUiAction(
            context,
            () => container.persistOnboardingDraft(
              container.onboardingController.draft,
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/onboarding/reconcile',
        builder: (context, state) => _OnboardingReconcile(container: container),
      ),
      GoRoute(
        path: '/onboarding/recovery',
        builder: (context, state) =>
            _AuthenticatedOnboardingRecovery(container: container),
      ),
      GoRoute(
        path: '/onboarding/:step',
        redirect: (context, state) =>
            _questionStep(state.pathParameters['step']) == null
            ? '/welcome'
            : null,
        builder: (context, state) {
          final step = _questionStep(state.pathParameters['step'])!;
          return OnboardingFlow(
            controller: container.onboardingController,
            step: step,
            onContinue: (next) {
              container.onboardingController.goTo(next);
              _runUiAction(
                context,
                () => container.persistOnboardingDraft(
                  container.onboardingController.draft,
                ),
              );
              context.push('/onboarding/${next.name}');
            },
            onBack: (previous) {
              container.onboardingController.goTo(previous);
              if (previous == OnboardingStep.welcome) {
                context.go('/welcome');
              } else if (context.canPop()) {
                context.pop();
              } else {
                context.go('/onboarding/${previous.name}');
              }
            },
            onDraftChanged: (draft) => _runUiAction(
              context,
              () => container.persistOnboardingDraft(draft),
            ),
            persistenceMessage: container.entryCoordinator?.state.message,
            onRetryPersistence: () => _runUiAction(
              context,
              () => container.persistOnboardingDraft(
                container.onboardingController.draft,
              ),
            ),
          );
        },
      ),
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

void _runUiAction(BuildContext context, Future<void> Function() action) {
  unawaited(() async {
    try {
      await action();
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('That action could not finish. Please retry.'),
        ),
      );
    }
  }());
}

OnboardingStep? _questionStep(String? value) {
  if (value == null) return null;
  for (final step in OnboardingStep.values) {
    if (step.name == value &&
        step != OnboardingStep.welcome &&
        step != OnboardingStep.review) {
      return step;
    }
  }
  return null;
}

class _OnboardingReconcile extends StatelessWidget {
  const _OnboardingReconcile({required this.container});

  final DependencyContainer container;

  @override
  Widget build(BuildContext context) {
    final state = container.entryCoordinator!.state;
    return Scaffold(
      appBar: AppBar(title: const Text('Finish your setup')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Use these reviewed answers?',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              state.message ?? 'This account is incomplete. Confirm before attaching the private draft saved on this device.',
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('reconcile-attach'),
              onPressed: () =>
                  _runUiAction(context, container.attachOnboardingDraft),
              child: Text(state.canRetry ? 'Retry' : 'Use these answers'),
            ),
            TextButton(
              key: const Key('reconcile-discard'),
              onPressed: () => _runUiAction(
                context,
                container.entryCoordinator!.discardDraft,
              ),
              child: const Text('Discard this draft'),
            ),
            TextButton(
              onPressed: () => _runUiAction(context, container.logout),
              child: const Text('Log out'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthenticatedOnboardingRecovery extends StatelessWidget {
  const _AuthenticatedOnboardingRecovery({required this.container});

  final DependencyContainer container;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Continue your setup')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Your account setup is incomplete.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          const Text(
            'Continue from the first missing section. The member app stays locked until the server confirms completion.',
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('recovery-continue'),
            onPressed: () =>
                _runUiAction(context, container.beginQuestionnaire),
            child: const Text('Continue setup'),
          ),
          TextButton(
            onPressed: () => _runUiAction(context, container.logout),
            child: const Text('Log out'),
          ),
        ],
      ),
    ),
  );
}

class _LazyMemberBranch extends StatefulWidget {
  const _LazyMemberBranch({
    super.key,
    required this.branch,
    required this.container,
  });

  final MemberBranch branch;
  final DependencyContainer container;

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
    MemberBranch.ritual => _buildRitual(context),
    MemberBranch.discover => DiscoverScreen(
      controller: widget.container.discoverController,
      onOpenSearch: widget.container.optionalSearchController == null
          ? null
          : () => context.push(MemberRoutes.discoverSearchPath),
      onOpenItem: (item) => _openDiscoverItem(context, item),
      onOpenCreator: (creator) =>
          context.push(MemberRoutes.discoverCreator.location(creator.id)),
      onOpenPrivateCircles: () =>
          context.push(MemberRoutes.discoverCirclesPath),
    ),
    MemberBranch.coven => CovenScreen(
      controller: widget.container.covenController,
      onOpenEntry: (id) => context.push(MemberRoutes.covenEntry.location(id)),
    ),
    MemberBranch.you => ProfileScreen(
      controller: widget.container.profileController,
      portfolioController: widget.container.portfolioController,
      onOpenInvesting: () => context.push(MemberRoutes.youInvestingPath),
      onOpenRitualPreferences: () =>
          context.push(MemberRoutes.youRitualPreferencesPath),
      onOpenAstrology: () => context.push(MemberRoutes.youAstrologyPath),
      onOpenPolicies: () => context.push(MemberRoutes.youPoliciesPath),
      onOpenAccount: () => context.push(MemberRoutes.youAccountPath),
      onOpenNotifications: widget.container.hasU9
          ? () => context.push(MemberRoutes.youNotificationsPath)
          : null,
      onOpenMembership: widget.container.hasU10
          ? () => context.push(MemberRoutes.youMembershipPath)
          : null,
      onOpenPortfolio: (id) =>
          context.push(MemberRoutes.portfolio.location(id)),
    ),
  };

  Widget _buildRitual(BuildContext context) {
    final child = DailyRitualScreen(
      controller: widget.container.dailyRitualController,
      onOpenCoven: () => context.go(MemberRoutes.coven.path),
      onToggleTheme: () => context.go(MemberRoutes.youRitualPreferencesPath),
      onOpenSearch: widget.container.optionalSearchController == null
          ? null
          : () => context.push(MemberRoutes.discoverSearchPath),
      onOpenBriefings: widget.container.hasU9
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
    );
    if (!widget.container.hasU10) return child;
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

void _openDiscoverItem(BuildContext context, DiscoverItemView item) {
  final location = switch (item.kind) {
    DiscoverItemKind.asset => MemberRoutes.assetLocation(
      item.id,
      sourceKind: 'discover',
      sourceId: item.id,
    ),
    DiscoverItemKind.grimoire => MemberRoutes.discoverGrimoire.location(
      item.id,
    ),
    DiscoverItemKind.circleTemplate =>
      MemberRoutes.discoverCircleTemplate.location(item.id),
    DiscoverItemKind.coven => MemberRoutes.covenEntry.location(item.id),
  };
  context.push(location);
}

AssetSourceContext _assetSource(Map<String, String> query) {
  final kind = switch (query['source']) {
    'ritual' => AssetSourceKind.ritual,
    'circle' => AssetSourceKind.circle,
    'discover' => AssetSourceKind.discover,
    'search' => AssetSourceKind.search,
    _ => AssetSourceKind.direct,
  };
  final sourceId = query['source_id'];
  return AssetSourceContext(
    kind: kind,
    resourceId: sourceId != null && MemberRoutes.isUuid(sourceId)
        ? sourceId
        : null,
  );
}

class _AssetCodexRoute extends StatefulWidget {
  const _AssetCodexRoute({
    super.key,
    required this.container,
    required this.assetId,
    required this.source,
  });

  final DependencyContainer container;
  final String assetId;
  final AssetSourceContext source;

  @override
  State<_AssetCodexRoute> createState() => _AssetCodexRouteState();
}

class _AssetCodexRouteState extends State<_AssetCodexRoute> {
  late final AssetCodexController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.container.createAssetCodexController(
      assetId: widget.assetId,
      source: widget.source,
    );
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AssetCodexScreen(
    controller: _controller,
    rowanController: widget.container.optionalRowanController,
    personalization:
        widget.container.memberBootstrap?.personalization ??
        const MemberPersonalization(),
    searchController: widget.container.optionalSearchController,
    onPreviewDemoOrder: widget.container.hasU7
        ? (assetId, symbol) {
            final portfolioId =
                widget.container.memberBootstrap?.defaultPortfolioId;
            if (portfolioId == null) return;
            context.push(
              MemberRoutes.portfolioOrdersLocation(
                portfolioId,
                assetId: assetId,
                symbol: symbol,
              ),
            );
          }
        : null,
  );
}

bool _validU7PortfolioRoute(
  DependencyContainer container,
  String? portfolioId,
) =>
    container.hasU7 &&
    portfolioId != null &&
    MemberRoutes.isStableId(portfolioId);

bool _validU8PortfolioRoute(
  DependencyContainer container,
  String? portfolioId,
) =>
    container.hasU8 &&
    portfolioId != null &&
    MemberRoutes.isStableId(portfolioId);

bool _validU8IntentionRoute(
  DependencyContainer container,
  Map<String, String> parameters,
) =>
    _validU8PortfolioRoute(container, parameters['portfolioId']) &&
    MemberRoutes.isUuid(parameters['intentionId'] ?? '');

class _CovenDetailRoute extends StatefulWidget {
  const _CovenDetailRoute({
    super.key,
    required this.container,
    required this.entryId,
  });

  final DependencyContainer container;
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

class _GrimoireRoute extends StatefulWidget {
  const _GrimoireRoute({
    super.key,
    required this.container,
    required this.grimoireId,
  });

  final DependencyContainer container;
  final String grimoireId;

  @override
  State<_GrimoireRoute> createState() => _GrimoireRouteState();
}

class _GrimoireRouteState extends State<_GrimoireRoute> {
  late final GrimoireController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.container.createGrimoireController(widget.grimoireId);
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GrimoireDetailScreen(
    controller: _controller,
    onOpenAsset: (id) => context.push(
      MemberRoutes.assetLocation(
        id,
        sourceKind: 'discover',
        sourceId: widget.grimoireId,
      ),
    ),
  );
}

class _CircleTemplateRoute extends StatefulWidget {
  const _CircleTemplateRoute({
    super.key,
    required this.container,
    required this.templateId,
  });

  final DependencyContainer container;
  final String templateId;

  @override
  State<_CircleTemplateRoute> createState() => _CircleTemplateRouteState();
}

class _CircleTemplateRouteState extends State<_CircleTemplateRoute> {
  late final CircleTemplateController _controller;
  late final CircleListController _copyController;

  @override
  void initState() {
    super.initState();
    _controller = widget.container.createCircleTemplateController(
      widget.templateId,
    );
    _copyController = widget.container.createCircleListController();
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _controller.dispose();
    _copyController.dispose();
    super.dispose();
  }

  Future<void> _copy() async {
    await _copyController.copyTemplate(widget.templateId);
    _openCreated();
  }

  Future<void> _retryCopy() async {
    await _copyController.retryPending();
    _openCreated();
  }

  void _openCreated() {
    final created = _copyController.lastCreated;
    if (!mounted ||
        created == null ||
        _copyController.mutationPhase != CircleMutationPhase.committed) {
      return;
    }
    context.push(MemberRoutes.discoverCircle.location(created.id));
  }

  @override
  Widget build(BuildContext context) => CircleTemplateScreen(
    controller: _controller,
    copyController: _copyController,
    onRetryCopy: () => unawaited(_retryCopy()),
    onOpenAsset: (id) => context.push(
      MemberRoutes.assetLocation(
        id,
        sourceKind: 'discover',
        sourceId: widget.templateId,
      ),
    ),
    onOpenCreator: (creator) =>
        context.push(MemberRoutes.discoverCreator.location(creator.id)),
    onCopy: (_) => unawaited(_copy()),
  );
}

class _CreatorRoute extends StatefulWidget {
  const _CreatorRoute({
    super.key,
    required this.container,
    required this.creatorId,
  });

  final DependencyContainer container;
  final String creatorId;

  @override
  State<_CreatorRoute> createState() => _CreatorRouteState();
}

class _CreatorRouteState extends State<_CreatorRoute> {
  late final CreatorController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.container.createCreatorController(widget.creatorId);
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      CreatorDetailScreen(controller: _controller);
}

class _PrivateCirclesRoute extends StatefulWidget {
  const _PrivateCirclesRoute({required this.container});

  final DependencyContainer container;

  @override
  State<_PrivateCirclesRoute> createState() => _PrivateCirclesRouteState();
}

class _PrivateCirclesRouteState extends State<_PrivateCirclesRoute> {
  late final CircleListController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.container.createCircleListController();
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PrivateCirclesScreen(
    controller: _controller,
    onOpenCircle: (id) =>
        context.push(MemberRoutes.discoverCircle.location(id)),
  );
}

class _PrivateCircleRoute extends StatefulWidget {
  const _PrivateCircleRoute({
    super.key,
    required this.container,
    required this.circleId,
  });

  final DependencyContainer container;
  final String circleId;

  @override
  State<_PrivateCircleRoute> createState() => _PrivateCircleRouteState();
}

class _PrivateCircleRouteState extends State<_PrivateCircleRoute> {
  late final CircleDetailController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.container.createCircleDetailController(
      widget.circleId,
    );
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PrivateCircleDetailScreen(
    controller: _controller,
    onOpenAsset: (id) => context.push(
      MemberRoutes.assetLocation(
        id,
        sourceKind: 'circle',
        sourceId: widget.circleId,
      ),
    ),
  );
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
    final entryState = container.entryCoordinator?.state;
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
        entryState?.message ??
            state.message ??
            'Sign-in is temporarily unavailable.',
        'Retry',
        container.retryEntryAction,
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
                  TextButton(
                    onPressed: () => _runUiAction(context, action),
                    child: Text(actionLabel!),
                  ),
                if (secondaryAction != null)
                  TextButton(
                    onPressed: () => _runUiAction(context, secondaryAction),
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
