// ignore_for_file: prefer_initializing_formals

import 'package:dio/dio.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart'
    as api;

import '../../../core/api/ritual_api.dart';
import '../../../core/api/view_state.dart';
import '../../../core/cache/cached_read.dart';
import '../../../core/cache/read_cache.dart';
import '../../discover/domain/model.dart';
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

class GeneratedCircleService implements CircleService {
  GeneratedCircleService(api.RitualInvestingApiClient client)
    : _circles = api.CirclesApi(client.dio),
      _discover = api.DiscoverApi(client.dio),
      _saves = api.SavesApi(client.dio);

  final api.CirclesApi _circles;
  final api.DiscoverApi _discover;
  final api.SavesApi _saves;

  @override
  Future<CircleCollection> fetchList({required bool includeArchived}) async {
    try {
      final response = (await _circles.listCircles(
        archived: includeArchived ? 'include' : 'exclude',
        limit: 50,
      )).data!;
      return CircleCollection(
        items: response.data.map(_circle).toList(growable: false),
        nextCursor: response.meta.nextCursor,
        hasMore: response.meta.hasMore,
      );
    } on DioException catch (error) {
      throw ApiFailureMapper.map(error);
    } on LoadFailure {
      rethrow;
    } on Object {
      throw const LoadFailure(LoadPhase.terminalFailure);
    }
  }

  @override
  Future<PrivateCircle> fetchDetail(String circleId) async {
    try {
      return _circle((await _circles.getCircle(id: circleId)).data!.data);
    } on DioException catch (error) {
      throw ApiFailureMapper.map(error);
    } on LoadFailure {
      rethrow;
    } on Object {
      throw const LoadFailure(LoadPhase.terminalFailure);
    }
  }

  @override
  Future<PrivateCircle> create(CircleCreateCommand command) async {
    try {
      final response = await _circles.createCircle(
        idempotencyKey: command.idempotencyKey,
        createCircleRequest: api.CreateCircleRequest(
          title: command.title,
          description: command.description,
          assets: command.assets.map(_requestAsset).toList(growable: false),
        ),
      );
      return _circle(response.data!.data);
    } on DioException catch (error) {
      if (_ambiguous(error)) throw const CircleAmbiguousMutation();
      throw ApiFailureMapper.map(error);
    }
  }

  @override
  Future<PrivateCircle> copy(CircleCopyCommand command) async {
    try {
      final response = await _circles.copyCircleTemplate(
        id: command.templateId,
        idempotencyKey: command.idempotencyKey,
        copyCircleTemplateRequest: api.CopyCircleTemplateRequest(
          title: command.title,
        ),
      );
      return _circle(response.data!.data);
    } on DioException catch (error) {
      if (_ambiguous(error)) throw const CircleAmbiguousMutation();
      throw ApiFailureMapper.map(error);
    }
  }

  @override
  Future<PrivateCircle> patch(
    String circleId,
    int expectedVersion,
    CircleDraft draft,
  ) async {
    try {
      final response = await _circles.patchCircle(
        id: circleId,
        ifMatch: _etag(expectedVersion),
        patchCircleRequest: api.PatchCircleRequest(
          title: draft.title,
          description: draft.description,
        ),
      );
      return _circle(response.data!.data);
    } on DioException catch (error) {
      if (_ambiguous(error)) throw const CircleAmbiguousMutation();
      throw ApiFailureMapper.map(error);
    }
  }

  @override
  Future<PrivateCircle> replaceAssets(
    String circleId,
    int expectedVersion,
    List<CircleAsset> assets,
  ) async {
    try {
      final response = await _circles.replaceCircleAssets(
        id: circleId,
        ifMatch: _etag(expectedVersion),
        replaceCircleAssetsRequest: api.ReplaceCircleAssetsRequest(
          assets: assets.map(_requestAsset).toList(growable: false),
        ),
      );
      return _circle(response.data!.data);
    } on DioException catch (error) {
      if (_ambiguous(error)) throw const CircleAmbiguousMutation();
      throw ApiFailureMapper.map(error);
    }
  }

  @override
  Future<PrivateCircle> putAsset(
    String circleId,
    int expectedVersion,
    CircleAsset asset,
  ) async {
    try {
      final response = await _circles.putCircleAsset(
        id: circleId,
        assetId: asset.assetId,
        ifMatch: _etag(expectedVersion),
        putCircleAssetRequest: api.PutCircleAssetRequest(
          ordinal: asset.ordinal,
          note: asset.note,
          weightBps: asset.weightBps,
        ),
      );
      return _circle(response.data!.data);
    } on DioException catch (error) {
      if (_ambiguous(error)) throw const CircleAmbiguousMutation();
      throw ApiFailureMapper.map(error);
    }
  }

  @override
  Future<PrivateCircle> removeAsset(
    String circleId,
    int expectedVersion,
    String assetId,
  ) async {
    try {
      final response = await _circles.deleteCircleAsset(
        id: circleId,
        assetId: assetId,
        ifMatch: _etag(expectedVersion),
      );
      return _circle(response.data!.data);
    } on DioException catch (error) {
      if (_ambiguous(error)) throw const CircleAmbiguousMutation();
      throw ApiFailureMapper.map(error);
    }
  }

  @override
  Future<void> archive(String circleId, int expectedVersion) async {
    try {
      await _circles.archiveCircle(
        id: circleId,
        ifMatch: _etag(expectedVersion),
      );
    } on DioException catch (error) {
      if (_ambiguous(error)) throw const CircleAmbiguousMutation();
      throw ApiFailureMapper.map(error);
    }
  }

  @override
  Future<CircleTemplateDetail> fetchTemplate(String templateId) async {
    try {
      final value = (await _discover.getCircleTemplate(id: templateId))
          .data!
          .data;
      return CircleTemplateDetail(
        id: value.id,
        revisionId: value.revisionId,
        slug: value.slug,
        title: value.title,
        description: value.description,
        theme: value.theme,
        creator: _creator(value.creator),
        assets: value.assets.map(_templateAsset).toList(growable: false),
        saved: value.saved,
        demo: _demo(value.demo),
      );
    } on DioException catch (error) {
      throw ApiFailureMapper.map(error);
    } on LoadFailure {
      rethrow;
    } on Object {
      throw const LoadFailure(LoadPhase.terminalFailure);
    }
  }

  @override
  Future<void> saveTemplate(String templateId) async {
    try {
      await _saves.saveCircleTemplate(
        id: templateId,
        saveAssetRequest: api.SaveAssetRequest(),
      );
    } on DioException catch (error) {
      if (_ambiguous(error)) throw const CircleAmbiguousMutation();
      throw ApiFailureMapper.map(error);
    }
  }

  @override
  Future<void> unsaveTemplate(String templateId) async {
    try {
      await _saves.unsaveCircleTemplate(id: templateId);
    } on DioException catch (error) {
      if (_ambiguous(error)) throw const CircleAmbiguousMutation();
      throw ApiFailureMapper.map(error);
    }
  }
}

PrivateCircle _circle(api.CircleView value) {
  if (!value.private) throw const LoadFailure(LoadPhase.terminalFailure);
  return PrivateCircle(
    id: value.id,
    title: value.title,
    description: value.description,
    private: value.private,
    version: value.version,
    assets: value.assets
        .map(
          (asset) => CircleAsset(
            assetId: asset.assetId,
            ordinal: asset.ordinal,
            note: asset.note,
            weightBps: asset.weightBps,
          ),
        )
        .toList(growable: false),
    sourceTemplateId: value.sourceTemplateId,
    sourceRevisionId: value.sourceRevisionId,
    archivedAt: value.archivedAt,
  );
}

api.CreateCircleRequestAssetsInner _requestAsset(CircleAsset value) =>
    api.CreateCircleRequestAssetsInner(
      assetId: value.assetId,
      ordinal: value.ordinal,
      note: value.note,
      weightBps: value.weightBps,
    );

CircleTemplateAsset _templateAsset(api.CircleTemplateDetailAssetsInner value) {
  switch (value.assetType) {
    case api.CircleTemplateDetailAssetsInnerAssetTypeEnum.equity:
    case api.CircleTemplateDetailAssetsInnerAssetTypeEnum.etf:
    case api.CircleTemplateDetailAssetsInnerAssetTypeEnum.marketIndex:
    case api.CircleTemplateDetailAssetsInnerAssetTypeEnum.cash:
      break;
    case api.CircleTemplateDetailAssetsInnerAssetTypeEnum.unknownDefaultOpenApi:
      throw const LoadFailure(LoadPhase.terminalFailure);
  }
  if (value.currency != api.CircleTemplateDetailAssetsInnerCurrencyEnum.USD) {
    throw const LoadFailure(LoadPhase.terminalFailure);
  }
  return CircleTemplateAsset(
    id: value.id,
    revisionId: value.revisionId,
    slug: value.slug,
    symbol: value.symbol,
    name: value.name,
    appearanceReason: value.appearanceReason,
    note: value.note,
    ordinal: value.ordinal,
    weightBps: value.weightBps,
    demo: _demo(value.demo),
  );
}

SeededCreatorView _creator(api.SeededCreator value) {
  if (!value.isFictional) {
    throw const LoadFailure(LoadPhase.terminalFailure);
  }
  return SeededCreatorView(
    id: value.id,
    slug: value.slug,
    displayName: value.displayName,
    bio: value.bio,
    isFictional: true,
    demo: _demo(value.demo),
  );
}

ResearchDemoDisclosure _demo(api.DemoDisclosure value) =>
    ResearchDemoDisclosure(
      isDemo: value.isDemo,
      observedAt: value.observedAt,
      sourceLabel: value.sourceLabel,
      limitations: value.limitations,
    );

String _etag(int version) => '"v$version"';

bool _ambiguous(DioException error) =>
    error.type == DioExceptionType.connectionError ||
    error.type == DioExceptionType.connectionTimeout ||
    error.type == DioExceptionType.receiveTimeout ||
    error.type == DioExceptionType.sendTimeout;
