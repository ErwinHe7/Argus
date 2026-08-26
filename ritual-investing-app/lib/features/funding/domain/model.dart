import 'package:flutter/foundation.dart';

import '../../../core/api/view_state.dart';
import '../../../core/bootstrap/member_bootstrap.dart';
import '../../portfolio/domain/model.dart';

enum FundingFixture { moonReserve, constellationSavings }

enum FundingSourceStatus { active, inactive }

@immutable
class FundingDemoDisclosure {
  const FundingDemoDisclosure({
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
class FundingSource {
  const FundingSource({
    required this.id,
    required this.fixture,
    required this.displayLabel,
    required this.fictionalLast4,
    required this.status,
    required this.demo,
  });

  final String id;
  final FundingFixture fixture;
  final String displayLabel;
  final String fictionalLast4;
  final FundingSourceStatus status;
  final FundingDemoDisclosure demo;

  bool get isActive => status == FundingSourceStatus.active;
}

@immutable
class FundingCollection {
  const FundingCollection({required this.items});
  final List<FundingSource> items;
}

enum FundingFailureReason { fundingSourceInUse, other }

class FundingFailure implements Exception {
  const FundingFailure(this.phase, this.reason);
  const FundingFailure.fundingSourceInUse()
    : phase = LoadPhase.conflict,
      reason = FundingFailureReason.fundingSourceInUse;

  final LoadPhase phase;
  final FundingFailureReason reason;
}

@immutable
class ContributionCommand {
  const ContributionCommand({
    required this.portfolioId,
    required this.sourceId,
    required this.minorUnits,
    required this.currency,
    required this.effectiveAt,
    required this.idempotencyKey,
  });

  final String portfolioId;
  final String sourceId;
  final int minorUnits;
  final PortfolioCurrency currency;
  final DateTime? effectiveAt;
  final String idempotencyKey;
}

@immutable
class ContributionDraft {
  const ContributionDraft({
    required this.portfolioId,
    required this.sourceId,
    required this.minorUnits,
    required this.currency,
    required this.effectiveAt,
  });

  final String portfolioId;
  final String sourceId;
  final int minorUnits;
  final PortfolioCurrency currency;
  final DateTime? effectiveAt;
}

@immutable
class ContributionReceipt {
  const ContributionReceipt({
    required this.commandId,
    required this.portfolioVersion,
    required this.ledgerTransactionIds,
    required this.demo,
  });

  final String commandId;
  final int portfolioVersion;
  final List<String> ledgerTransactionIds;
  final FundingDemoDisclosure demo;
}

class AmbiguousContributionFailure implements Exception {
  const AmbiguousContributionFailure();
}

@immutable
class ContributionDefaults {
  const ContributionDefaults({required this.minorUnits, required this.label});

  final int minorUnits;
  final String label;

  factory ContributionDefaults.forRhythm(MemberContributionRhythm rhythm) =>
      switch (rhythm) {
        MemberContributionRhythm.weekly => const ContributionDefaults(
          minorUnits: 2500,
          label: 'Weekly rhythm · editable one-time suggestion',
        ),
        MemberContributionRhythm.biweekly => const ContributionDefaults(
          minorUnits: 5000,
          label: 'Every-two-weeks rhythm · editable one-time suggestion',
        ),
        MemberContributionRhythm.monthly => const ContributionDefaults(
          minorUnits: 10000,
          label: 'Monthly rhythm · editable one-time suggestion',
        ),
        MemberContributionRhythm.irregular => const ContributionDefaults(
          minorUnits: 5000,
          label: 'Flexible rhythm · editable one-time suggestion',
        ),
        MemberContributionRhythm.notSure ||
        MemberContributionRhythm.unavailable => const ContributionDefaults(
          minorUnits: 2500,
          label: 'A flexible editable one-time suggestion',
        ),
      };
}
