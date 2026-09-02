// ignore_for_file: prefer_initializing_formals

import '../domain/model.dart';

abstract interface class AiAnalysisService {
  Future<AiAnalysisSnapshot> fetch();
}

/// A deliberately uncached read boundary for time-sensitive market-risk state.
class AiAnalysisRepository {
  const AiAnalysisRepository({required AiAnalysisService service})
    : _service = service;

  final AiAnalysisService _service;

  Future<AiAnalysisSnapshot> load() => _service.fetch();
}
