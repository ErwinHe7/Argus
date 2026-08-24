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

  test(
    'editorial review uses the generated secured transport contract',
    () async {
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
      expect(
        request.path,
        '/v1/admin/ritual-scenarios/ritual-1/revisions/revision-2/review-requests',
      );
      expect(request.headers['idempotency-key'], startsWith('cmd-'));
      expect(request.extra['secure'], isA<List<Map<String, String>>>());
      expect(jsonDecode(request.data as String), {
        'note': 'Submitted from the reviewed staff dashboard.',
      });
    },
  );

  test('workspace list uses the generated collection method', () async {
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
    expect(request.path, '/v1/admin/ritual-scenarios');
    expect(request.queryParameters['limit'], 20);
    expect(request.extra['secure'], isNotEmpty);
  });

  test('catalog patch uses generated DTO serialization and If-Match', () async {
    final capture = _CaptureAdapter();
    final client = RitualInvestingApiClient(
      basePathOverride: 'https://admin.ritual-investing.invalid',
    );
    client.dio.httpClientAdapter = capture;

    await expectLater(
      OpenApiAdminGateway(client).patchCatalog(
        adminDestinations.firstWhere(
          (destination) => destination.apiPath == '/v1/admin/assets',
        ),
        const AdminRecord(
          id: 'asset-1',
          title: 'VIG',
          status: 'active',
          version: 4,
          etag: '"v4"',
        ),
        const {'status': 'inactive'},
      ),
      throwsA(isA<DioException>()),
    );

    final request = capture.request!;
    expect(request.method, 'PATCH');
    expect(request.path, '/v1/admin/assets/asset-1');
    expect(request.headers['if-match'], '"v4"');
    expect(request.extra['secure'], isNotEmpty);
    expect(jsonDecode(request.data as String), {'status': 'inactive'});
  });

  test('job retry uses generated operation method and request DTO', () async {
    final capture = _CaptureAdapter();
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

    final request = capture.request!;
    expect(request.path, '/v1/admin/jobs/job-1/retry');
    expect(request.extra['secure'], isNotEmpty);
    expect(jsonDecode(request.data as String), {
      'reason': 'Reviewed retry from the staff dashboard.',
    });
  });
}

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
