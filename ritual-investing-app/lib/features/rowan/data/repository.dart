import 'package:dio/dio.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart'
    as api;

import '../../../core/api/ritual_api.dart';
import '../../../core/api/view_state.dart';
import '../../../core/cache/cached_read.dart';
import '../../../core/cache/read_cache.dart';
import '../domain/model.dart';

abstract interface class RowanService {
  Future<RowanCounselResult> fetch(RowanRequest request);
}

class RowanRepository {
  const RowanRepository({required this.service, required this.cache});

  final RowanService service;
  final ReadCache cache;

  Future<RepositoryRead<RowanCounselResult>> load(RowanRequest request) =>
      cachedRead(
        key: request.cacheKey,
        cache: cache,
        fetch: () => service.fetch(request),
      );
}

class GeneratedRowanService implements RowanService {
  GeneratedRowanService(api.RitualInvestingApiClient client)
    : _api = api.RowanApi(client.dio);

  final api.RowanApi _api;

  @override
  Future<RowanCounselResult> fetch(RowanRequest request) async {
    try {
      final value = (await _api.getRowanCounsel(
        surface: _surface(request.surface),
        contextCode: request.contextCode,
        resourceId: request.resourceId,
      )).data!.data;
      final surface = switch (value.surface) {
        api.RowanCounselSurfaceEnum.dailyRitual => RowanSurface.dailyRitual,
        api.RowanCounselSurfaceEnum.evidence => RowanSurface.evidence,
        api.RowanCounselSurfaceEnum.assetCodex => RowanSurface.assetCodex,
        api.RowanCounselSurfaceEnum.coven => RowanSurface.coven,
        api.RowanCounselSurfaceEnum.unknownDefaultOpenApi =>
          throw const LoadFailure(LoadPhase.terminalFailure),
      };
      if (surface != request.surface) {
        throw const LoadFailure(LoadPhase.terminalFailure);
      }
      return RowanCounselResult(
        scriptRevisionId: value.scriptRevisionId,
        surface: surface,
        body: value.body,
        riskFooter: value.riskFooter,
      );
    } on DioException catch (error) {
      if (_offline(error)) {
        throw const LoadFailure(LoadPhase.retryableFailure);
      }
      throw ApiFailureMapper.map(error);
    }
  }
}

String _surface(RowanSurface surface) => switch (surface) {
  RowanSurface.dailyRitual => 'daily_ritual',
  RowanSurface.evidence => 'evidence',
  RowanSurface.assetCodex => 'asset_codex',
  RowanSurface.coven => 'coven',
};

bool _offline(DioException error) =>
    error.type == DioExceptionType.connectionError ||
    error.type == DioExceptionType.connectionTimeout ||
    error.type == DioExceptionType.receiveTimeout ||
    error.type == DioExceptionType.sendTimeout;
