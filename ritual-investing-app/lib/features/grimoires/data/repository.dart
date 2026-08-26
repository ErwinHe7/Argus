// ignore_for_file: prefer_initializing_formals

import '../../../core/api/view_state.dart';
import '../../../core/cache/cached_read.dart';
import '../../../core/cache/read_cache.dart';
import '../domain/model.dart';

export '../../../core/cache/cached_read.dart' show OfflineException;

abstract interface class GrimoireService {
  Future<GrimoireDetail> fetchDetail(String grimoireId);
  Future<void> save(String grimoireId);
  Future<void> unsave(String grimoireId);
}

class GrimoireAmbiguousMutation implements Exception {
  const GrimoireAmbiguousMutation();
}

class GrimoireSaveResult {
  const GrimoireSaveResult({required this.value, required this.reconciled});

  final GrimoireDetail value;
  final bool reconciled;
}

class GrimoireRepository {
  GrimoireRepository({
    required GrimoireService service,
    required ReadCache cache,
  }) : _service = service,
       _cache = cache;

  final GrimoireService _service;
  final ReadCache _cache;

  Future<RepositoryRead<GrimoireDetail>> load(String grimoireId) => cachedRead(
    key: 'grimoire:$grimoireId',
    cache: _cache,
    fetch: () => _service.fetchDetail(grimoireId),
  );

  Future<GrimoireSaveResult> setSaved(
    GrimoireDetail current,
    bool target,
  ) async {
    var reconciled = false;
    try {
      if (target) {
        await _service.save(current.id);
      } else {
        await _service.unsave(current.id);
      }
    } on Object catch (error) {
      if (error is! GrimoireAmbiguousMutation &&
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
    return GrimoireSaveResult(value: authoritative, reconciled: reconciled);
  }
}
