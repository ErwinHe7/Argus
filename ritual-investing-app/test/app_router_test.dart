import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ritual_investing_app/app/ritual_investing_app.dart';
import 'package:ritual_investing_app/core/api/pending_command_store.dart';
import 'package:ritual_investing_app/core/api/ritual_api.dart';
import 'package:ritual_investing_app/core/auth/auth_controller.dart';
import 'package:ritual_investing_app/core/auth/member_auth.dart';
import 'package:ritual_investing_app/core/bootstrap/dependency_container.dart';
import 'package:ritual_investing_app/core/bootstrap/entry_coordinator.dart';
import 'package:ritual_investing_app/core/bootstrap/member_bootstrap.dart';
import 'package:ritual_investing_app/core/navigation/member_routes.dart';
import 'package:ritual_investing_app/features/onboarding/data/onboarding_draft_store.dart';
import 'package:ritual_investing_app/features/onboarding/data/onboarding_repository.dart';
import 'package:ritual_investing_app/features/onboarding/domain/onboarding_draft.dart';
import 'package:ritual_investing_app/features/privacy/data/repository.dart';
import 'package:ritual_investing_app/features/privacy/domain/model.dart';

import 'support/fixture_services.dart';

void main() {
  test('branch policy derives exact beta and production order', () {
    final beta = MemberNavigationPolicy.fromBootstrap(
      _bootstrapWithBranches(
        environment: MemberReleaseEnvironment.beta,
        enabled: const {
          MemberBranchCapability.ritual,
          MemberBranchCapability.starpath,
          MemberBranchCapability.discover,
          MemberBranchCapability.coven,
          MemberBranchCapability.you,
        },
      ),
    );
    final production = MemberNavigationPolicy.fromBootstrap(
      _bootstrapWithBranches(
        environment: MemberReleaseEnvironment.production,
        enabled: const {
          MemberBranchCapability.ritual,
          MemberBranchCapability.starpath,
          MemberBranchCapability.you,
        },
      ),
    );

    expect(beta.branches, [
      MemberBranch.ritual,
      MemberBranch.starpath,
      MemberBranch.discover,
      MemberBranch.coven,
      MemberBranch.you,
    ]);
    expect(production.branches, [
      MemberBranch.ritual,
      MemberBranch.starpath,
      MemberBranch.you,
    ]);
  });

  test('expired or unknown branch authority fails closed', () {
    for (final authority in [
      MemberNavigationCapabilities(
        schemaVersion: 'member-branch-capabilities-v1',
        capabilityVersion: 3,
        environment: MemberReleaseEnvironment.beta,
        evaluatedAt: DateTime.utc(2026, 8, 20),
        expiresAt: DateTime.utc(2026, 8, 23),
        enabled: const {MemberBranchCapability.ritual},
      ),
      MemberNavigationCapabilities(
        schemaVersion: 'member-branch-capabilities-v1',
        capabilityVersion: 3,
        environment: MemberReleaseEnvironment.beta,
        evaluatedAt: DateTime.utc(2026, 8, 20),
        expiresAt: DateTime.utc(2026, 8, 30),
        enabled: const {
          MemberBranchCapability.ritual,
          MemberBranchCapability.unknown,
        },
      ),
    ]) {
      final policy = MemberNavigationPolicy.fromBootstrap(
        _bootstrapWithAuthority(authority),
      );
      expect(policy.branches, [MemberBranch.ritual]);
      expect(policy.isAuthoritative, isFalse);
    }
  });

  test('hidden route fallback prefers Starpath then Ritual', () {
    final withStarpath = MemberNavigationPolicy.fromBootstrap(
      _bootstrapWithBranches(
        environment: MemberReleaseEnvironment.production,
        enabled: const {
          MemberBranchCapability.ritual,
          MemberBranchCapability.starpath,
          MemberBranchCapability.you,
        },
      ),
    );
    final rollback = MemberNavigationPolicy.fromBootstrap(
      _bootstrapWithBranches(
        environment: MemberReleaseEnvironment.production,
        enabled: const {
          MemberBranchCapability.ritual,
          MemberBranchCapability.you,
        },
      ),
    );

    expect(withStarpath.redirectFor('/discover/assets/id'), '/starpath');
    expect(rollback.redirectFor('/coven/entries/id'), '/ritual');
    expect(withStarpath.redirectFor('/you/account'), isNull);
  });

  testWidgets('production shell renders Ritual, Starpath, You only', (
    tester,
  ) async {
    await tester.pumpWidget(
      RitualInvestingApp(
        container: fixtureContainer(
          sessionBootstrapService: _ProductionBootstrapService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final router = GoRouter.of(
      tester.element(find.byKey(const Key('app-shell-scaffold'))),
    );
    final shell = router.configuration.routes
        .whereType<StatefulShellRoute>()
        .single;
    expect(shell.branches, hasLength(3));
    final destinations = tester
        .widgetList<NavigationDestination>(find.byType(NavigationDestination))
        .map((destination) => destination.label)
        .toList();
    expect(destinations, ['Ritual', 'Starpath', 'You']);

    router.go('/discover/assets/hidden-id');
    await tester.pumpAndSettle();
    expect(router.state.uri.path, MemberRoutes.starpath.path);
    expect(find.byKey(const Key('starpath-root')), findsOneWidget);
  });

  testWidgets('iOS beta tab bar preserves the same five-branch order', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(
        RitualInvestingApp(container: fixtureContainer()),
      );
      await tester.pumpAndSettle();

      final tabBar = tester.widget<CupertinoTabBar>(
        find.byType(CupertinoTabBar),
      );
      expect(tabBar.items.map((item) => item.label), [
        'Ritual',
        'Starpath',
        'Discover',
        'Coven',
        'You',
      ]);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('clean install signs up before starting onboarding', (
    tester,
  ) async {
    final sessions = _SignedOutSessionRepository(
      passwordSession: const AuthSession(
        accessToken: 'password-token',
        userId: '11111111-1111-4111-8111-111111111111',
      ),
    );
    final auth = AuthController(repository: sessions);
    final coordinator = EntryCoordinator(
      authController: auth,
      bootstrapService: _IncompleteBootstrapService(),
      draftStore: OnboardingDraftStore(
        storage: _MemoryProtectedStorage(),
        installation: const FixedInstallationBinding('install-a'),
        now: () => DateTime.utc(2026, 8, 24),
      ),
      onboardingRepository: _UnusedOnboardingRepository(),
    );
    final container = fixtureContainer(
      authController: auth,
      entryCoordinator: coordinator,
    );
    await coordinator.restore();
    await tester.pumpWidget(
      RitualInvestingApp(container: container, bootstrapOnStart: false),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('welcome-create-account')), findsOneWidget);
    final router = GoRouter.of(
      tester.element(find.byKey(const Key('welcome-create-account'))),
    );
    router.go(MemberRoutes.ritual.path);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/welcome');
    router.go(MemberRoutes.youAstrologyPath);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/welcome');

    await tester.tap(find.byKey(const Key('welcome-create-account')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/sign-up');
    expect(find.text('Create account'), findsAtLeastNWidgets(1));

    await tester.enterText(
      find.byKey(const Key('member-sign-in-email')),
      'new-member@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('member-sign-in-password')),
      'correct horse battery staple',
    );
    await tester.enterText(
      find.byKey(const Key('member-sign-in-password-confirmation')),
      'correct horse battery staple',
    );
    await tester.tap(find.byKey(const Key('member-sign-in-submit')));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/onboarding/experience');
    expect(find.text('How familiar are you with investing?'), findsOneWidget);
    expect(find.byKey(const Key('recovery-continue')), findsNothing);
    expect(sessions.passwordSignUpCredentials, [
      (
        email: 'new-member@example.com',
        password: 'correct horse battery staple',
      ),
    ]);

    await tester.tap(find.byKey(const Key('onboarding-back')));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/onboarding/recovery');
    expect(find.byKey(const Key('welcome-create-account')), findsNothing);
    expect(find.byKey(const Key('recovery-continue')), findsOneWidget);
  });

  testWidgets('existing account opens credential sign in without OAuth', (
    tester,
  ) async {
    final sessions = _SignedOutSessionRepository();
    final auth = AuthController(repository: sessions);
    final coordinator = EntryCoordinator(
      authController: auth,
      bootstrapService: _UnusedBootstrapService(),
      draftStore: OnboardingDraftStore(
        storage: _MemoryProtectedStorage(),
        installation: const FixedInstallationBinding('install-a'),
        now: () => DateTime.utc(2026, 8, 24),
      ),
      onboardingRepository: _UnusedOnboardingRepository(),
    );
    final container = fixtureContainer(
      authController: auth,
      entryCoordinator: coordinator,
    );
    await coordinator.restore();
    await tester.pumpWidget(
      RitualInvestingApp(container: container, bootstrapOnStart: false),
    );
    await tester.pumpAndSettle();

    expect(find.text('I have an account'), findsOneWidget);
    await tester.tap(find.byKey(const Key('welcome-sign-in')));
    await tester.pumpAndSettle();

    final router = GoRouter.of(
      tester.element(find.byKey(const Key('member-sign-in-email'))),
    );
    expect(router.state.uri.path, '/sign-in');
    expect(find.byKey(const Key('member-sign-in-password')), findsOneWidget);
    expect(sessions.passwordCredentials, isEmpty);
  });

  testWidgets('signup failure stays on account creation without onboarding', (
    tester,
  ) async {
    final sessions = _SignedOutSessionRepository(
      authenticationError: const MemberAuthUnavailable('email_exists'),
    );
    final auth = AuthController(repository: sessions);
    final coordinator = EntryCoordinator(
      authController: auth,
      bootstrapService: _UnusedBootstrapService(),
      draftStore: OnboardingDraftStore(
        storage: _MemoryProtectedStorage(),
        installation: const FixedInstallationBinding('install-a'),
        now: () => DateTime.utc(2026, 8, 24),
      ),
      onboardingRepository: _UnusedOnboardingRepository(),
    );
    final container = fixtureContainer(
      authController: auth,
      entryCoordinator: coordinator,
    );
    await coordinator.restore();
    await tester.pumpWidget(
      RitualInvestingApp(container: container, bootstrapOnStart: false),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('welcome-create-account')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('member-sign-in-email')),
      'existing@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('member-sign-in-password')),
      'correct horse battery staple',
    );
    await tester.enterText(
      find.byKey(const Key('member-sign-in-password-confirmation')),
      'correct horse battery staple',
    );
    await tester.tap(find.byKey(const Key('member-sign-in-submit')));
    await tester.pumpAndSettle();

    final router = GoRouter.of(
      tester.element(find.byKey(const Key('member-sign-in-email'))),
    );
    expect(router.state.uri.path, '/sign-up');
    expect(
      find.text('An account already exists for this email.'),
      findsOneWidget,
    );
    expect(find.text('How familiar are you with investing?'), findsNothing);
  });

  testWidgets(
    'confirmation-required signup replaces the form with a check-email screen',
    (tester) async {
      final signUpBarrier = Completer<void>();
      final sessions = _SignedOutSessionRepository(
        authenticationError: const MemberAuthUnavailable(
          'email_confirmation_required',
        ),
        signUpBarrier: signUpBarrier.future,
      );
      final auth = AuthController(repository: sessions);
      final coordinator = EntryCoordinator(
        authController: auth,
        bootstrapService: _UnusedBootstrapService(),
        draftStore: OnboardingDraftStore(
          storage: _MemoryProtectedStorage(),
          installation: const FixedInstallationBinding('install-a'),
          now: () => DateTime.utc(2026, 8, 24),
        ),
        onboardingRepository: _UnusedOnboardingRepository(),
      );
      final container = fixtureContainer(
        authController: auth,
        entryCoordinator: coordinator,
      );
      await coordinator.restore();
      await tester.pumpWidget(
        RitualInvestingApp(container: container, bootstrapOnStart: false),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('welcome-create-account')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('member-sign-in-email')),
        'new-member@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('member-sign-in-password')),
        'correct horse battery staple',
      );
      await tester.enterText(
        find.byKey(const Key('member-sign-in-password-confirmation')),
        'correct horse battery staple',
      );
      final router = GoRouter.of(
        tester.element(find.byKey(const Key('member-sign-in-email'))),
      );

      await tester.tap(find.byKey(const Key('member-sign-in-submit')));
      await tester.pump();
      await tester.pump();
      expect(router.state.uri.path, '/sign-up');

      signUpBarrier.complete();
      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/check-email');
      expect(find.text('Check your email'), findsOneWidget);
      expect(find.text('new-member@example.com'), findsOneWidget);
      expect(find.byKey(const Key('member-sign-in-email')), findsNothing);
      expect(find.byKey(const Key('member-sign-in-password')), findsNothing);
      expect(
        find.widgetWithText(FilledButton, 'Go to sign in'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextButton, 'Use a different email'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('welcome-create-account')), findsNothing);
      expect(find.text('How familiar are you with investing?'), findsNothing);

      await tester.tap(
        find.byKey(const Key('email-confirmation-change-email')),
      );
      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/sign-up');
      expect(find.byKey(const Key('member-sign-in-email')), findsOneWidget);
    },
  );

  testWidgets('fallback signed-out gate opens password form without OAuth', (
    tester,
  ) async {
    final sessions = _SignedOutSessionRepository();
    await tester.pumpWidget(
      RitualInvestingApp(
        container: fixtureContainer(sessionRepository: sessions),
        bootstrapOnStart: false,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('member-sign-in-email')), findsOneWidget);
    expect(find.byKey(const Key('member-sign-in-password')), findsOneWidget);
    expect(sessions.passwordCredentials, isEmpty);
  });

  testWidgets('valid credentials enter the completed member shell', (
    tester,
  ) async {
    final sessions = _SignedOutSessionRepository(
      passwordSession: const AuthSession(
        accessToken: 'password-token',
        userId: '11111111-1111-4111-8111-111111111111',
      ),
    );
    final auth = AuthController(repository: sessions);
    final bootstrap = _CompletedBootstrapService();
    final coordinator = EntryCoordinator(
      authController: auth,
      bootstrapService: bootstrap,
      draftStore: OnboardingDraftStore(
        storage: _MemoryProtectedStorage(),
        installation: const FixedInstallationBinding('install-a'),
        now: () => DateTime.utc(2026, 8, 24),
      ),
      onboardingRepository: _UnusedOnboardingRepository(),
    );
    final container = fixtureContainer(
      authController: auth,
      entryCoordinator: coordinator,
      sessionBootstrapService: bootstrap,
      includeU11: true,
      privacyRepository: _RouterPrivacyRepository(),
    );
    await coordinator.restore();
    await tester.pumpWidget(
      RitualInvestingApp(container: container, bootstrapOnStart: false),
    );
    await tester.pumpAndSettle();

    final router = GoRouter.of(
      tester.element(find.byKey(const Key('welcome-sign-in'))),
    );
    router.go(MemberRoutes.youPrivacyPath);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/welcome');

    await tester.tap(find.byKey(const Key('welcome-sign-in')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('member-sign-in-email')),
      'beta@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('member-sign-in-password')),
      'correct horse battery staple',
    );
    await tester.tap(find.byKey(const Key('member-sign-in-submit')));
    await tester.pumpAndSettle();

    expect(sessions.passwordCredentials, [
      (email: 'beta@example.com', password: 'correct horse battery staple'),
    ]);
    expect(find.byKey(const Key('app-shell-scaffold')), findsOneWidget);
    final signedInRouter = GoRouter.of(
      tester.element(find.byKey(const Key('app-shell-scaffold'))),
    );
    expect(signedInRouter.state.uri.path, MemberRoutes.youPrivacyPath);
  });

  testWidgets(
    'exact recovery callback permits one recovery-bound password update',
    (tester) async {
      final sessions = _RecoverySessionRepository();
      final auth = AuthController(repository: sessions);
      final bootstrap = _CompletedBootstrapService();
      final coordinator = EntryCoordinator(
        authController: auth,
        bootstrapService: bootstrap,
        draftStore: OnboardingDraftStore(
          storage: _MemoryProtectedStorage(),
          installation: const FixedInstallationBinding('install-recovery'),
          now: () => DateTime.utc(2026, 8, 30),
        ),
        onboardingRepository: _UnusedOnboardingRepository(),
      );
      final container = fixtureContainer(
        authController: auth,
        entryCoordinator: coordinator,
        sessionBootstrapService: bootstrap,
      );
      await coordinator.restore();
      await tester.pumpWidget(
        RitualInvestingApp(container: container, bootstrapOnStart: false),
      );
      await tester.pumpAndSettle();
      final router = GoRouter.of(
        tester.element(find.byKey(const Key('app-shell-scaffold'))),
      );

      router.go('/mobile/argus-auth/callback');
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/auth/recovery');
      expect(find.byKey(const Key('member-new-password')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('member-new-password')),
        'new-password',
      );
      await tester.tap(find.byKey(const Key('member-password-submit')));
      await tester.pumpAndSettle();

      expect(sessions.passwordUpdates, 1);
      expect(router.state.uri.path, MemberRoutes.ritual.path);
    },
  );

  testWidgets(
    'authenticated onboarding finishes setup without creating another account',
    (tester) async {
      final sessions = _SignedOutSessionRepository(
        restoredSession: const AuthSession(
          accessToken: 'password-token',
          userId: '11111111-1111-4111-8111-111111111111',
        ),
      );
      final auth = AuthController(repository: sessions);
      final bootstrap = _IncompleteBootstrapService();
      final onboarding = _CompletingOnboardingRepository();
      final coordinator = EntryCoordinator(
        authController: auth,
        bootstrapService: bootstrap,
        draftStore: OnboardingDraftStore(
          storage: _MemoryProtectedStorage(),
          installation: const FixedInstallationBinding('install-a'),
          now: () => DateTime.utc(2026, 8, 24),
        ),
        onboardingRepository: onboarding,
      );
      final container = fixtureContainer(
        authController: auth,
        entryCoordinator: coordinator,
        sessionBootstrapService: bootstrap,
      );
      await coordinator.restore();
      container.onboardingController.replaceDraft(_reviewedDraft());
      await tester.pumpWidget(
        RitualInvestingApp(container: container, bootstrapOnStart: false),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('recovery-continue')), findsOneWidget);
      await tester.tap(find.byKey(const Key('recovery-continue')));
      await tester.pumpAndSettle();
      expect(container.entryGate, MemberEntryGate.onboarding);

      final router = GoRouter.of(
        tester.element(find.text('How familiar are you with investing?')),
      );
      router.go('/onboarding/review');
      await tester.pumpAndSettle();

      final finishSetup = find.widgetWithText(FilledButton, 'Finish setup');
      await _scrollTo(tester, finishSetup);
      expect(finishSetup, findsOneWidget);

      router.go('/create-account');
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/onboarding/review');
      expect(find.byKey(const Key('member-sign-in-email')), findsNothing);

      await _scrollTo(tester, finishSetup);
      await tester.tap(finishSetup);
      await tester.pumpAndSettle();

      expect(onboarding.commands, hasLength(1));
      expect(find.byKey(const Key('app-shell-scaffold')), findsOneWidget);
      expect(sessions.passwordSignUpCredentials, isEmpty);
    },
  );

  testWidgets(
    'onboarding account creation uses password credentials without OAuth',
    (tester) async {
      final sessions = _SignedOutSessionRepository(
        authenticationError: const MemberAuthCancelled(),
      );
      final auth = AuthController(repository: sessions);
      final coordinator = EntryCoordinator(
        authController: auth,
        bootstrapService: _UnusedBootstrapService(),
        draftStore: OnboardingDraftStore(
          storage: _MemoryProtectedStorage(),
          installation: const FixedInstallationBinding('install-a'),
          now: () => DateTime.utc(2026, 8, 24),
        ),
        onboardingRepository: _UnusedOnboardingRepository(),
      );
      final container = fixtureContainer(
        authController: auth,
        entryCoordinator: coordinator,
      );
      final reviewedDraft = _reviewedDraft();
      await coordinator.beginQuestionnaire(reviewedDraft);
      container.onboardingController.replaceDraft(reviewedDraft);
      await tester.pumpWidget(
        RitualInvestingApp(container: container, bootstrapOnStart: false),
      );
      await tester.pumpAndSettle();

      final questionnaireRouter = GoRouter.of(
        tester.element(find.text('How familiar are you with investing?')),
      );
      questionnaireRouter.go('/onboarding/review');
      await tester.pumpAndSettle();

      final createAccount = find.byKey(const Key('review-create-account'));
      await _scrollTo(tester, createAccount);
      await tester.tap(createAccount);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('member-sign-in-email')), findsOneWidget);
      expect(find.byKey(const Key('member-sign-in-password')), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Create account'),
        findsOneWidget,
      );
      final router = GoRouter.of(
        tester.element(find.byKey(const Key('member-sign-in-email'))),
      );
      expect(router.state.uri.path, '/create-account');
      await tester.enterText(
        find.byKey(const Key('member-sign-in-email')),
        'new-member@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('member-sign-in-password')),
        'correct horse battery staple',
      );
      await tester.enterText(
        find.byKey(const Key('member-sign-in-password-confirmation')),
        'correct horse battery staple',
      );
      await tester.tap(find.byKey(const Key('member-sign-in-submit')));
      await tester.pumpAndSettle();

      expect(sessions.passwordSignUpCredentials, [
        (
          email: 'new-member@example.com',
          password: 'correct horse battery staple',
        ),
      ]);
    },
  );

  testWidgets('locked draft save remains editable and exposes retry', (
    tester,
  ) async {
    final storage = _MemoryProtectedStorage()
      ..writeError = const ProtectedStorageLocked();
    final auth = AuthController(repository: _SignedOutSessionRepository());
    final coordinator = EntryCoordinator(
      authController: auth,
      bootstrapService: _UnusedBootstrapService(),
      draftStore: OnboardingDraftStore(
        storage: storage,
        installation: const FixedInstallationBinding('install-a'),
        now: () => DateTime.utc(2026, 8, 24),
      ),
      onboardingRepository: _UnusedOnboardingRepository(),
    );
    final container = fixtureContainer(
      authController: auth,
      entryCoordinator: coordinator,
    );
    await coordinator.restore();
    await tester.pumpWidget(
      RitualInvestingApp(container: container, bootstrapOnStart: false),
    );
    await tester.pumpAndSettle();

    await coordinator.beginQuestionnaire();
    await tester.pumpAndSettle();

    expect(find.text('How familiar are you with investing?'), findsOneWidget);
    expect(find.byKey(const Key('draft-persistence-message')), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('review Retry saves only and never launches hosted auth', (
    tester,
  ) async {
    final storage = _MemoryProtectedStorage()
      ..writeError = const ProtectedStorageLocked();
    final sessions = _SignedOutSessionRepository();
    final auth = AuthController(repository: sessions);
    final coordinator = EntryCoordinator(
      authController: auth,
      bootstrapService: _UnusedBootstrapService(),
      draftStore: OnboardingDraftStore(
        storage: storage,
        installation: const FixedInstallationBinding('install-a'),
        now: () => DateTime.utc(2026, 8, 24),
      ),
      onboardingRepository: _UnusedOnboardingRepository(),
    );
    final container = fixtureContainer(
      authController: auth,
      entryCoordinator: coordinator,
    );
    await coordinator.createAccountWithPassword(
      reviewedDraft: _reviewedDraft(),
      email: 'setup@example.com',
      password: 'setup-password',
    );
    await tester.pumpWidget(
      RitualInvestingApp(container: container, bootstrapOnStart: false),
    );
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.text('Review your Ritual')));
    storage.writeError = null;

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(sessions.passwordSignUpCredentials, isEmpty);
    expect(storage.values, contains(OnboardingDraftStore.storageKey));
    expect(coordinator.state.destination, EntryDestination.review);
    expect(router.state.uri.path, '/onboarding/review');
    expect(find.text('Review your Ritual'), findsOneWidget);
  });

  testWidgets(
    'cancelled sign-up review Edit resumes questionnaire with draft intact',
    (tester) async {
      final sessions = _SignedOutSessionRepository(
        authenticationError: const MemberAuthCancelled(),
      );
      final auth = AuthController(repository: sessions);
      final coordinator = EntryCoordinator(
        authController: auth,
        bootstrapService: _UnusedBootstrapService(),
        draftStore: OnboardingDraftStore(
          storage: _MemoryProtectedStorage(),
          installation: const FixedInstallationBinding('install-a'),
          now: () => DateTime.utc(2026, 8, 24),
        ),
        onboardingRepository: _UnusedOnboardingRepository(),
      );
      final container = fixtureContainer(
        authController: auth,
        entryCoordinator: coordinator,
      );
      final draft = _reviewedDraft();
      await coordinator.createAccountWithPassword(
        reviewedDraft: draft,
        email: 'setup@example.com',
        password: 'setup-password',
      );
      await tester.pumpWidget(
        RitualInvestingApp(container: container, bootstrapOnStart: false),
      );
      await tester.pumpAndSettle();
      final router = GoRouter.of(
        tester.element(find.text('Review your Ritual')),
      );

      await tester.tap(find.widgetWithText(TextButton, 'Edit').first);
      await tester.pumpAndSettle();

      expect(coordinator.state.destination, EntryDestination.questionnaire);
      expect(container.onboardingController.draft, draft);
      expect(router.state.uri.path, '/onboarding/experience');
      expect(find.text('How familiar are you with investing?'), findsOneWidget);
    },
  );

  testWidgets(
    'cancelled sign-up review Back resumes prior question with draft intact',
    (tester) async {
      final sessions = _SignedOutSessionRepository(
        authenticationError: const MemberAuthCancelled(),
      );
      final auth = AuthController(repository: sessions);
      final coordinator = EntryCoordinator(
        authController: auth,
        bootstrapService: _UnusedBootstrapService(),
        draftStore: OnboardingDraftStore(
          storage: _MemoryProtectedStorage(),
          installation: const FixedInstallationBinding('install-a'),
          now: () => DateTime.utc(2026, 8, 24),
        ),
        onboardingRepository: _UnusedOnboardingRepository(),
      );
      final container = fixtureContainer(
        authController: auth,
        entryCoordinator: coordinator,
      );
      final draft = _reviewedDraft();
      await coordinator.createAccountWithPassword(
        reviewedDraft: draft,
        email: 'setup@example.com',
        password: 'setup-password',
      );
      await tester.pumpWidget(
        RitualInvestingApp(container: container, bootstrapOnStart: false),
      );
      await tester.pumpAndSettle();
      final router = GoRouter.of(
        tester.element(find.text('Review your Ritual')),
      );

      await tester.tap(find.byKey(const Key('review-back')));
      await tester.pumpAndSettle();

      expect(coordinator.state.destination, EntryDestination.questionnaire);
      expect(container.onboardingController.draft, draft);
      expect(router.state.uri.path, '/onboarding/astrologyOptIn');
      expect(
        find.text('Would you like personalized astrology?'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'beta shell has five lazy branches with independent back stacks',
    (tester) async {
      final loads = FeatureLoadTracker();
      await tester.pumpWidget(
        RitualInvestingApp(
          container: fixtureContainer(loadTracker: loads),
          resourceAccess: (_, _) => true,
        ),
      );
      await tester.pumpAndSettle();

      final router = GoRouter.of(
        tester.element(find.byKey(const Key('app-shell-scaffold'))),
      );
      final shell = router.configuration.routes
          .whereType<StatefulShellRoute>()
          .single;
      expect(shell.branches, hasLength(5));
      expect(shell.restorationScopeId, 'member-shell');
      expect(loads.count(MemberBranch.ritual), 1);
      expect(loads.count(MemberBranch.starpath), 0);
      expect(loads.count(MemberBranch.discover), 0);
      expect(loads.count(MemberBranch.coven), 0);
      expect(loads.count(MemberBranch.you), 0);

      router.push(MemberRoutes.ritualReading.location('ritual-1'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('detail-ritual-reading')), findsOneWidget);

      await tester.tap(find.text('Discover').last);
      await tester.pumpAndSettle();
      expect(loads.count(MemberBranch.discover), 1);
      expect(loads.count(MemberBranch.coven), 0);
      router.push(
        MemberRoutes.discoverAsset.location(
          '00000000-0000-4000-8000-000000000201',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('asset-codex-screen')), findsOneWidget);

      await tester.tap(find.text('Ritual').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('detail-ritual-reading')), findsOneWidget);
      await tester.tap(find.text('Discover').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('asset-codex-screen')), findsOneWidget);
    },
  );

  testWidgets(
    'invalid or unauthorized restored resource falls back without leaking id',
    (tester) async {
      await tester.pumpWidget(
        RitualInvestingApp(
          container: fixtureContainer(),
          resourceAccess: (_, id) => id == 'allowed-id',
        ),
      );
      await tester.pumpAndSettle();
      final router = GoRouter.of(
        tester.element(find.byKey(const Key('app-shell-scaffold'))),
      );

      router.go(
        MemberRoutes.discoverAsset.location('private-restored-asset-id'),
      );
      await tester.pumpAndSettle();

      expect(router.state.uri.path, MemberRoutes.discover.path);
      expect(find.textContaining('private-restored-asset-id'), findsNothing);
      expect(find.byKey(const Key('app-shell-scaffold')), findsOneWidget);
    },
  );

  testWidgets(
    'You settings use focused shell-gated routes and lifecycle logout',
    (tester) async {
      await tester.pumpWidget(
        RitualInvestingApp(
          container: fixtureContainer(),
          resourceAccess: (_, _) => true,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('You').last);
      await tester.pumpAndSettle();
      final router = GoRouter.of(
        tester.element(find.byKey(const Key('app-shell-scaffold'))),
      );

      await tester.tap(find.byKey(const Key('you-investing')));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, MemberRoutes.youInvestingPath);
      expect(find.text('Investing profile'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      router.go(MemberRoutes.youPoliciesPath);
      await tester.pumpAndSettle();
      expect(find.text('Policy decisions'), findsOneWidget);
      expect(find.text('Onboarding complete'), findsOneWidget);

      router.go(MemberRoutes.youAccountPath);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings-logout')));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/entry');
    },
  );

  testWidgets('U11 privacy uses a stable focused You route', (tester) async {
    await tester.pumpWidget(
      RitualInvestingApp(
        container: fixtureContainer(
          includeU11: true,
          privacyRepository: _RouterPrivacyRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('You').last);
    await tester.pumpAndSettle();
    final router = GoRouter.of(
      tester.element(find.byKey(const Key('app-shell-scaffold'))),
    );

    await _scrollTo(tester, find.byKey(const Key('you-privacy')));
    await tester.tap(find.byKey(const Key('you-privacy')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, MemberRoutes.youPrivacyPath);
    expect(find.text('Privacy and data'), findsOneWidget);
  });

  testWidgets('U5 stable UUID routes restore every research/private detail', (
    tester,
  ) async {
    await tester.pumpWidget(RitualInvestingApp(container: fixtureContainer()));
    await tester.pumpAndSettle();
    final router = GoRouter.of(
      tester.element(find.byKey(const Key('app-shell-scaffold'))),
    );

    router.go(
      MemberRoutes.discoverGrimoire.location(
        '00000000-0000-4000-8000-000000000540',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Quiet Power Grimoire'), findsOneWidget);

    router.go(
      MemberRoutes.discoverCircleTemplate.location(
        '00000000-0000-4000-8000-000000000550',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Soft Power Circle'), findsOneWidget);

    router.go(
      MemberRoutes.discoverCreator.location(
        '00000000-0000-4000-8000-000000000552',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mira Vale'), findsOneWidget);

    router.go(
      MemberRoutes.covenEntry.location('00000000-0000-4000-8000-000000000510'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Aurora Healthworks'), findsOneWidget);

    router.go(MemberRoutes.discoverCirclesPath);
    await tester.pumpAndSettle();
    expect(find.text('Your private Circles'), findsOneWidget);

    router.go(
      MemberRoutes.discoverCircle.location(
        '00000000-0000-4000-8000-000000000560',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Private · editable'), findsOneWidget);

    router.go(MemberRoutes.discoverGrimoire.location('not-a-uuid'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, MemberRoutes.discover.path);
    expect(find.textContaining('not-a-uuid'), findsNothing);
  });

  testWidgets('template copy opens the authoritative private Circle', (
    tester,
  ) async {
    await tester.pumpWidget(RitualInvestingApp(container: fixtureContainer()));
    await tester.pumpAndSettle();
    final router = GoRouter.of(
      tester.element(find.byKey(const Key('app-shell-scaffold'))),
    );
    router.go(
      MemberRoutes.discoverCircleTemplate.location(
        '00000000-0000-4000-8000-000000000550',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('template-copy')));
    await tester.pumpAndSettle();

    expect(
      router.state.uri.path,
      MemberRoutes.discoverCircle.location(
        '00000000-0000-4000-8000-000000000560',
      ),
    );
    expect(find.text('Private · editable'), findsOneWidget);
  });

  testWidgets('same U5 route type replaces its controller when UUID changes', (
    tester,
  ) async {
    const firstId = '00000000-0000-4000-8000-000000000552';
    const secondId = '00000000-0000-4000-8000-000000000553';
    await tester.pumpWidget(RitualInvestingApp(container: fixtureContainer()));
    await tester.pumpAndSettle();
    final router = GoRouter.of(
      tester.element(find.byKey(const Key('app-shell-scaffold'))),
    );

    router.go(MemberRoutes.discoverCreator.location(firstId));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('creator-detail-$firstId')),
      findsOneWidget,
    );

    router.go(MemberRoutes.discoverCreator.location(secondId));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('creator-detail-$firstId')), findsNothing);
    expect(
      find.byKey(const ValueKey('creator-detail-$secondId')),
      findsOneWidget,
    );

    const firstAssetId = '00000000-0000-4000-8000-000000000501';
    const secondAssetId = '00000000-0000-4000-8000-000000000502';
    router.go(MemberRoutes.assetLocation(firstAssetId, sourceKind: 'discover'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('asset-codex-$firstAssetId-discover-none')),
      findsOneWidget,
    );

    router.go(
      MemberRoutes.assetLocation(secondAssetId, sourceKind: 'discover'),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('asset-codex-$firstAssetId-discover-none')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('asset-codex-$secondAssetId-discover-none')),
      findsOneWidget,
    );
  });

  testWidgets('U9 briefing A to B route replaces selected authority', (
    tester,
  ) async {
    const briefingA = '00000000-0000-4000-8000-000000000091';
    const briefingB = '00000000-0000-4000-8000-000000000092';
    final container = fixtureContainer(includeU9: true);
    await tester.pumpWidget(RitualInvestingApp(container: container));
    await tester.pumpAndSettle();
    final router = GoRouter.of(
      tester.element(find.byKey(const Key('app-shell-scaffold'))),
    );

    router.go(MemberRoutes.briefingLocation(briefingA));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('briefing-$briefingA')), findsOneWidget);
    expect(find.textContaining('briefing $briefingA'), findsOneWidget);

    router.go(MemberRoutes.briefingLocation(briefingB));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('briefing-$briefingA')), findsNothing);
    expect(find.textContaining('briefing $briefingA'), findsNothing);
    expect(find.byKey(const ValueKey('briefing-$briefingB')), findsOneWidget);
    expect(find.textContaining('briefing $briefingB'), findsOneWidget);
    expect(container.briefingController.selected?.id, briefingB);

    router.go('/ritual/briefings/not-a-uuid');
    await tester.pumpAndSettle();
    expect(router.state.uri.path, MemberRoutes.ritual.path);
    expect(find.textContaining('not-a-uuid'), findsNothing);
  });
}

MemberBootstrap _bootstrapWithBranches({
  required MemberReleaseEnvironment environment,
  required Set<MemberBranchCapability> enabled,
}) => MemberBootstrap(
  accountId: 'navigation-member',
  onboarding: const MemberOnboardingGate.complete(),
  serverTime: DateTime.utc(2026, 8, 24),
  contractVersion: 'member-branch-capabilities-v1',
  themePreference: MemberThemePreference.system,
  branchCapabilities: MemberNavigationCapabilities(
    schemaVersion: 'member-branch-capabilities-v1',
    capabilityVersion: 3,
    environment: environment,
    evaluatedAt: DateTime.utc(2026, 8, 23),
    expiresAt: DateTime.utc(2026, 8, 25),
    enabled: enabled,
  ),
);

MemberBootstrap _bootstrapWithAuthority(
  MemberNavigationCapabilities authority,
) => MemberBootstrap(
  accountId: 'navigation-member',
  onboarding: const MemberOnboardingGate.complete(),
  serverTime: DateTime.utc(2026, 8, 24),
  contractVersion: 'member-branch-capabilities-v1',
  themePreference: MemberThemePreference.system,
  branchCapabilities: authority,
);

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  final scrollable = find.byWidgetPredicate(
    (widget) =>
        widget is Scrollable && widget.axisDirection == AxisDirection.down,
  );
  for (var attempt = 0; attempt < 12; attempt++) {
    if (finder.hitTestable().evaluate().isNotEmpty) return;
    await tester.drag(scrollable, const Offset(0, -360));
    await tester.pumpAndSettle();
  }
  expect(finder.hitTestable(), findsOneWidget);
}

class _SignedOutSessionRepository
    implements SessionRepository, PasswordSessionRepository {
  _SignedOutSessionRepository({
    this.authenticationError,
    this.passwordSession,
    this.restoredSession,
    this.signUpBarrier,
  });

  final Object? authenticationError;
  final AuthSession? passwordSession;
  final AuthSession? restoredSession;
  final Future<void>? signUpBarrier;
  final List<({String email, String password})> passwordCredentials = [];
  final List<({String email, String password})> passwordSignUpCredentials = [];
  @override
  MemberClientExpectation get memberClientExpectation =>
      const MemberClientExpectation(issuer: 'https://member-auth.test/auth/v1');
  @override
  Stream<AuthSession> get recoveredSessions => const Stream.empty();
  @override
  Future<AuthSession> signInWithPassword({
    required String email,
    required String password,
  }) async {
    passwordCredentials.add((email: email, password: password));
    final error = authenticationError;
    if (error != null) throw error;
    return passwordSession ?? const AuthSession(accessToken: 'password-token');
  }

  @override
  Future<AuthSession> signUpWithPassword({
    required String email,
    required String password,
  }) async {
    passwordSignUpCredentials.add((email: email, password: password));
    await signUpBarrier;
    final error = authenticationError;
    if (error != null) throw error;
    return passwordSession ?? const AuthSession(accessToken: 'password-token');
  }

  @override
  Future<AuthSession?> recover() async => restoredSession;
  @override
  Future<void> logout() async {}
}

class _RecoverySessionRepository
    implements
        SessionRepository,
        PasswordRecoverySessionRepository,
        InitialPasswordRecoveryRepository {
  bool _initialRecovery = true;
  int passwordUpdates = 0;

  @override
  MemberClientExpectation get memberClientExpectation =>
      const MemberClientExpectation(issuer: 'https://member-auth.test/auth/v1');
  @override
  Stream<AuthSession> get recoveredSessions => const Stream.empty();
  @override
  Future<AuthSession?> recover() async => const AuthSession(
    accessToken: 'recovery-token',
    userId: '11111111-1111-4111-8111-111111111111',
  );
  @override
  bool consumeInitialPasswordRecovery() {
    final value = _initialRecovery;
    _initialRecovery = false;
    return value;
  }

  @override
  Future<void> requestPasswordRecovery({required String email}) async {}
  @override
  Future<void> updatePassword({required String password}) async {
    passwordUpdates += 1;
  }

  @override
  Future<void> logout() async {}
}

OnboardingDraft _reviewedDraft() => const OnboardingDraft(
  experience: InvestingExperience.newToInvesting,
  goal: InvestmentGoal.longTermGrowth,
  horizon: InvestmentHorizon.long,
  risk: RiskComfort.moderate,
  contributionRhythm: ContributionRhythm.monthly,
  ritualLanguage: RitualLanguage.practical,
  ritualFamiliarity: RitualFamiliarity.curious,
  ritualInterests: {RitualInterest.practicalResearch},
  astrologyEnabled: false,
  termsAccepted: true,
  privacyAccepted: true,
  demoAccepted: true,
);

class _UnusedBootstrapService implements SessionBootstrapService {
  @override
  Future<MemberBootstrap> bootstrap() => throw StateError('unused');
}

class _CompletedBootstrapService implements SessionBootstrapService {
  @override
  Future<MemberBootstrap> bootstrap() async => MemberBootstrap(
    accountId: 'fixture-account',
    resetGeneration: 0,
    onboarding: const MemberOnboardingGate.complete(),
    entitlement: const MemberEntitlement(
      planCode: 'demo-free',
      status: MemberEntitlementStatus.active,
    ),
    defaultPortfolioId: 'fixture-portfolio',
    serverTime: DateTime.utc(2026, 8, 28),
    contractVersion: '1.0.0',
    themePreference: MemberThemePreference.system,
    branchCapabilities: fixtureBetaNavigationCapabilities(),
  );
}

class _ProductionBootstrapService implements SessionBootstrapService {
  @override
  Future<MemberBootstrap> bootstrap() async => _bootstrapWithBranches(
    environment: MemberReleaseEnvironment.production,
    enabled: const {
      MemberBranchCapability.ritual,
      MemberBranchCapability.starpath,
      MemberBranchCapability.you,
    },
  );
}

class _IncompleteBootstrapService implements SessionBootstrapService {
  @override
  Future<MemberBootstrap> bootstrap() async => MemberBootstrap(
    accountId: 'fixture-account',
    resetGeneration: 0,
    onboarding: MemberOnboardingGate.incomplete(
      nextStep: 'welcome',
      version: 1,
    ),
    entitlement: const MemberEntitlement(
      planCode: 'demo-free',
      status: MemberEntitlementStatus.active,
    ),
    defaultPortfolioId: 'fixture-portfolio',
    serverTime: DateTime.utc(2026, 8, 28),
    contractVersion: '1.0.0',
    themePreference: MemberThemePreference.system,
  );
}

class _CompletingOnboardingRepository implements OnboardingRepository {
  final List<OnboardingFinalizationCommand> commands = [];

  @override
  Future<MemberBootstrap> finalize(
    OnboardingFinalizationCommand command,
  ) async {
    commands.add(command);
    return _CompletedBootstrapService().bootstrap();
  }
}

class _UnusedOnboardingRepository implements OnboardingRepository {
  @override
  Future<MemberBootstrap> finalize(OnboardingFinalizationCommand command) =>
      throw StateError('unused');
}

class _MemoryProtectedStorage implements ProtectedStorage {
  final Map<String, String> values = {};
  Object? writeError;
  @override
  Future<void> delete(String key) async => values.remove(key);
  @override
  Future<Map<String, String>> readAll() async => Map.of(values);
  @override
  Future<void> write(String key, String value) async {
    final error = writeError;
    if (error != null) throw error;
    values[key] = value;
  }
}

class _RouterPrivacyRepository implements PrivacyRepository {
  @override
  Future<void> clearStaleLocalFiles() async {}
  @override
  Future<bool> accountInactive() async => false;
  @override
  Future<void> cancelAndClearLocal() async {}
  @override
  Future<PrivateExportDelivery> downloadAndShare(String requestId) async =>
      PrivateExportDelivery.completed;
  @override
  Future<void> forgetExportId(String requestId) async {}
  @override
  Future<PrivacyExport> getExport(String requestId) =>
      throw StateError('unused');
  @override
  Future<void> rememberExportId(String requestId) async {}
  @override
  Future<PrivacyExport> requestExport(String idempotencyKey) =>
      throw StateError('unused');
  @override
  Future<PrivacyDeletionReceipt> requestDeletion(
    String idempotencyKey,
    String stepUpReceipt,
  ) => throw StateError('unused');
  @override
  Future<String?> restoreExportId() async => null;
}
