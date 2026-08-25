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
    if (!_requiresDateOnlyRewrite(options)) {
      handler.next(options);
      return;
    }
    try {
      final body = options.data;
      if (body is String) {
        options.data = jsonEncode(_rewrite(jsonDecode(body)));
      } else if (body is Map || body is List) {
        options.data = _rewrite(body);
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

bool _requiresDateOnlyRewrite(RequestOptions options) =>
    options.path == '/v1/session/onboarding/finalize' ||
    (options.path == '/v1/me/astrology-profile' && options.method == 'PUT');

Object? _rewrite(Object? value, [String? key]) {
  if (value is Map) {
    return value.map<String, Object?>((rawKey, nested) {
      final name = rawKey.toString();
      return MapEntry(name, _rewrite(nested, name));
    });
  }
  if (value is List) return value.map(_rewrite).toList(growable: false);
  if (key == 'birth_date' && value is String) return _dateOnly(value);
  return value;
}

String _dateOnly(String raw) {
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) return raw;
  final generatedDateTime = RegExp(
    r'^(\d{4}-\d{2}-\d{2})T00:00:00(?:\.0{3,6})?Z$',
  ).firstMatch(raw);
  if (generatedDateTime == null) {
    throw const FormatException('birth_date must be date-only.');
  }
  return generatedDateTime.group(1)!;
}
