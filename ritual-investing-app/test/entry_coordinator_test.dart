import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/api/pending_command_store.dart';
import 'package:ritual_investing_app/core/api/ritual_api.dart';
import 'package:ritual_investing_app/core/auth/auth_controller.dart';
import 'package:ritual_investing_app/core/auth/member_auth.dart';
import 'package:ritual_investing_app/core/bootstrap/entry_coordinator.dart';
import 'package:ritual_investing_app/core/bootstrap/member_bootstrap.dart';
import 'package:ritual_investing_app/features/onboarding/data/onboarding_draft_store.dart';
import 'package:ritual_investing_app/features/onboarding/data/onboarding_repository.dart';
import 'package:ritual_investing_app/features/onboarding/domain/onboarding_draft.dart';

void main() {
  test(
    'completed authenticated account discards a stale anonymous draft',
    () async {
      final fixture = await _fixture(
        restoredSession: const AuthSession(accessToken: 'token'),
        bootstraps: [_bootstrap(complete: true, version: 2)],
      );
      await fixture.store.save(_draft());

      await fixture.coordinator.restore();

      expect(fixture.coordinator.state.destination, EntryDestination.shell);
      expect((await fixture.store.read()).status, DraftReadStatus.empty);
      expect(fixture.applied.single.onboarding.isComplete, isTrue);
      expect(fixture.finalization.commands, isEmpty);
    },
  );

  test(
    'returning sign in bypasses questionnaire for incomplete accounts',
    () async {
      final sessions = _SessionRepository(restoredSession: null);
      final fixture = await _fixture(
        sessionRepository: sessions,
        bootstraps: [_bootstrap(complete: false, version: 4)],
      );

      await fixture.coordinator.signInWithPassword(
        email: 'beta@example.com',
        password: 'correct horse battery staple',
      );

      expect(sessions.passwordSignIns, [
        (email: 'beta@example.com', password: 'correct horse battery staple'),
      ]);
      expect(
        fixture.coordinator.state.destination,
        EntryDestination.authenticatedRecovery,
      );
    },
  );

  test('password sign in preserves the actionable auth failure', () async {
    final sessions = _SessionRepository(
      restoredSession: null,
      authenticationError: const MemberAuthUnavailable('email_not_confirmed'),
    );
    final fixture = await _fixture(sessionRepository: sessions, bootstraps: []);

    await fixture.coordinator.signInWithPassword(
      email: 'beta@example.com',
      password: 'correct horse battery staple',
    );

    expect(fixture.coordinator.state.destination, EntryDestination.failure);
    expect(
      fixture.coordinator.state.message,
      'Confirm your email before signing in.',
    );
  });

  test(
    'Auth cancellation returns to editable review with draft intact',
    () async {
      final sessions = _SessionRepository(
        restoredSession: null,
        authenticationError: const MemberAuthCancelled(),
      );
      final fixture = await _fixture(
        sessionRepository: sessions,
        bootstraps: [],
      );

      await fixture.coordinator.createAccountWithPassword(
        reviewedDraft: _draft(),
        email: 'new-member@example.com',
        password: 'correct horse battery staple',
      );

      expect(fixture.coordinator.state.destination, EntryDestination.review);
      expect(fixture.coordinator.state.message, isNull);
      expect((await fixture.store.read()).draft, _draft());
    },
  );

  test(
    'conflict refetch preserves draft and retry uses the same key',
    () async {
      final finalization = _FinalizationRepository([
        const OnboardingFinalizationException(OnboardingFailureKind.conflict),
        _bootstrap(complete: true, version: 6),
      ]);
      final fixture = await _fixture(
        restoredSession: const AuthSession(accessToken: 'token'),
        bootstraps: [
          _bootstrap(complete: false, version: 5),
          _bootstrap(complete: false, version: 5),
        ],
        finalization: finalization,
      );
      await fixture.store.save(_draft());
      await fixture.coordinator.restore();

      await fixture.coordinator.attachDraft();
      expect(fixture.coordinator.state.destination, EntryDestination.reconcile);
      expect(fixture.coordinator.state.canRetry, isTrue);
      expect((await fixture.store.read()).status, DraftReadStatus.available);

      await fixture.coordinator.attachDraft();
      expect(fixture.coordinator.state.destination, EntryDestination.shell);
      expect(finalization.commands, hasLength(2));
      expect(
        finalization.commands.first.idempotencyKey,
        finalization.commands.last.idempotencyKey,
      );
      expect(
        finalization.commands.first.canonicalPayloadHash,
        finalization.commands.last.canonicalPayloadHash,
      );
      expect((await fixture.store.read()).status, DraftReadStatus.empty);
    },
  );

  test('completed bootstrap wins when protected draft cleanup fails', () async {
    final fixture = await _fixture(
      restoredSession: const AuthSession(accessToken: 'token'),
      bootstraps: [_bootstrap(complete: true, version: 2)],
    );
    await fixture.store.save(_draft());
    fixture.storage.deleteError = const ProtectedStorageLocked();

    await expectLater(fixture.coordinator.restore(), completes);

    expect(fixture.coordinator.state.destination, EntryDestination.shell);
    expect(fixture.coordinator.state.draft, isNull);
    expect(fixture.applied.single.canEnterMemberShell, isTrue);
  });

  test('completed finalization wins when protected cleanup fails', () async {
    final fixture = await _fixture(
      restoredSession: const AuthSession(accessToken: 'token'),
      bootstraps: [_bootstrap(complete: false, version: 1)],
      finalization: _FinalizationRepository([
        _bootstrap(complete: true, version: 2),
      ]),
    );
    await fixture.store.save(_draft());
    await fixture.coordinator.restore();
    fixture.storage.deleteError = const ProtectedStorageLocked();

    await expectLater(fixture.coordinator.attachDraft(), completes);

    expect(fixture.coordinator.state.destination, EntryDestination.shell);
    expect(fixture.coordinator.state.draft, isNull);
  });

  test('logout still clears authority when protected cleanup fails', () async {
    final sessions = _SessionRepository(
      restoredSession: const AuthSession(accessToken: 'token'),
    );
    final fixture = await _fixture(
      sessionRepository: sessions,
      bootstraps: [_bootstrap(complete: true, version: 2)],
    );
    await fixture.coordinator.restore();
    fixture.storage.deleteError = const ProtectedStorageLocked();

    await expectLater(fixture.coordinator.logout(), completes);

    expect(sessions.logoutCalls, 1);
    expect(fixture.coordinator.state.destination, EntryDestination.welcome);
    expect(fixture.coordinator.state.bootstrap, isNull);
  });

  test(
    'questionnaire save failure preserves editable in-memory answers',
    () async {
      final fixture = await _fixture(bootstraps: []);
      fixture.storage.writeError = const ProtectedStorageLocked();

      await expectLater(
        fixture.coordinator.beginQuestionnaire(_draft()),
        completes,
      );

      expect(
        fixture.coordinator.state.destination,
        EntryDestination.questionnaire,
      );
      expect(fixture.coordinator.state.draft, _draft());
      expect(fixture.coordinator.state.message, contains('device'));
      expect(fixture.coordinator.state.canRetry, isTrue);
    },
  );

  test('review save failure does not launch hosted sign-up', () async {
    final sessions = _SessionRepository(restoredSession: null);
    final fixture = await _fixture(sessionRepository: sessions, bootstraps: []);
    fixture.storage.writeError = const ProtectedStorageLocked();

    await expectLater(
      fixture.coordinator.createAccountWithPassword(
        reviewedDraft: _draft(),
        email: 'new-member@example.com',
        password: 'correct horse battery staple',
      ),
      completes,
    );

    expect(fixture.coordinator.state.destination, EntryDestination.review);
    expect(fixture.coordinator.state.draft, _draft());
    expect(fixture.coordinator.state.message, contains('device'));
    expect(sessions.passwordSignUps, isEmpty);
  });

  test('discard failure becomes a safe actionable state', () async {
    final fixture = await _fixture(bootstraps: []);
    await fixture.coordinator.beginQuestionnaire(_draft());
    fixture.storage.deleteError = const ProtectedStorageLocked();

    await expectLater(fixture.coordinator.discardDraft(), completes);

    expect(fixture.coordinator.state.destination, EntryDestination.failure);
    expect(fixture.coordinator.state.canRetry, isTrue);
    expect(fixture.coordinator.state.message, contains('discard'));
  });

  test(
    'completed server response contains local bootstrap apply failure',
    () async {
      var applyFails = true;
      final fixture = await _fixture(
        restoredSession: const AuthSession(accessToken: 'token'),
        bootstraps: [_bootstrap(complete: false, version: 1)],
        finalization: _FinalizationRepository([
          _bootstrap(complete: true, version: 2),
        ]),
        applyBootstrap: (value) async {
          if (applyFails && value?.onboarding.isComplete == true) {
            throw StateError('local scope unavailable');
          }
        },
      );
      await fixture.store.save(_draft());
      await fixture.coordinator.restore();

      await expectLater(fixture.coordinator.attachDraft(), completes);

      expect(fixture.coordinator.state.destination, EntryDestination.reconcile);
      expect(fixture.coordinator.state.draft, _draft());
      expect(fixture.coordinator.state.canRetry, isTrue);
      expect(fixture.coordinator.state.message, contains('prepare'));

      applyFails = false;
      await fixture.coordinator.attachDraft();
      expect(fixture.coordinator.state.destination, EntryDestination.shell);
      expect(fixture.coordinator.state.draft, isNull);
    },
  );

  test(
    'unexpected finalization failure remains handled and retryable',
    () async {
      final fixture = await _fixture(
        restoredSession: const AuthSession(accessToken: 'token'),
        bootstraps: [_bootstrap(complete: false, version: 1)],
        finalization: _FinalizationRepository([StateError('unexpected')]),
      );
      await fixture.store.save(_draft());
      await fixture.coordinator.restore();

      await expectLater(fixture.coordinator.attachDraft(), completes);

      expect(fixture.coordinator.state.destination, EntryDestination.reconcile);
      expect(fixture.coordinator.state.draft, _draft());
      expect(fixture.coordinator.state.canRetry, isTrue);
    },
  );

  test(
    'settings refresh applies a new authoritative completed bootstrap',
    () async {
      final fixture = await _fixture(
        restoredSession: const AuthSession(accessToken: 'token'),
        bootstraps: [
          _bootstrap(complete: true, version: 2),
          _bootstrap(
            complete: true,
            version: 2,
            theme: MemberThemePreference.dark,
          ),
        ],
      );
      await fixture.coordinator.restore();

      await fixture.coordinator.refreshCompletedBootstrap();

      expect(fixture.coordinator.state.destination, EntryDestination.shell);
      expect(
        fixture.coordinator.state.bootstrap?.themePreference,
        MemberThemePreference.dark,
      );
      expect(fixture.applied.last.themePreference, MemberThemePreference.dark);
    },
  );

  test(
    'cold and warm Webull links redeem then refetch without UI token state',
    () async {
      const cold = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQ';
      const warm = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopq';
      final links = StreamController<Uri>();
      addTearDown(links.close);
      final fixture = await _fixture(
        restoredSession: const AuthSession(accessToken: 'token'),
        bootstraps: [
          _bootstrap(complete: true, version: 2),
          _bootstrap(complete: true, version: 2),
          _bootstrap(complete: true, version: 2),
        ],
      );
      final redeemed = <String>[];
      fixture.coordinator.bindBrokerageNativeLinks(
        policy: MemberNativeLinkPolicy.parse(
          argusAuthAllowlist:
              'https://just-build-this.app/mobile/argus-auth/callback',
          webullCompletionAllowlist:
              'https://just-build-this.app/mobile/webull/complete',
        ),
        initialLink: () async => Uri.https(
          'just-build-this.app',
          '/mobile/webull/complete',
          {'completion': cold},
        ),
        links: links.stream,
        redeemCompletion: (completion) async => redeemed.add(completion),
      );

      await fixture.coordinator.restore();
      links.add(
        Uri.https('just-build-this.app', '/mobile/webull/complete', {
          'completion': warm,
        }),
      );
      await pumpEventQueue();

      expect(redeemed, [cold, warm]);
      expect(fixture.applied, hasLength(3));
      expect(fixture.coordinator.state.destination, EntryDestination.shell);
      expect(fixture.coordinator.state.message, isNot(contains(cold)));
      expect(fixture.coordinator.state.message, isNot(contains(warm)));
    },
  );
}

Future<_Fixture> _fixture({
  AuthSession? restoredSession,
  _SessionRepository? sessionRepository,
  required List<MemberBootstrap> bootstraps,
  _FinalizationRepository? finalization,
  ApplyMemberBootstrap? applyBootstrap,
}) async {
  final storage = _MemoryProtectedStorage();
  final store = OnboardingDraftStore(
    storage: storage,
    installation: const FixedInstallationBinding('install-a'),
    now: () => DateTime.utc(2026, 8, 24, 12),
  );
  final applied = <MemberBootstrap>[];
  final repository = finalization ?? _FinalizationRepository(const []);
  final coordinator = EntryCoordinator(
    authController: AuthController(
      repository:
          sessionRepository ??
          _SessionRepository(restoredSession: restoredSession),
    ),
    bootstrapService: _BootstrapService(bootstraps),
    draftStore: store,
    onboardingRepository: repository,
    applyBootstrap:
        applyBootstrap ??
        (value) async {
          if (value != null) applied.add(value);
        },
  );
  addTearDown(coordinator.dispose);
  return _Fixture(coordinator, store, storage, repository, applied);
}

class _Fixture {
  const _Fixture(
    this.coordinator,
    this.store,
    this.storage,
    this.finalization,
    this.applied,
  );
  final EntryCoordinator coordinator;
  final OnboardingDraftStore store;
  final _MemoryProtectedStorage storage;
  final _FinalizationRepository finalization;
  final List<MemberBootstrap> applied;
}

class _SessionRepository
    implements SessionRepository, PasswordSessionRepository {
  _SessionRepository({required this.restoredSession, this.authenticationError});
  final AuthSession? restoredSession;
  final Object? authenticationError;
  final List<({String email, String password})> passwordSignIns = [];
  final List<({String email, String password})> passwordSignUps = [];
  int logoutCalls = 0;

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
    passwordSignIns.add((email: email, password: password));
    final error = authenticationError;
    if (error != null) throw error;
    return const AuthSession(accessToken: 'token');
  }

  @override
  Future<AuthSession> signUpWithPassword({
    required String email,
    required String password,
  }) async {
    passwordSignUps.add((email: email, password: password));
    final error = authenticationError;
    if (error != null) throw error;
    return const AuthSession(accessToken: 'token');
  }

  @override
  Future<AuthSession?> recover() async => restoredSession;
  @override
  Future<void> logout() async => logoutCalls++;
}

class _BootstrapService implements SessionBootstrapService {
  _BootstrapService(this.results);
  final List<MemberBootstrap> results;
  int index = 0;
  @override
  Future<MemberBootstrap> bootstrap() async => results[index++];
}

class _FinalizationRepository implements OnboardingRepository {
  _FinalizationRepository(this.results);
  final List<Object> results;
  final List<OnboardingFinalizationCommand> commands = [];
  int index = 0;
  @override
  Future<MemberBootstrap> finalize(
    OnboardingFinalizationCommand command,
  ) async {
    commands.add(command);
    final result = results[index++];
    if (result is! MemberBootstrap) throw result;
    return result;
  }
}

class _MemoryProtectedStorage implements ProtectedStorage {
  final Map<String, String> values = {};
  Object? writeError;
  Object? deleteError;
  @override
  Future<void> delete(String key) async {
    final error = deleteError;
    if (error != null) throw error;
    values.remove(key);
  }

  @override
  Future<Map<String, String>> readAll() async => Map.of(values);
  @override
  Future<void> write(String key, String value) async {
    final error = writeError;
    if (error != null) throw error;
    values[key] = value;
  }
}

MemberBootstrap _bootstrap({
  required bool complete,
  required int version,
  MemberThemePreference theme = MemberThemePreference.system,
}) => MemberBootstrap(
  accountId: 'account-a',
  resetGeneration: 0,
  onboarding: complete
      ? MemberOnboardingGate.complete(version: version)
      : MemberOnboardingGate.incomplete(nextStep: 'profile', version: version),
  entitlement: const MemberEntitlement(
    planCode: 'demo-free',
    status: MemberEntitlementStatus.active,
  ),
  defaultPortfolioId: 'portfolio-a',
  serverTime: DateTime.utc(2026, 8, 24, 12),
  contractVersion: '1.0.0',
  themePreference: theme,
);

OnboardingDraft _draft() => const OnboardingDraft(
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
