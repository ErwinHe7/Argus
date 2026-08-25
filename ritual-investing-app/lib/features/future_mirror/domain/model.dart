import 'package:flutter/foundation.dart';

import '../../../core/bootstrap/member_bootstrap.dart';
import '../../funding/domain/model.dart';

enum FutureMirrorField {
  name,
  monthlyContribution,
  lowReturn,
  midReturn,
  highReturn,
}

@immutable
class FutureMirrorDemoDisclosure {
  const FutureMirrorDemoDisclosure({
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
class FutureMirrorDraft {
  const FutureMirrorDraft({
    required this.name,
    required this.monthlyContributionMinor,
    required this.lowReturnBps,
    required this.midReturnBps,
    required this.highReturnBps,
  });

  final String name;
  final int monthlyContributionMinor;
  final int lowReturnBps;
  final int midReturnBps;
  final int highReturnBps;

  Map<String, Object?> toCanonicalMap() => {
    'name': name.trim(),
    'monthly_contribution_minor': monthlyContributionMinor,
    'annual_return_bps': {
      'low': lowReturnBps,
      'mid': midReturnBps,
      'high': highReturnBps,
    },
  };

  factory FutureMirrorDraft.fromProtectedMap(Map<String, Object?> value) {
    if (value.length != 3 ||
        value['name'] is! String ||
        value['monthly_contribution_minor'] is! int ||
        value['annual_return_bps'] is! Map) {
      throw const FormatException('Unsupported Future Mirror assumptions.');
    }
    final returns = value['annual_return_bps']! as Map;
    if (returns.length != 3 ||
        returns['low'] is! int ||
        returns['mid'] is! int ||
        returns['high'] is! int) {
      throw const FormatException('Unsupported Future Mirror assumptions.');
    }
    return FutureMirrorDraft(
      name: value['name']! as String,
      monthlyContributionMinor: value['monthly_contribution_minor']! as int,
      lowReturnBps: returns['low']! as int,
      midReturnBps: returns['mid']! as int,
      highReturnBps: returns['high']! as int,
    );
  }

  bool exactlyMatches(FutureMirrorDraft other) =>
      name.trim() == other.name.trim() &&
      monthlyContributionMinor == other.monthlyContributionMinor &&
      lowReturnBps == other.lowReturnBps &&
      midReturnBps == other.midReturnBps &&
      highReturnBps == other.highReturnBps;
}

@immutable
class FutureMirrorPoint {
  const FutureMirrorPoint({
    required this.date,
    required this.lowMinor,
    required this.midMinor,
    required this.highMinor,
  });

  final DateTime date;
  final int lowMinor;
  final int midMinor;
  final int highMinor;
}

@immutable
class FutureMirror {
  const FutureMirror({
    required this.id,
    required this.intentionId,
    required this.assumptions,
    required this.points,
    required this.generatedAt,
    required this.modelVersion,
    required this.inputHash,
    required this.ledgerWatermark,
    required this.uncertainty,
    required this.demo,
  });

  final String id;
  final String intentionId;
  final FutureMirrorDraft assumptions;
  final List<FutureMirrorPoint> points;
  final DateTime generatedAt;
  final String modelVersion;
  final String inputHash;
  final int ledgerWatermark;
  final String uncertainty;
  final FutureMirrorDemoDisclosure demo;

  FutureMirrorPoint get finalPoint => points.last;
}

@immutable
class FutureMirrorGenerate {
  const FutureMirrorGenerate({
    required this.intentionId,
    required this.draft,
    required this.idempotencyKey,
  });

  final String intentionId;
  final FutureMirrorDraft draft;
  final String idempotencyKey;
}

@immutable
class FutureMirrorDefaults {
  const FutureMirrorDefaults({
    required this.monthlyContributionMinor,
    required this.lowReturnBps,
    required this.midReturnBps,
    required this.highReturnBps,
    required this.sourceLabel,
  });

  factory FutureMirrorDefaults.forPersonalization(
    MemberPersonalization personalization,
  ) {
    final contribution = ContributionDefaults.forRhythm(
      personalization.contributionRhythm,
    );
    final monthly = switch (personalization.contributionRhythm) {
      MemberContributionRhythm.weekly => contribution.minorUnits * 4,
      MemberContributionRhythm.biweekly => contribution.minorUnits * 2,
      _ => contribution.minorUnits,
    };
    final returns = switch (personalization.riskFraming) {
      MemberRiskFraming.low => const (-1000, 250, 2000),
      MemberRiskFraming.moderate => const (-1500, 500, 3000),
      MemberRiskFraming.high => const (-2500, 750, 4500),
      MemberRiskFraming.unavailable => const (-1500, 400, 2500),
    };
    return FutureMirrorDefaults(
      monthlyContributionMinor: monthly,
      lowReturnBps: returns.$1,
      midReturnBps: returns.$2,
      highReturnBps: returns.$3,
      sourceLabel:
          '${personalization.riskFraming.name} risk framing starting range · '
          '${personalization.contributionRhythm.name} contribution rhythm · '
          'editable assumptions, never a predicted return',
    );
  }

  final int monthlyContributionMinor;
  final int lowReturnBps;
  final int midReturnBps;
  final int highReturnBps;
  final String sourceLabel;
}

class AmbiguousFutureMirrorGeneration implements Exception {
  const AmbiguousFutureMirrorGeneration();
}

class FutureMirrorValidationFailure implements Exception {
  const FutureMirrorValidationFailure(this.fieldErrors);

  final Map<FutureMirrorField, String> fieldErrors;
}
