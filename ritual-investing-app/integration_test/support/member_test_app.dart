import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ritual_investing_api_client/ritual_investing_api_client.dart';
import 'package:ritual_investing_api_client/ritual_auth_interceptor.dart';
import 'package:ritual_investing_app/core/api/pending_command_store.dart';
import 'package:ritual_investing_app/core/api/ritual_api.dart';
import 'package:ritual_investing_app/core/auth/auth_controller.dart';
import 'package:ritual_investing_app/core/auth/member_auth.dart';
import 'package:ritual_investing_app/core/bootstrap/dependency_container.dart';
import 'package:ritual_investing_app/core/bootstrap/entry_coordinator.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/coven/application/controller.dart';
import 'package:ritual_investing_app/features/coven/data/repository.dart';
import 'package:ritual_investing_app/features/discover/application/controller.dart';
import 'package:ritual_investing_app/features/discover/data/repository.dart';
import 'package:ritual_investing_app/features/onboarding/application/onboarding_controller.dart';
import 'package:ritual_investing_app/features/onboarding/data/onboarding_draft_store.dart';
import 'package:ritual_investing_app/features/onboarding/data/onboarding_repository.dart';
import 'package:ritual_investing_app/features/portfolio/application/controller.dart';
import 'package:ritual_investing_app/features/portfolio/data/repository.dart';
import 'package:ritual_investing_app/features/profile/application/controller.dart';
import 'package:ritual_investing_app/features/profile/data/repository.dart';
import 'package:ritual_investing_app/features/ritual/application/daily_ritual_controller.dart';
import 'package:ritual_investing_app/features/ritual/data/daily_ritual_repository.dart';

class MemberTestHarness {
  MemberTestHarness._({required this.container, required this._server});

  static const _accountId = '00000000-0000-4000-8000-000000000001';
  static const _accessToken = 'local-member-access-token';

  final HttpServer _server;
  final DependencyContainer container;
  String? lastAuthorization;
  String get accountId => _accountId;

  static Future<MemberTestHarness> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final repository = _LocalMemberSessionRepository();
    final auth = AuthController(repository: repository);
    final client = RitualInvestingApiClient(
      basePathOverride: 'http://${server.address.address}:${server.port}',
      interceptors: [RitualAuthInterceptor(tokenProvider: auth)],
    );
    final storage = _LocalProtectedStorage();
    final container = DependencyContainer(
      authController: auth,
      sessionBootstrapService: GeneratedSessionBootstrapService(client),
      cacheStorage: MemoryReadCache(),
      pendingCommandStore: PendingCommandStore(storage: storage),
      featureScopeFactory: (_, _, _) => throw StateError(
        'The onboarding gate must not construct member feature fixtures.',
      ),
    );
    final harness = MemberTestHarness._(server: server, container: container);
    unawaited(harness._serve());
    return harness;
  }

  Future<void> _serve() async {
    await for (final request in _server) {
      lastAuthorization = request.headers.value(
        HttpHeaders.authorizationHeader,
      );
      if (request.method == 'POST' &&
          request.uri.path == '/v1/session/bootstrap') {
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(_bootstrapResponse));
        await request.response.close();
        continue;
      }
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    }
  }

  Future<void> close() => _server.close(force: true);

  static const Map<String, Object?> _bootstrapResponse = {
    'data': {
      'account': {'id': _accountId, 'status': 'active'},
      'astrology_profile': null,
      'contract_version': '1.0.0',
      'default_portfolio': {
        'currency': 'USD',
        'id': '00000000-0000-4000-8000-000000000002',
        'name': 'Local Demo Portfolio',
        'status': 'active',
        'version': 1,
      },
      'entitlement': {'plan_code': 'demo-free', 'status': 'active'},
      'investor_profile': null,
      'onboarding': {
        'cohort': 'member_v2',
        'completed_at': null,
        'completed_steps': <String>[],
        'current_step': 'welcome',
        'schema_version': 2,
        'version': 1,
      },
      'preferences': {
        'locale': 'en-US',
        'ritual_familiarity': null,
        'ritual_interests': null,
        'ritual_language': null,
        'ritual_mode': 'tarot',
        'theme_mode': 'system',
        'timezone': 'UTC',
        'version': 1,
      },
      'profile': {'display_name': 'Local Member', 'locale': 'en-US'},
      'reset_generation': 0,
      'server_time': '2026-08-24T12:00:00.000Z',
    },
    'meta': {'request_id': '00000000-0000-4000-8000-000000000003'},
  };
}

class GuidedMemberTestHarness {
  GuidedMemberTestHarness._(
    this.container,
    this._server,
    this._storage,
    this._sessions,
    bool initiallyComplete,
    this._failFirstFinalize,
  ) : _complete = initiallyComplete;

  static const _accountId = '00000000-0000-4000-8000-000000000011';
  static const _accessToken = 'guided-member-access-token';

  final DependencyContainer container;
  final HttpServer _server;
  final _LocalProtectedStorage _storage;
  final _GuidedSessionRepository _sessions;
  final bool _failFirstFinalize;
  bool _complete;
  int _finalizeAttempts = 0;
  final List<String> requestPaths = [];
  final List<String?> authorizationHeaders = [];
  final List<Map<String, dynamic>> finalizationPayloads = [];
  final List<String> idempotencyKeys = [];

  List<MemberAuthIntent> get authIntents =>
      List.unmodifiable(_sessions.intents);
  Map<String, String> get protectedValues => Map.unmodifiable(_storage.values);
  List<String> get financeOrBankingRequests => requestPaths
      .where(
        (path) => RegExp(
          r'bank|finance|plaid|broker|payment',
          caseSensitive: false,
        ).hasMatch(path),
      )
      .toList(growable: false);

  bool get hasProhibitedPersonalizationKeys =>
      finalizationPayloads.any((payload) => _containsProhibitedKey(payload));

  bool get allProtectedRequestsAuthorized {
    if (requestPaths.isEmpty ||
        requestPaths.length != authorizationHeaders.length) {
      return false;
    }
    for (var index = 0; index < requestPaths.length; index += 1) {
      if (!const {
            '/v1/session/bootstrap',
            '/v1/session/onboarding/finalize',
            '/v1/rituals/daily',
          }.contains(requestPaths[index]) ||
          authorizationHeaders[index] != 'Bearer $_accessToken') {
        return false;
      }
    }
    return true;
  }

  String get safeAuthorizationAudit => List.generate(
    requestPaths.length,
    (index) =>
        '${requestPaths[index]}:'
        '${authorizationHeaders[index] == 'Bearer $_accessToken' ? 'authorized' : 'missing-or-invalid'}',
  ).join(', ');

  static Future<GuidedMemberTestHarness> start({
    bool initiallyComplete = false,
    bool failFirstFinalize = false,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final sessions = _GuidedSessionRepository();
    final auth = AuthController(repository: sessions);
    final client = RitualInvestingApiClient(
      basePathOverride: 'http://${server.address.address}:${server.port}',
      interceptors: [RitualAuthInterceptor(tokenProvider: auth)],
    );
    final storage = _LocalProtectedStorage();
    final bootstrap = GeneratedSessionBootstrapService(client);
    final coordinator = EntryCoordinator(
      authController: auth,
      bootstrapService: bootstrap,
      draftStore: OnboardingDraftStore(
        storage: storage,
        installation: const FixedInstallationBinding('guided-install'),
        now: () => DateTime.utc(2026, 8, 25, 12),
      ),
      onboardingRepository: GeneratedOnboardingRepository(client),
    );
    final container = DependencyContainer(
      authController: auth,
      sessionBootstrapService: bootstrap,
      cacheStorage: MemoryReadCache(),
      pendingCommandStore: PendingCommandStore(storage: storage),
      entryCoordinator: coordinator,
      onboardingController: OnboardingController(
        now: () => DateTime.utc(2026, 8, 25, 12),
      ),
      featureScopeFactory: (scope, cache, bootstrap) => MemberFeatureScope(
        scope: scope,
        dailyRitualController: DailyRitualController(
          repository: DailyRitualRepository(
            service: GeneratedRitualApiService(client),
            cache: cache,
          ),
        ),
        discoverController: DiscoverController(
          repository: CachedDiscoverRepository(
            service: GeneratedDiscoverApiService(client),
            cache: cache,
          ),
          personalization: bootstrap.personalization,
        ),
        covenController: CovenController(
          repository: CachedCovenRepository(
            service: GeneratedCovenApiService(client),
            cache: cache,
          ),
        ),
        profileController: ProfileController(
          repository: CachedProfileRepository(
            service: GeneratedProfileApiService(client),
            cache: cache,
          ),
        ),
        portfolioController: PortfolioController(
          repository: CachedPortfolioRepository(
            service: GeneratedPortfolioApiService(client),
            cache: cache,
          ),
        ),
      ),
    );
    final harness = GuidedMemberTestHarness._(
      container,
      server,
      storage,
      sessions,
      initiallyComplete,
      failFirstFinalize,
    );
    unawaited(harness._serve());
    return harness;
  }

  Future<void> _serve() async {
    await for (final request in _server) {
      requestPaths.add(request.uri.path);
      authorizationHeaders.add(
        request.headers.value(HttpHeaders.authorizationHeader),
      );
      request.response.headers.contentType = ContentType.json;
      if (request.method == 'POST' &&
          request.uri.path == '/v1/session/bootstrap') {
        request.response.write(jsonEncode(_bootstrapResponse(_complete)));
      } else if (request.method == 'POST' &&
          request.uri.path == '/v1/session/onboarding/finalize') {
        _finalizeAttempts += 1;
        final payload = jsonDecode(
          await utf8.decoder.bind(request).join(),
        ) as Map<String, dynamic>;
        finalizationPayloads.add(payload);
        idempotencyKeys.add(request.headers.value('idempotency-key')!);
        if (_failFirstFinalize && _finalizeAttempts == 1) {
          request.response.statusCode = HttpStatus.serviceUnavailable;
          request.response.write(
            jsonEncode({
              'error': {
                'code': 'service_unavailable',
                'message': 'Retry the same reviewed command.',
              },
            }),
          );
        } else {
          _complete = true;
          request.response.write(jsonEncode(_bootstrapResponse(true)));
        }
      } else if (request.method == 'GET' &&
          request.uri.path == '/v1/rituals/daily') {
        request.response.write(jsonEncode(_dailyRitualResponse));
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write(
          jsonEncode({
            'error': {'code': 'resource_not_found', 'message': 'Not found'},
          }),
        );
      }
      await request.response.close();
    }
  }

  Future<void> close() => _server.close(force: true);

  static Map<String, Object?> _bootstrapResponse(bool complete) => {
    'data': {
      'account': {'id': _accountId, 'status': 'active'},
      'astrology_profile': null,
      'contract_version': '1.0.0',
      'default_portfolio': {
        'currency': 'USD',
        'id': '00000000-0000-4000-8000-000000000012',
        'name': 'Guided Demo Portfolio',
        'status': 'active',
        'version': 1,
      },
      'entitlement': {'plan_code': 'demo-free', 'status': 'active'},
      'investor_profile': complete
          ? {
              'contribution_rhythm': 'monthly',
              'experience': 'new',
              'goal_type': 'long_term_growth',
              'is_demo': true,
              'risk_comfort': 'moderate',
              'time_horizon': 'long',
              'version': 1,
            }
          : null,
      'onboarding': {
        'cohort': 'member_v2',
        'completed_at': complete ? '2026-08-25T12:00:00.000Z' : null,
        'completed_steps': complete
            ? ['welcome', 'profile', 'ritual', 'consents']
            : <String>[],
        'current_step': complete ? 'complete' : 'preferences',
        'schema_version': 2,
        'version': complete ? 4 : 3,
      },
      'preferences': {
        'locale': 'en-US',
        'ritual_familiarity': complete ? 'curious' : null,
        'ritual_interests': complete ? ['practical_research'] : null,
        'ritual_language': complete ? 'practical' : null,
        'ritual_mode': 'tarot',
        'theme_mode': 'system',
        'timezone': 'UTC',
        'version': complete ? 4 : 3,
      },
      'profile': {'display_name': 'Guided Member', 'locale': 'en-US'},
      'reset_generation': 0,
      'server_time': '2026-08-25T12:00:00.000Z',
    },
    'meta': {'request_id': '00000000-0000-4000-8000-000000000013'},
  };
}

class _LocalMemberSessionRepository implements SessionRepository {
  @override
  MemberClientExpectation get memberClientExpectation =>
      const MemberClientExpectation(authorizedParty: 'local-member-client');

  @override
  Stream<AuthSession> get recoveredSessions => const Stream.empty();

  @override
  Future<AuthSession> authenticate(MemberAuthIntent intent) async =>
      const AuthSession(accessToken: MemberTestHarness._accessToken);

  @override
  Future<AuthSession?> recover() async =>
      const AuthSession(accessToken: MemberTestHarness._accessToken);

  @override
  Future<void> logout() async {}
}

class _LocalProtectedStorage implements ProtectedStorage {
  final Map<String, String> values = {};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<Map<String, String>> readAll() async => Map.of(values);

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class _GuidedSessionRepository implements SessionRepository {
  final List<MemberAuthIntent> intents = [];
  AuthSession? _session;

  @override
  MemberClientExpectation get memberClientExpectation =>
      const MemberClientExpectation(authorizedParty: 'guided-member-client');

  @override
  Stream<AuthSession> get recoveredSessions => const Stream.empty();

  @override
  Future<AuthSession> authenticate(MemberAuthIntent intent) async {
    intents.add(intent);
    return _session = const AuthSession(
      accessToken: GuidedMemberTestHarness._accessToken,
    );
  }

  @override
  Future<AuthSession?> recover() async => _session;

  @override
  Future<void> logout() async => _session = null;
}

bool _containsProhibitedKey(Object? value) {
  if (value is Map) {
    for (final entry in value.entries) {
      final key = entry.key.toString();
      if (const {
        'birth_time',
        'birth_place',
        'derived_profile',
        'derived_profile_code',
        'religion',
        'astrological_sign',
      }.contains(key)) {
        return true;
      }
      if (_containsProhibitedKey(entry.value)) return true;
    }
  } else if (value is Iterable) {
    return value.any(_containsProhibitedKey);
  }
  return false;
}

final _dailyRitualResponse = DailyRitualResponse(
  data: DailyRitualDetail(
    art: ArtReference(
      alt: 'The Compass at a celestial crossroads',
      key: ArtReferenceKeyEnum.theCompass,
    ),
    assignmentId: '00000000-0000-4000-8000-000000000021',
    completedAt: null,
    date: DateTime.utc(2026, 8, 25),
    demo: DemoDisclosure(
      isDemo: true,
      limitations: const [
        'Deterministic Demo data; prices and signals are fictional.',
      ],
      observedAt: DateTime.utc(2026, 8, 25, 12),
      sourceLabel: 'Guided integration fixture',
    ),
    evidence: [
      EvidenceSummary(
        claimId: '00000000-0000-4000-8000-000000000022',
        factorLabel: 'Durable momentum',
        observedAt: DateTime.utc(2026, 8, 25, 12),
        summary: 'Durable momentum in the deterministic Demo window.',
        uncertainty: 'Short windows can reverse.',
      ),
    ],
    guidance: 'Compare the evidence and decide what deserves attention.',
    ideas: [
      RitualAssetIdea(
        appearanceReason: 'steady wealth',
        assetId: '00000000-0000-4000-8000-000000000023',
        name: 'Dividend Demo ETF',
        riskSummary: 'It can decline.',
        symbol: 'VIG',
      ),
    ],
    interpretation: 'Direction, not urgency.',
    marketLabel: 'Market-informed Demo',
    mode: DailyRitualDetailModeEnum.tarot,
    revealedAt: null,
    revision: DailyRitualDetailRevision(
      id: '00000000-0000-4000-8000-000000000024',
      number: 1,
    ),
    rowan: RowanCounsel(
      body: 'You decide what to explore.',
      riskFooter: 'Demo only; not investment advice.',
      scriptRevisionId: '00000000-0000-4000-8000-000000000025',
      surface: RowanCounselSurfaceEnum.dailyRitual,
    ),
    state: DailyRitualDetailStateEnum.assigned,
    title: 'Direction, not urgency.',
    version: 1,
  ),
  meta: ResponseMeta(requestId: '00000000-0000-4000-8000-000000000026'),
).toJson();
