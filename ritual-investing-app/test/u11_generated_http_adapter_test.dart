import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_api_client/ritual_auth_interceptor.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart';
import 'package:ritual_investing_app/features/privacy/data/generated_privacy_api_service.dart';
import 'package:ritual_investing_app/features/privacy/domain/model.dart';

void main() {
  test(
    'U11 generated Dio adapter proves privacy and reset contracts',
    () async {
      final harness = await _Harness.start();
      addTearDown(harness.close);
      final service = GeneratedPrivacyService(
        RitualInvestingApiClient(
          basePathOverride: harness.baseUrl,
          interceptors: [
            RitualAuthInterceptor(tokenProvider: const _TokenProvider()),
          ],
        ),
      );

      final requested = await service.requestExport(
        'u11-export-command-000001',
      );
      expect(requested.status, PrivacyExportStatus.queued);
      expect(requested.hasDownloadGrant, isFalse);

      final firstGrant = await service.getExport(_exportId);
      final latestGrant = await service.getExport(_exportId);
      expect(firstGrant.canDownload, isTrue);
      expect(latestGrant.canDownload, isTrue);

      harness.downloadRecentAuthOnce = true;
      await expectLater(
        service.downloadLatest(_exportId),
        throwsA(isA<RecentAuthRequired>()),
      );
      expect(await service.downloadLatest(_exportId), [80, 75, 3, 4]);
      final resumedDownloads = harness.requests
          .where((request) => request.path.endsWith('/download'))
          .toList();
      expect(resumedDownloads, hasLength(2));
      expect(
        resumedDownloads.map((request) => request.query['token']).toSet(),
        {_token2},
      );

      final beforeConsumedRetry = harness.requests.length;
      await expectLater(
        service.downloadLatest(_exportId),
        throwsA(_privacyFailure(PrivacyFailureKind.terminal)),
      );
      expect(harness.requests, hasLength(beforeConsumedRetry));

      await service.getExport(_exportId);
      harness.downloadNotFoundOnce = true;
      await expectLater(
        service.downloadLatest(_exportId),
        throwsA(_privacyFailure(PrivacyFailureKind.retryable)),
      );
      final refreshed = await service.getExport(_exportId);
      expect(refreshed.canDownload, isTrue);

      final deletion = await service.requestDeletion(
        'u11-deletion-command-0001',
      );
      expect(deletion.purgeGeneration, 5);
      harness.accountInactive = true;
      expect(await service.accountInactive(), isTrue);

      final reset = await service.resetDemo(1, 'u11-reset-command-0000001');
      expect(reset.resetGeneration, 8);
      expect(reset.defaultPortfolioId, _portfolioId);

      final create = harness.single('POST', '/v1/me/privacy/exports');
      expect(create.idempotencyKey, 'u11-export-command-000001');
      expect(create.body, {'format': 'zip'});
      final deletionRequest = harness.single(
        'POST',
        '/v1/me/privacy/deletion-requests',
      );
      expect(deletionRequest.idempotencyKey, 'u11-deletion-command-0001');
      expect(deletionRequest.body, {'confirmation': 'DELETE'});
      final resetRequest = harness.single('POST', '/v1/me/demo-reset');
      expect(resetRequest.idempotencyKey, 'u11-reset-command-0000001');
      expect(resetRequest.body, {
        'confirmation': 'RESET_DEMO',
        'seed_version': 1,
      });
      expect(
        harness.requests.every(
          (request) => request.authorization == 'Bearer u11-member-token',
        ),
        isTrue,
      );
      expect(
        harness.requests.every(
          (request) => !RegExp(
            r'bank|broker|payment|card|provider',
            caseSensitive: false,
          ).hasMatch(request.rawBody),
        ),
        isTrue,
      );
    },
  );
}

Matcher _privacyFailure(PrivacyFailureKind kind) =>
    isA<PrivacyFailure>().having((failure) => failure.kind, 'kind', kind);

class _Harness {
  _Harness._(this.server);

  final HttpServer server;
  final List<_Request> requests = [];
  int statusReads = 0;
  bool downloadRecentAuthOnce = false;
  bool downloadNotFoundOnce = false;
  bool accountInactive = false;

  String get baseUrl => 'http://${server.address.address}:${server.port}';

  static Future<_Harness> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final harness = _Harness._(server);
    unawaited(harness._serve());
    return harness;
  }

  _Request single(String method, String path) => requests.singleWhere(
    (request) => request.method == method && request.path == path,
  );

  Future<void> _serve() async {
    await for (final request in server) {
      final rawBody = await utf8.decoder.bind(request).join();
      final body = rawBody.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(rawBody) as Map<String, dynamic>;
      requests.add(
        _Request(
          method: request.method,
          path: request.uri.path,
          query: request.uri.queryParameters,
          authorization: request.headers.value(HttpHeaders.authorizationHeader),
          idempotencyKey: request.headers.value('idempotency-key'),
          body: body,
          rawBody: rawBody,
        ),
      );
      final path = request.uri.path;
      if (request.method == 'POST' && path == '/v1/me/privacy/exports') {
        request.response.statusCode = HttpStatus.accepted;
        _json(request, _privacyExport(status: 'queued'));
      } else if (request.method == 'GET' &&
          path == '/v1/me/privacy/exports/$_exportId') {
        statusReads += 1;
        _json(
          request,
          _privacyExport(
            status: 'completed',
            token: switch (statusReads) {
              1 => _token1,
              2 => _token2,
              3 => _token3,
              _ => _token4,
            },
            origin: baseUrl,
          ),
        );
      } else if (request.method == 'GET' && path.endsWith('/download')) {
        if (downloadRecentAuthOnce) {
          downloadRecentAuthOnce = false;
          request.response.statusCode = HttpStatus.forbidden;
          _json(request, _error('recent_auth_required', retryable: false));
        } else if (downloadNotFoundOnce) {
          downloadNotFoundOnce = false;
          request.response.statusCode = HttpStatus.notFound;
          _json(request, _error('not_found', retryable: false));
        } else {
          request.response.headers.contentType = ContentType.binary;
          request.response.add([80, 75, 3, 4]);
        }
      } else if (request.method == 'POST' &&
          path == '/v1/me/privacy/deletion-requests') {
        request.response.statusCode = HttpStatus.accepted;
        _json(request, {
          'data': {
            'request_id': _deletionId,
            'tombstone_id': _tombstoneId,
            'status': 'queued',
            'effective_at': '2026-08-25T12:00:00.000Z',
            'purge_by': '2026-09-24T12:00:00.000Z',
            'purge_generation': 5,
          },
          'meta': _meta,
        });
      } else if (request.method == 'POST' && path == '/v1/session/bootstrap') {
        if (accountInactive) {
          request.response.statusCode = HttpStatus.forbidden;
          _json(request, _error('account_inactive', retryable: false));
        } else {
          throw StateError('The active bootstrap response is unused.');
        }
      } else if (request.method == 'POST' && path == '/v1/me/demo-reset') {
        _json(request, {
          'data': {
            'reset_generation': 8,
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
      } else {
        request.response.statusCode = HttpStatus.notFound;
        _json(request, _error('not_found', retryable: false));
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

Map<String, Object?> _privacyExport({
  required String status,
  String? token,
  String? origin,
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

Map<String, Object?> _error(String code, {required bool retryable}) => {
  'error': {
    'code': code,
    'message': 'Typed U11 test response.',
    'request_id': 'u11-socket-request',
    'field_errors': <Object?>[],
    'retryable': retryable,
  },
};

class _Request {
  const _Request({
    required this.method,
    required this.path,
    required this.query,
    required this.authorization,
    required this.idempotencyKey,
    required this.body,
    required this.rawBody,
  });

  final String method;
  final String path;
  final Map<String, String> query;
  final String? authorization;
  final String? idempotencyKey;
  final Map<String, dynamic> body;
  final String rawBody;
}

class _TokenProvider implements AccessTokenProvider {
  const _TokenProvider();

  @override
  Future<String?> accessToken() async => 'u11-member-token';
}

const _meta = {'request_id': 'u11-socket-request'};
const _exportId = '018f3c2a-4b67-7a89-8abc-123456789020';
const _deletionId = '018f3c2a-4b67-7a89-8abc-123456789021';
const _tombstoneId = '018f3c2a-4b67-7a89-8abc-123456789022';
const _portfolioId = '018f3c2a-4b67-7a89-8abc-123456789099';
const _entitlementId = '018f3c2a-4b67-7a89-8abc-123456789098';
const _token1 =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _token2 =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _token3 =
    '3333333333333333333333333333333333333333333333333333333333333333';
const _token4 =
    '4444444444444444444444444444444444444444444444444444444444444444';
