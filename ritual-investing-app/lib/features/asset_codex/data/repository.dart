// ignore_for_file: prefer_initializing_formals

import '../../../core/api/view_state.dart';
import '../../../core/cache/cached_read.dart';
import '../../../core/cache/read_cache.dart';
import '../domain/model.dart';

export '../../../core/cache/cached_read.dart' show OfflineException;

abstract interface class AssetCodexService {
  Future<AssetCodex> fetchDetail(String assetId);
  Future<List<AssetEvidenceDetail>> fetchEvidence(String assetId);
  Future<List<AssetMetric>> fetchMetrics(String assetId);
  Future<AssetComparison> compare(List<String> assetIds);
  Future<void> save(String assetId, AssetSourceContext source);
  Future<void> unsave(String assetId);
}

class AssetAmbiguousMutation implements Exception {
  const AssetAmbiguousMutation();
}

class AssetSaveResult {
  const AssetSaveResult({required this.value, required this.reconciled});

  final AssetCodex value;
  final bool reconciled;
}

class AssetCodexRepository {
  AssetCodexRepository({
    required AssetCodexService service,
    required ReadCache cache,
  }) : _service = service,
       _cache = cache;

  final AssetCodexService _service;
  final ReadCache _cache;

  Future<RepositoryRead<AssetCodex>> load(
    String assetId,
    AssetSourceContext source,
  ) => cachedRead(
    key: 'asset-codex:$assetId',
    cache: _cache,
    fetch: () => _hydrate(assetId, source),
  );

  Future<AssetCodex> _hydrate(String assetId, AssetSourceContext source) async {
    final values = await Future.wait<Object>([
      _service.fetchDetail(assetId),
      _service.fetchEvidence(assetId),
      _service.fetchMetrics(assetId),
    ]);
    return (values[0] as AssetCodex).copyWith(
      source: source,
      detailedEvidence: values[1] as List<AssetEvidenceDetail>,
      metrics: values[2] as List<AssetMetric>,
    );
  }

  Future<AssetSaveResult> setSaved(AssetCodex current, bool target) async {
    var reconciled = false;
    try {
      if (target) {
        await _service.save(current.id, current.source);
      } else {
        await _service.unsave(current.id);
      }
    } on Object catch (error) {
      if (error is! AssetAmbiguousMutation &&
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
    return AssetSaveResult(
      value: authoritative.copyWith(source: current.source),
      reconciled: reconciled,
    );
  }

  Future<AssetComparison> compare(List<String> assetIds) =>
      _service.compare(List.unmodifiable(assetIds));
}
