import 'dart:convert';

import 'package:dio/dio.dart';

void ensureDateOnlyRequestSerialization(Dio dio) {
  if (dio.interceptors.any((value) => value is DateOnlyRequestInterceptor)) {
    return;
  }
  dio.interceptors.add(DateOnlyRequestInterceptor());
}

class DateOnlyRequestInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final fields = _dateOnlyFields(options);
    final queryFields = _dateOnlyQueryFields(options);
    if (fields.isEmpty && queryFields.isEmpty) {
      handler.next(options);
      return;
    }
    try {
      if (queryFields.isNotEmpty) {
        for (final field in queryFields) {
          final value = options.queryParameters[field];
          if (value == null) continue;
          options.queryParameters[field] = _queryDateOnly(value, field);
        }
      }
      final body = options.data;
      if (body is String) {
        options.data = jsonEncode(_rewrite(jsonDecode(body), fields));
      } else if (body is Map || body is List) {
        options.data = _rewrite(body, fields);
      }
      handler.next(options);
    } on Object catch (error, stackTrace) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.unknown,
          error: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }
}

Set<String> _dateOnlyQueryFields(RequestOptions options) {
  if (options.method != 'GET') return const {};
  if (options.path == '/v1/briefings/daily') return const {'local_date'};
  if (options.path == '/v1/briefings') {
    return const {'period_start', 'period_end'};
  }
  return const {};
}

Set<String> _dateOnlyFields(RequestOptions options) {
  if (options.path == '/v1/session/onboarding/finalize' ||
      (options.path == '/v1/astrology-profile' && options.method == 'PUT')) {
    return options.path == '/v1/astrology-profile'
        ? const {'birthDate'}
        : const {'birth_date'};
  }
  final segments = Uri.parse(options.path).pathSegments;
  final intentionCreate =
      options.method == 'POST' && options.path == '/v1/intentions';
  final intentionPatch =
      options.method == 'PATCH' &&
      segments.length == 3 &&
      segments[0] == 'v1' &&
      segments[1] == 'intentions' &&
      segments[2].isNotEmpty;
  final futureMirrorCreate =
      options.method == 'POST' &&
      segments.length == 4 &&
      segments[0] == 'v1' &&
      segments[1] == 'intentions' &&
      segments[2].isNotEmpty &&
      segments[3] == 'future-mirror';
  if (futureMirrorCreate) return const {'as_of_date'};
  return intentionCreate || intentionPatch ? const {'target_date'} : const {};
}

Object? _rewrite(Object? value, Set<String> fields, [String? key]) {
  if (value is Map) {
    return value.map<String, Object?>((rawKey, nested) {
      final name = rawKey.toString();
      return MapEntry(name, _rewrite(nested, fields, name));
    });
  }
  if (value is List) {
    return value.map((item) => _rewrite(item, fields)).toList(growable: false);
  }
  if (key != null && fields.contains(key) && value is String) {
    return _dateOnly(value, key);
  }
  return value;
}

String _dateOnly(String raw, String field) {
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) return raw;
  final generatedDateTime = RegExp(
    r'^(\d{4}-\d{2}-\d{2})T00:00:00(?:\.0{3,6})?Z$',
  ).firstMatch(raw);
  if (generatedDateTime == null) {
    throw FormatException('$field must be date-only.');
  }
  return generatedDateTime.group(1)!;
}

String _queryDateOnly(Object value, String field) {
  if (value is String) return _dateOnly(value, field);
  if (value is! DateTime ||
      !value.isUtc ||
      value.hour != 0 ||
      value.minute != 0 ||
      value.second != 0 ||
      value.millisecond != 0 ||
      value.microsecond != 0) {
    throw FormatException('$field must be a UTC date-only value.');
  }
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
