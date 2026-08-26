// ignore_for_file: prefer_initializing_formals

import 'package:dio/dio.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart'
    as api;

import '../../../core/api/api_failure_mapper.dart';
import '../../../core/api/view_state.dart';
import '../domain/model.dart';
import 'repository.dart';

class GeneratedAssetCodexService implements AssetCodexService {
  GeneratedAssetCodexService(api.RitualInvestingApiClient client)
    : _assets = api.AssetsApi(client.dio),
      _saves = api.SavesApi(client.dio);

  final api.AssetsApi _assets;
  final api.SavesApi _saves;

  @override
  Future<AssetCodex> fetchDetail(String assetId) async {
    try {
      final value = (await _assets.getAsset(assetId: assetId)).data!.data;
      return AssetCodex(
        id: value.id,
        revisionId: value.revisionId,
        slug: value.slug,
        symbol: value.symbol,
        name: value.name,
        kind: _assetKind(value.assetType),
        currency: _currency(value.currency),
        appearanceReason: value.appearanceReason,
        thesis: value.thesis,
        limitations: value.limitations,
        metricsAsOf: value.metricsAsOf,
        evidence: value.evidence.map(_evidenceSummary).toList(growable: false),
        detailedEvidence: const [],
        risks: value.risks
            .map(
              (risk) => AssetRisk(
                title: risk.title,
                detail: risk.detail,
                severity: switch (risk.severity) {
                  api.AssetCodexDetailRisksInnerSeverityEnum.low =>
                    AssetRiskSeverity.low,
                  api.AssetCodexDetailRisksInnerSeverityEnum.medium =>
                    AssetRiskSeverity.medium,
                  api.AssetCodexDetailRisksInnerSeverityEnum.high =>
                    AssetRiskSeverity.high,
                  api
                      .AssetCodexDetailRisksInnerSeverityEnum
                      .unknownDefaultOpenApi =>
                    throw const LoadFailure(LoadPhase.terminalFailure),
                },
              ),
            )
            .toList(growable: false),
        saved: value.saved,
        demo: _demo(value.demo),
        source: const AssetSourceContext(kind: AssetSourceKind.direct),
      );
    } on DioException catch (error) {
      _throwAssetFailure(error);
    }
  }

  @override
  Future<List<AssetEvidenceDetail>> fetchEvidence(String assetId) async {
    try {
      final values = (await _assets.getAssetEvidence(assetId: assetId))
          .data!
          .data;
      return values
          .map(
            (value) => AssetEvidenceDetail(
              claimId: value.claimId,
              factorLabel: value.factorLabel,
              observedAt: value.observedAt,
              summary: value.summary,
              uncertainty: value.uncertainty,
              publisher: value.source_.publisher,
              sourceTitle: value.source_.title,
              sourceUrl: Uri.parse(value.source_.url),
              publishedAt: value.source_.publishedAt,
            ),
          )
          .toList(growable: false);
    } on DioException catch (error) {
      _throwAssetFailure(error);
    } on FormatException {
      throw const LoadFailure(LoadPhase.terminalFailure);
    }
  }

  @override
  Future<List<AssetMetric>> fetchMetrics(String assetId) async {
    try {
      final values = (await _assets.getAssetMetrics(assetId: assetId))
          .data!
          .data;
      return values.map(_metric).toList(growable: false);
    } on DioException catch (error) {
      _throwAssetFailure(error);
    }
  }

  @override
  Future<AssetComparison> compare(List<String> assetIds) async {
    try {
      final value = (await _assets.compareAssets(
        compareAssetsRequest: api.CompareAssetsRequest(assetIds: assetIds),
      )).data!.data;
      return AssetComparison(
        items: value.assets
            .map(
              (item) => AssetComparisonItem(
                asset: _summary(item.asset),
                metric: _metric(item.latestMetric),
                riskCount: item.riskCount,
              ),
            )
            .toList(growable: false),
        comparedAt: value.comparedAt,
        demo: _demo(value.demo),
      );
    } on DioException catch (error) {
      _throwAssetFailure(error);
    }
  }

  @override
  Future<void> save(String assetId, AssetSourceContext source) async {
    try {
      await _saves.saveAsset(
        id: assetId,
        saveAssetRequest: api.SaveAssetRequest(
          sourceId: source.resourceId,
          sourceKind: _sourceKind(source.kind),
        ),
      );
    } on DioException catch (error) {
      if (_ambiguous(error)) throw const AssetAmbiguousMutation();
      _throwAssetFailure(error);
    }
  }

  @override
  Future<void> unsave(String assetId) async {
    try {
      await _saves.unsaveAsset(id: assetId);
    } on DioException catch (error) {
      if (_ambiguous(error)) throw const AssetAmbiguousMutation();
      _throwAssetFailure(error);
    }
  }
}

AssetKind _assetKind(Object value) => switch (value) {
  api.AssetCodexDetailAssetTypeEnum.equity ||
  api.AssetSummaryAssetTypeEnum.equity => AssetKind.equity,
  api.AssetCodexDetailAssetTypeEnum.etf ||
  api.AssetSummaryAssetTypeEnum.etf => AssetKind.etf,
  api.AssetCodexDetailAssetTypeEnum.marketIndex ||
  api.AssetSummaryAssetTypeEnum.marketIndex => AssetKind.marketIndex,
  api.AssetCodexDetailAssetTypeEnum.cash ||
  api.AssetSummaryAssetTypeEnum.cash => AssetKind.cash,
  _ => throw const LoadFailure(LoadPhase.terminalFailure),
};

String _currency(Object value) => switch (value) {
  api.AssetCodexDetailCurrencyEnum.USD ||
  api.AssetSummaryCurrencyEnum.USD => 'USD',
  _ => throw const LoadFailure(LoadPhase.terminalFailure),
};

AssetEvidenceSummary _evidenceSummary(api.EvidenceSummary value) =>
    AssetEvidenceSummary(
      claimId: value.claimId,
      factorLabel: value.factorLabel,
      observedAt: value.observedAt,
      summary: value.summary,
      uncertainty: value.uncertainty,
    );

AssetDemoDisclosure _demo(api.DemoDisclosure value) => AssetDemoDisclosure(
  isDemo: value.isDemo,
  observedAt: value.observedAt,
  sourceLabel: value.sourceLabel,
  limitations: value.limitations,
);

AssetMetric _metric(api.AssetMetric value) => AssetMetric(
  priceMinor: value.priceMinor,
  changeBps: value.changeBps,
  expenseRatioBps: value.expenseRatioBps,
  observedAt: value.observedAt,
  sourceLabel: value.sourceLabel,
  demo: _demo(value.demo),
);

AssetSummaryView _summary(api.AssetSummary value) => AssetSummaryView(
  id: value.id,
  revisionId: value.revisionId,
  slug: value.slug,
  symbol: value.symbol,
  name: value.name,
  kind: _assetKind(value.assetType),
  currency: _currency(value.currency),
  appearanceReason: value.appearanceReason,
  demo: _demo(value.demo),
);

api.SaveAssetRequestSourceKindEnum _sourceKind(AssetSourceKind value) =>
    switch (value) {
      AssetSourceKind.ritual => api.SaveAssetRequestSourceKindEnum.ritual,
      AssetSourceKind.circle => api.SaveAssetRequestSourceKindEnum.circle,
      AssetSourceKind.discover => api.SaveAssetRequestSourceKindEnum.discover,
      AssetSourceKind.search => api.SaveAssetRequestSourceKindEnum.search,
      AssetSourceKind.direct => api.SaveAssetRequestSourceKindEnum.direct,
    };

Never _throwAssetFailure(DioException error) {
  if (_ambiguous(error)) throw const OfflineException();
  throw ApiFailureMapper.map(error);
}

bool _ambiguous(DioException error) =>
    error.type == DioExceptionType.connectionError ||
    error.type == DioExceptionType.connectionTimeout ||
    error.type == DioExceptionType.receiveTimeout ||
    error.type == DioExceptionType.sendTimeout;
