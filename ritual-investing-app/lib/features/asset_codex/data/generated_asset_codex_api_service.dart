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
      _saves = api.SavedApi(client.dio);

  final api.AssetsApi _assets;
  final api.SavedApi _saves;

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
                  api.AssetRiskSeverityEnum.low => AssetRiskSeverity.low,
                  api.AssetRiskSeverityEnum.medium => AssetRiskSeverity.medium,
                  api.AssetRiskSeverityEnum.high => AssetRiskSeverity.high,
                  api.AssetRiskSeverityEnum.unknownDefaultOpenApi =>
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
      return values.map(_evidenceDetail).toList(growable: false);
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
        items: value.assets.map(_comparisonItem).toList(growable: false),
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
      await _saves.saveItem(
        itemKind: 'asset',
        itemId: assetId,
        saveItemRequest: api.SaveItemRequest(
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
      await _saves.unsaveItem(itemKind: 'asset', itemId: assetId);
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

String _currency(String value) => switch (value) {
  'USD' => value,
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

AssetEvidenceDetail _evidenceDetail(api.EvidenceDetail value) {
  final rawUrl = value.source_.url;
  final sourceUrl = rawUrl == null ? null : Uri.tryParse(rawUrl);
  if (sourceUrl == null ||
      sourceUrl.scheme != 'https' ||
      !sourceUrl.hasAuthority) {
    throw const LoadFailure(LoadPhase.terminalFailure);
  }
  return AssetEvidenceDetail(
    claimId: value.claimId,
    factorLabel: value.factorLabel,
    observedAt: value.observedAt,
    summary: value.summary,
    uncertainty: value.uncertainty,
    publisher: value.source_.publisher,
    sourceTitle: value.source_.title,
    sourceUrl: sourceUrl,
    publishedAt: value.source_.publishedAt,
  );
}

AssetDemoDisclosure _demo(api.ResearchDisclosure value) => AssetDemoDisclosure(
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

AssetComparisonItem _comparisonItem(api.AssetComparisonAssetsInner value) {
  final metric = value.latestMetric;
  if (metric == null) {
    throw const LoadFailure(LoadPhase.terminalFailure);
  }
  return AssetComparisonItem(
    asset: _summary(value.asset),
    metric: _metric(metric),
    riskCount: value.riskCount,
  );
}

api.SaveItemRequestSourceKindEnum _sourceKind(AssetSourceKind value) =>
    switch (value) {
      AssetSourceKind.ritual => api.SaveItemRequestSourceKindEnum.ritual,
      AssetSourceKind.circle => api.SaveItemRequestSourceKindEnum.circle,
      AssetSourceKind.discover => api.SaveItemRequestSourceKindEnum.discover,
      AssetSourceKind.search => api.SaveItemRequestSourceKindEnum.search,
      AssetSourceKind.direct => api.SaveItemRequestSourceKindEnum.direct,
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
