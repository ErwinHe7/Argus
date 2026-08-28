import 'package:flutter/foundation.dart';

enum MemberIntentionStatus { active, archived }

@immutable
class ExactScenarioMoney {
  const ExactScenarioMoney({required this.minorUnits, required this.currency});

  final String minorUnits;
  final String currency;
}

@immutable
class MemberIntentionScenario {
  const MemberIntentionScenario({
    required this.id,
    required this.title,
    required this.target,
    required this.targetDate,
    required this.status,
    required this.version,
    required this.createdAt,
  });

  final String id;
  final String title;
  final ExactScenarioMoney target;
  final DateTime targetDate;
  final MemberIntentionStatus status;
  final int version;
  final DateTime createdAt;
}

@immutable
class MemberIntentionInput {
  const MemberIntentionInput({
    required this.title,
    required this.target,
    required this.targetDate,
  });

  final String title;
  final ExactScenarioMoney target;
  final DateTime targetDate;
}

@immutable
class HypotheticalScenarioInput {
  const HypotheticalScenarioInput({
    required this.name,
    required this.baseline,
    required this.monthlyContribution,
    required this.lowReturnBps,
    required this.midReturnBps,
    required this.highReturnBps,
    required this.asOfDate,
  });

  final String name;
  final ExactScenarioMoney baseline;
  final ExactScenarioMoney monthlyContribution;
  final int lowReturnBps;
  final int midReturnBps;
  final int highReturnBps;
  final DateTime asOfDate;
}

@immutable
class HypotheticalScenarioPoint {
  const HypotheticalScenarioPoint({
    required this.date,
    required this.lowMinor,
    required this.midMinor,
    required this.highMinor,
  });

  final DateTime date;
  final String lowMinor;
  final String midMinor;
  final String highMinor;
}

@immutable
class HypotheticalFutureScenario {
  const HypotheticalFutureScenario({
    required this.id,
    required this.intentionId,
    required this.input,
    required this.targetDate,
    required this.points,
    required this.modelVersion,
    required this.assumptionVersion,
    required this.generatedAt,
    required this.uncertaintyDisclosure,
  });

  final String id;
  final String intentionId;
  final HypotheticalScenarioInput input;
  final DateTime targetDate;
  final List<HypotheticalScenarioPoint> points;
  final String modelVersion;
  final String assumptionVersion;
  final DateTime generatedAt;
  final String uncertaintyDisclosure;
}

class ScenarioAmbiguousFailure implements Exception {
  const ScenarioAmbiguousFailure();
}
