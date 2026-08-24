import 'package:flutter/foundation.dart';

@immutable
class PortfolioSummary {
  const PortfolioSummary({
    required this.id,
    required this.name,
    required this.cashMinor,
    required this.valuationMinor,
    required this.version,
    required this.ledgerWatermark,
  });

  final String id;
  final String name;
  final int cashMinor;
  final int valuationMinor;
  final int version;
  final int ledgerWatermark;
}

@immutable
class PortfolioCollection {
  const PortfolioCollection({required this.items});

  final List<PortfolioSummary> items;
}

@immutable
class ContributionReceipt {
  const ContributionReceipt({
    required this.commandId,
    required this.portfolioVersion,
  });

  final String commandId;
  final int portfolioVersion;
}
