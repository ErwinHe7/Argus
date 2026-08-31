import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ritual_investing_api_client/ritual_investing_api_client.dart';
import 'package:ritual_investing_api_client/ritual_auth_interceptor.dart';
import 'package:ritual_investing_app/core/api/pending_command_store.dart';
import 'package:ritual_investing_app/core/api/invalidation_bus.dart';
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
import 'package:ritual_investing_app/features/profile/application/controller.dart';
import 'package:ritual_investing_app/features/profile/data/repository.dart';
import 'package:ritual_investing_app/features/ritual/application/daily_ritual_controller.dart';
import 'package:ritual_investing_app/features/ritual/data/daily_ritual_repository.dart';
import 'package:ritual_investing_app/features/starpath/application/starpath_controller.dart';
import 'package:ritual_investing_app/features/starpath/data/generated_starpath_api_service.dart';
import 'package:ritual_investing_app/features/starpath/data/starpath_repository.dart';

class MemberTestHarness {
  MemberTestHarness._({required this.container, required this._server});

  static const _accountId = '00000000-0000-4000-8000-000000000001';
  static const _testIdentity = String.fromEnvironment(
    'RITUAL_MEMBER_TEST_ID',
    defaultValue: 'local-member',
  );
  static const _accessToken = '$_testIdentity:bootstrap';

  final HttpServer _server;
  final DependencyContainer container;
  String? lastAuthorization;
  String get accountId => _accountId;
  String get expectedAuthorization => 'Bearer $_accessToken';

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
      'astrology_profile': null,
      'branch_capabilities': {
        'schema_version': 'member-branch-capabilities-v1',
        'capability_version': 1,
        'environment': 'beta',
        'evaluated_at': '2026-08-24T12:00:00.000Z',
        'expires_at': '2026-08-24T12:05:00.000Z',
        'branches': ['ritual', 'starpath', 'discover', 'coven', 'you'],
      },
      'investor_profile': null,
      'member': {
        'created_at': '2026-08-24T11:00:00.000Z',
        'deletion_epoch': 0,
        'deletion_requested_at': null,
        'status': 'active',
        'updated_at': '2026-08-24T12:00:00.000Z',
        'user_id': _accountId,
      },
      'onboarding': {
        'completed_at': null,
        'completed_steps': <String>[],
        'current_step': 'welcome',
        'deletion_epoch': 0,
        'user_id': _accountId,
        'version': 1,
      },
      'preferences': {
        'deletion_epoch': 0,
        'locale': 'en-US',
        'ritual_mode': 'tarot',
        'theme_mode': 'system',
        'timezone': 'UTC',
        'user_id': _accountId,
        'version': 1,
      },
      'profile': {
        'avatar_media_id': null,
        'deletion_epoch': 0,
        'display_name': 'Local Member',
        'locale': 'en-US',
        'updated_at': '2026-08-24T12:00:00.000Z',
        'user_id': _accountId,
      },
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
  static const _testIdentity = String.fromEnvironment(
    'RITUAL_MEMBER_TEST_ID',
    defaultValue: 'local-member',
  );
  static const _accessToken = '$_testIdentity:onboarding';

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

  int get googleSignIns => _sessions.googleSignIns;
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
      featureScopeFactory: (scope, cache, bootstrap) {
        final invalidationBus = InvalidationBus();
        return MemberFeatureScope(
          scope: scope,
          dailyRitualController: DailyRitualController(
            repository: DailyRitualRepository(
              service: GeneratedRitualApiService(client),
              cache: cache,
            ),
          ),
          starpathController: StarpathController(
            repository: StarpathRepository(
              service: GeneratedStarpathApiService(client),
              cache: cache,
            ),
            createKey: () => 'guided-starpath-command-key',
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
          invalidationBus: invalidationBus,
        );
      },
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
      'astrology_profile': null,
      'branch_capabilities': {
        'schema_version': 'member-branch-capabilities-v1',
        'capability_version': 1,
        'environment': 'beta',
        'evaluated_at': '2026-08-25T12:00:00.000Z',
        'expires_at': '2026-08-25T12:05:00.000Z',
        'branches': ['ritual', 'starpath', 'discover', 'coven', 'you'],
      },
      'member': {
        'created_at': '2026-08-25T11:00:00.000Z',
        'deletion_epoch': 0,
        'deletion_requested_at': null,
        'status': 'active',
        'updated_at': '2026-08-25T12:00:00.000Z',
        'user_id': _accountId,
      },
      'investor_profile': complete
          ? {
              'deletion_epoch': 0,
              'goal_type': 'long_term_growth',
              'risk_comfort': 'moderate',
              'time_horizon': 'long',
              'user_id': _accountId,
              'version': 1,
            }
          : null,
      'onboarding': {
        'completed_at': complete ? '2026-08-25T12:00:00.000Z' : null,
        'completed_steps': complete
            ? ['welcome', 'profile', 'ritual', 'consents']
            : <String>[],
        'current_step': complete ? 'complete' : 'preferences',
        'deletion_epoch': 0,
        'user_id': _accountId,
        'version': complete ? 4 : 3,
      },
      'preferences': {
        'deletion_epoch': 0,
        'locale': 'en-US',
        'ritual_mode': 'tarot',
        'theme_mode': 'system',
        'timezone': 'UTC',
        'user_id': _accountId,
        'version': complete ? 4 : 3,
      },
      'profile': {
        'avatar_media_id': null,
        'deletion_epoch': 0,
        'display_name': 'Guided Member',
        'locale': 'en-US',
        'updated_at': '2026-08-25T12:00:00.000Z',
        'user_id': _accountId,
      },
      'server_time': '2026-08-25T12:00:00.000Z',
    },
    'meta': {'request_id': '00000000-0000-4000-8000-000000000013'},
  };
}

class _LocalMemberSessionRepository implements SessionRepository {
  @override
  MemberClientExpectation get memberClientExpectation =>
      const MemberClientExpectation(issuer: 'https://local-auth.test/auth/v1');

  @override
  Stream<AuthSession> get recoveredSessions => const Stream.empty();

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

class _GuidedSessionRepository
    implements SessionRepository, GoogleOAuthSessionRepository {
  int googleSignIns = 0;
  AuthSession? _session;

  @override
  MemberClientExpectation get memberClientExpectation =>
      const MemberClientExpectation(issuer: 'https://guided-auth.test/auth/v1');

  @override
  Stream<AuthSession> get recoveredSessions => const Stream.empty();

  @override
  Future<AuthSession?> signInWithGoogle() async {
    googleSignIns += 1;
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
  data: DailyRitualAssignment(
    allowedTokens: const [],
    bodyTemplate: 'You decide what to explore.',
    completedAt: null,
    deletionEpoch: 0,
    id: '00000000-0000-4000-8000-000000000021',
    localDate: DateTime.utc(2026, 8, 25),
    mode: DailyRitualAssignmentModeEnum.tarot,
    payload: {
      'title': 'Direction, not urgency.',
      'art_key': 'the_compass',
      'art_alt': 'The Compass at a celestial crossroads',
      'interpretation': 'Direction, not urgency.',
      'guidance': 'Compare the evidence and decide what deserves attention.',
      'market_label': 'Market-informed Demo',
      'observation_at': '2026-08-25T12:00:00.000Z',
      'revision_number': 1,
      'uncertainty': 'Short windows can reverse.',
      'evidence': [
        {
          'claim_id': '00000000-0000-4000-8000-000000000022',
          'factor_label': 'Durable momentum',
          'observed_at': '2026-08-25T12:00:00.000Z',
          'summary': 'Durable momentum in the deterministic Demo window.',
          'uncertainty': 'Short windows can reverse.',
        },
      ],
      'ideas': [
        {
          'appearance_reason': 'steady wealth',
          'asset_id': '00000000-0000-4000-8000-000000000023',
          'name': 'Dividend Demo ETF',
          'risk_summary': 'It can decline.',
          'symbol': 'VIG',
        },
      ],
    },
    revealedAt: null,
    revisionId: '00000000-0000-4000-8000-000000000024',
    riskFooter: 'Demo only; not investment advice.',
    rowanRevisionId: '00000000-0000-4000-8000-000000000025',
    scheduleId: '00000000-0000-4000-8000-000000000027',
    state: DailyRitualAssignmentStateEnum.assigned,
    userId: '00000000-0000-4000-8000-000000000001',
    version: 1,
  ),
  meta: ListAdminAudit200ResponseMeta(
    requestId: '00000000-0000-4000-8000-000000000026',
  ),
).toJson();
