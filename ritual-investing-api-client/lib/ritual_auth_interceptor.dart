import 'package:dio/dio.dart';

abstract interface class AccessTokenProvider {
  Future<String?> accessToken();
}

class RitualAuthInterceptor extends Interceptor {
  RitualAuthInterceptor({required AccessTokenProvider tokenProvider})
    : _tokenProvider = tokenProvider;
  final AccessTokenProvider _tokenProvider;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final token = await _tokenProvider.accessToken();
      if (token != null && token.isNotEmpty)
        options.headers['authorization'] = 'Bearer $token';
      handler.next(options);
    } catch (error, stackTrace) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }
}
