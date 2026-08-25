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
    if (fields.isEmpty) {
      handler.next(options);
      return;
    }
    try {
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

Set<String> _dateOnlyFields(RequestOptions options) {
  if (options.path == '/v1/session/onboarding/finalize' ||
      (options.path == '/v1/me/astrology-profile' && options.method == 'PUT')) {
    return const {'birth_date'};
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
