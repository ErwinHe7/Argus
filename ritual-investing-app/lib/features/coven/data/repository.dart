// ignore_for_file: prefer_initializing_formals

import '../../../core/api/view_state.dart';
import '../../../core/cache/cached_read.dart';
import '../../../core/cache/read_cache.dart';
import '../domain/model.dart';

export '../../../core/cache/cached_read.dart' show OfflineException;

abstract interface class CovenService {
  Future<CovenModel> fetch();
  Future<CovenDetail> fetchDetail(String entryId);
  Future<List<CovenEvidenceDetail>> fetchEvidence(String entryId);
  Future<void> save(String entryId);
  Future<void> unsave(String entryId);
}

class CovenAmbiguousMutation implements Exception {
  const CovenAmbiguousMutation();
}

class CovenSaveResult {
  const CovenSaveResult({required this.value, required this.reconciled});

  final CovenDetail value;
  final bool reconciled;
}

class CovenRepository {
  CovenRepository({required CovenService service, required ReadCache cache})
    : _service = service,
      _cache = cache;

  final CovenService _service;
  final ReadCache _cache;

  Future<RepositoryRead<CovenModel>> load() =>
      cachedRead(key: 'coven', cache: _cache, fetch: _service.fetch);

  Future<RepositoryRead<CovenDetail>> loadDetail(String entryId) => cachedRead(
    key: 'coven-detail:$entryId',
    cache: _cache,
    fetch: () => _hydrate(entryId),
  );

  Future<CovenDetail> _hydrate(String entryId) async {
    final values = await Future.wait<Object>([
      _service.fetchDetail(entryId),
      _service.fetchEvidence(entryId),
    ]);
    return (values[0] as CovenDetail).copyWith(
      evidence: values[1] as List<CovenEvidenceDetail>,
    );
  }

  Future<CovenSaveResult> setSaved(CovenDetail current, bool target) async {
    var reconciled = false;
    try {
      if (target) {
        await _service.save(current.id);
      } else {
        await _service.unsave(current.id);
      }
    } on Object catch (error) {
      if (error is! CovenAmbiguousMutation &&
          error is! OfflineException &&
          (error is! LoadFailure || error.phase != LoadPhase.conflict)) {
        rethrow;
      }
      reconciled = true;
    }
    final authoritative = await _service.fetchDetail(current.id);
    if (authoritative.saved != target) {
      if (reconciled) throw const OfflineException();
      throw const LoadFailure(LoadPhase.conflict);
    }
    return CovenSaveResult(
      value: authoritative.copyWith(evidence: current.evidence),
      reconciled: reconciled,
    );
  }
}

class CachedCovenRepository extends CovenRepository {
  CachedCovenRepository({required super.service, required super.cache});
}
