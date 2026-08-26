// ignore_for_file: prefer_initializing_formals

import 'package:dio/dio.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart'
    as api;

import '../../../core/api/api_failure_mapper.dart';
import '../../../core/api/view_state.dart';
import '../../discover/domain/model.dart';
import '../domain/model.dart';
import 'repository.dart';

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
