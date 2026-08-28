import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/onboarding/application/onboarding_controller.dart';
import '../../features/onboarding/presentation/onboarding_flow.dart';
import '../bootstrap/dependency_container.dart';
import '../bootstrap/entry_coordinator.dart';
import 'member_app_router.dart';
import 'member_routes.dart';

GoRouter createAppRouter({
  required DependencyContainer container,
  MemberResourceAccess? resourceAccess,
}) {
  final access = resourceAccess ?? (_, _) => false;
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
