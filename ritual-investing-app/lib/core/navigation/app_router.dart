import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/member_sign_in_screen.dart';
import '../../features/onboarding/application/onboarding_controller.dart';
import '../../features/onboarding/presentation/onboarding_flow.dart';
import '../auth/auth_controller.dart';
import '../bootstrap/dependency_container.dart';
import '../bootstrap/entry_coordinator.dart';
import 'member_app_router.dart';
import 'member_routes.dart';

GoRouter createAppRouter({
  required DependencyContainer container,
  MemberResourceAccess? resourceAccess,
  bool allowSelfServiceSignup = true,
  String? initialLocation,
  String? Function()? readPendingMemberPath,
  void Function(String?)? writePendingMemberPath,
}) {
  final access = resourceAccess ?? (_, _) => false;
  final navigation = MemberNavigationPolicy.fromBootstrap(
    container.memberBootstrap,
  );
  String? pendingMemberPath;
  String? readPendingPath() => readPendingMemberPath != null
      ? readPendingMemberPath()
      : pendingMemberPath;
  void writePendingPath(String? value) {
    if (writePendingMemberPath != null) {
      writePendingMemberPath(value);
    } else {
      pendingMemberPath = value;
    }
  }

  return GoRouter(
    initialLocation:
        initialLocation ??
        (kIsWeb
            ? null
            : container.entryCoordinator == null
            ? '/entry'
            : '/welcome'),
    restorationScopeId: 'ritual-investing-router',
    refreshListenable: container,
    errorBuilder: (context, state) => const _NotFoundScreen(),
    redirect: (context, state) {
      final path = state.uri.path;
      final coordinator = container.entryCoordinator;
      if (_legacyPasswordAuthPaths.contains(path)) {
        if (container.authController.state.phase != AuthPhase.signedIn) {
          return '/sign-in';
        }
        return switch (coordinator?.state.destination) {
          EntryDestination.questionnaire => '/onboarding/experience',
          EntryDestination.review => '/onboarding/review',
          _ => MemberRoutes.ritual.path,
        };
      }
      if (coordinator != null) {
        final isOnboarding = path.startsWith('/onboarding/');
        final stepName = path.startsWith('/onboarding/')
            ? path.substring('/onboarding/'.length)
            : null;
        final isQuestionnaire =
            _questionStep(stepName) != null || path == '/onboarding/review';
        final isAuthenticated =
            container.authController.state.phase == AuthPhase.signedIn;
        final isEntry =
            path == '/welcome' ||
            path == '/sign-in' ||
            path == '/mobile/argus-auth/callback' ||
            path == '/entry' ||
            isOnboarding;
        final safeMemberPath = _safePendingMemberPath(state.uri);
        if (!isAuthenticated && !isEntry && safeMemberPath != null) {
          writePendingPath(safeMemberPath);
        }
        return switch (coordinator.state.destination) {
          EntryDestination.restoring ||
          EntryDestination.finalizing => path == '/entry' ? null : '/entry',
          EntryDestination.welcome =>
            path == '/welcome' || path == '/sign-in' ? null : '/welcome',
          EntryDestination.questionnaire =>
            isQuestionnaire || path == '/sign-in'
                ? null
                : '/onboarding/experience',
          EntryDestination.review =>
            path == '/onboarding/review' || path == '/sign-in'
                ? null
                : '/onboarding/review',
          EntryDestination.reconcile =>
            path == '/onboarding/reconcile' ? null : '/onboarding/reconcile',
          EntryDestination.authenticatedRecovery =>
            path == '/onboarding/recovery' ? null : '/onboarding/recovery',
          EntryDestination.failure => path == '/entry' ? null : '/entry',
          EntryDestination.shell =>
            isEntry || path == '/'
                ? _restoreMemberPath(
                    navigation,
                    MemberNavigationPolicy.fromBootstrap(
                      container.memberBootstrap,
                    ),
                    readPendingPath,
                    () => writePendingPath(null),
                  )
                : navigation.redirectFor(path),
        };
      }
      final atEntry =
          state.uri.path == '/entry' || state.uri.path == '/sign-in';
      if (container.entryGate != MemberEntryGate.member) {
        if (container.entryGate == MemberEntryGate.signedOut &&
            state.uri.path == '/sign-in') {
          return null;
        }
        return atEntry ? null : '/entry';
      }
      if (atEntry || state.uri.path == '/') return MemberRoutes.ritual.path;
      return navigation.redirectFor(state.uri.path);
    },
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (context, state) => ListenableBuilder(
          listenable: container,
          builder: (context, _) => WelcomeScreen(
            message:
                container.entryCoordinator?.state.message ??
                container.authController.state.message,
            onContinueWithGoogle: container.signInWithGoogle,
          ),
        ),
      ),
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => MemberSignInScreen(
          message:
              container.entryCoordinator?.state.message ??
              container.authController.state.message,
          onContinueWithGoogle: container.signInWithGoogle,
        ),
      ),
      GoRoute(
        path: '/mobile/argus-auth/callback',
        builder: (context, state) => const _OAuthCallbackScreen(),
      ),
      GoRoute(
        path: '/onboarding/review',
        builder: (context, state) => OnboardingReviewScreen(
          controller: container.onboardingController,
          onEdit: (step) {
            container.entryCoordinator?.resumeQuestionnaire();
            container.onboardingController.goTo(step);
            context.push('/onboarding/${step.name}');
          },
          onBack: () {
            final previous =
                container.onboardingController.draft.astrologyEnabled == true
                ? OnboardingStep.birthDate
                : OnboardingStep.astrologyOptIn;
            container.entryCoordinator?.resumeQuestionnaire();
            container.onboardingController.goTo(previous);
            context.go('/onboarding/${previous.name}');
          },
          primaryActionLabel:
              container.authController.state.phase == AuthPhase.signedIn
              ? 'Finish setup'
              : 'Continue with Google',
          onPrimaryAction:
              container.authController.state.phase == AuthPhase.signedIn
              ? () => _runUiAction(context, container.attachOnboardingDraft)
              : () => context.push('/sign-in'),
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
                container.entryCoordinator?.pauseQuestionnaire();
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
      buildMemberShellRoute(
        runtime: container,
        resourceAccess: access,
        onLogout: container.logout,
      ),
    ],
  );
}

String? _safePendingMemberPath(Uri uri) {
  if (uri.hasQuery || uri.hasFragment || uri.path.length > 512) return null;
  return RegExp(r'^/(gospel|ritual|discover|coven|you)(/[A-Za-z0-9._~-]+)*$')
          .hasMatch(uri.path)
      ? uri.path
      : null;
}

String? _restoreMemberPath(
  MemberNavigationPolicy routerNavigation,
  MemberNavigationPolicy liveNavigation,
  String? Function() read,
  void Function() clear,
) {
  if (!_sameNavigation(routerNavigation, liveNavigation)) return null;
  final path = read() ?? MemberRoutes.ritual.path;
  clear();
  return routerNavigation.redirectFor(path) ?? path;
}

bool _sameNavigation(
  MemberNavigationPolicy first,
  MemberNavigationPolicy second,
) =>
    first.capabilityVersion == second.capabilityVersion &&
    first.isAuthoritative == second.isAuthoritative &&
    listEquals(first.branches, second.branches);

const _legacyPasswordAuthPaths = {
  '/sign-up',
  '/forgot-password',
  '/check-email',
  '/auth/recovery',
  '/create-account',
};

class _OAuthCallbackScreen extends StatelessWidget {
  const _OAuthCallbackScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Completing secure Google sign-in…'),
          ],
        ),
      ),
    ),
  );
}

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Page not found')),
    body: Center(
      child: TextButton(
        onPressed: () => context.go('/'),
        child: const Text('Return to Leo'),
      ),
    ),
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
  Widget build(BuildContext context) => BirthdayOnboardingScreen(
    controller: container.onboardingController,
    onFinish: container.completeBirthdayOnboarding,
    onLogout: container.logout,
    onDraftChanged: (draft) =>
        _runUiAction(context, () => container.persistOnboardingDraft(draft)),
    persistenceMessage: container.entryCoordinator?.state.message,
    onRetryPersistence: () => _runUiAction(
      context,
      () => container.persistOnboardingDraft(
        container.onboardingController.draft,
      ),
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
        'Sign in to continue to Leo.',
        'Sign in',
        () async => context.go('/sign-in'),
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
        'Add your birth date to finish setup.',
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
