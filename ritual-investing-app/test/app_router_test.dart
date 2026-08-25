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

import 'support/fixture_services.dart';

void main() {
  testWidgets('clean install cannot deep-link past guided welcome', (
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

    expect(find.byKey(const Key('welcome-get-started')), findsOneWidget);
    final router = GoRouter.of(
      tester.element(find.byKey(const Key('welcome-get-started'))),
    );
    router.go(MemberRoutes.ritual.path);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/welcome');
    router.go(MemberRoutes.youAstrologyPath);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/welcome');

    await tester.tap(find.byKey(const Key('welcome-get-started')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/onboarding/experience');
    expect(find.text('How familiar are you with investing?'), findsOneWidget);
  });

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

    await tester.tap(find.byKey(const Key('welcome-get-started')));
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
    await coordinator.createAccount(_reviewedDraft());
    await tester.pumpWidget(
      RitualInvestingApp(container: container, bootstrapOnStart: false),
    );
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.text('Review your Ritual')));
    storage.writeError = null;

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(sessions.intents, isEmpty);
    expect(storage.values, contains(OnboardingDraftStore.storageKey));
    expect(coordinator.state.destination, EntryDestination.review);
    expect(router.state.uri.path, '/onboarding/review');
    expect(find.text('Review your Ritual'), findsOneWidget);
  });

  testWidgets(
    'restored shell has four lazy branches with independent back stacks',
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
      expect(shell.branches, hasLength(4));
      expect(shell.restorationScopeId, 'member-shell');
      expect(loads.count(MemberBranch.ritual), 1);
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
      router.push(MemberRoutes.discoverAsset.location('asset-1'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('detail-discover-asset')), findsOneWidget);

      await tester.tap(find.text('Ritual').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('detail-ritual-reading')), findsOneWidget);
      await tester.tap(find.text('Discover').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('detail-discover-asset')), findsOneWidget);
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

  testWidgets('You settings use focused shell-gated routes and lifecycle logout', (
    tester,
  ) async {
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
  });
}

class _SignedOutSessionRepository implements SessionRepository {
  final List<MemberAuthIntent> intents = [];
  @override
  MemberClientExpectation get memberClientExpectation =>
      const MemberClientExpectation(authorizedParty: 'member-client');
  @override
  Stream<AuthSession> get recoveredSessions => const Stream.empty();
  @override
  Future<AuthSession> authenticate(MemberAuthIntent intent) async =>
      _authenticated(intent);
  AuthSession _authenticated(MemberAuthIntent intent) {
    intents.add(intent);
    return const AuthSession(accessToken: 'token');
  }

  @override
  Future<AuthSession?> recover() async => null;
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
