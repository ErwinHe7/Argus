import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/coven/presentation/coven_screen.dart';
import '../../features/asset_codex/application/controller.dart';
import '../../features/asset_codex/domain/model.dart';
import '../../features/asset_codex/presentation/asset_codex_screen.dart';
import '../../features/discover/presentation/discover_screen.dart';
import '../../features/onboarding/application/onboarding_controller.dart';
import '../../features/onboarding/presentation/onboarding_flow.dart';
import '../../features/profile/presentation/profile_screen.dart';
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
      if (stableId == null ||
          !MemberRoutes.isStableId(stableId) ||
          (definition == MemberRoutes.discoverAsset &&
              !MemberRoutes.isUuid(stableId)) ||
          ((definition != MemberRoutes.discoverAsset ||
                  !container.hasAssetCodex) &&
              !access(definition, stableId))) {
        return MemberRoutes.rootFor(definition.branch).path;
      }
      return null;
    },
    builder: (context, state) {
      if (definition == MemberRoutes.discoverAsset && container.hasAssetCodex) {
        return _AssetCodexRoute(
          container: container,
          assetId: state.pathParameters['stableId']!,
          source: _assetSource(state.uri.queryParameters),
        );
      }
      return _MemberResourceScreen(route: definition);
    },
  );

  StatefulShellBranch branch(
    MemberRouteDefinition root,
    MemberRouteDefinition detail,
  ) {
    final childRoutes = <RouteBase>[resourceRoute(detail)];
    if (root.branch == MemberBranch.you) {
      childRoutes.addAll([
        GoRoute(
          path: 'investing',
          builder: (context, state) =>
              InvestingProfileScreen(controller: container.profileController),
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
      ]);
    }
    if (root.branch == MemberBranch.discover) {
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
    MemberBranch.ritual => DailyRitualScreen(
      controller: widget.container.dailyRitualController,
      onOpenCoven: () => context.go(MemberRoutes.coven.path),
      onToggleTheme: () => context.go(MemberRoutes.youRitualPreferencesPath),
      onOpenSearch: widget.container.optionalSearchController == null
          ? null
          : () => context.push(MemberRoutes.discoverSearchPath),
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
    ),
    MemberBranch.discover => DiscoverScreen(
      controller: widget.container.discoverController,
    ),
    MemberBranch.coven => CovenScreen(
      controller: widget.container.covenController,
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
      onOpenPortfolio: (id) =>
          context.push(MemberRoutes.portfolio.location(id)),
    ),
  };
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
