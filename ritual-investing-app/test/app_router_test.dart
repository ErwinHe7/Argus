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

    await tester.tap(find.byKey(const Key('onboarding-back')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/welcome');
    expect(find.byKey(const Key('welcome-get-started')), findsOneWidget);
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
      await coordinator.createAccount(draft);
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
      await coordinator.createAccount(draft);
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

  testWidgets('U11 privacy and Demo reset use stable focused You routes', (
    tester,
  ) async {
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

    router.go(MemberRoutes.you.path);
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.byKey(const Key('you-demo-reset')));
    await tester.tap(find.byKey(const Key('you-demo-reset')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, MemberRoutes.youDemoResetPath);
    expect(find.text('Reset Demo'), findsOneWidget);

    router.go(MemberRoutes.youPrivacyPath);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, MemberRoutes.youPrivacyPath);
  });

  testWidgets(
    'U10 gates free surfaces from fresh capability codes and restores context',
    (tester) async {
      await tester.pumpWidget(
        RitualInvestingApp(container: fixtureContainer(includeU10: true)),
      );
      await tester.pumpAndSettle();
      final router = GoRouter.of(
        tester.element(find.byKey(const Key('app-shell-scaffold'))),
      );

      expect(
        find.byKey(const Key('daily-ritual-capability-gate')),
        findsOneWidget,
      );
      expect(find.text('PRIVATE RITUAL CONTENT'), findsNothing);

      const intentionId = '11111111-1111-4111-8111-111111111111';
      final returnLocation = MemberRoutes.futureMirrorLocation(
        'fixture-portfolio',
        intentionId,
      );
      router.go(
        MemberRoutes.membershipLocation(
          capabilityCode: 'future_mirror',
          returnLocation: returnLocation,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Open Future Mirror'), findsOneWidget);
      await _scrollTo(
        tester,
        find.byKey(const Key('membership-choose-premium')),
      );
      expect(
        find.byKey(const Key('membership-choose-premium')),
        findsOneWidget,
      );

      router.go(
        '${MemberRoutes.youMembershipPath}?capability=future_mirror&'
        'return_to=${Uri.encodeQueryComponent('https://provider.example')}',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('membership-choose-premium')), findsNothing);
      expect(find.textContaining('provider.example'), findsNothing);

      router.go('${MemberRoutes.youMembershipPath}/checkout/not-a-uuid');
      await tester.pumpAndSettle();
      expect(router.state.uri.path, MemberRoutes.youMembershipPath);
      expect(find.textContaining('not-a-uuid'), findsNothing);
    },
  );

  test('membership route builders reject external and malformed context', () {
    expect(
      () => MemberRoutes.membershipLocation(
        capabilityCode: 'future_mirror',
        returnLocation: 'https://provider.example',
      ),
      throwsArgumentError,
    );
    expect(
      () => MemberRoutes.membershipCheckoutLocation('not-a-uuid'),
      throwsArgumentError,
    );
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

  testWidgets(
    'U7 portfolio A to B order route never leaks labeled asset state',
    (tester) async {
      const assetA = '00000000-0000-4000-8000-000000000701';
      const assetB = '00000000-0000-4000-8000-000000000702';
      final container = fixtureContainer(includeU7: true);
      await tester.pumpWidget(RitualInvestingApp(container: container));
      await tester.pumpAndSettle();
      final router = GoRouter.of(
        tester.element(find.byKey(const Key('app-shell-scaffold'))),
      );

      router.go(
        MemberRoutes.portfolioOrdersLocation(
          'portfolio-a',
          assetId: assetA,
          symbol: 'AAA',
        ),
      );
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/you/portfolios/portfolio-a/orders');
      expect(find.text('AAA · from Asset Codex'), findsOneWidget);

      router.go(
        MemberRoutes.portfolioOrdersLocation(
          'portfolio-b',
          assetId: assetB,
          symbol: 'BBB',
        ),
      );
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/you/portfolios/portfolio-b/orders');
      expect(find.text('BBB · from Asset Codex'), findsOneWidget);
      expect(find.text('AAA · from Asset Codex'), findsNothing);
      expect(container.orderController.operation, 'order.commit:portfolio-b');
    },
  );

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

class _SignedOutSessionRepository implements SessionRepository {
  _SignedOutSessionRepository({this.authenticationError});

  final Object? authenticationError;
  final List<MemberAuthIntent> intents = [];
  @override
  MemberClientExpectation get memberClientExpectation =>
      const MemberClientExpectation(issuer: 'https://member-auth.test/auth/v1');
  @override
  Stream<AuthSession> get recoveredSessions => const Stream.empty();
  @override
  Future<AuthSession> authenticate(MemberAuthIntent intent) async {
    intents.add(intent);
    final error = authenticationError;
    if (error != null) throw error;
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

class _RouterPrivacyRepository implements PrivacyRepository {
  @override
  Future<void> clearStaleLocalFiles() async {}
  @override
  Future<bool> accountInactive() async => false;
  @override
  Future<void> cancelAndClearLocal() async {}
  @override
  Future<void> downloadAndShare(String requestId) async {}
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
  Future<PrivacyDeletionReceipt> requestDeletion(String idempotencyKey) =>
      throw StateError('unused');
  @override
  Future<DemoResetReceipt> resetDemo(int seedVersion, String idempotencyKey) =>
      throw StateError('unused');
  @override
  Future<String?> restoreExportId() async => null;
}
