// ignore_for_file: prefer_initializing_formals

import 'package:dio/dio.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart'
    as api;

import '../../../core/api/api_failure_mapper.dart';
import '../../../core/api/view_state.dart';
import '../../discover/domain/model.dart';
import '../domain/model.dart';
import 'repository.dart';

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
