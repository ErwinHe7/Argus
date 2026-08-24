import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_admin/data/admin_gateway.dart';

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
