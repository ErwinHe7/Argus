import 'package:dio/dio.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart'
    as api;

import '../../../core/api/api_failure_mapper.dart';
import '../../../core/api/view_state.dart';
import '../domain/model.dart';
import 'repository.dart';

class GeneratedRowanService implements RowanService {
  GeneratedRowanService(api.RitualInvestingApiClient client)
    : _api = api.RowanApi(client.dio);

  final api.RowanApi _api;

  @override
  Future<RowanCounselResult> fetch(RowanRequest request) async {
    try {
      final value = (await _api.resolveRowan(
        surface: _surface(request.surface),
        contextKey: request.contextCode,
      )).data!.data;
      return RowanCounselResult(
        scriptRevisionId: value.id,
        surface: request.surface,
        body: value.bodyTemplate,
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
