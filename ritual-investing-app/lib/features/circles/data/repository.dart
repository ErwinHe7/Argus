// ignore_for_file: prefer_initializing_formals

import '../../../core/api/view_state.dart';
import '../../../core/cache/cached_read.dart';
import '../../../core/cache/read_cache.dart';
import '../domain/model.dart';

export '../../../core/cache/cached_read.dart' show OfflineException;

abstract interface class CircleService {
  Future<CircleCollection> fetchList({required bool includeArchived});
  Future<PrivateCircle> fetchDetail(String circleId);
  Future<PrivateCircle> create(CircleCreateCommand command);
  Future<PrivateCircle> copy(CircleCopyCommand command);
  Future<PrivateCircle> patch(
    String circleId,
    int expectedVersion,
    CircleDraft draft,
  );
  Future<PrivateCircle> replaceAssets(
    String circleId,
    int expectedVersion,
    List<CircleAsset> assets,
  );
  Future<PrivateCircle> putAsset(
    String circleId,
    int expectedVersion,
    CircleAsset asset,
  );
  Future<PrivateCircle> removeAsset(
    String circleId,
    int expectedVersion,
    String assetId,
  );
  Future<void> archive(String circleId, int expectedVersion);
  Future<CircleTemplateDetail> fetchTemplate(String templateId);
  Future<void> saveTemplate(String templateId);
  Future<void> unsaveTemplate(String templateId);
}

class CircleAmbiguousMutation implements Exception {
  const CircleAmbiguousMutation();
}

class CircleTemplateSaveResult {
  const CircleTemplateSaveResult({
    required this.value,
    required this.reconciled,
  });

  final CircleTemplateDetail value;
  final bool reconciled;
}

class CircleRepository {
  CircleRepository({required CircleService service, required ReadCache cache})
    : _service = service,
      _cache = cache;

  final CircleService _service;
  final ReadCache _cache;

  Future<RepositoryRead<CircleCollection>> loadList({
    bool includeArchived = false,
  }) => cachedRead(
    key: 'circles:${includeArchived ? 'all' : 'active'}',
    cache: _cache,
    fetch: () => _service.fetchList(includeArchived: includeArchived),
  );

  Future<RepositoryRead<PrivateCircle>> loadDetail(String circleId) =>
      cachedRead(
        key: 'circle:$circleId',
        cache: _cache,
        fetch: () => _service.fetchDetail(circleId),
      );

  Future<PrivateCircle> fetchCurrent(String circleId) =>
      _service.fetchDetail(circleId);

  Future<PrivateCircle> create(CircleCreateCommand command) =>
      _service.create(command);

  Future<PrivateCircle> copy(CircleCopyCommand command) =>
      _service.copy(command);

  Future<PrivateCircle> patch(PrivateCircle current, CircleDraft draft) async {
    try {
      return await _service.patch(current.id, current.version, draft);
    } on CircleAmbiguousMutation {
      final authoritative = await _service.fetchDetail(current.id);
      if (authoritative.title == draft.title &&
          authoritative.description == draft.description) {
        return authoritative;
      }
      throw const OfflineException();
    }
  }

  Future<PrivateCircle> replaceAssets(
    PrivateCircle current,
    List<CircleAsset> assets,
  ) async {
    try {
      return await _service.replaceAssets(current.id, current.version, assets);
    } on CircleAmbiguousMutation {
      final authoritative = await _service.fetchDetail(current.id);
      if (_sameAssets(authoritative.assets, assets)) return authoritative;
      throw const OfflineException();
    }
  }

  Future<PrivateCircle> putAsset(
    PrivateCircle current,
    CircleAsset asset,
  ) async {
    try {
      return await _service.putAsset(current.id, current.version, asset);
    } on CircleAmbiguousMutation {
      final authoritative = await _service.fetchDetail(current.id);
      final committed = authoritative.assets.any(
        (value) =>
            value.assetId == asset.assetId &&
            value.ordinal == asset.ordinal &&
            value.note == asset.note &&
            value.weightBps == asset.weightBps,
      );
      if (committed) return authoritative;
      throw const OfflineException();
    }
  }

  Future<PrivateCircle> removeAsset(
    PrivateCircle current,
    String assetId,
  ) async {
    try {
      return await _service.removeAsset(current.id, current.version, assetId);
    } on CircleAmbiguousMutation {
      final authoritative = await _service.fetchDetail(current.id);
      if (authoritative.assets.every((asset) => asset.assetId != assetId)) {
        return authoritative;
      }
      throw const OfflineException();
    }
  }

  Future<PrivateCircle> archive(PrivateCircle current) async {
    try {
      await _service.archive(current.id, current.version);
    } on CircleAmbiguousMutation {
      final authoritative = await _service.fetchDetail(current.id);
      if (authoritative.isArchived) return authoritative;
      throw const OfflineException();
    }
    return _service.fetchDetail(current.id);
  }

  Future<RepositoryRead<CircleTemplateDetail>> loadTemplate(
    String templateId,
  ) => cachedRead(
    key: 'circle-template:$templateId',
    cache: _cache,
    fetch: () => _service.fetchTemplate(templateId),
  );

  Future<CircleTemplateSaveResult> setTemplateSaved(
    CircleTemplateDetail current,
    bool target,
  ) async {
    var reconciled = false;
    try {
      if (target) {
        await _service.saveTemplate(current.id);
      } else {
        await _service.unsaveTemplate(current.id);
      }
    } on Object catch (error) {
      if (error is! CircleAmbiguousMutation &&
          error is! OfflineException &&
          (error is! LoadFailure || error.phase != LoadPhase.conflict)) {
        rethrow;
      }
      reconciled = true;
    }
    final authoritative = await _service.fetchTemplate(current.id);
    if (authoritative.saved != target) {
      if (reconciled) throw const OfflineException();
      throw const LoadFailure(LoadPhase.conflict);
    }
    return CircleTemplateSaveResult(
      value: authoritative,
      reconciled: reconciled,
    );
  }
}

bool _sameAssets(List<CircleAsset> left, List<CircleAsset> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    final a = left[index];
    final b = right[index];
    if (a.assetId != b.assetId ||
        a.ordinal != b.ordinal ||
        a.note != b.note ||
        a.weightBps != b.weightBps) {
      return false;
    }
  }
  return true;
}
