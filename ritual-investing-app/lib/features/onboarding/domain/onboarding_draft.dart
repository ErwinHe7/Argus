import 'package:flutter/foundation.dart';

enum InvestingExperience { newToInvesting, someExperience, experienced }

enum InvestmentGoal { calmFund, longTermGrowth, income, exploration }

enum InvestmentHorizon { short, medium, long }

enum RiskComfort { low, moderate, high }

enum ContributionRhythm { weekly, biweekly, monthly, irregular, notSure }

enum RitualLanguage { practical, balanced, mystical, preferNotToSay }

enum RitualFamiliarity {
  newToRitual,
  curious,
  familiar,
  practiced,
  preferNotToSay,
}

enum RitualInterest {
  practicalResearch,
  tarot,
  astrology,
  moonCycles,
  reflection,
}

@immutable
class OnboardingDraft {
  const OnboardingDraft({
    this.experience,
    this.goal,
    this.horizon,
    this.risk,
    this.contributionRhythm,
    this.ritualLanguage,
    this.ritualFamiliarity,
    this.ritualInterests = const {},
    this.astrologyEnabled,
    this.birthDate,
    this.termsAccepted = false,
    this.privacyAccepted = false,
    this.demoAccepted = false,
  });

  final InvestingExperience? experience;
  final InvestmentGoal? goal;
  final InvestmentHorizon? horizon;
  final RiskComfort? risk;
  final ContributionRhythm? contributionRhythm;
  final RitualLanguage? ritualLanguage;
  final RitualFamiliarity? ritualFamiliarity;
  final Set<RitualInterest> ritualInterests;
  final bool? astrologyEnabled;
  final DateTime? birthDate;
  final bool termsAccepted;
  final bool privacyAccepted;
  final bool demoAccepted;

  static const _unset = Object();

  OnboardingDraft copyWith({
    Object? experience = _unset,
    Object? goal = _unset,
    Object? horizon = _unset,
    Object? risk = _unset,
    Object? contributionRhythm = _unset,
    Object? ritualLanguage = _unset,
    Object? ritualFamiliarity = _unset,
    Set<RitualInterest>? ritualInterests,
    Object? astrologyEnabled = _unset,
    Object? birthDate = _unset,
    bool? termsAccepted,
    bool? privacyAccepted,
    bool? demoAccepted,
  }) => OnboardingDraft(
    experience: identical(experience, _unset)
        ? this.experience
        : experience as InvestingExperience?,
    goal: identical(goal, _unset) ? this.goal : goal as InvestmentGoal?,
    horizon: identical(horizon, _unset)
        ? this.horizon
        : horizon as InvestmentHorizon?,
    risk: identical(risk, _unset) ? this.risk : risk as RiskComfort?,
    contributionRhythm: identical(contributionRhythm, _unset)
        ? this.contributionRhythm
        : contributionRhythm as ContributionRhythm?,
    ritualLanguage: identical(ritualLanguage, _unset)
        ? this.ritualLanguage
        : ritualLanguage as RitualLanguage?,
    ritualFamiliarity: identical(ritualFamiliarity, _unset)
        ? this.ritualFamiliarity
        : ritualFamiliarity as RitualFamiliarity?,
    ritualInterests: ritualInterests ?? this.ritualInterests,
    astrologyEnabled: identical(astrologyEnabled, _unset)
        ? this.astrologyEnabled
        : astrologyEnabled as bool?,
    birthDate: identical(birthDate, _unset)
        ? this.birthDate
        : birthDate as DateTime?,
    termsAccepted: termsAccepted ?? this.termsAccepted,
    privacyAccepted: privacyAccepted ?? this.privacyAccepted,
    demoAccepted: demoAccepted ?? this.demoAccepted,
  );

  Map<String, Object?> toJson() => {
    'experience': experience?.name,
    'goal': goal?.name,
    'horizon': horizon?.name,
    'risk': risk?.name,
    'contribution_rhythm': contributionRhythm?.name,
    'ritual_language': ritualLanguage?.name,
    'ritual_familiarity': ritualFamiliarity?.name,
    'ritual_interests': ritualInterests.map((value) => value.name).toList()
      ..sort(),
    'astrology_enabled': astrologyEnabled,
    if (birthDate != null) 'birth_date': onboardingDateOnly(birthDate!),
    'terms_accepted': termsAccepted,
    'privacy_accepted': privacyAccepted,
    'demo_accepted': demoAccepted,
  };

  factory OnboardingDraft.fromJson(
    Map<String, dynamic> json, {
    required DateTime today,
  }) {
    final birthDateValue = json['birth_date'];
    final draft = OnboardingDraft(
      experience: _enumByName(InvestingExperience.values, json['experience']),
      goal: _enumByName(InvestmentGoal.values, json['goal']),
      horizon: _enumByName(InvestmentHorizon.values, json['horizon']),
      risk: _enumByName(RiskComfort.values, json['risk']),
      contributionRhythm: _enumByName(
        ContributionRhythm.values,
        json['contribution_rhythm'],
      ),
      ritualLanguage: _enumByName(
        RitualLanguage.values,
        json['ritual_language'],
      ),
      ritualFamiliarity: _enumByName(
        RitualFamiliarity.values,
        json['ritual_familiarity'],
      ),
      ritualInterests:
          ((json['ritual_interests'] as List<dynamic>?) ?? const [])
              .map((value) => _enumByName(RitualInterest.values, value)!)
              .toSet(),
      astrologyEnabled: json['astrology_enabled'] as bool?,
      birthDate: birthDateValue == null
          ? null
          : parseOnboardingBirthDate(birthDateValue as String, today: today),
      termsAccepted: json['terms_accepted'] as bool? ?? false,
      privacyAccepted: json['privacy_accepted'] as bool? ?? false,
      demoAccepted: json['demo_accepted'] as bool? ?? false,
    );
    draft.validatePersisted(today: today);
    return draft;
  }

  void validatePersisted({required DateTime today}) {
    if (astrologyEnabled == true) {
      if (birthDate == null ||
          !isValidOnboardingBirthDate(birthDate!, today: today)) {
        throw const FormatException('Invalid astrology birth date.');
      }
    } else if (birthDate != null) {
      throw const FormatException(
        'Birth date requires explicit astrology opt-in.',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is OnboardingDraft &&
      other.experience == experience &&
      other.goal == goal &&
      other.horizon == horizon &&
      other.risk == risk &&
      other.contributionRhythm == contributionRhythm &&
      other.ritualLanguage == ritualLanguage &&
      other.ritualFamiliarity == ritualFamiliarity &&
      setEquals(other.ritualInterests, ritualInterests) &&
      other.astrologyEnabled == astrologyEnabled &&
      other.birthDate == birthDate &&
      other.termsAccepted == termsAccepted &&
      other.privacyAccepted == privacyAccepted &&
      other.demoAccepted == demoAccepted;

  @override
  int get hashCode => Object.hash(
    experience,
    goal,
    horizon,
    risk,
    contributionRhythm,
    ritualLanguage,
    ritualFamiliarity,
    Object.hashAllUnordered(ritualInterests),
    astrologyEnabled,
    birthDate,
    termsAccepted,
    privacyAccepted,
    demoAccepted,
  );
}

T? _enumByName<T extends Enum>(List<T> values, Object? name) {
  if (name == null) return null;
  if (name is! String) throw const FormatException('Invalid enum value.');
  for (final value in values) {
    if (value.name == name) return value;
  }
  throw FormatException('Unknown enum value: $name');
}

DateTime parseOnboardingBirthDate(String raw, {required DateTime today}) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw);
  if (match == null) throw const FormatException('Expected YYYY-MM-DD.');
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final candidate = DateTime.utc(year, month, day);
  if (candidate.year != year ||
      candidate.month != month ||
      candidate.day != day ||
      !isValidOnboardingBirthDate(candidate, today: today)) {
    throw const FormatException('Invalid birth date.');
  }
  return candidate;
}

bool isValidOnboardingBirthDate(DateTime value, {required DateTime today}) {
  if (!value.isUtc ||
      value.hour != 0 ||
      value.minute != 0 ||
      value.second != 0 ||
      value.millisecond != 0 ||
      value.microsecond != 0 ||
      value.year < 1900) {
    return false;
  }
  final latest = DateTime.utc(today.year, today.month, today.day);
  return !value.isAfter(latest);
}

String onboardingDateOnly(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.year.toString().padLeft(4, '0')}-${two(value.month)}-${two(value.day)}';
}
