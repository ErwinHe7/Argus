import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/api/date_only_request_interceptor.dart';

void main() {
  test('accepts exact date and generated UTC-midnight forms', () async {
    for (final value in ['1994-05-14', '1994-05-14T00:00:00.000Z']) {
      final adapter = _CaptureAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = adapter;
      ensureDateOnlyRequestSerialization(dio);

      await dio.put<void>(
        '/v1/me/astrology-profile',
        data: jsonEncode({'birth_date': value}),
      );

      expect(jsonDecode(adapter.body!)['birth_date'], '1994-05-14');
    }
  });

  test('rejects local, non-midnight, and offset timestamps', () async {
    for (final value in [
      '1994-05-14T00:00:00.000',
      '1994-05-14T12:00:00.000Z',
      '1994-05-14T00:00:00.000-04:00',
    ]) {
      final adapter = _CaptureAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = adapter;
      ensureDateOnlyRequestSerialization(dio);

      await expectLater(
        dio.put<void>(
          '/v1/me/astrology-profile',
          data: jsonEncode({'birth_date': value}),
        ),
        throwsA(isA<DioException>()),
        reason: value,
      );
      expect(adapter.calls, 0, reason: value);
    }
  });
}

class _CaptureAdapter implements HttpClientAdapter {
  String? body;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    body = options.data as String;
    return ResponseBody.fromString('', 204);
  }

  @override
  void close({bool force = false}) {}
}
