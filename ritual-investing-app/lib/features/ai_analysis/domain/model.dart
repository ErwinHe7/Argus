import 'package:flutter/foundation.dart';

enum AiTrackRecordKind { live, paperForwardTest, backtest }

/// Groups research portfolios by who or what the analysis is following.
///
/// This is deliberately separate from [AiTrackRecordKind]. A public-disclosure
/// tracker can still be a backtest, just as an AI simulation can.
enum AiPortfolioCategory { leoModel, aiSimulation, publicDisclosureTracker }

/// Describes what the displayed holdings actually represent.
enum AiHoldingsBasis {
  modelOutput,
  unofficialSimulation,
  delayedPublicDisclosure,
}

enum MarketRiskLevel { normal, watch, elevated, highStress }

enum MarketRiskSignalState { supportive, watch, stressed }

@immutable
class AiSectorAllocation {
  factory AiSectorAllocation({
    required String id,
    required String label,
    required int weightBps,
  }) {
    if (weightBps <= 0 || weightBps > 10000) {
      throw ArgumentError.value(
        weightBps,
        'weightBps',
        'must be greater than zero and no more than 10,000',
      );
    }
    return AiSectorAllocation._(
      id: _requiredText(id, 'id'),
      label: _requiredText(label, 'label'),
      weightBps: weightBps,
    );
  }

  const AiSectorAllocation._({
    required this.id,
    required this.label,
    required this.weightBps,
  });

  final String id;
  final String label;
  final int weightBps;
}

@immutable
class AiHolding {
  factory AiHolding({
    required String id,
    required String symbol,
    required String name,
    required int weightBps,
    required String rationale,
  }) {
    if (weightBps <= 0 || weightBps > 10000) {
      throw ArgumentError.value(
        weightBps,
        'weightBps',
        'must be greater than zero and no more than 10,000',
      );
    }
    return AiHolding._(
      id: _requiredText(id, 'id'),
      symbol: _requiredText(symbol, 'symbol'),
      name: _requiredText(name, 'name'),
      weightBps: weightBps,
      rationale: _requiredText(rationale, 'rationale'),
    );
  }

  const AiHolding._({
    required this.id,
    required this.symbol,
    required this.name,
    required this.weightBps,
    required this.rationale,
  });

  final String id;
  final String symbol;
  final String name;
  final int weightBps;
  final String rationale;
}

@immutable
class AiModelPortfolio {
  factory AiModelPortfolio({
    required String id,
    required String name,
    required String summary,
    required AiTrackRecordKind trackRecordKind,
    required String modelVersion,
    required DateTime start,
    required DateTime end,
    required int totalReturnBps,
    required String benchmarkLabel,
    required int benchmarkReturnBps,
    required int maxDrawdownMagnitudeBps,
    required int bestQuarterBps,
    required int worstQuarterBps,
    required DateTime holdingsAsOf,
    required String cadence,
    required String selectionUniverse,
    required bool dividendsIncluded,
    required String feeAssumption,
    required List<AiHolding> holdings,
    required List<int> returnSeriesBps,
    AiPortfolioCategory category = AiPortfolioCategory.leoModel,
    AiHoldingsBasis holdingsBasis = AiHoldingsBasis.modelOutput,
    String affiliationDisclosure =
        'Independent Leo research; no external affiliation or endorsement.',
    String sourceDisclosure = 'Deterministic educational data supplied by Leo, not live provider data.',
    List<AiSectorAllocation> sectorAllocations = const [],
    List<int> benchmarkReturnSeriesBps = const [],
    DateTime? sourceDataAsOf,
    String bestPeriodLabel = 'Best quarter',
    String worstPeriodLabel = 'Worst quarter',
    String? publicFigureName,
    String? publicFigureRole,
    String? portraitAssetPath,
    String? visualAssetPath,
  }) {
    final normalizedStart = start.toUtc();
    final normalizedEnd = end.toUtc();
    final normalizedHoldingsAsOf = holdingsAsOf.toUtc();
    final normalizedSourceDataAsOf = (sourceDataAsOf ?? holdingsAsOf).toUtc();
    if (normalizedStart.isAfter(normalizedEnd)) {
      throw ArgumentError.value(end, 'end', 'must be on or after start');
    }
    if (normalizedEnd.isAfter(normalizedHoldingsAsOf)) {
      throw ArgumentError.value(
        holdingsAsOf,
        'holdingsAsOf',
        'must be on or after the track-record end',
      );
    }
    if (normalizedSourceDataAsOf.isAfter(normalizedHoldingsAsOf)) {
      throw ArgumentError.value(
        sourceDataAsOf,
        'sourceDataAsOf',
        'must be on or before holdingsAsOf',
      );
    }
    if (maxDrawdownMagnitudeBps <= 0) {
      throw ArgumentError.value(
        maxDrawdownMagnitudeBps,
        'maxDrawdownMagnitudeBps',
        'must be expressed as a positive magnitude',
      );
    }
    if (bestQuarterBps < worstQuarterBps) {
      throw ArgumentError.value(
        bestQuarterBps,
        'bestQuarterBps',
        'must be greater than or equal to worstQuarterBps',
      );
    }
    if (holdings.isEmpty) {
      throw ArgumentError.value(holdings, 'holdings', 'must not be empty');
    }
    if (returnSeriesBps.isEmpty) {
      throw ArgumentError.value(
        returnSeriesBps,
        'returnSeriesBps',
        'must not be empty',
      );
    }
    if (benchmarkReturnSeriesBps.isNotEmpty) {
      if (benchmarkReturnSeriesBps.length != returnSeriesBps.length) {
        throw ArgumentError.value(
          benchmarkReturnSeriesBps.length,
          'benchmarkReturnSeriesBps',
          'must have the same number of points as returnSeriesBps',
        );
      }
      if (benchmarkReturnSeriesBps.last != benchmarkReturnBps) {
        throw ArgumentError.value(
          benchmarkReturnSeriesBps.last,
          'benchmarkReturnSeriesBps',
          'the final cumulative value must equal benchmarkReturnBps',
        );
      }
    }

    final holdingIds = <String>{};
    final holdingSymbols = <String>{};
    var allocatedWeightBps = 0;
    for (final holding in holdings) {
      if (!holdingIds.add(holding.id)) {
        throw ArgumentError.value(
          holding.id,
          'holdings',
          'holding ids must be unique',
        );
      }
      if (!holdingSymbols.add(holding.symbol.toUpperCase())) {
        throw ArgumentError.value(
          holding.symbol,
          'holdings',
          'holding symbols must be unique',
        );
      }
      allocatedWeightBps += holding.weightBps;
    }
    if (allocatedWeightBps > 10000) {
      throw ArgumentError.value(
        allocatedWeightBps,
        'holdings',
        'combined holding weight must not exceed 10,000 bps',
      );
    }

    final sectorIds = <String>{};
    var sectorWeightBps = 0;
    for (final sector in sectorAllocations) {
      if (!sectorIds.add(sector.id)) {
        throw ArgumentError.value(
          sector.id,
          'sectorAllocations',
          'sector ids must be unique',
        );
      }
      sectorWeightBps += sector.weightBps;
    }
    if (sectorAllocations.isNotEmpty && sectorWeightBps != 10000) {
      throw ArgumentError.value(
        sectorWeightBps,
        'sectorAllocations',
        'combined sector weight must equal 10,000 bps',
      );
    }

    return AiModelPortfolio._(
      id: _requiredText(id, 'id'),
      name: _requiredText(name, 'name'),
      summary: _requiredText(summary, 'summary'),
      trackRecordKind: trackRecordKind,
      modelVersion: _requiredText(modelVersion, 'modelVersion'),
      start: normalizedStart,
      end: normalizedEnd,
      totalReturnBps: totalReturnBps,
      benchmarkLabel: _requiredText(benchmarkLabel, 'benchmarkLabel'),
      benchmarkReturnBps: benchmarkReturnBps,
      maxDrawdownMagnitudeBps: maxDrawdownMagnitudeBps,
      bestQuarterBps: bestQuarterBps,
      worstQuarterBps: worstQuarterBps,
      holdingsAsOf: normalizedHoldingsAsOf,
      cadence: _requiredText(cadence, 'cadence'),
      selectionUniverse: _requiredText(selectionUniverse, 'selectionUniverse'),
      dividendsIncluded: dividendsIncluded,
      feeAssumption: _requiredText(feeAssumption, 'feeAssumption'),
      holdings: List.unmodifiable(holdings),
      returnSeriesBps: List.unmodifiable(returnSeriesBps),
      category: category,
      holdingsBasis: holdingsBasis,
      affiliationDisclosure: _requiredText(
        affiliationDisclosure,
        'affiliationDisclosure',
      ),
      sourceDisclosure: _requiredText(sourceDisclosure, 'sourceDisclosure'),
      sectorAllocations: List.unmodifiable(sectorAllocations),
      benchmarkReturnSeriesBps: List.unmodifiable(benchmarkReturnSeriesBps),
      sourceDataAsOf: normalizedSourceDataAsOf,
      bestPeriodLabel: _requiredText(bestPeriodLabel, 'bestPeriodLabel'),
      worstPeriodLabel: _requiredText(worstPeriodLabel, 'worstPeriodLabel'),
      publicFigureName: publicFigureName == null
          ? null
          : _requiredText(publicFigureName, 'publicFigureName'),
      publicFigureRole: publicFigureRole == null
          ? null
          : _requiredText(publicFigureRole, 'publicFigureRole'),
      portraitAssetPath: portraitAssetPath == null
          ? null
          : _requiredText(portraitAssetPath, 'portraitAssetPath'),
      visualAssetPath: visualAssetPath == null
          ? null
          : _requiredText(visualAssetPath, 'visualAssetPath'),
    );
  }

  const AiModelPortfolio._({
    required this.id,
    required this.name,
    required this.summary,
    required this.trackRecordKind,
    required this.modelVersion,
    required this.start,
    required this.end,
    required this.totalReturnBps,
    required this.benchmarkLabel,
    required this.benchmarkReturnBps,
    required this.maxDrawdownMagnitudeBps,
    required this.bestQuarterBps,
    required this.worstQuarterBps,
    required this.holdingsAsOf,
    required this.cadence,
    required this.selectionUniverse,
    required this.dividendsIncluded,
    required this.feeAssumption,
    required this.holdings,
    required this.returnSeriesBps,
    required this.category,
    required this.holdingsBasis,
    required this.affiliationDisclosure,
    required this.sourceDisclosure,
    required this.sectorAllocations,
    required this.benchmarkReturnSeriesBps,
    required this.sourceDataAsOf,
    required this.bestPeriodLabel,
    required this.worstPeriodLabel,
    required this.publicFigureName,
    required this.publicFigureRole,
    required this.portraitAssetPath,
    required this.visualAssetPath,
  });

  final String id;
  final String name;
  final String summary;
  final AiTrackRecordKind trackRecordKind;
  final String modelVersion;
  final DateTime start;
  final DateTime end;
  final int totalReturnBps;
  final String benchmarkLabel;
  final int benchmarkReturnBps;

  /// Stored as a positive magnitude. For example, a -12.4% drawdown is 1,240.
  final int maxDrawdownMagnitudeBps;

  final int bestQuarterBps;
  final int worstQuarterBps;
  final DateTime holdingsAsOf;
  final String cadence;
  final String selectionUniverse;
  final bool dividendsIncluded;
  final String feeAssumption;
  final List<AiHolding> holdings;
  final List<int> returnSeriesBps;
  final AiPortfolioCategory category;
  final AiHoldingsBasis holdingsBasis;
  final String affiliationDisclosure;
  final String sourceDisclosure;
  final List<AiSectorAllocation> sectorAllocations;
  final List<int> benchmarkReturnSeriesBps;

  /// Date of the underlying model input or public disclosure used to build
  /// the displayed holdings. This can predate [holdingsAsOf] for delayed
  /// public filings.
  final DateTime sourceDataAsOf;
  final String bestPeriodLabel;
  final String worstPeriodLabel;

  /// Optional visual identity for public-disclosure reconstructions. These
  /// fields identify the person associated with the reporting entity; they do
  /// not imply that the displayed reconstruction is the person's real return.
  final String? publicFigureName;
  final String? publicFigureRole;
  final String? portraitAssetPath;

  /// Optional editorial cover for Leo models and unofficial AI simulations.
  /// These visuals are product artwork, not provider marks or endorsements.
  final String? visualAssetPath;

  String get trackRecordLabel => switch (trackRecordKind) {
    AiTrackRecordKind.live => 'Live',
    AiTrackRecordKind.paperForwardTest => 'Paper forward test',
    AiTrackRecordKind.backtest => 'Backtest',
  };

  String get categoryLabel => switch (category) {
    AiPortfolioCategory.leoModel => 'Leo models',
    AiPortfolioCategory.aiSimulation => 'AI simulations',
    AiPortfolioCategory.publicDisclosureTracker => 'Public-disclosure trackers',
  };

  String get holdingsBasisLabel => switch (holdingsBasis) {
    AiHoldingsBasis.modelOutput => 'Model output',
    AiHoldingsBasis.unofficialSimulation => 'Unofficial simulation',
    AiHoldingsBasis.delayedPublicDisclosure => 'Delayed public disclosure',
  };
}

@immutable
class MarketRiskSignal {
  factory MarketRiskSignal({
    required String id,
    required String label,
    required MarketRiskSignalState state,
    required DateTime observedAt,
    required String horizon,
    required String summary,
    required String validation,
    required String limitations,
  }) => MarketRiskSignal._(
    id: _requiredText(id, 'id'),
    label: _requiredText(label, 'label'),
    state: state,
    observedAt: observedAt.toUtc(),
    horizon: _requiredText(horizon, 'horizon'),
    summary: _requiredText(summary, 'summary'),
    validation: _requiredText(validation, 'validation'),
    limitations: _requiredText(limitations, 'limitations'),
  );

  const MarketRiskSignal._({
    required this.id,
    required this.label,
    required this.state,
    required this.observedAt,
    required this.horizon,
    required this.summary,
    required this.validation,
    required this.limitations,
  });

  final String id;
  final String label;
  final MarketRiskSignalState state;
  final DateTime observedAt;
  final String horizon;
  final String summary;
  final String validation;
  final String limitations;
}

@immutable
class MarketRiskRegime {
  factory MarketRiskRegime({
    required MarketRiskLevel level,
    required String label,
    required String summary,
    required DateTime observedAt,
    required DateTime validThrough,
    required String horizon,
    required String validation,
    required String limitations,
    required List<MarketRiskSignal> signals,
  }) {
    final normalizedObservedAt = observedAt.toUtc();
    final normalizedValidThrough = validThrough.toUtc();
    if (!normalizedValidThrough.isAfter(normalizedObservedAt)) {
      throw ArgumentError.value(
        validThrough,
        'validThrough',
        'must be after observedAt',
      );
    }
    if (signals.isEmpty) {
      throw ArgumentError.value(signals, 'signals', 'must not be empty');
    }
    final signalIds = <String>{};
    for (final signal in signals) {
      if (!signalIds.add(signal.id)) {
        throw ArgumentError.value(
          signal.id,
          'signals',
          'signal ids must be unique',
        );
      }
      if (signal.observedAt.isAfter(normalizedValidThrough)) {
        throw ArgumentError.value(
          signal.observedAt,
          'signals',
          'signal timestamps must not be after validThrough',
        );
      }
    }

    return MarketRiskRegime._(
      level: level,
      label: _requiredText(label, 'label'),
      summary: _requiredText(summary, 'summary'),
      observedAt: normalizedObservedAt,
      validThrough: normalizedValidThrough,
      horizon: _requiredText(horizon, 'horizon'),
      validation: _requiredText(validation, 'validation'),
      limitations: _requiredText(limitations, 'limitations'),
      signals: List.unmodifiable(signals),
    );
  }

  const MarketRiskRegime._({
    required this.level,
    required this.label,
    required this.summary,
    required this.observedAt,
    required this.validThrough,
    required this.horizon,
    required this.validation,
    required this.limitations,
    required this.signals,
  });

  final MarketRiskLevel level;
  final String label;
  final String summary;
  final DateTime observedAt;
  final DateTime validThrough;
  final String horizon;
  final String validation;
  final String limitations;
  final List<MarketRiskSignal> signals;

  int get totalSignalCount => signals.length;

  /// Counts every non-supportive signal: both [MarketRiskSignalState.watch]
  /// and [MarketRiskSignalState.stressed].
  int get activeSignalCount => signals
      .where((signal) => signal.state != MarketRiskSignalState.supportive)
      .length;

  String get levelLabel => switch (level) {
    MarketRiskLevel.normal => 'Normal',
    MarketRiskLevel.watch => 'Watch',
    MarketRiskLevel.elevated => 'Elevated',
    MarketRiskLevel.highStress => 'High stress',
  };
}

@immutable
class AiAnalysisSnapshot {
  factory AiAnalysisSnapshot({
    required String id,
    required List<AiModelPortfolio> models,
    required MarketRiskRegime riskRegime,
    required DateTime observedAt,
    required DateTime availableAt,
    required DateTime expiresAt,
    required String sourceLabel,
    required String methodologyVersion,
    required bool isDemo,
    required List<String> limitations,
  }) {
    final normalizedObservedAt = observedAt.toUtc();
    final normalizedAvailableAt = availableAt.toUtc();
    final normalizedExpiresAt = expiresAt.toUtc();
    if (normalizedObservedAt.isAfter(normalizedAvailableAt)) {
      throw ArgumentError.value(
        availableAt,
        'availableAt',
        'must be on or after observedAt',
      );
    }
    if (!normalizedExpiresAt.isAfter(normalizedAvailableAt)) {
      throw ArgumentError.value(
        expiresAt,
        'expiresAt',
        'must be after availableAt',
      );
    }
    if (models.isEmpty) {
      throw ArgumentError.value(models, 'models', 'must not be empty');
    }
    if (limitations.isEmpty) {
      throw ArgumentError.value(
        limitations,
        'limitations',
        'must not be empty',
      );
    }
    final modelIds = <String>{};
    for (final model in models) {
      if (!modelIds.add(model.id)) {
        throw ArgumentError.value(
          model.id,
          'models',
          'model ids must be unique',
        );
      }
    }
    final normalizedLimitations = limitations
        .map((value) => _requiredText(value, 'limitations'))
        .toList(growable: false);

    return AiAnalysisSnapshot._(
      id: _requiredText(id, 'id'),
      models: List.unmodifiable(models),
      riskRegime: riskRegime,
      observedAt: normalizedObservedAt,
      availableAt: normalizedAvailableAt,
      expiresAt: normalizedExpiresAt,
      sourceLabel: _requiredText(sourceLabel, 'sourceLabel'),
      methodologyVersion: _requiredText(
        methodologyVersion,
        'methodologyVersion',
      ),
      isDemo: isDemo,
      limitations: List.unmodifiable(normalizedLimitations),
    );
  }

  const AiAnalysisSnapshot._({
    required this.id,
    required this.models,
    required this.riskRegime,
    required this.observedAt,
    required this.availableAt,
    required this.expiresAt,
    required this.sourceLabel,
    required this.methodologyVersion,
    required this.isDemo,
    required this.limitations,
  });

  final String id;
  final List<AiModelPortfolio> models;
  final MarketRiskRegime riskRegime;
  final DateTime observedAt;
  final DateTime availableAt;
  final DateTime expiresAt;
  final String sourceLabel;
  final String methodologyVersion;
  final bool isDemo;
  final List<String> limitations;

  bool isFreshAt(DateTime now) {
    final normalizedNow = now.toUtc();
    return !normalizedNow.isBefore(availableAt) &&
        normalizedNow.isBefore(expiresAt);
  }
}

String _requiredText(String value, String name) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, name, 'must not be empty');
  }
  return normalized;
}
