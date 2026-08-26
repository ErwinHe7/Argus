import 'package:flutter/foundation.dart';

enum PortfolioCurrency { usd }

enum PortfolioStatus { active, archived }

enum PortfolioActivityType { contribution, order, rebalance, recurring }

@immutable
class PortfolioDemoDisclosure {
  const PortfolioDemoDisclosure({
    required this.isDemo,
    required this.observedAt,
    required this.sourceLabel,
    required this.limitations,
  });

  final bool isDemo;
  final DateTime observedAt;
  final String sourceLabel;
  final List<String> limitations;
}

@immutable
class PortfolioSummary {
  const PortfolioSummary({
    required this.id,
    required this.name,
    required this.cashMinor,
    required this.valuationMinor,
    required this.currency,
    required this.status,
    required this.isDefault,
    required this.version,
    required this.ledgerWatermark,
    required this.asOfTransactionId,
    required this.demo,
    required this.targetAllocation,
  });

  final String id;
  final String name;
  final int cashMinor;
  final int valuationMinor;
  final PortfolioCurrency currency;
  final PortfolioStatus status;
  final bool isDefault;
  final int version;
  final int ledgerWatermark;
  final String? asOfTransactionId;
  final PortfolioDemoDisclosure demo;
  final List<PortfolioTargetAllocation> targetAllocation;

  bool get isActive => status == PortfolioStatus.active;
}

@immutable
class PortfolioTargetAllocation {
  const PortfolioTargetAllocation({
    required this.assetId,
    required this.targetBps,
  });

  final String assetId;
  final int targetBps;
}

@immutable
class PortfolioCollection {
  const PortfolioCollection({required this.items});

  final List<PortfolioSummary> items;

  PortfolioSummary? byId(String id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  PortfolioSummary? get serverDefault {
    for (final item in items) {
      if (item.isDefault) return item;
    }
    return null;
  }
}

@immutable
class PortfolioHolding {
  const PortfolioHolding({
    required this.assetId,
    required this.symbol,
    required this.quantityValue,
    required this.quantityScale,
    required this.marketValueMinor,
    required this.currency,
    required this.ledgerWatermark,
    required this.asOfTransactionId,
  });

  final String assetId;
  final String symbol;
  final String quantityValue;
  final int quantityScale;
  final int marketValueMinor;
  final PortfolioCurrency currency;
  final int ledgerWatermark;
  final String asOfTransactionId;
}

@immutable
class PortfolioActivityEntry {
  const PortfolioActivityEntry({
    required this.id,
    required this.type,
    required this.descriptionCode,
    required this.effectiveAt,
    required this.cashMinor,
    required this.currency,
    required this.ledgerWatermark,
    required this.demo,
  });

  final String id;
  final PortfolioActivityType type;
  final String descriptionCode;
  final DateTime effectiveAt;
  final int cashMinor;
  final PortfolioCurrency currency;
  final int ledgerWatermark;
  final PortfolioDemoDisclosure demo;
}

@immutable
class PortfolioSnapshotView {
  const PortfolioSnapshotView({
    required this.id,
    required this.asOfTransactionId,
    required this.ledgerWatermark,
    required this.asOf,
    required this.cashMinor,
    required this.marketValueMinor,
    required this.currency,
    required this.demo,
  });

  final String id;
  final String asOfTransactionId;
  final int ledgerWatermark;
  final DateTime asOf;
  final int cashMinor;
  final int marketValueMinor;
  final PortfolioCurrency currency;
  final PortfolioDemoDisclosure demo;
}

@immutable
class PortfolioDetail {
  const PortfolioDetail({
    required this.portfolio,
    required this.holdings,
    required this.activity,
    required this.snapshots,
  });

  final PortfolioSummary portfolio;
  final List<PortfolioHolding> holdings;
  final List<PortfolioActivityEntry> activity;
  final List<PortfolioSnapshotView> snapshots;
}
