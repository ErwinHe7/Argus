import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/api/view_state.dart';
import 'package:ritual_investing_app/core/api/ritual_api.dart';
import 'package:ritual_investing_app/core/api/pending_command_store.dart';
import 'package:ritual_investing_app/core/bootstrap/dependency_container.dart';
import 'package:ritual_investing_app/core/bootstrap/entry_coordinator.dart';
import 'package:ritual_investing_app/core/bootstrap/member_bootstrap.dart';
import 'package:ritual_investing_app/core/auth/auth_controller.dart';
import 'package:ritual_investing_app/core/auth/member_auth.dart';
import 'package:ritual_investing_app/core/cache/cache_entry.dart';
import 'package:ritual_investing_app/core/cache/cached_read.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/onboarding/domain/onboarding_draft.dart';
import 'package:ritual_investing_app/features/onboarding/data/onboarding_draft_store.dart';
import 'package:ritual_investing_app/features/onboarding/data/onboarding_repository.dart';
import 'package:ritual_investing_app/features/profile/domain/model.dart';

import 'support/fixture_services.dart';

void main() {
  test('legacy completion signals enter the shell without completed_at', () {
    expect(
      MemberOnboardingGate.fromServer(
        cohort: 'legacy_complete_v1',
        currentStep: 'profile',
        completedAt: null,
      ).isComplete,
      isTrue,
    );
    expect(
      MemberOnboardingGate.fromServer(
        cohort: 'member_v2',
        currentStep: 'complete',
        completedAt: null,
      ).isComplete,
      isTrue,
    );
  });

  test('unavailable entitlement gates an otherwise complete bootstrap', () {
    final envelope = MemberBootstrap(
      accountId: 'account-a',
      resetGeneration: 1,
      onboarding: const MemberOnboardingGate.complete(),
      entitlement: const MemberEntitlement(
        planCode: 'demo-free',
        status: MemberEntitlementStatus.unavailable,
      ),
      defaultPortfolioId: 'portfolio-a',
      serverTime: DateTime.utc(2026, 8, 24),
      contractVersion: '1.0.0',
      themePreference: MemberThemePreference.system,
    );

    expect(envelope.canEnterMemberShell, isFalse);
  });

  test(
    'authenticated bootstrap retains the immutable routing envelope',
    () async {
      final envelope = MemberBootstrap(
        accountId: 'account-a',
        resetGeneration: 7,
        onboarding: MemberOnboardingGate.incomplete(nextStep: 'preferences'),
        entitlement: MemberEntitlement(
          planCode: 'demo-free',
          status: MemberEntitlementStatus.active,
        ),
        defaultPortfolioId: 'portfolio-a',
        serverTime: DateTime.utc(2026, 8, 24, 12),
        contractVersion: '1.0.0',
        themePreference: MemberThemePreference.dark,
      );
      final container = fixtureContainer(
        sessionBootstrapService: _TrackingSessionBootstrapService(envelope),
      );

      await container.bootstrap();

      expect(container.memberBootstrap, same(envelope));
      expect(container.memberBootstrap?.canEnterMemberShell, isFalse);
      expect(container.memberBootstrap?.defaultPortfolioId, 'portfolio-a');
      expect(
        container.memberBootstrap?.themePreference,
        MemberThemePreference.dark,
      );
      expect(container.featureScope, isNull);
    },
  );

  test(
    'first authenticated bootstrap clears legacy Demo mutation state',
    () async {
      final cache = _TrackingCache();
      final sessionBootstrap = _TrackingSessionBootstrapService(
        completedBootstrap(),
      );
      final container = fixtureContainer(
        cache: cache,
        sessionBootstrapService: sessionBootstrap,
      );
      await container.bootstrap();
      await container.bootstrap();
      expect(cache.legacyClears, 1);
      expect(sessionBootstrap.calls, 2);
      expect(container.dailyRitualController.state.phase, LoadPhase.idle);
      expect(container.discoverController.state.phase, LoadPhase.idle);
      await container.ensureBranchLoaded(MemberBranch.ritual);
      expect(container.dailyRitualController.state.phase, LoadPhase.ready);
      expect(container.discoverController.state.phase, LoadPhase.idle);
      await container.ensureBranchLoaded(MemberBranch.discover);
      expect(
        container.discoverController.state.value?.items.first.title,
        'Quiet Power',
      );
    },
  );

  test('account bootstrap failure prevents account-scoped reads', () async {
    final cache = _TrackingCache();
    final container = fixtureContainer(
      cache: cache,
      sessionBootstrapService: _FailingSessionBootstrapService(),
    );

    await container.bootstrap();

    expect(container.authController.state.phase, AuthPhase.failure);
    expect(cache.legacyClears, 0);
    expect(container.featureScope, isNull);
  });

  test(
    'restoration gate clears when auth restore escapes unexpectedly',
    () async {
      final container = fixtureContainer(
        authController: _ThrowingRestoreAuthController(),
      );
      addTearDown(container.dispose);

      await expectLater(container.bootstrap(), throwsStateError);

      expect(container.entryGate, MemberEntryGate.signedOut);
    },
  );

  test(
    'account generation transition disposes scope before replacement',
    () async {
      final service = _SequenceSessionBootstrapService([
        completedBootstrap(resetGeneration: 0),
        completedBootstrap(resetGeneration: 1),
      ]);
      final container = fixtureContainer(sessionBootstrapService: service);
      await container.bootstrap();
      final oldScope = container.featureScope!;

      await container.bootstrap();

      expect(oldScope.isDisposed, isTrue);
      expect(container.featureScope, isNot(same(oldScope)));
      expect(container.activeCacheScope?.resetGeneration, 1);
    },
  );

  test(
    'same-scope bootstrap refresh updates active Discover personalization',
    () async {
      final service = _SequenceSessionBootstrapService([
        completedBootstrap(
          personalization: const MemberPersonalization(
            riskFraming: MemberRiskFraming.low,
            explanationDepth: MemberExplanationDepth.beginner,
            ritualVoice: MemberRitualVoice.practical,
          ),
        ),
        completedBootstrap(
          personalization: const MemberPersonalization(
            riskFraming: MemberRiskFraming.high,
            explanationDepth: MemberExplanationDepth.advanced,
            ritualVoice: MemberRitualVoice.mystical,
          ),
        ),
      ]);
      final container = fixtureContainer(sessionBootstrapService: service);
      await container.bootstrap();
      final scope = container.featureScope;

      await container.bootstrap();

      expect(container.featureScope, same(scope));
      expect(
        container.discoverController.personalization.riskFraming,
        MemberRiskFraming.high,
      );
      expect(
        container.discoverController.personalization.explanationDepth,
        MemberExplanationDepth.advanced,
      );
      expect(
        container.discoverController.personalization.ritualVoice,
        MemberRitualVoice.mystical,
      );
    },
  );

  test('investor edit refreshes same-scope Discover personalization', () async {
    final service = _SequenceSessionBootstrapService([
      completedBootstrap(
        personalization: const MemberPersonalization(
          riskFraming: MemberRiskFraming.low,
          explanationDepth: MemberExplanationDepth.beginner,
          ritualVoice: MemberRitualVoice.practical,
        ),
      ),
      completedBootstrap(
        personalization: const MemberPersonalization(
          riskFraming: MemberRiskFraming.high,
          explanationDepth: MemberExplanationDepth.advanced,
          ritualVoice: MemberRitualVoice.practical,
        ),
      ),
    ]);
    final container = fixtureContainer(sessionBootstrapService: service);
    await container.bootstrap();
    await container.ensureBranchLoaded(MemberBranch.you);
    final scope = container.featureScope;

    final saved = await container.updateMemberInvestor(
      const ProfileInvestorUpdate(
        experience: InvestingExperience.experienced,
        goal: InvestmentGoal.longTermGrowth,
        horizon: InvestmentHorizon.short,
        risk: RiskComfort.high,
        contributionRhythm: ContributionRhythm.monthly,
      ),
    );

    expect(saved, isTrue);
    expect(container.featureScope, same(scope));
    expect(
      container.discoverController.personalization.riskFraming,
      MemberRiskFraming.high,
    );
    expect(
      container.discoverController.personalization.explanationDepth,
      MemberExplanationDepth.advanced,
    );
  });

  test(
    'ritual voice edit refreshes practical to mystical in same scope',
    () async {
      final service = _SequenceSessionBootstrapService([
        completedBootstrap(
          personalization: const MemberPersonalization(
            ritualVoice: MemberRitualVoice.practical,
          ),
        ),
        completedBootstrap(
          personalization: const MemberPersonalization(
            ritualVoice: MemberRitualVoice.mystical,
          ),
        ),
      ]);
      final container = fixtureContainer(sessionBootstrapService: service);
      await container.bootstrap();
      await container.ensureBranchLoaded(MemberBranch.you);
      final scope = container.featureScope;

      final saved = await container.updateMemberPreferences(
        const ProfilePreferencesUpdate(
          expectedVersion: 1,
          ritualLanguage: RitualLanguage.mystical,
        ),
      );

      expect(saved, isTrue);
      expect(container.featureScope, same(scope));
      expect(
        container.discoverController.personalization.ritualVoice,
        MemberRitualVoice.mystical,
      );
    },
  );

  test(
    'saved investor edit reports bootstrap refresh failure authoritatively',
    () async {
      final service = _SequenceSessionBootstrapService([completedBootstrap()]);
      final container = fixtureContainer(sessionBootstrapService: service);
      await container.bootstrap();
      await container.ensureBranchLoaded(MemberBranch.you);

      final saved = await container.updateMemberInvestor(
        const ProfileInvestorUpdate(
          goal: InvestmentGoal.calmFund,
          horizon: InvestmentHorizon.long,
          risk: RiskComfort.low,
        ),
      );

      expect(saved, isFalse);
      expect(
        container.profileController.state.phase,
        LoadPhase.retryableFailure,
      );
      expect(
        container.profileController.message,
        'Saved on the server, but the app could not refresh. Try again to apply it here.',
      );
    },
  );

  test('account generation transition clears the old protected journal', () async {
    final storage = _TrackingProtectedStorage();
    final journal = PendingCommandStore(storage: storage);
    final service = _SequenceSessionBootstrapService([
      completedBootstrap(resetGeneration: 0),
      completedBootstrap(resetGeneration: 1),
    ]);
    final container = fixtureContainer(
      sessionBootstrapService: service,
      pendingCommandStore: journal,
    );
    await container.bootstrap();
    await journal.save(
      PendingCommand(
        scope: container.activeCacheScope!,
        operation: 'place_order',
        key: 'command-key',
        precondition: 'preview:4',
        canonicalPayloadHash:
            'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
        createdAt: DateTime.utc(2026, 8, 24),
      ),
    );

    await container.bootstrap();

    expect(storage.values, isEmpty);
  });

  test('logout fences member state when protected cleanup fails', () async {
    final repository = _SignedInSessionRepository();
    final container = fixtureContainer(
      sessionRepository: repository,
      pendingCommandStore: PendingCommandStore(
        storage: _FailingProtectedStorage(),
      ),
    );
    addTearDown(container.dispose);
    await container.bootstrap();
    final oldScope = container.featureScope!;

    await expectLater(container.logout(), completes);

    expect(oldScope.isDisposed, isTrue);
    expect(container.memberBootstrap, isNull);
    expect(container.featureScope, isNull);
    expect(container.entryGate, MemberEntryGate.signedOut);
    expect(repository.logoutCalls, 1);
  });

  test(
    'logout prevents an in-flight member read from recreating retired cache',
    () async {
      final cache = _TrackingCache();
      late ReadCache scopedCache;
      final fetchStarted = Completer<void>();
      final fetchResult = Completer<String>();
      final container = fixtureContainer(
        cache: cache,
        onScopedCacheCreated: (value) => scopedCache = value,
        sessionRepository: _SignedInSessionRepository(),
      );
      addTearDown(container.dispose);
      await container.bootstrap();
      final retiredScope = container.activeCacheScope!;

      final inFlightRead = cachedRead<String>(
        key: 'delayed-member-read',
        cache: scopedCache,
        fetch: () {
          fetchStarted.complete();
          return fetchResult.future;
        },
        now: () => DateTime.utc(2026, 8, 25, 12),
      );
      await fetchStarted.future;

      await container.logout();
      fetchResult.complete('retired account value');
      await inFlightRead;

      expect(
        cache.values.keys.where(
          (key) => key.startsWith(retiredScope.storagePrefix),
        ),
        isEmpty,
      );
    },
  );

  test(
    'logout resets account A answers before account B starts onboarding',
    () async {
      final storage = _TrackingProtectedStorage();
      final draftStore = OnboardingDraftStore(
        storage: storage,
        installation: const FixedInstallationBinding('install-a'),
        now: () => DateTime.utc(2026, 8, 24, 12),
      );
      final sessionRepository = _SignedInSessionRepository();
      final authController = AuthController(repository: sessionRepository);
      final bootstrapService = _TrackingSessionBootstrapService(
        _incompleteBootstrap(accountId: 'account-a'),
      );
      final coordinator = EntryCoordinator(
        authController: authController,
        bootstrapService: bootstrapService,
        draftStore: draftStore,
        onboardingRepository: _UnusedOnboardingRepository(),
      );
      final container = fixtureContainer(
        authController: authController,
        sessionBootstrapService: bootstrapService,
        entryCoordinator: coordinator,
      );
      addTearDown(coordinator.dispose);
      addTearDown(container.dispose);
      await draftStore.save(_reviewedOnboardingDraft());
      await container.bootstrap();
      expect(container.onboardingController.draft, _reviewedOnboardingDraft());

      await container.logout();

      expect(container.onboardingController.draft, const OnboardingDraft());
      await container.beginQuestionnaire();
      expect(coordinator.state.draft, const OnboardingDraft());
    },
  );

  test(
    'generation transition fences the old scope when protected cleanup fails',
    () async {
      final service = _SequenceSessionBootstrapService([
        completedBootstrap(resetGeneration: 0),
        completedBootstrap(resetGeneration: 1),
      ]);
      final container = fixtureContainer(
        sessionBootstrapService: service,
        pendingCommandStore: PendingCommandStore(
          storage: _FailingProtectedStorage(),
        ),
      );
      addTearDown(container.dispose);
      await container.bootstrap();
      final oldScope = container.featureScope!;

      await expectLater(container.bootstrap(), completes);

      expect(oldScope.isDisposed, isTrue);
      expect(container.activeCacheScope?.resetGeneration, 1);
      expect(container.entryGate, MemberEntryGate.member);
    },
  );

  test('process-death credential recovery resumes bootstrap once', () async {
    final repository = _RecoveringSessionRepository();
    final service = _TrackingSessionBootstrapService(completedBootstrap());
    final container = fixtureContainer(
      sessionRepository: repository,
      sessionBootstrapService: service,
    );
    addTearDown(container.dispose);

    await container.bootstrap();
    expect(container.entryGate, MemberEntryGate.signedOut);

    repository.emitRecovery();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(service.calls, 1);
    expect(container.entryGate, MemberEntryGate.member);
  });

  test('recovery queued during signed-out cleanup resumes bootstrap', () async {
    final repository = _SequencedRecoveryRepository([
      Future.value(const AuthSession(accessToken: 'access-token')),
      Future.value(null),
    ]);
    final cache = _BlockingScopeClearCache();
    final service = _TrackingSessionBootstrapService(completedBootstrap());
    final container = fixtureContainer(
      cache: cache,
      sessionRepository: repository,
      sessionBootstrapService: service,
    );
    addTearDown(container.dispose);
    await container.bootstrap();

    final restoration = container.bootstrap();
    await cache.clearEntered.future;
    repository.emitRecovery();
    cache.releaseClear.complete();
    await restoration;
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(service.calls, 2);
    expect(container.entryGate, MemberEntryGate.member);
  });

  test(
    'recovery consumed by normal restore does not double-bootstrap',
    () async {
      final pendingRestore = Completer<AuthSession?>();
      final repository = _SequencedRecoveryRepository([pendingRestore.future]);
      final service = _TrackingSessionBootstrapService(completedBootstrap());
      final container = fixtureContainer(
        sessionRepository: repository,
        sessionBootstrapService: service,
      );
      addTearDown(container.dispose);

      final restoration = container.bootstrap();
      repository.emitRecovery();
      pendingRestore.complete(null);
      await restoration;
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(service.calls, 1);
      expect(container.entryGate, MemberEntryGate.member);
    },
  );
}

class _TrackingSessionBootstrapService implements SessionBootstrapService {
  _TrackingSessionBootstrapService(this.result);

  final MemberBootstrap result;
  int calls = 0;

  @override
  Future<MemberBootstrap> bootstrap() async {
    calls++;
    return result;
  }
}

class _FailingSessionBootstrapService implements SessionBootstrapService {
  @override
  Future<MemberBootstrap> bootstrap() =>
      Future.error(StateError('bootstrap failed'));
}

class _SequenceSessionBootstrapService implements SessionBootstrapService {
  _SequenceSessionBootstrapService(this.values);
  final List<MemberBootstrap> values;
  int index = 0;

  @override
  Future<MemberBootstrap> bootstrap() async => values[index++];
}

class _RecoveringSessionRepository implements SessionRepository {
  final StreamController<AuthSession> _recoveries = StreamController.broadcast(
    sync: true,
  );

  @override
  MemberClientExpectation get memberClientExpectation =>
      const MemberClientExpectation(authorizedParty: 'member-client');

  @override
  Stream<AuthSession> get recoveredSessions => _recoveries.stream;

  void emitRecovery() =>
      _recoveries.add(const AuthSession(accessToken: 'recovered-access-token'));

  @override
  Future<AuthSession> authenticate(MemberAuthIntent intent) async =>
      const AuthSession(accessToken: 'access-token');

  @override
  Future<AuthSession?> recover() async => null;

  @override
  Future<void> logout() async {}
}

class _SequencedRecoveryRepository implements SessionRepository {
  _SequencedRecoveryRepository(this.recoveries);

  final List<Future<AuthSession?>> recoveries;
  final StreamController<AuthSession> _stream = StreamController.broadcast(
    sync: true,
  );
  int _recoveryIndex = 0;

  @override
  MemberClientExpectation get memberClientExpectation =>
      const MemberClientExpectation(authorizedParty: 'member-client');

  @override
  Stream<AuthSession> get recoveredSessions => _stream.stream;

  void emitRecovery() =>
      _stream.add(const AuthSession(accessToken: 'recovered-access-token'));

  @override
  Future<AuthSession> authenticate(MemberAuthIntent intent) async =>
      const AuthSession(accessToken: 'access-token');

  @override
  Future<AuthSession?> recover() => recoveries[_recoveryIndex++];

  @override
  Future<void> logout() async {}
}

class _SignedInSessionRepository implements SessionRepository {
  int logoutCalls = 0;

  @override
  MemberClientExpectation get memberClientExpectation =>
      const MemberClientExpectation(authorizedParty: 'member-client');

  @override
  Stream<AuthSession> get recoveredSessions => const Stream.empty();

  @override
  Future<AuthSession> authenticate(MemberAuthIntent intent) async =>
      const AuthSession(accessToken: 'access-token');

  @override
  Future<AuthSession?> recover() async =>
      const AuthSession(accessToken: 'access-token');

  @override
  Future<void> logout() async {
    logoutCalls++;
  }
}

class _ThrowingRestoreAuthController extends AuthController {
  _ThrowingRestoreAuthController()
    : super(repository: _SignedInSessionRepository());

  @override
  Future<void> restore() => Future.error(StateError('restore escaped'));
}

MemberBootstrap completedBootstrap({
  String accountId = 'fixture-account',
  int resetGeneration = 0,
  MemberPersonalization personalization = const MemberPersonalization(),
}) => MemberBootstrap(
  accountId: accountId,
  resetGeneration: resetGeneration,
  onboarding: const MemberOnboardingGate.complete(),
  entitlement: const MemberEntitlement(
    planCode: 'demo-free',
    status: MemberEntitlementStatus.active,
  ),
  defaultPortfolioId: 'fixture-portfolio',
  serverTime: DateTime.utc(2026, 8, 24),
  contractVersion: '1.0.0',
  themePreference: MemberThemePreference.system,
  personalization: personalization,
);

MemberBootstrap _incompleteBootstrap({required String accountId}) =>
    MemberBootstrap(
      accountId: accountId,
      resetGeneration: 0,
      onboarding: MemberOnboardingGate.incomplete(nextStep: 'profile'),
      entitlement: const MemberEntitlement(
        planCode: 'demo-free',
        status: MemberEntitlementStatus.active,
      ),
      defaultPortfolioId: 'fixture-portfolio',
      serverTime: DateTime.utc(2026, 8, 24),
      contractVersion: '1.0.0',
      themePreference: MemberThemePreference.system,
    );

OnboardingDraft _reviewedOnboardingDraft() => const OnboardingDraft(
  experience: InvestingExperience.newToInvesting,
  goal: InvestmentGoal.longTermGrowth,
  horizon: InvestmentHorizon.long,
  risk: RiskComfort.moderate,
  contributionRhythm: ContributionRhythm.monthly,
  ritualLanguage: RitualLanguage.practical,
  ritualFamiliarity: RitualFamiliarity.newToRitual,
  ritualInterests: {RitualInterest.practicalResearch},
  astrologyEnabled: false,
  termsAccepted: true,
  privacyAccepted: true,
  demoAccepted: true,
);

class _UnusedOnboardingRepository implements OnboardingRepository {
  @override
  Future<MemberBootstrap> finalize(OnboardingFinalizationCommand command) =>
      Future.error(StateError('Finalization is not used by this test.'));
}

class _TrackingCache implements ScopedReadCacheStorage {
  final Map<String, CacheEntry<Object>> values = {};
  int legacyClears = 0;
  @override
  Future<void> clearLegacyMutations() async {
    legacyClears++;
  }

  @override
  Future<CacheEntry<T>?> get<T>(String key) async {
    final value = values[key];
    return value == null
        ? null
        : CacheEntry(value: value.value as T, committedAt: value.committedAt);
  }

  @override
  Future<void> put<T>(String key, T value, DateTime committedAt) async {
    values[key] = CacheEntry<Object>(
      value: value as Object,
      committedAt: committedAt,
    );
  }

  @override
  Future<void> clearScope(CacheScope scope) async {
    values.removeWhere((key, _) => key.startsWith(scope.storagePrefix));
  }
}

class _BlockingScopeClearCache extends _TrackingCache {
  final Completer<void> clearEntered = Completer<void>();
  final Completer<void> releaseClear = Completer<void>();

  @override
  Future<void> clearScope(CacheScope scope) async {
    if (!clearEntered.isCompleted) clearEntered.complete();
    await releaseClear.future;
    await super.clearScope(scope);
  }
}

class _TrackingProtectedStorage implements ProtectedStorage {
  final Map<String, String> values = {};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<Map<String, String>> readAll() async => Map.of(values);

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class _FailingProtectedStorage implements ProtectedStorage {
  @override
  Future<void> delete(String key) => throw StateError('storage unavailable');

  @override
  Future<Map<String, String>> readAll() =>
      throw StateError('storage unavailable');

  @override
  Future<void> write(String key, String value) =>
      throw StateError('storage unavailable');
}
