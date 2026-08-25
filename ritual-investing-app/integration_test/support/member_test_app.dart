import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ritual_investing_api_client/generated/api.dart';
import 'package:ritual_investing_api_client/ritual_auth_interceptor.dart';
import 'package:ritual_investing_app/core/api/pending_command_store.dart';
import 'package:ritual_investing_app/core/api/ritual_api.dart';
import 'package:ritual_investing_app/core/auth/auth_controller.dart';
import 'package:ritual_investing_app/core/auth/member_auth.dart';
import 'package:ritual_investing_app/core/bootstrap/dependency_container.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';

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
      featureScopeFactory: (_, _) => throw StateError(
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
        'version': 0,
      },
      'entitlement': {'plan_code': 'demo-free', 'status': 'active'},
      'investor_profile': null,
      'onboarding': {
        'cohort': 'member_v2',
        'completed_at': null,
        'completed_steps': <String>[],
        'current_step': 'preferences',
        'schema_version': 2,
        'version': 0,
      },
      'preferences': {
        'locale': 'en-US',
        'ritual_familiarity': null,
        'ritual_interests': null,
        'ritual_language': null,
        'ritual_mode': 'tarot',
        'theme_mode': 'system',
        'timezone': 'UTC',
        'version': 0,
      },
      'profile': {'display_name': 'Local Member', 'locale': 'en-US'},
      'reset_generation': 0,
      'server_time': '2026-08-24T12:00:00.000Z',
    },
    'meta': {'request_id': '00000000-0000-4000-8000-000000000003'},
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
  final Map<String, String> _values = {};

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<Map<String, String>> readAll() async => Map.of(_values);

  @override
  Future<void> write(String key, String value) async => _values[key] = value;
}
