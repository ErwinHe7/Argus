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
        '/v1/astrology-profile',
        data: jsonEncode({'birthDate': value}),
      );

      expect(jsonDecode(adapter.body!)['birthDate'], '1994-05-14');
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
          '/v1/astrology-profile',
          data: jsonEncode({'birthDate': value}),
        ),
        throwsA(isA<DioException>()),
        reason: value,
      );
      expect(adapter.calls, 0, reason: value);
    }
  });

  test('Intention POST and PATCH emit exact target_date only', () async {
    for (final request in [
      ('POST', '/v1/intentions'),
      ('PATCH', '/v1/intentions/00000000-0000-4000-8000-000000000020'),
    ]) {
      final adapter = _CaptureAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = adapter;
      ensureDateOnlyRequestSerialization(dio);

      await dio.request<void>(
        request.$2,
        options: Options(method: request.$1),
        data: jsonEncode({'target_date': '2028-08-24T00:00:00.000Z'}),
      );

      expect(jsonDecode(adapter.body!)['target_date'], '2028-08-24');
    }
  });

  test(
    'Intention target_date rejects local, non-midnight, and offsets',
    () async {
      for (final value in [
        '2028-08-24T00:00:00.000',
        '2028-08-24T12:00:00.000Z',
        '2028-08-24T00:00:00.000-04:00',
      ]) {
        final adapter = _CaptureAdapter();
        final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
          ..httpClientAdapter = adapter;
        ensureDateOnlyRequestSerialization(dio);

        await expectLater(
          dio.post<void>(
            '/v1/intentions',
            data: jsonEncode({'target_date': value}),
          ),
          throwsA(isA<DioException>()),
        );
        expect(adapter.calls, 0);
      }
    },
  );

  test('rewrites only Future Mirror as_of_date', () async {
    final adapter = _CaptureAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = adapter;
    ensureDateOnlyRequestSerialization(dio);

    await dio.post<void>(
      '/v1/intentions/00000000-0000-4000-8000-000000000020/future-mirror',
      data: jsonEncode({
        'as_of_date': '2026-08-25T00:00:00.000Z',
        'target_date': '2028-08-24T00:00:00.000Z',
        'generated_at': '2026-08-25T12:00:00.000Z',
      }),
    );

    expect(jsonDecode(adapter.body!), {
      'as_of_date': '2026-08-25',
      'target_date': '2028-08-24T00:00:00.000Z',
      'generated_at': '2026-08-25T12:00:00.000Z',
    });
  });

  test('briefing date queries emit exact YYYY-MM-DD values', () async {
    for (final request in [
      (
        '/v1/briefings/daily',
        <String, Object?>{'local_date': DateTime.utc(2026, 8, 25)},
      ),
      (
        '/v1/briefings',
        <String, Object?>{
          'period_start': DateTime.utc(2026, 8, 1),
          'period_end': DateTime.utc(2026, 8, 31),
        },
      ),
    ]) {
      final adapter = _CaptureAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = adapter;
      ensureDateOnlyRequestSerialization(dio);

      await dio.get<void>(request.$1, queryParameters: request.$2);

      expect(
        adapter.query.values,
        everyElement(matches(RegExp(r'^\d{4}-\d{2}-\d{2}$'))),
      );
    }
  });

  test('briefing date queries reject local and non-midnight values', () async {
    for (final value in [
      DateTime(2026, 8, 25),
      DateTime.utc(2026, 8, 25, 12),
      '2026-08-25T00:00:00.000-04:00',
    ]) {
      final adapter = _CaptureAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = adapter;
      ensureDateOnlyRequestSerialization(dio);

      await expectLater(
        dio.get<void>(
          '/v1/briefings/daily',
          queryParameters: {'local_date': value},
        ),
        throwsA(isA<DioException>()),
      );
      expect(adapter.calls, 0);
    }
  });
}

class _CaptureAdapter implements HttpClientAdapter {
  String? body;
  int calls = 0;
  Map<String, dynamic> query = const {};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    body = options.data as String?;
    query = Map.of(options.queryParameters);
    return ResponseBody.fromString('', 204);
  }

  @override
  void close({bool force = false}) {}
}
