// ignore_for_file: prefer_initializing_formals

import 'package:dio/dio.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart'
    as api;

import '../../../core/api/api_failure_mapper.dart';
import '../../../core/api/view_state.dart';
import '../../../core/cache/cached_read.dart';
import '../../../core/cache/read_cache.dart';
import '../../discover/domain/model.dart';
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

class GeneratedGrimoireService implements GrimoireService {
  GeneratedGrimoireService(api.RitualInvestingApiClient client)
    : _discover = api.DiscoverApi(client.dio),
      _saves = api.SavesApi(client.dio);

  final api.DiscoverApi _discover;
  final api.SavesApi _saves;

  @override
  Future<GrimoireDetail> fetchDetail(String grimoireId) async {
    try {
      final value = (await _discover.getGrimoire(id: grimoireId)).data!.data;
      return GrimoireDetail(
        id: value.id,
        revisionId: value.revisionId,
        slug: value.slug,
        title: value.title,
        description: value.description,
        theme: value.theme,
        curatorLabel: value.curatorLabel,
        assets: value.assets.map(_asset).toList(growable: false),
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
  Future<void> save(String grimoireId) async {
    try {
      await _saves.saveGrimoire(
        id: grimoireId,
        saveAssetRequest: api.SaveAssetRequest(),
      );
    } on DioException catch (error) {
      if (_ambiguous(error)) throw const GrimoireAmbiguousMutation();
      throw ApiFailureMapper.map(error);
    }
  }

  @override
  Future<void> unsave(String grimoireId) async {
    try {
      await _saves.unsaveGrimoire(id: grimoireId);
    } on DioException catch (error) {
      if (_ambiguous(error)) throw const GrimoireAmbiguousMutation();
      throw ApiFailureMapper.map(error);
    }
  }
}

GrimoireAssetReference _asset(api.AssetSummary value) {
  if (value.assetType == api.AssetSummaryAssetTypeEnum.unknownDefaultOpenApi ||
      value.currency == api.AssetSummaryCurrencyEnum.unknownDefaultOpenApi) {
    throw const LoadFailure(LoadPhase.terminalFailure);
  }
  return GrimoireAssetReference(
    id: value.id,
    revisionId: value.revisionId,
    slug: value.slug,
    symbol: value.symbol,
    name: value.name,
    appearanceReason: value.appearanceReason,
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

bool _ambiguous(DioException error) =>
    error.type == DioExceptionType.connectionError ||
    error.type == DioExceptionType.connectionTimeout ||
    error.type == DioExceptionType.receiveTimeout ||
    error.type == DioExceptionType.sendTimeout;
