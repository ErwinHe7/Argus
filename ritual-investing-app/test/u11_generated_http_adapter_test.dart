import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_api_client/ritual_auth_interceptor.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart';
import 'package:ritual_investing_app/features/privacy/data/generated_privacy_api_service.dart';
import 'package:ritual_investing_app/features/privacy/domain/model.dart';

void main() {
  test('privacy adapter carries the action-bound deletion receipt', () async {
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

    final requested = await service.requestExport('u11-export-command-000001');
    expect(requested.status, PrivacyExportStatus.queued);
    final refreshed = await service.getExport(_exportId);
    expect(refreshed.status, PrivacyExportStatus.completed);
    expect(await service.downloadLatest(_exportId), [1, 2, 3]);
    expect(
      harness
          .single('GET', '/v1/privacy/requests/$_exportId/download')
          .authorization,
      'Bearer u11-member-token',
    );

    const receipt = 'delete_step_up_receipt_000000000001';
    final deletion = await service.requestDeletion(
      'u11-deletion-command-0001',
      receipt,
    );
    expect(deletion.requestId, _deletionId);
    expect(deletion.status, PrivacyDeletionStatus.queued);
    expect(deletion.requestedAt, DateTime.utc(2026, 8, 25, 12));

    final request = harness.single(
      'POST',
      '/v1/privacy/requests',
      requestType: 'deletion',
    );
    expect(request.idempotencyKey, 'u11-deletion-command-0001');
    expect(request.body, {
      'requestType': 'deletion',
      'step_up_receipt': receipt,
    });
    expect(request.authorization, 'Bearer u11-member-token');
    expect(request.rawBody, isNot(contains('tombstone')));
    expect(request.rawBody, isNot(contains('purge')));

    final beforeInvalid = harness.requests.length;
    await expectLater(
      service.requestDeletion('u11-deletion-command-0002', 'not-a-receipt'),
      throwsA(isA<RecentAuthRequired>()),
    );
    expect(harness.requests, hasLength(beforeInvalid));

    harness.accountInactive = true;
    expect(await service.accountInactive(), isTrue);

    harness.accountInactive = false;
    harness.genericForbidden = true;
    await expectLater(
      service.accountInactive(),
      throwsA(
        isA<PrivacyFailure>().having(
          (failure) => failure.kind,
          'kind',
          PrivacyFailureKind.forbidden,
        ),
      ),
    );
  });
}

class _Harness {
  _Harness._(this.server);

  final HttpServer server;
  final List<_Request> requests = [];
  bool accountInactive = false;
  bool genericForbidden = false;

  String get baseUrl => 'http://${server.address.address}:${server.port}';

  static Future<_Harness> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final harness = _Harness._(server);
    unawaited(harness._serve());
    return harness;
  }

  _Request single(String method, String path, {String? requestType}) =>
      requests.singleWhere(
        (request) =>
            request.method == method &&
            request.path == path &&
            (requestType == null || request.body['requestType'] == requestType),
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
          authorization: request.headers.value(HttpHeaders.authorizationHeader),
          idempotencyKey: request.headers.value('idempotency-key'),
          body: body,
          rawBody: rawBody,
        ),
      );
      request.response.headers.contentType = ContentType.json;
      if (request.method == 'POST' &&
          request.uri.path == '/v1/privacy/requests') {
        final deletion = body['requestType'] == 'deletion';
        _json(
          request,
          _privacyRequest(
            id: deletion ? _deletionId : _exportId,
            type: deletion ? 'deletion' : 'export',
            status: 'queued',
          ),
        );
      } else if (request.method == 'GET' &&
          request.uri.path == '/v1/privacy/requests') {
        _json(request, {
          'data': [
            _privacyData(id: _exportId, type: 'export', status: 'completed'),
          ],
          'meta': _meta,
        });
      } else if (request.method == 'GET' &&
          request.uri.path == '/v1/privacy/requests/$_exportId/download') {
        final bytes = <int>[1, 2, 3];
        request.response.headers.contentType = ContentType(
          'application',
          'zip',
        );
        request.response.headers.set(
          'x-content-sha256',
          sha256.convert(bytes).toString(),
        );
        request.response.headers.contentLength = bytes.length;
        request.response.add(bytes);
      } else if (request.method == 'POST' &&
          request.uri.path == '/v1/session/bootstrap' &&
          accountInactive) {
        request.response.statusCode = HttpStatus.forbidden;
        _json(request, _error('account_inactive'));
      } else if (request.method == 'POST' &&
          request.uri.path == '/v1/session/bootstrap' &&
          genericForbidden) {
        request.response.statusCode = HttpStatus.forbidden;
        _json(request, _error('forbidden'));
      } else {
        request.response.statusCode = HttpStatus.notFound;
        _json(request, _error('not_found'));
      }
      await request.response.close();
    }
  }

  Future<void> close() => server.close(force: true);
}

void _json(HttpRequest request, Map<String, Object?> body) =>
    request.response.write(jsonEncode(body));

Map<String, Object?> _privacyRequest({
  required String id,
  required String type,
  required String status,
}) => {'data': _privacyData(id: id, type: type, status: status), 'meta': _meta};

Map<String, Object?> _privacyData({
  required String id,
  required String type,
  required String status,
}) => {
  'id': id,
  'user_id': _userId,
  'deletion_epoch': 0,
  'request_type': type,
  'status': status,
  'requested_at': '2026-08-25T12:00:00.000Z',
  'completed_at': status == 'completed' ? '2026-08-25T12:01:00.000Z' : null,
  'failure_code': null,
};

Map<String, Object?> _error(String code) => {
  'error': {
    'code': code,
    'message': 'Typed privacy response.',
    'request_id': _requestId,
    'field_errors': <Object?>[],
    'retryable': false,
  },
};

class _Request {
  const _Request({
    required this.method,
    required this.path,
    required this.authorization,
    required this.idempotencyKey,
    required this.body,
    required this.rawBody,
  });

  final String method;
  final String path;
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

const _requestId = '00000000-0000-4000-8000-000000000099';
const _userId = '00000000-0000-4000-8000-000000000001';
const _exportId = '018f3c2a-4b67-7a89-8abc-123456789020';
const _deletionId = '018f3c2a-4b67-7a89-8abc-123456789021';
const _meta = <String, Object?>{
  'request_id': _requestId,
  'server_time': '2026-08-25T12:00:00.000Z',
};
