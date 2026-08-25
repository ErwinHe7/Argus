import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ritual_investing_api_client/ritual_auth_interceptor.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart';
import 'package:ritual_investing_app/core/api/pending_command_store.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/privacy/application/privacy_controller.dart';
import 'package:ritual_investing_app/features/privacy/data/private_export_files.dart';
import 'package:ritual_investing_app/features/privacy/data/repository.dart';
import 'package:ritual_investing_app/features/privacy/presentation/privacy_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'generated loopback export reset and lost-deletion response stay private',
    (tester) async {
      late _Harness harness;
      late Directory temporaryRoot;
      await tester.runAsync(() async {
        harness = await _Harness.start();
        temporaryRoot = await Directory.systemTemp.createTemp(
          'u11-private-export-',
        );
      });
      addTearDown(harness.close);
      addTearDown(() async {
        if (await temporaryRoot.exists()) {
          await temporaryRoot.delete(recursive: true);
        }
      });
      final storage = _Storage();
      final requestStore = PrivacyExportRequestStore(storage: storage);
      final sharedPaths = <String>[];
      final files = FlutterPrivateExportFiles(
        temporaryDirectory: () async => temporaryRoot,
        shareFile: (path) async {
          sharedPaths.add(path);
          expect(await File(path).readAsBytes(), [80, 75, 3, 4]);
          expect(path, isNot(contains('token')));
          return true;
        },
      );
      final scope = const CacheScope(
        accountId: 'u11-integration-account',
        resetGeneration: 4,
      );
      final controller = _controller(
        harness,
        storage,
        requestStore,
        files,
        scope,
      );

      await tester.pumpWidget(
        MaterialApp(home: PrivacySettingsScreen(controller: controller)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('privacy-export-request')));
      await tester.pumpAndSettle();
      expect(find.text('Export status: queued'), findsOneWidget);
      await tester.tap(find.byKey(const Key('privacy-export-refresh')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('privacy-export-share')), findsOneWidget);
      await tester.tap(find.byKey(const Key('privacy-export-share')));
      await tester.pumpAndSettle();

      expect(find.textContaining('shared and removed'), findsOneWidget);
      expect(sharedPaths, hasLength(1));
      expect(await File(sharedPaths.single).exists(), isFalse);
      expect(await requestStore.read(scope), isNull);
      expect(
        harness.downloadTokens.single,
        harness.statusTokens.last,
        reason: 'download must use only the latest rotated status token',
      );

      final resetGenerations = <int>[];
      final resetController = _controller(
        harness,
        storage,
        requestStore,
        files,
        scope,
        onResetAccepted: (generation) async => resetGenerations.add(generation),
      );
      await tester.pumpWidget(
        MaterialApp(home: DemoResetScreen(controller: resetController)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('demo-reset-review')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('demo-reset-confirm')));
      await tester.pumpAndSettle();
      expect(resetGenerations, [5]);
      expect(find.text('The seeded Demo is ready.'), findsOneWidget);

      var deletionAccepted = 0;
      final deletionController = _controller(
        harness,
        storage,
        requestStore,
        files,
        const CacheScope(
          accountId: 'u11-integration-account',
          resetGeneration: 5,
        ),
        onDeletionAccepted: () async => deletionAccepted += 1,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PrivacySettingsScreen(controller: deletionController),
        ),
      );
      await tester.pumpAndSettle();
      await _tapVisible(
        tester,
        find.byKey(const Key('privacy-deletion-review')),
      );
      await _tapVisible(
        tester,
        find.byKey(const Key('privacy-deletion-confirm')),
      );

      expect(deletionAccepted, 1);
      expect(harness.accountInactive, isTrue);
      expect(harness.deletionCalls, 1);
      expect(
        harness.requests.every(
          (request) =>
              request.authorization == 'Bearer u11-integration-member' &&
              !RegExp(
                r'bank|broker|payment|card|provider',
                caseSensitive: false,
              ).hasMatch(request.rawBody),
        ),
        isTrue,
      );
    },
  );
}

PrivacyController _controller(
  _Harness harness,
  ProtectedStorage storage,
  PrivacyExportRequestStore requestStore,
  PrivateExportFiles files,
  CacheScope scope, {
  Future<void> Function()? onDeletionAccepted,
  Future<void> Function(int generation)? onResetAccepted,
}) => PrivacyController(
  repository: ScopedPrivacyRepository(
    service: GeneratedPrivacyService(harness.client),
    requestStore: requestStore,
    files: files,
    scope: scope,
  ),
  pendingStore: PendingCommandStore(storage: storage),
  scope: scope,
  createKey: () => 'u11-integration-command-${harness.nextCommand++}',
  reauthenticate: () async {},
  onDeletionAccepted: onDeletionAccepted ?? () async {},
  onResetAccepted: onResetAccepted ?? (_) async {},
);

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  final scrollable = find.byType(Scrollable);
  for (
    var attempt = 0;
    attempt < 12 && finder.hitTestable().evaluate().isEmpty;
    attempt++
  ) {
    await tester.drag(scrollable.last, const Offset(0, -280));
    await tester.pumpAndSettle();
  }
  expect(finder.hitTestable(), findsOneWidget);
  await tester.tap(finder.hitTestable());
  await tester.pumpAndSettle();
}

class _Harness {
  _Harness._(this.server, this.client);

  final HttpServer server;
  final RitualInvestingApiClient client;
  final List<_Request> requests = [];
  final List<String> statusTokens = [];
  final List<String> downloadTokens = [];
  int nextCommand = 1;
  int statusReads = 0;
  int deletionCalls = 0;
  bool accountInactive = false;

  String get baseUrl => 'http://${server.address.address}:${server.port}';

  static Future<_Harness> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final client = RitualInvestingApiClient(
      basePathOverride: 'http://${server.address.address}:${server.port}',
      interceptors: [
        RitualAuthInterceptor(tokenProvider: const _TokenProvider()),
      ],
    );
    final harness = _Harness._(server, client);
    unawaited(harness._serve());
    return harness;
  }

  Future<void> _serve() async {
    await for (final request in server) {
      final rawBody = await utf8.decoder.bind(request).join();
      requests.add(
        _Request(
          path: request.uri.path,
          authorization: request.headers.value(HttpHeaders.authorizationHeader),
          rawBody: rawBody,
        ),
      );
      final path = request.uri.path;
      if (request.method == 'POST' && path == '/v1/me/privacy/exports') {
        request.response.statusCode = HttpStatus.accepted;
        _json(request, _export('queued'));
      } else if (request.method == 'GET' &&
          path == '/v1/me/privacy/exports/$_exportId') {
        statusReads += 1;
        final token = statusReads.isOdd ? _token1 : _token2;
        statusTokens.add(token);
        _json(request, _export('completed', origin: baseUrl, token: token));
      } else if (request.method == 'GET' && path.endsWith('/download')) {
        downloadTokens.add(request.uri.queryParameters['token'] ?? '');
        request.response.headers.contentType = ContentType.binary;
        request.response.add([80, 75, 3, 4]);
      } else if (request.method == 'POST' && path == '/v1/me/demo-reset') {
        _json(request, {
          'data': {
            'reset_generation': 5,
            'default_portfolio': {
              'id': _portfolioId,
              'name': 'Seeded Demo Portfolio',
              'currency': 'USD',
              'status': 'active',
              'version': 1,
            },
            'entitlement': {
              'id': _entitlementId,
              'plan_code': 'free',
              'status': 'active',
              'source': 'demo',
              'version': 1,
            },
            'demo': {
              'is_demo': true,
              'observed_at': '2026-08-25T12:00:00.000Z',
              'source_label': 'Ritual seeded Demo',
              'limitations': ['No real money moves or provider execution.'],
            },
          },
          'meta': _meta,
        });
      } else if (request.method == 'POST' &&
          path == '/v1/me/privacy/deletion-requests') {
        deletionCalls += 1;
        accountInactive = true;
        final socket = await request.response.detachSocket(writeHeaders: false);
        socket.destroy();
        continue;
      } else if (request.method == 'POST' &&
          path == '/v1/session/bootstrap' &&
          accountInactive) {
        request.response.statusCode = HttpStatus.forbidden;
        _json(request, _error('account_inactive'));
      } else {
        request.response.statusCode = HttpStatus.notFound;
        _json(request, _error('not_found'));
      }
      await request.response.close();
    }
  }

  Future<void> close() => server.close(force: true);
}

void _json(HttpRequest request, Map<String, Object?> body) {
  request.response.headers.contentType = ContentType.json;
  request.response.write(jsonEncode(body));
}

Map<String, Object?> _export(
  String status, {
  String? origin,
  String? token,
}) => {
  'data': {
    'id': _exportId,
    'request_type': 'export',
    'status': status,
    'snapshot_at': '2026-08-25T12:00:00.000Z',
    'completed_at': status == 'completed' ? '2026-08-25T12:01:00.000Z' : null,
    'expires_at': '2026-09-01T12:00:00.000Z',
    'failure_code': null,
    'format': 'zip',
    'download_link': token == null
        ? null
        : {
            'url':
                '$origin/v1/me/privacy/exports/$_exportId/download?token=$token',
            'expires_at': '2026-08-25T12:06:00.000Z',
          },
  },
  'meta': _meta,
};

Map<String, Object?> _error(String code) => {
  'error': {
    'code': code,
    'message': 'Typed U11 integration response.',
    'request_id': 'u11-integration-request',
    'field_errors': <Object?>[],
    'retryable': false,
  },
};

class _Request {
  const _Request({
    required this.path,
    required this.authorization,
    required this.rawBody,
  });

  final String path;
  final String? authorization;
  final String rawBody;
}

class _Storage implements ProtectedStorage {
  final Map<String, String> values = {};

  @override
  Future<void> delete(String key) async => values.remove(key);
  @override
  Future<Map<String, String>> readAll() async => Map.of(values);
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class _TokenProvider implements AccessTokenProvider {
  const _TokenProvider();

  @override
  Future<String?> accessToken() async => 'u11-integration-member';
}

const _meta = {'request_id': 'u11-integration-request'};
const _exportId = '018f3c2a-4b67-7a89-8abc-123456789020';
const _portfolioId = '018f3c2a-4b67-7a89-8abc-123456789099';
const _entitlementId = '018f3c2a-4b67-7a89-8abc-123456789098';
const _token1 =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _token2 =
    '2222222222222222222222222222222222222222222222222222222222222222';
