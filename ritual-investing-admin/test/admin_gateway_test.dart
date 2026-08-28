import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart';
import 'package:ritual_investing_admin/data/admin_gateway.dart';
import 'package:ritual_investing_admin/domain/admin_models.dart';

void main() {
  test('intentional commands receive distinct replay keys', () {
    const factory = AdminCommandKeyFactory();

    final first = factory.next('job-retry', 'job-1');
    final second = factory.next('job-retry', 'job-1');

    expect(first, startsWith('cmd-'));
    expect(second, startsWith('cmd-'));
    expect(second, isNot(first));
  });

  test('a transient network retry preserves the command replay key', () async {
    final dio = Dio();
    final adapter = _TransientAdapter();
    dio.httpClientAdapter = adapter;
    dio.interceptors.add(AdminIdempotencyRetryInterceptor(dio));

    final response = await dio.post<Object?>(
      '/v1/admin/jobs/job-1/retry',
      options: Options(headers: const {'idempotency-key': 'command-attempt-1'}),
    );

    expect(response.statusCode, 204);
    expect(adapter.keys, const ['command-attempt-1', 'command-attempt-1']);
  });

  test('editorial review uses the retained Supabase contract', () async {
    final capture = _CaptureAdapter();
    final client = RitualInvestingApiClient(
      basePathOverride: 'https://admin.ritual-investing.invalid',
    );
    client.dio.httpClientAdapter = capture;
    final gateway = OpenApiAdminGateway(client);

    await expectLater(
      gateway.requestReview(
        adminDestinations.first,
        const AdminRecord(
          id: 'ritual-1',
          title: 'Compass',
          status: 'draft',
          version: 2,
          revisionId: 'revision-2',
        ),
      ),
      throwsA(isA<DioException>()),
    );

    final request = capture.request!;
    expect(request.method, 'POST');
    expect(request.path, '/v1/admin/editorial/ritual-1/commands');
    expect(request.extra['secure'], isA<List<Map<String, String>>>());
    expect(_jsonData(request.data), {
      'action': 'request_review',
      'revision_id': 'revision-2',
      'reason': 'Reviewed staff editorial transition.',
      'high_trust': true,
    });
  });

  test(
    'workspace list scopes the generic editorial collection by kind',
    () async {
      final capture = _CaptureAdapter();
      final client = RitualInvestingApiClient(
        basePathOverride: 'https://admin.ritual-investing.invalid',
      );
      client.dio.httpClientAdapter = capture;

      await expectLater(
        OpenApiAdminGateway(client).list(adminDestinations.first),
        throwsA(isA<DioException>()),
      );

      final request = capture.request!;
      expect(request.method, 'GET');
      expect(request.path, '/v1/admin/editorial');
      expect(request.queryParameters['limit'], 20);
      expect(request.queryParameters['kind'], 'ritual');
      expect(request.extra['secure'], isNotEmpty);
    },
  );

  test('editorial patch preserves ETag conflict protection', () async {
    final capture = _CaptureAdapter();
    final client = RitualInvestingApiClient(
      basePathOverride: 'https://admin.ritual-investing.invalid',
    );
    client.dio.httpClientAdapter = capture;

    await expectLater(
      OpenApiAdminGateway(client).patchRevision(
        adminDestinations.first,
        const AdminRecord(
          id: 'item-1',
          title: 'Compass',
          status: 'draft',
          version: 4,
          revisionId: 'revision-4',
          etag: '"v4"',
        ),
        const {'title': 'Revised'},
      ),
      throwsA(isA<DioException>()),
    );

    final request = capture.request!;
    expect(request.method, 'PATCH');
    expect(request.path, '/v1/admin/editorial/item-1/revisions/revision-4');
    expect(request.headers['if-match'], '"v4"');
    expect(request.extra['secure'], isNotEmpty);
    expect(_jsonData(request.data), {
      'payload': {'title': 'Revised'},
    });
  });

  test('job retry obtains an action-bound receipt before dispatch', () async {
    final capture = _StepUpAdapter();
    final client = RitualInvestingApiClient(
      basePathOverride: 'https://admin.ritual-investing.invalid',
    );
    client.dio.httpClientAdapter = capture;

    await expectLater(
      OpenApiAdminGateway(client).retryJob(
        const AdminRecord(
          id: 'job-1',
          title: 'Export',
          status: 'failed',
          version: 1,
        ),
      ),
      throwsA(isA<DioException>()),
    );

    final request = capture.requests.last;
    expect(capture.requests.first.path, '/v1/admin/step-up');
    expect(_jsonData(capture.requests.first.data), {
      'action': 'admin_job_retry',
      'target_id': 'job-1',
    });
    expect(request.path, '/v1/admin/operations/jobs/job-1/retry');
    expect(request.extra['secure'], isNotEmpty);
    expect(request.headers['idempotency-key'], startsWith('cmd-'));
    expect(_jsonData(request.data), {
      'step_up_receipt': 'staff-step-up-receipt-000000000000000000000001',
    });
  });
}

Map<String, Object?> _jsonData(Object? value) => value is String
    ? Map<String, Object?>.from(jsonDecode(value) as Map)
    : Map<String, Object?>.from(value! as Map);

class _TransientAdapter implements HttpClientAdapter {
  final List<String?> keys = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    keys.add(options.headers['idempotency-key'] as String?);
    if (keys.length == 1) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: 'transient network failure',
      );
    }
    return ResponseBody.fromString('', 204);
  }

  @override
  void close({bool force = false}) {}
}

class _CaptureAdapter implements HttpClientAdapter {
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    request = options;
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
      error: 'captured request',
    );
  }

  @override
  void close({bool force = false}) {}
}

class _StepUpAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (requests.length == 1) {
      return ResponseBody.fromString(
        jsonEncode({
          'data': {'receipt': 'staff-step-up-receipt-000000000000000000000001'},
          'meta': {'request_id': '018f3c2a-4b67-7a89-8abc-123456789077'},
        }),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
      error: 'captured retry request',
    );
  }

  @override
  void close({bool force = false}) {}
}
